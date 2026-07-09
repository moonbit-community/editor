///|
/// Registers the generic fallback lexer for the `moonbit` language id the test
/// models carry (the real lexers are registered by the shell, not the common
/// tier), so the goldens keep PlainTokenizer's token segmentation. Idempotent;
/// the registration lives for the test binary.
fn register_plain_moonbit() -> Unit {
  @syntax.tokenization_registry.register(
    "moonbit",
    @syntax.PlainTokenizer::new(),
  )
  |> ignore
}

///|
fn plain_text_model(text : String) -> @model.TextModel {
  register_plain_moonbit()
  TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/plain.mbt",
    ),
    "",
    "moonbit",
    1,
    "",
    text,
  )
}

///|
fn hit_test_view(
  window? : @view_layout.LineWindow,
) -> (@view_model.ViewModel, @view_layout.LineWindow) {
  let model = plain_text_model("fn main {\n  let x = 1\n}\n\nfn other {}")
  let view_model = @view_model.ViewModel(model)
  let window = match window {
    Some(window) => window
    None => { start: 1, end: view_model.line_count() + 1 }
  }
  (view_model, window)
}

///|
fn projected_hit_test_view() -> (@view_model.ViewModel, @view_layout.LineWindow) {
  let model = plain_text_model("abcdefghij")
  let view_model = @view_model.ViewModel::with_options(
    model,
    @view_model.ViewModelOptions::soft_wrap(5),
  )
  (view_model, { start: 1, end: view_model.line_count() + 1 })
}

///|
fn inlay_hint_hit_test_view() -> (
  @view_model.ViewModel,
  @view_layout.LineWindow,
) {
  // The hint is written as an `after` injected-text decoration on the
  // backing model (Track F: injected text lives in decoration storage).
  let model = @model.TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/hit-test.mbt",
    ),
    "hit-test.mbt",
    "moonbit",
    1,
    "rev-1",
    "let x = 1",
  )
  model.delta_decorations([], [
    {
      range: Range(1, 6, 1, 6),
      options: ModelDecorationOptions(
        "",
        description="inlay-hint",
        show_if_collapsed=true,
        after=InjectedTextOptions(
          ": Int",
          inline_class_name="inlay-hint inlay-hint-type",
          attached_index=0,
        ),
      ),
    },
  ])
  |> ignore
  register_plain_moonbit()
  let view_model = @view_model.ViewModel::with_options(
    model,
    @view_model.ViewModelOptions::no_wrap(),
  )
  (view_model, { start: 1, end: view_model.line_count() + 1 })
}

///|
fn test_metrics(
  scroll_top? : Double = 0.0,
  scroll_left? : Double = 0.0,
  line_decorations_width? : Double = 0.0,
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
    line_decorations_width,
    view_zones,
  }
}

///|
test "hit test maps wrapped view line coordinates to a view position" {
  let (view_model, window) = projected_hit_test_view()
  assert_eq(view_model.line_count(), 2)
  let target = @common.hit_test(
    view_model,
    window,
    test_metrics(),
    50.0 + 8.0 * 2.0,
    18.0 + 4.0,
  )
  assert_true(target.kind == ContentText)
  assert_eq(target.line_number, 2)
  assert_eq(target.column, 2)
  let gutter = @common.hit_test(
    view_model,
    window,
    test_metrics(),
    10.0,
    18.0 + 4.0,
  )
  assert_true(gutter.kind == GutterLineNumbers)
  assert_eq(gutter.line_number, 2)
}

///|
test "hit test reports injected text hits with their view column and index" {
  let (view_model, window) = inlay_hint_hit_test_view()
  assert_eq(view_model.lines().get_view_line_data(1).content, "let x: Int = 1")
  let target = @common.hit_test(
    view_model,
    window,
    test_metrics(),
    50.0 + 8.0 * 6.0,
    4.0,
  )
  assert_true(target.kind == ContentText)
  assert_eq(target.column, 6)
  assert_eq(target.injected_text_index, 0)
  let source_after_hint = @common.hit_test(
    view_model,
    window,
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
  let (view_model, window) = hit_test_view()
  // Inside the gutter band of the first line.
  debug_inspect(
    @common.hit_test(view_model, window, test_metrics(), 10.0, 4.0),
    content=(
      #|{
      #|  kind: GutterLineNumbers,
      #|  line_number: 1,
      #|  column: 0,
      #|  token_index: -1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
  // Column 3 of line 1 lands inside the `main` identifier span.
  debug_inspect(
    @common.hit_test(view_model, window, test_metrics(), 50.0 + 8.0 * 3.0, 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 1,
      #|  column: 3,
      #|  token_index: 2,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
  // Past the end of line 1's text.
  debug_inspect(
    @common.hit_test(view_model, window, test_metrics(), 50.0 + 8.0 * 30.0, 4.0),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 1,
      #|  column: 9,
      #|  token_index: -1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: 168,
      #|}
    ),
  )
}

///|
test "hit test splits the gutter into line numbers and the decorations lane" {
  let (view_model, window) = hit_test_view()
  let metrics = test_metrics(line_decorations_width=24.0)
  // Left of the lane boundary (gutter_width 50 - lane 24 = 26): line numbers.
  let numbers = @common.hit_test(view_model, window, metrics, 25.0, 4.0)
  assert_true(numbers.kind == GutterLineNumbers)
  assert_eq(numbers.line_number, 1)
  assert_eq(numbers.gutter_offset_x, 0.0)
  // At and past the boundary: the line-decorations lane, with the offset
  // measured from the lane's left edge (Monaco's comment gate reads it as
  // `gutterOffsetX`).
  let lane = @common.hit_test(view_model, window, metrics, 26.0, 4.0)
  assert_true(lane.kind == GutterLineDecorations)
  assert_eq(lane.line_number, 1)
  assert_eq(lane.gutter_offset_x, 0.0)
  let lane_inner = @common.hit_test(
    view_model,
    window,
    metrics,
    40.0,
    18.0 + 4.0,
  )
  assert_true(lane_inner.kind == GutterLineDecorations)
  assert_eq(lane_inner.line_number, 2)
  assert_eq(lane_inner.gutter_offset_x, 14.0)
  // With no lane configured the whole band stays line numbers.
  let no_lane = @common.hit_test(view_model, window, test_metrics(), 40.0, 4.0)
  assert_true(no_lane.kind == GutterLineNumbers)
}

///|
test "hit test maps scrolled coordinates and below-content space" {
  let (view_model, window) = hit_test_view()
  // Scrolled down one line: y=4 now lands on line 2, column 2 -> `let`.
  debug_inspect(
    @common.hit_test(
      view_model,
      window,
      test_metrics(scroll_top=18.0),
      50.0 + 16.0,
      4.0,
    ),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 2,
      #|  column: 2,
      #|  token_index: 1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
  // Below the last line.
  debug_inspect(
    @common.hit_test(view_model, window, test_metrics(), 60.0, 18.0 * 5.0 + 4.0),
    content=(
      #|{
      #|  kind: BelowContent,
      #|  line_number: 5,
      #|  column: 0,
      #|  token_index: -1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
  // Outside the viewer box.
  debug_inspect(
    @common.hit_test(view_model, window, test_metrics(), -2.0, 4.0),
    content=(
      #|{
      #|  kind: OutsideEditor,
      #|  line_number: 0,
      #|  column: 0,
      #|  token_index: -1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
}

///|
test "hit test accounts for view zones displacing following lines" {
  let (view_model, window) = hit_test_view()
  let metrics = test_metrics(view_zones=[{ anchor_line: 1, height_px: 36 }])
  // The zone band itself belongs to the widget, not the editor content.
  debug_inspect(
    @common.hit_test(view_model, window, metrics, 60.0, 18.0 + 4.0),
    content=(
      #|{
      #|  kind: OutsideEditor,
      #|  line_number: 0,
      #|  column: 0,
      #|  token_index: -1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
  // Below the zone, line 2 is shifted down by the zone height.
  debug_inspect(
    @common.hit_test(
      view_model,
      window,
      metrics,
      50.0 + 16.0,
      18.0 + 36.0 + 4.0,
    ),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 2,
      #|  column: 2,
      #|  token_index: 1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
  // Above the zone, line 1 is unaffected.
  debug_inspect(
    @common.hit_test(view_model, window, metrics, 50.0 + 8.0 * 3.0, 4.0),
    content=(
      #|{
      #|  kind: ContentText,
      #|  line_number: 1,
      #|  column: 3,
      #|  token_index: 2,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
}

///|
test "hit test reports empty lines and windowed-out lines as content empty" {
  let (view_model, window) = hit_test_view()
  // Line 4 is empty: any column resolves to its start offset. x=70 sits 2.5
  // glyphs past the content origin and rounds to the nearer column 3.
  debug_inspect(
    @common.hit_test(view_model, window, test_metrics(), 70.0, 18.0 * 3.0 + 4.0),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 4,
      #|  column: 0,
      #|  token_index: -1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: 20,
      #|}
    ),
  )
  let (windowed_view_model, windowed_window) = hit_test_view(window={
    start: 1,
    end: 3,
  })
  // Line 4 exists in the document but is outside the rendered window.
  debug_inspect(
    @common.hit_test(
      windowed_view_model,
      windowed_window,
      test_metrics(),
      70.0,
      18.0 * 3.0 + 4.0,
    ),
    content=(
      #|{
      #|  kind: ContentEmpty,
      #|  line_number: 4,
      #|  column: 0,
      #|  token_index: -1,
      #|  injected_text_index: -1,
      #|  gutter_offset_x: 0,
      #|  horizontal_distance_to_text: -1,
      #|}
    ),
  )
}
