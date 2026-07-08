///|
/// Warms the model's memoized tokenization part and builds the long-lived
/// view model — the tail of Monaco's `_attachModel`
/// (`codeEditorWidget.ts`, reached from `setModel`). Only a model attach
/// pays this: later option and decoration changes update the view model in
/// place (`ViewModel::on_configuration_changed`,
/// `on_did_change_content_or_injected_text`) and tokenizer changes only
/// re-warm the token memo (`retokenize_current_model`). Synchronous CPU
/// work; the paint happens in the next render flush.
fn Viewer::attach_model(self : Viewer, model : @model.TextModel) -> Unit {
  let tokenize_started = now_ms()
  model.tokenization.force_tokenization()
  let tokenize_finished = now_ms()
  // Decorations live in the model's interval-tree storage; the view
  // model queries them lazily per viewport (no per-frame bake). The render
  // pass pulls its viewport data from the view model at flush time.
  let view_model = self.build_view_model(model)
  self.apply_view_model_layout(view_model, model.snapshot)
  let build_finished = now_ms()
  self.view_model = Some(view_model)
  self.rendered_window = None
  self.text_model = Some(model)
  self.refresh_cursor_context()
  self.content_generation += 1
  self.did_build_view_model.fire({
    model,
    line_count: view_model.line_count(),
    token_count: model.tokenization.token_count(),
    diagnostic_count: self.services.markers
    .diagnostics_for_resource(model.uri)
    .length(),
    tokenize_ms: tokenize_finished - tokenize_started,
    build_ms: build_finished - tokenize_finished,
  })
  self.pending_rendered = Some({ model, fresh: true })
  self.measure_requested = true
  self.schedule_render()
  self.request_model_features(model)
}

///|
fn Viewer::build_view_model(
  self : Viewer,
  model : @model.TextModel,
) -> @view_model.ViewModel {
  let options = self.options.view_model_options(
    self.soft_wrap_column,
    font_info=self.font_info,
    editor_id=self.editor_id,
  )
  // Injected text (inlay hints) reaches the projection through the model's
  // decoration storage (Track F), not through construction arguments.
  @view_model.ViewModel::with_options(model, options)
}

///|
/// The viewer's `model.onDidChangeTokens` handler: re-warms the reset token
/// memo and schedules a repaint — Monaco's `ModelTokensChangedEvent` →
/// `ViewTokensChangedEvent` round trip. The long-lived view model survives;
/// only the token memo and the paint are redone.
fn Viewer::retokenize_current_model(
  self : Viewer,
  model : @model.TextModel,
) -> Unit {
  let tokenize_started = now_ms()
  model.tokenization.force_tokenization()
  let tokenize_finished = now_ms()
  guard self.view_model is Some(view_model) else { return }
  self.content_generation += 1
  self.did_build_view_model.fire({
    model,
    line_count: view_model.line_count(),
    token_count: model.tokenization.token_count(),
    diagnostic_count: self.services.markers
    .diagnostics_for_resource(model.uri)
    .length(),
    tokenize_ms: tokenize_finished - tokenize_started,
    build_ms: 0.0,
  })
  let fresh = match self.pending_rendered {
    Some(pending) => pending.fresh
    None => false
  }
  self.pending_rendered = Some({ model, fresh })
  self.schedule_render()
}

///|
/// Routes a layout-affecting option change into the live view model —
/// Monaco's `_configuration.onDidChangeFast` → `_onConfigurationChanged`
/// subscription. A changed view-line mapping re-flushes the layout; anything
/// else only re-syncs the content width.
fn Viewer::on_configuration_changed(self : Viewer) -> Unit {
  match (self.view_model, self.text_model) {
    (Some(view_model), Some(model)) => {
      let options = self.options.view_model_options(
        self.soft_wrap_column,
        font_info=self.font_info,
        editor_id=self.editor_id,
      )
      if view_model.on_configuration_changed(options) {
        self.on_line_mapping_changed(view_model, model)
      } else {
        self.sync_content_width()
      }
    }
    _ => self.sync_content_width()
  }
}

///|
/// The viewer's side of a changed view-line mapping (wrapping reflow,
/// injected text): re-flush the layout, drop the rendered window, re-point
/// the cursor at the reconstructed projection, and mark the content stale —
/// Monaco's `ViewFlushedEvent`/`ViewLineMappingChangedEvent` handling
/// (`viewLayout.onFlushed` + `_cursor.onLineMappingChanged`).
fn Viewer::on_line_mapping_changed(
  self : Viewer,
  view_model : @view_model.ViewModel,
  model : @model.TextModel,
) -> Unit {
  self.apply_view_model_layout(view_model, model.snapshot)
  self.rendered_window = None
  self.refresh_cursor_context()
  self.content_generation += 1
  let fresh = match self.pending_rendered {
    Some(pending) => pending.fresh
    None => false
  }
  self.pending_rendered = Some({ model, fresh })
}

///|
fn Viewer::apply_view_model_layout(
  self : Viewer,
  view_model : @view_model.ViewModel,
  snapshot : @model.TextSnapshot,
) -> Unit {
  self.view_layout.set_line_count(view_model.line_count()) |> ignore
  self.normalize_browser_view_zones()
  self.sync_view_zones_with_layout()
  self.max_line_length = if self.options.soft_wrap && self.soft_wrap_column > 0 {
    max_view_line_length(view_model.lines())
  } else {
    max_line_length(snapshot)
  }
  self.sync_content_width()
}

///|
/// The widest line in UTF-16 code units, the horizontal scroll extent
/// driver (uniform-advance monospace metrics).
fn max_line_length(snapshot : @model.TextSnapshot) -> Int {
  let mut widest = 0
  for line in 0..<snapshot.line_count() {
    let length = snapshot.line_end_offset(line) -
      snapshot.line_start_offset(line)
    if length > widest {
      widest = length
    }
  }
  widest
}

///|
fn max_view_line_length(
  lines : @view_model.ViewModelLinesFromProjectedModel,
) -> Int {
  let mut widest = 0
  for line_number in 1..<=lines.get_view_line_count() {
    let length = lines.get_view_line_content(line_number).length()
    if length > widest {
      widest = length
    }
  }
  widest
}

///|
