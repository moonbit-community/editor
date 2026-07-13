///| Concrete backend passive-read, reset, visible refresh, lifecycle, and cancellation evidence.

///|
priv struct BackendHarness {
  access : TokenizationModelAccess
  attached : Ref[Int]
  scheduler : Ref[TokenizationScheduler?]
  too_large : Ref[Bool]
  disposing : Ref[Bool]
  errors : Array[String]
}

///|
fn backend_harness(lines : Array[String]) -> BackendHarness {
  let attached = Ref(0)
  let scheduler : Ref[TokenizationScheduler?] = Ref(None)
  let too_large = Ref(false)
  let disposing = Ref(false)
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
    language_id=() => "backend-test",
    attached_count=() => attached.val,
    too_large=() => too_large.val,
    disposing=() => disposing.val,
    scheduler=() => scheduler.val,
    unexpected_error=message => errors.push(message),
  )
  { access, attached, scheduler, too_large, disposing, errors }
}

///|
priv struct IdleTask {
  callback : (TokenizationIdleDeadline) -> Unit
  active : Ref[Bool]
}

///|
priv struct BackendSchedulerHarness {
  scheduler : TokenizationScheduler
  idle : Array[IdleTask]
}

///|
fn backend_scheduler_harness() -> BackendSchedulerHarness {
  let idle : Array[IdleTask] = []
  let now = Ref(0.0)
  let scheduler = TokenizationScheduler::new(
    idle=callback => {
      let active = Ref(true)
      idle.push({ callback, active })
      @base_common.Disposable::from(() => active.val = false)
    },
    zero_timeout=_callback => @base_common.Disposable::from(() => ()),
    delay=(_ms, _callback) => @base_common.Disposable::from(() => ()),
    now=() => now.val,
  )
  { scheduler, idle }
}

///|
fn run_idle(task : IdleTask, remaining? : Double = 0.0) -> Unit {
  if task.active.val {
    (task.callback)(TokenizationIdleDeadline::new(() => remaining))
  }
}

///|
test "passive reads never invoke support; explicit force stores exact ranges" {
  let harness = backend_harness(["one", "two"])
  let attached_views = AttachedViews::new()
  let calls : Array[String] = []
  let initial_calls = Ref(0)
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    attached_views,
    _ => Some(logging_support(calls, initial_calls)),
  )
  let events : Array[ModelTokensChangedEvent] = []
  backend.on_did_change_tokens(event => events.push(event)) |> ignore
  assert_eq(initial_calls.val, 2)
  assert_eq(backend.get_line_tokens(1).get_count(), 1)
  assert_eq(backend.get_line_tokens(2).get_count(), 1)
  assert_eq(calls.length(), 0)
  backend.force_tokenization(1)
  assert_eq(calls.length(), 1)
  assert_true(backend.has_tokens())
  assert_eq(events.length(), 1)
  assert_eq(events[0].ranges[0].from_line_number, 1)
  assert_eq(events[0].ranges[0].to_line_number, 1)
}

///|
test "too-large and missing support stay passive defaults and schedule nothing" {
  let harness = backend_harness(["one"])
  harness.too_large.val = true
  let resolves = Ref(0)
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    AttachedViews::new(),
    _ => {
      resolves.val += 1
      Some(logging_support([], Ref(0)))
    },
  )
  assert_eq(resolves.val, 0)
  assert_true(backend.has_accurate_tokens_for_line(1))
  assert_true(backend.is_cheap_to_tokenize(1))
  backend.force_tokenization(1)
  assert_false(backend.has_tokens())
  assert_eq(backend.get_line_tokens(1).get_count(), 1)
}

///|
test "stable attached ranges refresh synchronously without a scheduler" {
  let harness = backend_harness(["one", "two", "three"])
  let attached_views = AttachedViews::new()
  let calls : Array[String] = []
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    attached_views,
    _ => Some(logging_support(calls, Ref(0))),
  )
  let handle = attached_views.attach_view()
  handle.set_visible_lines([{ start_line_number: 1, end_line_number: 2 }], true)
  assert_eq(calls.length(), 2)
  assert_true(backend.has_accurate_tokens_for_line(2))
  assert_eq(backend.get_line_tokens(1).get_line_content(), "one")
}

///|
test "background completion remains completed across reset and repeated finish is silent" {
  let harness = backend_harness(["one"])
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    AttachedViews::new(),
    _ => Some(logging_support([], Ref(0))),
  )
  let state_events = Ref(0)
  backend.on_did_change_background_tokenization_state(_ => state_events.val += 1)
  |> ignore
  backend.force_tokenization(1)
  assert_true(backend.background_tokenization_state() == Completed)
  assert_eq(state_events.val, 1)
  backend.reset_tokenization()
  assert_true(backend.background_tokenization_state() == Completed)
  backend.force_tokenization(1)
  assert_eq(state_events.val, 1)
}

///|
test "scheduler None enqueues nothing; late scheduler wakes once and stale generation is inert" {
  let harness = backend_harness(["one", "two"])
  let calls : Array[String] = []
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    AttachedViews::new(),
    _ => Some(logging_support(calls, Ref(0))),
  )
  harness.attached.val = 1
  backend.handle_did_change_attached()
  assert_eq(calls.length(), 0)
  let scheduler = backend_scheduler_harness()
  harness.scheduler.val = Some(scheduler.scheduler)
  backend.handle_did_change_attached()
  assert_eq(scheduler.idle.length(), 1)
  let old_idle = scheduler.idle[0]
  harness.attached.val = 0
  backend.handle_did_change_attached()
  assert_false(old_idle.active.val)
  harness.attached.val = 1
  backend.handle_did_change_attached()
  assert_eq(scheduler.idle.length(), 2)
  // Simulate a hostile host invoking an already-cancelled old callback.
  (old_idle.callback)(TokenizationIdleDeadline::new(() => 0.0))
  assert_eq(calls.length(), 0)
  run_idle(scheduler.idle[1])
  assert_eq(calls.length(), 2)
  assert_true(backend.background_tokenization_state() == Completed)
}

///|
test "disposing guard drops token and font events" {
  let harness = backend_harness(["one"])
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    AttachedViews::new(),
    _ => Some(logging_support([], Ref(0))),
  )
  let token_events = Ref(0)
  let font_events = Ref(0)
  backend.on_did_change_tokens(_ => token_events.val += 1) |> ignore
  backend.on_did_change_font_tokens(_ => font_events.val += 1) |> ignore
  harness.disposing.val = true
  backend.reset_tokenization()
  backend.set_font_info(AnnotationsUpdate::create([]))
  backend.force_tokenization(1)
  assert_eq(token_events.val, 0)
  assert_eq(font_events.val, 0)
}

///|
test "set_font_info forwards the exact live payload and one absent removal" {
  let harness = backend_harness(["one"])
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    AttachedViews::new(),
    _ => Some(logging_support([], Ref(0))),
  )
  let events : Array[ModelFontTokensChangedEvent] = []
  backend.on_did_change_font_tokens(event => events.push(event)) |> ignore
  let changes : FontTokensUpdate = AnnotationsUpdate::create([
    {
      range: OffsetRange(1, 4),
      annotation: Some({
        font_family: Some("Mono"),
        font_size_multiplier: Some(1.25),
        line_height_multiplier: Some(1.5),
      }),
    },
    { range: OffsetRange(7, 9), annotation: None },
  ])
  backend.set_font_info(changes)
  assert_eq(events.length(), 1)
  assert_true(physical_equal(events[0].changes, changes))
  let annotations = events[0].changes.annotations()
  assert_eq(annotations.length(), 2)
  assert_true(annotations[0].annotation is Some(_))
  assert_true(annotations[1].annotation is None)
  harness.disposing.val = true
  backend.set_font_info(AnnotationsUpdate::create([]))
  assert_eq(events.length(), 1)
  backend.dispose()
  harness.disposing.val = false
  backend.set_font_info(changes)
  assert_eq(events.length(), 1)
}

///|
priv suberror BackendInitialStateError {
  InitialStateFailure
}

///|
test "failing initial state reports and disables support for the reset" {
  let harness = backend_harness(["one"])
  let failing = InternalTokenizationSupportAdapter::new(
    initial_state=() => raise BackendInitialStateError::InitialStateFailure,
    tokenize_encoded=(_text, _has_eol, state) => {
      tokens: [0, tag_to_metadata(Plain)],
      font_info: None,
      end_state: state,
    },
  )
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    AttachedViews::new(),
    _ => Some(failing),
  )
  assert_eq(harness.errors.length(), 1)
  assert_true(backend.has_accurate_tokens_for_line(1))
  assert_eq(backend.get_line_tokens(1).get_count(), 1)
}

///|
test "refreshRange preserves asymmetric clamp and reversed no-work branches" {
  let harness = backend_harness(["one", "two", "three"])
  let calls : Array[String] = []
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    harness.access,
    AttachedViews::new(),
    _ => Some(logging_support(calls, Ref(0))),
  )
  backend.refresh_range(-10, 99)
  assert_eq(calls.length(), 3)
  calls.clear()
  backend.reset_tokenization(fire_token_change_event=false)
  backend.refresh_range(3, 1)
  assert_true(calls.is_empty())
  backend.refresh_range(99, 99)
  assert_eq(calls.length(), 1)
  assert_true(calls[0].has_prefix("three:true:"))
}
