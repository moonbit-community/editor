///|
/// Converts a rendered view-model line to line-renderer data. Decorations are
/// supplied already in view coordinates (`ViewModelDecoration`) and clipped to
/// this view line; no document-offset arithmetic is involved.
pub fn view_line_rendering_data_from_render_line(
  line : RenderLine,
  view_decorations? : Array[ViewModelDecoration] = [],
) -> @view_line_renderer.ViewLineRenderingData {
  {
    min_column: 1,
    max_column: line.text.length() + 1,
    content: line.text,
    continues_with_wrapped_line: false,
    contains_rtl: contains_rtl(line.text),
    is_basic_ascii: is_basic_ascii(line.text),
    tokens: line_parts_from_render_line(line),
    inline_decorations: inline_decorations_for_line(line, view_decorations),
    tab_size: 2,
    start_visible_column: 0,
    text_direction: LTR,
    has_variable_fonts: false,
  }
}

///|
/// Builds full line-renderer input from a rendered view-model line, applying
/// the view-coordinate decorations that cover the line.
pub fn render_line_input_from_render_line(
  line : RenderLine,
  view_decorations? : Array[ViewModelDecoration] = [],
  space_width? : Double = 7.2,
  vertical_scrollbar_size? : Double = 0.0,
) -> @view_line_renderer.RenderLineInput {
  @view_line_renderer.RenderLineInput::from_view_line(
    view_line_rendering_data_from_render_line(line, view_decorations~),
    line_decorations=line_decorations_for_line(line, view_decorations),
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
/// Inline decorations (line-local, zero-based half-open columns) covering this
/// view line, clipped from each decoration's view range. Mirrors Monaco's
/// per-line inline-decoration projection; current-line decorations style the
/// line node itself, not its spans, so they are skipped here.
fn inline_decorations_for_line(
  line : RenderLine,
  view_decorations : Array[ViewModelDecoration],
) -> Array[@view_line_renderer.InlineDecoration] {
  let inline : Array[@view_line_renderer.InlineDecoration] = []
  let max_column = line.text.length() + 1
  for decoration in view_decorations {
    if decoration.kind == CurrentLine {
      continue
    }
    match decoration.columns_on_view_line(line.line_number, max_column) {
      Some((start_column, end_column)) =>
        inline.push(
          InlineDecoration(
            OffsetRange(start_column - 1, end_column - 1),
            decoration.class_name,
          ),
        )
      None => ()
    }
  }
  inline
}

///|
/// Line decorations in one-based columns for the line renderer, clipped from
/// each decoration's view range.
pub fn line_decorations_for_line(
  line : RenderLine,
  view_decorations : Array[ViewModelDecoration],
) -> Array[@view_line_renderer.LineDecoration] {
  let line_decorations : Array[@view_line_renderer.LineDecoration] = []
  let max_column = line.text.length() + 1
  for decoration in view_decorations {
    if decoration.kind == CurrentLine {
      continue
    }
    match decoration.columns_on_view_line(line.line_number, max_column) {
      Some((start_column, end_column)) =>
        line_decorations.push(
          LineDecoration(start_column, end_column, decoration.class_name),
        )
      None => ()
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
