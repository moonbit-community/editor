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
pub(all) enum ServerHostListResult {
  ServerHostListOk(Array[@remote_protocol.WorkspaceEntry])
  ServerHostListError(@workspace.FileSystemProviderErrorCode, String)
} derive(Debug)

///|
/// One resolved directory level: child stats with provider-minted URIs and
/// `children: None` (unresolved), the `IFileService.resolve` contract.
pub(all) enum ServerHostResolveResult {
  ServerHostResolveOk(Array[@workspace.WorkspaceStat])
  ServerHostResolveError(@workspace.FileSystemProviderErrorCode, String)
} derive(Debug)

///|
pub struct ServerWatch {
  priv dispose : () -> Unit
}

///|
pub(open) trait ServerHost {
  async fn list_workspace(Self, String) -> ServerHostListResult
  async fn read_directory(Self, String, String) -> ServerHostResolveResult
  async fn read_text_file(Self, String, @workspace.SourcePath) -> ServerHostReadResult
  fn watch_text_file(
    Self,
    String,
    @workspace.SourcePath,
    async (@workspace.FileChangeType) -> Unit,
    (async () -> Unit) -> Unit,
  ) -> ServerWatch
}

///|
pub struct RemoteServer {
  priv workspace_root : String
  priv host : &ServerHost
  priv hover_provider : &@language.HoverProvider
  priv definition_provider : &@language.DefinitionProvider
  priv references_provider : &@language.ReferencesProvider
  priv diagnostics_provider : &@language.DiagnosticsProvider
  priv document_symbol_provider : &@language.DocumentSymbolProvider
  priv semantic_tokens_provider : &@language.SemanticTokensProvider
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
pub fn RemoteServer::with_language_providers(
  workspace_root : String,
  host : &ServerHost,
  hover_provider : &@language.HoverProvider,
  definition_provider : &@language.DefinitionProvider,
  references_provider : &@language.ReferencesProvider,
  diagnostics_provider : &@language.DiagnosticsProvider,
  document_symbol_provider : &@language.DocumentSymbolProvider,
  semantic_tokens_provider : &@language.SemanticTokensProvider,
) -> RemoteServer {
  {
    workspace_root: normalize_workspace_root(workspace_root),
    host,
    hover_provider,
    definition_provider,
    references_provider,
    diagnostics_provider,
    document_symbol_provider,
    semantic_tokens_provider,
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
pub(all) enum RemoteDirectoryResult {
  /// Root-relative directory path ("" for the workspace root itself) plus
  /// the directory's display name.
  ParsedRemoteDirectory(String, String)
  RemoteDirectoryError(@remote_protocol.ProtocolError)
} derive(Debug)

///|
/// Resolves a directory URI to its root-relative path. Accepts the bare
/// `readonly-remote://workspace` root, which `resolve_remote_document_uri`
/// rejects because documents always carry a path.
pub fn resolve_remote_directory_uri(
  uri : @workspace.DocumentUri,
  request_id? : String = "",
) -> RemoteDirectoryResult {
  if uri.to_string() == "readonly-remote://workspace" {
    return ParsedRemoteDirectory("", "workspace")
  }
  match resolve_remote_document_uri(uri, request_id~) {
    ParsedRemotePath(path) =>
      ParsedRemoteDirectory(path.to_string(), directory_name(path.to_string()))
    RemotePathError(error) => RemoteDirectoryError(error)
  }
}

///|
fn directory_name(path : String) -> String {
  match path.rev_find("/") {
    Some(index) => path[index + 1:].to_owned()
    None => path
  }
}

///|
pub async fn RemoteServer::handle_client_packet(
  self : RemoteServer,
  packet : @remote_protocol.ClientPacket,
  emit : async (@remote_protocol.ServerPacket) -> Unit,
  spawn_watch : (async () -> Unit) -> Unit,
) -> Array[@remote_protocol.ServerPacket] {
  match packet {
    ListWorkspace(request) => [self.list_workspace(request)]
    ResolveDirectory(request) => [self.resolve_directory(request)]
    OpenDocument(request) => [self.open_document(request)]
    WatchDocument(request) => [self.watch_document(request, emit, spawn_watch)]
    CloseDocument(request) => {
      self.close_document(request)
      []
    }
    Diagnostics(request) => [self.diagnostics(request)]
    Hover(request) => [self.hover(request)]
    Definition(request) => [self.definition(request)]
    References(request) => [self.references(request)]
    DocumentSymbols(request) => [self.document_symbols(request)]
    SemanticTokens(request) => [self.semantic_tokens(request)]
  }
}

///|
pub async fn RemoteServer::list_workspace(
  self : RemoteServer,
  request : @remote_protocol.WorkspaceListRequest,
) -> @remote_protocol.ServerPacket {
  match self.host.list_workspace(self.workspace_root) {
    ServerHostListOk(entries) => WorkspaceListed({ id: request.id, entries })
    ServerHostListError(code, message) =>
      RemoteError(
        @remote_protocol.ProtocolError::from_file_system_error(
          FileSystemProviderError(code, message),
          request_id=request.id,
        ),
      )
  }
}

///|
/// Resolves one directory level: the stat for the requested URI with its
/// immediate children attached. The workspace root resolves through the
/// bare `readonly-remote://workspace` URI.
pub async fn RemoteServer::resolve_directory(
  self : RemoteServer,
  request : @remote_protocol.DocumentRequest,
) -> @remote_protocol.ServerPacket {
  match resolve_remote_directory_uri(request.uri, request_id=request.id) {
    ParsedRemoteDirectory(relative, name) =>
      match self.host.read_directory(self.workspace_root, relative) {
        ServerHostResolveOk(children) =>
          DirectoryResolved({
            id: request.id,
            stat: {
              uri: request.uri,
              name,
              kind: Directory,
              children: Some(children),
            },
          })
        ServerHostResolveError(code, message) =>
          RemoteError(
            @remote_protocol.ProtocolError::from_file_system_error(
              FileSystemProviderError(code, message, uri=request.uri),
              request_id=request.id,
            ),
          )
      }
    RemoteDirectoryError(error) => RemoteError(error)
  }
}

///|
pub async fn RemoteServer::open_document(
  self : RemoteServer,
  request : @remote_protocol.DocumentRequest,
) -> @remote_protocol.ServerPacket {
  match self.read_remote_document(request.id, request.uri) {
    SourceDocumentLoaded(document) => {
      let document = self.tracked_document(document)
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
pub async fn RemoteServer::watch_document(
  self : RemoteServer,
  request : @remote_protocol.DocumentRequest,
  emit : async (@remote_protocol.ServerPacket) -> Unit,
  spawn_watch : (async () -> Unit) -> Unit,
) -> @remote_protocol.ServerPacket {
  match resolve_remote_document_uri(request.uri, request_id=request.id) {
    ParsedRemotePath(path) => {
      let key = request.uri.to_string()
      match self.watches.get(key) {
        Some(existing) => existing.dispose()
        None => ()
      }
      let watch = self.host.watch_text_file(
        self.workspace_root,
        path,
        change_type => {
          self.handle_watch_event(request.id, request.uri, change_type, emit)
        },
        spawn_watch,
      )
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
pub fn RemoteServer::dispose_watches(self : RemoteServer) -> Unit {
  let keys : Array[String] = []
  for key, _watch in self.watches {
    keys.push(key)
  }
  for key in keys {
    match self.watches.get(key) {
      Some(watch) => watch.dispose()
      None => ()
    }
    self.watches.remove(key)
  }
}

///|
pub async fn RemoteServer::hover(
  self : RemoteServer,
  request : @remote_protocol.DocumentPositionRequest,
) -> @remote_protocol.ServerPacket {
  match
    self.cached_document(request.uri, request.document_version, request.id) {
    Some(document) =>
      HoverResult({
        id: request.id,
        uri: request.uri,
        version: document.version,
        hover: self.hover_provider.hover_at(document, request.offset),
      })
    None => self.missing_cached_document_error(request.id)
  }
}

///|
pub async fn RemoteServer::diagnostics(
  self : RemoteServer,
  request : @remote_protocol.DocumentVersionRequest,
) -> @remote_protocol.ServerPacket {
  match
    self.cached_document(request.uri, request.document_version, request.id) {
    Some(document) =>
      Diagnostics({
        id: request.id,
        uri: request.uri,
        version: document.version,
        diagnostics: self.diagnostics_provider.diagnostics_for_document(
          document,
        ),
      })
    None => self.missing_cached_document_error(request.id)
  }
}

///|
pub async fn RemoteServer::definition(
  self : RemoteServer,
  request : @remote_protocol.DocumentPositionRequest,
) -> @remote_protocol.ServerPacket {
  match
    self.cached_document(request.uri, request.document_version, request.id) {
    Some(document) =>
      DefinitionResult({
        id: request.id,
        uri: request.uri,
        version: document.version,
        location: self.definition_provider.definition_at(
          document,
          request.offset,
        ),
      })
    None => self.missing_cached_document_error(request.id)
  }
}

///|
pub async fn RemoteServer::references(
  self : RemoteServer,
  request : @remote_protocol.DocumentPositionRequest,
) -> @remote_protocol.ServerPacket {
  match
    self.cached_document(request.uri, request.document_version, request.id) {
    Some(document) => {
      let locations = self.references_provider.references_at(
        document,
        request.offset,
      )
      let references = []
      for location in locations {
        references.push(self.enrich_reference(document, location))
      }
      ReferencesResult({
        id: request.id,
        uri: request.uri,
        version: document.version,
        references,
      })
    }
    None => self.missing_cached_document_error(request.id)
  }
}

///|
/// Builds a `ReferenceItem` with one-based line/column and the text of the
/// containing line. Same-document references read the cached snapshot;
/// cross-file references read the file through the host and degrade to an
/// empty preview when the file cannot be read.
async fn RemoteServer::enrich_reference(
  self : RemoteServer,
  requested : @workspace.SourceDocument,
  location : @language.Location,
) -> @remote_protocol.ReferenceItem {
  let snapshot = if location.uri.to_string() == requested.uri.to_string() {
    Some(requested.snapshot())
  } else {
    match resolve_remote_document_uri(location.uri) {
      ParsedRemotePath(path) =>
        match self.host.read_text_file(self.workspace_root, path) {
          ServerHostReadOk(content) =>
            Some(@core.DocumentSnapshot(content.text))
          _ => None
        }
      RemotePathError(_) => None
    }
  }
  match snapshot {
    Some(snapshot) => {
      let line_index = snapshot.line_at_offset(location.range.start)
      let position = snapshot.position_at_offset(location.range.start)
      {
        uri: location.uri,
        range: location.range,
        line: position.line + 1,
        column: position.column + 1,
        line_text: snapshot.line_text(line_index),
      }
    }
    None =>
      {
        uri: location.uri,
        range: location.range,
        line: 0,
        column: 0,
        line_text: "",
      }
  }
}

///|
pub async fn RemoteServer::document_symbols(
  self : RemoteServer,
  request : @remote_protocol.DocumentVersionRequest,
) -> @remote_protocol.ServerPacket {
  match
    self.cached_document(request.uri, request.document_version, request.id) {
    Some(document) =>
      DocumentSymbolsResult({
        id: request.id,
        uri: request.uri,
        version: document.version,
        symbols: self.document_symbol_provider.document_symbols(document),
      })
    None => self.missing_cached_document_error(request.id)
  }
}

///|
pub async fn RemoteServer::semantic_tokens(
  self : RemoteServer,
  request : @remote_protocol.DocumentVersionRequest,
) -> @remote_protocol.ServerPacket {
  match
    self.cached_document(request.uri, request.document_version, request.id) {
    Some(document) =>
      SemanticTokensResult({
        id: request.id,
        uri: request.uri,
        version: document.version,
        semantic_tokens: self.semantic_tokens_provider.semantic_tokens_for_document(
          document,
        ),
      })
    None => self.missing_cached_document_error(request.id)
  }
}

///|
async fn RemoteServer::read_remote_document(
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
async fn RemoteServer::handle_watch_event(
  self : RemoteServer,
  request_id : String,
  uri : @workspace.DocumentUri,
  change_type : @workspace.FileChangeType,
  emit : async (@remote_protocol.ServerPacket) -> Unit,
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
          let document = self.tracked_document(document)
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
fn RemoteServer::tracked_document(
  self : RemoteServer,
  document : @workspace.SourceDocument,
) -> @workspace.SourceDocument {
  match self.documents.get(document.uri.to_string()) {
    Some(previous) =>
      if previous.revision == document.revision {
        previous
      } else {
        SourceDocument(
          document.uri,
          document.display_name,
          document.language_id,
          previous.version + 1,
          document.revision,
          document.text,
        )
      }
    None => document
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
fn normalize_workspace_root(root : String) -> String {
  let normalized = root.replace_all(old="\\", new="/")
  if normalized.has_suffix("/") && normalized.length() > 1 {
    normalized[0:normalized.length() - 1].to_owned()
  } else {
    normalized
  }
}
