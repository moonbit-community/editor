///|
test "driver records one entry state per line" {
  let doc = @core.DocumentSnapshot("fn main {\n  1\n}")
  let (_, line_entry_states) = tokenize_document_lines(
    doc,
    PlainTokenizer::new(),
  )
  assert_eq(line_entry_states.length(), doc.line_count())
  for state in line_entry_states {
    assert_true(state == TokenizerState(""))
  }
}
