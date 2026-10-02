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
  assert_true(@language.LanguageSelector::LanguageId("moonbit").matches(model))
  assert_true(
    @language.LanguageFilter::LanguageFilter(
      language="moonbit",
      scheme="file",
      pattern="src/*.mbt",
    ).matches(model),
  )
  assert_true(
    @language.LanguageSelector::LanguageSelectorList([
      LanguageId("javascript"),
      LanguageFilter(LanguageFilter(language="moonbit")),
    ]).matches(model),
  )
  assert_true(
    !@language.LanguageSelector::LanguageId("javascript").matches(model),
  )
  assert_true(
    !@language.LanguageFilter::LanguageFilter(
      language="moonbit",
      scheme="memory",
    ).matches(model),
  )
}

///|
fn expect_uri(raw_uri : String) -> @base_common.Uri raise {
  @base_common.Uri::parse(raw_uri)
}
