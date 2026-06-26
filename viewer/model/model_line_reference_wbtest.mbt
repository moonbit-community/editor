///| Faithful conformance port of vscode's `model.line.test.ts` (pinned
/// `vscode/` submodule, commit 294fb350).
///
/// Readonly-subset triage of the file's 53 cases: only the single
/// `ModelLine - getIndentLevel` case is in scope. It exercises `model/utils.ts`
/// `computeIndentLevel` — pure, readonly logic. White-box because that helper
/// is package-internal (vscode exports it, but the viewer keeps it private).
///
/// SKIPPED (out of scope, not silently dropped): the 52 `ModelLinesTokens`
/// cases. Every one routes through `testApplyEdits` → `model.applyEdits(...)`
/// (insert / delete / replace / split / append — model mutation a readonly
/// viewer does not implement) AND asserts on
/// `model.tokenization.getLineTokens(...)`, Monaco's background tokenizer
/// (`ManualTokenizationSupport` + `TokenizationRegistry`), which this viewer
/// also does not run (see Phase 3 step 1). The dropped case names, in source
/// order: single delete 1-5; multi delete 6-9; single insert 1-5; multi insert
/// 6-9; insertion on empty line; updates tokens on insertion 1-10; delete
/// second token 2; insert right before second token; delete first char; delete
/// 2nd and 3rd chars; delete first token; delete second token; delete second
/// token + a bit of the third one; delete second and third token; delete
/// everything; noop; equivalent to deleting first two chars; equivalent to
/// deleting from 5 to the end; updates tokens on replace 1-2; split at the
/// beginning; split at the end; split inthe middle 1-2; append empty 1-2;
/// append 1-3.

///|
/// Mirrors the suite's `assertIndentLevel(text, expected, tabSize = 4)`.
fn assert_indent_level(
  text : String,
  expected : Int,
  tab_size~ : Int = 4,
) -> Unit raise {
  assert_eq(compute_indent_level(text, tab_size), expected)
}

///|
test "getIndentLevel" {
  assert_indent_level("", -1)
  assert_indent_level(" ", -1)
  assert_indent_level("   \t", -1)
  assert_indent_level("Hello", 0)
  assert_indent_level(" Hello", 1)
  assert_indent_level("   Hello", 3)
  assert_indent_level("\tHello", 4)
  assert_indent_level(" \tHello", 4)
  assert_indent_level("  \tHello", 4)
  assert_indent_level("   \tHello", 4)
  assert_indent_level("    \tHello", 8)
  assert_indent_level("     \tHello", 8)
  assert_indent_level("\t Hello", 5)
  assert_indent_level("\t \tHello", 8)
}
