///|
/// Workbench-side language client: implements the `@language` provider
/// traits over the live protocol socket through `protocol_request`. The
/// workbench registers it with the viewer's selected language registry at
/// startup.
priv struct RemoteLanguageClient {
  log_service : @log.LogService
}

///|
fn register_remote_language_providers(
  services : @viewer.ViewerServices,
) -> Unit {
  let client = RemoteLanguageClient::{ log_service: services.log_service }
  let selector = @language.LanguageSelector::LanguageFilter(
    LanguageFilter(scheme="readonly-remote"),
  )
  services.languages.register_hover_provider(selector, client) |> ignore
  services.languages.register_diagnostics_provider(selector, client)
  |> ignore
  services.languages.register_document_symbol_provider(selector, client)
  |> ignore
  services.languages.register_document_semantic_tokens_provider(
    selector, client,
  )
  |> ignore
  services.languages.register_folding_range_provider(selector, client)
  |> ignore
  services.languages.register_inlay_hints_provider(selector, client)
  |> ignore
}

///|
fn RemoteLanguageClient::emit_remote_error(
  self : RemoteLanguageClient,
  operation : String,
  document : @workspace.DocumentSnapshot,
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
          ("revision", document.revision),
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
impl @language.HoverProvider for RemoteLanguageClient with fn provide_hover(
  self,
  document,
  position,
  _token,
) {
  let offset = document.offset_at_position(position)
  let response = protocol_request("hover", id => {
    Hover({
      id,
      uri: document.uri,
      document_revision: document.revision,
      offset,
    })
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
impl @language.DiagnosticsProvider for RemoteLanguageClient with fn provide_diagnostics(
  self,
  document,
  _token,
) {
  let response = protocol_request("diagnostics", id => {
    Diagnostics({ id, uri: document.uri, document_revision: document.revision })
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
impl @language.DocumentSymbolProvider for RemoteLanguageClient with fn provide_document_symbols(
  self,
  document,
  _token,
) {
  let response = protocol_request("symbols", id => {
    DocumentSymbols({
      id,
      uri: document.uri,
      document_revision: document.revision,
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
impl @language.SemanticTokensProvider for RemoteLanguageClient with fn provide_document_semantic_tokens(
  self,
  document,
  _token,
) {
  let response = protocol_request("semantic-tokens", id => {
    SemanticTokens({
      id,
      uri: document.uri,
      document_revision: document.revision,
    })
  })
  match response {
    SemanticTokensResult(payload) => payload.semantic_tokens
    packet => {
      self.emit_remote_error("semanticTokens", document, packet)
      []
    }
  }
}

///|
impl @language.FoldingRangeProvider for RemoteLanguageClient with fn provide_folding_ranges(
  self,
  document,
  _token,
) {
  let response = protocol_request("folding-ranges", id => {
    FoldingRanges({
      id,
      uri: document.uri,
      document_revision: document.revision,
    })
  })
  match response {
    FoldingRangesResult(payload) => payload.folding_ranges
    packet => {
      self.emit_remote_error("foldingRanges", document, packet)
      []
    }
  }
}

///|
impl @language.InlayHintsProvider for RemoteLanguageClient with fn provide_inlay_hints(
  self,
  document,
  _range,
  _token,
) {
  let response = protocol_request("inlay-hints", id => {
    InlayHints({ id, uri: document.uri, document_revision: document.revision })
  })
  match response {
    InlayHintsResult(payload) => payload.inlay_hints
    packet => {
      self.emit_remote_error("inlayHints", document, packet)
      []
    }
  }
}
