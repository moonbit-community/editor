///|
test "line html escapes text and merges span decorations" {
  let doc = @model.TextSnapshot("let a = \"<b> & 'c'\"")
  let frame = frame_for(doc, { start_line: 1, end_line: 2 })
  let line = frame.lines[0]
  let plain = @common.render_line_html(line, [])
  assert_true(plain.contains("<span class=\"view-line-content\">"))
  // `<`, `>`, `&` are escaped; like Monaco, `"` is left literal in text content
  // (only attribute values need quote-escaping). Spaces render as U+00A0, so the
  // escaped entities are checked without relying on the space byte.
  assert_true(plain.contains("\"&lt;b&gt;"))
  assert_true(plain.contains("&amp;"))
  assert_true(plain.contains("'c'\""))
  assert_false(plain.contains("<b>"))
  // A diagnostic decoration over `a` (view line 1, columns 5..6) lands on the
  // spans it intersects.
  let decorated = @common.render_line_html(line, [
    LineDecoration(5, 6, "diag-warning"),
  ])
  assert_true(decorated.contains("class=\"mtk4 diag-warning\""))
  // The line node's own class is constant (the current-line highlight renders
  // through its own overlay).
  assert_eq(@common.render_line_class(line), "view-line")
}

///|
test "empty lines emit an empty view-line content wrapper" {
  let doc = @model.TextSnapshot("a\n\nb")
  let frame = frame_for(doc, { start_line: 1, end_line: 4 })
  // Monaco emits an empty inner `<span></span>` for a blank line.
  assert_eq(
    @common.render_line_html(frame.lines[1], []),
    "<span class=\"view-line-content\"><span></span></span>",
  )
}
