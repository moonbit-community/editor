///| Faithful conformance port of vscode's `textModel.test.ts` (pinned `vscode/`
/// submodule, commit 294fb350).
///
/// Readonly-subset triage of the file's 40 cases. In scope and ported here (10):
///   - `Editor Model - TextModel`: `validatePosition` (integer asserts),
///     `validatePosition around high-low surrogate pairs 1` and `2`,
///     `validateRange around high-low surrogate pairs 1` and `2`,
///     `modifyPosition`, `getLineFirstNonWhitespaceColumn`,
///     `getLineLastNonWhitespaceColumn`
///   - `TextModel.mightContainRTL`: `nope`, `yes`
/// Backed by new pure-read `TextSnapshot` methods (`validate_position` /
/// `validate_range` with Monaco's surrogate-pair snapping, `modify_position`,
/// `get_line_{first,last}_non_whitespace_column`, `might_contain_rtl`) and the
/// shared `base/common` `strings.mbt` helpers.
///
/// SKIPPED — JS-only NaN/float/undefined semantics not representable with the
/// viewer's integer `Position`/`Range`:
///   - `validatePosition` drops its 4 float/`MIN_VALUE`/`MAX_VALUE` asserts
///     (`(-123.123, -0.5)`, `(MIN_VALUE, MIN_VALUE)`, `(MAX_VALUE, MAX_VALUE)`,
///     `(123.23, 47.5)`); the 13 integer asserts are ported.
///   - `validatePosition handle NaN.`, `issue #71480: validatePosition handle
///     floats`, `issue #71480: validateRange handle floats`, `#50471.
///     getValueInRange with invalid range` (NaN columns), `issue #119632:
///     invalid range` (`undefined` columns).
///
/// SKIPPED — out of scope (subsystems the readonly viewer does not implement):
///   - model options / indentation guessing (11): `guess indentation 1`,
///     `issue #44991/#55818/#70832/#62143/#84217/#65668/#249040`,
///     `normalizeIndentation 1/2`, `issue #168836`.
///   - streaming snapshot / BOM (4): `TextModel.createSnapshot` `empty file`,
///     `file with BOM`, `regular file`, `large file`.
///   - mutation / DI (3): `setValue resets 1/2`, `TextModel does not use events
///     internally`.
///
/// DEFERRED — EOL preference / buffer metadata (same EOL/lonely-CR gap as
/// `model.test`, see Deferred): `getValueLengthInRange` (its CRLF model expects
/// `\r\n`-counted lengths), `getValueLengthInRange different EOL`
/// (`EndOfLinePreference`), and the whole `TextModelData.fromString` suite
/// (`one line text`, `multiline text`, `Non Basic ASCII 1`, `containsRTL 1/2` —
/// `createTextBuffer` EOL guessing + lonely-CR splitting + `getLinesContent`).

///|
fn pos(line : Int, column : Int) -> @base_common.Position {
  Position(line, column)
}

///|
/// Field-wise position compare (avoids `Show`-based `assert_eq` on structs).
fn assert_pos(
  actual : @base_common.Position,
  line : Int,
  column : Int,
) -> Unit raise {
  assert_eq(actual.line_number, line)
  assert_eq(actual.column, column)
}

///|
fn assert_range(
  actual : @base_common.Range,
  sl : Int,
  sc : Int,
  el : Int,
  ec : Int,
) -> Unit raise {
  assert_eq(actual.start_line_number, sl)
  assert_eq(actual.start_column, sc)
  assert_eq(actual.end_line_number, el)
  assert_eq(actual.end_column, ec)
}

///|
fn join_lines(lines : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i, l in lines {
    if i > 0 {
      sb.write_string("\n")
    }
    sb.write_string(l)
  }
  sb.to_string()
}

///|
test "validatePosition" {
  let m = TextSnapshot("line one\nline two")
  assert_pos(m.validate_position(pos(0, 0)), 1, 1)
  assert_pos(m.validate_position(pos(0, 1)), 1, 1)
  assert_pos(m.validate_position(pos(1, 1)), 1, 1)
  assert_pos(m.validate_position(pos(1, 2)), 1, 2)
  assert_pos(m.validate_position(pos(1, 30)), 1, 9)
  assert_pos(m.validate_position(pos(2, 0)), 2, 1)
  assert_pos(m.validate_position(pos(2, 1)), 2, 1)
  assert_pos(m.validate_position(pos(2, 2)), 2, 2)
  assert_pos(m.validate_position(pos(2, 30)), 2, 9)
  assert_pos(m.validate_position(pos(3, 0)), 2, 9)
  assert_pos(m.validate_position(pos(3, 1)), 2, 9)
  assert_pos(m.validate_position(pos(3, 30)), 2, 9)
  assert_pos(m.validate_position(pos(30, 30)), 2, 9)
  // SKIPPED: the 4 float/MIN_VALUE/MAX_VALUE asserts (JS-only; integer Position).
}

///|
test "validatePosition around high-low surrogate pairs 1" {
  let m = TextSnapshot("a\u{1F4DA}b")
  assert_pos(m.validate_position(pos(0, 0)), 1, 1)
  assert_pos(m.validate_position(pos(0, 1)), 1, 1)
  assert_pos(m.validate_position(pos(0, 7)), 1, 1)
  assert_pos(m.validate_position(pos(1, 1)), 1, 1)
  assert_pos(m.validate_position(pos(1, 2)), 1, 2)
  assert_pos(m.validate_position(pos(1, 3)), 1, 2)
  assert_pos(m.validate_position(pos(1, 4)), 1, 4)
  assert_pos(m.validate_position(pos(1, 5)), 1, 5)
  assert_pos(m.validate_position(pos(1, 30)), 1, 5)
  assert_pos(m.validate_position(pos(2, 0)), 1, 5)
  assert_pos(m.validate_position(pos(2, 1)), 1, 5)
  assert_pos(m.validate_position(pos(2, 2)), 1, 5)
  assert_pos(m.validate_position(pos(2, 30)), 1, 5)
  // SKIPPED: the 4 float/MIN_VALUE/MAX_VALUE asserts (JS-only; integer Position).
}

///|
test "validatePosition around high-low surrogate pairs 2" {
  let m = TextSnapshot("a\u{1F4DA}\u{1F4DA}b")
  assert_pos(m.validate_position(pos(1, 1)), 1, 1)
  assert_pos(m.validate_position(pos(1, 2)), 1, 2)
  assert_pos(m.validate_position(pos(1, 3)), 1, 2)
  assert_pos(m.validate_position(pos(1, 4)), 1, 4)
  assert_pos(m.validate_position(pos(1, 5)), 1, 4)
  assert_pos(m.validate_position(pos(1, 6)), 1, 6)
  assert_pos(m.validate_position(pos(1, 7)), 1, 7)
}

///|
test "validateRange around high-low surrogate pairs 1" {
  let m = TextSnapshot("a\u{1F4DA}b")
  assert_range(m.validate_range(rng(0, 0, 0, 1)), 1, 1, 1, 1)
  assert_range(m.validate_range(rng(0, 0, 0, 7)), 1, 1, 1, 1)
  assert_range(m.validate_range(rng(1, 1, 1, 1)), 1, 1, 1, 1)
  assert_range(m.validate_range(rng(1, 1, 1, 2)), 1, 1, 1, 2)
  assert_range(m.validate_range(rng(1, 1, 1, 3)), 1, 1, 1, 4)
  assert_range(m.validate_range(rng(1, 1, 1, 4)), 1, 1, 1, 4)
  assert_range(m.validate_range(rng(1, 1, 1, 5)), 1, 1, 1, 5)
  assert_range(m.validate_range(rng(1, 2, 1, 2)), 1, 2, 1, 2)
  assert_range(m.validate_range(rng(1, 2, 1, 3)), 1, 2, 1, 4)
  assert_range(m.validate_range(rng(1, 2, 1, 4)), 1, 2, 1, 4)
  assert_range(m.validate_range(rng(1, 2, 1, 5)), 1, 2, 1, 5)
  assert_range(m.validate_range(rng(1, 3, 1, 3)), 1, 2, 1, 2)
  assert_range(m.validate_range(rng(1, 3, 1, 4)), 1, 2, 1, 4)
  assert_range(m.validate_range(rng(1, 3, 1, 5)), 1, 2, 1, 5)
  assert_range(m.validate_range(rng(1, 4, 1, 4)), 1, 4, 1, 4)
  assert_range(m.validate_range(rng(1, 4, 1, 5)), 1, 4, 1, 5)
  assert_range(m.validate_range(rng(1, 5, 1, 5)), 1, 5, 1, 5)
}

///|
test "validateRange around high-low surrogate pairs 2" {
  let m = TextSnapshot("a\u{1F4DA}\u{1F4DA}b")
  assert_range(m.validate_range(rng(0, 0, 0, 1)), 1, 1, 1, 1)
  assert_range(m.validate_range(rng(0, 0, 0, 7)), 1, 1, 1, 1)
  assert_range(m.validate_range(rng(1, 1, 1, 1)), 1, 1, 1, 1)
  assert_range(m.validate_range(rng(1, 1, 1, 2)), 1, 1, 1, 2)
  assert_range(m.validate_range(rng(1, 1, 1, 3)), 1, 1, 1, 4)
  assert_range(m.validate_range(rng(1, 1, 1, 4)), 1, 1, 1, 4)
  assert_range(m.validate_range(rng(1, 1, 1, 5)), 1, 1, 1, 6)
  assert_range(m.validate_range(rng(1, 1, 1, 6)), 1, 1, 1, 6)
  assert_range(m.validate_range(rng(1, 1, 1, 7)), 1, 1, 1, 7)
  assert_range(m.validate_range(rng(1, 2, 1, 2)), 1, 2, 1, 2)
  assert_range(m.validate_range(rng(1, 2, 1, 3)), 1, 2, 1, 4)
  assert_range(m.validate_range(rng(1, 2, 1, 4)), 1, 2, 1, 4)
  assert_range(m.validate_range(rng(1, 2, 1, 5)), 1, 2, 1, 6)
  assert_range(m.validate_range(rng(1, 2, 1, 6)), 1, 2, 1, 6)
  assert_range(m.validate_range(rng(1, 2, 1, 7)), 1, 2, 1, 7)
  assert_range(m.validate_range(rng(1, 3, 1, 3)), 1, 2, 1, 2)
  assert_range(m.validate_range(rng(1, 3, 1, 4)), 1, 2, 1, 4)
  assert_range(m.validate_range(rng(1, 3, 1, 5)), 1, 2, 1, 6)
  assert_range(m.validate_range(rng(1, 3, 1, 6)), 1, 2, 1, 6)
  assert_range(m.validate_range(rng(1, 3, 1, 7)), 1, 2, 1, 7)
  assert_range(m.validate_range(rng(1, 4, 1, 4)), 1, 4, 1, 4)
  assert_range(m.validate_range(rng(1, 4, 1, 5)), 1, 4, 1, 6)
  assert_range(m.validate_range(rng(1, 4, 1, 6)), 1, 4, 1, 6)
  assert_range(m.validate_range(rng(1, 4, 1, 7)), 1, 4, 1, 7)
  assert_range(m.validate_range(rng(1, 5, 1, 5)), 1, 4, 1, 4)
  assert_range(m.validate_range(rng(1, 5, 1, 6)), 1, 4, 1, 6)
  assert_range(m.validate_range(rng(1, 5, 1, 7)), 1, 4, 1, 7)
  assert_range(m.validate_range(rng(1, 6, 1, 6)), 1, 6, 1, 6)
  assert_range(m.validate_range(rng(1, 6, 1, 7)), 1, 6, 1, 7)
  assert_range(m.validate_range(rng(1, 7, 1, 7)), 1, 7, 1, 7)
}

///|
test "modifyPosition" {
  let m = TextSnapshot("line one\nline two")
  assert_pos(m.modify_position(pos(1, 1), 0), 1, 1)
  assert_pos(m.modify_position(pos(0, 0), 0), 1, 1)
  assert_pos(m.modify_position(pos(30, 1), 0), 2, 9)
  assert_pos(m.modify_position(pos(1, 1), 17), 2, 9)
  assert_pos(m.modify_position(pos(1, 1), 1), 1, 2)
  assert_pos(m.modify_position(pos(1, 1), 3), 1, 4)
  assert_pos(m.modify_position(pos(1, 2), 10), 2, 3)
  assert_pos(m.modify_position(pos(1, 5), 13), 2, 9)
  assert_pos(m.modify_position(pos(1, 2), 16), 2, 9)
  assert_pos(m.modify_position(pos(2, 9), -17), 1, 1)
  assert_pos(m.modify_position(pos(1, 2), -1), 1, 1)
  assert_pos(m.modify_position(pos(1, 4), -3), 1, 1)
  assert_pos(m.modify_position(pos(2, 3), -10), 1, 2)
  assert_pos(m.modify_position(pos(2, 9), -13), 1, 5)
  assert_pos(m.modify_position(pos(2, 9), -16), 1, 2)
  assert_pos(m.modify_position(pos(1, 2), 17), 2, 9)
  assert_pos(m.modify_position(pos(1, 2), 100), 2, 9)
  assert_pos(m.modify_position(pos(1, 2), -2), 1, 1)
  assert_pos(m.modify_position(pos(1, 2), -100), 1, 1)
  assert_pos(m.modify_position(pos(2, 2), -100), 1, 1)
  assert_pos(m.modify_position(pos(2, 9), -18), 1, 1)
}

///|
test "getLineFirstNonWhitespaceColumn" {
  let m = TextSnapshot(
    join_lines([
      "asd", " asd", "\tasd", "  asd", "\t\tasd", " ", "  ", "\t", "\t\t", "  \tasd",
      "", "",
    ]),
  )
  assert_eq(m.get_line_first_non_whitespace_column(1), 1)
  assert_eq(m.get_line_first_non_whitespace_column(2), 2)
  assert_eq(m.get_line_first_non_whitespace_column(3), 2)
  assert_eq(m.get_line_first_non_whitespace_column(4), 3)
  assert_eq(m.get_line_first_non_whitespace_column(5), 3)
  assert_eq(m.get_line_first_non_whitespace_column(6), 0)
  assert_eq(m.get_line_first_non_whitespace_column(7), 0)
  assert_eq(m.get_line_first_non_whitespace_column(8), 0)
  assert_eq(m.get_line_first_non_whitespace_column(9), 0)
  assert_eq(m.get_line_first_non_whitespace_column(10), 4)
  assert_eq(m.get_line_first_non_whitespace_column(11), 0)
  assert_eq(m.get_line_first_non_whitespace_column(12), 0)
}

///|
test "getLineLastNonWhitespaceColumn" {
  let m = TextSnapshot(
    join_lines([
      "asd", "asd ", "asd\t", "asd  ", "asd\t\t", " ", "  ", "\t", "\t\t", "asd  \t",
      "", "",
    ]),
  )
  assert_eq(m.get_line_last_non_whitespace_column(1), 4)
  assert_eq(m.get_line_last_non_whitespace_column(2), 4)
  assert_eq(m.get_line_last_non_whitespace_column(3), 4)
  assert_eq(m.get_line_last_non_whitespace_column(4), 4)
  assert_eq(m.get_line_last_non_whitespace_column(5), 4)
  assert_eq(m.get_line_last_non_whitespace_column(6), 0)
  assert_eq(m.get_line_last_non_whitespace_column(7), 0)
  assert_eq(m.get_line_last_non_whitespace_column(8), 0)
  assert_eq(m.get_line_last_non_whitespace_column(9), 0)
  assert_eq(m.get_line_last_non_whitespace_column(10), 4)
  assert_eq(m.get_line_last_non_whitespace_column(11), 0)
  assert_eq(m.get_line_last_non_whitespace_column(12), 0)
}

///|
test "mightContainRTL nope" {
  let m = TextSnapshot("hello world!")
  assert_eq(m.might_contain_rtl(), false)
}

///|
test "mightContainRTL yes" {
  let m = TextSnapshot("Hello,\nזוהי עובדה מבוססת שדעתו")
  assert_eq(m.might_contain_rtl(), true)
}
