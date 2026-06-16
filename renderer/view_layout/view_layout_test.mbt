///|
test "scrollable clamps positions inside its dimensions" {
  let scrollable = @view_layout.Scrollable::new()
  // Without dimensions everything clamps to the origin.
  assert_true(
    scrollable.set_position({ scroll_left: 50.0, scroll_top: 100.0 }) is None,
  )
  scrollable.set_dimensions({
    width: 800.0,
    scroll_width: 1000.0,
    height: 600.0,
    scroll_height: 1800.0,
  })
  |> ignore
  let change = scrollable.set_position({ scroll_left: 50.0, scroll_top: 100.0 })
  debug_inspect(
    change,
    content=(
      #|Some(
      #|  {
      #|    position: { scroll_left: 50, scroll_top: 100 },
      #|    delta_left: 50,
      #|    delta_top: 100,
      #|    left_changed: true,
      #|    top_changed: true,
      #|    dimensions_changed: false,
      #|  },
      #|)
    ),
  )
  // Overshoot clamps to content minus viewport; undershoot clamps to zero.
  scrollable.set_position({ scroll_left: 9999.0, scroll_top: 99999.0 })
  |> ignore
  debug_inspect(
    scrollable.position(),
    content=(
      #|{ scroll_left: 200, scroll_top: 1200 }
    ),
  )
  scrollable.set_position({ scroll_left: -5.0, scroll_top: -5.0 }) |> ignore
  debug_inspect(
    scrollable.position(),
    content=(
      #|{ scroll_left: 0, scroll_top: 0 }
    ),
  )
  // A clamped no-op answers None.
  assert_true(
    scrollable.set_position({ scroll_left: -1.0, scroll_top: -1.0 }) is None,
  )
}

///|
test "shrinking dimensions re-clamps the position as one change fact" {
  let scrollable = @view_layout.Scrollable::new()
  scrollable.set_dimensions({
    width: 100.0,
    scroll_width: 100.0,
    height: 100.0,
    scroll_height: 1000.0,
  })
  |> ignore
  scrollable.set_position({ scroll_left: 0.0, scroll_top: 900.0 }) |> ignore
  let change = scrollable.set_dimensions({
    width: 100.0,
    scroll_width: 100.0,
    height: 100.0,
    scroll_height: 400.0,
  })
  debug_inspect(
    change,
    content=(
      #|Some(
      #|  {
      #|    position: { scroll_left: 0, scroll_top: 300 },
      #|    delta_left: 0,
      #|    delta_top: -600,
      #|    left_changed: false,
      #|    top_changed: true,
      #|    dimensions_changed: true,
      #|  },
      #|)
    ),
  )
  // Content extents never report smaller than the viewport.
  scrollable.set_dimensions({
    width: 500.0,
    scroll_width: 10.0,
    height: 600.0,
    scroll_height: 10.0,
  })
  |> ignore
  debug_inspect(
    scrollable.dimensions(),
    content=(
      #|{ width: 500, scroll_width: 500, height: 600, scroll_height: 600 }
    ),
  )
}

///|
test "lines layout answers offsets and lines for uniform heights" {
  let lines = @view_layout.LinesLayout::new(line_height=18, line_count=100)
  assert_eq(lines.vertical_offset_for_line(0), 0.0)
  assert_eq(lines.vertical_offset_for_line(10), 180.0)
  // One past the end probes the bottom edge; beyond clamps.
  assert_eq(lines.vertical_offset_for_line(100), 1800.0)
  assert_eq(lines.vertical_offset_for_line(999), 1800.0)
  assert_eq(lines.line_at_vertical_offset(0.0), 0)
  assert_eq(lines.line_at_vertical_offset(17.9), 0)
  assert_eq(lines.line_at_vertical_offset(18.0), 1)
  assert_eq(lines.line_at_vertical_offset(99999.0), 99)
  assert_eq(lines.content_height(), 1800.0)
  let empty = @view_layout.LinesLayout::new(line_height=18)
  assert_eq(empty.line_at_vertical_offset(50.0), 0)
  assert_eq(empty.content_height(), 0.0)
}

///|
/// The layout-derived window must agree with the free `visible_window`
/// the browser cell uses today, for the same scroll state.
test "view layout windows match visible_window" {
  let layout = @view_layout.ViewLayout::new(line_height=18, line_count=10000)
  layout.set_viewport_size(width=800.0, height=600.0) |> ignore
  for scroll_top in ([0.0, 9000.0, 179400.0] : Array[Double]) {
    layout.scroll_to(scroll_top~) |> ignore
    let expected = @view_layout.visible_window(scroll_top, 600.0, 18, 10000, 20)
    let derived = layout.visible_window(overscan=20)
    assert_eq(derived.start, expected.start)
    assert_eq(derived.end, expected.end)
  }
  // Unmeasured viewport falls back to the same default band.
  let unmeasured = @view_layout.ViewLayout::new(
    line_height=18,
    line_count=10000,
  )
  let expected = @view_layout.visible_window(0.0, 0.0, 18, 10000, 20)
  let derived = unmeasured.visible_window(overscan=20)
  assert_eq(derived.start, expected.start)
  assert_eq(derived.end, expected.end)
  // Tiny documents render entirely.
  let tiny = @view_layout.ViewLayout::new(line_height=18, line_count=10)
  tiny.set_viewport_size(width=800.0, height=600.0) |> ignore
  debug_inspect(
    tiny.visible_window(overscan=20),
    content=(
      #|{ start: 0, end: 10 }
    ),
  )
}

///|
test "view layout hysteresis matches window_needs_update" {
  let layout = @view_layout.ViewLayout::new(line_height=18, line_count=10000)
  layout.set_viewport_size(width=800.0, height=600.0) |> ignore
  layout.scroll_to(scroll_top=9000.0) |> ignore
  let rendered = layout.visible_window(overscan=20)
  // Drift inside half the overscan keeps the rendered window.
  layout.scroll_to(scroll_top=9000.0 + 18.0 * 8.0) |> ignore
  assert_false(layout.window_needs_update(rendered, overscan=20))
  // Drift beyond half the overscan re-renders.
  layout.scroll_to(scroll_top=9000.0 + 18.0 * 11.0) |> ignore
  assert_true(layout.window_needs_update(rendered, overscan=20))
}

///|
test "view layout derives scroll dimensions from document and viewport" {
  let layout = @view_layout.ViewLayout::new(line_height=18, line_count=10000)
  layout.set_viewport_size(width=800.0, height=600.0) |> ignore
  debug_inspect(
    layout.dimensions(),
    content=(
      #|{ width: 800, scroll_width: 800, height: 600, scroll_height: 180000 }
    ),
  )
  // The widest measured line drives horizontal scrolling.
  layout.set_content_width(2000.0) |> ignore
  assert_eq(layout.dimensions().scroll_width, 2000.0)
  // Replacing the document re-clamps the scroll position.
  layout.scroll_to(scroll_top=179400.0) |> ignore
  let change = layout.set_line_count(100)
  debug_inspect(
    change,
    content=(
      #|Some(
      #|  {
      #|    position: { scroll_left: 0, scroll_top: 1200 },
      #|    delta_left: 0,
      #|    delta_top: -178200,
      #|    left_changed: false,
      #|    top_changed: true,
      #|    dimensions_changed: true,
      #|  },
      #|)
    ),
  )
  // The window origin is the content-space top of the window start.
  let window = layout.visible_window(overscan=20)
  assert_eq(layout.window_origin(window), (window.start * 18).to_double())
}
