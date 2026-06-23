///|
test "line html escapes text and merges span decorations" {
  let doc = @model.TextSnapshot("let a = \"<b> & 'c'\"")
  let frame = frame_for(doc, { start_line: 0, end_line: 1 })
  let line = frame.lines[0]
  let plain = @common.render_line_html(line, [])
  assert_true(plain.contains("<span class=\"view-line-content\">"))
  assert_true(plain.contains("&quot;&lt;b&gt; &amp; 'c'&quot;"))
  assert_false(plain.contains("<b>"))
  // A diagnostic decoration over `a` (view line 1, columns 5..6) lands on the
  // spans it intersects.
  let decorated = @common.render_line_html(line, [
    view_decoration(5, 6, Diagnostic, "diag-warning"),
  ])
  assert_true(decorated.contains("class=\"tok-identifier diag-warning\""))
  // The line class carries CurrentLine decorations only.
  assert_eq(@common.render_line_class(line, []), "view-line")
  assert_eq(
    @common.render_line_class(line, [
      view_decoration(1, 2, CurrentLine, "current-line"),
    ]),
    "view-line current-line",
  )
  assert_eq(
    @common.render_line_html(line, [
      view_decoration(1, 2, CurrentLine, "current-line"),
    ]),
    plain,
  )
}

///|
/// Builds a single-line view-coordinate decoration with one-based columns.
fn view_decoration(
  start_column : Int,
  end_column : Int,
  kind : @decorations.DecorationKind,
  class_name : String,
) -> @view_model.ViewModelDecoration {
  {
    range: {
      start_line_number: 1,
      start_column,
      end_line_number: 1,
      end_column,
    },
    kind,
    class_name,
  }
}

///|
test "empty lines emit an empty view-line content wrapper" {
  let doc = @model.TextSnapshot("a\n\nb")
  let frame = frame_for(doc, { start_line: 0, end_line: 3 })
  assert_eq(
    @common.render_line_html(frame.lines[1], []),
    "<span class=\"view-line-content\"></span>",
  )
}
