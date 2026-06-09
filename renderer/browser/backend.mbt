///|
pub fn browser_file_system_provider() -> &@workspace.FileSystemProvider {
  @dom.browser_file_system_provider()
}

///|
pub fn browser_remote_file_system_provider() -> &@workspace.FileSystemProvider {
  BrowserRemoteFileSystemProvider::{  }
}

///|
pub fn browser_lsp_transport() -> &@language.LspTransport {
  @dom.browser_lsp_transport()
}

///|
pub fn provider_disposable(dispose : () -> Unit) -> @dom.HostDisposable {
  @dom.provider_disposable(dispose)
}

///|
pub fn get_source() -> String {
  @dom.get_source()
}

///|
pub fn get_uri() -> String {
  @dom.get_uri()
}

///|
pub fn get_display_name() -> String {
  @dom.get_display_name()
}

///|
pub fn get_language_id_hint() -> String {
  @dom.get_language_id_hint()
}

///|
pub fn get_version() -> Int {
  @dom.get_version()
}

///|
pub fn get_revision() -> String {
  @dom.get_revision()
}

///|
pub fn emit_event(name : String, payload : String) -> Unit {
  @dom.emit_event(name, payload)
}

///|
pub fn queue_render() -> Unit {
  @dom.queue_render()
}

///|
pub fn mount_frame(frame : @renderer.RenderFrame) -> Unit {
  @dom.mount_render_model(frame.to_json())
}

///|
pub fn emit_render_event(
  frame : @renderer.RenderFrame,
  token_count : Int,
  diagnostic_count : Int,
) -> Unit {
  let mut payload = "{"
  payload = payload + "\"lineCount\":" + frame.line_count.to_string()
  payload = payload + ",\"tokenCount\":" + token_count.to_string()
  payload = payload + ",\"diagnosticCount\":"
  payload = payload + diagnostic_count.to_string()
  payload = payload + ",\"version\":" + frame.version.to_string()
  payload = payload + "}"
  emit_event("moonbit:render", payload)
}

///|
pub fn register_render_callback(
  callback : () -> @js_async.Promise[Unit],
) -> Unit {
  @dom.register_render_callback(callback)
}

///|
pub fn register_load_callback(
  callback : (String) -> @js_async.Promise[String],
) -> Unit {
  @dom.register_load_callback(callback)
}

///|
pub fn register_watch_callback(
  callback : (String, (String) -> Unit) -> @dom.HostDisposable,
) -> Unit {
  @dom.register_watch_callback(callback)
}

///|
pub fn register_hover_callback(
  callback : (Int, Int) -> @js_async.Promise[String],
) -> Unit {
  @dom.register_hover_callback(callback)
}

///|
pub fn register_definition_callback(
  callback : (Int, Int) -> @js_async.Promise[String],
) -> Unit {
  @dom.register_definition_callback(callback)
}

///|
priv struct BrowserRemoteFileSystemProvider {}

///|
impl @workspace.FileSystemProvider for BrowserRemoteFileSystemProvider with fn scheme(
  _self,
) {
  "readonly-remote"
}

///|
impl @workspace.FileSystemProvider for BrowserRemoteFileSystemProvider with fn read_file(
  _self,
  uri,
) {
  read_remote_file(uri)
}

///|
impl @workspace.FileSystemProvider for BrowserRemoteFileSystemProvider with fn watch(
  _self,
  uri,
  options,
  listener,
) {
  watch_remote_file(uri, options, listener)
}

///|
async fn read_remote_file(
  uri : @workspace.DocumentUri,
) -> @workspace.FileReadResult {
  let request = @remote_protocol.OpenDocument({
    id: request_id("open", uri),
    uri,
  })
  let response = @dom.request_remote_protocol(request.to_json())
  server_packet_to_read_result(uri, response)
}

///|
fn watch_remote_file(
  uri : @workspace.DocumentUri,
  _options : @workspace.WatchOptions,
  listener : (Array[@workspace.FileChange]) -> Unit,
) -> @workspace.FileWatch {
  let request = @remote_protocol.WatchDocument({
    id: request_id("watch", uri),
    uri,
  })
  let disposable = @dom.watch_remote_protocol(request.to_json(), response => {
    match @remote_protocol.decode_server_packet(response) {
      DecodedServerPacket(DocumentChanged(payload)) =>
        listener([{ uri: payload.document.uri, change_type: Changed }])
      DecodedServerPacket(RemoteError(error)) =>
        if error.provider_code == "FileNotFound" {
          listener([{ uri, change_type: Deleted }])
        } else {
          listener([{ uri, change_type: Changed }])
        }
      _ => listener([{ uri, change_type: Changed }])
    }
  })
  { dispose: () => disposable.dispose() }
}

///|
fn server_packet_to_read_result(
  uri : @workspace.DocumentUri,
  response : String,
) -> @workspace.FileReadResult {
  match @remote_protocol.decode_server_packet(response) {
    DecodedServerPacket(DocumentLoaded(payload)) =>
      FileReadOk(
        FileContent(
          payload.document.text,
          display_name=payload.document.display_name,
          language_id=payload.document.language_id,
          revision=payload.document.revision,
        ),
      )
    DecodedServerPacket(DocumentChanged(payload)) =>
      FileReadOk(
        FileContent(
          payload.document.text,
          display_name=payload.document.display_name,
          language_id=payload.document.language_id,
          revision=payload.document.revision,
        ),
      )
    DecodedServerPacket(RemoteError(error)) =>
      FileReadError(protocol_error_to_provider_error(uri, error))
    ServerPacketDecodeError(error) =>
      FileReadError(protocol_error_to_provider_error(uri, error))
    _ =>
      FileReadError(
        FileSystemProviderError(
          Unavailable,
          "Remote protocol response did not contain a document.",
          uri~,
        ),
      )
  }
}

///|
fn protocol_error_to_provider_error(
  uri : @workspace.DocumentUri,
  error : @remote_protocol.ProtocolError,
) -> @workspace.FileSystemProviderError {
  let provider_code = if error.provider_code == "" {
    "Unavailable"
  } else {
    error.provider_code
  }
  FileSystemProviderError(
    @workspace.FileSystemProviderErrorCode::from_string(provider_code),
    error.message,
    uri~,
  )
}

///|
fn request_id(prefix : String, uri : @workspace.DocumentUri) -> String {
  prefix + ":" + uri.to_string()
}
