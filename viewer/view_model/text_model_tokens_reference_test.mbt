///| Faithful conformance port of vscode's `RangePriorityQueueImpl` suite.
///
/// Source: `src/vs/editor/test/common/model/textModelTokens.test.ts` (pinned
/// `vscode/` submodule). Both `test(...)` cases are ported with their original
/// names. The `addRange` case exercises the `OffsetRange.addRange` static
/// (ported in `base/common`); `addRangeAndResize` exercises the queue itself.

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
  @base_common.OffsetRange::add_range(@base_common.OffsetRange(0, 2), ranges)
  @base_common.OffsetRange::add_range(@base_common.OffsetRange(10, 13), ranges)
  @base_common.OffsetRange::add_range(@base_common.OffsetRange(20, 24), ranges)
  assert_str_array_eq(or_strings(ranges), ["[0, 2)", "[10, 13)", "[20, 24)"])
  @base_common.OffsetRange::add_range(@base_common.OffsetRange(2, 10), ranges)
  assert_str_array_eq(or_strings(ranges), ["[0, 13)", "[20, 24)"])
  @base_common.OffsetRange::add_range(@base_common.OffsetRange(14, 19), ranges)
  assert_str_array_eq(or_strings(ranges), ["[0, 13)", "[14, 19)", "[20, 24)"])
  @base_common.OffsetRange::add_range(@base_common.OffsetRange(10, 22), ranges)
  assert_str_array_eq(or_strings(ranges), ["[0, 24)"])
  @base_common.OffsetRange::add_range(@base_common.OffsetRange(-1, 29), ranges)
  assert_str_array_eq(or_strings(ranges), ["[-1, 29)"])
  @base_common.OffsetRange::add_range(@base_common.OffsetRange(-10, -5), ranges)
  assert_str_array_eq(or_strings(ranges), ["[-10, -5)", "[-1, 29)"])
}

///|
test "addRangeAndResize" {
  let queue = RangePriorityQueueImpl::new()
  queue.add_range(@base_common.OffsetRange(0, 20))
  queue.add_range(@base_common.OffsetRange(100, 120))
  queue.add_range(@base_common.OffsetRange(200, 220))

  // disjoint
  queue.add_range_and_resize(@base_common.OffsetRange(25, 27), 0)
  assert_str_array_eq(or_strings(queue.get_ranges()), [
    "[0, 20)", "[98, 118)", "[198, 218)",
  ])
  queue.add_range_and_resize(@base_common.OffsetRange(19, 20), 0)
  assert_str_array_eq(or_strings(queue.get_ranges()), [
    "[0, 19)", "[97, 117)", "[197, 217)",
  ])
  queue.add_range_and_resize(@base_common.OffsetRange(19, 97), 0)
  assert_str_array_eq(or_strings(queue.get_ranges()), ["[0, 39)", "[119, 139)"])
  queue.add_range_and_resize(@base_common.OffsetRange(-1000, 1000), 0)
  assert_str_array_eq(or_strings(queue.get_ranges()), [])
}
