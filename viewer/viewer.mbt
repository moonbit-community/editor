///|
/// The embeddable readonly code viewer, the `vs/editor` (Monaco) role: an
/// browser `View` owning the rendered frame, the scroll and
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
  priv did_build_frame : @base_common.Emitter[ViewerFrameBuiltEvent]
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
  priv view_layout : @view_layout.ViewLayout
  priv mut frame : @view_model.RenderFrame?
  priv mut view_model : @view_model.ViewModel?
  priv mut frame_source : @view_model.FrameSource?
  priv mut text_model : @model.TextModel?
  priv mut provider_result : @language.ProviderResult
  priv mut folding_ranges : Array[@language.FoldingRange]
  priv mut folded_ranges : Array[@language.FoldingRange]
  priv mut inlay_hints : Array[@language.InlayHint]
  priv mut view_zones : Array[@view_zones.BrowserViewZone]
  priv mut cursor : @cursor.CursorsController?
  priv mut hover : @hover.HoverController
  /// Mouse-move grace state (Monaco's `_reactToEditorMouseMoveRunner`): while a
  /// hover widget is on screen, a move off the anchor is deferred by
  /// `@hover.hover_hiding_delay_ms` instead of reacting immediately, so the pointer can
  /// reach the widget. `hover_react_token` invalidates a deferred reaction that
  /// the pointer cancelled by entering the widget.
  priv mut hover_react_pending : Bool
  priv mut hover_react_token : Int
  priv mut hover_pending_target : @viewer_common.MouseTarget?
  /// Monaco `ContentHoverController` interaction state. `hover_settings` is the
  /// `editor.hover` snapshot taken at hook time; `hover_keep_open` is
  /// `shouldKeepOpenOnEditorMouseMoveOrLeave`; `hover_ignore_mouse_events`
  /// (`_ignoreMouseEvents`) suppresses every handler while a context menu is up;
  /// the last pointer client position + modifiers stand in for `_mouseMoveEvent`
  /// so `_isMouseOnContentHoverWidget` / `shouldShowHover` can be evaluated where
  /// the controller reacts (the pointer-handler seam only carries a hit target).
  priv hover_settings : @hover.HoverSettings
  priv mut hover_keep_open : Bool
  priv mut hover_ignore_mouse_events : Bool
  priv mut hover_mouse_posx : Double
  priv mut hover_mouse_posy : Double
  priv mut hover_last_modifiers : @hover.EventModifiers
  /// The last anchor token for which the public hover-resolution status fired,
  /// so it fires exactly once per anchor when the operation completes.
  priv mut hover_notified_token : Int
  /// Monaco `RenderedContentHover`'s mouse-getting-closer state (`isMouseGettingCloser`):
  /// reset whenever a new hover view is shown, so a sticky hover the pointer is
  /// approaching is kept open even off the anchor token.
  priv hover_mouse_closer : @hover.MouseCloserState
  priv mut char_width : Double
  priv mut soft_wrap_column : Int
  priv mut max_line_length : Int
  priv mut view : @view.View?
  /// The host element handed to `attach` — Monaco's `_containerDomElement`.
  priv mut container : @rdom.Element?
  priv mut render_pending : Bool
  priv mut measure_requested : Bool
  priv mut pending_rendered : PendingRendered?
  priv mut scroll_dirty : Bool
  /// Bumped whenever the inputs of line HTML change (new frame source or
  /// changed controller decorations); the recycler rewrites every
  /// rendered line when it differs, and only entering lines otherwise.
  priv mut content_generation : Int
  /// This editor's decoration `ownerId` (Monaco's per-widget editor id): the
  /// filter handed to `ViewModelDecorations` and the ownerId of the public
  /// `delta_decorations` API.
  priv editor_id : Int
  /// Bumped per `TextModel.onDidChangeDecorations` event; the render snapshot
  /// carries it, and a change dispatches `ViewDecorationsChanged` to the view
  /// parts (plan Deviation 3 — the frame-snapshot event seam).
  priv mut decorations_generation : Int
  priv mut model_decorations_subscription : @base_common.Disposable?
  /// The hover highlight's model decoration ids (Monaco's hover-owned
  /// decorations collection): rewritten by `sync_hover_decorations` whenever
  /// the hover view's highlighted range changes.
  priv mut hover_decoration_ids : Array[String]
  priv mut hover_decoration_range : @base_common.Range?
  /// Comments contrib state (`commentsController.ts` reduced; glue in
  /// `comments_host.mbt`): the DOM-free mouse/hover gates, the two
  /// owner-scoped decoration id sets (commenting ranges + thread glyphs),
  /// the open thread widgets by thread id, and the host's
  /// `line_decorations_width` before the contrib reserved the comment lane
  /// (`None` = not reserved).
  priv comments : @comments.CommentController
  priv mut comments_range_decoration_ids : Array[String]
  priv mut comments_glyph_decoration_ids : Array[String]
  priv open_comment_widgets : Map[String, @comments_browser.ReviewZoneWidget]
  priv mut comments_lane_base_width : Int?
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
  priv mut pending_horizontal_reveal : PendingHorizontalReveal?
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
priv struct PendingHorizontalReveal {
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
  selection : @view_model.Selection
  secondary_selections : Array[@view_model.Selection]
  model_version_id : Int
  old_selections : Array[@view_model.Selection]
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
pub(all) struct ViewerFrameBuiltEvent {
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
  let viewer : Viewer = {
    services,
    options,
    did_change_model: @base_common.Emitter::new(),
    did_change_cursor_position: @base_common.Emitter::new(),
    did_change_cursor_selection: @base_common.Emitter::new(),
    did_build_frame: @base_common.Emitter::new(),
    did_render_model: @base_common.Emitter::new(),
    did_resolve_hover: @base_common.Emitter::new(),
    did_scroll: @base_common.Emitter::new(),
    did_dispose: @base_common.Emitter::new(),
    did_mouse_down: @base_common.Emitter::new(),
    did_mouse_up: @base_common.Emitter::new(),
    did_mouse_move: @base_common.Emitter::new(),
    did_mouse_leave: @base_common.Emitter::new(),
    last_scroll_event: None,
    view_layout: @view_layout.ViewLayout::new(
      line_height=@core.editor_line_height,
    ),
    frame: None,
    view_model: None,
    frame_source: None,
    text_model: None,
    provider_result: @language.ProviderResult::empty(),
    folding_ranges: [],
    folded_ranges: [],
    inlay_hints: [],
    view_zones: [],
    cursor: None,
    hover: @hover.HoverController::empty(),
    hover_react_pending: false,
    hover_react_token: 0,
    hover_pending_target: None,
    hover_settings: @hover.HoverSettings::defaults(),
    hover_keep_open: false,
    hover_ignore_mouse_events: false,
    hover_mouse_posx: 0.0,
    hover_mouse_posy: 0.0,
    hover_last_modifiers: @hover.EventModifiers::none(),
    hover_notified_token: 0,
    hover_mouse_closer: @hover.MouseCloserState::new(),
    char_width: 0.0,
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
    hover_decoration_ids: [],
    hover_decoration_range: None,
    comments: @comments.CommentController::new(),
    comments_range_decoration_ids: [],
    comments_glyph_decoration_ids: [],
    open_comment_widgets: {},
    comments_lane_base_width: None,
    mouse_handler: None,
    last_mouse_buttons: 0,
    editor_has_focus: false,
    pending_horizontal_reveal: None,
  }
  // Marker decoration changes reach the render through the model's
  // decoration storage (`onDidChangeDecorations` → `ViewDecorationsChanged`);
  // this subscription only schedules the refresh without rebuilding the frame
  // (no `content_generation` bump — decoration plan Phase 3). Hosts observe
  // marker changes on `MarkerService::on_did_change_markers`.
  viewer.services.marker_decorations.on_did_change_marker_decorations(model => {
    if viewer.is_current_model(model) {
      viewer.schedule_render()
    }
  })
  |> ignore
  viewer.hook_comment_service()
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
  self.soft_wrap_column = self.options.soft_wrap_column_for_content_width(
    self.view_layout.dimensions().width,
    self.measured_char_width(),
  )
  self.rebuild_current_view_model_for_options()
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
  let view = @view.View::build()
  view.root.set_attribute("data-theme", self.options.theme)
  host.append_child(view.root.as_node())
  view.apply_squiggly_theme()
  self.view = Some(view)
  self.container = Some(host)
  self.hook_view_input(view)
  self.measure_requested = true
  self.schedule_render()
  // Threads that were expanded before the view existed can open now.
  self.sync_comments()
}

///|
/// Renders caller-owned immutable text model state — `setModel`. Source reads,
/// watches, reloads, and error policy belong to the host. `None` detaches the
/// current model and clears the rendered frame. Like Monaco, swapping the
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
  // Rotate the decoration-change subscription with the model (plan D6:
  // owners re-attach on swap). Attach before the marker service seeds the
  // model so the seeding delta is observed too.
  match self.model_decorations_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  self.hover_decoration_ids = []
  self.hover_decoration_range = None
  // Comment decoration/widget state belongs to the outgoing model; the sync
  // after the render re-applies the new resource's comment data.
  self.comments_range_decoration_ids = []
  self.comments_glyph_decoration_ids = []
  self.close_all_comment_widgets()
  self.model_decorations_subscription = Some(
    model.on_did_change_decorations(_event => {
      // Monaco: `onDidChangeDecorations` → `viewModel.decorations
      // .onModelDecorationsChanged()` (`viewModelImpl.ts`) — drop the
      // computer + viewport caches before the re-render reads them.
      match self.view_model {
        Some(view_model) =>
          view_model.decorations().on_model_decorations_changed()
        None => ()
      }
      self.decorations_generation += 1
      self.schedule_render()
    }),
  )
  self.services.marker_decorations.on_model_added(model)
  self.provider_result = @language.ProviderResult::empty()
  self.folding_ranges = []
  self.folded_ranges = []
  self.inlay_hints = []
  self.cursor = None
  self.cancel_mouse_selection()
  self.dismiss_hover()
  // Monaco's `_attachModel` starts the fresh view at the origin; callers that
  // want continuity restore a saved view state afterwards.
  self.apply_scroll_change(
    self.view_layout.scroll_to(scroll_top=0.0, scroll_left=0.0),
  )
  self.render_current_model(model, fresh=true, request_language=true)
  self.sync_comments()
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
/// Returns the current scroll state in host-restorable form.
pub fn Viewer::save_view_state(self : Viewer) -> ViewerViewState {
  let position = self.view_layout.position()
  { scroll_top: position.scroll_top, scroll_left: position.scroll_left }
}

///|
/// Restores a previously captured scroll state.
pub fn Viewer::restore_view_state(
  self : Viewer,
  state : ViewerViewState,
) -> Unit {
  self.apply_scroll_change(
    self.view_layout.scroll_to(
      scroll_top=state.scroll_top,
      scroll_left=state.scroll_left,
    ),
  )
}

///|
/// Disposes viewer-owned external resources. Like Monaco's dispose, the model
/// detaches silently (no `onDidChangeModel`).
pub fn Viewer::dispose(self : Viewer) -> Unit {
  if self.text_model is Some(_) {
    self.clear_current_model()
  }
  self.did_dispose.fire(())
  self.did_change_model.dispose()
  self.did_change_cursor_position.dispose()
  self.did_change_cursor_selection.dispose()
  self.did_build_frame.dispose()
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
  self.services.comments.dispose()
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
/// Sets the vertical synthetic scroll position — `setScrollTop`. Wheel and
/// scrollbar input arrive through the view's own listeners.
pub fn Viewer::set_scroll_top(self : Viewer, new_scroll_top : Double) -> Unit {
  self.apply_scroll_change(
    self.view_layout.scroll_to(scroll_top=new_scroll_top),
  )
}

///|
/// Sets the horizontal synthetic scroll position — `setScrollLeft`.
pub fn Viewer::set_scroll_left(self : Viewer, new_scroll_left : Double) -> Unit {
  self.apply_scroll_change(
    self.view_layout.scroll_to(
      scroll_top=self.view_layout.position().scroll_top,
      scroll_left=new_scroll_left,
    ),
  )
}

///|
/// Sets both synthetic scroll axes — `setScrollPosition` with Monaco's
/// `INewScrollPosition` semantics: an omitted axis keeps its position.
pub fn Viewer::set_scroll_position(
  self : Viewer,
  scroll_top? : Double,
  scroll_left? : Double,
) -> Unit {
  let position = self.view_layout.position()
  let scroll_top = match scroll_top {
    Some(value) => value
    None => position.scroll_top
  }
  let scroll_left = match scroll_left {
    Some(value) => value
    None => position.scroll_left
  }
  self.apply_scroll_change(
    self.view_layout.scroll_to(scroll_top~, scroll_left~),
  )
}

///|
/// Scrolls by a line-count delta using the viewer's fixed line height — the
/// keyboard arrow-scroll step.
fn Viewer::scroll_by_lines(self : Viewer, lines : Int) -> Unit {
  self.apply_scroll_change(
    self.view_layout.scroll_by(
      delta_top=(lines * @core.editor_line_height).to_double(),
    ),
  )
}

///|
/// Scrolls by a viewport-height page delta — the PageUp/PageDown step.
fn Viewer::scroll_by_pages(self : Viewer, pages : Int) -> Unit {
  self.apply_scroll_change(
    self.view_layout.scroll_by(
      delta_top=pages.to_double() * self.view_layout.dimensions().height,
    ),
  )
}

///|
/// Scrolls to the top of the document — the Home key.
fn Viewer::scroll_home(self : Viewer) -> Unit {
  self.apply_scroll_change(self.view_layout.scroll_to(scroll_top=0.0))
}

///|
/// Scrolls to the bottom of the document — the End key.
fn Viewer::scroll_end(self : Viewer) -> Unit {
  let dimensions = self.view_layout.dimensions()
  self.apply_scroll_change(
    self.view_layout.scroll_to(scroll_top=dimensions.scroll_height),
  )
}

///|
fn Viewer::clear_current_model(self : Viewer) -> Unit {
  match self.model_decorations_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  self.model_decorations_subscription = None
  self.hover_decoration_ids = []
  self.hover_decoration_range = None
  self.comments_range_decoration_ids = []
  self.comments_glyph_decoration_ids = []
  self.close_all_comment_widgets()
  self.frame = None
  self.view_model = None
  self.frame_source = None
  self.text_model = None
  self.provider_result = @language.ProviderResult::empty()
  self.folding_ranges = []
  self.folded_ranges = []
  self.inlay_hints = []
  self.view_zones = []
  self.view_layout.set_view_zones([]) |> ignore
  self.pending_horizontal_reveal = None
  self.apply_scroll_change(
    self.view_layout.scroll_to(scroll_top=0.0, scroll_left=0.0),
  )
  self.cursor = None
  self.cancel_mouse_selection()
  self.hover = @hover.HoverController::empty()
  self.hover_keep_open = false
  self.hover_ignore_mouse_events = false
  self.cancel_hover_react()
  self.schedule_render()
}

///|
/// Re-renders the current model with updated feature data.
fn Viewer::render_feature_update(self : Viewer) -> Unit {
  match self.text_model {
    Some(model) => {
      self.render_current_model(model, fresh=false, request_language=false)
      // Folding/feature changes move the view-line axis; open comment
      // widgets follow their model anchors (D8).
      self.reanchor_comment_widgets()
    }
    None => ()
  }
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
