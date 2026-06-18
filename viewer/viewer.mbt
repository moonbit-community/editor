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
  priv did_open_document : @base_common.Emitter[@workspace.DocumentSnapshot]
  priv did_build_frame : @base_common.Emitter[ViewerFrameBuiltEvent]
  priv did_render_document : @base_common.Emitter[ViewerDocumentRenderedEvent]
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
  priv mut source_document : @workspace.DocumentSnapshot?
  priv mut text_model : @model.TextModel?
  priv mut provider_result : @language.ProviderResult
  priv mut folding_ranges : Array[@language.FoldingRange]
  priv mut folded_ranges : Array[@language.FoldingRange]
  priv mut inlay_hints : Array[@language.InlayHint]
  priv mut view_zones : Array[BrowserViewZone]
  priv mut selection : @view_model.Selection?
  priv mut selection_dragging : Bool
  priv mut hover : HoverController
  priv mut char_width : Double
  priv mut soft_wrap_column : Int
  priv mut max_line_length : Int
  priv mut render_version : Int
  priv mut view : View?
  priv mut render_pending : Bool
  priv mut measure_requested : Bool
  priv mut pending_rendered : PendingRendered?
  priv mut scroll_dirty : Bool
  /// Bumped whenever the inputs of line HTML change (new frame source or
  /// changed controller decorations); the recycler rewrites every
  /// rendered line when it differs, and only entering lines otherwise.
  priv mut content_generation : Int
  priv mut drag : ScrollbarDrag?
}

///|
priv struct PendingRendered {
  document : @workspace.DocumentSnapshot
  fresh : Bool
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
pub(all) struct CurrentDocument {
  uri : @base_common.Uri
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
  document : @workspace.DocumentSnapshot
  line_count : Int
  token_count : Int
  diagnostic_count : Int
  tokenize_ms : Double
  build_ms : Double
} derive(Debug)

///|
pub(all) struct ViewerDocumentRenderedEvent {
  document : @workspace.DocumentSnapshot
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
  {
    services,
    options,
    did_open_document: @base_common.Emitter::new(),
    did_build_frame: @base_common.Emitter::new(),
    did_render_document: @base_common.Emitter::new(),
    did_change_diagnostics: @base_common.Emitter::new(),
    did_resolve_hover: @base_common.Emitter::new(),
    did_scroll: @base_common.Emitter::new(),
    did_dispose: @base_common.Emitter::new(),
    layout: @view_layout.ViewLayout::new(line_height=editor_line_height),
    theme,
    placeholder,
    frame: None,
    view_model: None,
    frame_source: None,
    source_document: None,
    text_model: None,
    provider_result: @language.ProviderResult::empty(),
    folding_ranges: [],
    folded_ranges: [],
    inlay_hints: [],
    view_zones: [],
    selection: None,
    selection_dragging: false,
    hover: HoverController::empty(),
    char_width: 0.0,
    soft_wrap_column: 0,
    max_line_length: 0,
    render_version: 0,
    view: None,
    render_pending: false,
    measure_requested: false,
    pending_rendered: None,
    scroll_dirty: false,
    content_generation: 0,
    drag: None,
  }
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
pub fn Viewer::on_did_open_document(
  self : Viewer,
  listener : (@workspace.DocumentSnapshot) -> Unit,
) -> @base_common.Disposable {
  self.did_open_document.event(listener)
}

///|
pub fn Viewer::on_did_build_frame(
  self : Viewer,
  listener : (ViewerFrameBuiltEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_build_frame.event(listener)
}

///|
pub fn Viewer::on_did_render_document(
  self : Viewer,
  listener : (ViewerDocumentRenderedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_render_document.event(listener)
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
  let view = View::build()
  view.root.set_attribute("data-theme", self.theme)
  host.append_child(view.root.as_node())
  self.view = Some(view)
  self.hook_view_input(view)
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Renders caller-owned immutable document state. Source reads, watches,
/// reloads, and error policy belong to the host.
pub fn Viewer::set_document(
  self : Viewer,
  snapshot : @workspace.DocumentSnapshot,
  view_state? : ViewStatePolicy = PreserveAnchor,
) -> Unit {
  self.services.markers.clear_resource(snapshot.uri)
  self.provider_result = @language.ProviderResult::empty()
  self.folding_ranges = []
  self.folded_ranges = []
  self.inlay_hints = []
  if view_state.resets_controller_state() {
    self.selection = None
    self.selection_dragging = false
    self.hover = self.hover.cleared()
  }
  self.render_current_document(
    snapshot,
    fresh=true,
    request_language=true,
    view_state~,
  )
  self.did_open_document.fire(snapshot)
}

///|
/// Returns the current document identity and viewport facts.
pub fn Viewer::current_document(self : Viewer) -> CurrentDocument? {
  match self.source_document {
    Some(document) => {
      let position = self.layout.position()
      Some({
        uri: document.uri,
        revision: document.revision,
        language_id: document.language_id,
        display_name: document.display_name,
        scroll_top: position.scroll_top,
        scroll_left: position.scroll_left,
      })
    }
    None => None
  }
}

///|
/// Returns the current document identity and viewport facts.
pub fn Viewer::current(self : Viewer) -> CurrentDocument? {
  self.current_document()
}

///|
/// Returns the current scroll state in host-restorable form.
pub fn Viewer::get_view_state(self : Viewer) -> ViewerViewState {
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
/// Clears the current document and rendered frame. The host remains
/// responsible for closing files, cancelling watches, and showing source
/// errors.
pub fn Viewer::clear_document(
  self : Viewer,
  view_state? : ViewStatePolicy = Reset,
) -> Unit {
  self.clear_current_document(view_state~)
}

///|
/// Disposes viewer-owned external resources.
pub fn Viewer::dispose(self : Viewer) -> Unit {
  self.clear_document()
  self.did_dispose.fire(())
  self.did_open_document.dispose()
  self.did_build_frame.dispose()
  self.did_render_document.dispose()
  self.did_change_diagnostics.dispose()
  self.did_resolve_hover.dispose()
  self.did_scroll.dispose()
  self.did_dispose.dispose()
}

///|
/// Pushes the host's theme into the viewer. Colors cascade from the
/// host's CSS theme variables, so this only mirrors the theme onto the
/// view root as a `data-theme` attribute (for standalone styling); the
/// view keeps its DOM and scroll position.
pub fn Viewer::set_theme(self : Viewer, theme : String) -> Unit {
  self.theme = theme
  match self.view {
    Some(view) => view.root.set_attribute("data-theme", theme)
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
    self.layout.scroll_by(delta_top=(lines * editor_line_height).to_double()),
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
/// Re-requests document-level feature data for the current document.
pub fn Viewer::refresh_document_features(self : Viewer) -> Unit {
  match self.source_document {
    Some(document) => self.request_document_features(document)
    None => ()
  }
}

///|
fn Viewer::clear_current_document(
  self : Viewer,
  view_state~ : ViewStatePolicy,
) -> Unit {
  self.frame = None
  self.view_model = None
  self.frame_source = None
  self.source_document = None
  self.text_model = None
  self.provider_result = @language.ProviderResult::empty()
  self.folding_ranges = []
  self.folded_ranges = []
  self.inlay_hints = []
  self.view_zones = []
  self.layout.set_view_zones([]) |> ignore
  self.apply_view_state_policy(view_state)
  self.selection = None
  self.selection_dragging = false
  self.hover = HoverController::empty()
  self.schedule_render()
}

///|
/// Re-renders the current document with updated feature data.
fn Viewer::render_feature_update(self : Viewer) -> Unit {
  match self.source_document {
    Some(document) =>
      self.render_current_document(
        document,
        fresh=false,
        request_language=false,
      )
    None => ()
  }
}

///|
fn Viewer::apply_scroll_change(
  self : Viewer,
  change : @view_layout.ScrollChange?,
) -> Unit {
  match change {
    Some(_) => {
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
