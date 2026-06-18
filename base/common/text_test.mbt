///|
test "range normalizes endpoints and tests offsets" {
  let range : Range = Range(8, 3)
  assert_eq(range.start, 3)
  assert_eq(range.end, 8)
  assert_true(range.contains_offset(3))
  assert_true(!range.contains_offset(8))
  assert_true(range.intersects(Range(7, 10)))
  assert_true(!range.intersects(Range(8, 10)))
}

///|
test "clamps ints" {
  assert_eq(clamp_int(-1, 0, 10), 0)
  assert_eq(clamp_int(4, 0, 10), 4)
  assert_eq(clamp_int(99, 0, 10), 10)
}
