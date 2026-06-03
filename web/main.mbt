///|
fn main {
  @dom.register_render_callback(render_current_document)
  @dom.register_load_callback(uri => {
    @js_async.Promise::from_async(() => load_source_document(uri))
  })
  @dom.register_watch_callback(watch_source_document)
}

///|
async fn load_source_document(uri_value : String) -> String {
  let provider = @dom.browser_file_system_provider()
  let result = match @workspace.DocumentUri::parse(uri_value) {
    ParsedDocumentUri(uri) => @workspace.read_source_document(provider, uri)
    DocumentUriError(_) =>
      SourceDocumentLoadError(
        FileSystemProviderError(InvalidUri, "Invalid document URI " + uri_value),
      )
  }
  result.to_json()
}

///|
fn watch_source_document(
  uri_value : String,
  emit : (String) -> Unit,
) -> @dom.HostDisposable {
  match @workspace.DocumentUri::parse(uri_value) {
    ParsedDocumentUri(uri) => {
      let provider = @dom.browser_file_system_provider()
      let watch = @workspace.watch_file(provider, uri, changes => {
        emit(@workspace.FileChange::array_to_json(changes))
      })
      @dom.provider_disposable(() => watch.dispose())
    }
    DocumentUriError(_) => @dom.provider_disposable(() => ())
  }
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
