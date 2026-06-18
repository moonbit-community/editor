///|
fn frame_for(
  doc : @model.TextSnapshot,
  viewport : @view_model.FrameViewport,
  decorations? : @decorations.DecorationSet = @decorations.DecorationSet::empty(),
  providers? : @language.ProviderResult = @language.ProviderResult::empty(),
) -> @view_model.RenderFrame {
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  @view_model.build_frame(
    FrameSource(tokenized, decorations, providers),
    viewport,
  )
}
