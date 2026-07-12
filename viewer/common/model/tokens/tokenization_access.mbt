///| Live model access and host-neutral scheduling contracts.

///|
/// Idle callback deadline. Callers must read `time_remaining` immediately.
pub struct TokenizationIdleDeadline {
  priv read_time_remaining : () -> Double
}

///|
/// Creates a deadline backed by a host-provided remaining-time reader.
pub fn TokenizationIdleDeadline::new(
  read_time_remaining : () -> Double,
) -> TokenizationIdleDeadline {
  { read_time_remaining, }
}

///|
/// Remaining idle budget in milliseconds.
pub fn TokenizationIdleDeadline::time_remaining(
  self : TokenizationIdleDeadline,
) -> Double {
  (self.read_time_remaining)()
}

///|
/// FFI-free scheduling surface supplied by a browser host or deterministic test.
pub struct TokenizationScheduler {
  priv schedule_idle : ((TokenizationIdleDeadline) -> Unit) -> @base_common.Disposable
  priv schedule_zero : (() -> Unit) -> @base_common.Disposable
  priv schedule_delay : (Int, () -> Unit) -> @base_common.Disposable
  priv read_now : () -> Double
}

///|
/// Creates a scheduler from cancellable idle, zero-timeout, delayed, and clock
/// operations. All durations and clock values use milliseconds.
pub fn TokenizationScheduler::new(
  idle~ : ((TokenizationIdleDeadline) -> Unit) -> @base_common.Disposable,
  zero_timeout~ : (() -> Unit) -> @base_common.Disposable,
  delay~ : (Int, () -> Unit) -> @base_common.Disposable,
  now~ : () -> Double,
) -> TokenizationScheduler {
  {
    schedule_idle: idle,
    schedule_zero: zero_timeout,
    schedule_delay: delay,
    read_now: now,
  }
}

///|
/// Schedules cancellable idle work.
pub fn TokenizationScheduler::idle(
  self : TokenizationScheduler,
  callback : (TokenizationIdleDeadline) -> Unit,
) -> @base_common.Disposable {
  (self.schedule_idle)(callback)
}

///|
/// Schedules a cancellable zero-timeout continuation.
pub fn TokenizationScheduler::zero_timeout(
  self : TokenizationScheduler,
  callback : () -> Unit,
) -> @base_common.Disposable {
  (self.schedule_zero)(callback)
}

///|
/// Schedules a cancellable delayed continuation.
pub fn TokenizationScheduler::delay(
  self : TokenizationScheduler,
  milliseconds : Int,
  callback : () -> Unit,
) -> @base_common.Disposable {
  (self.schedule_delay)(milliseconds, callback)
}

///|
/// Reads the scheduler's monotonic millisecond clock.
pub fn TokenizationScheduler::now(self : TokenizationScheduler) -> Double {
  (self.read_now)()
}

///|
/// Synchronized live facts borrowed from `TextModel`. Every query is a closure
/// so replacement content is visible before flush handling and no line array is
/// copied across the package-cycle boundary.
pub struct TokenizationModelAccess {
  priv read_line_count : () -> Int
  priv read_line_content : (Int) -> String
  priv read_line_length : (Int) -> Int
  priv read_first_non_whitespace_column : (Int) -> Int
  priv read_language_id : () -> String
  priv read_attached_count : () -> Int
  priv read_too_large : () -> Bool
  priv read_disposing : () -> Bool
  priv read_scheduler : () -> TokenizationScheduler?
  priv report_error : (String) -> Unit
}

///|
/// Creates the live access carrier owned and synchronized by `TextModel`.
pub fn TokenizationModelAccess::new(
  line_count~ : () -> Int,
  line_content~ : (Int) -> String,
  line_length~ : (Int) -> Int,
  first_non_whitespace_column~ : (Int) -> Int,
  language_id~ : () -> String,
  attached_count~ : () -> Int,
  too_large~ : () -> Bool,
  disposing~ : () -> Bool,
  scheduler~ : () -> TokenizationScheduler?,
  unexpected_error~ : (String) -> Unit,
) -> TokenizationModelAccess {
  {
    read_line_count: line_count,
    read_line_content: line_content,
    read_line_length: line_length,
    read_first_non_whitespace_column: first_non_whitespace_column,
    read_language_id: language_id,
    read_attached_count: attached_count,
    read_too_large: too_large,
    read_disposing: disposing,
    read_scheduler: scheduler,
    report_error: unexpected_error,
  }
}

///|
/// Current logical line count.
pub fn TokenizationModelAccess::line_count(
  self : TokenizationModelAccess,
) -> Int {
  (self.read_line_count)()
}

///|
/// Current content of one validated one-based line.
pub fn TokenizationModelAccess::line_content(
  self : TokenizationModelAccess,
  line_number : Int,
) -> String {
  (self.read_line_content)(line_number)
}

///|
/// Current UTF-16 length of one validated one-based line.
pub fn TokenizationModelAccess::line_length(
  self : TokenizationModelAccess,
  line_number : Int,
) -> Int {
  (self.read_line_length)(line_number)
}

///|
/// Current one-based first-non-whitespace column, or zero for whitespace-only.
pub fn TokenizationModelAccess::first_non_whitespace_column(
  self : TokenizationModelAccess,
  line_number : Int,
) -> Int {
  (self.read_first_non_whitespace_column)(line_number)
}

///|
/// Current construction-fixed language id.
pub fn TokenizationModelAccess::language_id(
  self : TokenizationModelAccess,
) -> String {
  (self.read_language_id)()
}

///|
/// Aggregate attached editor count after the current transition.
pub fn TokenizationModelAccess::attached_count(
  self : TokenizationModelAccess,
) -> Int {
  (self.read_attached_count)()
}

///|
/// Constructor-fixed large-file tokenization guard.
pub fn TokenizationModelAccess::is_too_large(
  self : TokenizationModelAccess,
) -> Bool {
  (self.read_too_large)()
}

///|
/// Whether the owning model is in its disposal guard interval.
pub fn TokenizationModelAccess::is_disposing(
  self : TokenizationModelAccess,
) -> Bool {
  (self.read_disposing)()
}

///|
/// Scheduler selected for the current aggregate attached epoch, if any.
pub fn TokenizationModelAccess::scheduler(
  self : TokenizationModelAccess,
) -> TokenizationScheduler? {
  (self.read_scheduler)()
}

///|
/// Reports a tokenizer failure at the model-owned unexpected-error seam.
pub fn TokenizationModelAccess::report_unexpected_error(
  self : TokenizationModelAccess,
  message : String,
) -> Unit {
  (self.report_error)(message)
}
