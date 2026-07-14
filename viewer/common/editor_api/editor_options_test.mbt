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

///|
test "RenderLineHighlight exposes every canonical mode" {
  let modes : Array[RenderLineHighlight] = [None, Gutter, Line, All]
  assert_eq(modes.length(), 4)
  assert_eq(modes[0], None)
  assert_eq(modes[1], Gutter)
  assert_eq(modes[2], Line)
  assert_eq(modes[3], All)
}
