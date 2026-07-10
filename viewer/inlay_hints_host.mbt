// The inlay-hints producer: converts provider hints into `after`
// injected-text decorations, the storage Monaco's `InlayHintsController`
// writes (`inlayHintsController.ts` `_updateHintsDecorators`:
// `{ range: fromPositions(position), options: { description, showIfCollapsed,
// after: { content, inlineClassName, attachedData } } }`). The projection
// reads injected text back from the model's decoration storage.

///|
/// Monaco `InlayHintsController` (`inlayHintsController.ts`,
/// `editor.contrib.InlayHints`): the per-editor provider result and its
/// decoration collection, reached through the instance table
/// (`docs/architecture.md`, "Controller access"). Filed in the root package
/// next to the glue below — the mirror has no `contrib/inlay_hints`
/// package yet.
priv struct InlayHintsController {
  /// The last provider result; kept for hover tooltip lookup.
  mut inlay_hints : Array[@language.InlayHint]
  /// The controller's per-editor decoration collection
  /// (`_updateHintsDecorators`' owner-scoped ids).
  mut inlay_hint_decoration_ids : Array[String]
  /// Viewer-lifetime request generation. It is never reset on model swaps;
  /// every replacement or invalidation advances it before new work begins.
  mut request_generation : Int
  /// Caller-owned cancellation source for the one current provider request.
  mut request_source : @language.CancellationTokenSource?
}

///|
/// Immutable authority captured at inlay request creation. URI, host version,
/// revision, and decoration instance id are deliberately absent.
priv struct InlayRequestStamp {
  model : @model.TextModel
  internal_version : Int
  generation : Int
  token : @language.CancellationToken
}

///|
/// Per-editor instances keyed by `viewer.get_id()`.
let inlay_hints_instances : Map[String, InlayHintsController] = {}

///|
fn InlayHintsController::attach(editor_id : String) -> InlayHintsController {
  let controller : InlayHintsController = {
    inlay_hints: [],
    inlay_hint_decoration_ids: [],
    request_generation: 0,
    request_source: None,
  }
  inlay_hints_instances[editor_id] = controller
  controller
}

///|
fn InlayHintsController::get(editor_id : String) -> InlayHintsController? {
  inlay_hints_instances.get(editor_id)
}

///|
fn InlayHintsController::detach(editor_id : String) -> Unit {
  match inlay_hints_instances.get(editor_id) {
    Some(controller) => controller.cancel_request()
    None => ()
  }
  inlay_hints_instances.remove(editor_id)
}

///|
fn new_feature_cancellation_source() -> @language.CancellationTokenSource {
  @language.CancellationTokenSource::new(schedule=callback => {
    schedule_timeout(callback, 0)
  })
}

///|
/// Cancels/retires old work and captures one fresh model/version/generation
/// request authority.
fn InlayHintsController::begin_request(
  self : InlayHintsController,
  model : @model.TextModel,
) -> InlayRequestStamp {
  match self.request_source {
    Some(source) => source.dispose(cancel=true)
    None => ()
  }
  self.request_generation += 1
  let source = new_feature_cancellation_source()
  self.request_source = Some(source)
  {
    model,
    internal_version: model.get_version_id(),
    generation: self.request_generation,
    token: source.token(),
  }
}

///|
/// Invalidates the current generation even when no provider request exists, so
/// a completion captured before detach/content change can never become current
/// again.
fn InlayHintsController::cancel_request(self : InlayHintsController) -> Unit {
  match self.request_source {
    Some(source) => source.dispose(cancel=true)
    None => ()
  }
  self.request_source = None
  self.request_generation += 1
}

///|
fn InlayHintsController::accepts_request(
  self : InlayHintsController,
  stamp : InlayRequestStamp,
  current_model : @model.TextModel?,
) -> Bool {
  !stamp.token.is_cancellation_requested() &&
  !stamp.model.is_disposed() &&
  self.request_generation == stamp.generation &&
  (match current_model {
    Some(model) =>
      !model.is_disposed() &&
      physical_equal(model, stamp.model) &&
      model.get_version_id() == stamp.internal_version
    None => false
  })
}

///|
fn InlayHintsController::finish_request(
  self : InlayHintsController,
  generation : Int,
) -> Unit {
  if self.request_generation != generation {
    return
  }
  match self.request_source {
    Some(source) => source.dispose()
    None => ()
  }
  self.request_source = None
}

///|
/// Drops the per-model state on a model swap: the provider result and the
/// decoration ids belong to the outgoing model.
fn InlayHintsController::reset_model_state(self : InlayHintsController) -> Unit {
  self.cancel_request()
  self.inlay_hints = []
  self.inlay_hint_decoration_ids = []
}

///|
/// The live controller instance for this editor — Monaco's
/// `InlayHintsController.get(editor)`. `None` after dispose.
fn Viewer::inlay_hints_controller(self : Viewer) -> InlayHintsController? {
  InlayHintsController::get(self.get_id())
}

///|
/// `registerEditorContribution(InlayHintsController.ID, …,
/// AfterFirstRender)` (`inlayHints.contribution.ts`).
fn register_inlay_hints_contribution(
  registry : EditorContributionRegistry,
) -> Unit {
  registry.register_editor_contribution(
    "editor.contrib.InlayHints",
    AfterFirstRender,
    viewer => {
      InlayHintsController::attach(viewer.get_id()) |> ignore
      {
        id: "editor.contrib.InlayHints",
        dispose: () => InlayHintsController::detach(viewer.get_id()),
      }
    },
  )
}

///|
/// Rewrites this editor's inlay-hint decorations from the current provider
/// result. The decoration-change event (with `affects_injected_text`)
/// triggers the projection rebuild.
fn Viewer::sync_inlay_hint_decorations(self : Viewer) -> Unit {
  guard self.inlay_hints_controller() is Some(controller) else { return }
  guard self.get_model() is Some(model) else { return }
  if controller.inlay_hints.is_empty() &&
    controller.inlay_hint_decoration_ids.is_empty() {
    return
  }
  controller.inlay_hint_decoration_ids = model.delta_decorations(
    controller.inlay_hint_decoration_ids,
    inlay_hint_delta_decorations(controller.inlay_hints),
    owner_id=self.editor_id,
  )
}

///|
/// One collapsed `after`-injected-text decoration per non-empty hint.
fn inlay_hint_delta_decorations(
  hints : Array[@language.InlayHint],
) -> Array[@model.ModelDeltaDecoration] {
  let decorations : Array[@model.ModelDeltaDecoration] = []
  for index in 0..<hints.length() {
    let hint = hints[index]
    let content = padded_inlay_hint_label(hint)
    if content.length() == 0 {
      continue
    }
    decorations.push({
      range: Range(
        hint.position.line_number,
        hint.position.column,
        hint.position.line_number,
        hint.position.column,
      ),
      options: ModelDecorationOptions(
        "",
        description="inlay-hint",
        // A collapsed range must survive the injected-text tree's
        // `showIfCollapsed || !isEmpty` query filter (Monaco sets it too).
        show_if_collapsed=true,
        after=InjectedTextOptions(
          content,
          inline_class_name=inlay_hint_class_name(hint),
          attached_index=index,
        ),
      ),
    })
  }
  decorations
}

///|
fn padded_inlay_hint_label(hint : @language.InlayHint) -> String {
  let builder = StringBuilder()
  if hint.padding_left {
    builder.write_string(" ")
  }
  builder.write_string(hint.label)
  if hint.padding_right {
    builder.write_string(" ")
  }
  builder.to_string()
}

///|
fn inlay_hint_class_name(hint : @language.InlayHint) -> String {
  match hint.kind {
    Some(TypeHint) => "inlay-hint inlay-hint-type"
    Some(ParameterHint) => "inlay-hint inlay-hint-parameter"
    None => "inlay-hint"
  }
}
