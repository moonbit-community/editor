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
#external
priv type TokenizationIdleTarget

///|
#external
priv type BrowserIdleDeadline

///|
#external
priv type TokenizationIdleAdapter

///|
extern "js" fn global_tokenization_idle_target_js() -> TokenizationIdleTarget = "() => globalThis"

///|
/// Selects Monaco's browser-idle implementation once for one realm. The
/// injected target is the exact local test seam; production constructs one
/// process-global adapter from `globalThis` below.
extern "js" fn create_tokenization_idle_adapter_js(
  target : TokenizationIdleTarget,
) -> TokenizationIdleAdapter =
  #| (target) => {
  #|   let runWhenIdle;
  #|   if (typeof target.requestIdleCallback !== "function" ||
  #|       typeof target.cancelIdleCallback !== "function") {
  #|     runWhenIdle = (_targetWindow, runner, _timeout) => {
  #|       target.setTimeout(() => {
  #|         if (disposed) return;
  #|         const end = target.Date.now() + 15;
  #|         const deadline = {
  #|           didTimeout: true,
  #|           timeRemaining() {
  #|             return Math.max(0, end - target.Date.now());
  #|           },
  #|         };
  #|         runner(Object.freeze(deadline));
  #|       }, 0);
  #|       let disposed = false;
  #|       return () => {
  #|         if (disposed) return;
  #|         disposed = true;
  #|       };
  #|     };
  #|   } else {
  #|     runWhenIdle = (targetWindow, runner, timeout) => {
  #|       const handle = targetWindow.requestIdleCallback(
  #|         runner,
  #|         typeof timeout === "number" ? { timeout } : undefined,
  #|       );
  #|       let disposed = false;
  #|       return () => {
  #|         if (disposed) return;
  #|         disposed = true;
  #|         targetWindow.cancelIdleCallback(handle);
  #|       };
  #|     };
  #|   }
  #|   return (runner, hasTimeout, timeout) =>
  #|     runWhenIdle(target, runner, hasTimeout ? timeout : undefined);
  #| }

///|
extern "js" fn run_tokenization_idle_adapter_js(
  adapter : TokenizationIdleAdapter,
  callback : (BrowserIdleDeadline) -> Unit,
  has_timeout : Bool,
  timeout : Double,
) -> () -> Unit = "(adapter, callback, hasTimeout, timeout) => adapter(callback, hasTimeout, timeout)"

///|
extern "js" fn browser_idle_deadline_time_remaining_js(
  deadline : BrowserIdleDeadline,
) -> Double = "(deadline) => deadline.timeRemaining()"

///|
/// Monaco's `runWhenGlobalIdle`: bind the once-selected adapter to the same
/// `globalThis` realm used for feature detection (`async.ts:1536-1579`).
let browser_tokenization_idle_adapter : TokenizationIdleAdapter = create_tokenization_idle_adapter_js(
  global_tokenization_idle_target_js(),
)

///|
fn schedule_tokenization_idle(
  callback : (@model.TokenizationIdleDeadline) -> Unit,
) -> @base_common.Disposable {
  let cancel = run_tokenization_idle_adapter_js(
    browser_tokenization_idle_adapter,
    deadline => {
      callback(
        @model.TokenizationIdleDeadline::new(() => {
          browser_idle_deadline_time_remaining_js(deadline)
        }),
      )
    },
    false,
    0.0,
  )
  @base_common.Disposable::from(cancel)
}

///|
let browser_tokenization_scheduler : @model.TokenizationScheduler = @model.TokenizationScheduler::new(
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
