// Conformance port of Monaco/VS Code's indent-fold limit suite.
//
// Ports: vscode/src/vs/editor/contrib/folding/test/browser/indentFold.test.ts
// From vscode submodule commit 294fb350837dbaee37b949533fead4df4e0e8971.

///|
test "Limit by indent" {
  let lines = [
    "A", "  A", "  A", "    A", "      A", "    A", "      A", "      A", "         A",
    "      A", "         A", "  A", "              A", "                 A", "A",
    "  A",
  ]
  let r1 = (1, 14)
  let r2 = (3, 11)
  let r3 = (4, 5)
  let r4 = (6, 11)
  let r5 = (8, 9)
  let r6 = (10, 11)
  let r7 = (12, 14)
  let r8 = (13, 14)
  let r9 = (15, 16)
  let snapshot = model_of(lines)
  fn assert_limit(
    max_entries : Int,
    expected_ranges : Array[(Int, Int)],
    message : String,
  ) -> Unit raise {
    let reported : Ref[Int?] = { val: None }
    let limit = @folding.FoldingLimitReporter::new(max_entries, update=fn(
      _computed,
      limited,
    ) {
      reported.val = limited
    })
    let indent_ranges = @folding.compute_ranges(
      snapshot,
      true,
      folding_ranges_limit=limit,
    )
    guard indent_ranges.length() <= max_entries else { fail("max " + message) }
    let actual : Array[(Int, Int)] = []
    for i in 0..<indent_ranges.length() {
      actual.push(
        (
          indent_ranges.get_start_line_number(i),
          indent_ranges.get_end_line_number(i),
        ),
      )
    }
    guard actual == expected_ranges else {
      fail(
        "\{message}: got \{to_repr(actual)}, expected \{to_repr(expected_ranges)}",
      )
    }
    // limited is `false` (None) when 9 ranges fit, else the limit itself.
    let expected_reported : Int? = if 9 <= max_entries {
      None
    } else {
      Some(max_entries)
    }
    guard reported.val == expected_reported else {
      fail("limited \{message}: got \{to_repr(reported.val)}")
    }
  }

  assert_limit(1000, [r1, r2, r3, r4, r5, r6, r7, r8, r9], "1000")
  assert_limit(9, [r1, r2, r3, r4, r5, r6, r7, r8, r9], "9")
  assert_limit(8, [r1, r2, r3, r4, r5, r6, r7, r9], "8")
  assert_limit(7, [r1, r2, r3, r4, r5, r7, r9], "7")
  assert_limit(6, [r1, r2, r3, r4, r7, r9], "6")
  assert_limit(5, [r1, r2, r3, r7, r9], "5")
  assert_limit(4, [r1, r2, r7, r9], "4")
  assert_limit(3, [r1, r2, r9], "3")
  assert_limit(2, [r1, r9], "2")
  assert_limit(1, [r1], "1")
  assert_limit(0, [], "0")
}
