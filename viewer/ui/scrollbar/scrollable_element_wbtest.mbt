///|
/// `_onMouseWheel` delta parity: a pixel-mode trackpad delta of +2.37px
/// normalizes to -2.37/40 wheel units, scales by `SCROLL_WHEEL_SENSITIVITY`
/// to -2.9625, and floors away from zero to a 3px scroll (Monaco scrolls
/// 1.25x the raw pixel delta, never less than a whole pixel).
test "wheel deltas scale by 50/40 and round away from zero" {
  let (delta_left, delta_top) = mouse_wheel_scroll_deltas({
    delta_x: 0.0,
    delta_y: -2.37 / 40.0,
  })
  assert_eq(delta_left, 0.0)
  assert_eq(delta_top, 3.0)
  // Scrolling up mirrors: raw -3px -> +0.075 units -> ceil(3.75) -> -4px.
  let (_, delta_top) = mouse_wheel_scroll_deltas({
    delta_x: 0.0,
    delta_y: 3.0 / 40.0,
  })
  assert_eq(delta_top, -4.0)
  // "otherwise low speed scrolling will never scroll": 0.2px still moves 1px.
  let (_, delta_top) = mouse_wheel_scroll_deltas({
    delta_x: 0.0,
    delta_y: -0.2 / 40.0,
  })
  assert_eq(delta_top, 1.0)
}

///|
/// `scrollPredominantAxis` (default true, matching `resolveOptions` and the
/// editor's scrollbar options): the minor axis is dropped so vertical
/// trackpad scrolling never drifts sideways; ties go to vertical.
test "predominant axis drops the minor delta" {
  let (delta_left, delta_top) = mouse_wheel_scroll_deltas({
    delta_x: -0.3 / 40.0,
    delta_y: -6.0 / 40.0,
  })
  assert_eq(delta_left, 0.0)
  assert_eq(delta_top, 8.0)
  let (delta_left, delta_top) = mouse_wheel_scroll_deltas({
    delta_x: -6.0 / 40.0,
    delta_y: -0.3 / 40.0,
  })
  assert_eq(delta_left, 8.0)
  assert_eq(delta_top, 0.0)
  let (delta_left, delta_top) = mouse_wheel_scroll_deltas(
    { delta_x: -0.3 / 40.0, delta_y: -6.0 / 40.0 },
    scroll_predominant_axis=false,
  )
  assert_eq(delta_left, 1.0)
  assert_eq(delta_top, 8.0)
}

///|
/// The alt-key `fastScrollSensitivity` branch (default 5).
test "alt key applies fast scroll sensitivity" {
  let (_, delta_top) = mouse_wheel_scroll_deltas(
    { delta_x: 0.0, delta_y: -8.0 / 40.0 },
    alt_key=true,
  )
  assert_eq(delta_top, 50.0)
}

///|
test "numberAsPixels adds px to numbers and preserves strings" {
  assert_eq(number_as_pixels(Pixels(12.5)), "12.5px")
  assert_eq(number_as_pixels(Raw("calc(100% - 10px)")), "calc(100% - 10px)")
}
