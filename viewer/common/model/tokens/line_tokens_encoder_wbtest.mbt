///| Verifies the line-local encoder (`line_tokens_from_lexer_tokens`): the
/// faithful `LineTokens` it produces carries a token segment per lexer token
/// with inter-token gaps and trailing text filled by default-metadata tokens.

///|
test "encoder fills gaps and trailing text with default metadata" {
  let line = "let x = 1"
  let tokens : Array[@syntax.LineToken] = [
    { start: 0, end: 3, tag: Keyword },
    { start: 8, end: 9, tag: Number },
  ]
  let lt = line_tokens_from_lexer_tokens(
    line,
    tokens,
    @services.LanguageIdCodec::new(),
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
test "empty line encodes to a single zero-length default token" {
  let lt = line_tokens_from_lexer_tokens(
    "",
    [],
    @services.LanguageIdCodec::new(),
  )
  assert_eq(lt.get_line_content(), "")
  assert_eq(lt.get_count(), 1)
  assert_eq(lt.get_end_offset(0), 0)
}

///|
test "tokens past the line end clamp to the line" {
  let lt = line_tokens_from_lexer_tokens(
    "ab",
    [{ start: 0, end: 5, tag: Keyword }],
    @services.LanguageIdCodec::new(),
  )
  assert_eq(lt.get_line_content(), "ab")
  assert_eq(lt.get_count(), 1)
  assert_eq(lt.get_end_offset(0), 2)
}
