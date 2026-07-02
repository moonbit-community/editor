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
  priv did_change_model : @base_common.Emitter[@model.TextModel]
  priv did_change_cursor_position : @base_common.Emitter[@base_common.Position]
  priv did_change_cursor_selection : @base_common.Emitter[@view_model.Selection]
  priv did_build_frame : @base_common.Emitter[ViewerFrameBuiltEvent]
  priv did_render_model : @base_common.Emitter[ViewerModelRenderedEvent]
  priv did_change_diagnostics : @base_common.Emitter[
    ViewerDiagnosticsChangedEvent,
  ]
  priv did_resolve_hover : @base_common.Emitter[ViewerHoverResolvedEvent]
  priv did_scroll : @base_common.Emitter[ViewerScrollEvent]
  priv did_dispose : @base_common.Emitter[Unit]
  priv layout : @view_layout.ViewLayout
  priv mut theme : String
  priv mut placeholder : String
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
  priv mut mouse_handler : @controller.MouseHandler?
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
pub(all) enum ViewStatePolicy {
  PreserveAnchor
  Reset
  Restore(ViewerViewState)
} derive(Debug)

///|
pub(all) struct ViewerViewState {
  scroll_top : Double
  scroll_left : Double
} derive(Debug)

///|
pub(all) struct CurrentModel {
  uri : @base_common.Uri
  version : Int
  revision : String
  language_id : String
  display_name : String
  scroll_top : Double
  scroll_left : Double
} derive(Debug)

///|
pub(all) struct ViewerDiagnosticsChangedEvent {
  count : Int
  revision : String
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
pub(all) struct ViewerScrollEvent {
  scroll_top : Double
  scroll_left : Double
} derive(Debug)

///|
/// Creates a viewer instance. Call `attach` before setting documents so the
/// first render has a DOM view to measure and patch.
pub fn Viewer::Viewer(
  services? : ViewerServices = ViewerServices::new(),
  options? : ViewerOptions = ViewerOptions::default(),
  theme? : String = "dark",
  placeholder? : String = "",
) -> Viewer {
  let viewer : Viewer = {
    services,
    options,
    did_change_model: @base_common.Emitter::new(),
    did_change_cursor_position: @base_common.Emitter::new(),
    did_change_cursor_selection: @base_common.Emitter::new(),
    did_build_frame: @base_common.Emitter::new(),
    did_render_model: @base_common.Emitter::new(),
    did_change_diagnostics: @base_common.Emitter::new(),
    did_resolve_hover: @base_common.Emitter::new(),
    did_scroll: @base_common.Emitter::new(),
    did_dispose: @base_common.Emitter::new(),
    layout: @view_layout.ViewLayout::new(line_height=@core.editor_line_height),
    theme,
    placeholder,
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
    mouse_handler: None,
    editor_has_focus: false,
    pending_horizontal_reveal: None,
  }
  // Marker decoration changes reach the render through the model's
  // decoration storage (`onDidChangeDecorations` → `ViewDecorationsChanged`);
  // this subscription only keeps the public diagnostics-count event fresh
  // without rebuilding the frame (no `content_generation` bump — decoration
  // plan Phase 3).
  viewer.services.marker_decorations.on_did_change_marker_decorations(model => {
    if viewer.is_current_model(model) {
      viewer.did_change_diagnostics.fire({
        count: viewer.services.markers
        .diagnostics_for_resource(model.uri)
        .length(),
        revision: model.revision,
      })
      viewer.schedule_render()
    }
  })
  |> ignore
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
/// Creates and attaches a viewer in one call.
pub fn Viewer::create(
  host : @rdom.Element,
  services? : ViewerServices = ViewerServices::new(),
  options? : ViewerOptions = ViewerOptions::default(),
  theme? : String = "dark",
  placeholder? : String = "",
) -> Viewer {
  let viewer = Viewer(services~, options~, theme~, placeholder~)
  viewer.attach(host)
  viewer
}

///|
pub fn Viewer::on_did_change_model(
  self : Viewer,
  listener : (@model.TextModel) -> Unit,
) -> @base_common.Disposable {
  self.did_change_model.event(listener)
}

///|
/// Fires when the primary cursor's model position changed — Monaco's
/// `onDidChangeCursorPosition` (`cew:117-118`, fired at `:1836-1845`). The
/// payload is the new position; `secondaryPositions`/`reason`/`source` are
/// dropped (no multi-cursor, no cause-distinguishing caller — see the
/// set-selection port plan's deviations).
pub fn Viewer::on_did_change_cursor_position(
  self : Viewer,
  listener : (@base_common.Position) -> Unit,
) -> @base_common.Disposable {
  self.did_change_cursor_position.event(listener)
}

///|
/// Fires when the primary cursor's model selection changed — Monaco's
/// `onDidChangeCursorSelection` (`cew:120-121`, fired at `:1846-1857`). The
/// payload is the new selection; `secondarySelections`/`oldSelections`/
/// `modelVersionId`/`reason`/`source` are dropped (no multi-cursor, no version
/// counter on the swap-wholesale model — see the set-selection port plan's
/// deviations).
pub fn Viewer::on_did_change_cursor_selection(
  self : Viewer,
  listener : (@view_model.Selection) -> Unit,
) -> @base_common.Disposable {
  self.did_change_cursor_selection.event(listener)
}

///|
pub fn Viewer::on_did_build_frame(
  self : Viewer,
  listener : (ViewerFrameBuiltEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_build_frame.event(listener)
}

///|
pub fn Viewer::on_did_render_model(
  self : Viewer,
  listener : (ViewerModelRenderedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_render_model.event(listener)
}

///|
pub fn Viewer::on_did_change_diagnostics(
  self : Viewer,
  listener : (ViewerDiagnosticsChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_change_diagnostics.event(listener)
}

///|
pub fn Viewer::on_did_resolve_hover(
  self : Viewer,
  listener : (ViewerHoverResolvedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_resolve_hover.event(listener)
}

///|
pub fn Viewer::on_did_scroll(
  self : Viewer,
  listener : (ViewerScrollEvent) -> Unit,
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
/// Applies runtime options and rebuilds the current view model when wrapping or
/// tab settings change.
pub fn Viewer::set_options(self : Viewer, options : ViewerOptions) -> Unit {
  if self.options == options {
    return
  }
  self.options = options
  self.soft_wrap_column = self.options.soft_wrap_column_for_content_width(
    self.layout.dimensions().width,
    self.measured_char_width(),
  )
  self.rebuild_current_view_model_for_options()
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Applies runtime options through the Monaco-shaped public name. `set_options`
/// remains available for existing hosts that already use it.
pub fn Viewer::update_options(self : Viewer, options : ViewerOptions) -> Unit {
  self.set_options(options)
}

///|
/// Builds the browser `View` inside the host element and hooks its
/// listeners. The host element must stay mounted and must never receive
/// host-rendered children; the view owns its whole subtree.
pub fn Viewer::attach(self : Viewer, host : @rdom.Element) -> Unit {
  if self.view is Some(_) {
    return
  }
  let view = @view.View::build()
  view.root.set_attribute("data-theme", self.theme)
  host.append_child(view.root.as_node())
  view.apply_squiggly_theme()
  self.view = Some(view)
  self.hook_view_input(view)
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Renders caller-owned immutable text model state. Source reads, watches,
/// reloads, and error policy belong to the host.
pub fn Viewer::set_model(
  self : Viewer,
  model : @model.TextModel,
  view_state? : ViewStatePolicy = PreserveAnchor,
) -> Unit {
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
  if view_state.resets_controller_state() {
    self.cursor = None
    self.cancel_mouse_selection()
    self.dismiss_hover()
  }
  self.render_current_model(
    model,
    fresh=true,
    request_language=true,
    view_state~,
  )
  self.did_change_model.fire(model)
}

///|
/// Returns the current model installed on the viewer.
pub fn Viewer::get_model(self : Viewer) -> @model.TextModel? {
  self.text_model
}

///|
/// Returns the current model identity and viewport facts.
pub fn Viewer::current_model(self : Viewer) -> CurrentModel? {
  match self.text_model {
    Some(model) => {
      let position = self.layout.position()
      Some({
        uri: model.uri,
        version: model.version,
        revision: model.revision,
        language_id: model.language_id,
        display_name: model.display_name,
        scroll_top: position.scroll_top,
        scroll_left: position.scroll_left,
      })
    }
    None => None
  }
}

///|
/// Returns the current scroll state in host-restorable form.
pub fn Viewer::save_view_state(self : Viewer) -> ViewerViewState {
  let position = self.layout.position()
  { scroll_top: position.scroll_top, scroll_left: position.scroll_left }
}

///|
/// Restores a previously captured scroll state.
pub fn Viewer::restore_view_state(
  self : Viewer,
  state : ViewerViewState,
) -> Unit {
  self.apply_scroll_change(
    self.layout.scroll_to(
      scroll_top=state.scroll_top,
      scroll_left=state.scroll_left,
    ),
  )
}

///|
/// Clears the current model and rendered frame. The host remains
/// responsible for closing files, cancelling watches, and showing source
/// errors.
pub fn Viewer::clear_model(
  self : Viewer,
  view_state? : ViewStatePolicy = Reset,
) -> Unit {
  self.clear_current_model(view_state~)
}

///|
/// Disposes viewer-owned external resources.
pub fn Viewer::dispose(self : Viewer) -> Unit {
  self.clear_model()
  self.did_dispose.fire(())
  self.did_change_model.dispose()
  self.did_change_cursor_position.dispose()
  self.did_change_cursor_selection.dispose()
  self.did_build_frame.dispose()
  self.did_render_model.dispose()
  self.did_change_diagnostics.dispose()
  self.did_resolve_hover.dispose()
  self.did_scroll.dispose()
  self.did_dispose.dispose()
  self.services.marker_decorations.dispose()
  self.services.markers.dispose()
}

///|
/// Pushes the host's theme into the viewer. Colors cascade from the
/// host's CSS theme variables, so this mirrors the theme onto the view
/// root as a `data-theme` attribute (for standalone styling) and
/// recomputes the squiggle stylesheet from the newly cascaded colors; the
/// view keeps its DOM and scroll position.
pub fn Viewer::set_theme(self : Viewer, theme : String) -> Unit {
  self.theme = theme
  match self.view {
    Some(view) => {
      view.root.set_attribute("data-theme", theme)
      view.apply_squiggly_theme()
    }
    None => ()
  }
}

///|
/// Re-measures the viewer box after a host-observed layout change.
pub fn Viewer::remeasure(self : Viewer) -> Unit {
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Pushes the message shown while the viewer has no rendered frame.
pub fn Viewer::set_placeholder(self : Viewer, message : String) -> Unit {
  if self.placeholder != message {
    self.placeholder = message
    self.schedule_render()
  }
}

///|
/// Forwards the host-captured Escape key to the feature controllers.
pub fn Viewer::escape(self : Viewer) -> Unit {
  self.dispatch_editor_event(EscapePressed)
}

///|
/// Synthetic scroll entry points: the host routes keyboard scrolling
/// (and the harness scroll control) through these; wheel and scrollbar
/// input arrive through the view's own listeners.
pub fn Viewer::scroll_to(self : Viewer, scroll_top : Double) -> Unit {
  self.apply_scroll_change(self.layout.scroll_to(scroll_top~))
}

///|
/// Scrolls to an explicit vertical and horizontal synthetic scroll position.
pub fn Viewer::scroll_to_position(
  self : Viewer,
  scroll_top : Double,
  scroll_left : Double,
) -> Unit {
  self.apply_scroll_change(self.layout.scroll_to(scroll_top~, scroll_left~))
}

///|
/// Scrolls by a line-count delta using the viewer's fixed line height.
pub fn Viewer::scroll_by_lines(self : Viewer, lines : Int) -> Unit {
  self.apply_scroll_change(
    self.layout.scroll_by(
      delta_top=(lines * @core.editor_line_height).to_double(),
    ),
  )
}

///|
/// Scrolls by a viewport-height page delta.
pub fn Viewer::scroll_by_pages(self : Viewer, pages : Int) -> Unit {
  self.apply_scroll_change(
    self.layout.scroll_by(
      delta_top=pages.to_double() * self.layout.dimensions().height,
    ),
  )
}

///|
/// Scrolls to the top of the document.
pub fn Viewer::scroll_home(self : Viewer) -> Unit {
  self.apply_scroll_change(self.layout.scroll_to(scroll_top=0.0))
}

///|
/// Scrolls to the bottom of the document.
pub fn Viewer::scroll_end(self : Viewer) -> Unit {
  let dimensions = self.layout.dimensions()
  self.apply_scroll_change(
    self.layout.scroll_to(scroll_top=dimensions.scroll_height),
  )
}

///|
/// Re-requests model-level feature data for the current model.
pub fn Viewer::refresh_model_features(self : Viewer) -> Unit {
  match self.text_model {
    Some(model) => self.request_model_features(model)
    None => ()
  }
}

///|
fn Viewer::clear_current_model(
  self : Viewer,
  view_state~ : ViewStatePolicy,
) -> Unit {
  match self.model_decorations_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  self.model_decorations_subscription = None
  self.hover_decoration_ids = []
  self.hover_decoration_range = None
  self.frame = None
  self.view_model = None
  self.frame_source = None
  self.text_model = None
  self.provider_result = @language.ProviderResult::empty()
  self.folding_ranges = []
  self.folded_ranges = []
  self.inlay_hints = []
  self.view_zones = []
  self.layout.set_view_zones([]) |> ignore
  self.pending_horizontal_reveal = None
  self.apply_view_state_policy(view_state)
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
    Some(model) =>
      self.render_current_model(model, fresh=false, request_language=false)
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

///|
fn ViewStatePolicy::resets_controller_state(self : ViewStatePolicy) -> Bool {
  match self {
    Reset | Restore(_) => true
    PreserveAnchor => false
  }
}

///|
fn Viewer::apply_view_state_policy(
  self : Viewer,
  view_state : ViewStatePolicy,
) -> Unit {
  match view_state {
    Reset =>
      self.apply_scroll_change(
        self.layout.scroll_to(scroll_top=0.0, scroll_left=0.0),
      )
    Restore(state) => self.restore_view_state(state)
    PreserveAnchor => ()
  }
}
