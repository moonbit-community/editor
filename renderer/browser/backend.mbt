///|
pub fn browser_file_system_provider() -> &@workspace.FileSystemProvider {
  @dom.browser_file_system_provider()
}

///|
pub fn browser_remote_file_system_provider() -> &@workspace.FileSystemProvider {
  BrowserRemoteFileSystemProvider::{  }
}

///|
pub(all) struct BrowserRemoteLanguageProvider {
  priv last_error : Ref[@remote_protocol.ProtocolError?]
}

///|
pub fn browser_remote_language_provider() -> BrowserRemoteLanguageProvider {
  { last_error: Ref(None) }
}

///|
pub fn BrowserRemoteLanguageProvider::as_hover_provider(
  self : BrowserRemoteLanguageProvider,
) -> &@language.HoverProvider {
  self
}

///|
pub fn BrowserRemoteLanguageProvider::as_definition_provider(
  self : BrowserRemoteLanguageProvider,
) -> &@language.DefinitionProvider {
  self
}

///|
pub fn BrowserRemoteLanguageProvider::as_references_provider(
  self : BrowserRemoteLanguageProvider,
) -> &@language.ReferencesProvider {
  self
}

///|
pub fn BrowserRemoteLanguageProvider::as_diagnostics_provider(
  self : BrowserRemoteLanguageProvider,
) -> &@language.DiagnosticsProvider {
  self
}

///|
pub fn BrowserRemoteLanguageProvider::as_document_symbol_provider(
  self : BrowserRemoteLanguageProvider,
) -> &@language.DocumentSymbolProvider {
  self
}

///|
pub fn BrowserRemoteLanguageProvider::as_semantic_tokens_provider(
  self : BrowserRemoteLanguageProvider,
) -> &@language.SemanticTokensProvider {
  self
}

///|
pub fn BrowserRemoteLanguageProvider::last_error_message(
  self : BrowserRemoteLanguageProvider,
) -> String {
  match self.last_error.val {
    Some(error) => error.message
    None => ""
  }
}

///|
pub fn BrowserRemoteLanguageProvider::clear_last_error(
  self : BrowserRemoteLanguageProvider,
) -> Unit {
  self.last_error.val = None
}

///|
pub fn emit_event(name : String, payload : String) -> Unit {
  @dom.emit_event(name, payload)
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
impl @language.DiagnosticsProvider for BrowserRemoteLanguageProvider with fn diagnostics_for_document(
  self,
  document,
) {
  let request = @remote_protocol.ClientPacket::Diagnostics({
    id: request_id("diagnostics", document.uri),
    uri: document.uri,
    document_version: document.version,
  })
  match self.request_packet(request) {
    Some(Diagnostics(payload)) =>
      if payload_matches_document(payload.uri, payload.version, document) {
        payload.diagnostics
      } else {
        []
      }
    _ => []
  }
}

///|
impl @language.HoverProvider for BrowserRemoteLanguageProvider with fn hover_at(
  self,
  document,
  offset,
) {
  let request = @remote_protocol.Hover({
    id: request_id("hover", document.uri),
    uri: document.uri,
    document_version: document.version,
    offset,
  })
  match self.request_packet(request) {
    Some(HoverResult(payload)) =>
      if payload_matches_document(payload.uri, payload.version, document) {
        payload.hover
      } else {
        None
      }
    _ => None
  }
}

///|
impl @language.DefinitionProvider for BrowserRemoteLanguageProvider with fn definition_at(
  self,
  document,
  offset,
) {
  let request = @remote_protocol.Definition({
    id: request_id("definition", document.uri),
    uri: document.uri,
    document_version: document.version,
    offset,
  })
  match self.request_packet(request) {
    Some(DefinitionResult(payload)) =>
      if payload_matches_document(payload.uri, payload.version, document) {
        payload.location
      } else {
        None
      }
    _ => None
  }
}

///|
impl @language.ReferencesProvider for BrowserRemoteLanguageProvider with fn references_at(
  self,
  document,
  offset,
) {
  let request = @remote_protocol.References({
    id: request_id("references", document.uri),
    uri: document.uri,
    document_version: document.version,
    offset,
  })
  match self.request_packet(request) {
    Some(ReferencesResult(payload)) =>
      if payload_matches_document(payload.uri, payload.version, document) {
        let locations : Array[@language.Location] = []
        for item in payload.references {
          locations.push({ uri: item.uri, range: item.range })
        }
        locations
      } else {
        []
      }
    _ => []
  }
}

///|
impl @language.DocumentSymbolProvider for BrowserRemoteLanguageProvider with fn document_symbols(
  self,
  document,
) {
  let request = @remote_protocol.DocumentSymbols({
    id: request_id("symbols", document.uri),
    uri: document.uri,
    document_version: document.version,
  })
  match self.request_packet(request) {
    Some(DocumentSymbolsResult(payload)) =>
      if payload_matches_document(payload.uri, payload.version, document) {
        payload.symbols
      } else {
        []
      }
    _ => []
  }
}

///|
impl @language.SemanticTokensProvider for BrowserRemoteLanguageProvider with fn semantic_tokens_for_document(
  self,
  document,
) {
  let request = @remote_protocol.SemanticTokens({
    id: request_id("semantic-tokens", document.uri),
    uri: document.uri,
    document_version: document.version,
  })
  match self.request_packet(request) {
    Some(SemanticTokensResult(payload)) =>
      if payload_matches_document(payload.uri, payload.version, document) {
        payload.semantic_tokens
      } else {
        []
      }
    _ => []
  }
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
async fn BrowserRemoteLanguageProvider::request_packet(
  self : BrowserRemoteLanguageProvider,
  packet : @remote_protocol.ClientPacket,
) -> @remote_protocol.ServerPacket? {
  let response = @dom.request_remote_protocol(packet.to_json())
  match @remote_protocol.decode_server_packet(response) {
    DecodedServerPacket(RemoteError(error)) => {
      self.last_error.val = Some(error)
      None
    }
    DecodedServerPacket(packet) => {
      self.last_error.val = None
      Some(packet)
    }
    ServerPacketDecodeError(error) => {
      self.last_error.val = Some(error)
      None
    }
  }
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

///|
fn payload_matches_document(
  uri : @workspace.DocumentUri,
  version : Int,
  document : @workspace.SourceDocument,
) -> Bool {
  uri.to_string() == document.uri.to_string() &&
  (version <= 0 || version == document.version)
}
