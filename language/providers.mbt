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
  uri : String
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
pub fn demo_providers(doc : @core.DocumentSnapshot) -> ProviderResult {
  let diagnostics = []
  let hovers = []
  let definitions = []
  let symbols = []
  let semantic_tokens = []
  let warning = doc.text.find("TODO")
  match warning {
    Some(start) =>
      diagnostics.push(Diagnostic::{
        range: Range(start, start + 4),
        severity: Warning,
        message: "Demo diagnostic from readonly provider",
      })
    None => ()
  }
  let main_start = doc.text.find("main")
  match main_start {
    Some(start) => {
      let range = @core.Range(start, start + 4)
      hovers.push(Hover::{ range, contents: "Demo hover: entry point symbol" })
      definitions.push(Location::{ uri: "memory://fixture.mbt", range })
      symbols.push(DocumentSymbol::{ name: "main", kind: "function", range })
      semantic_tokens.push(SemanticToken::{ range, token_type: "function" })
    }
    None => ()
  }
  { hovers, diagnostics, definitions, symbols, semantic_tokens }
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
pub fn DiagnosticSeverity::label(self : DiagnosticSeverity) -> String {
  match self {
    Error => "Error"
    Warning => "Warning"
    Info => "Info"
  }
}
