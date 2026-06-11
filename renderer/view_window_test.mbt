///|
test "visible window covers the viewport plus overscan, clamped" {
  // 600px viewport at 18px lines = 34 lines visible, 20 lines of overscan.
  debug_inspect(
    @renderer.visible_window(0.0, 600.0, 18, 10000, 20),
    content=(
      #|{ start: 0, end: 54 }
    ),
  )
  // Scrolled to line 500.
  debug_inspect(
    @renderer.visible_window(9000.0, 600.0, 18, 10000, 20),
    content=(
      #|{ start: 480, end: 554 }
    ),
  )
  // Bottom of the document clamps the end.
  debug_inspect(
    @renderer.visible_window(179400.0, 600.0, 18, 10000, 20),
    content=(
      #|{ start: 9946, end: 10000 }
    ),
  )
  // Unmeasured viewport falls back to a default band; tiny documents
  // render entirely.
  debug_inspect(
    @renderer.visible_window(0.0, 0.0, 18, 10000, 20),
    content=(
      #|{ start: 0, end: 80 }
    ),
  )
  debug_inspect(
    @renderer.visible_window(0.0, 600.0, 18, 10, 20),
    content=(
      #|{ start: 0, end: 10 }
    ),
  )
}

///|
test "window updates apply hysteresis of half the overscan" {
  let current : @renderer.LineWindow = { start: 100, end: 160 }
  // Drift inside half the overscan keeps the current window.
  assert_false(
    @renderer.window_needs_update(current, { start: 108, end: 168 }, 20),
  )
  // Drift beyond half the overscan re-renders.
  assert_true(
    @renderer.window_needs_update(current, { start: 111, end: 171 }, 20),
  )
  assert_true(
    @renderer.window_needs_update(current, { start: 89, end: 149 }, 20),
  )
  // A clamped edge can move only one bound; either bound counts.
  assert_true(
    @renderer.window_needs_update(current, { start: 100, end: 175 }, 20),
  )
}
