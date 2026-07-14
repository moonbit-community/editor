///|
test "RenderWhitespace exposes every canonical mode" {
  let modes : Array[RenderWhitespace] = [
    None,
    Boundary,
    Selection,
    Trailing,
    All,
  ]
  assert_eq(modes.length(), 5)
  assert_eq(modes[0], None)
  assert_eq(modes[1], Boundary)
  assert_eq(modes[2], Selection)
  assert_eq(modes[3], Trailing)
  assert_eq(modes[4], All)
}
