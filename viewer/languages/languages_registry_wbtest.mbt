///|
fn test_model() -> @model.TextModel {
  TextModel(
    @base_common.Uri::memory("language-test.mbt"),
    "language-test.mbt",
    "moonbit",
    7,
    "rev-7",
    "fn main {\n  value\n}\n",
  )
}

///|
async test "provider failures are logged and isolated" {
  let memory = @log.MemoryLogger::new()
  let log_service = @log.LogService::new(logger=memory)
  let languages = Languages::new()
  languages.register_hover_provider(LanguageId("moonbit"), FailingHoverProvider::{

  })
  |> ignore
  languages.register_hover_provider(LanguageId("moonbit"), TestHoverProvider::{

  })
  |> ignore
  let model = test_model()
  let hover = languages.hover_at(model, 3, log_service)
  assert_true(hover is Some(_))
  let entries = memory.entries()
  assert_eq(entries.length(), 1)
  assert_true(entries[0].category == "language.hover")
  assert_true(entries[0].details[2] == ("providerIndex", "0"))
}

///|
test "token providers dispose only the active registration" {
  let languages = Languages::new()
  let first = languages.set_tokens_provider(
    "toy",
    @syntax.PlainTokenizer::new(),
  )
  let second = languages.set_tokens_provider(
    "toy",
    @syntax.PlainTokenizer::new(),
  )
  first.dispose()
  assert_true(languages.lookup_tokens_provider("toy") is Some(_))
  second.dispose()
  assert_true(languages.lookup_tokens_provider("toy") is None)
}

///|
async test "language provider registrations preserve order after disposal" {
  let languages = Languages::new()
  let first = languages.register_hover_provider(LanguageId("moonbit"), NamedHoverProvider::{
    text: "first",
  })
  let second = languages.register_hover_provider(LanguageId("moonbit"), NamedHoverProvider::{
    text: "second",
  })
  let log_service = @log.LogService::new()
  let model = test_model()
  assert_hover_text(languages.hover_at(model, 3, log_service), "first")
  first.dispose()
  assert_hover_text(languages.hover_at(model, 3, log_service), "second")
  second.dispose()
  assert_true(languages.hover_at(model, 3, log_service) is None)
}

///|
priv struct TestHoverProvider {}

///|
impl @language.HoverProvider for TestHoverProvider with fn provide_hover(
  _self,
  model,
  position,
  _token,
) {
  let offset = model.snapshot.offset_at_position(position)
  Some({
    range: Range(offset, offset + 1),
    contents: [PlainText("provider hover")],
  })
}

///|
priv struct NamedHoverProvider {
  text : String
}

///|
impl @language.HoverProvider for NamedHoverProvider with fn provide_hover(
  self,
  model,
  position,
  _token,
) {
  let offset = model.snapshot.offset_at_position(position)
  Some({ range: Range(offset, offset + 1), contents: [PlainText(self.text)] })
}

///|
fn assert_hover_text(hover : @language.Hover?, expected : String) -> Unit raise {
  match hover {
    Some(hover) =>
      match hover.contents[0] {
        PlainText(text) => assert_eq(text, expected)
        Markdown(_) => fail("expected plaintext hover")
      }
    None => fail("expected hover")
  }
}

///|
priv suberror TestProviderError {
  TestProviderError
}

///|
priv struct FailingHoverProvider {}

///|
impl @language.HoverProvider for FailingHoverProvider with fn provide_hover(
  _self,
  _model,
  _position,
  _token,
) {
  raise TestProviderError
}
