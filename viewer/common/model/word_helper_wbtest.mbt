// Conformance port of the "Get word at position" cases from
// vscode/src/vs/editor/test/common/model/model.test.ts (default word
// definition).

///|
fn word_at(model : TextModel, column : Int) -> WordAtPosition? {
  model.get_word_at_position(Position(1, column))
}

///|
test "Get word at position" {
  let snapshot = wb_model("This text has some  words. ")
  assert_true(
    word_at(snapshot, 1) ==
    Some({ word: "This", start_column: 1, end_column: 5 }),
  )
  assert_true(
    word_at(snapshot, 2) ==
    Some({ word: "This", start_column: 1, end_column: 5 }),
  )
  assert_true(
    word_at(snapshot, 4) ==
    Some({ word: "This", start_column: 1, end_column: 5 }),
  )
  assert_true(
    word_at(snapshot, 5) ==
    Some({ word: "This", start_column: 1, end_column: 5 }),
  )
  assert_true(
    word_at(snapshot, 6) ==
    Some({ word: "text", start_column: 6, end_column: 10 }),
  )
  assert_true(
    word_at(snapshot, 19) ==
    Some({ word: "some", start_column: 15, end_column: 19 }),
  )
  assert_true(word_at(snapshot, 20) is None)
  assert_true(
    word_at(snapshot, 21) ==
    Some({ word: "words", start_column: 21, end_column: 26 }),
  )
  assert_true(
    word_at(snapshot, 26) ==
    Some({ word: "words", start_column: 21, end_column: 26 }),
  )
  assert_true(word_at(snapshot, 27) is None)
  assert_true(word_at(snapshot, 28) is None)
}

///|
test "word number alternative" {
  // (-?\d*\.\d\w*) takes alternation priority; '.' is a separator so a word run
  // splits around it (wordHelper.ts:39).
  let snapshot = wb_model("abc3.14def")
  assert_true(
    word_at(snapshot, 1) ==
    Some({ word: "abc3", start_column: 1, end_column: 5 }),
  )
  assert_true(
    word_at(snapshot, 6) ==
    Some({ word: ".14def", start_column: 5, end_column: 11 }),
  )
  let decimal = wb_model(".5")
  assert_true(
    word_at(decimal, 1) == Some({ word: ".5", start_column: 1, end_column: 3 }),
  )
}
