///|
/// Pure line-HTML emission, the Monaco `viewLineRenderer` role: a
/// `RenderLine` plus controller decorations become the escaped inner HTML
/// of one `.view-line` node. No DOM types; the browser view assigns the
/// result with one `innerHTML` write per entering line.
///
/// Decoration merging mirrors the old vdom path: `CurrentLine`
/// decorations extend the line class (see `render_line_class`), every
/// other kind extends the classes of the spans it intersects.
pub fn render_line_html(
  line : @view_model.RenderLine,
  view_decorations : Array[@view_model.ViewModelDecoration],
) -> String {
  @view_line_renderer.render_view_line2(
    @view_model.render_line_input_from_render_line(line, view_decorations~),
  ).html
}

///|
/// The class of the line node itself: `view-line` plus any `CurrentLine`
/// decorations covering the view line (inclusive view-line bounds).
pub fn render_line_class(
  line : @view_model.RenderLine,
  view_decorations : Array[@view_model.ViewModelDecoration],
) -> String {
  let mut class_name = "view-line"
  for decoration in view_decorations {
    if decoration.kind == CurrentLine &&
      decoration.range.start_line_number <= line.line_number &&
      line.line_number <= decoration.range.end_line_number {
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
