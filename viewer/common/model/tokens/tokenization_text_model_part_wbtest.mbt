///| Part-level conformance: the whole-document sweep threads lexer state line
/// to line, encodes every line into the binary store, and round-trips
/// language ids through the process-wide codec.

///|
/// Toy two-state tokenizer: `/* ... */` block comments carried across lines,
/// a leading `let` tagged as a keyword, everything else untokenized.
priv struct BlockCommentToy {}

///|
let toy_code : @syntax.TokenizerState = TokenizerState("code")

///|
let toy_comment : @syntax.TokenizerState = TokenizerState("comment")

///|
impl @syntax.LineTokenizer for BlockCommentToy with fn initial_state(_self) {
  toy_code
}

///|
impl @syntax.LineTokenizer for BlockCommentToy with fn tokenize_line(
  _self,
  line_text,
  state,
) {
  let tokens : Array[@syntax.LineToken] = []
  let mut at = 0
  let mut in_comment = state == toy_comment
  if !in_comment &&
    line_text.length() >= 3 &&
    line_text[0] == 'l' &&
    line_text[1] == 'e' &&
    line_text[2] == 't' {
    tokens.push({ start: 0, end: 3, tag: Keyword })
    at = 3
  }
  while at < line_text.length() {
    if in_comment {
      let close = find_marker(line_text, at, '*', '/')
      let end = match close {
        Some(index) => index + 2
        None => line_text.length()
      }
      tokens.push({ start: at, end, tag: Comment })
      in_comment = close is None
      at = end
    } else {
      match find_marker(line_text, at, '/', '*') {
        Some(index) => {
          in_comment = true
          at = index
        }
        None => at = line_text.length()
      }
    }
  }
  (tokens, if in_comment { toy_comment } else { toy_code })
}

///|
fn find_marker(
  line_text : String,
  from : Int,
  first : Char,
  second : Char,
) -> Int? {
  for i in from..<(line_text.length() - 1) {
    if line_text[i].to_int() == first.to_int() &&
      line_text[i + 1].to_int() == second.to_int() {
      return Some(i)
    }
  }
  None
}

///|
fn toy_part(text : String, language_id : String) -> TokenizationTextModelPart {
  @syntax.tokenization_registry.register(language_id, BlockCommentToy::{  })
  |> ignore
  let lines : Array[String] = []
  let mut start = 0
  for i in 0..<text.length() {
    if text[i] == '\n' {
      lines.push(text[start:i].to_owned())
      start = i + 1
    }
  }
  lines.push(text[start:text.length()].to_owned())
  TokenizationTextModelPart::new(lines, language_id)
}

///|
test "the sweep threads state across lines and encodes every line" {
  let part = toy_part(
    (
      #|let a = 1
      #|/* two
      #|line comment */
      #|let b = 2
    ),
    "part-toy",
  )

  // Every line's stored `LineTokens` reproduces the line text.
  assert_eq(part.get_line_tokens(1).get_line_content(), "let a = 1")
  assert_eq(part.get_line_tokens(2).get_line_content(), "/* two")
  assert_eq(part.get_line_tokens(3).get_line_content(), "line comment */")
  assert_eq(part.get_line_tokens(4).get_line_content(), "let b = 2")

  // Line 1: "let" (keyword) then " a = 1" (gap, default fg).
  let line1 = part.get_line_tokens(1)
  assert_eq(line1.get_count(), 2)
  assert_eq(line1.get_class_name(0), "mtk3") // Keyword
  assert_eq(line1.get_end_offset(0), 3)
  assert_eq(line1.get_class_name(1), "mtk1") // gap -> default foreground

  // The block comment carries the comment color and standard token type on
  // the interior lines the threaded state covers.
  let line2 = part.get_line_tokens(2)
  assert_eq(line2.get_class_name(0), "mtk7") // Comment
  assert_eq(
    line2.get_standard_token_type(0),
    @common_tokens.STANDARD_TOKEN_TYPE_COMMENT,
  )
  assert_eq(part.get_line_tokens(3).get_class_name(0), "mtk7")

  // Out-of-range lines clamp into the document (the viewer clamps where
  // Monaco throws).
  assert_eq(part.get_line_tokens(99).get_line_content(), "let b = 2")
  assert_eq(part.get_line_tokens(0).get_line_content(), "let a = 1")
}

///|
/// Every token of a part tagged with a language decodes back to it (gap,
/// syntax, and blank-line tokens alike), and the packed metadata's low 8 bits
/// equal the process-wide codec's numeric id. The `mtk<fg>` classes are
/// unchanged — the language field is presentation-neutral.
test "language id round-trips through the process-wide codec" {
  // A blank middle line exercises the empty-line token path; no tokenizer is
  // registered for this language, exercising the null-tokenization path too.
  let part = TokenizationTextModelPart::new(
    ["let a = 1", "", "let b = 2"],
    "part-null-language",
  )
  let expected_id = @services.language_id_codec.register("part-null-language")
  assert_true(expected_id != 0)
  for line_number in 1..<=3 {
    let tokens = part.get_line_tokens(line_number)
    assert_true(tokens.get_count() >= 1)
    for i in 0..<tokens.get_count() {
      assert_eq(tokens.get_language_id(i), "part-null-language")
      assert_eq(
        @common_tokens.TokenMetadata::get_language_id(tokens.get_metadata(i)),
        expected_id,
      )
    }
  }
}

///|
/// The part's own registry subscription (the backend constructor's
/// `_register(TokenizationRegistry.onDidChange(...))`): a (re)registration
/// touching the part's language resets the memo and fires
/// `on_did_change_tokens`; `dispose` unsubscribes.
test "registry changes reset the part and fire on_did_change_tokens" {
  let part = TokenizationTextModelPart::new(
    ["let a = 1", "let b = 2"],
    "part-registry-sub",
  )
  let events : Array[ModelTokensChangedEvent] = []
  part.on_did_change_tokens(event => events.push(event)) |> ignore
  // Registry miss warms the memo with one default token per line.
  assert_eq(part.get_line_tokens(1).get_count(), 1)
  let registration = @syntax.tokenization_registry.register(
    "part-registry-sub",
    BlockCommentToy::{  },
  )
  // The part observed the registration itself: memo dropped, whole-document
  // change announced.
  assert_false(part.has_tokens())
  assert_eq(events.length(), 1)
  assert_false(events[0].semantic_tokens_applied)
  assert_eq(events[0].ranges.length(), 1)
  assert_eq(events[0].ranges[0].from_line_number, 1)
  assert_eq(events[0].ranges[0].to_line_number, 2)
  // The re-read resolves the just-registered tokenizer.
  assert_eq(part.get_line_tokens(1).get_count(), 2)
  // Other languages' registrations do not touch the part.
  let other = @syntax.tokenization_registry.register(
    "part-registry-sub-other",
    BlockCommentToy::{  },
  )
  assert_true(part.has_tokens())
  assert_eq(events.length(), 1)
  other.dispose()
  // dispose unsubscribes: the deregistration no longer reaches the part.
  part.dispose()
  registration.dispose()
  assert_true(part.has_tokens())
  assert_eq(events.length(), 1)
}

///|
test "reset_tokenization drops the memo and re-reads the registry" {
  let part = TokenizationTextModelPart::new(["let a = 1"], "part-reset")
  assert_false(part.has_tokens())
  // Registry miss: the whole line is one default token.
  assert_eq(part.get_line_tokens(1).get_count(), 1)
  assert_true(part.has_tokens())
  // Register the toy, reset, and the keyword segmentation appears.
  let registration = @syntax.tokenization_registry.register("part-reset", BlockCommentToy::{

  })
  part.reset_tokenization()
  assert_false(part.has_tokens())
  assert_eq(part.get_line_tokens(1).get_count(), 2)
  assert_eq(part.get_line_tokens(1).get_class_name(0), "mtk3")
  registration.dispose()
}
