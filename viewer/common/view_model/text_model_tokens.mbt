///| Faithful 1:1 port of vscode's `RangePriorityQueueImpl`.
///
/// Source: `src/vs/editor/common/model/textModelTokens.ts` (pinned `vscode/`
/// submodule). A priority queue of disjoint, sorted `OffsetRange`s used by
/// Monaco's background tokenizer to track which line ranges still need
/// tokenization. The readonly viewer does not run that background worker, so
/// this is ported purely for conformance with `textModelTokens.test.ts`; the
/// `OffsetRange.addRange` static it builds on lives in `base/common`.

///|
pub struct RangePriorityQueueImpl {
  ranges : Array[@base_common.OffsetRange]
}

///|
pub fn RangePriorityQueueImpl::new() -> RangePriorityQueueImpl {
  { ranges: [] }
}

///|
pub fn RangePriorityQueueImpl::get_ranges(
  self : RangePriorityQueueImpl,
) -> Array[@base_common.OffsetRange] {
  self.ranges
}

///|
/// The smallest queued offset, or `None` when empty. Mirrors the `min` getter.
pub fn RangePriorityQueueImpl::min(self : RangePriorityQueueImpl) -> Int? {
  if self.ranges.length() == 0 {
    None
  } else {
    Some(self.ranges[0].start)
  }
}

///|
/// Removes and returns the smallest queued offset, or `None` when empty.
pub fn RangePriorityQueueImpl::remove_min(
  self : RangePriorityQueueImpl,
) -> Int? {
  if self.ranges.length() == 0 {
    return None
  }
  let range = self.ranges[0]
  if range.start + 1 == range.end_exclusive {
    self.ranges.remove(0) |> ignore
  } else {
    self.ranges[0] = OffsetRange(range.start + 1, range.end_exclusive)
  }
  Some(range.start)
}

///|
/// Removes a single offset `value` from the queue, splitting a range if needed.
pub fn RangePriorityQueueImpl::delete(
  self : RangePriorityQueueImpl,
  value : Int,
) -> Unit {
  let mut idx = -1
  for i in 0..<self.ranges.length() {
    if self.ranges[i].contains(value) {
      idx = i
      break
    }
  }
  if idx != -1 {
    let range = self.ranges[idx]
    if range.start == value {
      if range.end_exclusive == value + 1 {
        self.ranges.remove(idx) |> ignore
      } else {
        self.ranges[idx] = OffsetRange(value + 1, range.end_exclusive)
      }
    } else if range.end_exclusive == value + 1 {
      self.ranges[idx] = OffsetRange(range.start, value)
    } else {
      self.ranges[idx] = OffsetRange(range.start, value)
      self.ranges.insert(idx + 1, OffsetRange(value + 1, range.end_exclusive))
    }
  }
}

///|
pub fn RangePriorityQueueImpl::add_range(
  self : RangePriorityQueueImpl,
  range : @base_common.OffsetRange,
) -> Unit {
  @base_common.OffsetRange::add_range(range, self.ranges)
}

///|
/// Inserts `range` while resizing every range after it by `new_length -
/// range.length`, merging any intersecting ranges. Mirrors `addRangeAndResize`.
pub fn RangePriorityQueueImpl::add_range_and_resize(
  self : RangePriorityQueueImpl,
  range : @base_common.OffsetRange,
  new_length : Int,
) -> Unit {
  let mut idx_first_might_be_intersecting = 0
  while !(idx_first_might_be_intersecting >= self.ranges.length() ||
        range.start <=
        self.ranges[idx_first_might_be_intersecting].end_exclusive) {
    idx_first_might_be_intersecting = idx_first_might_be_intersecting + 1
  }
  let mut idx_first_is_after = idx_first_might_be_intersecting
  while !(idx_first_is_after >= self.ranges.length() ||
        range.end_exclusive < self.ranges[idx_first_is_after].start) {
    idx_first_is_after = idx_first_is_after + 1
  }
  let delta = new_length - range.length()
  for i in idx_first_is_after..<self.ranges.length() {
    self.ranges[i] = self.ranges[i].delta(delta)
  }
  if idx_first_might_be_intersecting == idx_first_is_after {
    let new_range = @base_common.OffsetRange(
      range.start,
      range.start + new_length,
    )
    if !new_range.is_empty() {
      self.ranges.insert(idx_first_might_be_intersecting, new_range)
    }
  } else {
    let start = range.start.min(
      self.ranges[idx_first_might_be_intersecting].start,
    )
    let end_ex = range.end_exclusive.max(
      self.ranges[idx_first_is_after - 1].end_exclusive,
    )
    let new_range = @base_common.OffsetRange(start, end_ex + delta)
    let delete_count = idx_first_is_after - idx_first_might_be_intersecting
    if !new_range.is_empty() {
      splice_ranges(
        self.ranges,
        idx_first_might_be_intersecting,
        delete_count,
        Some(new_range),
      )
    } else {
      splice_ranges(
        self.ranges,
        idx_first_might_be_intersecting,
        delete_count,
        None,
      )
    }
  }
}

///|
/// Removes `delete_count` elements at `index`, then inserts `item` there (when
/// present) — the subset of JS `Array.splice` this port needs.
fn splice_ranges(
  arr : Array[@base_common.OffsetRange],
  index : Int,
  delete_count : Int,
  item : @base_common.OffsetRange?,
) -> Unit {
  for _ in 0..<delete_count {
    arr.remove(index) |> ignore
  }
  match item {
    Some(it) => arr.insert(index, it)
    None => ()
  }
}
