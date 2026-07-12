///| Attached-view identity, aggregation, stabilization, and debounce evidence.

///|
priv struct ScheduledCallback {
  callback : () -> Unit
  active : Ref[Bool]
}

///|
fn deterministic_scheduler(
  delayed : Array[ScheduledCallback],
) -> TokenizationScheduler {
  TokenizationScheduler::new(
    idle=callback => {
      callback(TokenizationIdleDeadline::new(() => 0.0))
      @base_common.Disposable::from(() => ())
    },
    zero_timeout=callback => {
      callback()
      @base_common.Disposable::from(() => ())
    },
    delay=(_milliseconds, callback) => {
      let active = Ref(true)
      delayed.push({ callback, active })
      @base_common.Disposable::from(() => active.val = false)
    },
    now=() => 0.0,
  )
}

///|
fn run_scheduled(task : ScheduledCallback) -> Unit {
  if task.active.val {
    (task.callback)()
  }
}

///|
test "AttachedViewState equality checks ranges before stabilization" {
  let ranges = [@base_common.LineRange(1, 3)]
  let a = AttachedViewState::new(ranges, false)
  let same = AttachedViewState::new([@base_common.LineRange(1, 3)], false)
  let different_ranges = AttachedViewState::new(
    [@base_common.LineRange(1, 4)],
    false,
  )
  let different_stability = AttachedViewState::new(
    [@base_common.LineRange(1, 3)],
    true,
  )
  assert_true(a.equals(a))
  assert_true(a.equals(same))
  assert_false(a.equals(different_ranges))
  assert_false(a.equals(different_stability))
}

///|
test "AttachedViews preserves identity, joins ranges, and emits absent detach state" {
  let manager = AttachedViews::new()
  let events : Array[AttachedViewStateChange] = []
  manager.on_did_change_visible_ranges(event => events.push(event)) |> ignore
  let first = manager.attach_view()
  let second = manager.attach_view()
  first.set_visible_lines([{ start_line_number: 3, end_line_number: 5 }], false)
  second.set_visible_lines(
    [
      { start_line_number: 1, end_line_number: 2 },
      { start_line_number: 6, end_line_number: 7 },
    ],
    true,
  )
  let aggregate = manager.visible_line_ranges()
  assert_eq(aggregate.length(), 1)
  assert_eq(aggregate[0].start_line_number, 1)
  assert_eq(aggregate[0].end_line_number_exclusive, 8)
  assert_true(events[0].view.same(first))
  assert_true(events[1].view.same(second))
  manager.detach_view(first)
  assert_true(events[2].view.same(first))
  assert_true(events[2].state is None)
  let remaining = manager.visible_line_ranges()
  assert_eq(remaining.length(), 2)
}

///|
test "AttachedViewHandler debounces unstable state and stable state cancels then refreshes" {
  let delayed : Array[ScheduledCallback] = []
  let scheduler = deterministic_scheduler(delayed)
  let refresh_count = Ref(0)
  let handler = AttachedViewHandler::new(() => refresh_count.val += 1, () => {
    Some(scheduler)
  })
  handler.handle_state_change(
    AttachedViewState::new([@base_common.LineRange(1, 3)], false),
  )
  assert_eq(delayed.length(), 1)
  assert_eq(refresh_count.val, 0)
  handler.handle_state_change(
    AttachedViewState::new([@base_common.LineRange(2, 4)], false),
  )
  assert_eq(delayed.length(), 2)
  run_scheduled(delayed[0])
  assert_eq(refresh_count.val, 0)
  run_scheduled(delayed[1])
  assert_eq(refresh_count.val, 1)
  handler.handle_state_change(
    AttachedViewState::new([@base_common.LineRange(5, 7)], false),
  )
  assert_eq(delayed.length(), 3)
  handler.handle_state_change(
    AttachedViewState::new([@base_common.LineRange(5, 7)], true),
  )
  assert_eq(refresh_count.val, 2)
  run_scheduled(delayed[2])
  assert_eq(refresh_count.val, 2)
  // Equal requested/computed ranges suppress a repeated stable refresh.
  handler.handle_state_change(
    AttachedViewState::new([@base_common.LineRange(5, 7)], true),
  )
  assert_eq(refresh_count.val, 2)
}
