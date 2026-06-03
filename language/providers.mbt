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
pub fn demo_provider() -> &LanguageProvider {
  DemoLanguageProvider::{  }
}

///|
pub fn demo_providers(doc : @core.DocumentSnapshot) -> ProviderResult {
  collect_provider_result(demo_provider(), doc)
}

///|
priv struct DemoLanguageProvider {}

///|
impl LanguageProvider for DemoLanguageProvider with fn hovers(_self, doc) {
  let hovers = []
  match main_range(doc) {
    Some(range) =>
      hovers.push(Hover::{ range, contents: "Demo hover: entry point symbol" })
    None => ()
  }
  hovers
}

///|
impl LanguageProvider for DemoLanguageProvider with fn diagnostics(_self, doc) {
  let diagnostics = []
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
  diagnostics
}

///|
impl LanguageProvider for DemoLanguageProvider with fn definitions(_self, doc) {
  let definitions = []
  match main_range(doc) {
    Some(range) =>
      definitions.push(Location::{
        uri: @workspace.DocumentUri::memory("fixture.mbt"),
        range,
      })
    None => ()
  }
  definitions
}

///|
impl LanguageProvider for DemoLanguageProvider with fn symbols(_self, doc) {
  let symbols = []
  match main_range(doc) {
    Some(range) =>
      symbols.push(DocumentSymbol::{ name: "main", kind: "function", range })
    None => ()
  }
  symbols
}

///|
impl LanguageProvider for DemoLanguageProvider with fn semantic_tokens(
  _self,
  doc,
) {
  let semantic_tokens = []
  match main_range(doc) {
    Some(range) =>
      semantic_tokens.push(SemanticToken::{ range, token_type: "function" })
    None => ()
  }
  semantic_tokens
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

///|
fn main_range(doc : @core.DocumentSnapshot) -> @core.Range? {
  match doc.text.find("main") {
    Some(start) => Some(Range(start, start + 4))
    None => None
  }
}
