///|
pub(all) struct NativeWorkspaceLanguageProvider {
  root : String
  provider : @server.LspLanguageProvider
}

///|
pub fn NativeWorkspaceLanguageProvider::NativeWorkspaceLanguageProvider(
  root : String,
  provider : @server.LspLanguageProvider,
) -> NativeWorkspaceLanguageProvider {
  { root: normalize_host_path(root), provider }
}

///|
pub impl @language.HoverProvider for NativeWorkspaceLanguageProvider with fn hover_at(
  self,
  document,
  offset,
) {
  match self.lsp_document(document) {
    Some(lsp_document) =>
      self.provider.as_hover_provider().hover_at(lsp_document, offset)
    None => None
  }
}

///|
pub impl @language.DefinitionProvider for NativeWorkspaceLanguageProvider with fn definition_at(
  self,
  document,
  offset,
) {
  match self.lsp_document(document) {
    Some(lsp_document) =>
      match
        self.provider
        .as_definition_provider()
        .definition_at(lsp_document, offset) {
        Some(location) => self.remote_location(location)
        None => None
      }
    None => None
  }
}

///|
pub impl @language.ReferencesProvider for NativeWorkspaceLanguageProvider with fn references_at(
  self,
  document,
  offset,
) {
  match self.lsp_document(document) {
    Some(lsp_document) => {
      let locations = self.provider
        .as_references_provider()
        .references_at(lsp_document, offset)
      let mapped = []
      for location in locations {
        match self.remote_location(location) {
          Some(remote) => mapped.push(remote)
          None => ()
        }
      }
      mapped
    }
    None => []
  }
}

///|
pub impl @language.DiagnosticsProvider for NativeWorkspaceLanguageProvider with fn diagnostics_for_document(
  self,
  document,
) {
  match self.lsp_document(document) {
    Some(lsp_document) =>
      self.provider
      .as_diagnostics_provider()
      .diagnostics_for_document(lsp_document)
    None => []
  }
}

///|
pub impl @language.DocumentSymbolProvider for NativeWorkspaceLanguageProvider with fn document_symbols(
  self,
  document,
) {
  match self.lsp_document(document) {
    Some(lsp_document) =>
      self.provider.as_document_symbol_provider().document_symbols(lsp_document)
    None => []
  }
}

///|
pub impl @language.SemanticTokensProvider for NativeWorkspaceLanguageProvider with fn semantic_tokens_for_document(
  self,
  document,
) {
  match self.lsp_document(document) {
    Some(lsp_document) =>
      self.provider
      .as_semantic_tokens_provider()
      .semantic_tokens_for_document(lsp_document)
    None => []
  }
}

///|
pub impl @language.FoldingRangeProvider for NativeWorkspaceLanguageProvider with fn folding_ranges(
  _self,
  _document,
) {
  []
}

///|
fn NativeWorkspaceLanguageProvider::lsp_document(
  self : NativeWorkspaceLanguageProvider,
  document : @workspace.SourceDocument,
) -> @workspace.SourceDocument? {
  match @server.resolve_remote_document_uri(document.uri) {
    ParsedRemotePath(path) =>
      match self.file_uri(path) {
        Some(uri) =>
          Some(
            SourceDocument(
              uri,
              document.display_name,
              document.language_id,
              document.version,
              document.revision,
              document.text,
            ),
          )
        None => None
      }
    RemotePathError(_) => None
  }
}

///|
fn NativeWorkspaceLanguageProvider::file_uri(
  self : NativeWorkspaceLanguageProvider,
  path : @workspace.SourcePath,
) -> @workspace.DocumentUri? {
  let raw = file_uri_for_host_path(self.root + "/" + path.to_string())
  match @workspace.DocumentUri::parse(raw) {
    ParsedDocumentUri(uri) => Some(uri)
    DocumentUriError(_) => None
  }
}

///|
fn NativeWorkspaceLanguageProvider::remote_location(
  self : NativeWorkspaceLanguageProvider,
  location : @language.Location,
) -> @language.Location? {
  match self.remote_uri(location.uri) {
    Some(uri) => Some({ ..location, uri, })
    None => None
  }
}

///|
fn NativeWorkspaceLanguageProvider::remote_uri(
  self : NativeWorkspaceLanguageProvider,
  uri : @workspace.DocumentUri,
) -> @workspace.DocumentUri? {
  let prefix = file_uri_for_host_path(self.root) + "/"
  let raw = uri.to_string()
  if raw.has_prefix(prefix) {
    @server.remote_document_uri(raw[prefix.length():].to_owned())
  } else {
    None
  }
}

///|
pub fn file_uri_for_host_path(path : String) -> String {
  "file://" + normalize_host_path(path)
}
