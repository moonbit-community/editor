///|
/// Line-table behavior of `DocumentSnapshot`, matching the byte-identical
/// `build_line_starts` copy in `viewer/common/model/text_snapshot.mbt` (see
/// that function's pairing note): `\n`, a lonely `\r`, and `\r\n` each end a
/// line, with the `\r\n` pair counted as one line break.
test "document snapshot splits on lf, lonely cr, and crlf" {
  let doc = @workspace.DocumentSnapshot(
    @base_common.Uri::memory("eol.txt"),
    "",
    "",
    "",
    "one\ntwo\rthree\r\nfour",
  )
  assert_eq(doc.line_count(), 4)
  assert_eq(doc.line_text(0), "one")
  assert_eq(doc.line_text(1), "two")
  assert_eq(doc.line_text(2), "three")
  assert_eq(doc.line_text(3), "four")
  // Offset↔position round trip across the lonely-CR break: offset 8 is the
  // 't' of "three" (line 3, column 1).
  let pos = doc.position_at_offset(8)
  assert_eq(pos.line_number, 3)
  assert_eq(pos.column, 1)
  assert_eq(doc.offset_at_position(pos), 8)
}
