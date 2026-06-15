///|
test "log service filters by level" {
  let memory = MemoryLogger::new()
  let service = LogService::new(level=Warning, logger=memory)
  service.info("test", "hidden")
  service.warn("test", "visible", details=[("key", "value")])
  service.error("test", "also visible")
  let entries = memory.entries()
  assert_eq(entries.length(), 2)
  assert_true(entries[0].level == Warning)
  assert_true(entries[0].details[0] == ("key", "value"))
  assert_true(entries[1].level == Error)
}

///|
test "null logger accepts entries and flushes" {
  let service = LogService::new(logger=NullLogger::new())
  service.error("test", "ignored")
  service.flush()
  assert_true(true)
}

///|
test "multiplex logger fans out entries and flushes" {
  let first = MemoryLogger::new()
  let second = MemoryLogger::new()
  let mux = MultiplexLogger::new([first, second])
  let service = LogService::new(level=Trace, logger=mux)
  service.debug("test", "fanout")
  service.flush()
  assert_eq(first.entries().length(), 1)
  assert_eq(second.entries().length(), 1)
  assert_eq(first.flush_count(), 1)
  assert_eq(second.flush_count(), 1)
}
