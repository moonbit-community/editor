// Track F (deviations-closeout): inlay hints reach the projection through
// the model's injected-text decoration storage, and injected-text
// decoration deltas rebuild the projection through the decoration-change
// event (`affects_injected_text`).

///|
test "inlay hints flow through decoration storage into the projection" {
  with_test_viewer("let x = 1", viewer => {
    assert_eq(
      viewer.test_view_model().lines().get_view_line_data(1).content,
      "let x = 1",
    )
    // The producer path: hints arrive, decorations are rewritten, and the
    // change event rebuilds the projection — no explicit re-render call.
    viewer.inlay_hints_controller().unwrap().inlay_hints = [
      InlayHint(Position(1, 6), ": Int", kind=TypeHint),
    ]
    viewer.sync_inlay_hint_decorations()
    let line = viewer.test_view_model().lines().get_view_line_data(1)
    assert_eq(line.content, "let x: Int = 1")
    // The injected span carries the hint's source index for hover lookup.
    assert_eq(
      viewer.test_view_model().injected_text_index_at(Position(1, 6)),
      0,
    )
    // The model's injected-text query surfaces the stored decoration.
    match viewer.text_model {
      Some(model) =>
        assert_eq(model.get_injected_text_decorations().length(), 1)
      None => fail("expected a model")
    }
    // Hint removal flows the same way: the delta clears the decorations and
    // the projection returns to the plain line.
    viewer.inlay_hints_controller().unwrap().inlay_hints = []
    viewer.sync_inlay_hint_decorations()
    assert_eq(
      viewer.test_view_model().lines().get_view_line_data(1).content,
      "let x = 1",
    )
  })
}

///|
test "moving a hint re-projects at the new anchor" {
  with_test_viewer("abcdef", viewer => {
    viewer.inlay_hints_controller().unwrap().inlay_hints = [
      InlayHint(Position(1, 3), "XX", kind=ParameterHint),
    ]
    viewer.sync_inlay_hint_decorations()
    assert_eq(
      viewer.test_view_model().lines().get_view_line_data(1).content,
      "abXXcdef",
    )
    viewer.inlay_hints_controller().unwrap().inlay_hints = [
      InlayHint(Position(1, 5), "XX", kind=ParameterHint),
    ]
    viewer.sync_inlay_hint_decorations()
    assert_eq(
      viewer.test_view_model().lines().get_view_line_data(1).content,
      "abcdXXef",
    )
  })
}
