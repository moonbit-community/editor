///| Phase 3 storage: `TokenizedDocument` retains a faithful per-line
/// `LineTokens` alongside the legacy buckets. White-box so the `LineTokens`
/// accessors can be called directly.

///|
test "line_tokens_for_line encodes each line and covers its content" {
  let doc = @model.TextSnapshot(
    (
      #|let a = 1
      #|/* two
      #|line comment */
      #|let b = 2
    ),
    language_id="moonbit",
  )
  let comment_range = @base_common.OffsetRange(10, 32)
  let tokens : Array[@syntax.Token] = [
    { range: OffsetRange(0, 3), tag: Keyword, text: "let" },
    { range: comment_range, tag: Comment, text: doc.slice(comment_range) },
    { range: OffsetRange(33, 36), tag: Keyword, text: "let" },
  ]
  let tokenized = TokenizedDocument::build(doc, tokens)

  // The stored `LineTokens` reproduces each line's text.
  for line in 0..<doc.line_count() {
    assert_eq(
      tokenized.line_tokens_for_line(line).get_line_content(),
      doc.line_text(line),
    )
  }

  // Line 0: "let" (keyword) then " a = 1" (gap, default fg).
  let line0 = tokenized.line_tokens_for_line(0)
  assert_eq(line0.get_count(), 2)
  assert_eq(line0.get_class_name(0), "mtk3") // Keyword
  assert_eq(line0.get_end_offset(0), 3)
  assert_eq(line0.get_class_name(1), "mtk1") // gap -> default foreground

  // The block comment carries the comment color and standard token type on the
  // interior lines it covers.
  let line1 = tokenized.line_tokens_for_line(1)
  assert_eq(line1.get_class_name(0), "mtk7") // Comment
  assert_eq(
    line1.get_standard_token_type(0),
    STANDARD_TOKEN_TYPE_COMMENT,
  )

  // Out-of-range lines answer an empty token line.
  assert_eq(tokenized.line_tokens_for_line(99).get_count(), 1)
  assert_eq(tokenized.line_tokens_for_line(99).get_line_content(), "")
}
