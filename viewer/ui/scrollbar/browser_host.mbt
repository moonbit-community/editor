///|
/// One-shot timer. The custom scrollbar's auto-hide delay runs through this
/// instead of a framework command. Mirrors the viewer core's `set_timeout`.
extern "js" fn set_timeout(callback : () -> Unit, ms : Int) -> Double =
  #| (callback, ms) => globalThis.setTimeout(callback, ms)
