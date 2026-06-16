///|
test "identity coordinates converter preserves model and view positions" {
  let converter = @renderer.IdentityCoordinatesConverter::new()
  let position = @core.Position(2, 7)
  assert_true(converter.model_position_to_view_position(position) == position)
  assert_true(converter.view_position_to_model_position(position) == position)
  let range = @view_line_renderer.ViewRange::{
    start_line_number: 2,
    start_column: 3,
    end_line_number: 4,
    end_column: 9,
  }
  assert_true(converter.model_range_to_view_range(range) == range)
  assert_true(converter.view_range_to_model_range(range) == range)
}

///|
test "view model lines as-is match render frame line data" {
  let doc = @core.DocumentSnapshot("fn main {\n  let x = 1\n}")
  let tokenized = @renderer.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let providers = @language.ProviderResult::{
    hovers: [],
    diagnostics: [],
    definitions: [],
    symbols: [],
    semantic_tokens: [{ range: Range(13, 14), token_type: "variable" }],
  }
  let source = @renderer.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    providers,
  )
  let view_model = @renderer.ViewModel(source)
  let lines = view_model.lines()
  let direct_line = lines.render_line(2)
  let frame = view_model.render_frame({ start_line: 1, end_line: 2 })
  let frame_line = frame.lines[0]
  assert_eq(direct_line.line_number, frame_line.line_number)
  assert_eq(direct_line.offset, frame_line.offset)
  assert_eq(direct_line.text, frame_line.text)
  assert_eq(direct_line.spans.length(), frame_line.spans.length())
  for index in 0..<direct_line.spans.length() {
    assert_eq(direct_line.spans[index].start, frame_line.spans[index].start)
    assert_eq(direct_line.spans[index].end, frame_line.spans[index].end)
    assert_eq(
      direct_line.spans[index].class_name,
      frame_line.spans[index].class_name,
    )
  }
  let data = lines.view_line_rendering_data(2)
  assert_eq(data.min_column, 1)
  assert_eq(data.max_column, direct_line.text.length() + 1)
  assert_eq(data.content, direct_line.text)
  assert_eq(data.tokens.length(), direct_line.spans.length())
  for index in 0..<data.tokens.length() {
    assert_eq(data.tokens[index].end_index, direct_line.spans[index].end)
    assert_eq(
      data.tokens[index].class_name,
      direct_line.spans[index].class_name,
    )
  }
}

///|
test "view model produces viewport data from layout window" {
  let doc = @core.DocumentSnapshot("a\nbb\nccc")
  let view_model = view_model_for(doc)
  let viewport = @renderer.ViewportData::from_view_model(
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
}

///|
fn view_model_for(doc : @core.DocumentSnapshot) -> @renderer.ViewModel {
  let tokenized = @renderer.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  ViewModel(
    FrameSource(
      tokenized,
      @decorations.DecorationSet::empty(),
      @language.ProviderResult::empty(),
    ),
  )
}
