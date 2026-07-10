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
