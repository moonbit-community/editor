///|
priv struct RenderedDocument {
  frame : @renderer.RenderFrame
  document : @workspace.SourceDocument
}

///|
priv enum DocumentRenderResult {
  DocumentRendered(RenderedDocument)
  DocumentRenderFailed(String, String, String)
}

///|
pub fn start_app() -> Unit {
  @dom.install_host_capabilities()
  mount_app()
}

///|
fn connect_protocol_cmd(emit : @rabbita.Emit[BrowserMsg]) -> @rabbita.Cmd {
  @websocket.connect(
    protocol_connection_id(),
    @dom.protocol_websocket_url(),
    on_event=event => emit(ProtocolEvent(event)),
    failed=message => emit(ProtocolSendFailed(message)),
  )
}

///|
fn send_client_packet_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  packet : @remote_protocol.ClientPacket,
) -> @rabbita.Cmd {
  @websocket.send(protocol_connection_id(), Text(packet.to_json()), failed=message => {
    emit(ProtocolSendFailed(message))
  })
}

///|
fn load_workspace_document_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  id : String,
) -> @rabbita.Cmd {
  match workspace_document_uri(id) {
    Some(uri) =>
      @rabbita.batch([
        send_client_packet_cmd(
          emit,
          OpenDocument({ id: request_id("open", uri), uri }),
        ),
        send_client_packet_cmd(
          emit,
          WatchDocument({ id: request_id("watch", uri), uri }),
        ),
      ])
    None =>
      emit(
        DocumentRenderResolved(
          DocumentRenderFailed("", "error", "Invalid workspace file selection."),
          false,
        ),
      )
  }
}

///|
fn close_active_document_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  document : @workspace.SourceDocument?,
) -> @rabbita.Cmd {
  match document {
    Some(document) =>
      send_client_packet_cmd(
        emit,
        CloseDocument({
          id: request_id("close", document.uri),
          uri: document.uri,
        }),
      )
    None => @rabbita.none
  }
}

///|
fn protocol_connection_id() -> String {
  "readonly-editor-protocol"
}

///|
fn render_document_cmd(
  document : @workspace.SourceDocument,
  previous : @workspace.SourceDocument?,
  providers : @language.ProviderResult,
  request_language : Bool,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => {
    let result = render_document(document, previous, providers)
    dispatch_browser_msg(DocumentRenderResolved(result, request_language))
  })
}

///|
fn render_document(
  loaded_document : @workspace.SourceDocument,
  _previous : @workspace.SourceDocument?,
  providers : @language.ProviderResult,
) -> DocumentRenderResult {
  let source_document = loaded_document
  @dom.set_current_document(source_document.to_json())
  let doc = source_document.snapshot()
  let tokens = @syntax.highlight(doc)
  emit_language_status(providers.diagnostics.length(), doc.version)
  let decorations = decorations_from_diagnostics(providers.diagnostics)
  let frame = @renderer.build_frame(
    doc,
    { start_line: 0, end_line: doc.line_count() },
    tokens,
    decorations,
    providers,
  )
  emit_render_event(frame, tokens.length(), providers.diagnostics.length())
  DocumentRendered({ frame, document: source_document })
}

///|
fn workspace_document_uri(id : String) -> @workspace.DocumentUri? {
  match @workspace.SourcePath::normalize_root_relative_path(id) {
    ParsedSourcePath(path) =>
      match
        @workspace.DocumentUri::parse(
          "readonly-remote://workspace/" + path.to_string(),
        ) {
        ParsedDocumentUri(uri) => Some(uri)
        DocumentUriError(_) => None
      }
    SourcePathError(_) => None
  }
}

///|
fn emit_language_status(diagnostic_count : Int, version : Int) -> Unit {
  emit_event(
    "language:diagnostics",
    "{\"count\":" +
    diagnostic_count.to_string() +
    ",\"version\":" +
    version.to_string() +
    "}",
  )
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
