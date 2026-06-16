///|
/// The embeddable readonly code viewer, the `vs/editor` (Monaco) role: an
/// imperative view island owning the rendered frame, the scroll and
/// layout model, the input bridge, and the feature controllers. It is
/// constructed with a `&DocumentSource`, attached into a host-provided
/// stable element, and reports lifecycle facts through `on_notification`;
/// it knows nothing about transports, shells, or harness event formats.
///
/// All methods are plain calls (the host wraps them in its own effect
/// system if it has one). The host must never render its own children
/// into the element passed to `attach`.
pub struct Viewer {
  priv source : &@workspace.DocumentSource
  priv services : ViewerServices
  priv notify_host : (ViewerNotification) -> Unit
  priv layout : @view_layout.ViewLayout
  priv mut theme : String
  priv mut placeholder : String
  priv mut frame : @renderer.RenderFrame?
  priv mut view_model : @renderer.ViewModel?
  priv mut frame_source : @renderer.FrameSource?
  priv mut source_document : @workspace.SourceDocument?
  priv mut provider_result : @language.ProviderResult
  priv mut hover : HoverController
  priv mut char_width : Double
  priv mut max_line_length : Int
  priv mut open_generation : Int
  priv mut island : Island?
  priv mut watch : @workspace.FileWatch?
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
  document : @workspace.SourceDocument
  fresh : Bool
}

///|
/// Lifecycle facts the viewer reports to its host. The host formats and
/// emits harness events, syncs its own chrome (title, status, tree
/// reveal), and decides messaging while the viewer has no frame.
pub(all) enum ViewerNotification {
  /// A frame build started for a document version with this many
  /// provider diagnostics merged in.
  ViewerDiagnosticsStatus(count~ : Int, version~ : Int)
  /// A frame finished building (synchronous facts, before paint).
  /// `tokenize_ms` covers the per-version whole-document tokenization
  /// (zero-ish when the tokenized cache was reused); `build_ms` covers
  /// the viewport window build.
  ViewerFrameBuilt(
    @workspace.SourceDocument,
    line_count~ : Int,
    token_count~ : Int,
    diagnostic_count~ : Int,
    tokenize_ms~ : Double,
    build_ms~ : Double
  )
  /// The built frame painted. `fresh` marks a document switch or watched
  /// change (as opposed to a same-version feature-data re-render);
  /// `patch_ms` is the duration of the DOM flush that painted it.
  ViewerDocumentRendered(
    @workspace.SourceDocument,
    line_count~ : Int,
    rendered_lines~ : Int,
    diagnostics~ : Array[@language.Diagnostic],
    patch_ms~ : Double,
    fresh~ : Bool
  )
  /// Opening or watching the document failed; the viewer cleared its frame.
  ViewerDocumentFailed(@workspace.FileSystemProviderError)
  /// A hover request resolved (or resolved empty) for a document version.
  ViewerHoverResolved(ok~ : Bool, version~ : Int)
  /// The synthetic scroll position settled after a paint.
  ViewerScrolled(scroll_top~ : Double, scroll_left~ : Double)
}

///|
pub fn Viewer::Viewer(
  source : &@workspace.DocumentSource,
  on_notification~ : (ViewerNotification) -> Unit,
  services? : ViewerServices = ViewerServices::new(),
  theme? : String = "dark",
  placeholder? : String = "",
) -> Viewer {
  {
    source,
    services,
    notify_host: on_notification,
    layout: @view_layout.ViewLayout::new(line_height=editor_line_height),
    theme,
    placeholder,
    frame: None,
    view_model: None,
    frame_source: None,
    source_document: None,
    provider_result: @language.ProviderResult::empty(),
    hover: HoverController::empty(),
    char_width: 0.0,
    max_line_length: 0,
    open_generation: 0,
    island: None,
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
/// Builds the view island inside the host element and hooks its
/// listeners. The host element must stay mounted and must never receive
/// host-rendered children; the island owns its whole subtree.
pub fn Viewer::attach(self : Viewer, host : @rdom.Element) -> Unit {
  if self.island is Some(_) {
    return
  }
  let island = Island::build()
  island.root.set_attribute("data-theme", self.theme)
  host.append_child(island.root.as_node())
  self.island = Some(island)
  self.hook_island_input(island)
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Owns the full document-switch choreography: closes the previous
/// document and its watch, clears the frame, subscribes the new watch,
/// and opens the document through the source.
pub fn Viewer::open(self : Viewer, uri : @workspace.DocumentUri) -> Unit {
  self.open_generation += 1
  let generation = self.open_generation
  self.dispose_watch()
  match self.source_document {
    Some(document) => self.source.close_document(document.uri)
    None => ()
  }
  self.frame = None
  self.view_model = None
  self.frame_source = None
  self.source_document = None
  self.provider_result = @language.ProviderResult::empty()
  self.hover = HoverController::empty()
  self.schedule_render()
  self.watch = Some(
    self.source.watch_document(uri, result => {
      if generation == self.open_generation {
        self.document_resolved(result)
      }
    }),
  )
  let source = self.source
  @js.async_run(() => {
    let result = source.open_document(uri) catch {
      _ =>
        SourceDocumentLoadError(
          FileSystemProviderError(Unavailable, "Document open failed.", uri~),
        )
    }
    if generation == self.open_generation {
      self.document_resolved(result)
    }
  })
}

///|
/// Pushes the host's theme into the viewer. Colors cascade from the
/// host's CSS theme variables, so this only mirrors the theme onto the
/// island root as a `data-theme` attribute (for standalone styling); the
/// island keeps its DOM and scroll position.
pub fn Viewer::set_theme(self : Viewer, theme : String) -> Unit {
  self.theme = theme
  match self.island {
    Some(island) => island.root.set_attribute("data-theme", theme)
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
/// input arrive through the island's own listeners.
pub fn Viewer::scroll_to(self : Viewer, scroll_top : Double) -> Unit {
  self.apply_scroll_change(self.layout.scroll_to(scroll_top~))
}

///|
pub fn Viewer::scroll_to_position(
  self : Viewer,
  scroll_top : Double,
  scroll_left : Double,
) -> Unit {
  self.apply_scroll_change(self.layout.scroll_to(scroll_top~, scroll_left~))
}

///|
pub fn Viewer::scroll_by_lines(self : Viewer, lines : Int) -> Unit {
  self.apply_scroll_change(
    self.layout.scroll_by(delta_top=(lines * editor_line_height).to_double()),
  )
}

///|
pub fn Viewer::scroll_by_pages(self : Viewer, pages : Int) -> Unit {
  self.apply_scroll_change(
    self.layout.scroll_by(
      delta_top=pages.to_double() * self.layout.dimensions().height,
    ),
  )
}

///|
pub fn Viewer::scroll_home(self : Viewer) -> Unit {
  self.apply_scroll_change(self.layout.scroll_to(scroll_top=0.0))
}

///|
pub fn Viewer::scroll_end(self : Viewer) -> Unit {
  let dimensions = self.layout.dimensions()
  self.apply_scroll_change(
    self.layout.scroll_to(scroll_top=dimensions.scroll_height),
  )
}

///|
/// Push APIs for unsolicited feature data (for example server-initiated
/// diagnostics pushes routed by the host).
pub fn Viewer::push_diagnostics(
  self : Viewer,
  diagnostics : Array[@language.Diagnostic],
) -> Unit {
  match self.source_document {
    Some(document) => {
      self.services.markers.set_diagnostics("push", document.uri, diagnostics)
      self.render_feature_update()
    }
    None => ()
  }
}

///|
pub fn Viewer::push_symbols(
  self : Viewer,
  symbols : Array[@language.DocumentSymbol],
) -> Unit {
  self.provider_result = { ..self.provider_result, symbols, }
  self.render_feature_update()
}

///|
pub fn Viewer::push_semantic_tokens(
  self : Viewer,
  semantic_tokens : Array[@language.SemanticToken],
) -> Unit {
  self.provider_result = { ..self.provider_result, semantic_tokens, }
  self.render_feature_update()
}

///|
pub fn Viewer::refresh_document_features(self : Viewer) -> Unit {
  match self.source_document {
    Some(document) => self.request_document_features(document)
    None => ()
  }
}

///|
fn Viewer::document_resolved(
  self : Viewer,
  result : @workspace.SourceDocumentLoadResult,
) -> Unit {
  match result {
    SourceDocumentLoaded(document) => {
      self.services.markers.clear_resource(document.uri)
      self.provider_result = @language.ProviderResult::empty()
      self.hover = self.hover.cleared()
      self.render_current_document(document, fresh=true, request_language=true)
    }
    SourceDocumentLoadError(error) => {
      self.frame = None
      self.view_model = None
      self.frame_source = None
      self.hover = self.hover.cleared()
      (self.notify_host)(ViewerDocumentFailed(error))
      self.schedule_render()
    }
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
      match self.island {
        Some(island) => island.editor_scrollable.reveal_for_scroll()
        None => ()
      }
      self.scroll_dirty = true
      self.schedule_render()
    }
    None => ()
  }
}
