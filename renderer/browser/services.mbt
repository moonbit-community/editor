///|
pub(all) struct LanguageFeatureRegistry[T] {
  entries : Array[T]
}

///|
pub fn[T] LanguageFeatureRegistry::new() -> LanguageFeatureRegistry[T] {
  { entries: [] }
}

///|
pub fn[T] LanguageFeatureRegistry::register(
  self : LanguageFeatureRegistry[T],
  entry : T,
) -> Unit {
  self.entries.push(entry)
}

///|
pub(all) struct LanguageFeaturesService {
  hover_provider : LanguageFeatureRegistry[&@language.HoverProvider]
  diagnostics_provider : LanguageFeatureRegistry[&@language.DiagnosticsProvider]
  document_symbol_provider : LanguageFeatureRegistry[
    &@language.DocumentSymbolProvider,
  ]
  semantic_tokens_provider : LanguageFeatureRegistry[
    &@language.SemanticTokensProvider,
  ]
  log_service : @log.LogService
}

///|
pub fn LanguageFeaturesService::new(
  log_service? : @log.LogService = @log.LogService::new(),
) -> LanguageFeaturesService {
  {
    hover_provider: LanguageFeatureRegistry::new(),
    diagnostics_provider: LanguageFeatureRegistry::new(),
    document_symbol_provider: LanguageFeatureRegistry::new(),
    semantic_tokens_provider: LanguageFeatureRegistry::new(),
    log_service,
  }
}

///|
pub fn LanguageFeaturesService::register_hover_provider(
  self : LanguageFeaturesService,
  provider : &@language.HoverProvider,
) -> Unit {
  self.hover_provider.register(provider)
}

///|
pub fn LanguageFeaturesService::register_diagnostics_provider(
  self : LanguageFeaturesService,
  provider : &@language.DiagnosticsProvider,
) -> Unit {
  self.diagnostics_provider.register(provider)
}

///|
pub fn LanguageFeaturesService::register_document_symbol_provider(
  self : LanguageFeaturesService,
  provider : &@language.DocumentSymbolProvider,
) -> Unit {
  self.document_symbol_provider.register(provider)
}

///|
pub fn LanguageFeaturesService::register_semantic_tokens_provider(
  self : LanguageFeaturesService,
  provider : &@language.SemanticTokensProvider,
) -> Unit {
  self.semantic_tokens_provider.register(provider)
}

///|
pub async fn LanguageFeaturesService::hover_at(
  self : LanguageFeaturesService,
  document : @workspace.SourceDocument,
  offset : Int,
) -> @language.Hover? noraise {
  for index in 0..<self.hover_provider.entries.length() {
    let provider = self.hover_provider.entries[index]
    match
      (provider.hover_at(document, offset) catch {
        _ => {
          self.log_provider_failure("language.hover", document, index)
          None
        }
      }) {
      Some(hover) => return Some(hover)
      None => ()
    }
  }
  None
}

///|
pub async fn LanguageFeaturesService::diagnostics_for_document(
  self : LanguageFeaturesService,
  document : @workspace.SourceDocument,
  apply : (String, Array[@language.Diagnostic]) -> Unit,
) -> Unit noraise {
  for index in 0..<self.diagnostics_provider.entries.length() {
    let provider = self.diagnostics_provider.entries[index]
    let owner = "diagnostics:" + index.to_string()
    let diagnostics = provider.diagnostics_for_document(document) catch {
      _ => {
        self.log_provider_failure("language.diagnostics", document, index)
        []
      }
    }
    apply(owner, diagnostics)
  }
}

///|
pub async fn LanguageFeaturesService::document_symbols(
  self : LanguageFeaturesService,
  document : @workspace.SourceDocument,
) -> Array[@language.DocumentSymbol] noraise {
  let symbols : Array[@language.DocumentSymbol] = []
  for index in 0..<self.document_symbol_provider.entries.length() {
    let provider = self.document_symbol_provider.entries[index]
    let result = provider.document_symbols(document) catch {
      _ => {
        self.log_provider_failure("language.documentSymbols", document, index)
        []
      }
    }
    symbols.append(result)
  }
  symbols
}

///|
pub async fn LanguageFeaturesService::semantic_tokens_for_document(
  self : LanguageFeaturesService,
  document : @workspace.SourceDocument,
) -> Array[@language.SemanticToken] noraise {
  let tokens : Array[@language.SemanticToken] = []
  for index in 0..<self.semantic_tokens_provider.entries.length() {
    let provider = self.semantic_tokens_provider.entries[index]
    let result = provider.semantic_tokens_for_document(document) catch {
      _ => {
        self.log_provider_failure("language.semanticTokens", document, index)
        []
      }
    }
    tokens.append(result)
  }
  tokens
}

///|
fn LanguageFeaturesService::log_provider_failure(
  self : LanguageFeaturesService,
  category : String,
  document : @workspace.SourceDocument,
  index : Int,
) -> Unit {
  self.log_service.warn(category, "provider failed", details=[
    ("document", document.uri.to_string()),
    ("version", document.version.to_string()),
    ("providerIndex", index.to_string()),
  ])
}

///|
pub(all) struct HoverParticipantRegistry {
  entries : Array[&HoverParticipant]
}

///|
pub fn HoverParticipantRegistry::new() -> HoverParticipantRegistry {
  { entries: [] }
}

///|
pub fn HoverParticipantRegistry::register(
  self : HoverParticipantRegistry,
  participant : &HoverParticipant,
) -> Unit {
  self.entries.push(participant)
}

///|
pub(all) struct ViewerServices {
  language_features : LanguageFeaturesService
  markers : MarkerService
  marker_decorations : MarkerDecorationsService
  hover_participants : HoverParticipantRegistry
  log_service : @log.LogService
}

///|
pub fn ViewerServices::new(
  log_service? : @log.LogService = @log.LogService::new(),
) -> ViewerServices {
  let markers = MarkerService::new()
  let hover_participants = HoverParticipantRegistry::new()
  hover_participants.register(MarkerHoverParticipant::new())
  hover_participants.register(MarkdownHoverParticipant::new())
  {
    language_features: LanguageFeaturesService::new(log_service~),
    markers,
    marker_decorations: MarkerDecorationsService::new(markers),
    hover_participants,
    log_service,
  }
}
