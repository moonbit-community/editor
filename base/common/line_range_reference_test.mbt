// Conformance port of Monaco/VS Code's LineRange / LineRangeSet suites.
//
// Ports: vscode/src/vs/editor/test/common/core/lineRange.test.ts
// From vscode submodule commit 294fb350837dbaee37b949533fead4df4e0e8971.

///|
test "contains" {
  let r = LineRange::LineRange(2, 3)
  assert_eq(r.contains(1), false)
  assert_eq(r.contains(2), true)
  assert_eq(r.contains(3), false)
  assert_eq(r.contains(4), false)
}

///|
test "addRange" {
  let set = LineRangeSet::new()
  set.add_range(LineRange(2, 3))
  set.add_range(LineRange(3, 4))
  set.add_range(LineRange(10, 20))
  assert_eq(set.to_string(), "[2,4), [10,20)")
  set.add_range(LineRange(3, 21))
  assert_eq(set.to_string(), "[2,21)")
}

///|
test "getUnion" {
  let set1 = LineRangeSet::new(normalized_ranges=[
    LineRange(2, 3),
    LineRange(5, 7),
    LineRange(10, 20),
  ])
  let set2 = LineRangeSet::new(normalized_ranges=[
    LineRange(3, 4),
    LineRange(6, 8),
    LineRange(9, 11),
  ])
  let union = set1.get_union(set2)
  assert_eq(union.to_string(), "[2,4), [5,8), [9,20)")
}

///|
test "intersects" {
  let set1 = LineRangeSet::new(normalized_ranges=[
    LineRange(2, 3),
    LineRange(5, 7),
    LineRange(10, 20),
  ])
  assert_eq(set1.intersects(LineRange(1, 2)), false)
  assert_eq(set1.intersects(LineRange(1, 3)), true)
  assert_eq(set1.intersects(LineRange(3, 5)), false)
}
