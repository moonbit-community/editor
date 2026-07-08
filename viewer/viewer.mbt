///|
/// The embeddable readonly code viewer, the `vs/editor` (Monaco) role: an
/// browser `View` owning the rendered lines, the scroll and
/// layout model, the input bridge, and the feature controllers. It is
/// constructed independently from document sources, attached into a
/// host-provided stable element, and reports lifecycle facts through typed
/// subscriptions; it knows nothing about transports, shell reload policy,
/// provider watches, or harness event formats.
///
/// All methods are plain calls (the host wraps them in its own effect
/// system if it has one). The host must never render its own children
/// into the element passed to `attach`.
pub struct Viewer {
  priv services : ViewerServices
  priv mut options : ViewerOptions
  priv did_change_model : @base_common.Emitter[ModelChangedEvent]
  priv did_change_cursor_position : @base_common.Emitter[
    CursorPositionChangedEvent,
  ]
  priv did_change_cursor_selection : @base_common.Emitter[
    CursorSelectionChangedEvent,
  ]
  priv did_build_view_model : @base_common.Emitter[ViewerViewModelBuiltEvent]
  priv did_render_model : @base_common.Emitter[ViewerModelRenderedEvent]
  priv did_resolve_hover : @base_common.Emitter[ViewerHoverResolvedEvent]
  priv did_scroll : @base_common.Emitter[ScrollEvent]
  priv did_dispose : @base_common.Emitter[Unit]
  /// Public mouse events (`onMouseDown`/`onMouseUp`/`onMouseMove`/
  /// `onMouseLeave`, see `mouse_events.mbt`), fired from the controller's
  /// notify seams; the comments contrib subscribes like Monaco's
  /// `CommentController.registerEditorListeners`.
  priv did_mouse_down : @base_common.Emitter[EditorMouseEvent]
  priv did_mouse_up : @base_common.Emitter[EditorMouseEvent]
  priv did_mouse_move : @base_common.Emitter[EditorMouseEvent]
  priv did_mouse_leave : @base_common.Emitter[Unit]
  /// The last fired scroll event's facts, the diff base for the next event's
  /// `*_changed` flags (Monaco's `ScrollEvent` carries per-axis change bits).
  priv mut last_scroll_event : ScrollEvent?
  priv mut view_model : @view_model.ViewModel?
  /// The last rendered view-line window (clamped, half-open): exactly the
  /// lines intersecting the viewport at the last flush, resynced from the
  /// layout every flush.
  priv mut rendered_window : @view_layout.LineWindow?
  priv mut text_model : @model.TextModel?
  priv mut view_zones : Array[@view_zones.BrowserViewZone]
  /// The persistent content-hover widget (Monaco `ContentHoverWidget`),
  /// created lazily and mounted once through the content-widgets part.
  priv mut content_hover_widget : @hover_browser.ContentHoverWidget?
  /// The `HoverWidgetView` last driven into the widget, so
  /// `sync_content_hover_widget` shows/hides exactly when the derived view
  /// changed (Monaco `_setCurrentResult`'s changed-result gate).
  priv mut hover_widget_view : @hover.HoverWidgetView?
  /// The measured font facts (Monaco's `EditorOption.fontInfo`): starts as
  /// the untrusted headless estimate and is replaced by
  /// `FontMeasurements.readFontInfo` at the first attached measure.
  priv mut font_info : @config.FontInfo
  /// The measured editor box (Monaco's `EditorOption.layoutInfo` role — the
  /// container observer lives in `editorConfiguration.ts`, and `ViewLayout`
  /// *reads* layout info from the configuration): the content width (view box
  /// minus the gutter) and the viewport height. Written by `measure`; read
  /// pre-model by the wrap-column math and `get_layout_info`, and seeded into
  /// each per-model `ViewLayout` at construction.
  priv mut measured_content_width : Double
  priv mut measured_height : Double
  priv mut soft_wrap_column : Int
  priv mut max_line_length : Int
  priv mut view : @view.View?
  /// The host element handed to `attach` — Monaco's `_containerDomElement`.
  priv mut container : @rdom.Element?
  priv mut render_pending : Bool
  priv mut measure_requested : Bool
  priv mut pending_rendered : PendingRendered?
  priv mut scroll_dirty : Bool
  /// Bumped whenever the inputs of line HTML change (new view model or
  /// changed controller decorations); the recycler rewrites every
  /// rendered line when it differs, and only entering lines otherwise.
  priv mut content_generation : Int
  /// This editor's decoration `ownerId` (Monaco's per-widget editor id): the
  /// filter handed to `ViewModelDecorations` and the ownerId of the public
  /// `delta_decorations` API.
  priv editor_id : Int
  /// Bumped per `TextModel.onDidChangeDecorations` event; the render snapshot
  /// carries it, and a change dispatches `ViewDecorationsChanged` to the view
  /// parts (plan Deviation 3 — the render-snapshot event seam).
  priv mut decorations_generation : Int
  priv mut model_decorations_subscription : @base_common.Disposable?
  priv mut model_tokens_subscription : @base_common.Disposable?
  priv mut model_will_dispose_subscription : @base_common.Disposable?
  priv mut mouse_handler : @controller.MouseHandler?
  /// The last `mousemove`'s `MouseEvent.buttons` bitmask, recorded by the
  /// root listener so `on_mouse_move` events can carry `event.leftButton`
  /// (the notify seam only carries the hit target).
  priv mut last_mouse_buttons : Int
  /// Whether the editor root currently has DOM focus — the viewer's stand-in
  /// for Monaco's edit-context focus (`view.ts` `_getEditorClassName` /
  /// `ViewFocusChangedEvent`). Sourced by `focus`/`blur` listeners on the root
  /// (`input.mbt`); read into every render snapshot, where a change dispatches
  /// `ViewFocusChanged` to the view parts.
  priv mut editor_has_focus : Bool
  /// Monaco's `ViewLines._horizontalRevealRequest`: a single-line reveal whose
  /// horizontal scroll is deferred until the target view line renders (its
  /// client rects are unknown until then). Flushed in `flush_render`, cancelled
  /// when an unrelated scroll moves out of the reveal's band (`reveal.mbt`).
  priv mut horizontal_reveal_request : HorizontalRevealRangeRequest?
  /// The per-editor contribution instances the registry constructed
  /// (`codeEditorContributions.ts`'s `_instances`, keyed by contribution
  /// id); disposed with the viewer.
  priv mut contributions : Map[String, EditorContribution]
}

///|
priv struct PendingRendered {
  model : @model.TextModel
  fresh : Bool
}

///|
/// A deferred horizontal reveal, Monaco's `HorizontalRevealRangeRequest`. Holds
/// the 1-based view line/columns to measure once rendered, plus the scroll-top
/// band (`[start_scroll_top, stop_scroll_top]`) outside which an intervening
/// vertical scroll cancels the request.
priv struct HorizontalRevealRangeRequest {
  view_line_number : Int
  start_column : Int
  end_column : Int
  start_scroll_top : Double
  stop_scroll_top : Double
}

///|
pub(all) struct ViewerViewState {
  scroll_top : Double
  scroll_left : Double
} derive(Debug)

///|
/// Monaco's `IModelChangedEvent` (`editorCommon.ts`): the model swap fact,
/// carried as resource URIs (`None` for the detached side).
pub(all) struct ModelChangedEvent {
  old_model_url : @base_common.Uri?
  new_model_url : @base_common.Uri?
} derive(Debug)

///|
/// Monaco's `CursorChangeReason` (`cursorEvents.ts`). The readonly viewer's
/// cursor only moves explicitly (API or mouse), so today only `NotSet` and
/// `Explicit` are fired; the editing reasons exist for shape parity.
pub(all) enum CursorChangeReason {
  NotSet
  ContentFlush
  RecoverFromMarkers
  Explicit
  Paste
  Undo
  Redo
} derive(Eq, Debug)

///|
/// Monaco's `ICursorPositionChangedEvent`. The viewer is single-cursor, so
/// `secondary_positions` is always empty (see `get_selections`).
pub(all) struct CursorPositionChangedEvent {
  position : @base_common.Position
  secondary_positions : Array[@base_common.Position]
  reason : CursorChangeReason
  source : String
} derive(Debug)

///|
/// Monaco's `ICursorSelectionChangedEvent`, single-cursor: the secondary
/// arrays are always empty, and `old_selections` is at most one element
/// (empty before the first cursor exists).
pub(all) struct CursorSelectionChangedEvent {
  selection : @core.Selection
  secondary_selections : Array[@core.Selection]
  model_version_id : Int
  old_selections : Array[@core.Selection]
  old_model_version_id : Int
  source : String
  reason : CursorChangeReason
} derive(Debug)

///|
/// Monaco's `ScrollEvent` (`scrollable.ts`) trimmed to the position and extent
/// facts plus their per-axis change flags.
pub(all) struct ScrollEvent {
  scroll_top : Double
  scroll_left : Double
  scroll_width : Double
  scroll_height : Double
  scroll_top_changed : Bool
  scroll_left_changed : Bool
  scroll_width_changed : Bool
  scroll_height_changed : Bool
} derive(Debug)

///|
pub(all) struct ViewerViewModelBuiltEvent {
  model : @model.TextModel
  line_count : Int
  token_count : Int
  diagnostic_count : Int
  tokenize_ms : Double
  build_ms : Double
} derive(Debug)

///|
pub(all) struct ViewerModelRenderedEvent {
  model : @model.TextModel
  line_count : Int
  rendered_lines : Int
  diagnostics : Array[@language.Diagnostic]
  patch_ms : Double
  fresh : Bool
} derive(Debug)

///|
pub(all) struct ViewerHoverResolvedEvent {
  ok : Bool
  revision : String
} derive(Debug)

///|
/// Creates a viewer instance. Call `attach` before setting documents so the
/// first render has a DOM view to measure and patch.
pub fn Viewer::Viewer(
  services? : ViewerServices = ViewerServices::new(),
  options? : ViewerOptions = ViewerOptions::default(),
) -> Viewer {
  let font_info = @config.FontInfo::estimated(
    options.bare_font_info(pixel_ratio=@browser_config.device_pixel_ratio()),
  )
  let viewer : Viewer = {
    services,
    options,
    did_change_model: @base_common.Emitter::new(),
    did_change_cursor_position: @base_common.Emitter::new(),
    did_change_cursor_selection: @base_common.Emitter::new(),
    did_build_view_model: @base_common.Emitter::new(),
    did_render_model: @base_common.Emitter::new(),
    did_resolve_hover: @base_common.Emitter::new(),
    did_scroll: @base_common.Emitter::new(),
    did_dispose: @base_common.Emitter::new(),
    did_mouse_down: @base_common.Emitter::new(),
    did_mouse_up: @base_common.Emitter::new(),
    did_mouse_move: @base_common.Emitter::new(),
    did_mouse_leave: @base_common.Emitter::new(),
    last_scroll_event: None,
    view_model: None,
    rendered_window: None,
    text_model: None,
    view_zones: [],
    content_hover_widget: None,
    hover_widget_view: None,
    font_info,
    measured_content_width: 0.0,
    measured_height: 0.0,
    soft_wrap_column: 0,
    max_line_length: 0,
    view: None,
    container: None,
    render_pending: false,
    measure_requested: false,
    pending_rendered: None,
    scroll_dirty: false,
    content_generation: 0,
    editor_id: next_editor_id(),
    decorations_generation: 0,
    model_decorations_subscription: None,
    model_tokens_subscription: None,
    model_will_dispose_subscription: None,
    mouse_handler: None,
    last_mouse_buttons: 0,
    editor_has_focus: false,
    horizontal_reveal_request: None,
    contributions: {},
  }
  // Marker decoration changes reach the render through the model's
  // decoration storage (`onDidChangeDecorations` → `ViewDecorationsChanged`);
  // this subscription only schedules the refresh without rebuilding the view model
  // (no `content_generation` bump — decoration plan Phase 3). Hosts observe
  // marker changes on `MarkerService::on_did_change_markers`.
  viewer.services.marker_decorations.on_did_change_marker_decorations(model => {
    if viewer.is_current_model(model) {
      viewer.schedule_render()
    }
  })
  |> ignore
  // Editor contributions instantiate through the registry
  // (`codeEditorWidget.ts:344` `this._contributions.initialize(...)`);
  // they live until `dispose` — `set_model` does not re-create them.
  viewer.contributions = editor_registry().instantiate_all(viewer)
  viewer
}

///|
/// Process-wide editor id counter (Monaco's per-widget editor id).
priv struct EditorIdCounter {
  mut value : Int
}

///|
let editor_id_counter : EditorIdCounter = { value: 0 }

///|
fn next_editor_id() -> Int {
  editor_id_counter.value += 1
  editor_id_counter.value
}

///|
/// Creates and attaches a viewer in one call — the `monaco.editor.create`
/// entry point.
pub fn Viewer::create(
  host : @rdom.Element,
  services? : ViewerServices = ViewerServices::new(),
  options? : ViewerOptions = ViewerOptions::default(),
) -> Viewer {
  let viewer = Viewer(services~, options~)
  viewer.attach(host)
  viewer
}

///|
/// Fires when the installed model changed — Monaco's `onDidChangeModel`
/// carrying `IModelChangedEvent` (the old/new resource URIs).
pub fn Viewer::on_did_change_model(
  self : Viewer,
  listener : (ModelChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_change_model.event(listener)
}

///|
/// Fires when the primary cursor's model position changed — Monaco's
/// `onDidChangeCursorPosition` (`cew:117-118`, fired at `:1836-1845`).
/// Single-cursor: `secondary_positions` is always empty.
pub fn Viewer::on_did_change_cursor_position(
  self : Viewer,
  listener : (CursorPositionChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_change_cursor_position.event(listener)
}

///|
/// Fires when the primary cursor's model selection changed — Monaco's
/// `onDidChangeCursorSelection` (`cew:120-121`, fired at `:1846-1857`).
/// Single-cursor: the secondary arrays are always empty.
pub fn Viewer::on_did_change_cursor_selection(
  self : Viewer,
  listener : (CursorSelectionChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_change_cursor_selection.event(listener)
}

///|
/// Fires after the editor scroll position or extents changed — Monaco's
/// `onDidScrollChange`, coalesced onto the render flush.
pub fn Viewer::on_did_scroll_change(
  self : Viewer,
  listener : (ScrollEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_scroll.event(listener)
}

///|
pub fn Viewer::on_did_dispose(
  self : Viewer,
  listener : () -> Unit,
) -> @base_common.Disposable {
  self.did_dispose.event(_ => listener())
}

///|
/// Applies runtime options — `updateOptions`. Theme and placeholder apply
/// without a rebuild; the current view model is rebuilt when wrapping, tab, or
/// render settings change.
pub fn Viewer::update_options(self : Viewer, options : ViewerOptions) -> Unit {
  if self.options == options {
    return
  }
  let previous = self.options
  self.options = options
  if previous.theme != options.theme {
    self.apply_theme()
  }
  if previous.same_layout_options(options) {
    self.schedule_render()
    return
  }
  // A changed font option resolves through `FontMeasurements` immediately
  // (Monaco's synchronous `_recomputeOptions`), so the wrap column below
  // already uses the new advance width.
  self.refresh_font_info()
  self.soft_wrap_column = self.options.soft_wrap_column_for_content_width(
    self.measured_content_width,
    self.measured_char_width(),
  )
  self.on_configuration_changed()
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Mirrors the theme option onto the view root as a `data-theme` attribute
/// (colors cascade from the host's CSS theme variables) and recomputes the
/// squiggle stylesheet from the newly cascaded colors; the view keeps its DOM
/// and scroll position.
fn Viewer::apply_theme(self : Viewer) -> Unit {
  match self.view {
    Some(view) => {
      view.root.set_attribute("data-theme", self.options.theme)
      view.apply_squiggly_theme()
    }
    None => ()
  }
}

///|
/// Builds the browser `View` inside the host element and hooks its
/// listeners. The host element must stay mounted and must never receive
/// host-rendered children; the view owns its whole subtree.
fn Viewer::attach(self : Viewer, host : @rdom.Element) -> Unit {
  if self.view is Some(_) {
    return
  }
  let view = @view.View::new()
  view.root.set_attribute("data-theme", self.options.theme)
  host.append_child(view.root.as_node())
  view.apply_squiggly_theme()
  self.view = Some(view)
  self.container = Some(host)
  // The editor root carries the configured font — Monaco's
  // `applyFontInfo(this.domNode, fontInfo)` in `view.ts`. The measured
  // `FontInfo` replaces the headless estimate at the first flush's measure.
  self.apply_font_info_to_view(view)
  // Untrusted readings re-measure after 5s (`FontMeasurements.onDidChange`,
  // e.g. once a web font finished loading) — Monaco's
  // `_recomputeOptions` subscription in `editorConfiguration.ts`.
  @browser_config.font_measurements().on_did_change(() => {
    self.measure_requested = true
    self.schedule_render()
  })
  |> ignore
  self.hook_view_input(view)
  self.measure_requested = true
  self.schedule_render()
  // Feedback bubbles seeded before the view existed can mount now.
  self.rebuild_agent_feedback_widgets()
}

///|
/// Renders caller-owned immutable text model state — `setModel`. Source reads,
/// watches, reloads, and error policy belong to the host. `None` detaches the
/// current model and clears the rendered content. Like Monaco, swapping the
/// model resets the scroll position and controller state; hosts preserve or
/// restore scroll through `save_view_state`/`restore_view_state`.
pub fn Viewer::set_model(self : Viewer, model : @model.TextModel?) -> Unit {
  match model {
    Some(model) => self.set_current_model(model)
    None =>
      match self.text_model {
        Some(prev) => {
          let old_model_url = Some(prev.uri)
          self.clear_current_model()
          self.did_change_model.fire({ old_model_url, new_model_url: None })
        }
        None => ()
      }
  }
}

///|
fn Viewer::set_current_model(self : Viewer, model : @model.TextModel) -> Unit {
  let old_model_url = match self.text_model {
    Some(prev) => Some(prev.uri)
    None => None
  }
  // Rotate the per-model marker decorations: drop the previous model's set when
  // switching resources, then (re)register this model so marker changes resolve
  // against its snapshot (Monaco's `_onModelRemoved`/`_onModelAdded`).
  match self.text_model {
    Some(prev) =>
      if prev.uri.to_string() != model.uri.to_string() {
        self.services.marker_decorations.on_model_removed(prev)
      }
    None => ()
  }
  self.services.markers.clear_resource(model.uri)
  // Rotate the per-model subscriptions with the model (plan D6: owners
  // re-attach on swap) — Monaco's `listenersToRemove` set in `_attachModel`.
  // The decoration-change subscription attaches before the marker service
  // seeds the model so the seeding delta is observed too.
  match self.model_decorations_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  match self.model_tokens_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  match self.model_will_dispose_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  // The hover-owned decoration ids belong to the outgoing model's storage.
  match self.content_hover_controller() {
    Some(hc) => hc.reset_model_state()
    None => ()
  }
  // Feedback decoration/widget state belongs to the outgoing model; the
  // model-change event re-applies the new resource's feedback data.
  match self.agent_feedback_input_contribution() {
    Some(ic) => ic.reset_model_state()
    None => ()
  }
  match self.agent_feedback_widget_contribution() {
    Some(wc) => wc.reset_model_state()
    None => ()
  }
  self.clear_agent_feedback_widgets() |> ignore
  self.model_decorations_subscription = Some(
    model.on_did_change_decorations(event => {
      // Monaco: `onDidChangeDecorations` → `viewModel.decorations
      // .onModelDecorationsChanged()` (`viewModelImpl.ts`) — drop the
      // computer + viewport caches before the re-render reads them.
      match self.view_model {
        Some(view_model) => {
          view_model.decorations().on_model_decorations_changed()
          // Injected-text deltas re-run the line-breaks computer per line in
          // Monaco (`onDidChangeContentOrInjectedText`); the viewer's
          // granularity is the whole-document reproject
          // (`_lines.onModelFlushed()`), applied to the live view model.
          if event.affects_injected_text {
            view_model.on_did_change_content_or_injected_text()
            self.on_line_mapping_changed(view_model, model)
          }
        }
        None => ()
      }
      self.decorations_generation += 1
      self.schedule_render()
    }),
  )
  // A disposed model detaches itself
  // (`codeEditorWidget.ts:1787` `model.onWillDispose(() => this.setModel(null))`).
  self.model_will_dispose_subscription = Some(
    model.on_will_dispose(() => self.set_model(None)),
  )
  // Token changes (the part's registry subscription fires them on tokenizer
  // (re)registration) re-warm the memo and repaint — Monaco's
  // `ModelTokensChangedEvent` handling. The viewer's granularity is the whole
  // document, so the event's ranges are not consulted.
  self.model_tokens_subscription = Some(
    model.on_did_change_tokens(_ => self.retokenize_current_model(model)),
  )
  self.services.marker_decorations.on_model_added(model)
  match self.inlay_hints_controller() {
    Some(controller) => controller.reset_model_state()
    None => ()
  }
  self.cancel_mouse_selection()
  self.dismiss_hover()
  self.attach_model(model)
  self.did_change_model.fire({ old_model_url, new_model_url: Some(model.uri) })
}

///|
/// Returns the current model installed on the viewer.
pub fn Viewer::get_model(self : Viewer) -> @model.TextModel? {
  self.text_model
}

///|
/// Whether a model is installed — `hasModel`, Monaco's type-guard companion to
/// `getModel`.
pub fn Viewer::has_model(self : Viewer) -> Bool {
  self.text_model is Some(_)
}

///|
/// The current options snapshot — the read side of `update_options` (Monaco's
/// `getOptions`/`getRawOptions`, collapsed onto the one options struct).
pub fn Viewer::get_options(self : Viewer) -> ViewerOptions {
  self.options
}

///|
/// The editor type marker, Monaco's `getEditorType()` →
/// `EditorType.ICodeEditor`.
pub fn Viewer::get_editor_type(self : Viewer) -> String {
  ignore(self)
  "vs.editor.ICodeEditor"
}

///|
/// This editor's unique id, Monaco's `getId()`: the editor type plus the
/// process-wide instance counter.
pub fn Viewer::get_id(self : Viewer) -> String {
  self.get_editor_type() + ":" + self.editor_id.to_string()
}

///|
/// The editor's own root element — `getDomNode`; `None` until attached.
pub fn Viewer::get_dom_node(self : Viewer) -> @rdom.Element? {
  match self.view {
    Some(view) => Some(view.root)
    None => None
  }
}

///|
/// The host container element — `getContainerDomNode`; `None` until attached
/// (Monaco receives the container at construction, so it is always present
/// there).
pub fn Viewer::get_container_dom_node(self : Viewer) -> @rdom.Element? {
  self.container
}

///|
/// Focuses the editor's focusable surface — `focus()`. Monaco focuses the
/// hidden textarea / edit context; the viewer's focusable surface is the view
/// root itself.
pub fn Viewer::focus(self : Viewer) -> Unit {
  match self.view {
    Some(view) => focus_element(view.root)
    None => ()
  }
}

///|
/// Whether the editor's text surface has DOM focus — `hasTextFocus()`.
pub fn Viewer::has_text_focus(self : Viewer) -> Bool {
  self.editor_has_focus
}

///|
/// Whether focus is anywhere inside the editor widget, including hover
/// widgets — `hasWidgetFocus()`.
pub fn Viewer::has_widget_focus(self : Viewer) -> Bool {
  match self.view {
    Some(view) => self.editor_has_focus || element_contains_active(view.root)
    None => false
  }
}

///|
/// Returns the current scroll state in host-restorable form — Monaco's
/// `saveViewState` (`cew:1038-1041`). No model → `None`.
pub fn Viewer::save_view_state(self : Viewer) -> ViewerViewState? {
  guard self.view_model is Some(view_model) else { return None }
  let position = view_model.view_layout.position()
  Some({ scroll_top: position.scroll_top, scroll_left: position.scroll_left })
}

///|
/// Restores a previously captured scroll state — Monaco's `restoreViewState`
/// (`cew:1052`): a no-op without a model, and `None` state restores nothing.
pub fn Viewer::restore_view_state(
  self : Viewer,
  state : ViewerViewState?,
) -> Unit {
  guard self.view_model is Some(view_model) else { return }
  match state {
    Some(state) =>
      self.apply_scroll_change(
        view_model.view_layout.scroll_to(
          scroll_top=state.scroll_top,
          scroll_left=state.scroll_left,
        ),
      )
    None => ()
  }
}

///|
/// Disposes viewer-owned external resources. Like Monaco's dispose, the model
/// detaches silently (no `onDidChangeModel`).
pub fn Viewer::dispose(self : Viewer) -> Unit {
  if self.text_model is Some(_) {
    self.clear_current_model()
  }
  // Contributions dispose with the editor (`codeEditorWidget.dispose` →
  // `this._contributions.dispose()`).
  for _, contribution in self.contributions {
    (contribution.dispose)()
  }
  self.contributions = {}
  self.did_dispose.fire(())
  self.did_change_model.dispose()
  self.did_change_cursor_position.dispose()
  self.did_change_cursor_selection.dispose()
  self.did_build_view_model.dispose()
  self.did_render_model.dispose()
  self.did_resolve_hover.dispose()
  self.did_scroll.dispose()
  self.did_dispose.dispose()
  self.did_mouse_down.dispose()
  self.did_mouse_up.dispose()
  self.did_mouse_move.dispose()
  self.did_mouse_leave.dispose()
  self.services.marker_decorations.dispose()
  self.services.markers.dispose()
  self.services.agent_feedback.dispose()
}

///|
/// Re-measures the viewer box after a host-observed layout change —
/// `layout()`. The explicit-dimension form is not ported: the viewer always
/// measures its host element.
pub fn Viewer::layout(self : Viewer) -> Unit {
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Sets the vertical synthetic scroll position — `setScrollTop`
/// (`cew:1014-1017`, no model → no-op). Wheel and scrollbar input arrive
/// through the view's own listeners.
pub fn Viewer::set_scroll_top(self : Viewer, new_scroll_top : Double) -> Unit {
  guard self.view_model is Some(view_model) else { return }
  self.apply_scroll_change(
    view_model.view_layout.scroll_to(scroll_top=new_scroll_top),
  )
}

///|
/// Sets the horizontal synthetic scroll position — `setScrollLeft`
/// (`cew:1003-1006`, no model → no-op).
pub fn Viewer::set_scroll_left(self : Viewer, new_scroll_left : Double) -> Unit {
  guard self.view_model is Some(view_model) else { return }
  self.apply_scroll_change(
    view_model.view_layout.scroll_to(
      scroll_top=view_model.view_layout.position().scroll_top,
      scroll_left=new_scroll_left,
    ),
  )
}

///|
/// Sets both synthetic scroll axes — `setScrollPosition` with Monaco's
/// `INewScrollPosition` semantics: an omitted axis keeps its position
/// (`cew:1025-1028`, no model → no-op).
pub fn Viewer::set_scroll_position(
  self : Viewer,
  scroll_top? : Double,
  scroll_left? : Double,
) -> Unit {
  guard self.view_model is Some(view_model) else { return }
  let position = view_model.view_layout.position()
  let scroll_top = match scroll_top {
    Some(value) => value
    None => position.scroll_top
  }
  let scroll_left = match scroll_left {
    Some(value) => value
    None => position.scroll_left
  }
  self.apply_scroll_change(
    view_model.view_layout.scroll_to(scroll_top~, scroll_left~),
  )
}

///|
/// Scrolls by a line-count delta using the configured line height — the
/// keyboard arrow-scroll step.
fn Viewer::scroll_by_lines(self : Viewer, lines : Int) -> Unit {
  guard self.view_model is Some(view_model) else { return }
  self.apply_scroll_change(
    view_model.view_layout.scroll_by(
      delta_top=(lines * self.font_info.line_height).to_double(),
    ),
  )
}

///|
/// Scrolls by a viewport-height page delta — the PageUp/PageDown step.
fn Viewer::scroll_by_pages(self : Viewer, pages : Int) -> Unit {
  guard self.view_model is Some(view_model) else { return }
  self.apply_scroll_change(
    view_model.view_layout.scroll_by(
      delta_top=pages.to_double() * view_model.view_layout.dimensions().height,
    ),
  )
}

///|
/// Scrolls to the top of the document — the Home key.
fn Viewer::scroll_home(self : Viewer) -> Unit {
  guard self.view_model is Some(view_model) else { return }
  self.apply_scroll_change(view_model.view_layout.scroll_to(scroll_top=0.0))
}

///|
/// Scrolls to the bottom of the document — the End key.
fn Viewer::scroll_end(self : Viewer) -> Unit {
  guard self.view_model is Some(view_model) else { return }
  let dimensions = view_model.view_layout.dimensions()
  self.apply_scroll_change(
    view_model.view_layout.scroll_to(scroll_top=dimensions.scroll_height),
  )
}

///|
fn Viewer::clear_current_model(self : Viewer) -> Unit {
  match self.model_decorations_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  self.model_decorations_subscription = None
  match self.model_tokens_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  self.model_tokens_subscription = None
  match self.model_will_dispose_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  self.model_will_dispose_subscription = None
  match self.content_hover_controller() {
    Some(hc) => hc.reset_model_state()
    None => ()
  }
  match self.agent_feedback_input_contribution() {
    Some(ic) => ic.reset_model_state()
    None => ()
  }
  match self.agent_feedback_widget_contribution() {
    Some(wc) => wc.reset_model_state()
    None => ()
  }
  self.clear_agent_feedback_widgets() |> ignore
  self.view_model = None
  self.rendered_window = None
  self.text_model = None
  match self.inlay_hints_controller() {
    Some(controller) => controller.reset_model_state()
    None => ()
  }
  self.view_zones = []
  self.horizontal_reveal_request = None
  self.cancel_mouse_selection()
  match self.content_hover_controller() {
    Some(hc) => {
      hc.hover = @hover.HoverController::empty()
      hc.hover_keep_open = false
      hc.hover_ignore_mouse_events = false
      hc.cancel_react()
    }
    None => ()
  }
  self.sync_content_hover_widget()
  self.schedule_render()
}

///|
fn Viewer::apply_scroll_change(
  self : Viewer,
  change : @view_layout.ScrollChange?,
) -> Unit {
  match change {
    Some(scroll_change) => {
      self.cancel_horizontal_reveal_on_scroll(scroll_change)
      self.on_editor_scroll_changed(scroll_change)
      match self.view {
        Some(view) => view.editor_scrollbar.scrollable().reveal_for_scroll()
        None => ()
      }
      self.scroll_dirty = true
      self.schedule_render()
    }
    None => ()
  }
}
