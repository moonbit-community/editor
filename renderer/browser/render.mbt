///|
priv struct RenderedDocument {
  source : @renderer.FrameSource
  frame : @renderer.RenderFrame
  document : @workspace.SourceDocument
}

///|
fn render_document_cmd(
  notify : (ViewerNotification) -> Unit,
  emit : @rabbita.Emit[ViewerMsg],
  document : @workspace.SourceDocument,
  cached : @renderer.TokenizedDocument?,
  providers : @language.ProviderResult,
  scroll_top : Double,
  viewer_height : Double,
  request_language : Bool,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(scheduler => {
    let rendered = render_document(
      notify, document, cached, providers, scroll_top, viewer_height,
    )
    scheduler.add(emit(DocumentRenderResolved(rendered, request_language)))
  })
}

///|
/// When the latest frame build finished, so the after-paint notification
/// can report the DOM patch duration alongside the frame build duration.
let last_build_finished_at : Ref[Double] = Ref(0.0)

///|
/// Builds (or reuses) the per-version tokenized document, buckets the
/// feature data into a frame source, and emits the frame for the window
/// derived from the given scroll state. Only the tokenize step depends on
/// document size; cache hits skip it entirely.
fn render_document(
  notify : (ViewerNotification) -> Unit,
  document : @workspace.SourceDocument,
  cached : @renderer.TokenizedDocument?,
  providers : @language.ProviderResult,
  scroll_top : Double,
  viewer_height : Double,
) -> RenderedDocument {
  let tokenize_started = @dom.now_ms()
  let tokenized = match cached {
    Some(tokenized) => tokenized
    None => {
      let doc = document.snapshot()
      let tokens = match tokenizer_registry.lookup(doc.language_id) {
        Some(tokenizer) => @syntax.tokenize_document(doc, tokenizer)
        None => @syntax.highlight(doc)
      }
      @renderer.TokenizedDocument::build(doc, tokens)
    }
  }
  let tokenize_finished = @dom.now_ms()
  notify(
    ViewerDiagnosticsStatus(
      count=providers.diagnostics.length(),
      version=tokenized.snapshot.version,
    ),
  )
  let decorations = decorations_from_diagnostics(providers.diagnostics)
  let source = @renderer.FrameSource(tokenized, decorations, providers)
  let window = @renderer.visible_window(
    scroll_top,
    viewer_height,
    editor_line_height,
    tokenized.snapshot.line_count(),
    line_overscan,
  )
  let frame = @renderer.build_frame(source, {
    start_line: window.start,
    end_line: window.end,
  })
  let build_finished = @dom.now_ms()
  last_build_finished_at.val = build_finished
  notify(
    ViewerFrameBuilt(
      document,
      line_count=frame.line_count,
      token_count=tokenized.token_count,
      diagnostic_count=providers.diagnostics.length(),
      tokenize_ms=tokenize_finished - tokenize_started,
      build_ms=build_finished - tokenize_finished,
    ),
  )
  { source, frame, document }
}

///|
/// The cached tokenized document, valid only for the same document
/// identity and version (the Monaco model-version guard).
fn cached_tokenized(
  model : ViewerModel,
  document : @workspace.SourceDocument,
) -> @renderer.TokenizedDocument? {
  match (model.frame_source, model.source_document) {
    (Some(source), Some(current)) =>
      if current.uri.to_string() == document.uri.to_string() &&
        source.tokenized.snapshot.version == document.version {
        Some(source.tokenized)
      } else {
        None
      }
    _ => None
  }
}

///|
fn decorations_from_diagnostics(
  diagnostics : Array[@language.Diagnostic],
) -> @decorations.DecorationSet {
  let items = []
  for diagnostic in diagnostics {
    let class_name = match diagnostic.severity {
      Error => "diag-error"
      Warning => "diag-warning"
      Info => "diag-info"
    }
    items.push(
      @decorations.Decoration(
        diagnostic.range,
        Diagnostic,
        class_name,
        message=diagnostic.message,
      ),
    )
  }
  @decorations.DecorationSet::from_array(items)
}
