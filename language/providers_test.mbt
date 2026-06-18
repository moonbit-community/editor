///|
test "provider result finds hover and definition by offset" {
  let providers : ProviderResult = {
    hovers: [{ range: Range(3, 7), contents: [PlainText("Provider hover")] }],
    diagnostics: [
      { range: Range(0, 2), severity: Warning, message: "Provider warning" },
    ],
    definitions: [
      { uri: @base_common.Uri::memory("provider.mbt"), range: Range(3, 7) },
    ],
    symbols: [{ name: "main", kind: "function", range: Range(3, 7) }],
    semantic_tokens: [{ range: Range(3, 7), token_type: "function" }],
  }
  assert_eq(providers.diagnostics.length(), 1)
  assert_eq(providers.definitions.length(), 1)
  assert_eq(providers.definitions[0].uri.to_string(), "memory://provider.mbt")
  let hover = providers.hover_at(3)
  match hover {
    Some(item) =>
      match item.contents {
        [PlainText(text)] => assert_eq(text, "Provider hover")
        _ => fail("expected plaintext hover")
      }
    None => fail("expected hover")
  }
  match providers.definition_at(3) {
    Some(item) => assert_eq(item.uri.to_string(), "memory://provider.mbt")
    None => fail("expected definition")
  }
}

///|
test "language selectors match language scheme and path" {
  let model = @model.TextModel(
    expect_uri("file://workspace/src/main.mbt"),
    "main.mbt",
    "moonbit",
    1,
    "rev-1",
    "fn main {}\n",
  )
  assert_true(LanguageSelector::LanguageId("moonbit").matches(model))
  assert_true(
    LanguageFilter::LanguageFilter(
      language="moonbit",
      scheme="file",
      pattern="src/*.mbt",
    ).matches(model),
  )
  assert_true(
    LanguageSelector::LanguageSelectorList([
      LanguageId("javascript"),
      LanguageFilter(LanguageFilter(language="moonbit")),
    ]).matches(model),
  )
  assert_true(!LanguageSelector::LanguageId("javascript").matches(model))
  assert_true(
    !LanguageFilter::LanguageFilter(language="moonbit", scheme="memory").matches(
      model,
    ),
  )
}

///|
fn expect_uri(raw_uri : String) -> @base_common.Uri raise {
  match @base_common.Uri::parse(raw_uri) {
    ParsedUri(uri) => uri
    UriError(error) => fail("unexpected uri error " + error.to_string())
  }
}
