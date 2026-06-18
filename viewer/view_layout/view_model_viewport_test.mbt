///|
test "view model produces viewport data from layout window" {
  let doc = @model.TextSnapshot("a\nbb\nccc")
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let view_model = @view_model.ViewModel(
    FrameSource(
      tokenized,
      @decorations.DecorationSet::empty(),
      @language.ProviderResult::empty(),
    ),
  )
  let viewport = @view_layout.ViewportData::from_view_model(
    view_model,
    { start: 1, end: 3 },
    line_height=18,
  )
  assert_eq(viewport.start_line_number, 2)
  assert_eq(viewport.end_line_number, 3)
  assert_eq(viewport.line_data(2).unwrap().content, "bb")
  assert_eq(viewport.line_data(3).unwrap().content, "ccc")
  debug_inspect(
    viewport.relative_vertical_offset,
    content=(
      #|[0, 18]
    ),
  )
  let layout = @view_layout.ViewLayout::new(line_height=18, line_count=3)
  layout.set_view_zones([{ anchor_line: 1, height_px: 36 }]) |> ignore
  let displaced = @view_layout.ViewportData::from_view_model(
    view_model,
    { start: 1, end: 3 },
    line_height=18,
    layout~,
  )
  debug_inspect(
    displaced.relative_vertical_offset,
    content=(
      #|[0, 18]
    ),
  )
  debug_inspect(
    displaced.view_zones,
    content=(
      #|[
      #|  {
      #|    zone_index: 0,
      #|    anchor_line: 1,
      #|    height_px: 36,
      #|    relative_vertical_offset: -36,
      #|  },
      #|]
    ),
  )
}
