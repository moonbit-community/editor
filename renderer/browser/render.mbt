///|
priv struct RenderedDocument {
  frame : @renderer.RenderFrame
  document : @workspace.SourceDocument
}

///|
fn render_document_cmd(
  notify : (ViewerNotification) -> Unit,
  emit : @rabbita.Emit[ViewerMsg],
  document : @workspace.SourceDocument,
  previous : @workspace.SourceDocument?,
  providers : @language.ProviderResult,
  request_language : Bool,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(scheduler => {
    let rendered = render_document(notify, document, previous, providers)
    scheduler.add(emit(DocumentRenderResolved(rendered, request_language)))
  })
}

///|
/// When the latest frame build finished, so the after-paint notification
/// can report the DOM patch duration alongside the frame build duration.
let last_build_finished_at : Ref[Double] = Ref(0.0)

///|
fn render_document(
  notify : (ViewerNotification) -> Unit,
  loaded_document : @workspace.SourceDocument,
  _previous : @workspace.SourceDocument?,
  providers : @language.ProviderResult,
) -> RenderedDocument {
  let source_document = loaded_document
  let build_started = @dom.now_ms()
  let doc = source_document.snapshot()
  let tokens = match tokenizer_registry.lookup(doc.language_id) {
    Some(tokenizer) => @syntax.tokenize_document(doc, tokenizer)
    None => @syntax.highlight(doc)
  }
  notify(
    ViewerDiagnosticsStatus(
      count=providers.diagnostics.length(),
      version=doc.version,
    ),
  )
  let decorations = decorations_from_diagnostics(providers.diagnostics)
  let frame = @renderer.build_frame(
    doc,
    { start_line: 0, end_line: doc.line_count() },
    tokens,
    decorations,
    providers,
  )
  let build_finished = @dom.now_ms()
  last_build_finished_at.val = build_finished
  notify(
    ViewerFrameBuilt(
      source_document,
      line_count=frame.line_count,
      token_count=tokens.length(),
      diagnostic_count=providers.diagnostics.length(),
      build_ms=build_finished - build_started,
    ),
  )
  { frame, document: source_document }
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
