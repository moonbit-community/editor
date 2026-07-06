///|
/// Builds a view model over `doc`, with the generic fallback lexer
/// registered for the model's `moonbit` language id
/// (`register_plain_moonbit`, shared with the mouse-target tests).
fn view_model_for(doc : @model.TextSnapshot) -> @view_model.ViewModel {
  register_plain_moonbit()
  let model = @model.TextModel(
    @base_common.Uri::memory("frame.mbt"),
    "",
    "moonbit",
    1,
    "",
    doc.get_value(),
  )
  ViewModel(model)
}
