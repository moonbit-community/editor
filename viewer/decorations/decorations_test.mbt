///|
test "finds decorations by range and position" {
  let first = @decorations.Decoration(
    @base_common.Range::Range(1, 3, 1, 6),
    Diagnostic,
    "diag-error",
    message="fixture",
  )
  let second = @decorations.Decoration(
    @base_common.Range::Range(1, 11, 1, 13),
    SearchMatch,
    "search-hit",
  )
  let set = DecorationSet::from_array([first, second])
  assert_eq(set.between(@base_common.Range::Range(1, 5, 1, 12)).length(), 2)
  assert_eq(set.at_position(@base_common.Position::Position(1, 4)).length(), 1)
  assert_eq(set.at_position(@base_common.Position::Position(1, 9)).length(), 0)
}
