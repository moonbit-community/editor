///|
/// Pure line-HTML emission, the Monaco `viewLineRenderer` role: a
/// `RenderLine` plus controller decorations become the escaped inner HTML
/// of one line node. No DOM types; the browser view assigns the result
/// with one `innerHTML` write per entering line.
///
/// Decoration merging mirrors the old vdom path: `CurrentLine`
/// decorations extend the line class (see `render_line_class`), every
/// other kind extends the classes of the spans it intersects.
pub fn render_line_html(
  line : RenderLine,
  decorations : Array[@decorations.Decoration],
) -> String {
  let html = StringBuilder()
  html.write_string("<pre class=\"code\">")
  if line.spans.length() == 0 {
    write_escaped(html, line.text)
  } else {
    for span in line.spans {
      let mut class_name = span.class_name
      let span_range = @core.Range(
        line.offset + span.start,
        line.offset + span.end,
      )
      for decoration in decorations {
        if decoration.kind != CurrentLine &&
          decoration.range.intersects(span_range) {
          class_name = class_name + " " + decoration.class_name
        }
      }
      html.write_string("<span class=\"")
      write_escaped(html, class_name)
      html.write_string("\">")
      write_escaped(html, line.span_text(span))
      html.write_string("</span>")
    }
  }
  html.write_string("</pre>")
  html.to_string()
}

///|
/// The class of the line node itself: `code-line` plus any `CurrentLine`
/// decorations touching the line (inclusive bounds, as before).
pub fn render_line_class(
  line : RenderLine,
  decorations : Array[@decorations.Decoration],
) -> String {
  let line_start = line.offset
  let line_end = line.offset + line.text.length()
  let mut class_name = "code-line"
  for decoration in decorations {
    if decoration.kind == CurrentLine &&
      decoration.range.start <= line_end &&
      line_start <= decoration.range.end {
      class_name = class_name + " " + decoration.class_name
    }
  }
  class_name
}

///|
/// HTML-escapes text for element content or attribute values.
pub fn escape_html(text : String) -> String {
  let html = StringBuilder()
  write_escaped(html, text)
  html.to_string()
}

///|
fn write_escaped(html : StringBuilder, text : String) -> Unit {
  for ch in text {
    match ch {
      '&' => html.write_string("&amp;")
      '<' => html.write_string("&lt;")
      '>' => html.write_string("&gt;")
      '"' => html.write_string("&quot;")
      _ => html.write_char(ch)
    }
  }
}
