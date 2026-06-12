///|
/// Workbench-side language client: implements the `@language` provider
/// traits over the live protocol socket through `protocol_request`. The
/// workbench registers it with the viewer's provider registry at startup.
priv struct RemoteLanguageClient {}

///|
fn register_remote_language_providers() -> Unit {
  let client = RemoteLanguageClient::{  }
  @browser.register_hover_provider(client)
  @browser.register_diagnostics_provider(client)
  @browser.register_document_symbol_provider(client)
  @browser.register_semantic_tokens_provider(client)
}

///|
fn RemoteLanguageClient::emit_remote_error(
  packet : @remote_protocol.ServerPacket,
) -> Unit {
  match packet {
    RemoteError(error) =>
      emit_event("language:error", error.to_json().stringify())
    _ => ()
  }
}

///|
impl @language.HoverProvider for RemoteLanguageClient with fn hover_at(
  _self,
  document,
  offset,
) {
  let response = protocol_request("hover", id => {
    Hover({ id, uri: document.uri, document_version: document.version, offset })
  })
  match response {
    HoverResult(payload) => payload.hover
    packet => {
      RemoteLanguageClient::emit_remote_error(packet)
      None
    }
  }
}

///|
impl @language.DiagnosticsProvider for RemoteLanguageClient with fn diagnostics_for_document(
  _self,
  document,
) {
  let response = protocol_request("diagnostics", id => {
    Diagnostics({ id, uri: document.uri, document_version: document.version })
  })
  match response {
    Diagnostics(payload) => payload.diagnostics
    packet => {
      RemoteLanguageClient::emit_remote_error(packet)
      []
    }
  }
}

///|
impl @language.DocumentSymbolProvider for RemoteLanguageClient with fn document_symbols(
  _self,
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
      RemoteLanguageClient::emit_remote_error(packet)
      []
    }
  }
}

///|
impl @language.SemanticTokensProvider for RemoteLanguageClient with fn semantic_tokens_for_document(
  _self,
  document,
) {
  let response = protocol_request("semantic-tokens", id => {
    SemanticTokens({ id, uri: document.uri, document_version: document.version })
  })
  match response {
    SemanticTokensResult(payload) => payload.semantic_tokens
    packet => {
      RemoteLanguageClient::emit_remote_error(packet)
      []
    }
  }
}
