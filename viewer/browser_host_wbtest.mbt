// Deterministic source-shaped coverage for the Viewer root's
// `runAtThisOrScheduleAtNextAnimationFrame` scheduler. The production helper
// is exercised directly; only the native rAF capability is replaced.

///|
#external
priv type AnimationFrameHarness

///|
test "root render scheduler shares drains cancels and advances native frames" {
  let harness = new_animation_frame_harness()
  defer animation_frame_harness_restore(harness)
  let events : Array[String] = []
  let first = run_at_this_or_schedule_at_next_animation_frame(() => {
    events.push("first")
    run_at_this_or_schedule_at_next_animation_frame(() => {
      events.push("reentrant")
    })
    |> ignore
    let canceled_current = run_at_this_or_schedule_at_next_animation_frame(() => {
      events.push("canceled-current")
    })
    canceled_current.dispose()
  })
  let canceled_next = run_at_this_or_schedule_at_next_animation_frame(() => {
    events.push("canceled-next")
  })
  canceled_next.dispose()

  // Both outside-frame items share one pending native rAF.
  assert_eq(animation_frame_harness_request_count(harness), 1)
  assert_eq(animation_frame_harness_pending_count(harness), 1)
  assert_true(events.is_empty())

  animation_frame_harness_run_next(harness)
  // The live reentrant item drains in the same native frame. Canceled items
  // in both the next and current queues never invoke their callbacks.
  assert_eq(animation_frame_harness_request_count(harness), 1)
  assert_eq(animation_frame_harness_pending_count(harness), 0)
  assert_eq(events.length(), 2)
  assert_eq(events[0], "first")
  assert_eq(events[1], "reentrant")

  let next = run_at_this_or_schedule_at_next_animation_frame(() => {
    events.push("next-frame")
  })
  // Once the prior drain has finished, new work owns the next native frame.
  assert_eq(animation_frame_harness_request_count(harness), 2)
  assert_eq(animation_frame_harness_pending_count(harness), 1)
  animation_frame_harness_run_next(harness)
  assert_eq(events.length(), 3)
  assert_eq(events[2], "next-frame")

  first.dispose()
  next.dispose()
}

///|
extern "js" fn new_animation_frame_harness() -> AnimationFrameHarness =
  #| () => {
  #|   const hadOwnRequestAnimationFrame = Object.prototype.hasOwnProperty.call(
  #|     globalThis,
  #|     'requestAnimationFrame',
  #|   );
  #|   const originalRequestAnimationFrame = globalThis.requestAnimationFrame;
  #|   const callbacks = [];
  #|   let requestCount = 0;
  #|   globalThis.requestAnimationFrame = (callback) => {
  #|     requestCount += 1;
  #|     callbacks.push(callback);
  #|     return requestCount;
  #|   };
  #|   return {
  #|     callbacks,
  #|     requestCount: () => requestCount,
  #|     restore: () => {
  #|       if (hadOwnRequestAnimationFrame) {
  #|         globalThis.requestAnimationFrame = originalRequestAnimationFrame;
  #|       } else {
  #|         delete globalThis.requestAnimationFrame;
  #|       }
  #|     },
  #|   };
  #| }

///|
extern "js" fn animation_frame_harness_request_count(
  harness : AnimationFrameHarness,
) -> Int = "(harness) => harness.requestCount()"

///|
extern "js" fn animation_frame_harness_pending_count(
  harness : AnimationFrameHarness,
) -> Int = "(harness) => harness.callbacks.length"

///|
extern "js" fn animation_frame_harness_run_next(
  harness : AnimationFrameHarness,
) -> Unit =
  #| (harness) => {
  #|   const callback = harness.callbacks.shift();
  #|   if (!callback) throw new Error('no pending animation frame');
  #|   callback(0);
  #| }

///|
extern "js" fn animation_frame_harness_restore(
  harness : AnimationFrameHarness,
) -> Unit = "(harness) => harness.restore()"
