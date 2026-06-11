///|
fn test_frame() -> @renderer.RenderFrame {
  let doc = @core.DocumentSnapshot("fn main {\n  let x = 1\n}\n\nfn other {}")
  let tokens = @syntax.highlight(doc)
  @renderer.build_frame(
    doc,
    { start_line: 0, end_line: doc.line_count() },
    tokens,
    @decorations.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
}

///|
fn test_metrics(
  scroll_top? : Double = 0.0,
  view_zones? : Array[@renderer.ViewZone] = [],
) -> @renderer.ViewMetrics {
  {
    origin_x: 0.0,
    origin_y: 0.0,
    scroll_top,
    viewport_height: 200.0,
    line_height: 18,
    char_width: 8.0,
    gutter_width: 50.0,
    view_zones,
  }
}

///|
test "hit test resolves gutter, text, and empty content targets" {
  let frame = test_frame()
  // Inside the gutter band of the first line.
  debug_inspect(
    @renderer.hit_test(frame, test_metrics(), 10.0, 4.0),
    content=(
      #|{
      #|  kind: GutterLineNumbers,
      #|  line_number: 1,
      #|  column: 0,
      #|  offset: 0,
      #|  span_index: -1,
      #|}
    ),
  )
  // Column 3 of line 1 lands inside the `main` identifier span.
  debug_inspect(
    @renderer.hit_test(frame, test_metrics(), 50.0 + 8.0 * 3.0, 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 1,
      #|  column: 3,
      #|  offset: 3,
      #|  span_index: 2,
      #|}
    ),
  )
  // Past the end of line 1's text.
  debug_inspect(
    @renderer.hit_test(frame, test_metrics(), 50.0 + 8.0 * 30.0, 4.0),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 1,
      #|  column: 30,
      #|  offset: 9,
      #|  span_index: -1,
      #|}
    ),
  )
}

///|
test "hit test maps scrolled coordinates and below-content space" {
  let frame = test_frame()
  // Scrolled down one line: y=4 now lands on line 2, column 2 -> `let`.
  debug_inspect(
    @renderer.hit_test(frame, test_metrics(scroll_top=18.0), 50.0 + 16.0, 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 2,
      #|  column: 2,
      #|  offset: 12,
      #|  span_index: 1,
      #|}
    ),
  )
  // Below the last line.
  debug_inspect(
    @renderer.hit_test(frame, test_metrics(), 60.0, 18.0 * 5.0 + 4.0),
    content=(
      #|{
      #|  kind: BelowContent,
      #|  line_number: 5,
      #|  column: 0,
      #|  offset: -1,
      #|  span_index: -1,
      #|}
    ),
  )
  // Outside the viewer box.
  debug_inspect(
    @renderer.hit_test(frame, test_metrics(), -2.0, 4.0),
    content=(
      #|{
      #|  kind: Outside,
      #|  line_number: 0,
      #|  column: 0,
      #|  offset: -1,
      #|  span_index: -1,
      #|}
    ),
  )
}

///|
test "hit test accounts for view zones displacing following lines" {
  let frame = test_frame()
  let metrics = test_metrics(view_zones=[{ anchor_line: 1, height_px: 36 }])
  // The zone band itself belongs to the widget, not the editor content.
  debug_inspect(
    @renderer.hit_test(frame, metrics, 60.0, 18.0 + 4.0),
    content=(
      #|{
      #|  kind: Outside,
      #|  line_number: 0,
      #|  column: 0,
      #|  offset: -1,
      #|  span_index: -1,
      #|}
    ),
  )
  // Below the zone, line 2 is shifted down by the zone height.
  debug_inspect(
    @renderer.hit_test(frame, metrics, 50.0 + 16.0, 18.0 + 36.0 + 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 2,
      #|  column: 2,
      #|  offset: 12,
      #|  span_index: 1,
      #|}
    ),
  )
  // Above the zone, line 1 is unaffected.
  debug_inspect(
    @renderer.hit_test(frame, metrics, 50.0 + 8.0 * 3.0, 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 1,
      #|  column: 3,
      #|  offset: 3,
      #|  span_index: 2,
      #|}
    ),
  )
}

///|
test "hit test reports empty lines and windowed-out lines as content empty" {
  let frame = test_frame()
  // Line 4 is empty: any column resolves to its start offset.
  debug_inspect(
    @renderer.hit_test(frame, test_metrics(), 70.0, 18.0 * 3.0 + 4.0),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 4,
      #|  column: 2,
      #|  offset: 24,
      #|  span_index: -1,
      #|}
    ),
  )
  let doc = @core.DocumentSnapshot("fn main {\n  let x = 1\n}\n\nfn other {}")
  let windowed = @renderer.build_frame(
    doc,
    { start_line: 0, end_line: 2 },
    @syntax.highlight(doc),
    @decorations.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  // Line 4 exists in the document but is outside the rendered window.
  debug_inspect(
    @renderer.hit_test(windowed, test_metrics(), 70.0, 18.0 * 3.0 + 4.0),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 4,
      #|  column: 0,
      #|  offset: -1,
      #|  span_index: -1,
      #|}
    ),
  )
}
