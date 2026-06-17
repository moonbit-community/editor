///|
/// Hover payload shape. Markdown content is rendered by browser hover
/// participants; plaintext is escaped and shown verbatim.
pub(all) enum HoverContent {
  PlainText(String)
  Markdown(String)
} derive(Eq, Debug)

///|
/// Hover result anchored to a document range in core UTF-16 offsets.
pub(all) struct Hover {
  range : @core.Range
  contents : Array[HoverContent]
} derive(Debug)

///|
/// Diagnostic severity levels accepted from semantic providers and remote LSP
/// adapters.
pub(all) enum DiagnosticSeverity {
  Error
  Warning
  Info
} derive(Eq, Debug)

///|
/// Problem marker over a source range.
pub(all) struct Diagnostic {
  range : @core.Range
  severity : DiagnosticSeverity
  message : String
} derive(Debug)

///|
/// Cross-document location result for definition and reference providers.
pub(all) struct Location {
  uri : @workspace.DocumentUri
  range : @core.Range
} derive(Debug)

///|
/// Symbol outline item for the current document.
pub(all) struct DocumentSymbol {
  name : String
  kind : String
  range : @core.Range
} derive(Debug)

///|
/// Semantic token span after provider-side token-type classification.
pub(all) struct SemanticToken {
  range : @core.Range
  token_type : String
} derive(Debug)

///|
/// Aggregated feature result used by the renderer model when several semantic
/// feature families are computed together.
pub(all) struct ProviderResult {
  hovers : Array[Hover]
  diagnostics : Array[Diagnostic]
  definitions : Array[Location]
  symbols : Array[DocumentSymbol]
  semantic_tokens : Array[SemanticToken]
} derive(Debug)

///|
/// Legacy snapshot-level provider aggregate used by the compatibility render
/// path.
pub(open) trait LanguageProvider {
  fn hovers(Self, @core.DocumentSnapshot) -> Array[Hover]
  fn diagnostics(Self, @core.DocumentSnapshot) -> Array[Diagnostic]
  fn definitions(Self, @core.DocumentSnapshot) -> Array[Location]
  fn symbols(Self, @core.DocumentSnapshot) -> Array[DocumentSymbol]
  fn semantic_tokens(Self, @core.DocumentSnapshot) -> Array[SemanticToken]
}

///|
/// Asynchronous hover provider for a versioned `SourceDocument` and UTF-16
/// offset.
pub(open) trait HoverProvider {
  async fn hover_at(Self, @workspace.SourceDocument, Int) -> Hover?
}

///|
/// Asynchronous definition provider for a versioned `SourceDocument` and
/// UTF-16 offset.
pub(open) trait DefinitionProvider {
  async fn definition_at(Self, @workspace.SourceDocument, Int) -> Location?
}

///|
/// Asynchronous references provider for a versioned `SourceDocument` and
/// UTF-16 offset.
pub(open) trait ReferencesProvider {
  async fn references_at(Self, @workspace.SourceDocument, Int) -> Array[
    Location,
  ]
}

///|
/// Document diagnostics provider. Results replace diagnostics for the queried
/// document/resource owner.
pub(open) trait DiagnosticsProvider {
  async fn diagnostics_for_document(Self, @workspace.SourceDocument) -> Array[
    Diagnostic,
  ]
}

///|
/// Document symbol provider for outline/navigation views.
pub(open) trait DocumentSymbolProvider {
  async fn document_symbols(Self, @workspace.SourceDocument) -> Array[
    DocumentSymbol,
  ]
}

///|
/// Full-document semantic token provider. The viewer treats returned tokens as
/// replacing the previous semantic-token set for that document version.
pub(open) trait SemanticTokensProvider {
  async fn semantic_tokens_for_document(Self, @workspace.SourceDocument) -> Array[
    SemanticToken,
  ]
}

///|
/// Empty feature aggregate used when no provider has answered.
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
/// Collects every feature family from the legacy snapshot-level provider.
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
/// Collects document-level feature families that do not depend on a cursor
/// offset.
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
/// Last hover containing `offset`, matching the viewer's later-result-wins
/// behavior for overlapping hover ranges.
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
/// First definition location containing `offset`.
pub fn ProviderResult::definition_at(
  self : ProviderResult,
  offset : Int,
) -> Location? {
  definition_at(self, offset)
}

///|
/// Human-readable diagnostic severity label.
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
