///|
fn bucket_texts(
  tokenized : @renderer.TokenizedDocument,
  line : Int,
) -> Array[String] {
  let texts = []
  for token in tokenized.tokens_for_line(line) {
    texts.push(token.text)
  }
  texts
}

///|
test "tokens bucket per line and multi-line tokens cover every line" {
  let doc = @core.DocumentSnapshot(
    (
      #|let a = 1
      #|/* two
      #|line comment */
      #|let b = 2
    ),
    language_id="moonbit",
  )
  // Hand-built tokens with doc offsets: the block comment spans lines 1-2.
  let comment_range = @core.Range(10, 32)
  let tokens : Array[@syntax.Token] = [
    { range: Range(0, 3), tag: Keyword, text: "let" },
    { range: comment_range, tag: Comment, text: doc.slice(comment_range) },
    { range: Range(33, 36), tag: Keyword, text: "let" },
  ]
  let tokenized = @renderer.TokenizedDocument::build(doc, tokens)
  assert_eq(tokenized.token_count, 3)
  debug_inspect(
    bucket_texts(tokenized, 0),
    content=(
      #|["let"]
    ),
  )
  assert_eq(tokenized.tokens_for_line(1).length(), 1)
  assert_true(tokenized.tokens_for_line(1)[0].tag is Comment)
  assert_eq(tokenized.tokens_for_line(2).length(), 1)
  assert_true(tokenized.tokens_for_line(2)[0].tag is Comment)
  debug_inspect(
    bucket_texts(tokenized, 3),
    content=(
      #|["let"]
    ),
  )
  // Out-of-range lines answer empty instead of trapping.
  assert_eq(tokenized.tokens_for_line(99).length(), 0)
}

///|
test "bucketed window frames equal a full lexer pass" {
  let chunks = []
  for i in 0..<200 {
    chunks.push("pub fn generated_value_" + i.to_string() + "() -> Int {")
    chunks.push("  " + i.to_string())
    chunks.push("}")
  }
  let doc = @core.DocumentSnapshot(chunks.join("\n"))
  let tokenized = @renderer.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let source = @renderer.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  let frame = @renderer.build_frame(source, { start_line: 300, end_line: 360 })
  assert_eq(frame.lines.length(), 60)
  assert_eq(frame.lines[0].line_number, 301)
  for line in frame.lines {
    let mut joined = ""
    for span in line.spans {
      joined = joined + line.span_text(span)
    }
    assert_eq(joined, line.text)
  }
}

///|
test "feature buckets accept unsorted ranges" {
  let doc = @core.DocumentSnapshot("aaa\nbbb\nccc\nddd")
  let tokenized = @renderer.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let providers = @language.ProviderResult::{
    hovers: [],
    diagnostics: [],
    definitions: [],
    symbols: [],
    // Deliberately out of order: line 3, then line 0, then a multi-line one.
    semantic_tokens: [
      { range: Range(12, 15), token_type: "variable" },
      { range: Range(0, 3), token_type: "function" },
      { range: Range(4, 11), token_type: "comment" },
    ],
  }
  let source = @renderer.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    providers,
  )
  let frame = @renderer.build_frame(source, { start_line: 0, end_line: 4 })
  let classes = []
  for line in frame.lines {
    let line_classes = []
    for span in line.spans {
      line_classes.push(span.class_name)
    }
    classes.push(line_classes.join("|"))
  }
  debug_inspect(
    classes,
    content=(
      #|[
      #|  "tok-identifier sem-function",
      #|  "tok-identifier sem-comment",
      #|  "tok-identifier sem-comment",
      #|  "tok-identifier sem-variable",
      #|]
    ),
  )
}
