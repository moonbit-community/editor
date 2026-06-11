///|
pub(all) struct Hover {
  range : @core.Range
  contents : String
} derive(Debug)

///|
pub(all) enum DiagnosticSeverity {
  Error
  Warning
  Info
} derive(Eq, Debug)

///|
pub(all) struct Diagnostic {
  range : @core.Range
  severity : DiagnosticSeverity
  message : String
} derive(Debug)

///|
pub(all) struct Location {
  uri : @workspace.DocumentUri
  range : @core.Range
} derive(Debug)

///|
pub(all) struct DocumentSymbol {
  name : String
  kind : String
  range : @core.Range
} derive(Debug)

///|
pub(all) struct SemanticToken {
  range : @core.Range
  token_type : String
} derive(Debug)

///|
pub(all) struct ProviderResult {
  hovers : Array[Hover]
  diagnostics : Array[Diagnostic]
  definitions : Array[Location]
  symbols : Array[DocumentSymbol]
  semantic_tokens : Array[SemanticToken]
} derive(Debug)

///|
pub(open) trait LanguageProvider {
  fn hovers(Self, @core.DocumentSnapshot) -> Array[Hover]
  fn diagnostics(Self, @core.DocumentSnapshot) -> Array[Diagnostic]
  fn definitions(Self, @core.DocumentSnapshot) -> Array[Location]
  fn symbols(Self, @core.DocumentSnapshot) -> Array[DocumentSymbol]
  fn semantic_tokens(Self, @core.DocumentSnapshot) -> Array[SemanticToken]
}

///|
pub(open) trait HoverProvider {
  async fn hover_at(Self, @workspace.SourceDocument, Int) -> Hover?
}

///|
pub(open) trait DefinitionProvider {
  async fn definition_at(Self, @workspace.SourceDocument, Int) -> Location?
}

///|
pub(open) trait ReferencesProvider {
  async fn references_at(Self, @workspace.SourceDocument, Int) -> Array[
    Location,
  ]
}

///|
pub(open) trait DiagnosticsProvider {
  async fn diagnostics_for_document(Self, @workspace.SourceDocument) -> Array[
    Diagnostic,
  ]
}

///|
pub(open) trait DocumentSymbolProvider {
  async fn document_symbols(Self, @workspace.SourceDocument) -> Array[
    DocumentSymbol,
  ]
}

///|
pub(open) trait SemanticTokensProvider {
  async fn semantic_tokens_for_document(Self, @workspace.SourceDocument) -> Array[
    SemanticToken,
  ]
}

///|
pub fn ProviderResult::empty() -> ProviderResult {
  {
    hovers: [],
    diagnostics: [],
    definitions: [],
    symbols: [],
    semantic_tokens: [],
  }
}

///|
pub fn collect_provider_result(
  provider : &LanguageProvider,
  doc : @core.DocumentSnapshot,
) -> ProviderResult {
  {
    hovers: provider.hovers(doc),
    diagnostics: provider.diagnostics(doc),
    definitions: provider.definitions(doc),
    symbols: provider.symbols(doc),
    semantic_tokens: provider.semantic_tokens(doc),
  }
}

///|
pub async fn collect_document_provider_result(
  diagnostics : &DiagnosticsProvider,
  symbols : &DocumentSymbolProvider,
  semantic_tokens : &SemanticTokensProvider,
  document : @workspace.SourceDocument,
) -> ProviderResult {
  {
    hovers: [],
    diagnostics: diagnostics.diagnostics_for_document(document),
    definitions: [],
    symbols: symbols.document_symbols(document),
    semantic_tokens: semantic_tokens.semantic_tokens_for_document(document),
  }
}

///|
pub fn ProviderResult::hover_at(self : ProviderResult, offset : Int) -> Hover? {
  let mut found : Hover? = None
  for hover in self.hovers {
    if hover.range.contains_offset(offset) {
      found = Some(hover)
    }
  }
  found
}

///|
pub fn ProviderResult::definition_at(
  self : ProviderResult,
  offset : Int,
) -> Location? {
  definition_at(self, offset)
}

///|
pub fn DiagnosticSeverity::label(self : DiagnosticSeverity) -> String {
  match self {
    Error => "Error"
    Warning => "Warning"
    Info => "Info"
  }
}

///|
fn definition_at(providers : ProviderResult, offset : Int) -> Location? {
  let mut found : Location? = None
  for location in providers.definitions {
    if found is None && location.range.contains_offset(offset) {
      found = Some(location)
    }
  }
  found
}
