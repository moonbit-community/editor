///|
/// Registers the generic fallback lexer for the `moonbit` language id the
/// test models carry (the real lexers are registered by the shell, not the
/// common tier). Idempotent; the registration lives for the test binary.
fn register_plain_moonbit() -> Unit {
  @syntax.tokenization_registry.register(
    "moonbit",
    @syntax.PlainTokenizer::new(),
  )
  |> ignore
}

///|
/// Builds a view model over `doc`, with the generic fallback lexer
/// registered for the model's `moonbit` language id
/// (`register_plain_moonbit`, shared with the mouse-target tests).
fn view_model_for(doc : @model.TextSnapshot) -> @view_model.ViewModel {
  register_plain_moonbit()
  let model = @model.TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/frame.mbt",
    ),
    "",
    "moonbit",
    1,
    "",
    doc.get_value(),
  )
  ViewModel(model)
}
