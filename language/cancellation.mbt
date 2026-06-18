///|
/// Stable cancellation token passed to async language providers.
pub struct CancellationToken {
  priv cancelled : Ref[Bool]
}

///|
/// Creates a token that can be cancelled by the caller.
pub fn CancellationToken::new() -> CancellationToken {
  { cancelled: Ref(false) }
}

///|
/// Shared never-cancelled token for synchronous or generation-guarded callers.
pub fn CancellationToken::none() -> CancellationToken {
  CancellationToken::new()
}

///|
/// Requests cancellation.
pub fn CancellationToken::cancel(self : CancellationToken) -> Unit {
  self.cancelled.val = true
}

///|
/// Whether cancellation has been requested.
pub fn CancellationToken::is_cancellation_requested(
  self : CancellationToken,
) -> Bool {
  self.cancelled.val
}
