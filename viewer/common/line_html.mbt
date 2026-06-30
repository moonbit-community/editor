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
  render_whitespace? : @view_line_renderer.RenderWhitespace = None,
  render_control_characters? : Bool = false,
) -> String {
  @view_line_renderer.render_view_line2(
    @view_model.render_line_input_from_render_line(
      line,
      view_decorations~,
      render_whitespace~,
      render_control_characters~,
    ),
  ).html
}

///|
/// Source-code HTML for one rendered line, the Monaco `_tokenizeToString` role
/// (`textToHtmlTokenizer.ts`): class-based token spans with HTML-escaped text
/// and ordinary, *breakable* spaces — no `U+00A0` substitution or tab
/// expansion. Used for hover/markdown code blocks, which wrap (`white-space:
/// pre-wrap`); distinct from `render_line_html`, the editor view-line renderer,
/// whose non-breaking spaces and tab expansion reproduce Monaco's view geometry
/// but never break.
pub fn render_source_line_html(line : @view_model.RenderLine) -> String {
  let html = StringBuilder()
  html.write_string("<span class=\"view-line-content\">")
  let tokens = line.tokens
  let mut start = 0
  let mut wrote = false
  for i in 0..<tokens.get_count() {
    let end = tokens.get_end_offset(i)
    if start < end {
      html.write_string("<span class=\"")
      write_escaped(html, tokens.get_class_name(i))
      html.write_string("\">")
      write_escaped(html, tokens.get_token_text(i))
      html.write_string("</span>")
      wrote = true
    }
    start = end
  }
  if !wrote {
    write_escaped(html, line.text)
  }
  html.write_string("</span>")
  html.to_string()
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
