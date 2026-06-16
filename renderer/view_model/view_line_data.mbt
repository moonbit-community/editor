///|
pub fn view_line_rendering_data_from_render_line(
  line : RenderLine,
  decorations? : Array[@decorations.Decoration] = [],
) -> @view_line_renderer.ViewLineRenderingData {
  {
    min_column: 1,
    max_column: line.text.length() + 1,
    content: line.text,
    continues_with_wrapped_line: false,
    contains_rtl: contains_rtl(line.text),
    is_basic_ascii: is_basic_ascii(line.text),
    tokens: line_parts_from_render_line(line),
    inline_decorations: inline_decorations_for_line(line, decorations),
    tab_size: 2,
    start_visible_column: 0,
    text_direction: LTR,
    has_variable_fonts: false,
  }
}

///|
pub fn render_line_input_from_render_line(
  line : RenderLine,
  decorations? : Array[@decorations.Decoration] = [],
  space_width? : Double = 7.2,
  vertical_scrollbar_size? : Double = 0.0,
) -> @view_line_renderer.RenderLineInput {
  @view_line_renderer.RenderLineInput::from_view_line(
    view_line_rendering_data_from_render_line(line, decorations~),
    line_decorations=line_decorations_for_line(line, decorations),
    space_width~,
    vertical_scrollbar_size~,
  )
}

///|
fn line_parts_from_render_line(
  line : RenderLine,
) -> Array[@view_line_renderer.LinePart] {
  let parts : Array[@view_line_renderer.LinePart] = []
  if line.spans.length() == 0 {
    if line.text.length() > 0 {
      parts.push(LinePart(line.text.length(), @syntax.Plain.css_class()))
    }
    return parts
  }
  for span in line.spans {
    parts.push(
      LinePart(
        span.end,
        span.class_name,
        contains_rtl=contains_rtl(line.span_text(span)),
      ),
    )
  }
  parts
}

///|
fn inline_decorations_for_line(
  line : RenderLine,
  decorations : Array[@decorations.Decoration],
) -> Array[@view_line_renderer.InlineDecoration] {
  let inline : Array[@view_line_renderer.InlineDecoration] = []
  let line_start = line.offset
  let line_end = line.offset + line.text.length()
  for decoration in decorations {
    if decoration.kind == CurrentLine {
      continue
    }
    let range = decoration.range
    if range.intersects(Range(line_start, line_end)) {
      inline.push(
        InlineDecoration(
          Range(
            max_int(line_start, range.start) - line_start,
            min_int(line_end, range.end) - line_start,
          ),
          decoration.class_name,
        ),
      )
    }
  }
  inline
}

///|
pub fn line_decorations_for_line(
  line : RenderLine,
  decorations : Array[@decorations.Decoration],
) -> Array[@view_line_renderer.LineDecoration] {
  let line_decorations : Array[@view_line_renderer.LineDecoration] = []
  let line_start = line.offset
  let line_end = line.offset + line.text.length()
  for decoration in decorations {
    if decoration.kind == CurrentLine {
      continue
    }
    let range = decoration.range
    if range.intersects(Range(line_start, line_end)) {
      line_decorations.push(
        LineDecoration(
          max_int(line_start, range.start) - line_start + 1,
          min_int(line_end, range.end) - line_start + 1,
          decoration.class_name,
        ),
      )
    }
  }
  line_decorations
}

///|
fn is_basic_ascii(text : String) -> Bool {
  for i in 0..<text.length() {
    if text[i].to_int() > 127 {
      return false
    }
  }
  true
}

///|
fn contains_rtl(text : String) -> Bool {
  for i in 0..<text.length() {
    let code = text[i].to_int()
    if (code >= 0x0590 && code <= 0x08ff) ||
      (code >= 0xfb1d && code <= 0xfdff) ||
      (code >= 0xfe70 && code <= 0xfeff) {
      return true
    }
  }
  false
}
