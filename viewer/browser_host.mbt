///|
/// Monotonic high-resolution timestamp in milliseconds, for render timing
/// instrumentation.
extern "js" fn now_ms() -> Double =
  #| () => globalThis.performance?.now() ?? Date.now()

///|
/// One-shot timer. The viewer's hover and scrollbar delays run through this
/// instead of framework commands.
extern "js" fn set_timeout(callback : () -> Unit, ms : Int) -> Double =
  #| (callback, ms) => globalThis.setTimeout(callback, ms)

///|
/// The microtask scheduler Monaco's `MicrotaskEmitter` hardcodes
/// (`event.ts:1610`); injected into `MarkerService`'s change emitter here in
/// the js-only host package (`@base_common` compiles for native too).
extern "js" fn queue_microtask(callback : () -> Unit) -> Unit =
  #| (callback) => globalThis.queueMicrotask(callback)
