// Behavior tests transcribing the mouse-gate branches of
// `commentThreadZoneWidget.ts:53-110` and the hover-split arm of
// `CommentingRangeDecorator._doUpdate` (`commentsController.ts:181-249`).
// Upstream ships no unit tests for these units.

///|
fn uri(value : String) -> @base_common.Uri {
  match @base_common.Uri::parse(value) {
    ParsedUri(u) => u
    UriError(_) => abort("bad test uri: " + value)
  }
}

///|
fn thread_at(line : Int) -> @comments_common.CommentThread {
  {
    thread_id: "t" + line.to_string(),
    resource: uri("memory://review/a.mbt"),
    range: Range(line, 1, line, 1),
    comments: [],
    collapsible_state: Collapsed,
    is_template: false,
  }
}

///|
fn lane_summary(decorations : Array[@model.DeltaDecoration]) -> String {
  decorations
  .map(decoration => {
    let class_name = decoration.options.lines_decorations_class_name.unwrap()
    decoration.range.start_line_number.to_string() +
    "-" +
    decoration.range.end_line_number.to_string() +
    ":" +
    class_name
  })
  .join(" | ")
}

///|
test "parse_mouse_down_info transcribes the gate branches" {
  // Wrong target kind → null (`:64-66`).
  assert_true(parse_mouse_down_info(GutterLineNumbers, 4.0, 3, true) is None)
  assert_true(parse_mouse_down_info(ContentText, 4.0, 3, true) is None)
  // Offset past 20px collides with folding/git decorations → null (`:71-73`).
  assert_true(
    parse_mouse_down_info(GutterLineDecorations, 21.0, 3, true) is None,
  )
  // No glyph on the line (`commentsController.ts:1108` className gate) → null.
  assert_true(
    parse_mouse_down_info(GutterLineDecorations, 4.0, 3, false) is None,
  )
  // No line → null (`:56-58`).
  assert_true(
    parse_mouse_down_info(GutterLineDecorations, 4.0, 0, true) is None,
  )
  assert_eq(
    parse_mouse_down_info(GutterLineDecorations, 4.0, 3, true).unwrap(),
    3,
  )
}

///|
test "mouse up only matches the mousedown line on the lane" {
  let controller = CommentController::new()
  // No prior mousedown → null.
  assert_true(controller.on_mouse_up(GutterLineDecorations, 3, true) is None)
  // Down and up on the same lane line → act.
  controller.on_mouse_down(GutterLineDecorations, 4.0, 3, true)
  assert_eq(controller.on_mouse_up(GutterLineDecorations, 3, true).unwrap(), 3)
  // The pending down is consumed.
  assert_true(controller.on_mouse_up(GutterLineDecorations, 3, true) is None)
  // Up on a different line → null (`isMouseUpEventMatchMouseDown:104`).
  controller.on_mouse_down(GutterLineDecorations, 4.0, 3, true)
  assert_true(controller.on_mouse_up(GutterLineDecorations, 5, true) is None)
  // Up off the lane → null (`:106-108`).
  controller.on_mouse_down(GutterLineDecorations, 4.0, 3, true)
  assert_true(controller.on_mouse_up(ContentText, 3, true) is None)
  // Down rejected by the gates never matches an up.
  controller.on_mouse_down(GutterLineDecorations, 25.0, 3, true)
  assert_true(controller.on_mouse_up(GutterLineDecorations, 3, true) is None)
}

///|
test "update_hover reports changes once" {
  let controller = CommentController::new()
  assert_true(controller.update_hover(4))
  assert_false(controller.update_hover(4))
  assert_true(controller.update_hover(-1))
  assert_false(controller.update_hover(-1))
}

///|
test "commenting range decorations split around the hovered line" {
  let ranges : Array[@base_common.Range] = [Range(2, 1, 6, 1)]
  // No hover: the whole range renders the base glyph.
  assert_eq(
    lane_summary(commenting_range_decorations(ranges, -1, [])),
    "2-6:comment-range-glyph comment-diff-added",
  )
  // Hover inside: before / hover / after split (`_doUpdate:229-241`).
  assert_eq(
    lane_summary(commenting_range_decorations(ranges, 4, [])),
    "2-3:comment-range-glyph comment-diff-added | 4-4:comment-range-glyph line-hover | 5-6:comment-range-glyph comment-diff-added",
  )
  // Hover on the first line: no before-remainder.
  assert_eq(
    lane_summary(commenting_range_decorations(ranges, 2, [])),
    "2-2:comment-range-glyph line-hover | 3-6:comment-range-glyph comment-diff-added",
  )
  // Hover outside the range: unchanged base decoration.
  assert_eq(
    lane_summary(commenting_range_decorations(ranges, 9, [])),
    "2-6:comment-range-glyph comment-diff-added",
  )
}

///|
test "hovering a line that carries a thread suppresses the plus affordance" {
  // `_lineHasThread` (`_doUpdate:233-235`): the emphasis piece is skipped,
  // the remainders still split.
  assert_eq(
    lane_summary(commenting_range_decorations([Range(2, 1, 6, 1)], 4, [4])),
    "2-3:comment-range-glyph comment-diff-added | 5-6:comment-range-glyph comment-diff-added",
  )
}

///|
test "thread glyphs render on the thread's end line" {
  let decorations = thread_glyph_decorations([thread_at(3), thread_at(7)])
  assert_eq(
    lane_summary(decorations),
    "3-3:comment-range-glyph comment-thread | 7-7:comment-range-glyph comment-thread",
  )
  assert_true(decorations[0].options.is_whole_line)
  assert_eq(
    decorations[0].options.description,
    comment_glyph_decoration_description,
  )
}

///|
test "line_in_commenting_context covers ranges and thread lines" {
  let ranges : Array[@base_common.Range] = [Range(2, 1, 4, 1)]
  let threads = [thread_at(9)]
  assert_true(line_in_commenting_context(ranges, threads, 2))
  assert_true(line_in_commenting_context(ranges, threads, 4))
  assert_true(line_in_commenting_context(ranges, threads, 9))
  assert_false(line_in_commenting_context(ranges, threads, 5))
  assert_false(line_in_commenting_context([], [], 1))
}
