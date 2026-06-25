///|
fn hit_test_frame(
  viewport? : @view_model.FrameViewport,
) -> @view_model.RenderFrame {
  let doc = @model.TextSnapshot("fn main {\n  let x = 1\n}\n\nfn other {}")
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let source = @view_model.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  let viewport = match viewport {
    Some(viewport) => viewport
    None => { start_line: 0, end_line: doc.line_count() }
  }
  @view_model.build_frame(source, viewport)
}

///|
fn projected_hit_test_frame() -> @view_model.RenderFrame {
  let doc = @model.TextSnapshot("abcdefghij")
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let source = @view_model.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  let view_model = @view_model.ViewModel::with_options(
    source,
    @view_model.ViewModelOptions::soft_wrap(5),
  )
  view_model.render_frame({ start_line: 0, end_line: view_model.line_count() })
}

///|
fn inlay_hint_hit_test_frame() -> @view_model.RenderFrame {
  let doc = @model.TextSnapshot("let x = 1")
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let source = @view_model.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  let view_model = @view_model.ViewModel::with_options_and_inlay_hints(
    source,
    @view_model.ViewModelOptions::no_wrap(),
    [InlayHint(Position(0, 5), ": Int", kind=TypeHint)],
  )
  view_model.render_frame({ start_line: 0, end_line: view_model.line_count() })
}

///|
fn test_metrics(
  scroll_top? : Double = 0.0,
  scroll_left? : Double = 0.0,
  view_zones? : Array[@view_layout.ViewZone] = [],
) -> @common.ViewMetrics {
  {
    origin_x: 0.0,
    origin_y: 0.0,
    scroll_top,
    scroll_left,
    viewport_height: 200.0,
    line_height: 18,
    char_width: 8.0,
    gutter_width: 50.0,
    view_zones,
  }
}

///|
test "hit test maps wrapped view line coordinates to a view position" {
  let frame = projected_hit_test_frame()
  assert_eq(frame.line_count, 2)
  let target = @common.hit_test(
    frame,
    test_metrics(),
    50.0 + 8.0 * 2.0,
    18.0 + 4.0,
  )
  assert_true(target.kind == ContentText)
  assert_eq(target.line_number, 2)
  assert_eq(target.column, 2)
  let gutter = @common.hit_test(frame, test_metrics(), 10.0, 18.0 + 4.0)
  assert_true(gutter.kind == GutterLineNumbers)
  assert_eq(gutter.line_number, 2)
}

///|
test "hit test reports injected text hits with their view column and index" {
  let frame = inlay_hint_hit_test_frame()
  assert_eq(frame.lines[0].text, "let x: Int = 1")
  let target = @common.hit_test(frame, test_metrics(), 50.0 + 8.0 * 6.0, 4.0)
  assert_true(target.kind == ContentText)
  assert_eq(target.column, 6)
  assert_eq(target.injected_text_index, 0)
  let source_after_hint = @common.hit_test(
    frame,
    test_metrics(),
    50.0 + 8.0 * 11.0,
    4.0,
  )
  assert_true(source_after_hint.kind == ContentText)
  assert_eq(source_after_hint.column, 11)
  assert_eq(source_after_hint.injected_text_index, -1)
}

///|
test "hit test resolves gutter, text, and empty content targets" {
  let frame = hit_test_frame()
  // Inside the gutter band of the first line.
  debug_inspect(
    @common.hit_test(frame, test_metrics(), 10.0, 4.0),
    content=(
      #|{
      #|  kind: GutterLineNumbers,
      #|  line_number: 1,
      #|  column: 0,
      #|  span_index: -1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
  // Column 3 of line 1 lands inside the `main` identifier span.
  debug_inspect(
    @common.hit_test(frame, test_metrics(), 50.0 + 8.0 * 3.0, 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 1,
      #|  column: 3,
      #|  span_index: 2,
      #|  injected_text_index: -1,
      #|}
    ),
  )
  // Past the end of line 1's text.
  debug_inspect(
    @common.hit_test(frame, test_metrics(), 50.0 + 8.0 * 30.0, 4.0),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 1,
      #|  column: 30,
      #|  span_index: -1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
}

///|
test "hit test maps scrolled coordinates and below-content space" {
  let frame = hit_test_frame()
  // Scrolled down one line: y=4 now lands on line 2, column 2 -> `let`.
  debug_inspect(
    @common.hit_test(frame, test_metrics(scroll_top=18.0), 50.0 + 16.0, 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 2,
      #|  column: 2,
      #|  span_index: 1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
  // Below the last line.
  debug_inspect(
    @common.hit_test(frame, test_metrics(), 60.0, 18.0 * 5.0 + 4.0),
    content=(
      #|{
      #|  kind: BelowContent,
      #|  line_number: 5,
      #|  column: 0,
      #|  span_index: -1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
  // Outside the viewer box.
  debug_inspect(
    @common.hit_test(frame, test_metrics(), -2.0, 4.0),
    content=(
      #|{
      #|  kind: Outside,
      #|  line_number: 0,
      #|  column: 0,
      #|  span_index: -1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
}

///|
test "hit test accounts for view zones displacing following lines" {
  let frame = hit_test_frame()
  let metrics = test_metrics(view_zones=[{ anchor_line: 1, height_px: 36 }])
  // The zone band itself belongs to the widget, not the editor content.
  debug_inspect(
    @common.hit_test(frame, metrics, 60.0, 18.0 + 4.0),
    content=(
      #|{
      #|  kind: Outside,
      #|  line_number: 0,
      #|  column: 0,
      #|  span_index: -1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
  // Below the zone, line 2 is shifted down by the zone height.
  debug_inspect(
    @common.hit_test(frame, metrics, 50.0 + 16.0, 18.0 + 36.0 + 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 2,
      #|  column: 2,
      #|  span_index: 1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
  // Above the zone, line 1 is unaffected.
  debug_inspect(
    @common.hit_test(frame, metrics, 50.0 + 8.0 * 3.0, 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 1,
      #|  column: 3,
      #|  span_index: 2,
      #|  injected_text_index: -1,
      #|}
    ),
  )
}

///|
test "hit test reports empty lines and windowed-out lines as content empty" {
  let frame = hit_test_frame()
  // Line 4 is empty: any column resolves to its start offset. x=70 sits 2.5
  // glyphs past the content origin and rounds to the nearer column 3.
  debug_inspect(
    @common.hit_test(frame, test_metrics(), 70.0, 18.0 * 3.0 + 4.0),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 4,
      #|  column: 3,
      #|  span_index: -1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
  let windowed = hit_test_frame(viewport={ start_line: 0, end_line: 2 })
  // Line 4 exists in the document but is outside the rendered window.
  debug_inspect(
    @common.hit_test(windowed, test_metrics(), 70.0, 18.0 * 3.0 + 4.0),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 4,
      #|  column: 0,
      #|  span_index: -1,
      #|  injected_text_index: -1,
      #|}
    ),
  )
}
