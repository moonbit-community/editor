///| State/frontier, safe-tokenize, heuristic, and cost branch evidence.

///|
priv suberror TokenTestError {
  TokenFailure
}

///|
priv struct TokenTestHarness {
  access : TokenizationModelAccess
  errors : Array[String]
}

///|
fn token_test_harness(lines : Array[String]) -> TokenTestHarness {
  let attached = Ref(0)
  let scheduler : Ref[TokenizationScheduler?] = Ref(None)
  let errors : Array[String] = []
  let access = TokenizationModelAccess::new(
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
    language_id=() => "token-test",
    attached_count=() => attached.val,
    too_large=() => false,
    disposing=() => false,
    scheduler=() => scheduler.val,
    unexpected_error=message => errors.push(message),
  )
  { access, errors }
}

///|
fn logging_support(
  calls : Array[String],
  initial_calls : Ref[Int],
) -> InternalTokenizationSupportAdapter {
  InternalTokenizationSupportAdapter::new(
    initial_state=() => {
      initial_calls.val += 1
      TokenizerState("initial")
    },
    tokenize_encoded=(text, has_eol, state) => {
      calls.push("\{text}:\{has_eol}:\{to_repr(state)}")
      {
        tokens: [0, tag_to_metadata(Plain)],
        font_info: None,
        end_state: TokenizerState(text),
      }
    },
  )
}

///|
test "TrackingTokenizationStateStore advances, converges, and preserves final completion" {
  let initial = @syntax.TokenizerState("initial")
  let store = TrackingTokenizationStateStore::new(3)
  assert_true(store.get_first_invalid_end_state_line_number() == Some(1))
  guard store.get_first_invalid_line(initial) is Some(first) else {
    fail("expected first invalid line")
  }
  assert_eq(first.line_number, 1)
  assert_true(first.start_state == initial)
  let a = @syntax.TokenizerState("a")
  assert_true(store.set_end_state(1, a))
  assert_true(store.get_first_invalid_end_state_line_number() == Some(2))
  guard store.get_first_invalid_line(initial) is Some(second) else {
    fail("expected second invalid line")
  }
  assert_true(second.start_state == a)
  assert_true(store.set_end_state(2, a))
  assert_true(store.get_first_invalid_end_state_line_number() == Some(3))
  assert_true(store.set_end_state(3, a))
  assert_true(store.all_states_valid())
  assert_eq(store.get_first_invalid_end_state_line_number_or_max(), 0x7FFFFFFF)
  // Equal final state remains valid and reports no change.
  assert_false(store.set_end_state(3, a))
  assert_true(store.all_states_valid())
  // Changed middle state invalidates exactly its successor.
  assert_true(store.set_end_state(2, TokenizerState("b")))
  assert_true(store.get_first_invalid_end_state_line_number() == Some(3))
}

///|
test "TokenizerWithStateStore demands through line and records hasEOL true" {
  let harness = token_test_harness(["one", "two", "three"])
  let calls : Array[String] = []
  let initial_calls = Ref(0)
  let tokenizer = TokenizerWithStateStoreAndTextModel::new(
    3,
    logging_support(calls, initial_calls),
    harness.access,
    @services.language_id_codec,
  )
  let builder = @common_tokens.ContiguousMultilineTokensBuilder::new()
  tokenizer.update_tokens_until_line(builder, 2)
  assert_eq(initial_calls.val, 1)
  assert_eq(calls.length(), 2)
  assert_true(calls[0].contains(":true:"))
  assert_true(calls[1].contains(":true:"))
  assert_true(tokenizer.has_accurate_tokens_for_line(1))
  assert_true(tokenizer.has_accurate_tokens_for_line(2))
  assert_false(tokenizer.has_accurate_tokens_for_line(3))
  assert_eq(builder.finalize().length(), 1)
}

///|
test "cheapness is strict at 2048 and only the first invalid line is cheap" {
  let short = "x".repeat(2047)
  let boundary = "x".repeat(2048)
  let harness = token_test_harness([short, boundary, "x"])
  let tokenizer = TokenizerWithStateStoreAndTextModel::new(
    3,
    logging_support([], Ref(0)),
    harness.access,
    @services.language_id_codec,
  )
  assert_true(tokenizer.is_cheap_to_tokenize(1))
  assert_false(tokenizer.is_cheap_to_tokenize(2))
  let builder = @common_tokens.ContiguousMultilineTokensBuilder::new()
  tokenizer.update_tokens_until_line(builder, 1)
  assert_true(tokenizer.is_cheap_to_tokenize(1))
  assert_false(tokenizer.is_cheap_to_tokenize(2))
  assert_false(tokenizer.is_cheap_to_tokenize(3))
}

///|
test "findLikelyRelevantLines ignores whitespace and replays ancestors without EOL" {
  let harness = token_test_harness([
    "root", "  child", "    ", "    grandchild", "      target",
  ])
  let calls : Array[String] = []
  let support = logging_support(calls, Ref(0))
  let tokenizer = TokenizerWithStateStoreAndTextModel::new(
    5,
    support,
    harness.access,
    @services.language_id_codec,
  )
  let state = tokenizer.guess_start_state(5)
  assert_true(state == TokenizerState("    grandchild"))
  assert_eq(calls.length(), 3)
  for call in calls {
    assert_true(call.contains(":false:"))
  }
}

///|
test "safe_tokenize missing and failing support reports then returns language fallback" {
  let harness = token_test_harness(["abc"])
  let state = @syntax.TokenizerState("state")
  let missing = safe_tokenize(
    @services.language_id_codec,
    "token-test",
    None,
    "abc",
    true,
    state,
    harness.access,
  )
  assert_eq(missing.tokens.length(), 2)
  assert_eq(missing.tokens[0], 3)
  assert_true(missing.end_state == state)
  let failing = InternalTokenizationSupportAdapter::new(
    initial_state=() => state,
    tokenize_encoded=(_text, _has_eol, _state) => {
      raise TokenTestError::TokenFailure
    },
  )
  let fallback = safe_tokenize(
    @services.language_id_codec,
    "token-test",
    Some(failing),
    "abc",
    false,
    state,
    harness.access,
  )
  assert_eq(fallback.tokens[0], 3)
  assert_eq(harness.errors.length(), 1)
}

///|
test "start offset conversion uses next start and final raw UTF16 length" {
  let words : Array[UInt] = [0, 11, 2, 22, 5, 33]
  start_offsets_to_end_offsets(words, 9)
  assert_eq(words[0], 2)
  assert_eq(words[2], 5)
  assert_eq(words[4], 9)
  assert_eq(words[1], 11)
  assert_eq(words[3], 22)
}
