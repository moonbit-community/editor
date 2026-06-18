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
  range : @base_common.Range
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
  range : @base_common.Range
  severity : DiagnosticSeverity
  message : String
} derive(Debug)

///|
/// Cross-document location result for definition and reference providers.
pub(all) struct Location {
  uri : @base_common.Uri
  range : @base_common.Range
} derive(Debug)

///|
/// Symbol outline item for the current document.
pub(all) struct DocumentSymbol {
  name : String
  kind : String
  range : @base_common.Range
} derive(Debug)

///|
/// Semantic token span after provider-side token-type classification.
pub(all) struct SemanticToken {
  range : @base_common.Range
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
/// Asynchronous hover provider for a readonly text model and
/// zero-based UTF-16 position.
pub(open) trait HoverProvider {
  async fn provide_hover(
    Self,
    @model.TextModel,
    @base_common.Position,
    CancellationToken,
  ) -> Hover?
}

///|
/// Asynchronous definition provider for a readonly text model.
pub(open) trait DefinitionProvider {
  async fn provide_definition(
    Self,
    @model.TextModel,
    @base_common.Position,
    CancellationToken,
  ) -> Location?
}

///|
/// Asynchronous references provider for a readonly text model.
pub(open) trait ReferencesProvider {
  async fn provide_references(
    Self,
    @model.TextModel,
    @base_common.Position,
    CancellationToken,
  ) -> Array[Location]
}

///|
/// Document diagnostics provider. Results replace diagnostics for the queried
/// document/resource owner.
pub(open) trait DiagnosticsProvider {
  async fn provide_diagnostics(Self, @model.TextModel, CancellationToken) -> Array[
    Diagnostic,
  ]
}

///|
/// Document symbol provider for outline/navigation views.
pub(open) trait DocumentSymbolProvider {
  async fn provide_document_symbols(Self, @model.TextModel, CancellationToken) -> Array[
    DocumentSymbol,
  ]
}

///|
/// Full-document semantic token provider. The viewer treats returned tokens as
/// replacing the previous semantic-token set for that document revision.
pub(open) trait SemanticTokensProvider {
  async fn provide_document_semantic_tokens(
    Self,
    @model.TextModel,
    CancellationToken,
  ) -> Array[SemanticToken]
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
/// Collects model-level feature families that do not depend on a cursor
/// offset.
pub async fn collect_model_provider_result(
  diagnostics : &DiagnosticsProvider,
  symbols : &DocumentSymbolProvider,
  semantic_tokens : &SemanticTokensProvider,
  model : @model.TextModel,
  token : CancellationToken,
) -> ProviderResult {
  {
    hovers: [],
    diagnostics: diagnostics.provide_diagnostics(model, token),
    definitions: [],
    symbols: symbols.provide_document_symbols(model, token),
    semantic_tokens: semantic_tokens.provide_document_semantic_tokens(
      model, token,
    ),
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
