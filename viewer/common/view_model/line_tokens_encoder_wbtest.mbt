///| Verifies the Phase 2 encoder (`line_tokens_from_syntax_tokens`) against the
/// legacy `spans_for_line` segmentation: the faithful `LineTokens` it produces
/// must carry the same token boundaries (so the rendered output is unchanged up
/// to the `tok-* -> mtk<n>` class remap).

///|
test "encoder fills gaps and trailing text with default metadata" {
  let line = "let x = 1"
  let tokens : Array[@syntax.Token] = [
    { range: OffsetRange(0, 3), tag: Keyword, text: "let" },
    { range: OffsetRange(8, 9), tag: Number, text: "1" },
  ]
  let lt = line_tokens_from_syntax_tokens(
    line,
    0,
    tokens,
    LanguageIdCodec::new(),
  )
  assert_eq(lt.get_line_content(), line)
  assert_eq(lt.get_count(), 3)
  // "let" | " x = " (gap) | "1"
  assert_eq(lt.get_end_offset(0), 3)
  assert_eq(lt.get_end_offset(1), 8)
  assert_eq(lt.get_end_offset(2), 9)
  assert_eq(lt.get_class_name(0), "mtk3") // Keyword
  assert_eq(lt.get_class_name(1), "mtk1") // gap -> default foreground
  assert_eq(lt.get_class_name(2), "mtk6") // Number
}

///|
test "encoder rebases document-offset tokens onto a non-first line" {
  // Two-line document; tokenize the second line, whose start offset is 4.
  let doc = @model.TextSnapshot("ab=\nCat")
  let line = 1
  let line_start = doc.line_start_offset(line)
  assert_eq(line_start, 4)
  let tokens : Array[@syntax.Token] = [
    { range: OffsetRange(4, 7), tag: Type, text: doc.slice(OffsetRange(4, 7)) },
  ]
  let lt = line_tokens_from_syntax_tokens(
    doc.line_text(line),
    line_start,
    tokens,
    LanguageIdCodec::new(),
  )
  assert_eq(lt.get_line_content(), "Cat")
  assert_eq(lt.get_count(), 1)
  assert_eq(lt.get_end_offset(0), 3)
  assert_eq(lt.get_class_name(0), "mtk9") // Type
}

///|
test "empty line encodes to a single zero-length default token" {
  let lt = line_tokens_from_syntax_tokens("", 0, [], LanguageIdCodec::new())
  assert_eq(lt.get_line_content(), "")
  assert_eq(lt.get_count(), 1)
  assert_eq(lt.get_end_offset(0), 0)
}

///|
/// Reproduces the legacy `spans_for_line` segmentation (token segments clipped
/// to the line + default-metadata gap/trailing fills), returning the
/// non-degenerate segment end offsets in line-local coordinates. Independent of
/// the encoder, so the test below cross-checks the encoder's boundaries against
/// the behavior the retired `spans_for_line` produced.
fn reference_segment_ends(
  line_text : String,
  line_start_offset : Int,
  tokens : Array[@syntax.Token],
) -> Array[Int] {
  let line_length = line_text.length()
  let line_end_offset = line_start_offset + line_length
  let ends = []
  let mut cursor = 0
  for token in tokens {
    let start = token.range.start.max(line_start_offset) - line_start_offset
    let end = token.range.end_exclusive.min(line_end_offset) - line_start_offset
    if cursor < start {
      ends.push(start)
    }
    if start < end {
      ends.push(end)
      cursor = end
    }
  }
  if cursor < line_length {
    ends.push(line_length)
  }
  ends
}

///|
test "encoder boundaries match the legacy segmentation for a tokenized document" {
  let doc = @model.TextSnapshot(
    "pub fn answer { // note\n  let value = 42\n}\n\nDone",
  )
  let tokens = @syntax.highlight(doc)
  let buckets = bucket_by_line(doc, tokens, token => token.range)
  for line in 0..<doc.line_count() {
    let line_start = doc.line_start_offset(line)
    let expected_ends = reference_segment_ends(
      doc.line_text(line),
      line_start,
      buckets[line],
    )
    let lt = line_tokens_from_syntax_tokens(
      doc.line_text(line),
      line_start,
      buckets[line],
      LanguageIdCodec::new(),
    )
    // Compare the non-degenerate boundary sets (the renderer drops zero-length
    // segments; `create_empty` adds one for blank lines the legacy path omits).
    let token_ends = []
    for i in 0..<lt.get_count() {
      if lt.get_start_offset(i) < lt.get_end_offset(i) {
        token_ends.push(lt.get_end_offset(i))
      }
    }
    assert_eq(expected_ends.length(), token_ends.length())
    for i in 0..<expected_ends.length() {
      assert_eq(expected_ends[i], token_ends[i])
    }
  }
}
