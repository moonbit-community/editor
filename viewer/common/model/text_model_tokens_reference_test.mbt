///| Faithful conformance port of vscode's `RangePriorityQueueImpl` suite.
///
/// Source: `vscode/src/vs/editor/test/common/model/textModelTokens.test.ts` at
/// `b18492a288de038fbc7643aae6de8247029d11bd`. Both `test(...)` cases preserve
/// their original names. Branch-derived cases below cover queue members the
/// two upstream tests do not call directly.

///|
fn or_strings(ranges : Array[@base_common.OffsetRange]) -> Array[String] {
  ranges.map(fn(r) { r.to_string() })
}

///|
/// Element-wise string-array equality (avoids the deprecated `Show`-based
/// `assert_eq` on arrays while keeping per-element failure detail).
fn assert_str_array_eq(
  actual : Array[String],
  expected : Array[String],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(actual[i], expected[i])
  }
}

///|
test "addRange" {
  let ranges : Array[@base_common.OffsetRange] = []
  @base_common.OffsetRange::add_range(OffsetRange(0, 2), ranges)
  @base_common.OffsetRange::add_range(OffsetRange(10, 13), ranges)
  @base_common.OffsetRange::add_range(OffsetRange(20, 24), ranges)
  assert_str_array_eq(or_strings(ranges), ["[0, 2)", "[10, 13)", "[20, 24)"])
  @base_common.OffsetRange::add_range(OffsetRange(2, 10), ranges)
  assert_str_array_eq(or_strings(ranges), ["[0, 13)", "[20, 24)"])
  @base_common.OffsetRange::add_range(OffsetRange(14, 19), ranges)
  assert_str_array_eq(or_strings(ranges), ["[0, 13)", "[14, 19)", "[20, 24)"])
  @base_common.OffsetRange::add_range(OffsetRange(10, 22), ranges)
  assert_str_array_eq(or_strings(ranges), ["[0, 24)"])
  @base_common.OffsetRange::add_range(OffsetRange(-1, 29), ranges)
  assert_str_array_eq(or_strings(ranges), ["[-1, 29)"])
  @base_common.OffsetRange::add_range(OffsetRange(-10, -5), ranges)
  assert_str_array_eq(or_strings(ranges), ["[-10, -5)", "[-1, 29)"])
}

///|
test "addRangeAndResize" {
  let queue = RangePriorityQueueImpl::new()
  queue.add_range(OffsetRange(0, 20))
  queue.add_range(OffsetRange(100, 120))
  queue.add_range(OffsetRange(200, 220))

  // disjoint
  queue.add_range_and_resize(OffsetRange(25, 27), 0)
  assert_str_array_eq(or_strings(queue.get_ranges()), [
    "[0, 20)", "[98, 118)", "[198, 218)",
  ])
  queue.add_range_and_resize(OffsetRange(19, 20), 0)
  assert_str_array_eq(or_strings(queue.get_ranges()), [
    "[0, 19)", "[97, 117)", "[197, 217)",
  ])
  queue.add_range_and_resize(OffsetRange(19, 97), 0)
  assert_str_array_eq(or_strings(queue.get_ranges()), ["[0, 39)", "[119, 139)"])
  queue.add_range_and_resize(OffsetRange(-1000, 1000), 0)
  assert_str_array_eq(or_strings(queue.get_ranges()), [])
}

///|
test "RangePriorityQueueImpl min removeMin delete and toString" {
  let queue = RangePriorityQueueImpl::new()
  assert_true(queue.min() is None)
  assert_true(queue.remove_min() is None)
  queue.add_range(OffsetRange(1, 2))
  queue.add_range(OffsetRange(4, 8))
  assert_eq(queue.to_string(), "[1, 2) + [4, 8)")
  assert_true(queue.min() == Some(1))
  assert_true(queue.remove_min() == Some(1))
  assert_eq(queue.to_string(), "[4, 8)")
  queue.delete(4)
  assert_eq(queue.to_string(), "[5, 8)")
  queue.delete(7)
  assert_eq(queue.to_string(), "[5, 7)")
  queue.delete(6)
  assert_eq(queue.to_string(), "[5, 6)")
  queue.delete(5)
  assert_eq(queue.to_string(), "")
  queue.delete(999)
  assert_eq(queue.to_string(), "")
}

///|
test "RangePriorityQueueImpl delete splits interior and addRange covers boundaries" {
  let queue = RangePriorityQueueImpl::new()
  queue.add_range(OffsetRange(10, 20))
  queue.delete(15)
  assert_eq(queue.to_string(), "[10, 15) + [16, 20)")
  queue.add_range(OffsetRange(15, 16))
  assert_eq(queue.to_string(), "[10, 20)")
  queue.add_range(OffsetRange(12, 14))
  assert_eq(queue.to_string(), "[10, 20)")
  queue.add_range(OffsetRange(0, 30))
  assert_eq(queue.to_string(), "[0, 30)")
}
