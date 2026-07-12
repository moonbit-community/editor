///|
/// Monotonic high-resolution timestamp in milliseconds, for render timing
/// instrumentation.
extern "js" fn now_ms() -> Double =
  #| () => globalThis.performance?.now() ?? Date.now()

///|
/// Wall-clock milliseconds used by Monaco's smooth-scrolling operation.
extern "js" fn date_now_ms() -> Double =
  #| () => Date.now()

///|
extern "js" fn request_animation_frame(callback : () -> Unit) -> Double =
  #| (callback) => globalThis.requestAnimationFrame(callback)

///|
extern "js" fn cancel_animation_frame(handle : Double) -> Unit =
  #| (handle) => globalThis.cancelAnimationFrame(handle)

///|
fn schedule_at_next_animation_frame(
  callback : () -> Unit,
) -> @base_common.Disposable {
  let handle = request_animation_frame(callback)
  @base_common.Disposable::from(() => cancel_animation_frame(handle))
}

///|
/// Browser idle adapter selected from the current global realm. When either
/// native idle function is absent it preserves Monaco's timeout-backed
/// `Date.now() + 15` deadline and makes disposal inert rather than relying on
/// timer cancellation (`base/common/async.ts:1536-1579`).
extern "js" fn schedule_tokenization_idle_js(
  callback : (() -> Double) -> Unit,
) -> () -> Unit =
  #| (callback) => {
  #|   const g = globalThis;
  #|   let disposed = false;
  #|   if (typeof g.requestIdleCallback !== "function" ||
  #|       typeof g.cancelIdleCallback !== "function") {
  #|     g.setTimeout(() => {
  #|       if (disposed) return;
  #|       const end = Date.now() + 15;
  #|       callback(() => Math.max(0, end - Date.now()));
  #|     }, 0);
  #|     return () => {
  #|       if (disposed) return;
  #|       disposed = true;
  #|     };
  #|   }
  #|   const handle = g.requestIdleCallback((deadline) => {
  #|     if (!disposed) callback(() => deadline.timeRemaining());
  #|   });
  #|   return () => {
  #|     if (disposed) return;
  #|     disposed = true;
  #|     g.cancelIdleCallback(handle);
  #|   };
  #| }

///|
fn schedule_tokenization_idle(
  callback : (@model_tokens.TokenizationIdleDeadline) -> Unit,
) -> @base_common.Disposable {
  let cancel = schedule_tokenization_idle_js(read_time_remaining => {
    callback(@model_tokens.TokenizationIdleDeadline::new(read_time_remaining))
  })
  @base_common.Disposable::from(cancel)
}

///|
let browser_tokenization_scheduler : @model_tokens.TokenizationScheduler = @model_tokens.TokenizationScheduler::new(
  idle=schedule_tokenization_idle,
  zero_timeout=callback => schedule_timeout(callback, 0),
  delay=(milliseconds, callback) => schedule_timeout(callback, milliseconds),
  now=now_ms,
)

///|
/// Monaco `dom.runAtThisOrScheduleAtNextAnimationFrame` for the single-window
/// Viewer root. A render requested while the native frame queue is already
/// draining joins the current queue; otherwise one native rAF owns the next
/// queue. Smooth scrolling deliberately continues to use the stricter
/// `schedule_at_next_animation_frame` helper above.
extern "js" fn run_at_this_or_schedule_at_next_animation_frame_cancel(
  callback : () -> Unit,
) -> () -> Unit =
  #| (() => {
  #|   let nextQueue = [];
  #|   let currentQueue = [];
  #|   let frameRequested = false;
  #|   let inFrameRunner = false;
  #|   const drain = () => {
  #|     frameRequested = false;
  #|     currentQueue = nextQueue;
  #|     nextQueue = [];
  #|     inFrameRunner = true;
  #|     while (currentQueue.length > 0) {
  #|       const item = currentQueue.shift();
  #|       if (item.canceled) continue;
  #|       item.callback();
  #|     }
  #|     inFrameRunner = false;
  #|   };
  #|   return (callback) => {
  #|     const item = { callback, canceled: false };
  #|     if (inFrameRunner) {
  #|       currentQueue.push(item);
  #|     } else {
  #|       nextQueue.push(item);
  #|       if (!frameRequested) {
  #|         frameRequested = true;
  #|         globalThis.requestAnimationFrame(drain);
  #|       }
  #|     }
  #|     return () => { item.canceled = true; };
  #|   };
  #| })()

///|
fn run_at_this_or_schedule_at_next_animation_frame(
  callback : () -> Unit,
) -> @base_common.Disposable {
  let cancel = run_at_this_or_schedule_at_next_animation_frame_cancel(callback)
  @base_common.Disposable::from(cancel)
}

///|
/// One-shot timer. The viewer's hover and scrollbar delays run through this
/// instead of framework commands.
extern "js" fn set_timeout(callback : () -> Unit, ms : Int) -> Double =
  #| (callback, ms) => globalThis.setTimeout(callback, ms)

///|
extern "js" fn clear_timeout(handle : Double) -> Unit =
  #| (handle) => globalThis.clearTimeout(handle)

///|
/// Owns one timeout as an idempotent disposable. Disposal prevents delivery
/// and clears the browser handle; the callback also retires the handle before
/// invoking user code so a reentrant cancel is a no-op.
fn schedule_timeout(callback : () -> Unit, ms : Int) -> @base_common.Disposable {
  let active = Ref(true)
  let handle = set_timeout(
    () => {
      if active.val {
        active.val = false
        callback()
      }
    },
    ms,
  )
  @base_common.Disposable::from(() => {
    if active.val {
      active.val = false
      clear_timeout(handle)
    }
  })
}

///|
/// Starts every task in its own JavaScript async continuation and resumes when
/// the last continuation finishes. Completion callbacks therefore observe real
/// completion order while shared packages remain independent of the browser's
/// async runtime.
async fn run_async_tasks_concurrently(tasks : Array[async () -> Unit]) -> Unit {
  if tasks.is_empty() {
    return
  }
  @js.suspend((resolve : (Unit) -> Unit, _reject : (Error) -> Unit) => {
    let remaining = Ref(tasks.length())
    for task in tasks {
      @js.async_run(() => {
        task() catch {
          _ => ()
        }
        remaining.val -= 1
        if remaining.val == 0 {
          resolve(())
        }
      })
    }
  }) catch {
    _ => ()
  }
}

///|
/// Starts one detached JS async continuation. Freshness/cancellation ownership
/// remains with the request stamp captured by the continuation.
fn launch_async_task(task : async () -> Unit noraise) -> Unit {
  @js.async_run(task)
}

///|
/// The microtask scheduler Monaco's `MicrotaskEmitter` hardcodes
/// (`event.ts:1610`); injected into `MarkerService`'s change emitter here in
/// the js-only host package (`@base_common` compiles for native too).
extern "js" fn queue_microtask(callback : () -> Unit) -> Unit =
  #| (callback) => globalThis.queueMicrotask(callback)
