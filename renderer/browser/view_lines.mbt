///|
/// Pixel height of one rendered code line. Keep in sync with
/// `--editor-line-height` in app/src/style.css.
let editor_line_height = 18

///|
/// Total horizontal padding of the line-number gutter. Keep in sync with
/// `.gutter` padding in app/src/style.css.
let gutter_padding_px = 34

///|
/// Lines and spans carry no feature knowledge: feature classes arrive as
/// controller decorations merged onto the syntax classes here.
fn view_line(
  decorations : Array[@decorations.Decoration],
  line : @renderer.RenderLine,
) -> @html.Html {
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
  @html.div(
    class=class_name,
    attrs=@html.Attrs::build().data_set("line", line.line_number.to_string()),
    [
      @html.div(class="gutter", line.line_number.to_string()),
      if line.spans.length() == 0 {
        @html.pre(class="code", if line.text == "" { " " } else { line.text })
      } else {
        @html.pre(class="code", span_nodes(decorations, line))
      },
    ],
  )
}

///|
fn span_nodes(
  decorations : Array[@decorations.Decoration],
  line : @renderer.RenderLine,
) -> Array[@html.Html] {
  let spans : Array[@html.Html] = []
  for i in 0..<line.spans.length() {
    let span = line.spans[i]
    let absolute_start = line.offset + span.start
    let absolute_end = line.offset + span.end
    spans.push(view_span(decorations, span, absolute_start, absolute_end))
  }
  spans
}

///|
/// Spans carry no handlers or data attributes: text plus classes only. All
/// interaction routes through the container hit test.
fn view_span(
  decorations : Array[@decorations.Decoration],
  span : @renderer.RenderSpan,
  absolute_start : Int,
  absolute_end : Int,
) -> @html.Html {
  let mut class_name = span.class_name
  let span_range = @core.Range(absolute_start, absolute_end)
  for decoration in decorations {
    if decoration.kind != CurrentLine && decoration.range.intersects(span_range) {
      class_name = class_name + " " + decoration.class_name
    }
  }
  @html.span(class=class_name, span.text)
}

///|
fn line_col_for_offset(
  frame : @renderer.RenderFrame,
  offset : Int,
) -> (Int, Int)? {
  for line in frame.lines {
    let end = line.offset + line.text.length()
    if offset >= line.offset && offset <= end {
      return Some((line.line_number, offset - line.offset))
    }
  }
  None
}
