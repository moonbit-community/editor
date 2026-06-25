// Conformance port of Monaco/VS Code's FoldingRanges suite.
//
// Ports: vscode/src/vs/editor/contrib/folding/test/browser/foldingRanges.test.ts
// From vscode submodule commit 294fb350837dbaee37b949533fead4df4e0e8971.

///|
/// Matches `/^<text>$/` (whole line equals text).
fn exact_matcher(text : String) -> (String) -> Bool {
  fn(line) { line == text }
}

///|
fn exact_region_markers() -> @folding.FoldingMarkers {
  @folding.FoldingMarkers::new(
    exact_matcher("#region"),
    exact_matcher("#endregion"),
  )
}

///|
fn fold_range(
  from : Int,
  to : Int,
  collapsed? : Bool = false,
  source? : @folding.FoldSource = @folding.FoldSource::Provider,
  type_? : String,
) -> @folding.FoldRange {
  @folding.FoldRange::new(from, to, is_collapsed=collapsed, source~, type_?)
}

///|
fn assert_equal_ranges(
  range1 : @folding.FoldRange,
  range2 : @folding.FoldRange,
  msg : String,
) -> Unit raise {
  guard range1.start_line_number == range2.start_line_number else {
    fail(msg + " start")
  }
  guard range1.end_line_number == range2.end_line_number else {
    fail(msg + " end")
  }
  guard range1.type_ == range2.type_ else { fail(msg + " type") }
  guard range1.is_collapsed == range2.is_collapsed else {
    fail(msg + " collapsed")
  }
  guard range1.source == range2.source else { fail(msg + " source") }
}

///|
test "test max folding regions" {
  let lines : Array[String] = []
  let n_regions = @folding.max_folding_regions
  let collector = @folding.RangesCollector::new(
    @folding.FoldingLimitReporter::new(@folding.max_folding_regions),
  )
  for _i in 0..<n_regions {
    let start_line_number = lines.length()
    lines.push("#region")
    let end_line_number = lines.length()
    lines.push("#endregion")
    collector.insert_first(start_line_number, end_line_number, 0)
  }
  let model = model_of(lines)
  let actual = collector.to_indent_ranges(model)
  assert_eq(actual.length(), n_regions)
}

///|
test "findRange" {
  let lines = [
    "#region", "#endregion", "class A {", "  void foo() {", "    if (true) {", "        return;",
    "    }", "", "    if (true) {", "      return;", "    }", "  }", "}",
  ]
  let text_model = model_of(lines)
  let actual = @folding.compute_ranges(
    text_model,
    false,
    markers=exact_region_markers(),
  )
  assert_eq(actual.find_range(1), 0)
  assert_eq(actual.find_range(2), 0)
  assert_eq(actual.find_range(3), 1)
  assert_eq(actual.find_range(4), 2)
  assert_eq(actual.find_range(5), 3)
  assert_eq(actual.find_range(6), 3)
  assert_eq(actual.find_range(7), 2)
  assert_eq(actual.find_range(8), 2)
  assert_eq(actual.find_range(9), 4)
  assert_eq(actual.find_range(10), 4)
  assert_eq(actual.find_range(11), 2)
  assert_eq(actual.find_range(12), 1)
  assert_eq(actual.find_range(13), -1)
}

///|
test "setCollapsed" {
  let lines : Array[String] = []
  let n_regions = 500
  for _i in 0..<n_regions {
    lines.push("#region")
  }
  for _i in 0..<n_regions {
    lines.push("#endregion")
  }
  let model = model_of(lines)
  let actual = @folding.compute_ranges(
    model,
    false,
    markers=exact_region_markers(),
  )
  assert_eq(actual.length(), n_regions)
  for i in 0..<n_regions {
    actual.set_collapsed(i, i % 3 == 0)
  }
  for i in 0..<n_regions {
    assert_eq(actual.is_collapsed(i), i % 3 == 0)
  }
}

///|
test "sanitizeAndMerge1" {
  let region_set1 = [
    fold_range(0, 100), // invalid, should be removed
    fold_range(1, 100, type_="A"), // valid
    fold_range(1, 100, type_="Z"), // invalid, duplicate start
    fold_range(10, 10), // invalid, should be removed
    fold_range(20, 80, type_="C1"), // valid inside 'B'
    fold_range(22, 80, collapsed=true, type_="D1"), // valid inside 'C1'
    fold_range(90, 101), // invalid, should be removed
  ]
  let region_set2 = [
    fold_range(20, 80, collapsed=true), // should merge with C1
    fold_range(18, 80, collapsed=true), // invalid, out of order
    fold_range(21, 81, collapsed=true, type_="Z"), // invalid, overlapping
    fold_range(22, 80, collapsed=true, type_="D2"), // should merge with D1
  ]
  let result = @folding.FoldingRegions::sanitize_and_merge(
    region_set1,
    region_set2,
    max_line_number=100,
  )
  assert_eq(result.length(), 3)
  assert_equal_ranges(result[0], fold_range(1, 100, type_="A"), "A1")
  assert_equal_ranges(
    result[1],
    fold_range(20, 80, collapsed=true, type_="C1"),
    "C1",
  )
  assert_equal_ranges(
    result[2],
    fold_range(22, 80, collapsed=true, type_="D1"),
    "D1",
  )
}

///|
test "sanitizeAndMerge2" {
  let p = @folding.FoldSource::Provider
  let u = @folding.FoldSource::UserDefined
  let region_set1 = [
    fold_range(1, 100, source=p, type_="a1"), // valid
    fold_range(2, 100, source=p, type_="a2"), // valid
    fold_range(3, 19, source=p, type_="a3"), // valid
    fold_range(20, 71, source=p, type_="a4"), // overlaps b3
    fold_range(21, 29, source=p, type_="a5"), // valid
    fold_range(81, 91, source=p, type_="a6"), // overlaps b4
  ]
  let region_set2 = [
    fold_range(30, 39, collapsed=true, source=p, type_="b1"), // valid, will be recovered
    fold_range(40, 49, collapsed=true, source=u, type_="b2"), // valid
    fold_range(50, 100, collapsed=true, source=u, type_="b3"), // overlaps a4
    fold_range(80, 90, collapsed=true, source=u, type_="b4"), // overlaps a6
    fold_range(92, 100, collapsed=true, source=u, type_="b5"), // valid
  ]
  let result = @folding.FoldingRegions::sanitize_and_merge(
    region_set1,
    region_set2,
    max_line_number=100,
  )
  assert_eq(result.length(), 9)
  assert_equal_ranges(result[0], fold_range(1, 100, source=p, type_="a1"), "P1")
  assert_equal_ranges(result[1], fold_range(2, 100, source=p, type_="a2"), "P2")
  assert_equal_ranges(result[2], fold_range(3, 19, source=p, type_="a3"), "P3")
  assert_equal_ranges(result[3], fold_range(21, 29, source=p, type_="a5"), "P4")
  assert_equal_ranges(
    result[4],
    fold_range(
      30,
      39,
      collapsed=true,
      source=@folding.FoldSource::Recovered,
      type_="b1",
    ),
    "P5",
  )
  assert_equal_ranges(
    result[5],
    fold_range(40, 49, collapsed=true, source=u, type_="b2"),
    "P6",
  )
  assert_equal_ranges(
    result[6],
    fold_range(50, 100, collapsed=true, source=u, type_="b3"),
    "P7",
  )
  assert_equal_ranges(
    result[7],
    fold_range(80, 90, collapsed=true, source=u, type_="b4"),
    "P8",
  )
  assert_equal_ranges(
    result[8],
    fold_range(92, 100, collapsed=true, source=u, type_="b5"),
    "P9",
  )
}

///|
test "sanitizeAndMerge3" {
  let p = @folding.FoldSource::Provider
  let rec = @folding.FoldSource::Recovered
  let region_set1 = [
    fold_range(1, 100, source=p, type_="a1"), // valid
    fold_range(10, 29, source=p, type_="a2"), // matches manual hidden
    fold_range(35, 39, collapsed=true, source=rec, type_="a3"), // valid
  ]
  let region_set2 = [
    fold_range(10, 29, collapsed=true, source=rec, type_="b1"), // matches a
    fold_range(20, 28, collapsed=true, source=p, type_="b2"), // should remain
    fold_range(30, 39, collapsed=true, source=rec, type_="b3"), // should remain
  ]
  let result = @folding.FoldingRegions::sanitize_and_merge(
    region_set1,
    region_set2,
    max_line_number=100,
  )
  assert_eq(result.length(), 5)
  assert_equal_ranges(result[0], fold_range(1, 100, source=p, type_="a1"), "R1")
  assert_equal_ranges(
    result[1],
    fold_range(10, 29, collapsed=true, source=p, type_="a2"),
    "R2",
  )
  assert_equal_ranges(
    result[2],
    fold_range(20, 28, collapsed=true, source=rec, type_="b2"),
    "R3",
  )
  assert_equal_ranges(
    result[3],
    fold_range(30, 39, collapsed=true, source=rec, type_="b3"),
    "R3",
  )
  assert_equal_ranges(
    result[4],
    fold_range(35, 39, collapsed=true, source=rec, type_="a3"),
    "R4",
  )
}

///|
test "sanitizeAndMerge4" {
  let p = @folding.FoldSource::Provider
  let rec = @folding.FoldSource::Recovered
  let region_set1 = [
    fold_range(1, 100, source=p, type_="a1"), // valid
  ]
  let region_set2 = [
    fold_range(20, 28, collapsed=true, source=p, type_="b1"), // hidden
    fold_range(30, 38, collapsed=true, source=p, type_="b2"), // hidden
  ]
  let result = @folding.FoldingRegions::sanitize_and_merge(
    region_set1,
    region_set2,
    max_line_number=100,
  )
  assert_eq(result.length(), 3)
  assert_equal_ranges(result[0], fold_range(1, 100, source=p, type_="a1"), "R1")
  assert_equal_ranges(
    result[1],
    fold_range(20, 28, collapsed=true, source=rec, type_="b1"),
    "R2",
  )
  assert_equal_ranges(
    result[2],
    fold_range(30, 38, collapsed=true, source=rec, type_="b2"),
    "R3",
  )
}
