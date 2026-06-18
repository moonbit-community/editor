///|
/// The embeddable readonly code viewer, the `vs/editor` (Monaco) role: an
/// browser `View` owning the rendered frame, the scroll and
/// layout model, the input bridge, and the feature controllers. It is
/// constructed with a `&DocumentProvider`, attached into a host-provided
/// stable element, and reports lifecycle facts through typed subscriptions;
/// it knows nothing about transports, shells, or harness event formats.
///
/// All methods are plain calls (the host wraps them in its own effect
/// system if it has one). The host must never render its own children
/// into the element passed to `attach`.
pub struct Viewer {
  priv provider : &@workspace.DocumentProvider
  priv services : ViewerServices
  priv mut options : ViewerOptions
  priv did_open_document : @base_common.Emitter[@workspace.DocumentSnapshot]
  priv did_build_frame : @base_common.Emitter[ViewerFrameBuiltEvent]
  priv did_render_document : @base_common.Emitter[ViewerDocumentRenderedEvent]
  priv did_change_diagnostics : @base_common.Emitter[
    ViewerDiagnosticsChangedEvent,
  ]
  priv did_fail_document : @base_common.Emitter[@workspace.DocumentError]
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
  priv mut open_generation : Int
  priv mut render_version : Int
  priv mut view : View?
  priv mut watch : @base_common.Disposable?
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
  RestoreOrReset
  PreserveAnchor
  Reset
} derive(Eq, Debug)

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
/// Creates a viewer instance. Call `attach` before opening documents so the
/// first render has a DOM view to measure and patch.
pub fn Viewer::Viewer(
  provider : &@workspace.DocumentProvider,
  services? : ViewerServices = ViewerServices::new(),
  options? : ViewerOptions = ViewerOptions::default(),
  theme? : String = "dark",
  placeholder? : String = "",
) -> Viewer {
  {
    provider,
    services,
    options,
    did_open_document: @base_common.Emitter::new(),
    did_build_frame: @base_common.Emitter::new(),
    did_render_document: @base_common.Emitter::new(),
    did_change_diagnostics: @base_common.Emitter::new(),
    did_fail_document: @base_common.Emitter::new(),
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
    open_generation: 0,
    render_version: 0,
    view: None,
    watch: None,
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
  provider : &@workspace.DocumentProvider,
  services? : ViewerServices = ViewerServices::new(),
  options? : ViewerOptions = ViewerOptions::default(),
  theme? : String = "dark",
  placeholder? : String = "",
) -> Viewer {
  let viewer = Viewer(provider, services~, options~, theme~, placeholder~)
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
pub fn Viewer::on_did_fail_document(
  self : Viewer,
  listener : (@workspace.DocumentError) -> Unit,
) -> @base_common.Disposable {
  self.did_fail_document.event(listener)
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
/// Owns the full document-switch choreography: closes the previous
/// document and its watch, clears the frame, subscribes the new watch,
/// and opens the document through the source.
pub fn Viewer::open(
  self : Viewer,
  uri : @base_common.Uri,
  view_state? : ViewStatePolicy = RestoreOrReset,
) -> Unit {
  self.open_generation += 1
  let generation = self.open_generation
  self.dispose_watch()
  match self.source_document {
    Some(document) => self.provider.close(document.uri)
    None => ()
  }
  self.clear_current_document(
    reset_scroll=view_state == Reset || view_state == RestoreOrReset,
  )
  self.watch = Some(
    self.provider.watch(uri, change => {
      if generation == self.open_generation {
        self.notify(change)
      }
    }),
  )
  self.read_uri(uri, generation, view_state~)
}

///|
/// Re-reads the current URI through the provider.
pub fn Viewer::reload(
  self : Viewer,
  view_state? : ViewStatePolicy = PreserveAnchor,
) -> Unit {
  match self.source_document {
    Some(document) => {
      let generation = self.open_generation
      self.read_uri(document.uri, generation, view_state~)
    }
    None => ()
  }
}

///|
/// Applies a provider or host document change notification.
pub fn Viewer::notify(
  self : Viewer,
  change : @workspace.DocumentChange,
  view_state? : ViewStatePolicy = PreserveAnchor,
) -> Unit {
  match change {
    DocumentInvalidated(uri~, ..) =>
      if self.is_current_uri(uri) {
        self.reload(view_state~)
      }
    DocumentUpdated(snapshot) =>
      if self.is_current_uri(snapshot.uri) {
        self.show(snapshot, view_state~)
      }
    DocumentDeleted(uri) =>
      if self.is_current_uri(uri) {
        self.document_failed(
          DocumentError(FileNotFound, "Document was deleted.", uri~),
        )
      }
    DocumentChangeFailed(uri~, error~) =>
      if self.is_current_uri(uri) {
        self.document_failed(error)
      }
  }
}

///|
/// Shows an already-loaded snapshot.
pub fn Viewer::show(
  self : Viewer,
  snapshot : @workspace.DocumentSnapshot,
  view_state? : ViewStatePolicy = PreserveAnchor,
) -> Unit {
  self.services.markers.clear_resource(snapshot.uri)
  self.provider_result = @language.ProviderResult::empty()
  self.folding_ranges = []
  self.folded_ranges = []
  self.inlay_hints = []
  if view_state == Reset || view_state == RestoreOrReset {
    self.selection = None
    self.selection_dragging = false
    self.hover = self.hover.cleared()
  }
  self.render_current_document(
    snapshot,
    fresh=true,
    request_language=true,
    reset_view_state=view_state == Reset || view_state == RestoreOrReset,
  )
  self.did_open_document.fire(snapshot)
}

///|
/// Returns the current document identity and viewport facts.
pub fn Viewer::current(self : Viewer) -> CurrentDocument? {
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
/// Closes the current document and clears the rendered frame.
pub fn Viewer::close(self : Viewer) -> Unit {
  self.open_generation += 1
  self.dispose_watch()
  match self.source_document {
    Some(document) => self.provider.close(document.uri)
    None => ()
  }
  self.clear_current_document(reset_scroll=true)
}

///|
/// Disposes viewer-owned external resources.
pub fn Viewer::dispose(self : Viewer) -> Unit {
  self.close()
  self.did_dispose.fire(())
  self.did_open_document.dispose()
  self.did_build_frame.dispose()
  self.did_render_document.dispose()
  self.did_change_diagnostics.dispose()
  self.did_fail_document.dispose()
  self.did_resolve_hover.dispose()
  self.did_scroll.dispose()
  self.did_dispose.dispose()
}

///|
fn Viewer::read_uri(
  self : Viewer,
  uri : @base_common.Uri,
  generation : Int,
  view_state~ : ViewStatePolicy,
) -> Unit {
  let provider = self.provider
  @js.async_run(() => {
    let result = provider.read(uri) catch {
      _ =>
        DocumentReadFailed(
          DocumentError(Unavailable, "Document open failed.", uri~),
        )
    }
    if generation == self.open_generation {
      self.document_resolved(result, view_state~)
    }
  })
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
fn Viewer::document_resolved(
  self : Viewer,
  result : @workspace.DocumentReadResult,
  view_state~ : ViewStatePolicy,
) -> Unit {
  match result {
    DocumentLoaded(document) => self.show(document, view_state~)
    DocumentNotFound(uri) =>
      self.document_failed(
        DocumentError(FileNotFound, "Document not found.", uri~),
      )
    DocumentReadFailed(error) => self.document_failed(error)
  }
}

///|
fn Viewer::document_failed(
  self : Viewer,
  error : @workspace.DocumentError,
) -> Unit {
  self.clear_current_document(reset_scroll=false)
  self.did_fail_document.fire(error)
  self.schedule_render()
}

///|
fn Viewer::clear_current_document(self : Viewer, reset_scroll~ : Bool) -> Unit {
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
  if reset_scroll {
    self.apply_scroll_change(
      self.layout.scroll_to(scroll_top=0.0, scroll_left=0.0),
    )
  }
  self.selection = None
  self.selection_dragging = false
  self.hover = HoverController::empty()
  self.schedule_render()
}

///|
fn Viewer::is_current_uri(self : Viewer, uri : @base_common.Uri) -> Bool {
  match self.source_document {
    Some(document) => document.uri.to_string() == uri.to_string()
    None => false
  }
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
fn Viewer::dispose_watch(self : Viewer) -> Unit {
  match self.watch {
    Some(watch) => watch.dispose()
    None => ()
  }
  self.watch = None
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
