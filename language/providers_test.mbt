///|
test "collects language provider surfaces" {
  let doc = @core.DocumentSnapshot("fn main {\n }")
  let provider = TestLanguageProvider::{  }
  let providers = collect_provider_result(provider, doc)
  assert_eq(providers.hovers.length(), 1)
  assert_eq(providers.diagnostics.length(), 1)
  assert_eq(providers.definitions.length(), 1)
  assert_eq(providers.definitions[0].uri.to_string(), "memory://provider.mbt")
  let hover = providers.hover_at(3)
  match hover {
    Some(item) => assert_eq(item.contents, "Provider hover")
    None => fail("expected hover")
  }
}

///|
struct TestLanguageProvider {}

///|
impl LanguageProvider for TestLanguageProvider with fn hovers(_self, _doc) {
  [{ range: Range(3, 7), contents: "Provider hover" }]
}

///|
impl LanguageProvider for TestLanguageProvider with fn diagnostics(_self, _doc) {
  [{ range: Range(0, 2), severity: Warning, message: "Provider warning" }]
}

///|
impl LanguageProvider for TestLanguageProvider with fn definitions(_self, _doc) {
  [{ uri: @workspace.DocumentUri::memory("provider.mbt"), range: Range(3, 7) }]
}

///|
impl LanguageProvider for TestLanguageProvider with fn symbols(_self, _doc) {
  [{ name: "main", kind: "function", range: Range(3, 7) }]
}

///|
impl LanguageProvider for TestLanguageProvider with fn semantic_tokens(
  _self,
  _doc,
) {
  [{ range: Range(3, 7), token_type: "function" }]
}
