///|
fn main {
  @browser.register_render_callback(() => {
    @js_async.Promise::from_async(() => render_current_document())
  })
  lsp_client().set_diagnostics_listener(
    Some((_uri, _version) => @browser.queue_render()),
  )
  @browser.register_load_callback(uri => {
    @js_async.Promise::from_async(() => load_source_document(uri))
  })
  @browser.register_watch_callback(watch_source_document)
  @browser.register_hover_callback((offset, version) => {
    @js_async.Promise::from_async(() => hover_current_document(offset, version))
  })
  @browser.register_definition_callback((offset, version) => {
    @js_async.Promise::from_async(() => {
      definition_current_document(offset, version)
    })
  })
}

///|
let active_lsp_client : @language.LspClient = LspClient(
  @browser.browser_lsp_transport(),
)

///|
async fn load_source_document(uri_value : String) -> String {
  let result = match @workspace.DocumentUri::parse(uri_value) {
    ParsedDocumentUri(uri) =>
      @workspace.read_source_document(provider_for_uri(uri), uri)
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
      let provider = provider_for_uri(uri)
      let watch = @workspace.watch_file(provider, uri, changes => {
        emit(@workspace.FileChange::array_to_json(changes))
      })
      @browser.provider_disposable(() => watch.dispose())
    }
    DocumentUriError(_) => @browser.provider_disposable(() => ())
  }
}

///|
fn provider_for_uri(
  uri : @workspace.DocumentUri,
) -> &@workspace.FileSystemProvider {
  if uri.scheme() == "readonly-remote" {
    @browser.browser_remote_file_system_provider()
  } else {
    @browser.browser_file_system_provider()
  }
}

///|
async fn render_current_document() -> Unit {
  let source_document = current_source_document()
  let doc = source_document.snapshot()
  let tokens = @syntax.highlight(doc)
  let client = lsp_client()
  let providers = client.sync_document(source_document)
  emit_lsp_status(client, providers.diagnostics.length(), doc.version)
  let decorations = decorations_from_diagnostics(providers.diagnostics)
  let frame = @renderer.build_frame(
    doc,
    { start_line: 0, end_line: doc.line_count() },
    tokens,
    decorations,
    providers,
  )
  @browser.emit_render_event(
    frame,
    tokens.length(),
    providers.diagnostics.length(),
  )
  @browser.mount_frame(frame)
}

///|
async fn hover_current_document(offset : Int, expected_version : Int) -> String {
  let source_document = current_source_document()
  if source_document.version != expected_version {
    return hover_response_json(false, source_document.version, None)
  }
  let client = lsp_client()
  match client.hover_at(source_document, offset) {
    Some(hover) => {
      @browser.emit_event(
        "lsp:hover",
        "{\"ok\":true,\"version\":" + source_document.version.to_string() + "}",
      )
      hover_response_json(true, source_document.version, Some(hover))
    }
    None => {
      let error = client.last_error()
      if error != "" {
        @browser.emit_event(
          "lsp:error",
          "{\"message\":" + json_string(error) + "}",
        )
        client.clear_last_error()
      }
      hover_response_json(false, source_document.version, None)
    }
  }
}

///|
async fn definition_current_document(
  offset : Int,
  expected_version : Int,
) -> String {
  let source_document = current_source_document()
  if source_document.version != expected_version {
    return location_response_json(false, source_document.version, None)
  }
  let client = lsp_client()
  match client.definition_at(source_document, offset) {
    Some(location) => {
      @browser.emit_event(
        "lsp:definition",
        "{\"ok\":true,\"version\":" + source_document.version.to_string() + "}",
      )
      location_response_json(true, source_document.version, Some(location))
    }
    None => {
      let error = client.last_error()
      if error != "" {
        @browser.emit_event(
          "lsp:error",
          "{\"message\":" + json_string(error) + "}",
        )
        client.clear_last_error()
      }
      location_response_json(false, source_document.version, None)
    }
  }
}

///|
fn current_source_document() -> @workspace.SourceDocument {
  SourceDocument(
    current_document_uri(),
    @browser.get_display_name(),
    @browser.get_language_id_hint(),
    @browser.get_version(),
    @browser.get_revision(),
    @browser.get_source(),
  )
}

///|
fn current_document_uri() -> @workspace.DocumentUri {
  match @workspace.DocumentUri::parse(@browser.get_uri()) {
    ParsedDocumentUri(uri) => uri
    DocumentUriError(_) => @workspace.DocumentUri::memory("demo.mbt")
  }
}

///|
fn lsp_client() -> @language.LspClient {
  active_lsp_client
}

///|
fn emit_lsp_status(
  client : @language.LspClient,
  diagnostic_count : Int,
  version : Int,
) -> Unit {
  if client.is_initialized() {
    @browser.emit_event(
      "lsp:initialize",
      "{\"ok\":true,\"version\":" + version.to_string() + "}",
    )
  }
  let error = client.last_error()
  if error != "" {
    @browser.emit_event("lsp:error", "{\"message\":" + json_string(error) + "}")
    client.clear_last_error()
  }
  @browser.emit_event(
    "lsp:diagnostics",
    "{\"count\":" +
    diagnostic_count.to_string() +
    ",\"version\":" +
    version.to_string() +
    "}",
  )
}

///|
fn hover_response_json(
  ok : Bool,
  version : Int,
  hover : @language.Hover?,
) -> String {
  let mut out = "{\"ok\":" + ok.to_string()
  out = out + ",\"version\":" + version.to_string()
  match hover {
    Some(item) => out = out + ",\"hover\":" + hover_json(item)
    None => ()
  }
  out + "}"
}

///|
fn location_response_json(
  ok : Bool,
  version : Int,
  location : @language.Location?,
) -> String {
  let mut out = "{\"ok\":" + ok.to_string()
  out = out + ",\"version\":" + version.to_string()
  match location {
    Some(item) => out = out + ",\"location\":" + location_json(item)
    None => ()
  }
  out + "}"
}

///|
fn location_json(location : @language.Location) -> String {
  let mut out = "{"
  out = out + "\"uri\":" + json_string(location.uri.to_string())
  out = out + ",\"range\":{"
  out = out + "\"start\":" + location.range.start.to_string()
  out = out + ",\"end\":" + location.range.end.to_string()
  out = out + "}"
  out + "}"
}

///|
fn hover_json(hover : @language.Hover) -> String {
  let mut out = "{"
  out = out + "\"range\":{"
  out = out + "\"start\":" + hover.range.start.to_string()
  out = out + ",\"end\":" + hover.range.end.to_string()
  out = out + "}"
  out = out + ",\"contents\":" + json_string(hover.contents)
  out + "}"
}

///|
fn json_string(value : String) -> String {
  value.escape(quote=true)
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
