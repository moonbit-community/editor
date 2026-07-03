///|
/// Phase 2 of `monaco-hover-logic-chain-port.md`: the Monaco `HoverOperation`
/// state machine ported into `HoverController`.
fn markdown_part(start : Int, end : Int, text : String) -> HoverPart {
  MarkdownHover(
    range=Range(1, start + 1, 1, end + 1),
    contents=[PlainText(text)],
    ordinal=100,
  )
}

///|
/// Test entry: arm a delayed operation for `[start, end)` as if no hover were
/// shown, the way `on_event` arms one for a fresh anchor (line 1).
fn HoverController::start_delayed(
  self : HoverController,
  start : Int,
  end : Int,
  injected_text_index? : Int = -1,
) -> (HoverEffect, HoverController) {
  self.start_showing_or_update_hover(
    { range: Range(1, start + 1, 1, end + 1), injected_text_index },
    false,
  )
}

///|
test "delayed start arms the operation and suppresses results before the delay" {
  let controller = HoverController::empty()
  let (effect, armed) = controller.start_delayed(3, 7)
  assert_true(effect is HoverScheduleDelayed(1))
  assert_true(armed.operation.state is HoverOpFirstWait)
  // The same anchor keeps the in-flight operation untouched.
  let (again, unchanged) = armed.start_delayed(3, 7)
  assert_true(again is HoverNoEffect)
  assert_eq(unchanged.operation.token, armed.operation.token)
  // A new anchor rotates the token, invalidating in-flight timers.
  let (rescheduled, moved) = armed.start_delayed(10, 14)
  assert_true(rescheduled is HoverScheduleDelayed(2))
  assert_eq(moved.operation.token, 2)

  // The async trigger advances to SecondWait; emission is still suppressed.
  let (proceed, second_wait) = moved.op_trigger_async(2)
  assert_true(proceed)
  assert_true(second_wait.operation.state is HoverOpSecondWait)
  let async_during_wait = second_wait.op_async_item(2, [
    markdown_part(10, 14, "x"),
  ])
  assert_true(async_during_wait.view is None)
  assert_eq(async_during_wait.operation.parts.length(), 1)
  // The async stream finishes while still in SecondWait: emission stays
  // suppressed, but the operation records that async is done.
  let async_finished = async_during_wait.op_async_done(2)
  assert_true(async_finished.view is None)

  // The sync trigger (full delay) emits the accumulated parts: now it is shown.
  let shown = async_finished.op_trigger_sync(2, [])
  assert_true(shown.view is Some(_))
  // Async already finished during SecondWait, so the sync trigger completes
  // straight to Idle (Monaco's `_asyncIterableDone ? Idle : WaitingForAsync`).
  assert_true(shown.is_complete())
}

///|
test "loading message appears only while waiting for a slow async compute" {
  let (_, armed) = HoverController::empty().start_delayed(3, 7)
  let (_, second_wait) = armed.op_trigger_async(1)
  // Sync produced nothing and async is still pending -> WaitingForAsync.
  let waiting = second_wait.op_trigger_sync(1, [])
  assert_true(waiting.operation.state is HoverOpWaitingForAsync)
  assert_true(waiting.view is None)
  // The loading timer turns the wait into the loading message.
  let loading = waiting.op_trigger_loading(1)
  assert_true(loading.operation.state is HoverOpWaitingForAsyncShowingLoading)
  assert_true(loading.widget_view() is Some(_))
  match loading.widget_view() {
    Some(view) => {
      assert_false(view.measurable)
      assert_eq(view.parts.length(), 1)
    }
    None => ()
  }
  // A streamed async result replaces the loading message and completes.
  let resolved = loading.op_async_item(1, [markdown_part(3, 7, "fn main")])
  assert_true(resolved.view is Some(_))
  let done = resolved.op_async_done(1)
  assert_true(done.is_complete())
}

///|
test "immediate path shows the hover synchronously without the schedulers" {
  // Monaco start(Immediate): invoke the async + sync triggers back to back,
  // skipping the waits. The view is shown right away.
  let (_, armed) = HoverController::empty().start_delayed(3, 7)
  let (proceed, second_wait) = armed.op_trigger_async(1)
  assert_true(proceed)
  let shown = second_wait.op_trigger_sync(1, [markdown_part(3, 7, "immediate")])
  assert_true(shown.view is Some(_))
}

///|
test "stale timers and async results are dropped by the token guard" {
  let (_, armed) = HoverController::empty().start_delayed(3, 7)
  // A newer anchor has rotated the token to 2.
  let (_, moved) = armed.start_delayed(10, 14)
  assert_eq(moved.operation.token, 2)
  // A stale async trigger (token 1) does not advance the operation.
  let (proceed, untouched) = moved.op_trigger_async(1)
  assert_false(proceed)
  assert_true(untouched.operation.state is HoverOpFirstWait)
  // A stale streamed result is ignored.
  let still_empty = moved.op_async_item(1, [markdown_part(10, 14, "stale")])
  assert_eq(still_empty.operation.parts.length(), 0)
}

///|
test "clearing rotates the token and drops the shown hover" {
  let (_, armed) = HoverController::empty().start_delayed(3, 7)
  let (_, second_wait) = armed.op_trigger_async(1)
  let shown = second_wait.op_trigger_sync(1, [markdown_part(3, 7, "fn main")])
  assert_true(shown.view is Some(_))
  let cleared = shown.cleared()
  assert_true(cleared.view is None)
  assert_true(cleared.anchor is None)
  // The token rotated so a late async result for token 1 is dropped.
  assert_eq(cleared.operation.token, shown.operation.token + 1)
  let late = cleared.op_async_item(1, [markdown_part(3, 7, "late")])
  assert_true(late.view is None)
}
