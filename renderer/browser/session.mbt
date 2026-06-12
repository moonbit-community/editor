///|
priv struct RenderedDocument {
  frame : @renderer.RenderFrame
  document : @workspace.SourceDocument
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
/// Opens and watches a workspace document through the `DocumentSource`
/// trait: the open resolves as a correlated request, the watch listener
/// dispatches every later load result back into the update loop.
fn load_workspace_document_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  uri : @workspace.DocumentUri,
) -> @rabbita.Cmd {
  @rabbita.batch([
    @cmd.custom_cmd(_ => {
      dispose_active_document_watch()
      active_document_watch.val = Some(
        document_source.watch_document(uri, result => {
          dispatch_browser_msg(DocumentSourceResolved(result))
        }),
      )
    }),
    @cmd.perform(result => emit(DocumentSourceResolved(result)), async fn() noraise {
      document_source.open_document(uri) catch {
        _ =>
          SourceDocumentLoadError(
            FileSystemProviderError(Unavailable, "Document open failed.", uri~),
          )
      }
    }),
  ])
}

///|
fn close_active_document_cmd(
  document : @workspace.SourceDocument?,
) -> @rabbita.Cmd {
  match document {
    Some(document) =>
      @cmd.custom_cmd(_ => {
        dispose_active_document_watch()
        document_source.close_document(document.uri)
      })
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
    let rendered = render_document(document, previous, providers)
    dispatch_browser_msg(DocumentRenderResolved(rendered, request_language))
  })
}

///|
/// When the latest frame build finished, so the after-paint hook can report
/// the DOM patch duration alongside the frame build duration.
let last_build_finished_at : Ref[Double] = Ref(0.0)

///|
fn render_document(
  loaded_document : @workspace.SourceDocument,
  _previous : @workspace.SourceDocument?,
  providers : @language.ProviderResult,
) -> RenderedDocument {
  let source_document = loaded_document
  @dom.set_current_document(source_document.to_json())
  let build_started = @dom.now_ms()
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
  let build_finished = @dom.now_ms()
  last_build_finished_at.val = build_finished
  emit_render_event(
    frame,
    tokens.length(),
    providers.diagnostics.length(),
    build_finished - build_started,
  )
  { frame, document: source_document }
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
