///|
/// Builds a windowed frame over `doc`, with the generic fallback lexer
/// registered for the model's `moonbit` language id
/// (`register_plain_moonbit`, shared with the mouse-target tests).
fn frame_for(
  doc : @model.TextSnapshot,
  viewport : @view_model.FrameViewport,
  providers? : @language.ProviderResult = @language.ProviderResult::empty(),
) -> @view_model.RenderFrame {
  register_plain_moonbit()
  let model = @model.TextModel(
    @base_common.Uri::memory("frame.mbt"),
    "",
    "moonbit",
    1,
    "",
    doc.get_value(),
  )
  @view_model.build_frame(FrameSource(model, providers), viewport)
}
