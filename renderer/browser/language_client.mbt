///|
/// Browser-side language client: implements the `@language` provider traits
/// over the live protocol socket through `protocol_request`.
priv struct RemoteLanguageClient {}

///|
fn RemoteLanguageClient::emit_remote_error(
  packet : @remote_protocol.ServerPacket,
) -> Unit {
  match packet {
    RemoteError(error) => emit_event("language:error", error.to_json())
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

///|
/// Ordered providers per feature. One entry today — the remote client —
/// and the extension point for more.
priv struct ProviderRegistry {
  hover : Array[&@language.HoverProvider]
  diagnostics : Array[&@language.DiagnosticsProvider]
  symbols : Array[&@language.DocumentSymbolProvider]
  semantic_tokens : Array[&@language.SemanticTokensProvider]
}

///|
let provider_registry : ProviderRegistry = {
  let client = RemoteLanguageClient::{  }
  {
    hover: [client],
    diagnostics: [client],
    symbols: [client],
    semantic_tokens: [client],
  }
}

///|
async fn ProviderRegistry::hover_at(
  self : ProviderRegistry,
  document : @workspace.SourceDocument,
  offset : Int,
) -> @language.Hover? noraise {
  for provider in self.hover {
    match (provider.hover_at(document, offset) catch { _ => None }) {
      Some(hover) => return Some(hover)
      None => ()
    }
  }
  None
}

///|
/// Commands controllers use to resolve features through the registry; each
/// tags its result with the requesting document version so stale responses
/// are dropped at handling in addition to id correlation.
fn hover_provider_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  document : @workspace.SourceDocument?,
  offset : Int,
  token : Int,
) -> @rabbita.Cmd {
  match document {
    Some(document) => {
      let version = document.version
      @cmd.perform(result => emit(HoverResolved(version, token, result)), async fn() noraise {
        provider_registry.hover_at(document, offset)
      })
    }
    None => @rabbita.none
  }
}

///|
/// Document-level features requested after a fresh render: diagnostics,
/// symbols, and semantic tokens, each resolving independently like the
/// per-packet flow they replace.
fn language_feature_cmds(
  emit : @rabbita.Emit[BrowserMsg],
  document : @workspace.SourceDocument,
) -> @rabbita.Cmd {
  let version = document.version
  @rabbita.batch([
    @cmd.perform(result => emit(DiagnosticsResolved(version, result)), async fn() noraise {
      match provider_registry.diagnostics.get(0) {
        Some(provider) =>
          provider.diagnostics_for_document(document) catch {
            _ => []
          }
        None => []
      }
    }),
    @cmd.perform(result => emit(SymbolsResolved(version, result)), async fn() noraise {
      match provider_registry.symbols.get(0) {
        Some(provider) => provider.document_symbols(document) catch { _ => [] }
        None => []
      }
    }),
    @cmd.perform(result => emit(SemanticTokensResolved(version, result)), async fn() noraise {
      match provider_registry.semantic_tokens.get(0) {
        Some(provider) =>
          provider.semantic_tokens_for_document(document) catch {
            _ => []
          }
        None => []
      }
    }),
  ])
}
