///|
fn viewport_window(
  viewport : @renderer.ViewportData,
) -> @view_layout.LineWindow {
  { start: viewport.start_line_number - 1, end: viewport.end_line_number }
}

///|
fn render_line_input_for_viewport(
  viewport : @renderer.ViewportData,
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
fn write_line_node(
  node : @rdom.Element,
  line : @view_model.RenderLine,
  decorations : Array[@decorations.Decoration],
  input : @view_line_renderer.RenderLineInput,
  window_index : Int,
  rewrite_html~ : Bool,
) -> Unit {
  node.set_attribute("class", @renderer.render_line_class(line, decorations))
  node.set_attribute("data-line", line.line_number.to_string())
  node.set_attribute("style", line_node_style(window_index))
  if rewrite_html {
    node.set_inner_html(@view_line_renderer.render_view_line2(input).html)
  }
}

///|
fn write_line_number_node(
  gutter : @rdom.Element,
  line : @view_model.RenderLine,
  window_index : Int,
) -> Unit {
  gutter.set_attribute("class", "line-number")
  gutter.set_attribute("data-line", line.line_number.to_string())
  gutter.set_attribute("style", line_node_style(window_index))
  gutter.set_inner_html(line.line_number.to_string())
}

///|
fn line_node_style(window_index : Int) -> String {
  "top:" +
  (window_index * editor_line_height).to_string() +
  "px;height:" +
  editor_line_height.to_string() +
  "px"
}
