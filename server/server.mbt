///|
pub(all) enum RemotePathResult {
  ParsedRemotePath(@workspace.SourcePath)
  RemotePathError(@remote_protocol.ProtocolError)
} derive(Debug)

///|
pub(all) enum ServerHostReadResult {
  ServerHostReadOk(@workspace.FileContent)
  ServerHostReadError(@workspace.FileSystemProviderErrorCode, String)
} derive(Debug)

///|
pub struct ServerWatch {
  priv dispose : () -> Unit
}

///|
pub(open) trait ServerHost {
  fn read_text_file(Self, String, @workspace.SourcePath) -> ServerHostReadResult
  fn watch_text_file(
    Self,
    String,
    @workspace.SourcePath,
    (@workspace.FileChangeType) -> Unit,
  ) -> ServerWatch
  fn request_lsp(Self, String) -> String
  fn notify_lsp(Self, String) -> Unit
}

///|
pub struct RemoteServer {
  priv workspace_root : String
  priv host : &ServerHost
  priv documents : Map[String, @workspace.SourceDocument]
  priv watches : Map[String, ServerWatch]
}

///|
pub fn ServerWatch::ServerWatch(dispose : () -> Unit) -> ServerWatch {
  { dispose, }
}

///|
pub fn ServerWatch::dispose(self : ServerWatch) -> Unit {
  (self.dispose)()
}

///|
pub fn RemoteServer::RemoteServer(
  workspace_root : String,
  host : &ServerHost,
) -> RemoteServer {
  {
    workspace_root: normalize_workspace_root(workspace_root),
    host,
    documents: Map::default(),
    watches: Map::default(),
  }
}

///|
pub fn remote_document_uri(raw_path : String) -> @workspace.DocumentUri? {
  match @workspace.SourcePath::normalize_root_relative_path(raw_path) {
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
pub fn resolve_remote_document_uri(
  uri : @workspace.DocumentUri,
  request_id? : String = "",
) -> RemotePathResult {
  let raw = uri.to_string()
  let prefix = "readonly-remote://workspace/"
  if !raw.has_prefix(prefix) {
    return RemotePathError(
      ProtocolError(
        ProtocolInvalidUri,
        "Remote URI must use readonly-remote://workspace/.",
        request_id~,
      ),
    )
  }
  match
    @workspace.SourcePath::normalize_root_relative_path(
      raw[prefix.length():].to_owned(),
    ) {
    ParsedSourcePath(path) => ParsedRemotePath(path)
    SourcePathError(error) =>
      RemotePathError(
        ProtocolError(
          ProtocolInvalidUri,
          "Invalid remote workspace path " + error.to_string(),
          request_id~,
        ),
      )
  }
}

///|
pub fn RemoteServer::handle_client_packet(
  self : RemoteServer,
  packet : @remote_protocol.ClientPacket,
  emit : (@remote_protocol.ServerPacket) -> Unit,
) -> Array[@remote_protocol.ServerPacket] {
  match packet {
    OpenDocument(request) => [self.open_document(request)]
    WatchDocument(request) => [self.watch_document(request, emit)]
    CloseDocument(request) => {
      self.close_document(request)
      []
    }
    Hover(request) => [self.hover(request)]
    Definition(request) => [self.definition(request)]
    Lsp(lsp_packet) => [self.route_lsp(lsp_packet)]
  }
}

///|
pub fn RemoteServer::open_document(
  self : RemoteServer,
  request : @remote_protocol.DocumentRequest,
) -> @remote_protocol.ServerPacket {
  match self.read_remote_document(request.id, request.uri) {
    SourceDocumentLoaded(document) => {
      self.documents.set(request.uri.to_string(), document)
      DocumentLoaded({ id: request.id, document })
    }
    SourceDocumentLoadError(error) =>
      RemoteError(
        @remote_protocol.ProtocolError::from_file_system_error(
          error,
          request_id=request.id,
        ),
      )
  }
}

///|
pub fn RemoteServer::watch_document(
  self : RemoteServer,
  request : @remote_protocol.DocumentRequest,
  emit : (@remote_protocol.ServerPacket) -> Unit,
) -> @remote_protocol.ServerPacket {
  match resolve_remote_document_uri(request.uri, request_id=request.id) {
    ParsedRemotePath(path) => {
      let key = request.uri.to_string()
      match self.watches.get(key) {
        Some(existing) => existing.dispose()
        None => ()
      }
      let watch = self.host.watch_text_file(self.workspace_root, path, change_type => {
        self.handle_watch_event(request.id, request.uri, change_type, emit)
      })
      self.watches.set(key, watch)
      self.open_document(request)
    }
    RemotePathError(error) => RemoteError(error)
  }
}

///|
pub fn RemoteServer::close_document(
  self : RemoteServer,
  request : @remote_protocol.DocumentRequest,
) -> Unit {
  let key = request.uri.to_string()
  match self.watches.get(key) {
    Some(watch) => {
      watch.dispose()
      self.watches.remove(key)
    }
    None => ()
  }
  self.documents.remove(key)
}

///|
pub fn RemoteServer::hover(
  self : RemoteServer,
  request : @remote_protocol.DocumentPositionRequest,
) -> @remote_protocol.ServerPacket {
  match
    self.cached_document(request.uri, request.document_version, request.id) {
    Some(document) => {
      let providers = @language.demo_providers(document.snapshot())
      HoverResult({
        id: request.id,
        uri: request.uri,
        version: document.version,
        hover: providers.hover_at(request.offset),
      })
    }
    None => self.missing_cached_document_error(request.id)
  }
}

///|
pub fn RemoteServer::definition(
  self : RemoteServer,
  request : @remote_protocol.DocumentPositionRequest,
) -> @remote_protocol.ServerPacket {
  match
    self.cached_document(request.uri, request.document_version, request.id) {
    Some(document) => {
      let providers = @language.demo_providers(document.snapshot())
      DefinitionResult({
        id: request.id,
        uri: request.uri,
        version: document.version,
        location: definition_at(providers, request.offset),
      })
    }
    None => self.missing_cached_document_error(request.id)
  }
}

///|
pub fn RemoteServer::route_lsp(
  self : RemoteServer,
  packet : @remote_protocol.LspProtocolPacket,
) -> @remote_protocol.ServerPacket {
  LspResult({ id: packet.id, message: self.host.request_lsp(packet.message) })
}

///|
fn RemoteServer::read_remote_document(
  self : RemoteServer,
  request_id : String,
  uri : @workspace.DocumentUri,
) -> @workspace.SourceDocumentLoadResult {
  match resolve_remote_document_uri(uri, request_id~) {
    ParsedRemotePath(path) =>
      match self.host.read_text_file(self.workspace_root, path) {
        ServerHostReadOk(content) =>
          SourceDocumentLoaded(
            @workspace.SourceDocument::from_file_content(uri, content),
          )
        ServerHostReadError(code, message) =>
          SourceDocumentLoadError(FileSystemProviderError(code, message, uri~))
      }
    RemotePathError(error) =>
      SourceDocumentLoadError(
        FileSystemProviderError(InvalidUri, error.message, uri~),
      )
  }
}

///|
fn RemoteServer::handle_watch_event(
  self : RemoteServer,
  request_id : String,
  uri : @workspace.DocumentUri,
  change_type : @workspace.FileChangeType,
  emit : (@remote_protocol.ServerPacket) -> Unit,
) -> Unit {
  match change_type {
    Deleted => {
      self.documents.remove(uri.to_string())
      emit(
        RemoteError(
          ProtocolError(
            ProtocolProviderError,
            "Watched source file was deleted.",
            request_id~,
            provider_code="FileNotFound",
          ),
        ),
      )
    }
    _ =>
      match self.read_remote_document(request_id, uri) {
        SourceDocumentLoaded(document) => {
          self.documents.set(uri.to_string(), document)
          emit(DocumentChanged({ id: request_id, document }))
        }
        SourceDocumentLoadError(error) =>
          emit(
            RemoteError(
              @remote_protocol.ProtocolError::from_file_system_error(
                error,
                request_id~,
              ),
            ),
          )
      }
  }
}

///|
fn RemoteServer::cached_document(
  self : RemoteServer,
  uri : @workspace.DocumentUri,
  expected_version : Int,
  request_id : String,
) -> @workspace.SourceDocument? {
  ignore(request_id)
  match self.documents.get(uri.to_string()) {
    Some(document) =>
      if expected_version <= 0 || document.version == expected_version {
        Some(document)
      } else {
        None
      }
    None => None
  }
}

///|
fn RemoteServer::missing_cached_document_error(
  _self : RemoteServer,
  request_id : String,
) -> @remote_protocol.ServerPacket {
  RemoteError(
    ProtocolError(
      ProtocolInvalidPacket,
      "No matching loaded document is available for this request.",
      request_id~,
    ),
  )
}

///|
fn definition_at(
  providers : @language.ProviderResult,
  offset : Int,
) -> @language.Location? {
  let mut found : @language.Location? = None
  for location in providers.definitions {
    if found is None && location.range.contains_offset(offset) {
      found = Some(location)
    }
  }
  found
}

///|
fn normalize_workspace_root(root : String) -> String {
  let normalized = root.replace_all(old="\\", new="/")
  if normalized.has_suffix("/") && normalized.length() > 1 {
    normalized[0:normalized.length() - 1].to_owned()
  } else {
    normalized
  }
}
