///|
test "lexes keywords strings numbers and comments" {
  let doc = @model.TextSnapshot("pub fn main { let x = \"hi\" // ok\n42 }")
  let tokens = highlight(doc)
  @debug.assert_eq(tokens[0].tag, Keyword)
  @debug.assert_eq(tokens[1].tag, Keyword)
  @debug.assert_eq(tokens[4].tag, Keyword)
  @debug.assert_eq(tokens[7].tag, String)
  @debug.assert_eq(tokens[8].tag, Comment)
  @debug.assert_eq(tokens[9].tag, Number)
}
