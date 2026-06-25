// Conformance port of Monaco/VS Code's indentation/marker folding suite.
//
// Ports: vscode/src/vs/editor/contrib/folding/test/browser/indentRangeProvider.test.ts
// From vscode submodule commit 294fb350837dbaee37b949533fead4df4e0e8971.
//
// Adaptation: FoldingMarkers RegExps are modelled as matcher closures (this
// viewer has no regex engine). The helpers below reproduce `/^\s*#region\b/`
// style matching, including the case-insensitive ("i" flag) variants.

///|
fn model_of(lines : Array[String]) -> @model.TextSnapshot {
  TextSnapshot(lines.join("\n"))
}

///|
fn is_word_char(code : Int) -> Bool {
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95
}

///|
fn to_lower_ascii(code : Int) -> Int {
  if code >= 65 && code <= 90 {
    code + 32
  } else {
    code
  }
}

///|
/// Matches `/^\s*<text>\b/`. `text` ends in a word char for all callers, so the
/// trailing `\b` requires end-of-line or a following non-word char.
fn ws_prefix_word_matcher(
  text : String,
  ignore_case? : Bool = false,
) -> (String) -> Bool {
  fn(line) {
    let mut i = 0
    while i < line.length() && (line[i].to_int() == 32 || line[i].to_int() == 9) {
      i += 1
    }
    if i + text.length() > line.length() {
      return false
    }
    for k in 0..<text.length() {
      let mut a = line[i + k].to_int()
      let mut b = text[k].to_int()
      if ignore_case {
        a = to_lower_ascii(a)
        b = to_lower_ascii(b)
      }
      if a != b {
        return false
      }
    }
    let j = i + text.length()
    if j >= line.length() {
      return true
    }
    !is_word_char(line[j].to_int())
  }
}

///|
fn region_markers() -> @folding.FoldingMarkers {
  @folding.FoldingMarkers::new(
    ws_prefix_word_matcher("#region"),
    ws_prefix_word_matcher("#endregion"),
  )
}

///|
fn assert_ranges(
  lines : Array[String],
  expected : Array[(Int, Int, Int)],
  offside : Bool,
  markers? : @folding.FoldingMarkers,
) -> Unit raise {
  let snapshot = model_of(lines)
  let actual = @folding.compute_ranges(snapshot, offside, markers?)
  let actual_ranges : Array[(Int, Int, Int)] = []
  for i in 0..<actual.length() {
    actual_ranges.push(
      (
        actual.get_start_line_number(i),
        actual.get_end_line_number(i),
        actual.get_parent_index(i),
      ),
    )
  }
  guard actual_ranges == expected else {
    fail(
      "ranges mismatch: got \{to_repr(actual_ranges)}, expected \{to_repr(expected)}",
    )
  }
}

///|
test "Fold one level" {
  let range = ["A", "  A", "  A", "  A"]
  assert_ranges(range, [(1, 4, -1)], true)
  assert_ranges(range, [(1, 4, -1)], false)
}

///|
test "Fold two levels" {
  let range = ["A", "  A", "  A", "    A", "    A"]
  assert_ranges(range, [(1, 5, -1), (3, 5, 0)], true)
  assert_ranges(range, [(1, 5, -1), (3, 5, 0)], false)
}

///|
test "Fold three levels" {
  let range = ["A", "  A", "    A", "      A", "A"]
  assert_ranges(range, [(1, 4, -1), (2, 4, 0), (3, 4, 1)], true)
  assert_ranges(range, [(1, 4, -1), (2, 4, 0), (3, 4, 1)], false)
}

///|
test "Fold decreasing indent" {
  let range = ["    A", "  A", "A"]
  assert_ranges(range, [], true)
  assert_ranges(range, [], false)
}

///|
test "Fold Java" {
  assert_ranges(
    [
      "class A {", "  void foo() {", "    console.log();", "    console.log();",
      "  }", "", "  void bar() {", "    console.log();", "  }", "}", "interface B {",
      "  void bar();", "}",
    ],
    [(1, 9, -1), (2, 4, 0), (7, 8, 0), (11, 12, -1)],
    false,
  )
}

///|
test "Fold Javadoc" {
  assert_ranges(
    ["/**", " * Comment", " */", "class A {", "  void foo() {", "  }", "}"],
    [(1, 3, -1), (4, 6, -1)],
    false,
  )
}

///|
test "Fold Whitespace Java" {
  assert_ranges(
    [
      "class A {", "", "  void foo() {", "     ", "     return 0;", "  }", "      ",
      "}",
    ],
    [(1, 7, -1), (3, 5, 0)],
    false,
  )
}

///|
test "Fold Whitespace Python" {
  assert_ranges(
    [
      "def a:", "  pass", "   ", "  def b:", "    pass", "  ", "      ", "def c: # since there was a deintent here",
    ],
    [(1, 5, -1), (4, 5, 0)],
    true,
  )
}

///|
test "Fold Tabs" {
  assert_ranges(
    [
      "class A {", "\t\t", "\tvoid foo() {", "\t \t//hello", "\t    return 0;", "  \t}",
      "      ", "}",
    ],
    [(1, 7, -1), (3, 5, 0)],
    false,
  )
}

///|
test "Inside region, indented" {
  assert_ranges(
    [
      "class A {", "  #region", "  void foo() {", "     ", "     return 0;", "  }",
      "  #endregion", "}",
    ],
    [(1, 7, -1), (2, 7, 0), (3, 5, 1)],
    false,
    markers=region_markers(),
  )
}

///|
test "Inside region, not indented" {
  assert_ranges(
    [
      "var x;", "#region", "void foo() {", "     ", "     return 0;", "  }", "#endregion",
      "",
    ],
    [(2, 7, -1), (3, 6, 0)],
    false,
    markers=region_markers(),
  )
}

///|
test "Empty Regions" {
  assert_ranges(
    ["var x;", "#region", "#endregion", "#region", "", "#endregion", "var y;"],
    [(2, 3, -1), (4, 6, -1)],
    false,
    markers=region_markers(),
  )
}

///|
test "Nested Regions" {
  assert_ranges(
    ["var x;", "#region", "#region", "", "#endregion", "#endregion", "var y;"],
    [(2, 6, -1), (3, 5, 0)],
    false,
    markers=region_markers(),
  )
}

///|
test "Nested Regions 2" {
  assert_ranges(
    [
      "class A {", "  #region", "", "  #region", "", "  #endregion", "  // comment",
      "  #endregion", "}",
    ],
    [(1, 8, -1), (2, 8, 0), (4, 6, 1)],
    false,
    markers=region_markers(),
  )
}

///|
test "Incomplete Regions" {
  assert_ranges(
    ["class A {", "#region", "  // comment", "}"],
    [(2, 3, -1)],
    false,
    markers=region_markers(),
  )
}

///|
test "Incomplete Regions 2" {
  assert_ranges(
    [
      "", "#region", "#region", "#region", "  // comment", "#endregion", "#endregion",
      " // hello",
    ],
    [(3, 7, -1), (4, 6, 0)],
    false,
    markers=region_markers(),
  )
}

///|
test "Indented region before" {
  assert_ranges(
    ["if (x)", "  return;", "", "#region", "  // comment", "#endregion"],
    [(1, 3, -1), (4, 6, -1)],
    false,
    markers=region_markers(),
  )
}

///|
test "Indented region before 2" {
  assert_ranges(
    [
      "if (x)", "  log();", "", "    #region", "      // comment", "    #endregion",
    ],
    [(1, 6, -1), (2, 6, 0), (4, 6, 1)],
    false,
    markers=region_markers(),
  )
}

///|
test "Indented region in-between" {
  assert_ranges(
    ["#region", "  // comment", "  if (x)", "    return;", "", "#endregion"],
    [(1, 6, -1), (3, 5, 0)],
    false,
    markers=region_markers(),
  )
}

///|
test "Indented region after" {
  assert_ranges(
    ["#region", "  // comment", "", "#endregion", "  if (x)", "    return;"],
    [(1, 4, -1), (5, 6, -1)],
    false,
    markers=region_markers(),
  )
}

///|
test "With off-side" {
  assert_ranges(
    ["#region", "  ", "", "#endregion", ""],
    [(1, 4, -1)],
    true,
    markers=region_markers(),
  )
}

///|
test "Nested with off-side" {
  assert_ranges(
    ["#region", "  ", "#region", "", "#endregion", "", "#endregion", ""],
    [(1, 7, -1), (3, 5, 0)],
    true,
    markers=region_markers(),
  )
}

///|
test "Issue 35981" {
  assert_ranges(
    [
      "function thisFoldsToEndOfPage() {", "  const variable = []", "    // #region",
      "    .reduce((a, b) => a,[]);", "}", "", "function thisFoldsProperly() {",
      "  const foo = \"bar\"", "}",
    ],
    [(1, 4, -1), (2, 4, 0), (7, 8, -1)],
    false,
    markers=region_markers(),
  )
}

///|
test "Misspelled Markers" {
  assert_ranges(
    [
      "#Region", "#endregion", "#regionsandmore", "#endregion", "#region", "#end region",
      "#region", "#endregionff",
    ],
    [],
    true,
    markers=region_markers(),
  )
}

///|
test "Issue 79359" {
  assert_ranges(
    [
      "#region", "", "class A", "  foo", "", "class A", "  foo", "", "#endregion",
    ],
    [(1, 9, -1), (3, 4, 0), (6, 7, 0)],
    true,
    markers=region_markers(),
  )
}

///|
test "Markers with stateful flags" {
  // start: /^\s*#region\b/g, end: /^\s*#endregion\b/g
  assert_ranges(
    ["#region", "content", "#endregion"],
    [(1, 3, -1)],
    false,
    markers=@folding.FoldingMarkers::new(
      ws_prefix_word_matcher("#region"),
      ws_prefix_word_matcher("#endregion"),
    ),
  )

  // start: /^\s*#region\b/gi, end: /^\s*#endregion\b/g
  assert_ranges(
    ["#REGION", "content", "#endregion"],
    [(1, 3, -1)],
    false,
    markers=@folding.FoldingMarkers::new(
      ws_prefix_word_matcher("#region", ignore_case=true),
      ws_prefix_word_matcher("#endregion"),
    ),
  )

  // start: /^\s*#region\b/gi, end: /^\s*#endregion\b/g
  assert_ranges(
    ["#REGION", "content", "#ENDREGION"],
    [],
    false,
    markers=@folding.FoldingMarkers::new(
      ws_prefix_word_matcher("#region", ignore_case=true),
      ws_prefix_word_matcher("#endregion"),
    ),
  )

  // start: /^\s*#region\b/g, end: /^\s*#endregion\b/gi
  assert_ranges(
    ["#REGION", "content", "#ENDREGION"],
    [],
    false,
    markers=@folding.FoldingMarkers::new(
      ws_prefix_word_matcher("#region"),
      ws_prefix_word_matcher("#endregion", ignore_case=true),
    ),
  )
}
