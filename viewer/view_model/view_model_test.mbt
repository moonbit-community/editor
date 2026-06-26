///|
test "identity coordinates converter preserves model and view positions" {
  let converter = @view_model.IdentityCoordinatesConverter::new()
  let position = @base_common.Position(2, 7)
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
  let doc = @model.TextSnapshot("fn main {\n  let x = 1\n}")
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let providers = @language.ProviderResult::{
    hovers: [],
    diagnostics: [],
    definitions: [],
    symbols: [],
  }
  let source = @view_model.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    providers,
  )
  let view_model = @view_model.ViewModel(source)
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
fn test_view_model(
  text : String,
  options : @view_model.ViewModelOptions,
) -> @view_model.ViewModel {
  let doc = @model.TextSnapshot(text)
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  @view_model.ViewModel::with_options(
    FrameSource(
      tokenized,
      @decorations.DecorationSet::empty(),
      @language.ProviderResult::empty(),
    ),
    options,
  )
}

///|
fn test_folded_view_model(
  text : String,
  options : @view_model.ViewModelOptions,
  ranges : Array[@language.FoldingRange],
) -> @view_model.ViewModel {
  let doc = @model.TextSnapshot(text)
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let source = @view_model.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  @view_model.ViewModel::with_options_and_folding(
    source,
    options,
    @view_model.FoldingModel::from_folded_ranges(ranges, doc.line_count()),
  )
}

///|
fn test_inlay_view_model(
  text : String,
  options : @view_model.ViewModelOptions,
  hints : Array[@language.InlayHint],
) -> @view_model.ViewModel {
  let doc = @model.TextSnapshot(text)
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  @view_model.ViewModel::with_options_and_inlay_hints(
    FrameSource(
      tokenized,
      @decorations.DecorationSet::empty(),
      @language.ProviderResult::empty(),
    ),
    options,
    hints,
  )
}

///|
test "projected view lines cover one two and many wrapped segments" {
  let one = test_view_model("abc", @view_model.ViewModelOptions::soft_wrap(5))
  assert_eq(one.line_count(), 1)
  assert_eq(one.lines().get_view_line_content(1), "abc")
  let two = test_view_model(
    "abcdef",
    @view_model.ViewModelOptions::soft_wrap(5),
  )
  assert_eq(two.line_count(), 2)
  assert_eq(two.lines().get_view_line_content(1), "abcde")
  assert_eq(two.lines().get_view_line_content(2), "f")
  assert_eq(two.lines().model_line_number_of_view_line(2), 1)
  let second = two.lines().view_line_rendering_data(2)
  assert_true(second.continues_with_wrapped_line)
  assert_eq(second.min_column, 6)
  assert_eq(second.max_column, 7)
  let many = test_view_model(
    "abcdefghijkl",
    @view_model.ViewModelOptions::soft_wrap(5),
  )
  assert_eq(many.line_count(), 3)
  assert_eq(many.lines().get_view_line_content(1), "abcde")
  assert_eq(many.lines().get_view_line_content(2), "fghij")
  assert_eq(many.lines().get_view_line_content(3), "kl")
}

///|
test "projected coordinates convert model and view positions at wrap boundaries" {
  let view_model = test_view_model(
    "abcdefghij",
    @view_model.ViewModelOptions::soft_wrap(5),
  )
  let converter = view_model.coordinates_converter()
  let before_boundary = converter.model_position_to_view_position(
    Position(1, 5),
  )
  assert_eq(before_boundary.line_number, 1)
  assert_eq(before_boundary.column, 5)
  let boundary = converter.model_position_to_view_position(Position(1, 6))
  assert_eq(boundary.line_number, 2)
  assert_eq(boundary.column, 1)
  let round_trip = converter.view_position_to_model_position(Position(2, 1))
  assert_eq(round_trip.line_number, 1)
  assert_eq(round_trip.column, 6)
  let line_end = converter.view_position_to_model_position(Position(2, 6))
  assert_eq(line_end.line_number, 1)
  assert_eq(line_end.column, 11)
  let model_input_range : @view_line_renderer.ViewRange = {
    start_line_number: 1,
    start_column: 6,
    end_line_number: 1,
    end_column: 10,
  }
  let range = converter.model_range_to_view_range(model_input_range)
  assert_eq(range.start_line_number, 2)
  assert_eq(range.start_column, 1)
  assert_eq(range.end_line_number, 2)
  assert_eq(range.end_column, 5)
  let model_range = converter.view_range_to_model_range(range)
  assert_eq(model_range.start_line_number, 1)
  assert_eq(model_range.start_column, 6)
  assert_eq(model_range.end_line_number, 1)
  assert_eq(model_range.end_column, 10)
}

///|
test "projected line breaks account for tabs and full width characters" {
  let tabs = test_view_model(
    "a\tb",
    @view_model.ViewModelOptions::soft_wrap(4, tab_size=4),
  )
  assert_eq(tabs.line_count(), 2)
  let first_tab_line = tabs.lines().view_line_rendering_data(1)
  assert_eq(first_tab_line.content, "a\t")
  assert_eq(first_tab_line.start_visible_column, 0)
  assert_eq(first_tab_line.max_column, 3)
  let second_tab_line = tabs.lines().view_line_rendering_data(2)
  assert_eq(second_tab_line.content, "b")
  assert_eq(second_tab_line.start_visible_column, 4)
  assert_true(second_tab_line.continues_with_wrapped_line)
  let full_width = test_view_model(
    "ab中c",
    @view_model.ViewModelOptions::soft_wrap(4),
  )
  assert_eq(full_width.line_count(), 2)
  assert_eq(full_width.lines().get_view_line_content(1), "ab中")
  assert_eq(full_width.lines().get_view_line_content(2), "c")
}

///|
test "projected line breaks prefer Monaco word break points" {
  let space_break = test_view_model(
    "hello world",
    @view_model.ViewModelOptions::soft_wrap(8),
  )
  assert_eq(space_break.line_count(), 2)
  assert_eq(space_break.lines().get_view_line_content(1), "hello ")
  assert_eq(space_break.lines().get_view_line_content(2), "world")
  let before_punctuation = test_view_model(
    "call(argument)",
    @view_model.ViewModelOptions::soft_wrap(6),
  )
  assert_eq(before_punctuation.line_count(), 3)
  assert_eq(before_punctuation.lines().get_view_line_content(1), "call")
  assert_eq(before_punctuation.lines().get_view_line_content(2), "(argum")
  let cjk = test_view_model(
    "中文abc",
    @view_model.ViewModelOptions::soft_wrap(3),
  )
  assert_eq(cjk.line_count(), 3)
  assert_eq(cjk.lines().get_view_line_content(1), "中")
  assert_eq(cjk.lines().get_view_line_content(2), "文")
  assert_eq(cjk.lines().get_view_line_content(3), "abc")
}

///|
test "projected long moonbit lines retain source text across segments" {
  let text = "fn main { let really_long_identifier_name = 1234567890 }"
  let view_model = test_view_model(
    text,
    @view_model.ViewModelOptions::soft_wrap(12),
  )
  assert_true(view_model.line_count() > 1)
  let mut joined = ""
  for line_number in 1..<=view_model.line_count() {
    joined = joined + view_model.lines().get_view_line_content(line_number)
  }
  assert_eq(joined, text)
}

///|
test "inlay hints render as injected text without changing model offsets" {
  let view_model = test_inlay_view_model(
    "let x = 1",
    @view_model.ViewModelOptions::no_wrap(),
    [InlayHint(Position(1, 6), ": Int", kind=TypeHint)],
  )
  assert_eq(view_model.line_count(), 1)
  let line = view_model.lines().render_line(1)
  assert_eq(line.text, "let x: Int = 1")
  assert_eq(line.source_offset_at_column(0), 0)
  assert_eq(line.source_offset_at_column(5), 5)
  assert_eq(line.source_offset_at_column(10), 5)
  assert_eq(line.source_offset_at_column(line.text.length()), 9)
  assert_eq(line.injected_text_index_at_column(5), 0)
  assert_eq(line.injected_text_index_at_column(10), -1)
  let data = view_model.lines().view_line_rendering_data(1)
  assert_eq(data.content, "let x: Int = 1")
  assert_true(data.tokens.any(part => part.class_name.contains("inlay-hint")))
}

///|
test "injected text participates in wrapping and coordinate conversion" {
  let view_model = test_inlay_view_model(
    "abcdef",
    @view_model.ViewModelOptions::soft_wrap(5),
    [InlayHint(Position(1, 4), "XYZ", kind=ParameterHint)],
  )
  assert_eq(view_model.line_count(), 2)
  assert_eq(view_model.lines().get_view_line_content(1), "abcXY")
  assert_eq(view_model.lines().get_view_line_content(2), "Zdef")
  let converter = view_model.coordinates_converter()
  let source_position = converter.model_position_to_view_position(
    Position(1, 4),
  )
  assert_eq(source_position.line_number, 1)
  assert_eq(source_position.column, 4)
  let hint_position = converter.view_position_to_model_position(Position(1, 5))
  assert_eq(hint_position.line_number, 1)
  assert_eq(hint_position.column, 4)
  let wrapped_source = converter.view_position_to_model_position(Position(2, 2))
  assert_eq(wrapped_source.line_number, 1)
  assert_eq(wrapped_source.column, 4)
}

///|
test "injected text can sit at line boundaries" {
  let view_model = test_inlay_view_model(
    "ab",
    @view_model.ViewModelOptions::no_wrap(),
    [
      InlayHint(Position(1, 1), "[", kind=ParameterHint),
      InlayHint(Position(1, 3), "]", kind=TypeHint),
    ],
  )
  let line = view_model.lines().render_line(1)
  assert_eq(line.text, "[ab]")
  assert_eq(line.source_offset_at_column(0), 0)
  assert_eq(line.source_offset_at_column(1), 0)
  assert_eq(line.source_offset_at_column(3), 2)
  assert_eq(line.injected_text_index_at_column(0), 0)
  assert_eq(line.injected_text_index_at_column(3), 1)
}

///|
test "folded view model projects visible lines without soft wrap" {
  let view_model = test_folded_view_model(
    "a\nb\nc\nd",
    @view_model.ViewModelOptions::no_wrap(),
    [FoldingRange(1, 3)],
  )
  assert_eq(view_model.line_count(), 2)
  assert_eq(view_model.lines().get_view_line_content(1), "a")
  assert_eq(view_model.lines().get_view_line_content(2), "d")
  assert_eq(view_model.lines().model_line_number_of_view_line(1), 1)
  assert_eq(view_model.lines().model_line_number_of_view_line(2), 4)
  let converter = view_model.coordinates_converter()
  let last_model_line = converter.model_position_to_view_position(
    Position(4, 1),
  )
  assert_eq(last_model_line.line_number, 2)
  assert_eq(last_model_line.column, 1)
  let hidden_model_line = converter.model_position_to_view_position(
    Position(2, 1),
  )
  assert_eq(hidden_model_line.line_number, 1)
  assert_eq(hidden_model_line.column, 2)
  let view_position = converter.view_position_to_model_position(Position(2, 1))
  assert_eq(view_position.line_number, 4)
  assert_eq(view_position.column, 1)
}

///|
test "folded view model wraps only visible model lines" {
  let view_model = test_folded_view_model(
    "aa\nhidden\nabcdef",
    @view_model.ViewModelOptions::soft_wrap(3),
    [FoldingRange(1, 2)],
  )
  assert_eq(view_model.line_count(), 3)
  assert_eq(view_model.lines().get_view_line_content(1), "aa")
  assert_eq(view_model.lines().get_view_line_content(2), "abc")
  assert_eq(view_model.lines().get_view_line_content(3), "def")
  assert_eq(view_model.lines().model_line_number_of_view_line(2), 3)
  let converter = view_model.coordinates_converter()
  let wrapped_visible_line = converter.model_position_to_view_position(
    Position(3, 5),
  )
  assert_eq(wrapped_visible_line.line_number, 3)
  assert_eq(wrapped_visible_line.column, 2)
  let hidden_model_line = converter.model_position_to_view_position(
    Position(2, 1),
  )
  assert_eq(hidden_model_line.line_number, 1)
  assert_eq(hidden_model_line.column, 3)
}
