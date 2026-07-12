///| TextModel-owned tokenization access, size policy, and scheduler epochs.

///|
priv struct ModelTokenizationCountingTokenizer {
  calls : Ref[Int]
}

///|
impl @syntax.LineTokenizer for ModelTokenizationCountingTokenizer with fn initial_state(
  _self,
) {
  TokenizerState("model-tokenization")
}

///|
impl @syntax.LineTokenizer for ModelTokenizationCountingTokenizer with fn tokenize_line(
  self,
  _line_text,
  state,
) {
  self.calls.val += 1
  ([], state)
}

///|
fn tokenization_model(text : String, language_id : String) -> TextModel {
  TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="tokenization-model",
      path="/model.mbt",
    ),
    "model.mbt",
    language_id,
    1,
    "",
    text,
  )
}

///|
priv struct ModelIdleTask {
  callback : (@tokens.TokenizationIdleDeadline) -> Unit
  active : Ref[Bool]
}

///|
priv struct ModelScheduledTask {
  active : Ref[Bool]
}

///|
priv struct ModelTokenizationSchedulerHarness {
  scheduler : @tokens.TokenizationScheduler
  idle : Array[ModelIdleTask]
  zero : Array[ModelScheduledTask]
  delayed : Array[ModelScheduledTask]
  delay_milliseconds : Array[Int]
}

///|
fn model_tokenization_scheduler_harness() -> ModelTokenizationSchedulerHarness {
  let idle : Array[ModelIdleTask] = []
  let zero : Array[ModelScheduledTask] = []
  let delayed : Array[ModelScheduledTask] = []
  let delay_milliseconds : Array[Int] = []
  let scheduler = @tokens.TokenizationScheduler::new(
    idle=callback => {
      let active = Ref(true)
      idle.push({ callback, active })
      @base_common.Disposable::from(() => active.val = false)
    },
    zero_timeout=_callback => {
      let active = Ref(true)
      zero.push({ active, })
      @base_common.Disposable::from(() => active.val = false)
    },
    delay=(milliseconds, _callback) => {
      let active = Ref(true)
      delay_milliseconds.push(milliseconds)
      delayed.push({ active, })
      @base_common.Disposable::from(() => active.val = false)
    },
    now=() => 0.0,
  )
  { scheduler, idle, zero, delayed, delay_milliseconds }
}

///|
test "large-file tokenization thresholds are strict and constructor-fixed" {
  assert_eq(LARGE_FILE_SIZE_THRESHOLD, 20 * 1024 * 1024)
  assert_eq(LARGE_FILE_LINE_COUNT_THRESHOLD, 300 * 1000)

  let at_size = tokenization_model(
    "x".repeat(LARGE_FILE_SIZE_THRESHOLD),
    "token-size-boundary",
  )
  assert_eq(at_size.get_value_length(), LARGE_FILE_SIZE_THRESHOLD)
  assert_false(at_size.is_too_large_for_tokenization())
  at_size.set_value("small")
  assert_false(at_size.is_too_large_for_tokenization())
  at_size.dispose()

  let over_size = tokenization_model(
    "x".repeat(LARGE_FILE_SIZE_THRESHOLD + 1),
    "token-size-over",
  )
  assert_true(over_size.is_too_large_for_tokenization())
  over_size.set_value("small")
  assert_true(over_size.is_too_large_for_tokenization())
  over_size.dispose()

  let at_lines = tokenization_model(
    "\n".repeat(LARGE_FILE_LINE_COUNT_THRESHOLD - 1),
    "token-lines-boundary",
  )
  assert_eq(at_lines.get_line_count(), LARGE_FILE_LINE_COUNT_THRESHOLD)
  assert_false(at_lines.is_too_large_for_tokenization())
  at_lines.dispose()

  let over_lines = tokenization_model(
    "\n".repeat(LARGE_FILE_LINE_COUNT_THRESHOLD),
    "token-lines-over",
  )
  assert_eq(over_lines.get_line_count(), LARGE_FILE_LINE_COUNT_THRESHOLD + 1)
  assert_true(over_lines.is_too_large_for_tokenization())
  over_lines.dispose()
}

///|
test "set_value updates the live token carrier and token_count stays passive" {
  let calls = Ref(0)
  let language_id = "text-model-live-token-carrier"
  let registration = @syntax.tokenization_registry.register(language_id, ModelTokenizationCountingTokenizer::{
    calls,
  })
  let model = tokenization_model("old\nvalue", language_id)
  assert_eq(model.tokenization_snapshot.val.get_value(), "old\nvalue")
  assert_false(model.tokenization.has_tokens())
  assert_eq(model.tokenization.token_count(), 2)
  assert_eq(calls.val, 0)

  model.set_value("new\nvalue\nnow")
  assert_eq(model.tokenization_snapshot.val.get_value(), "new\nvalue\nnow")
  assert_eq(model.tokenization_snapshot.val.line_count(), 3)
  assert_eq(model.tokenization.get_line_tokens(3).get_line_content(), "now")
  assert_false(model.tokenization.has_tokens())
  assert_eq(model.tokenization.token_count(), 3)
  assert_eq(calls.val, 0)

  model.tokenization.force_tokenization(2)
  assert_eq(calls.val, 2)
  let before_count = calls.val
  assert_eq(model.tokenization.token_count(), 3)
  assert_eq(calls.val, before_count)
  model.dispose()
  registration.dispose()
}

///|
test "attached epoch selects first scheduler, retains it, then cancels and clears" {
  let calls = Ref(0)
  let language_id = "text-model-scheduler-epoch"
  let registration = @syntax.tokenization_registry.register(language_id, ModelTokenizationCountingTokenizer::{
    calls,
  })
  let first_scheduler = model_tokenization_scheduler_harness()
  let later_scheduler = model_tokenization_scheduler_harness()
  let model = tokenization_model("one\ntwo\nthree\nfour\nfive", language_id)

  // None starts the epoch without selecting or enqueueing a host scheduler.
  let headless = model.on_before_attached()
  assert_eq(model.get_attached_editor_count(), 1)
  assert_true(model.is_attached_to_editor())
  assert_true(model.tokenization_scheduler.val is None)
  assert_true(first_scheduler.idle.is_empty())

  // The first late Some wakes the existing worker exactly once. Incrementing
  // 1 -> 2 must not synthesize another first-attach wake.
  let supplying = model.on_before_attached(scheduler=first_scheduler.scheduler)
  assert_eq(model.get_attached_editor_count(), 2)
  assert_true(model.tokenization_scheduler.val is Some(_))
  assert_eq(first_scheduler.idle.length(), 1)
  assert_true(first_scheduler.zero.is_empty())

  // Later Some and None candidates cannot replace the selected scheduler.
  let later = model.on_before_attached(scheduler=later_scheduler.scheduler)
  let another_headless = model.on_before_attached()
  assert_eq(model.get_attached_editor_count(), 4)
  assert_eq(first_scheduler.idle.length(), 1)
  assert_true(later_scheduler.idle.is_empty())
  later.set_visible_lines([{ start_line_number: 3, end_line_number: 3 }], false)
  another_headless.set_visible_lines(
    [{ start_line_number: 5, end_line_number: 5 }],
    false,
  )
  assert_eq(first_scheduler.delayed.length(), 2)
  assert_eq(first_scheduler.delay_milliseconds.length(), 2)
  assert_eq(first_scheduler.delay_milliseconds[0], 50)
  assert_eq(first_scheduler.delay_milliseconds[1], 50)
  assert_true(later_scheduler.delayed.is_empty())

  // Removing the Viewer that supplied the scheduler is nonfinal, so the
  // worker and selected scheduler remain live for headless/sibling views.
  model.on_before_detached(supplying)
  assert_eq(model.get_attached_editor_count(), 3)
  assert_true(first_scheduler.idle[0].active.val)
  assert_true(model.tokenization_scheduler.val is Some(_))
  headless.set_visible_lines(
    [{ start_line_number: 1, end_line_number: 1 }],
    false,
  )
  assert_eq(first_scheduler.delayed.length(), 3)
  assert_true(later_scheduler.delayed.is_empty())

  // The exact supplied handle disappeared; the remaining aggregate contains
  // only the three handles which have visible state.
  let aggregate = model.attached_views.visible_line_ranges()
  assert_eq(aggregate.length(), 3)
  assert_eq(aggregate[0].start_line_number, 1)
  assert_eq(aggregate[1].start_line_number, 3)
  assert_eq(aggregate[2].start_line_number, 5)

  model.on_before_detached(later)
  model.on_before_detached(another_headless)
  assert_eq(model.get_attached_editor_count(), 1)
  assert_true(first_scheduler.idle[0].active.val)
  model.on_before_detached(headless)
  assert_eq(model.get_attached_editor_count(), 0)
  assert_false(model.is_attached_to_editor())
  assert_true(model.tokenization_scheduler.val is None)
  assert_false(first_scheduler.idle[0].active.val)
  for task in first_scheduler.delayed {
    assert_false(task.active.val)
  }

  // A hostile host invoking an old epoch callback cannot tokenize or disturb
  // the fresh epoch's coalescing state.
  (first_scheduler.idle[0].callback)(
    @tokens.TokenizationIdleDeadline::new(() => 0.0),
  )
  assert_eq(calls.val, 0)
  let fresh = model.on_before_attached(scheduler=later_scheduler.scheduler)
  assert_eq(later_scheduler.idle.length(), 1)
  assert_true(later_scheduler.idle[0].active.val)
  (first_scheduler.idle[0].callback)(
    @tokens.TokenizationIdleDeadline::new(() => 0.0),
  )
  assert_eq(calls.val, 0)
  assert_true(later_scheduler.idle[0].active.val)
  model.on_before_detached(fresh)
  assert_false(later_scheduler.idle[0].active.val)
  assert_true(model.tokenization_scheduler.val is None)

  // A subsequent fresh epoch can select again; model disposal owns worker
  // cancellation and clears the selected scheduler even with a live handle.
  let disposal_handle = model.on_before_attached(
    scheduler=later_scheduler.scheduler,
  )
  ignore(disposal_handle)
  assert_eq(later_scheduler.idle.length(), 2)
  assert_true(later_scheduler.idle[1].active.val)
  model.dispose()
  assert_false(later_scheduler.idle[1].active.val)
  assert_true(model.tokenization_scheduler.val is None)
  registration.dispose()
}
