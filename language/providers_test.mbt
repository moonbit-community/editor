///|
test "provider result finds hover and definition by offset" {
  let providers : ProviderResult = {
    hovers: [
      {
        range: @base_common.Range::Range(1, 4, 1, 8),
        contents: [PlainText("Provider hover")],
      },
    ],
    diagnostics: [
      {
        range: @base_common.Range::Range(1, 1, 1, 3),
        severity: Warning,
        message: "Provider warning",
      },
    ],
    definitions: [
      {
        uri: @base_common.Uri::memory("provider.mbt"),
        range: @base_common.Range::Range(1, 4, 1, 8),
      },
    ],
    symbols: [
      {
        name: "main",
        kind: "function",
        range: @base_common.Range::Range(1, 4, 1, 8),
      },
    ],
    semantic_tokens: [{ range: OffsetRange(3, 7), token_type: "function" }],
  }
  assert_eq(providers.diagnostics.length(), 1)
  assert_eq(providers.definitions.length(), 1)
  assert_eq(providers.definitions[0].uri.to_string(), "memory://provider.mbt")
  let hover = providers.hover_at(@base_common.Position::Position(1, 4))
  match hover {
    Some(item) =>
      match item.contents {
        [PlainText(text)] => assert_eq(text, "Provider hover")
        _ => fail("expected plaintext hover")
      }
    None => fail("expected hover")
  }
  match providers.definition_at(@base_common.Position::Position(1, 4)) {
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
