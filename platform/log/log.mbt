///|
pub(all) enum LogLevel {
  Off
  Trace
  Debug
  Info
  Warning
  Error
} derive(Eq, Debug)

///|
pub(all) struct LogEntry {
  level : LogLevel
  category : String
  message : String
  details : Array[(String, String)]
} derive(Eq, Debug)

///|
pub(open) trait Logger {
  fn log(Self, LogEntry) -> Unit noraise
  fn flush(Self) -> Unit noraise
}

///|
pub(all) struct NullLogger {}

///|
pub fn NullLogger::new() -> NullLogger {
  NullLogger::{  }
}

///|
pub impl Logger for NullLogger with fn log(_self, _entry) {
  ()
}

///|
pub impl Logger for NullLogger with fn flush(_self) {
  ()
}

///|
pub(all) struct MemoryLogger {
  entries : Array[LogEntry]
  flush_count : Ref[Int]
}

///|
pub fn MemoryLogger::new() -> MemoryLogger {
  { entries: [], flush_count: Ref(0) }
}

///|
pub fn MemoryLogger::entries(self : MemoryLogger) -> Array[LogEntry] {
  self.entries.copy()
}

///|
pub fn MemoryLogger::flush_count(self : MemoryLogger) -> Int {
  self.flush_count.val
}

///|
pub impl Logger for MemoryLogger with fn log(self, entry) {
  self.entries.push(entry)
}

///|
pub impl Logger for MemoryLogger with fn flush(self) {
  self.flush_count.val = self.flush_count.val + 1
}

///|
pub(all) struct MultiplexLogger {
  loggers : Array[&Logger]
}

///|
pub fn MultiplexLogger::new(loggers : Array[&Logger]) -> MultiplexLogger {
  { loggers, }
}

///|
pub impl Logger for MultiplexLogger with fn log(self, entry) {
  for logger in self.loggers {
    logger.log(entry)
  }
}

///|
pub impl Logger for MultiplexLogger with fn flush(self) {
  for logger in self.loggers {
    logger.flush()
  }
}

///|
pub(all) struct LogService {
  level : LogLevel
  logger : &Logger
}

///|
pub fn LogService::new(
  level? : LogLevel = Info,
  logger? : &Logger = NullLogger::{  },
) -> LogService {
  { level, logger }
}

///|
pub fn LogService::log(self : LogService, entry : LogEntry) -> Unit {
  if should_log(self.level, entry.level) {
    self.logger.log(entry)
  }
}

///|
pub fn LogService::trace(
  self : LogService,
  category : String,
  message : String,
  details? : Array[(String, String)] = [],
) -> Unit {
  self.log({ level: Trace, category, message, details })
}

///|
pub fn LogService::debug(
  self : LogService,
  category : String,
  message : String,
  details? : Array[(String, String)] = [],
) -> Unit {
  self.log({ level: Debug, category, message, details })
}

///|
pub fn LogService::info(
  self : LogService,
  category : String,
  message : String,
  details? : Array[(String, String)] = [],
) -> Unit {
  self.log({ level: Info, category, message, details })
}

///|
pub fn LogService::warn(
  self : LogService,
  category : String,
  message : String,
  details? : Array[(String, String)] = [],
) -> Unit {
  self.log({ level: Warning, category, message, details })
}

///|
pub fn LogService::error(
  self : LogService,
  category : String,
  message : String,
  details? : Array[(String, String)] = [],
) -> Unit {
  self.log({ level: Error, category, message, details })
}

///|
pub fn LogService::flush(self : LogService) -> Unit {
  self.logger.flush()
}

///|
pub fn LogLevel::label(self : LogLevel) -> String {
  match self {
    Off => "off"
    Trace => "trace"
    Debug => "debug"
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
pub fn LogLevel::is_warning_or_error(self : LogLevel) -> Bool {
  level_rank(self) >= level_rank(Warning) && self != Off
}

///|
fn should_log(configured : LogLevel, entry : LogLevel) -> Bool {
  configured != Off &&
  entry != Off &&
  level_rank(entry) >= level_rank(configured)
}

///|
fn level_rank(level : LogLevel) -> Int {
  match level {
    Off => 99
    Trace => 0
    Debug => 1
    Info => 2
    Warning => 3
    Error => 4
  }
}
