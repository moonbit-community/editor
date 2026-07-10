///|
fn inlay_request_model(text : String) -> @model.TextModel {
  TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/inlay-request-test.mbt",
    ),
    "inlay-request-test.mbt",
    "moonbit",
    1,
    "request-test",
    text,
  )
}

///|
fn inlay_hint(
  line_number : Int,
  column : Int,
  label : String,
) -> @language.InlayHint {
  InlayHint(Position(line_number, column), label)
}

///|
priv suberror InlayTestProviderError {
  InlayTestProviderError
}

///|
priv struct StaticInlayProvider {
  hints : Array[@language.InlayHint]
  observed_ranges : Array[@base_common.OffsetRange]
  observed_tokens : Array[@language.CancellationToken]
  fail : Bool
}

///|
impl @language.InlayHintsProvider for StaticInlayProvider with fn provide_inlay_hints(
  self,
  _model,
  range,
  token,
) {
  self.observed_ranges.push(range)
  self.observed_tokens.push(token)
  if self.fail {
    raise InlayTestProviderError
  }
  self.hints
}

///|
priv struct ControlledInlayProvider {
  name : String
  started : @aqueue.Queue[
    (String, @base_common.OffsetRange, @language.CancellationToken),
  ]
  gate : @aqueue.Queue[Unit]
  signal_after : @aqueue.Queue[Unit]?
  hints : Array[@language.InlayHint]
  fail_after_gate : Bool
}

///|
impl @language.InlayHintsProvider for ControlledInlayProvider with fn provide_inlay_hints(
  self,
  _model,
  range,
  token,
) {
  self.started.put((self.name, range, token))
  self.gate.get()
  match self.signal_after {
    Some(queue) => queue.put(())
    None => ()
  }
  if self.fail_after_gate {
    raise InlayTestProviderError
  }
  self.hints
}

///|
async fn run_inlay_test_tasks_concurrently(
  tasks : Array[async () -> Unit],
) -> Unit {
  @async.with_task_group() <| group => {
    for task in tasks {
      group.spawn_bg(task)
    }
  }
}

///|
async test "inlay request supports injected B-to-A concurrent completion" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let log_service = @log.LogService::new()
  let started = @aqueue.Queue(kind=Unbounded)
  let release_a = @aqueue.Queue(kind=Unbounded)
  let release_b = @aqueue.Queue(kind=Unbounded)
  let provider_a = ControlledInlayProvider::{
    name: "a",
    started,
    gate: release_a,
    signal_after: None,
    hints: [inlay_hint(1, 1, "a")],
    fail_after_gate: false,
  }
  let provider_b = ControlledInlayProvider::{
    name: "b",
    started,
    gate: release_b,
    signal_after: Some(release_a),
    hints: [inlay_hint(1, 1, "b")],
    fail_after_gate: false,
  }
  let registration_a = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider_a,
  )
  let registration_b = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider_b,
  )
  let token = @language.CancellationToken::new()
  @async.with_task_group() <| group => {
    let request = group.spawn(() => {
      languages.inlay_hints_for_ranges(
        model,
        [model.get_full_model_range()],
        token,
        log_service,
        run_tasks=run_inlay_test_tasks_concurrently,
      )
    })
    let (first_name, _, first_token) = started.get()
    assert_eq(first_name, "b")
    assert_true(physical_equal(first_token, token))
    let (second_name, _, second_token) = started.get()
    assert_eq(second_name, "a")
    assert_true(physical_equal(second_token, token))
    // Both tasks have started. Releasing B also releases A only as B returns,
    // so completion-order accumulation is deterministically B then A.
    release_b.put(())
    let fragments = request.wait()
    assert_eq(fragments.items.length(), 2)
    assert_eq(fragments.items[0].hint.label, "b")
    assert_eq(fragments.items[1].hint.label, "a")
    assert_eq(fragments.provider.length(), 2)
    assert_true(
      physical_equal(fragments.provider[0], fragments.items[0].provider),
    )
    assert_true(
      physical_equal(fragments.provider[1], fragments.items[1].provider),
    )
  }
  registration_a.dispose()
  registration_b.dispose()
}

///|
async test "inlay request fans out captured ranges and keeps caller token" {
  let languages = Languages::new()
  let model = inlay_request_model("ab\ncde\n")
  let observed_ranges : Array[@base_common.OffsetRange] = []
  let observed_tokens : Array[@language.CancellationToken] = []
  let provider = StaticInlayProvider::{
    hints: [inlay_hint(1, 1, "hint")],
    observed_ranges,
    observed_tokens,
    fail: false,
  }
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider,
  )
  let ranges : Array[@base_common.Range] = [
    Range(1, 1, 1, 2),
    Range(2, 1, 2, 3),
  ]
  let token = @language.CancellationToken::new()
  let fragments = languages.inlay_hints_for_ranges(
    model,
    ranges,
    token,
    @log.LogService::new(),
  )
  observed_ranges.sort_by((left, right) => left.start - right.start)
  assert_true(observed_ranges == [OffsetRange(0, 1), OffsetRange(3, 5)])
  assert_eq(observed_tokens.length(), 2)
  assert_true(physical_equal(observed_tokens[0], token))
  assert_true(physical_equal(observed_tokens[1], token))
  assert_true(fragments.ranges == ranges)
  assert_eq(fragments.items.length(), 2)
  assert_eq(fragments.provider.length(), 1)
  // Disposal after return cannot retroactively mutate accepted fragments.
  registration.dispose()
  assert_eq(fragments.items.length(), 2)
}

///|
async test "inlay snapshot excludes inactive and nonmatching registrations" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let inactive_ranges : Array[@base_common.OffsetRange] = []
  let inactive = StaticInlayProvider::{
    hints: [inlay_hint(1, 1, "inactive")],
    observed_ranges: inactive_ranges,
    observed_tokens: [],
    fail: false,
  }
  let inactive_registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    inactive,
  )
  inactive_registration.dispose()
  let mismatched_ranges : Array[@base_common.OffsetRange] = []
  let mismatched = StaticInlayProvider::{
    hints: [inlay_hint(1, 1, "mismatched")],
    observed_ranges: mismatched_ranges,
    observed_tokens: [],
    fail: false,
  }
  let mismatched_registration = languages.register_inlay_hints_provider(
    LanguageId("other"),
    mismatched,
  )
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [model.get_full_model_range()],
    @language.CancellationToken::new(),
    @log.LogService::new(),
  )
  assert_eq(inactive_ranges.length(), 0)
  assert_eq(mismatched_ranges.length(), 0)
  assert_eq(fragments.items.length(), 0)
  mismatched_registration.dispose()
}

///|
async test "model-wide inlay API stays compatible and forwards optional token" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let observed_tokens : Array[@language.CancellationToken] = []
  let provider = StaticInlayProvider::{
    hints: [inlay_hint(1, 1, "hint")],
    observed_ranges: [],
    observed_tokens,
    fail: false,
  }
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider,
  )
  let token = @language.CancellationToken::new()
  let explicit = languages.inlay_hints_for_model(
    model,
    @log.LogService::new(),
    token~,
  )
  assert_eq(explicit.length(), 1)
  assert_true(physical_equal(observed_tokens[0], token))
  // Existing two-argument callers still receive the same model-wide result.
  let compatible = languages.inlay_hints_for_model(
    model,
    @log.LogService::new(),
  )
  assert_eq(compatible.length(), 1)
  assert_eq(compatible[0].label, "hint")
  registration.dispose()
}

///|
async test "inlay request rejects a registration disposed during await" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let started = @aqueue.Queue(kind=Unbounded)
  let gate = @aqueue.Queue(kind=Unbounded)
  let provider = ControlledInlayProvider::{
    name: "disposed",
    started,
    gate,
    signal_after: None,
    hints: [inlay_hint(1, 1, "stale")],
    fail_after_gate: false,
  }
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider,
  )
  @async.with_task_group() <| group => {
    let request = group.spawn(() => {
      languages.inlay_hints_for_ranges(
        model,
        [model.get_full_model_range()],
        @language.CancellationToken::new(),
        @log.LogService::new(),
      )
    })
    started.get() |> ignore
    registration.dispose()
    gate.put(())
    let fragments = request.wait()
    assert_eq(fragments.items.length(), 0)
    assert_eq(fragments.provider.length(), 0)
  }
}

///|
async test "inlay cancellation is silent and rejects all settled data" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let memory = @log.MemoryLogger::new()
  let log_service = @log.LogService::new(logger=memory)
  let started = @aqueue.Queue(kind=Unbounded)
  let gate = @aqueue.Queue(kind=Unbounded)
  let provider = ControlledInlayProvider::{
    name: "cancelled",
    started,
    gate,
    signal_after: None,
    hints: [],
    fail_after_gate: true,
  }
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider,
  )
  let token = @language.CancellationToken::new()
  @async.with_task_group() <| group => {
    let request = group.spawn(allow_failure=true, () => {
      languages.inlay_hints_for_ranges(
        model,
        [model.get_full_model_range()],
        token,
        log_service,
      )
    })
    let (_, _, observed_token) = started.get()
    assert_true(physical_equal(observed_token, token))
    token.cancel()
    gate.put(())
    try request.wait() catch {
      InlayHintsRequestCancelled => ()
      _ => fail("expected inlay request cancellation")
    } noraise {
      _ => fail("expected inlay request cancellation")
    }
  }
  assert_eq(memory.entries().length(), 0)
  registration.dispose()
}

///|
async test "disposed model rejects an otherwise successful inlay request" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let provider = StaticInlayProvider::{
    hints: [inlay_hint(1, 1, "hint")],
    observed_ranges: [],
    observed_tokens: [],
    fail: false,
  }
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider,
  )
  model.dispose()
  try
    languages.inlay_hints_for_ranges(
      model,
      [model.get_full_model_range()],
      @language.CancellationToken::new(),
      @log.LogService::new(),
    )
  catch {
    InlayHintsRequestCancelled => ()
    _ => fail("expected disposed-model cancellation")
  } noraise {
    _ => fail("expected disposed-model cancellation")
  }
  registration.dispose()
}

///|
async test "inlay provider failure is contained without hiding siblings" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let memory = @log.MemoryLogger::new()
  let log_service = @log.LogService::new(logger=memory)
  let good = StaticInlayProvider::{
    hints: [inlay_hint(1, 1, "good")],
    observed_ranges: [],
    observed_tokens: [],
    fail: false,
  }
  let bad = StaticInlayProvider::{
    hints: [],
    observed_ranges: [],
    observed_tokens: [],
    fail: true,
  }
  let good_registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    good,
  )
  let bad_registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    bad,
  )
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [model.get_full_model_range()],
    @language.CancellationToken::new(),
    log_service,
  )
  assert_eq(fragments.items.length(), 1)
  assert_eq(fragments.items[0].hint.label, "good")
  assert_eq(memory.entries().length(), 1)
  assert_eq(memory.entries()[0].category, "language.inlayHints")
  assert_true(memory.entries()[0].details[2] == ("providerIndex", "1"))
  good_registration.dispose()
  bad_registration.dispose()
}

///|
async test "inlay fragments derive word and token anchors then sort positions" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n!@#\n")
  let provider = StaticInlayProvider::{
    hints: [
      inlay_hint(2, 2, "token"),
      inlay_hint(1, 2, "after"),
      inlay_hint(1, 1, "before"),
    ],
    observed_ranges: [],
    observed_tokens: [],
    fail: false,
  }
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider,
  )
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [model.get_full_model_range()],
    @language.CancellationToken::new(),
    @log.LogService::new(),
  )
  assert_true(
    fragments.items.map(item => item.hint.label) == ["before", "after", "token"],
  )
  assert_true(fragments.items[0].anchor.direction == Before)
  assert_true(fragments.items[0].anchor.range == Range(1, 1, 1, 4))
  assert_true(fragments.items[1].anchor.direction == After)
  assert_true(fragments.items[1].anchor.range == Range(1, 1, 1, 2))
  assert_true(fragments.items[2].anchor.direction == Before)
  assert_true(fragments.items[2].anchor.range == Range(2, 1, 2, 4))
  assert_eq(fragments.provider.length(), 1)
  registration.dispose()
}

///|
test "single-character token adjustment preserves exact source boundaries" {
  let metadata = @tokens.LineTokens::default_token_metadata()
  let tokens = @tokens.LineTokens::create_from_text_and_metadata(
    [("!", metadata), ("@", metadata), ("#", metadata)],
    @services.language_id_codec,
  )
  assert_true(adjusted_single_character_token_bounds(tokens, 2, 2) == (1, 2))
  assert_true(adjusted_single_character_token_bounds(tokens, 1, 1) == (1, 2))
  assert_true(adjusted_single_character_token_bounds(tokens, 1, 2) == (2, 3))
  let wide = @tokens.LineTokens::create_from_text_and_metadata(
    [("!!", metadata), ("@", metadata)],
    @services.language_id_codec,
  )
  assert_true(adjusted_single_character_token_bounds(wide, 0, 0) == (0, 2))
}
