// Exact-label readonly adaptation of
// vscode/src/vs/editor/test/browser/controller/cursor.test.ts:2822-2851
// at pinned vscode commit
// `b18492a288de038fbc7643aae6de8247029d11bd`.
// Pinned file SHA-256:
// `73badec15dc0fbf27c06c4c5b80b0da12ccf9e8e624609570d611f96cfadba4c`.

///|
priv struct CursorTokenizationCountingTokenizer {
  calls : Ref[Int]
}

///|
impl @syntax.LineTokenizer for CursorTokenizationCountingTokenizer with fn initial_state(
  _self,
) {
  TokenizerState("cursor-tokenization-reference")
}

///|
impl @syntax.LineTokenizer for CursorTokenizationCountingTokenizer with fn tokenize_line(
  self,
  _line_text,
  state,
) {
  self.calls.val += 1
  ([], state)
}

///|
/// The readonly Viewer has no incremental `applyEdits` lane, so the upstream
/// insertion is adapted to `set_value`. Expanding one line to three makes a
/// stale sibling projection observable while retaining the source regression:
/// a cursor callback requests cheap tokenization during model content delivery.
test "issue #46314: ViewModel is out of sync with Model!" {
  let language_id = "cursor-tokenization-issue-46314"
  let calls = Ref(0)
  let registration = @syntax.tokenization_registry.register(language_id, CursorTokenizationCountingTokenizer::{
    calls,
  })
  let model = test_model("Just text", language_id~)
  let first = Viewer::Viewer()
  let second = Viewer::Viewer()
  first.set_model(Some(model))
  second.set_model(Some(model))
  first.set_position(Position(1, 5))

  let mut cursor_events = 0
  let projections_were_current = Ref(true)
  let subscription = first.on_did_change_cursor_position(_ => {
    cursor_events += 1
    model.tokenization.tokenize_if_cheap(1)
    projections_were_current.val = projections_were_current.val &&
      first.test_view_model().line_count() == model.get_line_count() &&
      second.test_view_model().line_count() == model.get_line_count() &&
      first.test_view_model().get_line_content(1) == model.get_line_content(1) &&
      second.test_view_model().get_line_content(1) == model.get_line_content(1)
  })

  assert_eq(calls.val, 0)
  first.set_value("-Just text\nsecond\nthird")
  assert_eq(cursor_events, 1)
  assert_true(projections_were_current.val)
  assert_eq(first.test_view_model().line_count(), 3)
  assert_eq(second.test_view_model().line_count(), 3)
  assert_eq(first.test_view_model().get_line_content(3), "third")
  assert_eq(second.test_view_model().get_line_content(3), "third")
  // Only the callback's cheap demand may lex. Attaching two Viewers, content
  // delivery, projection reads, and telemetry must remain passive.
  assert_eq(calls.val, 1)

  subscription.dispose()
  first.dispose()
  second.dispose()
  model.dispose()
  registration.dispose()
}
