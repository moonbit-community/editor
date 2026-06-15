///|
/// Workbench-side language client: implements the `@language` provider
/// traits over the live protocol socket through `protocol_request`. The
/// workbench registers it with the viewer's language features service at
/// startup.
priv struct RemoteLanguageClient {
  log_service : @log.LogService
}

///|
fn register_remote_language_providers(
  services : @browser.ViewerServices,
) -> Unit {
  let client = RemoteLanguageClient::{ log_service: services.log_service }
  services.language_features.register_hover_provider(client)
  services.language_features.register_diagnostics_provider(client)
  services.language_features.register_document_symbol_provider(client)
  services.language_features.register_semantic_tokens_provider(client)
}

///|
fn RemoteLanguageClient::emit_remote_error(
  self : RemoteLanguageClient,
  operation : String,
  document : @workspace.SourceDocument,
  packet : @remote_protocol.ServerPacket,
) -> Unit {
  match packet {
    RemoteError(error) =>
      self.log_service.error(
        "language.protocol",
        "remote protocol provider error",
        details=[
          ("operation", operation),
          ("document", document.uri.to_string()),
          ("version", document.version.to_string()),
          ("code", error.code.label()),
          ("providerCode", error.provider_code),
          ("message", error.message),
          ("requestId", error.request_id),
        ],
      )
    _ => ()
  }
}

///|
impl @language.HoverProvider for RemoteLanguageClient with fn hover_at(
  self,
  document,
  offset,
) {
  let response = protocol_request("hover", id => {
    Hover({ id, uri: document.uri, document_version: document.version, offset })
  })
  match response {
    HoverResult(payload) => payload.hover
    packet => {
      self.emit_remote_error("hover", document, packet)
      None
    }
  }
}

///|
impl @language.DiagnosticsProvider for RemoteLanguageClient with fn diagnostics_for_document(
  self,
  document,
) {
  let response = protocol_request("diagnostics", id => {
    Diagnostics({ id, uri: document.uri, document_version: document.version })
  })
  match response {
    Diagnostics(payload) => payload.diagnostics
    packet => {
      self.emit_remote_error("diagnostics", document, packet)
      []
    }
  }
}

///|
impl @language.DocumentSymbolProvider for RemoteLanguageClient with fn document_symbols(
  self,
  document,
) {
  let response = protocol_request("symbols", id => {
    DocumentSymbols({
      id,
      uri: document.uri,
      document_version: document.version,
    })
  })
  match response {
    DocumentSymbolsResult(payload) => payload.symbols
    packet => {
      self.emit_remote_error("documentSymbols", document, packet)
      []
    }
  }
}

///|
impl @language.SemanticTokensProvider for RemoteLanguageClient with fn semantic_tokens_for_document(
  self,
  document,
) {
  let response = protocol_request("semantic-tokens", id => {
    SemanticTokens({ id, uri: document.uri, document_version: document.version })
  })
  match response {
    SemanticTokensResult(payload) => payload.semantic_tokens
    packet => {
      self.emit_remote_error("semanticTokens", document, packet)
      []
    }
  }
}
