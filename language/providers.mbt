///|
/// Hover payload shape. Markdown content is rendered by browser hover
/// participants; plaintext is escaped and shown verbatim.
pub(all) enum HoverContent {
  PlainText(String)
  Markdown(String)
} derive(Eq, Debug)

///|
/// Hover result anchored to a line/column `Range`, matching Monaco's `Hover`.
pub(all) struct Hover {
  range : @base_common.Range
  contents : Array[HoverContent]
} derive(Debug)

///|
/// Diagnostic severity levels accepted from semantic providers and remote LSP
/// adapters. `Hint` matches LSP `DiagnosticSeverity.Hint` (4) and Monaco's
/// `MarkerSeverity.Hint`.
pub(all) enum DiagnosticSeverity {
  Error
  Warning
  Info
  Hint
} derive(Eq, Debug)

///|
/// Diagnostic tag, mirroring Monaco's `MarkerTag` (`markers.ts:51`) and LSP's
/// `DiagnosticTag` (`Unnecessary=1, Deprecated=2`). Kept local to `language`
/// rather than reusing `viewer/common/markers`'s `MarkerTag`, since `language`
/// sits below `viewer` in the package graph.
pub(all) enum DiagnosticTag {
  Unnecessary
  Deprecated
} derive(Eq, Debug)

///|
/// Problem marker over a source range. `range` is a line/column `Range`,
/// matching Monaco's `IMarkerData`.
pub(all) struct Diagnostic {
  range : @base_common.Range
  severity : DiagnosticSeverity
  message : String
  tags : Array[DiagnosticTag]?
} derive(Debug)

///|
/// Cross-document location result for definition and reference providers.
/// `range` is a line/column `Range`, matching Monaco's `Location`.
pub(all) struct Location {
  uri : @base_common.Uri
  range : @base_common.Range
} derive(Debug)

///|
/// Symbol outline item for the current document. `range` is a line/column
/// `Range`, matching Monaco's `DocumentSymbol`.
pub(all) struct DocumentSymbol {
  name : String
  kind : String
  range : @base_common.Range
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
/// Document symbol provider for outline/navigation views.
pub(open) trait DocumentSymbolProvider {
  async fn provide_document_symbols(Self, @model.TextModel, CancellationToken) -> Array[
    DocumentSymbol,
  ]
}

///|
/// Human-readable diagnostic severity label.
pub fn DiagnosticSeverity::label(self : DiagnosticSeverity) -> String {
  match self {
    Error => "Error"
    Warning => "Warning"
    Info => "Info"
    Hint => "Hint"
  }
}

///|
/// Diagnostic tag label, mirrored on the wire.
pub fn DiagnosticTag::label(self : DiagnosticTag) -> String {
  match self {
    Unnecessary => "Unnecessary"
    Deprecated => "Deprecated"
  }
}
