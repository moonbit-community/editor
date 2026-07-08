///| Faithful conformance port of vscode's `model.test.ts` (pinned `vscode/`
/// submodule, commit 294fb350).
///
/// Readonly-subset triage of the file's 32 cases. In scope: 7 readonly reads,
/// of which 6 are ported here against `TextSnapshot` (the 7th, `Get word at
/// position`, is ported in `word_helper_wbtest.mbt`):
///   - `Editor Model - Model`: `model getValue`, `getValueInRange`,
///     `getValueLengthInRange`
///   - `Editor Model - Model Line Separators`: `model getValue`, `model lines`,
///     `Bug 13333: Model should line break on lonely CR too`
///
/// SKIPPED (out of scope, not silently dropped):
///   - 23 `Editor Model - Model` editing/eventing cases — `model insert*`
///     (empty / without newline 1-2 / one / two / many newlines), `model
///     delete*` (empty / one line / one line 2 / all from a line / two lines /
///     many lines / everything), every `* eventing` variant of those, `setValue
///     eventing`, and `issue #46342` — all call `model.applyEdits`/`setValue`
///     (model mutation) or assert a `ModelRawContentChangedEvent` the readonly
///     viewer does not emit.
///   - `Editor Model - Words`: `getWordAtPosition at embedded language
///     boundaries` and `issue #61296` — need DI language services, per-language
///     word patterns, and tokenization (out of scope).
///

///|
/// The suite's shared 5-line model (`LINE1..LINE5` joined with mixed CRLF/LF, as
/// in `setup()`).
fn this_model() -> TextSnapshot {
  TextSnapshot("My First Line\r\n\t\tMy Second Line\n    Third Line\n\r\n1")
}

///|
fn rng(sl : Int, sc : Int, el : Int, ec : Int) -> @base_common.Range {
  Range(sl, sc, el, ec)
}

///|
test "model getValue" {
  assert_eq(
    this_model().get_value(),
    "My First Line\n\t\tMy Second Line\n    Third Line\n\n1",
  )
}

///|
test "getValueInRange" {
  let m = this_model()
  assert_eq(m.get_value_in_range(rng(1, 1, 1, 1)), "")
  assert_eq(m.get_value_in_range(rng(1, 1, 1, 2)), "M")
  assert_eq(m.get_value_in_range(rng(1, 2, 1, 3)), "y")
  assert_eq(m.get_value_in_range(rng(1, 1, 1, 14)), "My First Line")
  assert_eq(m.get_value_in_range(rng(1, 1, 2, 1)), "My First Line\n")
  assert_eq(m.get_value_in_range(rng(1, 1, 2, 2)), "My First Line\n\t")
  assert_eq(m.get_value_in_range(rng(1, 1, 2, 3)), "My First Line\n\t\t")
  assert_eq(
    m.get_value_in_range(rng(1, 1, 2, 17)),
    "My First Line\n\t\tMy Second Line",
  )
  assert_eq(
    m.get_value_in_range(rng(1, 1, 3, 1)),
    "My First Line\n\t\tMy Second Line\n",
  )
  assert_eq(
    m.get_value_in_range(rng(1, 1, 4, 1)),
    "My First Line\n\t\tMy Second Line\n    Third Line\n",
  )
}

///|
test "getValueLengthInRange" {
  let m = this_model()
  assert_eq(m.get_value_length_in_range(rng(1, 1, 1, 1)), "".length())
  assert_eq(m.get_value_length_in_range(rng(1, 1, 1, 2)), "M".length())
  assert_eq(m.get_value_length_in_range(rng(1, 2, 1, 3)), "y".length())
  assert_eq(
    m.get_value_length_in_range(rng(1, 1, 1, 14)),
    "My First Line".length(),
  )
  assert_eq(
    m.get_value_length_in_range(rng(1, 1, 2, 1)),
    "My First Line\n".length(),
  )
  assert_eq(
    m.get_value_length_in_range(rng(1, 1, 2, 2)),
    "My First Line\n\t".length(),
  )
  assert_eq(
    m.get_value_length_in_range(rng(1, 1, 2, 3)),
    "My First Line\n\t\t".length(),
  )
  assert_eq(
    m.get_value_length_in_range(rng(1, 1, 2, 17)),
    "My First Line\n\t\tMy Second Line".length(),
  )
  assert_eq(
    m.get_value_length_in_range(rng(1, 1, 3, 1)),
    "My First Line\n\t\tMy Second Line\n".length(),
  )
  assert_eq(
    m.get_value_length_in_range(rng(1, 1, 4, 1)),
    "My First Line\n\t\tMy Second Line\n    Third Line\n".length(),
  )
}

///|
/// `Editor Model - Model Line Separators` suite: `\u{2028}` (LINE SEPARATOR) is
/// not a line break — only `\n`/`\r`/`\r\n` are.
fn this_model_line_separators() -> TextSnapshot {
  TextSnapshot(
    "My First Line\u{2028}\t\tMy Second Line\n    Third Line\u{2028}\r\n1",
  )
}

///|
test "model getValue [Line Separators]" {
  assert_eq(
    this_model_line_separators().get_value(),
    "My First Line\u{2028}\t\tMy Second Line\n    Third Line\u{2028}\n1",
  )
}

///|
test "model lines" {
  assert_eq(this_model_line_separators().line_count(), 3)
}

///|
/// Adaptation: Monaco expects `getValue()` = `"Hello\r\nWorld!\r\nAnother
/// line"` because `createTextBuffer` normalizes to the majority EOL (`\r\n`
/// here); the viewer has no EOL option and always joins with `\n`.
test "Bug 13333: Model should line break on lonely CR too" {
  let m = TextSnapshot("Hello\rWorld!\r\nAnother line")
  assert_eq(m.line_count(), 3)
  assert_eq(m.get_value(), "Hello\nWorld!\nAnother line")
}
