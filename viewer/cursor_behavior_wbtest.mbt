// Cursor/selection behavior suite — the slice of vscode's
// editor/test/browser/controller/cursor.test.ts that is pure semantic state
// (model/view selections), driven through the headless harness in
// `test_viewer_wbtest.mbt`. These never belonged in a browser: they assert on
// positions and ranges, not pixels.

///|
/// `MoveTo` (a plain click) collapses the selection at the target, reported in
/// model coordinates. With no wrapping the view position passed to `move_to`
/// equals the model position the converter derives.
test "MoveTo positions the cursor in model coordinates" {
  with_test_viewer("line one\nline two\nline three", viewer => {
    @cursor.move_to(viewer.test_cursor(), Position(2, 5))
    assert_cursor(
      viewer,
      @view_model.Selection::new(Position(2, 5), Position(2, 5)),
    )
  })
}

///|
test "move_to collapses the selection at the target position" {
  with_test_viewer("line one\nline two\nline three", viewer => {
    @cursor.move_to(viewer.test_cursor(), Position(1, 3))
    let selection = viewer.test_cursor().get_model_selection()
    assert_true(selection.is_empty())
    assert_position(selection.get_position(), Position(1, 3))
  })
}

///|
/// `MoveToSelect` (shift-click / drag) extends to the target while keeping the
/// existing anchor, so the result is a ranged selection.
test "move_to_select extends the selection from the anchor" {
  with_test_viewer("line one\nline two\nline three", viewer => {
    let cursor = viewer.test_cursor()
    @cursor.move_to(cursor, Position(1, 3))
    @cursor.move_to_select(cursor, Position(1, 7))
    assert_cursor(
      viewer,
      @view_model.Selection::new(Position(1, 3), Position(1, 7)),
    )
  })
}

///|
test "move_to_select spans multiple model lines" {
  with_test_viewer("line one\nline two\nline three", viewer => {
    let cursor = viewer.test_cursor()
    @cursor.move_to(cursor, Position(1, 6))
    @cursor.move_to_select(cursor, Position(3, 4))
    let selection = viewer.test_cursor().get_model_selection()
    assert_false(selection.is_empty())
    assert_position(selection.start(), Position(1, 6))
    assert_position(selection.end(), Position(3, 4))
  })
}

///|
/// Without wrapping the model and view selections coincide — the identity the
/// coordinates converter guarantees in the no-projection case.
test "view and model selections coincide without wrapping" {
  with_test_viewer("line one\nline two\nline three", viewer => {
    let cursor = viewer.test_cursor()
    @cursor.move_to(cursor, Position(2, 2))
    @cursor.move_to_select(cursor, Position(2, 6))
    assert_selection_eq(
      cursor.get_view_selection(),
      cursor.get_model_selection(),
    )
  })
}
