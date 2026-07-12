///|
test "model-line digit band preserves measured outer width before LayoutInfo" {
  with_test_viewer(["1", "2", "3", "4", "5", "6", "7", "8", "9"].join("\n"), viewer => {
    viewer.options = ViewerOptions(line_numbers_min_chars=1, folding=false)
    viewer.measured_content_width = 360.0
    viewer.measured_height = 180.0
    let view_model = viewer.test_view_model()
    let previous_content_left = viewer.gutter_width(9)
    let current_content_left = viewer.gutter_width(10)
    assert_true(current_content_left > previous_content_left)
    let measured_outer_width = previous_content_left +
      viewer.measured_content_width

    assert_true(viewer.sync_content_box_for_model_line_count(view_model, 9, 10))
    assert_eq(
      current_content_left + viewer.measured_content_width,
      measured_outer_width,
    )
    assert_eq(
      view_model.view_layout.dimensions().width,
      viewer.measured_content_width,
    )
    let retained_width = viewer.measured_content_width
    assert_false(
      viewer.sync_content_box_for_model_line_count(view_model, 10, 11),
    )
    assert_eq(viewer.measured_content_width, retained_width)
  })
}
