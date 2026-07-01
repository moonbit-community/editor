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
  assert_eq(line1.get_standard_token_type(0), STANDARD_TOKEN_TYPE_COMMENT)

  // Out-of-range lines answer an empty token line.
  assert_eq(tokenized.line_tokens_for_line(99).get_count(), 1)
  assert_eq(tokenized.line_tokens_for_line(99).get_line_content(), "")
}

///|
/// Phase 3 round-trip: every token of a model tagged `moonbit` decodes back to
/// `"moonbit"` (gap, syntax, and blank-line tokens alike), and the packed
/// metadata's low 8 bits equal `encode_language_id("moonbit")`. The `mtk<fg>`
/// classes are unchanged — the language field is presentation-neutral.
test "language id round-trips through the per-document codec" {
  // A blank middle line exercises the empty-line token path.
  let doc = @model.TextSnapshot(
    (
      #|let a = 1
      #|
      #|let b = 2
    ),
    language_id="moonbit",
  )
  let tokenized = TokenizedDocument::build(doc, @syntax.highlight(doc))

  // A fresh codec seeded the same way yields the document's numeric id; the
  // build allocated it deterministically from the built-in seed.
  let expected_id = LanguageIdCodec::new().encode_language_id("moonbit")
  assert_true(expected_id != 0)
  for line in 0..<doc.line_count() {
    let tokens = tokenized.line_tokens_for_line(line)
    assert_true(tokens.get_count() >= 1)
    for i in 0..<tokens.get_count() {
      assert_eq(tokens.get_language_id(i), "moonbit")
      assert_eq(
        TokenMetadata::get_language_id(tokens.get_metadata(i)),
        expected_id,
      )
    }
  }

  // The keyword class is still `mtk3` — language id does not touch foreground.
  assert_eq(tokenized.line_tokens_for_line(0).get_class_name(0), "mtk3")
}

///|
/// A different model language decodes to its own string, and a language outside
/// the built-in seed is allocated an id on demand and still round-trips.
test "non-default and unregistered languages round-trip" {
  let js = @model.TextSnapshot("var x = 1", language_id="javascript")
  let js_doc = TokenizedDocument::build(js, @syntax.highlight(js))
  let js_tokens = js_doc.line_tokens_for_line(0)
  for i in 0..<js_tokens.get_count() {
    assert_eq(js_tokens.get_language_id(i), "javascript")
  }

  // "toy" is not a built-in language; `register` allocates it on build.
  let toy = @model.TextSnapshot("x", language_id="toy")
  let toy_doc = TokenizedDocument::build(toy, [])
  let toy_tokens = toy_doc.line_tokens_for_line(0)
  assert_eq(toy_tokens.get_language_id(0), "toy")
}
