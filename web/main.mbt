///|
fn main {
  @dom.register_render_callback(render_current_document)
  render_current_document()
}

///|
fn render_current_document() -> Unit {
  let source_document = current_source_document()
  let doc = source_document.snapshot()
  let tokens = @syntax.highlight(doc)
  let providers = @language.demo_providers(doc)
  let decorations = decorations_from_diagnostics(providers.diagnostics)
  let model = @view.render(
    doc,
    { start_line: 0, end_line: doc.line_count() },
    tokens,
    decorations,
    providers,
  )
  let mut event_payload = "{"
  event_payload = event_payload +
    "\"lineCount\":" +
    doc.line_count().to_string()
  event_payload = event_payload +
    ",\"tokenCount\":" +
    tokens.length().to_string()
  event_payload = event_payload + ",\"diagnosticCount\":"
  event_payload = event_payload + providers.diagnostics.length().to_string()
  event_payload = event_payload + ",\"version\":"
  event_payload = event_payload + doc.version.to_string()
  event_payload = event_payload + "}"
  @dom.emit_event("moonbit:render", event_payload)
  @dom.mount_render_model(model.to_json())
}

///|
fn current_source_document() -> @workspace.SourceDocument {
  SourceDocument(
    current_document_uri(),
    @dom.get_display_name(),
    @dom.get_language_id_hint(),
    @dom.get_version(),
    @dom.get_revision(),
    @dom.get_source(),
  )
}

///|
fn current_document_uri() -> @workspace.DocumentUri {
  match @workspace.DocumentUri::parse(@dom.get_uri()) {
    ParsedDocumentUri(uri) => uri
    DocumentUriError(_) => @workspace.DocumentUri::memory("demo.mbt")
  }
}

///|
fn decorations_from_diagnostics(
  diagnostics : Array[@language.Diagnostic],
) -> @decorations.DecorationSet {
  let items = []
  for diagnostic in diagnostics {
    items.push(
      @decorations.Decoration(
        diagnostic.range,
        Diagnostic,
        "diag-warning",
        message=diagnostic.message,
      ),
    )
  }
  @decorations.DecorationSet::from_array(items)
}
