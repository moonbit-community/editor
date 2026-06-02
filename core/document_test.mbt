///|
test "line index handles lf and crlf" {
  let doc = DocumentSnapshot::new("one\ntwo\r\nthree")
  assert_eq(doc.line_count(), 3)
  assert_eq(doc.line_text(0), "one")
  assert_eq(doc.line_text(1), "two")
  assert_eq(doc.line_text(2), "three")
  assert_eq(doc.line_start_offset(2), 9)
}

///|
test "offset and position use utf16 code units" {
  let doc = DocumentSnapshot::new("a😊\n中")
  assert_eq(doc.length(), 5)
  let pos = doc.position_at_offset(3)
  assert_eq(pos.line, 0)
  assert_eq(pos.column, 3)
  assert_eq(doc.offset_at_position(Position::new(1, 1)), 5)
}

///|
test "range helpers normalize and intersect" {
  let range = Range::new(8, 3)
  assert_eq(range.start, 3)
  assert_eq(range.end, 8)
  assert_true(range.contains_offset(4))
  assert_false(range.contains_offset(8))
  assert_true(range.intersects(Range::new(7, 10)))
}
