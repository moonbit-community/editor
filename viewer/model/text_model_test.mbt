///|
test "text snapshot handles lf and crlf" {
  let doc = @model.TextSnapshot("one\ntwo\r\nthree")
  assert_eq(doc.line_count(), 3)
  assert_eq(doc.line_text(0), "one")
  assert_eq(doc.line_text(1), "two")
  assert_eq(doc.line_text(2), "three")
  assert_eq(doc.line_start_offset(2), 9)
}

///|
test "offset and position use utf16 code units" {
  let doc = @model.TextSnapshot("a😊\n中")
  assert_eq(doc.length(), 5)
  let pos = doc.position_at_offset(3)
  assert_eq(pos.line, 0)
  assert_eq(pos.column, 3)
  assert_eq(doc.offset_at_position(Position(1, 1)), 5)
}

///|
test "text model owns uri and version identity" {
  let model = @model.TextModel(
    @base_common.Uri::memory("main.mbt"),
    "main.mbt",
    "moonbit",
    3,
    "rev-3",
    "pub fn main {}\n",
  )
  assert_eq(model.uri.to_string(), "memory://main.mbt")
  assert_eq(model.display_name, "main.mbt")
  assert_eq(model.language_id, "moonbit")
  assert_eq(model.version, 3)
  assert_eq(model.revision, "rev-3")
  assert_eq(model.snapshot().text, "pub fn main {}\n")
}
