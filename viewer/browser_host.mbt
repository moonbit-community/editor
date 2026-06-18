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
