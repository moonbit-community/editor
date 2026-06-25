///|
test "finds decorations by range and offset" {
  let first = @decorations.Decoration(
    OffsetRange(2, 5),
    Diagnostic,
    "diag-error",
    message="fixture",
  )
  let second = @decorations.Decoration(
    OffsetRange(10, 12),
    SearchMatch,
    "search-hit",
  )
  let set = DecorationSet::from_array([first, second])
  assert_eq(set.between(OffsetRange(4, 11)).length(), 2)
  assert_eq(set.at_offset(3).length(), 1)
  assert_eq(set.at_offset(8).length(), 0)
}
