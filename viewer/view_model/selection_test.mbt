///|
test "selection normalizes model ranges and copies plain source text" {
  let snapshot = @model.TextSnapshot("abc\ndef")
  let selection = @view_model.Selection::from_offsets(snapshot, 6, 1)
  let range = selection.normalized_range(snapshot)
  assert_eq(range.start, 1)
  assert_eq(range.end, 6)
  assert_eq(selection.get_plain_text_to_copy(snapshot), "bc\nde")
}

///|
test "selection rich copy escapes source text" {
  let snapshot = @model.TextSnapshot("a < b && c")
  let selection = @view_model.Selection::from_offsets(
    snapshot,
    0,
    snapshot.length(),
  )
  assert_eq(
    selection.get_rich_text_to_copy(snapshot),
    "<pre class=\"readonly-editor-copy\">a &lt; b &amp;&amp; c</pre>",
  )
}

///|
test "selection copy uses model text not injected text" {
  let snapshot = @model.TextSnapshot("let x = 1")
  let selection = @view_model.Selection::from_offsets(
    snapshot,
    0,
    snapshot.length(),
  )
  assert_eq(selection.get_plain_text_to_copy(snapshot), "let x = 1")
}
