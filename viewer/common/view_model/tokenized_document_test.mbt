///|
/// Whether any of a rendered line's tokens carries `class_name`.
fn line_has_token_class(
  line : @view_model.RenderLine,
  class_name : String,
) -> Bool {
  let tokens = line.tokens
  for i in 0..<tokens.get_count() {
    if tokens.get_class_name(i) == class_name {
      return true
    }
  }
  false
}

///|
test "tokens bucket per line and multi-line tokens cover every line" {
  let doc = @model.TextSnapshot(
    (
      #|let a = 1
      #|/* two
      #|line comment */
      #|let b = 2
    ),
    language_id="moonbit",
  )
  // Hand-built tokens with doc offsets: the block comment spans lines 1-2.
  let comment_range = @base_common.OffsetRange(10, 32)
  let tokens : Array[@syntax.Token] = [
    { range: OffsetRange(0, 3), tag: Keyword, text: "let" },
    { range: comment_range, tag: Comment, text: doc.slice(comment_range) },
    { range: OffsetRange(33, 36), tag: Keyword, text: "let" },
  ]
  let tokenized = @view_model.TokenizedDocument::build(doc, tokens)
  assert_eq(tokenized.token_count, 3)
  // Render the frame and read the encoded `mtk<colorId>` classes: line 0 opens
  // with the keyword color, and the block comment colors every line it covers.
  let source = @view_model.FrameSource(
    tokenized,
    @model.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  let frame = @view_model.build_frame(source, {
    start_line: 1,
    end_line: doc.line_count() + 1,
  })
  assert_eq(frame.lines[0].tokens.get_class_name(0), "mtk3") // Keyword
  assert_true(line_has_token_class(frame.lines[1], "mtk7")) // Comment
  assert_true(line_has_token_class(frame.lines[2], "mtk7")) // Comment
  assert_eq(frame.lines[3].tokens.get_class_name(0), "mtk3") // Keyword
}

///|
test "bucketed window frames equal a full lexer pass" {
  let chunks = []
  for i in 0..<200 {
    chunks.push("pub fn generated_value_" + i.to_string() + "() -> Int {")
    chunks.push("  " + i.to_string())
    chunks.push("}")
  }
  let doc = @model.TextSnapshot(chunks.join("\n"))
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let source = @view_model.FrameSource(
    tokenized,
    @model.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  let frame = @view_model.build_frame(source, { start_line: 301, end_line: 361 })
  assert_eq(frame.lines.length(), 60)
  assert_eq(frame.lines[0].line_number, 301)
  for line in frame.lines {
    let mut joined = ""
    let tokens = line.tokens
    for i in 0..<tokens.get_count() {
      joined = joined + tokens.get_token_text(i)
    }
    assert_eq(joined, line.text)
  }
}
