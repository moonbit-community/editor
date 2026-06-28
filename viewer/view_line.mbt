///|
fn viewport_window(
  viewport : @view_layout.ViewportData,
) -> @view_layout.LineWindow {
  // ViewportData is a 1-based inclusive range `[start, end]`; the render window
  // is the equivalent 1-based half-open `[start, end + 1)`.
  { start: viewport.start_line_number, end: viewport.end_line_number + 1 }
}

///|
fn render_line_input_for_viewport(
  viewport : @view_layout.ViewportData,
  index : Int,
  space_width : Double,
) -> @view_line_renderer.RenderLineInput {
  let line_number = viewport.start_line_number + index
  @view_line_renderer.RenderLineInput::from_view_line(
    viewport.lines[index],
    line_decorations=viewport.decorations_for_line(line_number),
    space_width~,
    vertical_scrollbar_size=editor_vertical_scrollbar_size,
  )
}

///|
/// Writes a line node's attributes, and on `rewrite_html` its `innerHTML`.
/// Returns the freshly produced `CharacterMapping` when the HTML is rewritten,
/// or `None` when the existing DOM (and its previously stored mapping) is
/// reused. The mapping is the DOM-truth bridge consumed by hit-testing and
/// selection measurement.
fn write_line_node(
  node : @rdom.Element,
  line : @view_model.RenderLine,
  view_decorations : Array[@view_model.ViewModelDecoration],
  input : @view_line_renderer.RenderLineInput,
  top : Int,
  rewrite_html~ : Bool,
) -> @view_line_renderer.CharacterMapping? {
  node.set_attribute(
    "class",
    @viewer_common.render_line_class(line, view_decorations),
  )
  node.set_attribute("data-line", line.line_number.to_string())
  node.set_attribute("style", line_node_style(top))
  if rewrite_html {
    let output = @view_line_renderer.render_view_line2(input)
    node.set_inner_html(output.html)
    Some(output.character_mapping)
  } else {
    None
  }
}

///|
fn write_line_number_node(
  gutter : @rdom.Element,
  line : @view_model.RenderLine,
  top : Int,
) -> Unit {
  gutter.set_attribute("class", "line-number")
  gutter.set_attribute("data-line", line.line_number.to_string())
  gutter.set_attribute("style", line_node_style(top))
  gutter.set_inner_html(line.line_number.to_string())
}

///|
fn line_node_style(top : Int) -> String {
  "top:" +
  top.to_string() +
  "px;height:" +
  editor_line_height.to_string() +
  "px"
}
