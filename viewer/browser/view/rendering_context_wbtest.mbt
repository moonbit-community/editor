///|
test "rendering geometry carriers preserve source rounding and order" {
  let floats = [
    FloatHorizontalRange::FloatHorizontalRange(1.49, 2.5),
    FloatHorizontalRange::FloatHorizontalRange(-1.5, -1.6),
    FloatHorizontalRange::FloatHorizontalRange(8.51, 0.49),
  ]
  let rounded = HorizontalRange::from(floats)
  assert_eq(rounded.length(), 3)
  assert_true(rounded[0] == { left: 1, width: 3 })
  assert_true(rounded[1] == { left: -1, width: -2 })
  assert_true(rounded[2] == { left: 9, width: 0 })
  assert_eq(rounded[0].to_string(), "[1,3]")
  assert_eq(floats[0].to_string(), "[1.49,2.5]")
  assert_eq(FloatHorizontalRange::compare(floats[0], floats[2]), -7.02)

  let position = HorizontalPosition::HorizontalPosition(true, -1.5)
  assert_true(position.outside_rendered_line)
  assert_eq(position.original_left, -1.5)
  assert_eq(position.left, -1)
  assert_eq(HorizontalPosition::HorizontalPosition(false, 2.5).left, 3)

  let visible = VisibleRanges::VisibleRanges(true, floats)
  assert_true(visible.outside_rendered_line)
  assert_eq(visible.ranges.length(), 3)

  let boundaries = HorizontalRange::from([
    FloatHorizontalRange::FloatHorizontalRange(4.0, -4.0),
    FloatHorizontalRange::FloatHorizontalRange(1.5, -2.5),
    FloatHorizontalRange::FloatHorizontalRange(-2.5, 3.49),
  ])
  assert_true(boundaries[0] == { left: 4, width: -4 })
  assert_true(boundaries[1] == { left: 2, width: -2 })
  assert_true(boundaries[2] == { left: -2, width: 3 })
  assert_eq(boundaries[2].to_string(), "[-2,3]")

  let carried = line_visible_ranges_from_raw([
    (true, 7, [(11, 3), (-5, 9)], false),
    (false, 2, [], true),
  ])
  assert_eq(carried.length(), 2)
  assert_true(carried[0].outside_rendered_line)
  assert_eq(carried[0].line_number, 7)
  assert_eq(carried[0].ranges.length(), 2)
  assert_true(carried[0].ranges[0] == { left: 11, width: 3 })
  assert_true(carried[0].ranges[1] == { left: -5, width: 9 })
  assert_false(carried[0].continues_on_next_line)
  assert_false(carried[1].outside_rendered_line)
  assert_eq(carried[1].line_number, 2)
  assert_eq(carried[1].ranges.length(), 0)
  assert_true(carried[1].continues_on_next_line)
}

///|
test "LineVisibleRanges first and last are order independent with strict ties" {
  let first_tie = LineVisibleRanges::LineVisibleRanges(
    false,
    2,
    [HorizontalRange::HorizontalRange(10.0, 1.0)],
    false,
  )
  let second_tie = LineVisibleRanges::LineVisibleRanges(
    true,
    2,
    [HorizontalRange::HorizontalRange(20.0, 2.0)],
    true,
  )
  let low = LineVisibleRanges::LineVisibleRanges(false, 1, [], true)
  let high = LineVisibleRanges::LineVisibleRanges(false, 9, [], false)
  let unsorted = Some([first_tie, high, low, second_tie])
  assert_true(LineVisibleRanges::first_line(None) is None)
  assert_true(LineVisibleRanges::last_line(None) is None)
  assert_true(LineVisibleRanges::first_line(Some([])) is None)
  assert_true(LineVisibleRanges::last_line(Some([])) is None)
  let singleton = Some([second_tie])
  assert_true(LineVisibleRanges::first_line(singleton) == Some(second_tie))
  assert_true(LineVisibleRanges::last_line(singleton) == Some(second_tie))
  assert_true(LineVisibleRanges::first_line(unsorted) == Some(low))
  assert_true(LineVisibleRanges::last_line(unsorted) == Some(high))

  // Strict replacement preserves the first carrier on an equal line number.
  let tied = Some([first_tie, second_tie])
  assert_true(LineVisibleRanges::first_line(tied) == Some(first_tie))
  assert_true(LineVisibleRanges::last_line(tied) == Some(first_tie))
}

///|
test "RenderingContext DOM facade returns null without rendered ViewLines" {
  install_view_lifecycle_test_browser()
  let model = @model.TextModel(
    @base_common.Uri::file("/rendering-context-facade-test.mbt"),
    "rendering-context-facade-test.mbt",
    "moonbit",
    1,
    "rev-1",
    "alpha",
  )
  let view_model = @view_model.ViewModel(model)
  let layout = @view_layout.ViewLayout::new(line_height=20, line_count=1)
  layout.set_viewport_size(width=80.0, height=20.0) |> ignore
  let view = View::View()
  let (context, _restricted) = view_event_test_overlay_render_context(
    view_model,
    layout,
    view.view_lines,
    1,
  )
  assert_true(
    context.lines_visible_ranges_for_range(Range(1, 1, 1, 2), false) is None,
  )
  assert_true(context.visible_range_for_position(Position(1, 1)) is None)
}

///|
test "RenderingContext snapshots current viewport and forwards includeViewZones" {
  install_view_lifecycle_test_browser()
  let model = @model.TextModel(
    @base_common.Uri::file("/rendering-context-snapshot-test.mbt"),
    "rendering-context-snapshot-test.mbt",
    "moonbit",
    1,
    "rev-1",
    "a\nb\nc\nd\ne\nf\ng\nh\ni\nj",
  )
  let view_model = @view_model.ViewModel(model)
  let layout = @view_layout.ViewLayout::new(line_height=20, line_count=10)
  layout.set_viewport_size(width=80.0, height=40.0) |> ignore
  layout.set_max_line_width(300.0) |> ignore
  layout.change_whitespace(accessor => {
    accessor.insert_whitespace(2, 0, 30.0, 0.0) |> ignore
  })
  |> ignore
  layout.scroll_to(scroll_top=37.0, scroll_left=23.0) |> ignore
  let before = layout.get_current_viewport()
  assert_eq(before.top, 37.0)
  assert_eq(before.left, 23.0)
  assert_eq(before.width, 80.0)
  assert_eq(before.height, 40.0)
  let view = View::View()
  let (context, _restricted) = view_event_test_overlay_render_context(
    view_model,
    layout,
    view.view_lines,
    1,
  )
  assert_eq(context.position.scroll_top, 37.0)
  assert_eq(context.position.scroll_left, 23.0)
  assert_eq(context.dimensions.width, 80.0)
  assert_eq(context.dimensions.height, 40.0)
  assert_eq(context.vertical_offset_for_line(3), 70.0)
  assert_eq(context.vertical_offset_for_line(3, include_view_zones=true), 40.0)
  assert_eq(context.line_height_for_line(9), 20.0)
  let widget_context = context.content_widgets_render_context()
  assert_eq(widget_context.scroll_top, 37.0)
  assert_eq(widget_context.scroll_left, 23.0)
  assert_eq(widget_context.viewport_width, 80.0)
  assert_eq(widget_context.viewport_height, 40.0)
  assert_eq((widget_context.vertical_offset_for_line)(3), 70.0)

  // Restricted geometry is a frame snapshot. Later layout mutations do not
  // rewrite the current RenderingContext or its capability projection.
  layout.scroll_to(scroll_top=99.0, scroll_left=44.0) |> ignore
  layout.set_viewport_size(width=60.0, height=30.0) |> ignore
  assert_eq(context.position.scroll_top, 37.0)
  assert_eq(context.position.scroll_left, 23.0)
  assert_eq(context.dimensions.width, 80.0)
  assert_eq(context.dimensions.height, 40.0)
  assert_eq(widget_context.scroll_top, 37.0)
  assert_eq(widget_context.scroll_left, 23.0)
  assert_eq(widget_context.viewport_width, 80.0)
  assert_eq(widget_context.viewport_height, 40.0)
}
