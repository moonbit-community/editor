///|
test "range helpers normalize and intersect" {
  let range = @core.Range(8, 3)
  assert_eq(range.start, 3)
  assert_eq(range.end, 8)
  assert_true(range.contains_offset(4))
  assert_false(range.contains_offset(8))
  assert_true(range.intersects(Range(7, 10)))
}

///|
test "clamps integers" {
  assert_eq(@core.clamp_int(-1, 0, 10), 0)
  assert_eq(@core.clamp_int(4, 0, 10), 4)
  assert_eq(@core.clamp_int(99, 0, 10), 10)
}
