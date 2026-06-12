///|
test "line html escapes text and merges span decorations" {
  let doc = @core.DocumentSnapshot("let a = \"<b> & 'c'\"")
  let frame = frame_for(doc, { start_line: 0, end_line: 1 })
  let line = frame.lines[0]
  let plain = @renderer.render_line_html(line, [])
  assert_true(plain.contains("<pre class=\"code\">"))
  assert_true(plain.contains("&quot;&lt;b&gt; &amp; 'c'&quot;"))
  assert_false(plain.contains("<b>"))
  // A diagnostic decoration over `a` lands on the spans it intersects.
  let decorated = @renderer.render_line_html(line, [
    Decoration(Range(4, 5), Diagnostic, "diag-warning"),
  ])
  assert_true(decorated.contains("class=\"tok-identifier diag-warning\""))
  // The line class carries CurrentLine decorations only.
  assert_eq(@renderer.render_line_class(line, []), "code-line")
  assert_eq(
    @renderer.render_line_class(line, [
      Decoration(Range(0, 1), CurrentLine, "current-line"),
    ]),
    "code-line current-line",
  )
  assert_eq(
    @renderer.render_line_html(line, [
      Decoration(Range(0, 1), CurrentLine, "current-line"),
    ]),
    plain,
  )
}

///|
test "empty lines emit an empty pre" {
  let doc = @core.DocumentSnapshot("a\n\nb")
  let frame = frame_for(doc, { start_line: 0, end_line: 3 })
  assert_eq(
    @renderer.render_line_html(frame.lines[1], []),
    "<pre class=\"code\"></pre>",
  )
}
