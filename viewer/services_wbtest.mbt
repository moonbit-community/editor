///|
fn test_model() -> @model.TextModel {
  TextModel(
    @base_common.Uri::memory("service-test.mbt"),
    "service-test.mbt",
    "moonbit",
    7,
    "rev-7",
    "fn main {\n  value\n}\n",
  )
}

///|
async test "content hover computer separates sync markers from async markdown" {
  let services = ViewerServices::new(languages=Languages::new())
  let model = test_model()
  services.markers.set_diagnostics("diagnostics:0", model.uri, [
    { range: Range(12, 17), severity: Warning, message: "marker hover" },
  ])
  services.languages.register_hover_provider(LanguageId("moonbit"), TestHoverProvider::{

  })
  |> ignore
  let computer = ContentHoverComputer::new(services)
  let sync_hover = computer.compute_sync(model, Range(12, 17), 14)
  match sync_hover {
    Some(hover) => {
      assert_eq(hover.parts.length(), 1)
      assert_true(hover.parts[0] is MarkerHover(_))
    }
    None => fail("expected marker hover")
  }
  let async_hover = computer.compute_async(model, Range(12, 17), 14)
  match async_hover {
    Some(hover) => {
      assert_eq(hover.parts.length(), 1)
      assert_true(hover.parts[0] is MarkdownHover(_))
    }
    None => fail("expected markdown hover")
  }
}

///|
async test "provider failures are logged and isolated" {
  let memory = @log.MemoryLogger::new()
  let services = ViewerServices::new(
    languages=Languages::new(),
    log_service=@log.LogService::new(logger=memory),
  )
  services.languages.register_hover_provider(LanguageId("moonbit"), FailingHoverProvider::{

  })
  |> ignore
  services.languages.register_hover_provider(LanguageId("moonbit"), TestHoverProvider::{

  })
  |> ignore
  let model = test_model()
  let hover = services.languages.hover_at(model, 3, services.log_service)
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
