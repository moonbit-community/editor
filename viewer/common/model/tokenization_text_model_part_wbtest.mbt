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
  part_from_lines(lines, language_id)
}

///|
fn test_access(
  lines : Array[String],
  language_id : String,
) -> TokenizationModelAccess {
  test_access_with_disposing(lines, language_id, Ref(false))
}

///|
fn test_access_with_disposing(
  lines : Array[String],
  language_id : String,
  disposing : Ref[Bool],
) -> TokenizationModelAccess {
  TokenizationModelAccess::new(
    line_count=() => lines.length(),
    line_content=line_number => lines[line_number - 1],
    line_length=line_number => lines[line_number - 1].length(),
    first_non_whitespace_column=line_number => {
      let index = @base_common.first_non_whitespace_index(
        lines[line_number - 1],
      )
      if index < 0 {
        0
      } else {
        index + 1
      }
    },
    language_id=() => language_id,
    attached_count=() => 0,
    too_large=() => false,
    disposing=() => disposing.val,
    scheduler=() => None,
    unexpected_error=_ => (),
  )
}

///|
fn part_from_lines(
  lines : Array[String],
  language_id : String,
) -> TokenizationTextModelPart {
  TokenizationTextModelPart::new(
    test_access(lines, language_id),
    AttachedViews::new(),
  )
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
  part.force_tokenization(4)

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
}

///|
/// Every token of a part tagged with a language decodes back to it (gap,
/// syntax, and blank-line tokens alike), and the packed metadata's low 8 bits
/// equal the process-wide codec's numeric id. The `mtk<fg>` classes are
/// unchanged — the language field is presentation-neutral.
test "language id round-trips through the process-wide codec" {
  // A blank middle line exercises the empty-line token path; no tokenizer is
  // registered for this language, exercising the null-tokenization path too.
  let part = part_from_lines(
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
  let part = part_from_lines(["let a = 1", "let b = 2"], "part-registry-sub")
  let events : Array[ModelTokensChangedEvent] = []
  part.on_did_change_tokens(event => events.push(event)) |> ignore
  // Registry miss reads one passive default token without warming state.
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
  // Re-read remains passive; explicit force resolves the support.
  assert_eq(part.get_line_tokens(1).get_count(), 1)
  part.force_tokenization(1)
  assert_eq(part.get_line_tokens(1).get_count(), 2)
  // Other languages' registrations do not touch the part.
  let other = @syntax.tokenization_registry.register(
    "part-registry-sub-other",
    BlockCommentToy::{  },
  )
  assert_true(part.has_tokens())
  assert_eq(events.length(), 2)
  other.dispose()
  // dispose unsubscribes: the deregistration no longer reaches the part.
  part.dispose()
  registration.dispose()
  assert_true(part.has_tokens())
  assert_eq(events.length(), 2)
}

///|
test "reset_tokenization drops the memo and re-reads the registry" {
  let part = part_from_lines(["let a = 1"], "part-reset")
  assert_false(part.has_tokens())
  // Registry miss: passive default reads never create stored state.
  assert_eq(part.get_line_tokens(1).get_count(), 1)
  assert_false(part.has_tokens())
  // Register the toy, reset, and the keyword segmentation appears.
  let registration = @syntax.tokenization_registry.register("part-reset", BlockCommentToy::{

  })
  part.reset_tokenization()
  assert_false(part.has_tokens())
  part.force_tokenization(1)
  assert_eq(part.get_line_tokens(1).get_count(), 2)
  assert_eq(part.get_line_tokens(1).get_class_name(0), "mtk3")
  registration.dispose()
}

///|
test "panic get_line_tokens rejects line zero" {
  let part = part_from_lines(["one"], "invalid-line-zero")
  ignore(part.get_line_tokens(0))
}

///|
test "panic force_tokenization rejects line count plus one" {
  let part = part_from_lines(["one"], "invalid-line-high")
  part.force_tokenization(2)
}

///|
test "token_count is a passive stored/default read" {
  let lines = ["one", "two", "three"]
  let calls : Array[String] = []
  let part = TokenizationTextModelPart::new_with_support_resolver(
    test_access(lines, "passive-count"),
    AttachedViews::new(),
    _ => Some(logging_support(calls, Ref(0))),
  )
  assert_eq(part.token_count(), 3)
  assert_true(calls.is_empty())
  part.force_tokenization(2)
  let before = calls.length()
  assert_eq(part.token_count(), 3)
  assert_eq(calls.length(), before)
}

///|
test "font payload forwards unchanged only through the exposed second emitter" {
  let lines = ["one"]
  let disposing = Ref(false)
  let part = TokenizationTextModelPart::new_with_support_resolver(
    test_access_with_disposing(lines, "part-font-forward", disposing),
    AttachedViews::new(),
    _ => Some(logging_support([], Ref(0))),
  )
  let first_emitter_events = Ref(0)
  let public_events : Array[ModelFontTokensChangedEvent] = []
  part.first_font_emitter.event(_ => first_emitter_events.val += 1) |> ignore
  part.on_did_change_font_tokens(event => public_events.push(event)) |> ignore
  let option : FontTokenOption = {
    font_family: Some("Mono"),
    font_size_multiplier: Some(1.25),
    line_height_multiplier: Some(1.5),
  }
  let changes : FontTokensUpdate = AnnotationsUpdate::create([
    { range: OffsetRange(2, 5), annotation: Some(option) },
    { range: OffsetRange(8, 9), annotation: None },
  ])
  part.backend.set_font_info(changes)
  assert_eq(first_emitter_events.val, 0)
  assert_eq(public_events.length(), 1)
  assert_false(
    physical_equal(part.first_font_emitter, part.public_font_emitter),
  )
  assert_true(physical_equal(public_events[0].changes, changes))
  let actual = public_events[0].changes.annotations()
  assert_eq(actual.length(), 2)
  assert_eq(actual[0].range.start, 2)
  assert_eq(actual[0].range.end_exclusive, 5)
  assert_true(actual[0].annotation is Some(_))
  assert_true(actual[1].annotation is None)

  // Both the backend and part forwarding callback have live-disposal guards.
  disposing.val = true
  part.backend.set_font_info(AnnotationsUpdate::create([]))
  assert_eq(public_events.length(), 1)
  disposing.val = false
  part.dispose()
  part.backend.set_font_info(changes)
  assert_eq(public_events.length(), 1)
}

///|
test "dispose releases subscriptions emitters and backend before marking disposed" {
  let part = part_from_lines(["one"], "part-dispose-order")
  let subscription_order : Array[String] = []
  match part.backend_token_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  match part.backend_font_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  part.backend_token_subscription = Some(
    @base_common.Disposable::from(() => {
      if part.disposed {
        abort("token subscription disposed after terminal flag")
      }
      subscription_order.push("tokens")
    }),
  )
  part.backend_font_subscription = Some(
    @base_common.Disposable::from(() => {
      if part.disposed {
        abort("font subscription disposed after terminal flag")
      }
      subscription_order.push("font")
    }),
  )
  part.did_change_tokens.event(_ => ()) |> ignore
  part.first_font_emitter.event(_ => ()) |> ignore
  part.public_font_emitter.event(_ => ()) |> ignore

  part.dispose()
  assert_true(part.disposed)
  assert_eq(subscription_order.length(), 2)
  assert_eq(subscription_order[0], "tokens")
  assert_eq(subscription_order[1], "font")
  assert_true(part.backend_token_subscription is None)
  assert_true(part.backend_font_subscription is None)
  assert_false(part.did_change_tokens.has_listeners())
  assert_false(part.first_font_emitter.has_listeners())
  assert_false(part.public_font_emitter.has_listeners())
  assert_true(part.backend.disposed)

  part.dispose()
  assert_eq(subscription_order.length(), 2)
}

///|
test "assert_not_disposed continues on the live branch" {
  let part = part_from_lines(["one"], "part-live-guard")
  part.assert_not_disposed()
}

///|
test "panic assert_not_disposed rejects a disposed part" {
  let part = part_from_lines(["one"], "part-disposed-guard")
  part.dispose()
  part.assert_not_disposed()
}

///|
test "panic token_count rejects guarded work after disposal" {
  let part = part_from_lines(["one"], "part-disposed-token-count")
  part.dispose()
  ignore(part.token_count())
}
