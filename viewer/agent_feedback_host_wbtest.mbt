// Headless behavior tests for the agent-feedback glue
// (`agent_feedback_host.mbt`): the DOM-free gates of `_updateHoverGlyph`,
// the reserved-lane store/restore, and the focus gate of
// `_onSelectionChanged`. The widget itself (positioning, keyboard, blur) is
// DOM-bound and covered in the browser suite. Runs over the unattached
// `with_test_viewer` harness; the test model's resource is
// `memory://test-model`.

///|
fn test_model_uri() -> @base_common.Uri {
  @base_common.Uri::memory("test-model")
}

///|
test "feedback lane reserves 18px while enabled and restores the base" {
  with_test_viewer("alpha\nbeta\ngamma", viewer => {
    let service = viewer.services.agent_feedback
    assert_eq(viewer.options.line_decorations_width, 0)
    service.set_feedback_enabled(test_model_uri(), true)
    assert_eq(viewer.options.line_decorations_width, 18)
    service.set_feedback_enabled(test_model_uri(), false)
    assert_eq(viewer.options.line_decorations_width, 0)
  })
}

///|
test "hover glyph follows non-empty lines of an enabled resource" {
  with_test_viewer("alpha\n   \ngamma", viewer => {
    let service = viewer.services.agent_feedback
    // Disabled resource: no glyph.
    viewer.update_agent_feedback_hover_glyph(1)
    assert_eq(viewer.agent_feedback_hover_line, -1)
    service.set_feedback_enabled(test_model_uri(), true)
    viewer.update_agent_feedback_hover_glyph(1)
    assert_eq(viewer.agent_feedback_hover_line, 1)
    assert_eq(viewer.agent_feedback_hover_decoration_ids.length(), 1)
    // Whitespace-only line: cleared.
    viewer.update_agent_feedback_hover_glyph(2)
    assert_eq(viewer.agent_feedback_hover_line, -1)
    assert_eq(viewer.agent_feedback_hover_decoration_ids.length(), 0)
    // Out-of-range line: stays cleared.
    viewer.update_agent_feedback_hover_glyph(9)
    assert_eq(viewer.agent_feedback_hover_line, -1)
  })
}

///|
test "lines with unresolved feedback refuse the add glyph" {
  with_test_viewer("alpha\nbeta\ngamma", viewer => {
    let service = viewer.services.agent_feedback
    service.set_feedback_enabled(test_model_uri(), true)
    let item = service.add_feedback(test_model_uri(), Range(3, 1, 3, 6), "note")
    viewer.update_agent_feedback_hover_glyph(3)
    assert_eq(viewer.agent_feedback_hover_line, -1)
    // Resolved feedback frees the line again.
    service.set_feedback_resolved(test_model_uri(), item.id, true)
    viewer.update_agent_feedback_hover_glyph(3)
    assert_eq(viewer.agent_feedback_hover_line, 3)
  })
}

///|
test "feedback landing on the glyph line clears the glyph" {
  with_test_viewer("alpha\nbeta\ngamma", viewer => {
    let service = viewer.services.agent_feedback
    service.set_feedback_enabled(test_model_uri(), true)
    viewer.update_agent_feedback_hover_glyph(2)
    assert_eq(viewer.agent_feedback_hover_line, 2)
    // The change subscription re-evaluates the glyph gates.
    service.add_feedback(test_model_uri(), Range(2, 1, 2, 5), "note") |> ignore
    assert_eq(viewer.agent_feedback_hover_line, -1)
  })
}

///|
test "selection changes without editor focus never open the input" {
  with_test_viewer("alpha\nbeta\ngamma", viewer => {
    let service = viewer.services.agent_feedback
    service.set_feedback_enabled(test_model_uri(), true)
    viewer.set_selection(
      @view_model.Selection::from_positions(Position(1, 1), Position(1, 6)),
    )
    // The unattached harness has no DOM focus, so `_onSelectionChanged`'s
    // `hasTextFocus` gate holds the input closed (and no widget DOM is
    // ever created headlessly).
    assert_eq(viewer.agent_feedback_input_visible, false)
    assert_true(viewer.agent_feedback_input is None)
  })
}
