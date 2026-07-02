///| Faithful conformance port of vscode's `intervalTree.test.ts` (pinned
/// `vscode/` submodule, commit 294fb350):
/// `vscode/src/vs/editor/test/common/model/intervalTree.test.ts`.
///
/// Ported members: the op-driven harness (`Oracle`, `TestState`,
/// `testIntervalTree`), `assertTreeInvariants` (RB height rule, red-parent
/// rule, delta bounds, maxEnd consistency, in-order sortedness — run after
/// every mutating op like the source), gen01–gen18, `force delta overflow`,
/// the 5 Cormen interval-search cases, and the `nodeAcceptEdit` table (208
/// assertions across stickiness x forceMoveMarkers x edit shapes).
///
/// Adaptations:
/// - The source's `getRandomInt` fuzz loop (`Math.random`, gated behind
///   `GENERATE_TESTS`) ports as a seeded xorshift32 PRNG with the fixed seed
///   set {11111, 22222, 33333, 44444, 55555} — deterministic in CI.
/// - `force delta overflow` constants (~9e14) exceed MoonBit's 32-bit `Int`;
///   they are scaled by 1e-6 (the test runs the plain insert + invariant
///   harness — the overflow it was sized for only triggers with the source's
///   commented-out FORCE_OVERFLOWING_TEST ctor line). A companion test drives
///   the real `normalize_delta` path through `accept_replace` within 32-bit
///   offsets instead.
/// - `Oracle.insert` (push + stable sort by (start, end)) is expressed as
///   insert-at-upper-bound, which is what a stable sort does to the appended
///   element.

// #region IntervalTree 1 — op-driven harness

///|
priv struct Interval {
  mut start : Int
  mut end : Int
}

///|
priv struct Oracle {
  intervals : Array[Interval]
}

///|
fn Oracle::new() -> Oracle {
  { intervals: [] }
}

///|
fn Oracle::insert(self : Oracle, interval : Interval) -> Interval {
  let mut idx = self.intervals.length()
  for i, existing in self.intervals {
    if existing.start > interval.start ||
      (existing.start == interval.start && existing.end > interval.end) {
      idx = i
      break
    }
  }
  self.intervals.insert(idx, interval)
  interval
}

///|
fn Oracle::delete(self : Oracle, interval : Interval) -> Unit {
  for i, existing in self.intervals {
    if physical_equal(existing, interval) {
      let _ = self.intervals.remove(i)
      return
    }
  }
}

///|
fn Oracle::search(self : Oracle, start : Int, end : Int) -> Array[Interval] {
  let result : Array[Interval] = []
  for interval in self.intervals {
    if interval.start <= end && interval.end >= start {
      result.push(interval)
    }
  }
  result
}

///|
priv enum Op {
  Insert(Int, Int)
  Delete(Int)
  Change(Int, Int, Int)
  Search(Int, Int)
}

///|
priv struct TestState {
  oracle : Oracle
  tree : @model.IntervalTree
  tree_nodes : Array[@model.IntervalNode?]
  oracle_nodes : Array[Interval?]
  /// Replays the source ctor's commented-out `FORCE_OVERFLOWING_TEST:
  /// this.delta = start` line, which is how Monaco exercises the delta
  /// arithmetic in rotations/insert/delete/search through this same suite.
  forced_delta : Bool
}

///|
fn TestState::new(forced_delta? : Bool = false) -> TestState {
  {
    oracle: Oracle::new(),
    tree: @model.IntervalTree::new(),
    tree_nodes: [],
    oracle_nodes: [],
    forced_delta,
  }
}

///|
fn TestState::accept_op(self : TestState, op : Op) -> Unit raise {
  match op {
    Insert(begin, end) => {
      // ids allocate sequentially (source: ++this._lastNodeId indexes the slot)
      let node = @model.IntervalNode::new("", begin, end)
      if self.forced_delta {
        node.delta = begin // FORCE_OVERFLOWING_TEST: this.delta = start
      }
      self.tree_nodes.push(Some(node))
      self.tree.insert(node)
      self.oracle_nodes.push(Some(self.oracle.insert({ start: begin, end })))
    }
    Delete(id) => {
      self.tree.delete(self.tree_nodes[id].unwrap())
      self.oracle.delete(self.oracle_nodes[id].unwrap())
      self.tree_nodes[id] = None
      self.oracle_nodes[id] = None
    }
    Change(id, begin, end) => {
      let node = self.tree_nodes[id].unwrap()
      self.tree.delete(node)
      node.reset(0, begin, end, None)
      self.tree.insert(node)
      let interval = self.oracle_nodes[id].unwrap()
      self.oracle.delete(interval)
      interval.start = begin
      interval.end = end
      let _ = self.oracle.insert(interval)
    }
    Search(begin, end) => {
      let actual_nodes = self.tree.interval_search(
        begin, end, 0, false, false, 0, false,
      )
      let actual = actual_nodes.map(n => {
        (n.cached_absolute_start, n.cached_absolute_end)
      })
      let expected = self.oracle.search(begin, end).map(i => (i.start, i.end))
      assert_pairs_eq(actual, expected)
      return
    }
  }
  assert_tree_invariants(self.tree)
  let actual = self.tree
    .get_all_in_order()
    .map(n => (n.cached_absolute_start, n.cached_absolute_end))
  let expected = self.oracle.intervals.map(i => (i.start, i.end))
  assert_pairs_eq(actual, expected)
}

///|
fn TestState::get_existing_node_id(self : TestState, index : Int) -> Int raise {
  let mut curr_index = -1
  for i in 0..<self.tree_nodes.length() {
    if self.tree_nodes[i] is None {
      continue
    }
    curr_index += 1
    if curr_index == index {
      return i
    }
  }
  fail("unexpected")
}

///|
fn test_interval_tree(ops : Array[Op]) -> Unit raise {
  let state = TestState::new()
  for op in ops {
    state.accept_op(op)
  }
}

///|
/// Every generated op list, for the FORCE_OVERFLOWING_TEST re-run.
fn gen_op_lists() -> Array[Array[Op]] {
  [
    [Insert(28, 35), Insert(52, 54), Insert(63, 69)],
    [Insert(80, 89), Insert(92, 100), Insert(99, 99)],
    [Insert(89, 96), Insert(71, 74), Delete(1)],
    [Insert(44, 46), Insert(85, 88), Delete(0)],
    [Insert(82, 90), Insert(69, 73), Delete(0), Delete(1)],
    [Insert(41, 63), Insert(98, 98), Insert(47, 51), Delete(2)],
    [Insert(24, 26), Insert(11, 28), Insert(27, 30), Insert(80, 85), Delete(1)],
    [Insert(100, 100), Insert(100, 100)],
    [Insert(58, 65), Insert(82, 96), Insert(58, 65)],
    [Insert(32, 40), Insert(25, 29), Insert(24, 32)],
    [Insert(25, 70), Insert(99, 100), Insert(46, 51), Insert(57, 57), Delete(2)],
    [Insert(20, 26), Insert(10, 18), Insert(99, 99), Insert(37, 59), Delete(2)],
    [Insert(3, 91), Insert(57, 57), Insert(35, 44), Insert(72, 81), Delete(2)],
    [Insert(58, 61), Insert(34, 35), Insert(56, 62), Insert(69, 78), Delete(0)],
    [
      Insert(63, 69),
      Insert(17, 24),
      Insert(3, 13),
      Insert(84, 94),
      Insert(18, 23),
      Insert(96, 98),
      Delete(1),
    ],
    [
      Insert(27, 27),
      Insert(42, 87),
      Insert(42, 49),
      Insert(69, 71),
      Insert(20, 27),
      Insert(8, 9),
      Insert(42, 49),
      Delete(1),
    ],
    [
      Insert(21, 23),
      Insert(83, 87),
      Insert(56, 58),
      Insert(1, 55),
      Insert(56, 59),
      Insert(58, 60),
      Insert(56, 65),
      Delete(1),
      Delete(0),
      Delete(6),
    ],
    [Insert(25, 25), Insert(67, 79), Delete(0), Search(65, 75)],
  ]
}

///|
test "gen01-gen18 under FORCE_OVERFLOWING_TEST (delta = start)" {
  for ops in gen_op_lists() {
    let state = TestState::new(forced_delta=true)
    for op in ops {
      state.accept_op(op)
    }
  }
}

///|
test "seeded fuzz under FORCE_OVERFLOWING_TEST (delta = start)" {
  let seeds : Array[UInt] = [11111, 22222, 33333]
  for seed in seeds {
    AutoTest::new(seed, forced_delta=true).run()
  }
}

///|
fn assert_pairs_eq(
  actual : Array[(Int, Int)],
  expected : Array[(Int, Int)],
) -> Unit raise {
  if actual != expected {
    fail("got \{to_repr(actual)}, expected \{to_repr(expected)}")
  }
}

// #endregion

// #region Assertion (intervalTree.test.ts:856-912)

///|
fn assert_tree_invariants(t : @model.IntervalTree) -> Unit raise {
  assert_true(@model.get_node_color(@model.sentinel) is Black)
  assert_true(physical_equal(@model.sentinel.parent(), @model.sentinel))
  assert_true(physical_equal(@model.sentinel.left(), @model.sentinel))
  assert_true(physical_equal(@model.sentinel.right(), @model.sentinel))
  assert_eq(@model.sentinel.start, 0)
  assert_eq(@model.sentinel.end, 0)
  assert_eq(@model.sentinel.delta, 0)
  assert_true(physical_equal(t.root.parent(), @model.sentinel))
  assert_valid_tree(t)
}

///|
fn depth(n : @model.IntervalNode) -> Int raise {
  if physical_equal(n, @model.sentinel) {
    // The leafs are black
    return 1
  }
  assert_eq(depth(n.left()), depth(n.right()))
  (if @model.get_node_color(n) is Black { 1 } else { 0 }) + depth(n.left())
}

///|
fn assert_valid_node(n : @model.IntervalNode, delta : Int) -> Unit raise {
  if physical_equal(n, @model.sentinel) {
    return
  }
  let l = n.left()
  let r = n.right()
  if @model.get_node_color(n) is Red {
    assert_true(@model.get_node_color(l) is Black)
    assert_true(@model.get_node_color(r) is Black)
  }
  let mut expected_max_end = n.end
  if !physical_equal(l, @model.sentinel) {
    assert_true(
      @model.interval_compare(
        l.start + delta,
        l.end + delta,
        n.start + delta,
        n.end + delta,
      ) <=
      0,
    )
    if l.max_end > expected_max_end {
      expected_max_end = l.max_end
    }
  }
  if !physical_equal(r, @model.sentinel) {
    assert_true(
      @model.interval_compare(
        n.start + delta,
        n.end + delta,
        r.start + delta + n.delta,
        r.end + delta + n.delta,
      ) <=
      0,
    )
    if r.max_end + n.delta > expected_max_end {
      expected_max_end = r.max_end + n.delta
    }
  }
  assert_eq(n.max_end, expected_max_end)
  assert_valid_node(l, delta)
  assert_valid_node(r, delta + n.delta)
}

///|
fn assert_valid_tree(t : @model.IntervalTree) -> Unit raise {
  if physical_equal(t.root, @model.sentinel) {
    return
  }
  assert_true(@model.get_node_color(t.root) is Black)
  assert_eq(depth(t.root.left()), depth(t.root.right()))
  assert_valid_node(t.root, 0)
}

// #endregion

// #region suite "generated"

///|
test "gen01" {
  test_interval_tree([Insert(28, 35), Insert(52, 54), Insert(63, 69)])
}

///|
test "gen02" {
  test_interval_tree([Insert(80, 89), Insert(92, 100), Insert(99, 99)])
}

///|
test "gen03" {
  test_interval_tree([Insert(89, 96), Insert(71, 74), Delete(1)])
}

///|
test "gen04" {
  test_interval_tree([Insert(44, 46), Insert(85, 88), Delete(0)])
}

///|
test "gen05" {
  test_interval_tree([Insert(82, 90), Insert(69, 73), Delete(0), Delete(1)])
}

///|
test "gen06" {
  test_interval_tree([Insert(41, 63), Insert(98, 98), Insert(47, 51), Delete(2)])
}

///|
test "gen07" {
  test_interval_tree([
    Insert(24, 26),
    Insert(11, 28),
    Insert(27, 30),
    Insert(80, 85),
    Delete(1),
  ])
}

///|
test "gen08" {
  test_interval_tree([Insert(100, 100), Insert(100, 100)])
}

///|
test "gen09" {
  test_interval_tree([Insert(58, 65), Insert(82, 96), Insert(58, 65)])
}

///|
test "gen10" {
  test_interval_tree([Insert(32, 40), Insert(25, 29), Insert(24, 32)])
}

///|
test "gen11" {
  test_interval_tree([
    Insert(25, 70),
    Insert(99, 100),
    Insert(46, 51),
    Insert(57, 57),
    Delete(2),
  ])
}

///|
test "gen12" {
  test_interval_tree([
    Insert(20, 26),
    Insert(10, 18),
    Insert(99, 99),
    Insert(37, 59),
    Delete(2),
  ])
}

///|
test "gen13" {
  test_interval_tree([
    Insert(3, 91),
    Insert(57, 57),
    Insert(35, 44),
    Insert(72, 81),
    Delete(2),
  ])
}

///|
test "gen14" {
  test_interval_tree([
    Insert(58, 61),
    Insert(34, 35),
    Insert(56, 62),
    Insert(69, 78),
    Delete(0),
  ])
}

///|
test "gen15" {
  test_interval_tree([
    Insert(63, 69),
    Insert(17, 24),
    Insert(3, 13),
    Insert(84, 94),
    Insert(18, 23),
    Insert(96, 98),
    Delete(1),
  ])
}

///|
test "gen16" {
  test_interval_tree([
    Insert(27, 27),
    Insert(42, 87),
    Insert(42, 49),
    Insert(69, 71),
    Insert(20, 27),
    Insert(8, 9),
    Insert(42, 49),
    Delete(1),
  ])
}

///|
test "gen17" {
  test_interval_tree([
    Insert(21, 23),
    Insert(83, 87),
    Insert(56, 58),
    Insert(1, 55),
    Insert(56, 59),
    Insert(58, 60),
    Insert(56, 65),
    Delete(1),
    Delete(0),
    Delete(6),
  ])
}

///|
test "gen18" {
  test_interval_tree([Insert(25, 25), Insert(67, 79), Delete(0), Search(65, 75)])
}

///|
test "force delta overflow" {
  // Search the IntervalNode ctor for FORCE_OVERFLOWING_TEST
  // to force that this test leads to a delta normalization.
  // (Source constants scaled by 1e-6 to fit 32-bit Int — see header.)
  test_interval_tree([
    Insert(686081138, 733009856),
    Insert(591031326, 591031326),
    Insert(940037682, 940037682),
    Insert(598413641, 598413641),
    Insert(800564156, 800564156),
    Insert(894198957, 894198957),
  ])
}

///|
test "delta overflow via accept_replace normalizes (companion, not in source)" {
  // Drives the real normalize_delta path within 32-bit offsets: two large
  // no-overlap inserts push the root delta past MAX_SAFE_DELTA (1<<30).
  let state = TestState::new()
  state.accept_op(Insert(10, 20))
  state.accept_op(Insert(30, 40))
  state.accept_op(Insert(50, 60))
  let shift = 600000000
  state.tree.accept_replace(0, 0, shift, false)
  state.tree.accept_replace(0, 0, shift, false)
  assert_tree_invariants(state.tree)
  let actual = state.tree
    .get_all_in_order()
    .map(n => (n.cached_absolute_start, n.cached_absolute_end))
  assert_pairs_eq(actual, [
    (10 + 2 * shift, 20 + 2 * shift),
    (30 + 2 * shift, 40 + 2 * shift),
    (50 + 2 * shift, 60 + 2 * shift),
  ])
}

// #endregion

// #region seeded fuzz (source getRandomInt loop, fixed seeds)

///|
priv struct Rng {
  mut state : UInt
}

///|
fn Rng::next(self : Rng) -> UInt {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  x
}

///|
/// `getRandomInt(min, max)`: inclusive on both ends.
fn Rng::int_in(self : Rng, min : Int, max : Int) -> Int {
  min +
  (self.next() % (max - min + 1).reinterpret_as_uint()).reinterpret_as_int()
}

///|
/// `getRandomRange(min, max)`.
fn Rng::range_in(self : Rng, min : Int, max : Int) -> (Int, Int) {
  let begin = self.int_in(min, max)
  let length = if self.int_in(1, 10) <= 2 {
    // large range
    self.int_in(0, max - begin)
  } else {
    // small range
    self.int_in(0, if max - begin < 10 { max - begin } else { 10 })
  }
  (begin, begin + length)
}

///|
priv struct AutoTest {
  rng : Rng
  state : TestState
  mut insert_cnt : Int
  mut delete_cnt : Int
  mut change_cnt : Int
}

///|
fn AutoTest::new(seed : UInt, forced_delta? : Bool = false) -> AutoTest {
  let rng : Rng = { state: seed }
  let insert_cnt = rng.int_in(1, 30) // MIN_INSERTS..MAX_INSERTS
  let change_cnt = rng.int_in(10, 20) // MIN_CHANGE_CNT..MAX_CHANGE_CNT
  {
    rng,
    state: TestState::new(forced_delta~),
    insert_cnt,
    delete_cnt: 0,
    change_cnt,
  }
}

///|
fn AutoTest::run(self : AutoTest) -> Unit raise {
  while self.insert_cnt > 0 || self.delete_cnt > 0 || self.change_cnt > 0 {
    if self.insert_cnt > 0 {
      let (begin, end) = self.rng.range_in(1, 100)
      self.state.accept_op(Insert(begin, end))
      self.insert_cnt -= 1
      self.delete_cnt += 1
    } else if self.change_cnt > 0 {
      let idx = self.rng.int_in(0, self.delete_cnt - 1)
      let (begin, end) = self.rng.range_in(1, 100)
      self.state.accept_op(
        Change(self.state.get_existing_node_id(idx), begin, end),
      )
      self.change_cnt -= 1
    } else {
      let idx = self.rng.int_in(self.delete_cnt / 2, self.delete_cnt - 1)
      self.state.accept_op(Delete(self.state.get_existing_node_id(idx)))
      self.delete_cnt -= 1
    }

    // Let's also search for something...
    let (begin, end) = self.rng.range_in(1, 100)
    self.state.accept_op(Search(begin, end))
  }
}

///|
test "seeded fuzz (getRandomInt loop, seeds 11111/22222/33333/44444/55555)" {
  let seeds : Array[UInt] = [11111, 22222, 33333, 44444, 55555]
  for seed in seeds {
    AutoTest::new(seed).run()
  }
}

// #endregion

// #region suite "searching" (the Cormen tree)

///|
fn create_cormen_tree() -> @model.IntervalTree {
  let r = @model.IntervalTree::new()
  let data = [
    (16, 21),
    (8, 9),
    (25, 30),
    (5, 8),
    (15, 23),
    (17, 19),
    (26, 26),
    (0, 3),
    (6, 10),
    (19, 20),
  ]
  for interval in data {
    let (start, end) = interval
    let node = @model.IntervalNode::new("", start, end)
    r.insert(node)
  }
  r
}

///|
fn assert_interval_search(
  t : @model.IntervalTree,
  start : Int,
  end : Int,
  expected : Array[(Int, Int)],
) -> Unit raise {
  let actual_nodes = t.interval_search(start, end, 0, false, false, 0, false)
  let actual = actual_nodes.map(n => {
    (n.cached_absolute_start, n.cached_absolute_end)
  })
  assert_pairs_eq(actual, expected)
}

///|
test "cormen 1->2" {
  assert_interval_search(create_cormen_tree(), 1, 2, [(0, 3)])
}

///|
test "cormen 4->8" {
  assert_interval_search(create_cormen_tree(), 4, 8, [(5, 8), (6, 10), (8, 9)])
}

///|
test "cormen 10->15" {
  assert_interval_search(create_cormen_tree(), 10, 15, [(6, 10), (15, 23)])
}

///|
test "cormen 21->25" {
  assert_interval_search(create_cormen_tree(), 21, 25, [
    (15, 23),
    (16, 21),
    (25, 30),
  ])
}

///|
test "cormen 24->24" {
  assert_interval_search(create_cormen_tree(), 24, 24, [])
}

// #endregion

// #region IntervalTree 2 — nodeAcceptEdit

///|
fn assert_node_accept_edit(
  msg : String,
  node_start : Int,
  node_end : Int,
  node_stickiness : Int,
  start : Int,
  end : Int,
  text_length : Int,
  force_move_markers : Bool,
  expected_node_start : Int,
  expected_node_end : Int,
) -> Unit raise {
  let node = @model.IntervalNode::new("", node_start, node_end)
  @model.set_node_stickiness(
    node,
    @model.TrackedRangeStickiness::from_int(node_stickiness),
  )
  @model.node_accept_edit(node, start, end, text_length, force_move_markers)
  if node.start != expected_node_start || node.end != expected_node_end {
    fail(
      "\{msg}: got (\{node.start}, \{node.end}), expected (\{expected_node_start}, \{expected_node_end})",
    )
  }
}

///|
/// Stickiness column is the numeric `TrackedRangeStickiness`:
/// 0=AlwaysGrowsWhenTypingAtEdges, 1=NeverGrowsWhenTypingAtEdges,
/// 2=GrowsOnlyWhenTypingBefore, 3=GrowsOnlyWhenTypingAfter.
test "nodeAcceptEdit" {
  let cases : Array[(String, Int, Int, Int, Int, Int, Int, Bool, Int, Int)] = [
    // A. collapsed decoration
    // no-op
    ("A.000", 0, 0, 0, 0, 0, 0, false, 0, 0),
    ("A.001", 0, 0, 1, 0, 0, 0, false, 0, 0),
    ("A.002", 0, 0, 2, 0, 0, 0, false, 0, 0),
    ("A.003", 0, 0, 3, 0, 0, 0, false, 0, 0),
    ("A.004", 0, 0, 0, 0, 0, 0, true, 0, 0),
    ("A.005", 0, 0, 1, 0, 0, 0, true, 0, 0),
    ("A.006", 0, 0, 2, 0, 0, 0, true, 0, 0),
    ("A.007", 0, 0, 3, 0, 0, 0, true, 0, 0),
    // insertion
    ("A.008", 0, 0, 0, 0, 0, 1, false, 0, 1),
    ("A.009", 0, 0, 1, 0, 0, 1, false, 1, 1),
    ("A.010", 0, 0, 2, 0, 0, 1, false, 0, 0),
    ("A.011", 0, 0, 3, 0, 0, 1, false, 1, 1),
    ("A.012", 0, 0, 0, 0, 0, 1, true, 1, 1),
    ("A.013", 0, 0, 1, 0, 0, 1, true, 1, 1),
    ("A.014", 0, 0, 2, 0, 0, 1, true, 1, 1),
    ("A.015", 0, 0, 3, 0, 0, 1, true, 1, 1),
    // B. non collapsed decoration
    // no-op
    ("B.000", 0, 5, 0, 0, 0, 0, false, 0, 5),
    ("B.001", 0, 5, 1, 0, 0, 0, false, 0, 5),
    ("B.002", 0, 5, 2, 0, 0, 0, false, 0, 5),
    ("B.003", 0, 5, 3, 0, 0, 0, false, 0, 5),
    ("B.004", 0, 5, 0, 0, 0, 0, true, 0, 5),
    ("B.005", 0, 5, 1, 0, 0, 0, true, 0, 5),
    ("B.006", 0, 5, 2, 0, 0, 0, true, 0, 5),
    ("B.007", 0, 5, 3, 0, 0, 0, true, 0, 5),
    // insertion at start
    ("B.008", 0, 5, 0, 0, 0, 1, false, 0, 6),
    ("B.009", 0, 5, 1, 0, 0, 1, false, 1, 6),
    ("B.010", 0, 5, 2, 0, 0, 1, false, 0, 6),
    ("B.011", 0, 5, 3, 0, 0, 1, false, 1, 6),
    ("B.012", 0, 5, 0, 0, 0, 1, true, 1, 6),
    ("B.013", 0, 5, 1, 0, 0, 1, true, 1, 6),
    ("B.014", 0, 5, 2, 0, 0, 1, true, 1, 6),
    ("B.015", 0, 5, 3, 0, 0, 1, true, 1, 6),
    // insertion in middle
    ("B.016", 0, 5, 0, 2, 2, 1, false, 0, 6),
    ("B.017", 0, 5, 1, 2, 2, 1, false, 0, 6),
    ("B.018", 0, 5, 2, 2, 2, 1, false, 0, 6),
    ("B.019", 0, 5, 3, 2, 2, 1, false, 0, 6),
    ("B.020", 0, 5, 0, 2, 2, 1, true, 0, 6),
    ("B.021", 0, 5, 1, 2, 2, 1, true, 0, 6),
    ("B.022", 0, 5, 2, 2, 2, 1, true, 0, 6),
    ("B.023", 0, 5, 3, 2, 2, 1, true, 0, 6),
    // insertion at end
    ("B.024", 0, 5, 0, 5, 5, 1, false, 0, 6),
    ("B.025", 0, 5, 1, 5, 5, 1, false, 0, 5),
    ("B.026", 0, 5, 2, 5, 5, 1, false, 0, 5),
    ("B.027", 0, 5, 3, 5, 5, 1, false, 0, 6),
    ("B.028", 0, 5, 0, 5, 5, 1, true, 0, 6),
    ("B.029", 0, 5, 1, 5, 5, 1, true, 0, 6),
    ("B.030", 0, 5, 2, 5, 5, 1, true, 0, 6),
    ("B.031", 0, 5, 3, 5, 5, 1, true, 0, 6),
    // replace with larger text until start
    ("B.032", 5, 10, 0, 4, 5, 2, false, 5, 11),
    ("B.033", 5, 10, 1, 4, 5, 2, false, 6, 11),
    ("B.034", 5, 10, 2, 4, 5, 2, false, 5, 11),
    ("B.035", 5, 10, 3, 4, 5, 2, false, 6, 11),
    ("B.036", 5, 10, 0, 4, 5, 2, true, 6, 11),
    ("B.037", 5, 10, 1, 4, 5, 2, true, 6, 11),
    ("B.038", 5, 10, 2, 4, 5, 2, true, 6, 11),
    ("B.039", 5, 10, 3, 4, 5, 2, true, 6, 11),
    // replace with smaller text until start
    ("B.040", 5, 10, 0, 3, 5, 1, false, 4, 9),
    ("B.041", 5, 10, 1, 3, 5, 1, false, 4, 9),
    ("B.042", 5, 10, 2, 3, 5, 1, false, 4, 9),
    ("B.043", 5, 10, 3, 3, 5, 1, false, 4, 9),
    ("B.044", 5, 10, 0, 3, 5, 1, true, 4, 9),
    ("B.045", 5, 10, 1, 3, 5, 1, true, 4, 9),
    ("B.046", 5, 10, 2, 3, 5, 1, true, 4, 9),
    ("B.047", 5, 10, 3, 3, 5, 1, true, 4, 9),
    // replace with larger text select start
    ("B.048", 5, 10, 0, 4, 6, 3, false, 5, 11),
    ("B.049", 5, 10, 1, 4, 6, 3, false, 5, 11),
    ("B.050", 5, 10, 2, 4, 6, 3, false, 5, 11),
    ("B.051", 5, 10, 3, 4, 6, 3, false, 5, 11),
    ("B.052", 5, 10, 0, 4, 6, 3, true, 7, 11),
    ("B.053", 5, 10, 1, 4, 6, 3, true, 7, 11),
    ("B.054", 5, 10, 2, 4, 6, 3, true, 7, 11),
    ("B.055", 5, 10, 3, 4, 6, 3, true, 7, 11),
    // replace with smaller text select start
    ("B.056", 5, 10, 0, 4, 6, 1, false, 5, 9),
    ("B.057", 5, 10, 1, 4, 6, 1, false, 5, 9),
    ("B.058", 5, 10, 2, 4, 6, 1, false, 5, 9),
    ("B.059", 5, 10, 3, 4, 6, 1, false, 5, 9),
    ("B.060", 5, 10, 0, 4, 6, 1, true, 5, 9),
    ("B.061", 5, 10, 1, 4, 6, 1, true, 5, 9),
    ("B.062", 5, 10, 2, 4, 6, 1, true, 5, 9),
    ("B.063", 5, 10, 3, 4, 6, 1, true, 5, 9),
    // replace with larger text from start
    ("B.064", 5, 10, 0, 5, 6, 2, false, 5, 11),
    ("B.065", 5, 10, 1, 5, 6, 2, false, 5, 11),
    ("B.066", 5, 10, 2, 5, 6, 2, false, 5, 11),
    ("B.067", 5, 10, 3, 5, 6, 2, false, 5, 11),
    ("B.068", 5, 10, 0, 5, 6, 2, true, 7, 11),
    ("B.069", 5, 10, 1, 5, 6, 2, true, 7, 11),
    ("B.070", 5, 10, 2, 5, 6, 2, true, 7, 11),
    ("B.071", 5, 10, 3, 5, 6, 2, true, 7, 11),
    // replace with smaller text from start
    ("B.072", 5, 10, 0, 5, 7, 1, false, 5, 9),
    ("B.073", 5, 10, 1, 5, 7, 1, false, 5, 9),
    ("B.074", 5, 10, 2, 5, 7, 1, false, 5, 9),
    ("B.075", 5, 10, 3, 5, 7, 1, false, 5, 9),
    ("B.076", 5, 10, 0, 5, 7, 1, true, 6, 9),
    ("B.077", 5, 10, 1, 5, 7, 1, true, 6, 9),
    ("B.078", 5, 10, 2, 5, 7, 1, true, 6, 9),
    ("B.079", 5, 10, 3, 5, 7, 1, true, 6, 9),
    // replace with larger text to end
    ("B.080", 5, 10, 0, 9, 10, 2, false, 5, 11),
    ("B.081", 5, 10, 1, 9, 10, 2, false, 5, 10),
    ("B.082", 5, 10, 2, 9, 10, 2, false, 5, 10),
    ("B.083", 5, 10, 3, 9, 10, 2, false, 5, 11),
    ("B.084", 5, 10, 0, 9, 10, 2, true, 5, 11),
    ("B.085", 5, 10, 1, 9, 10, 2, true, 5, 11),
    ("B.086", 5, 10, 2, 9, 10, 2, true, 5, 11),
    ("B.087", 5, 10, 3, 9, 10, 2, true, 5, 11),
    // replace with smaller text to end
    ("B.088", 5, 10, 0, 8, 10, 1, false, 5, 9),
    ("B.089", 5, 10, 1, 8, 10, 1, false, 5, 9),
    ("B.090", 5, 10, 2, 8, 10, 1, false, 5, 9),
    ("B.091", 5, 10, 3, 8, 10, 1, false, 5, 9),
    ("B.092", 5, 10, 0, 8, 10, 1, true, 5, 9),
    ("B.093", 5, 10, 1, 8, 10, 1, true, 5, 9),
    ("B.094", 5, 10, 2, 8, 10, 1, true, 5, 9),
    ("B.095", 5, 10, 3, 8, 10, 1, true, 5, 9),
    // replace with larger text select end
    ("B.096", 5, 10, 0, 9, 11, 3, false, 5, 10),
    ("B.097", 5, 10, 1, 9, 11, 3, false, 5, 10),
    ("B.098", 5, 10, 2, 9, 11, 3, false, 5, 10),
    ("B.099", 5, 10, 3, 9, 11, 3, false, 5, 10),
    ("B.100", 5, 10, 0, 9, 11, 3, true, 5, 12),
    ("B.101", 5, 10, 1, 9, 11, 3, true, 5, 12),
    ("B.102", 5, 10, 2, 9, 11, 3, true, 5, 12),
    ("B.103", 5, 10, 3, 9, 11, 3, true, 5, 12),
    // replace with smaller text select end
    ("B.104", 5, 10, 0, 9, 11, 1, false, 5, 10),
    ("B.105", 5, 10, 1, 9, 11, 1, false, 5, 10),
    ("B.106", 5, 10, 2, 9, 11, 1, false, 5, 10),
    ("B.107", 5, 10, 3, 9, 11, 1, false, 5, 10),
    ("B.108", 5, 10, 0, 9, 11, 1, true, 5, 10),
    ("B.109", 5, 10, 1, 9, 11, 1, true, 5, 10),
    ("B.110", 5, 10, 2, 9, 11, 1, true, 5, 10),
    ("B.111", 5, 10, 3, 9, 11, 1, true, 5, 10),
    // replace with larger text from end
    ("B.112", 5, 10, 0, 10, 11, 3, false, 5, 10),
    ("B.113", 5, 10, 1, 10, 11, 3, false, 5, 10),
    ("B.114", 5, 10, 2, 10, 11, 3, false, 5, 10),
    ("B.115", 5, 10, 3, 10, 11, 3, false, 5, 10),
    ("B.116", 5, 10, 0, 10, 11, 3, true, 5, 13),
    ("B.117", 5, 10, 1, 10, 11, 3, true, 5, 13),
    ("B.118", 5, 10, 2, 10, 11, 3, true, 5, 13),
    ("B.119", 5, 10, 3, 10, 11, 3, true, 5, 13),
    // replace with smaller text from end
    ("B.120", 5, 10, 0, 10, 12, 1, false, 5, 10),
    ("B.121", 5, 10, 1, 10, 12, 1, false, 5, 10),
    ("B.122", 5, 10, 2, 10, 12, 1, false, 5, 10),
    ("B.123", 5, 10, 3, 10, 12, 1, false, 5, 10),
    ("B.124", 5, 10, 0, 10, 12, 1, true, 5, 11),
    ("B.125", 5, 10, 1, 10, 12, 1, true, 5, 11),
    ("B.126", 5, 10, 2, 10, 12, 1, true, 5, 11),
    ("B.127", 5, 10, 3, 10, 12, 1, true, 5, 11),
    // delete until start
    ("B.128", 5, 10, 0, 4, 5, 0, false, 4, 9),
    ("B.129", 5, 10, 1, 4, 5, 0, false, 4, 9),
    ("B.130", 5, 10, 2, 4, 5, 0, false, 4, 9),
    ("B.131", 5, 10, 3, 4, 5, 0, false, 4, 9),
    ("B.132", 5, 10, 0, 4, 5, 0, true, 4, 9),
    ("B.133", 5, 10, 1, 4, 5, 0, true, 4, 9),
    ("B.134", 5, 10, 2, 4, 5, 0, true, 4, 9),
    ("B.135", 5, 10, 3, 4, 5, 0, true, 4, 9),
    // delete select start
    ("B.136", 5, 10, 0, 4, 6, 0, false, 4, 8),
    ("B.137", 5, 10, 1, 4, 6, 0, false, 4, 8),
    ("B.138", 5, 10, 2, 4, 6, 0, false, 4, 8),
    ("B.139", 5, 10, 3, 4, 6, 0, false, 4, 8),
    ("B.140", 5, 10, 0, 4, 6, 0, true, 4, 8),
    ("B.141", 5, 10, 1, 4, 6, 0, true, 4, 8),
    ("B.142", 5, 10, 2, 4, 6, 0, true, 4, 8),
    ("B.143", 5, 10, 3, 4, 6, 0, true, 4, 8),
    // delete from start
    ("B.144", 5, 10, 0, 5, 6, 0, false, 5, 9),
    ("B.145", 5, 10, 1, 5, 6, 0, false, 5, 9),
    ("B.146", 5, 10, 2, 5, 6, 0, false, 5, 9),
    ("B.147", 5, 10, 3, 5, 6, 0, false, 5, 9),
    ("B.148", 5, 10, 0, 5, 6, 0, true, 5, 9),
    ("B.149", 5, 10, 1, 5, 6, 0, true, 5, 9),
    ("B.150", 5, 10, 2, 5, 6, 0, true, 5, 9),
    ("B.151", 5, 10, 3, 5, 6, 0, true, 5, 9),
    // delete to end
    ("B.152", 5, 10, 0, 9, 10, 0, false, 5, 9),
    ("B.153", 5, 10, 1, 9, 10, 0, false, 5, 9),
    ("B.154", 5, 10, 2, 9, 10, 0, false, 5, 9),
    ("B.155", 5, 10, 3, 9, 10, 0, false, 5, 9),
    ("B.156", 5, 10, 0, 9, 10, 0, true, 5, 9),
    ("B.157", 5, 10, 1, 9, 10, 0, true, 5, 9),
    ("B.158", 5, 10, 2, 9, 10, 0, true, 5, 9),
    ("B.159", 5, 10, 3, 9, 10, 0, true, 5, 9),
    // delete select end
    ("B.160", 5, 10, 0, 9, 11, 0, false, 5, 9),
    ("B.161", 5, 10, 1, 9, 11, 0, false, 5, 9),
    ("B.162", 5, 10, 2, 9, 11, 0, false, 5, 9),
    ("B.163", 5, 10, 3, 9, 11, 0, false, 5, 9),
    ("B.164", 5, 10, 0, 9, 11, 0, true, 5, 9),
    ("B.165", 5, 10, 1, 9, 11, 0, true, 5, 9),
    ("B.166", 5, 10, 2, 9, 11, 0, true, 5, 9),
    ("B.167", 5, 10, 3, 9, 11, 0, true, 5, 9),
    // delete from end
    ("B.168", 5, 10, 0, 10, 11, 0, false, 5, 10),
    ("B.169", 5, 10, 1, 10, 11, 0, false, 5, 10),
    ("B.170", 5, 10, 2, 10, 11, 0, false, 5, 10),
    ("B.171", 5, 10, 3, 10, 11, 0, false, 5, 10),
    ("B.172", 5, 10, 0, 10, 11, 0, true, 5, 10),
    ("B.173", 5, 10, 1, 10, 11, 0, true, 5, 10),
    ("B.174", 5, 10, 2, 10, 11, 0, true, 5, 10),
    ("B.175", 5, 10, 3, 10, 11, 0, true, 5, 10),
    // replace with larger text entire
    ("B.176", 5, 10, 0, 5, 10, 3, false, 5, 8),
    ("B.177", 5, 10, 1, 5, 10, 3, false, 5, 8),
    ("B.178", 5, 10, 2, 5, 10, 3, false, 5, 8),
    ("B.179", 5, 10, 3, 5, 10, 3, false, 5, 8),
    ("B.180", 5, 10, 0, 5, 10, 3, true, 8, 8),
    ("B.181", 5, 10, 1, 5, 10, 3, true, 8, 8),
    ("B.182", 5, 10, 2, 5, 10, 3, true, 8, 8),
    ("B.183", 5, 10, 3, 5, 10, 3, true, 8, 8),
    // replace with smaller text entire
    ("B.184", 5, 10, 0, 5, 10, 7, false, 5, 12),
    ("B.185", 5, 10, 1, 5, 10, 7, false, 5, 10),
    ("B.186", 5, 10, 2, 5, 10, 7, false, 5, 10),
    ("B.187", 5, 10, 3, 5, 10, 7, false, 5, 12),
    ("B.188", 5, 10, 0, 5, 10, 7, true, 12, 12),
    ("B.189", 5, 10, 1, 5, 10, 7, true, 12, 12),
    ("B.190", 5, 10, 2, 5, 10, 7, true, 12, 12),
    ("B.191", 5, 10, 3, 5, 10, 7, true, 12, 12),
  ]
  for c in cases {
    let (msg, ns, ne, stick, s, e, tl, fmm, es, ee) = c
    assert_node_accept_edit(msg, ns, ne, stick, s, e, tl, fmm, es, ee)
  }
}

// #endregion
