///|
/// A half-open range of 1-based view-line numbers the view should render:
/// covers lines `start ..< end` in Monaco's view coordinate space.
pub(all) struct LineWindow {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
/// Lines assumed visible while the viewer height is still unmeasured.
let default_visible_lines = 60

///|
/// The window of lines worth rendering for the current scroll position:
/// the visible band plus `overscan` lines on each side, clamped to the
/// document.
pub fn visible_window(
  scroll_top : Double,
  viewport_height : Double,
  line_height : Int,
  line_count : Int,
  overscan : Int,
) -> LineWindow {
  if line_count <= 0 {
    return { start: 1, end: 1 }
  }
  let first_visible = (scroll_top / line_height.to_double()).to_int() + 1
  let visible = if viewport_height > 0.0 {
    (viewport_height / line_height.to_double()).to_int() + 1
  } else {
    default_visible_lines
  }
  let start = @base_common.clamp_int(
    first_visible - overscan,
    1,
    line_count + 1,
  )
  let end = @base_common.clamp_int(
    first_visible + visible + overscan,
    start,
    line_count + 1,
  )
  { start, end }
}

///|
/// Hysteresis for window updates: re-render only when the next window has
/// drifted by more than half the overscan, so native scrolling inside the
/// overscan band re-renders nothing.
pub fn window_needs_update(
  current : LineWindow,
  next : LineWindow,
  overscan : Int,
) -> Bool {
  let threshold = overscan / 2
  let start_shift = current.start - next.start
  let end_shift = current.end - next.end
  start_shift > threshold ||
  -start_shift > threshold ||
  end_shift > threshold ||
  -end_shift > threshold
}
