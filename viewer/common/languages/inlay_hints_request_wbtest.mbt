///|
fn inlay_request_model(text : String) -> @model.TextModel {
  inlay_request_model_for_language(text, "moonbit")
}

///|
fn inlay_request_model_for_language(
  text : String,
  language_id : String,
) -> @model.TextModel {
  TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/inlay-request-test.mbt",
    ),
    "inlay-request-test.mbt",
    language_id,
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
priv struct ModelRecordingInlayProvider {
  observed_models : Array[@model.TextModel]
  observed_ranges : Array[@base_common.OffsetRange]
  observed_tokens : Array[@language.CancellationToken]
  hints : Array[@language.InlayHint]
}

///|
impl @language.InlayHintsProvider for ModelRecordingInlayProvider with fn provide_inlay_hints(
  self,
  model,
  range,
  token,
) {
  self.observed_models.push(model)
  self.observed_ranges.push(range)
  self.observed_tokens.push(token)
  self.hints
}

///|
priv struct InlayProbeTokenizer {
  calls : Ref[Int]
  tokens : Array[@syntax.LineToken]
}

///|
impl @syntax.LineTokenizer for InlayProbeTokenizer with fn initial_state(_self) {
  TokenizerState("inlay-probe")
}

///|
impl @syntax.LineTokenizer for InlayProbeTokenizer with fn tokenize_line(
  self,
  _line_text,
  state,
) {
  self.calls.val += 1
  (self.tokens.copy(), state)
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
async test "inlay request supports injected A-to-B concurrent completion" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let started = @aqueue.Queue(kind=Unbounded)
  let release_a = @aqueue.Queue(kind=Unbounded)
  let release_b = @aqueue.Queue(kind=Unbounded)
  let provider_a = ControlledInlayProvider::{
    name: "a",
    started,
    gate: release_a,
    signal_after: Some(release_b),
    hints: [inlay_hint(1, 1, "a")],
    fail_after_gate: false,
  }
  let provider_b = ControlledInlayProvider::{
    name: "b",
    started,
    gate: release_b,
    signal_after: None,
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
  @async.with_task_group() <| group => {
    let request = group.spawn(() => {
      languages.inlay_hints_for_ranges(
        model,
        [model.get_full_model_range()],
        @language.CancellationToken::new(),
        @log.LogService::new(),
        run_tasks=run_inlay_test_tasks_concurrently,
      )
    })
    let (first_name, _, _) = started.get()
    let (second_name, _, _) = started.get()
    assert_eq(first_name, "b")
    assert_eq(second_name, "a")
    // Both tasks have started. A releases B only as A returns, fixing the
    // completion order independently from registry/start order.
    release_a.put(())
    let fragments = request.wait()
    assert_eq(fragments.items.length(), 2)
    assert_eq(fragments.items[0].hint.label, "a")
    assert_eq(fragments.items[1].hint.label, "b")
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
async test "inlay request with zero ranges launches no provider tasks" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let observed_ranges : Array[@base_common.OffsetRange] = []
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    StaticInlayProvider::{
      hints: [inlay_hint(1, 1, "unused")],
      observed_ranges,
      observed_tokens: [],
      fail: false,
    },
  )
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [],
    @language.CancellationToken::new(),
    @log.LogService::new(),
    run_tasks=tasks => assert_true(tasks.is_empty()),
  )
  assert_true(observed_ranges.is_empty())
  assert_true(fragments.ranges.is_empty())
  assert_true(fragments.items.is_empty())
  assert_true(fragments.provider.is_empty())
  registration.dispose()
}

///|
async test "inlay request covers zero one two providers by zero one two ranges" {
  let model = inlay_request_model("foo\nbar\n")
  for provider_count in [0, 1, 2] {
    for range_count in [0, 1, 2] {
      let languages = Languages::new()
      let observed_a : Array[@base_common.OffsetRange] = []
      let observed_b : Array[@base_common.OffsetRange] = []
      let registrations : Array[@base_common.Disposable] = []
      if provider_count >= 1 {
        registrations.push(
          languages.register_inlay_hints_provider(LanguageId("moonbit"), StaticInlayProvider::{
            hints: [],
            observed_ranges: observed_a,
            observed_tokens: [],
            fail: false,
          }),
        )
      }
      if provider_count >= 2 {
        registrations.push(
          languages.register_inlay_hints_provider(LanguageId("moonbit"), StaticInlayProvider::{
            hints: [],
            observed_ranges: observed_b,
            observed_tokens: [],
            fail: false,
          }),
        )
      }
      let ranges : Array[@base_common.Range] = match range_count {
        0 => []
        1 => [Range(1, 1, 1, 2)]
        _ => [Range(1, 1, 1, 2), Range(2, 1, 2, 2)]
      }
      let fragments = languages.inlay_hints_for_ranges(
        model,
        ranges,
        @language.CancellationToken::new(),
        @log.LogService::new(),
      )
      assert_eq(
        observed_a.length() + observed_b.length(),
        provider_count * range_count,
      )
      assert_true(fragments.ranges == ranges)
      assert_true(fragments.items.is_empty())
      for registration in registrations {
        registration.dispose()
      }
    }
  }
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
/// PR-EOL-002/004: both Range endpoints are converted in the model's
/// normalized LF coordinate space, and the provider receives that exact
/// OffsetRange for every supported raw EOL form.
async test "inlay request forwards exact normalized ranges for every EOL form" {
  let cases : Array[(String, String)] = [
    ("a\r\nb", "a\nb"),
    ("a\rb", "a\nb"),
    ("a\r\nb\rc\nd", "a\nb\nc\nd"),
    ("tail\r\n", "tail\n"),
    ("🙂\r\nβ\r中\n", "🙂\nβ\n中\n"),
    ("\u{FEFF}head\r\ntail", "\u{FEFF}head\ntail"),
  ]
  for sample in cases {
    let raw = sample.0
    let normalized = sample.1
    let languages = Languages::new()
    let model = inlay_request_model(raw)
    let observed_ranges : Array[@base_common.OffsetRange] = []
    let provider = StaticInlayProvider::{
      hints: [],
      observed_ranges,
      observed_tokens: [],
      fail: false,
    }
    let registration = languages.register_inlay_hints_provider(
      LanguageId("moonbit"),
      provider,
    )
    let full_range = model.get_full_model_range()
    let fragments = languages.inlay_hints_for_ranges(
      model,
      [full_range],
      @language.CancellationToken::new(),
      @log.LogService::new(),
    )
    assert_eq(model.get_value(), normalized)
    assert_eq(model.get_value_length(), normalized.length())
    assert_eq(observed_ranges.length(), 1)
    assert_true(observed_ranges == [OffsetRange(0, normalized.length())])
    assert_eq(observed_ranges[0].start, 0)
    assert_eq(observed_ranges[0].end_exclusive, normalized.length())
    assert_true(fragments.ranges == [full_range])
    registration.dispose()
    model.dispose()
  }
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
async test "inlay snapshot still invokes a captured provider disposed before task launch" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let observed_models : Array[@model.TextModel] = []
  let observed_ranges : Array[@base_common.OffsetRange] = []
  let observed_tokens : Array[@language.CancellationToken] = []
  let provider = ModelRecordingInlayProvider::{
    observed_models,
    observed_ranges,
    observed_tokens,
    hints: [inlay_hint(1, 1, "disposed-before-launch")],
  }
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider,
  )
  let token = @language.CancellationToken::new()
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [model.get_full_model_range()],
    token,
    @log.LogService::new(),
    run_tasks=tasks => {
      // `run_tasks` is called only after provider/range requests and task
      // closures have been snapshotted. Registry compaction must not skip or
      // invalidate that captured task.
      assert_eq(tasks.length(), 1)
      registration.dispose()
      for task in tasks {
        task()
      }
    },
  )
  assert_eq(observed_models.length(), 1)
  assert_true(physical_equal(observed_models[0], model))
  assert_true(observed_ranges == [OffsetRange(0, model.get_value_length())])
  assert_eq(observed_tokens.length(), 1)
  assert_true(physical_equal(observed_tokens[0], token))
  assert_true(fragments.items.is_empty())
  assert_true(fragments.provider.is_empty())
  model.dispose()
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
async test "inlay post-await liveness rejects a settled provider disposed while its sibling waits" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let started = @aqueue.Queue(kind=Unbounded)
  let release_a = @aqueue.Queue(kind=Unbounded)
  let release_b = @aqueue.Queue(kind=Unbounded)
  let provider_b = ControlledInlayProvider::{
    name: "b",
    started,
    gate: release_b,
    signal_after: None,
    hints: [inlay_hint(1, 1, "b")],
    fail_after_gate: false,
  }
  let provider_a = ControlledInlayProvider::{
    name: "a",
    started,
    gate: release_a,
    signal_after: None,
    hints: [inlay_hint(1, 1, "a")],
    fail_after_gate: false,
  }
  // Requests run in reversed registration order, so the task handles below
  // are A then B while B remains independently blocked on its own gate.
  let registration_b = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider_b,
  )
  let registration_a = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    provider_a,
  )
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [model.get_full_model_range()],
    @language.CancellationToken::new(),
    @log.LogService::new(),
    run_tasks=tasks => {
      assert_eq(tasks.length(), 2)
      @async.with_task_group() <| group => {
        let task_a = group.spawn(() => tasks[0]())
        let task_b = group.spawn(() => tasks[1]())
        let (first, _, _) = started.get()
        let (second, _, _) = started.get()
        assert_true(
          (first == "a" && second == "b") || (first == "b" && second == "a"),
        )
        release_a.put(())
        task_a.wait()
        // A's nonempty result has already passed the per-task liveness check.
        // Dispose it while B is demonstrably still pending, then let B settle.
        registration_a.dispose()
        release_b.put(())
        task_b.wait()
      }
    },
  )
  assert_eq(fragments.items.length(), 1)
  assert_eq(fragments.items[0].hint.label, "b")
  assert_eq(fragments.provider.length(), 1)
  assert_true(
    physical_equal(fragments.provider[0], fragments.items[0].provider),
  )
  registration_b.dispose()
  model.dispose()
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
async test "inlay cancellation after provider settlement triggers the final guard" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let observed_ranges : Array[@base_common.OffsetRange] = []
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    StaticInlayProvider::{
      hints: [inlay_hint(1, 1, "settled")],
      observed_ranges,
      observed_tokens: [],
      fail: false,
    },
  )
  let token = @language.CancellationToken::new()
  try
    languages.inlay_hints_for_ranges(
      model,
      [model.get_full_model_range()],
      token,
      @log.LogService::new(),
      run_tasks=tasks => {
        for task in tasks {
          task()
        }
        // Every provider task has returned and retained its data. Cancellation
        // here can only be observed by the post-settlement request guard.
        token.cancel()
      },
    )
  catch {
    InlayHintsRequestCancelled => ()
    _ => fail("expected post-settlement inlay cancellation")
  } noraise {
    _ => fail("expected post-settlement inlay cancellation")
  }
  assert_eq(observed_ranges.length(), 1)
  registration.dispose()
  model.dispose()
}

///|
async test "inlay model disposal after provider settlement triggers the final guard" {
  let languages = Languages::new()
  let model = inlay_request_model("foo\n")
  let observed_ranges : Array[@base_common.OffsetRange] = []
  let registration = languages.register_inlay_hints_provider(
    LanguageId("moonbit"),
    StaticInlayProvider::{
      hints: [inlay_hint(1, 1, "settled")],
      observed_ranges,
      observed_tokens: [],
      fail: false,
    },
  )
  try
    languages.inlay_hints_for_ranges(
      model,
      [model.get_full_model_range()],
      @language.CancellationToken::new(),
      @log.LogService::new(),
      run_tasks=tasks => {
        for task in tasks {
          task()
        }
        // As above, disposal happens after every provider result has settled.
        model.dispose()
      },
    )
  catch {
    InlayHintsRequestCancelled => ()
    _ => fail("expected post-settlement disposed-model cancellation")
  } noraise {
    _ => fail("expected post-settlement disposed-model cancellation")
  }
  assert_eq(observed_ranges.length(), 1)
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
async test "inlay fragments validate an invalid provider position before deriving its anchor" {
  let languages = Languages::new()
  let model = inlay_request_model_for_language("!!!", "inlay-invalid-position")
  let registration = languages.register_inlay_hints_provider(
    LanguageId("inlay-invalid-position"),
    StaticInlayProvider::{
      hints: [inlay_hint(99, 99, "clamped")],
      observed_ranges: [],
      observed_tokens: [],
      fail: false,
    },
  )
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [model.get_full_model_range()],
    @language.CancellationToken::new(),
    @log.LogService::new(),
  )
  assert_eq(fragments.items.length(), 1)
  assert_true(fragments.items[0].hint.position == Position(99, 99))
  assert_true(fragments.items[0].anchor.direction == Before)
  assert_true(fragments.items[0].anchor.range == Range(1, 1, 1, 4))
  registration.dispose()
  model.dispose()
}

///|
async test "inlay word anchor returns before touching model tokenization" {
  let language_id = "inlay-word-without-tokenization"
  let calls = Ref(0)
  let tokenizer_registration = @syntax.tokenization_registry.register(
    language_id,
    InlayProbeTokenizer::{ calls, tokens: [{ start: 0, end: 3, tag: Keyword }] },
  )
  let languages = Languages::new()
  let model = inlay_request_model_for_language("foo", language_id)
  let provider_registration = languages.register_inlay_hints_provider(
    LanguageId(language_id),
    StaticInlayProvider::{
      hints: [inlay_hint(1, 2, "word")],
      observed_ranges: [],
      observed_tokens: [],
      fail: false,
    },
  )
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [model.get_full_model_range()],
    @language.CancellationToken::new(),
    @log.LogService::new(),
  )
  assert_eq(calls.val, 0)
  assert_true(fragments.items[0].anchor.direction == After)
  assert_true(fragments.items[0].anchor.range == Range(1, 1, 1, 2))
  provider_registration.dispose()
  model.dispose()
  tokenizer_registration.dispose()
}

///|
async test "inlay token anchor converts one-based column with exact minus and plus one" {
  let language_id = "inlay-token-offset-boundary"
  let calls = Ref(0)
  let tokenizer_registration = @syntax.tokenization_registry.register(
    language_id,
    InlayProbeTokenizer::{
      calls,
      tokens: [
        { start: 0, end: 2, tag: Punctuation },
        { start: 2, end: 4, tag: Operator },
        { start: 4, end: 6, tag: Delimiter },
      ],
    },
  )
  let languages = Languages::new()
  let model = inlay_request_model_for_language("!!@@##", language_id)
  let provider_registration = languages.register_inlay_hints_provider(
    LanguageId(language_id),
    StaticInlayProvider::{
      // Column 2 maps to zero-based offset 1, inside token [0, 2). Using
      // column directly would instead select the next token at boundary 2.
      hints: [inlay_hint(1, 2, "offset")],
      observed_ranges: [],
      observed_tokens: [],
      fail: false,
    },
  )
  let fragments = languages.inlay_hints_for_ranges(
    model,
    [model.get_full_model_range()],
    @language.CancellationToken::new(),
    @log.LogService::new(),
  )
  assert_eq(calls.val, 1)
  assert_true(fragments.items[0].anchor.direction == Before)
  assert_true(fragments.items[0].anchor.range == Range(1, 1, 1, 3))
  provider_registration.dispose()
  model.dispose()
  tokenizer_registration.dispose()
}

///|
test "single-character token adjustment preserves the five-token boundary matrix" {
  let metadata = @tokens.LineTokens::default_token_metadata()
  let tokens = @tokens.LineTokens::create_from_text_and_metadata(
    [
      ("!", metadata),
      ("@", metadata),
      ("#", metadata),
      ("$", metadata),
      ("%", metadata),
    ],
    @services.language_id_codec,
  )
  assert_eq(tokens.get_count(), 5)
  // Index 0: no leading neighbor exists; its end may select index 1.
  assert_true(adjusted_single_character_token_bounds(tokens, 0, 0) == (0, 1))
  assert_true(adjusted_single_character_token_bounds(tokens, 0, 1) == (1, 2))
  // Index 1: strict `> 1` blocks the leading branch; trailing remains valid.
  assert_true(adjusted_single_character_token_bounds(tokens, 1, 1) == (1, 2))
  assert_true(adjusted_single_character_token_bounds(tokens, 1, 2) == (2, 3))
  // Interior index 2 exercises both eligible neighbors.
  assert_true(adjusted_single_character_token_bounds(tokens, 2, 2) == (1, 2))
  assert_true(adjusted_single_character_token_bounds(tokens, 2, 3) == (3, 4))
  // Index count-2 can select either interior or last neighbor.
  assert_true(adjusted_single_character_token_bounds(tokens, 3, 3) == (2, 3))
  assert_true(adjusted_single_character_token_bounds(tokens, 3, 4) == (4, 5))
  // Last index still permits leading selection, but its end cannot trail past
  // `count - 1`.
  assert_true(adjusted_single_character_token_bounds(tokens, 4, 4) == (3, 4))
  assert_true(adjusted_single_character_token_bounds(tokens, 4, 5) == (4, 5))
  let wide = @tokens.LineTokens::create_from_text_and_metadata(
    [
      ("!", metadata),
      ("@", metadata),
      ("##", metadata),
      ("$", metadata),
      ("%", metadata),
    ],
    @services.language_id_codec,
  )
  // The length-2 token is at eligible index 2. Both its start and end would
  // choose a neighbor if the exact single-character guard were weakened.
  assert_true(adjusted_single_character_token_bounds(wide, 2, 2) == (2, 4))
  assert_true(adjusted_single_character_token_bounds(wide, 2, 4) == (2, 4))
}
