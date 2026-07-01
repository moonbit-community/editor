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
  render_whitespace~ : @view_layout.RenderWhitespace,
  render_control_characters~ : Bool,
  selection_view_range~ : @view_layout.ViewRange?,
) -> @view_layout.RenderLineInput {
  let line_number = viewport.start_line_number + index
  let line_data = viewport.lines[index]
  @view_layout.RenderLineInput::from_view_line(
    line_data,
    line_decorations=viewport.decorations_for_line(line_number),
    space_width~,
    render_whitespace~,
    render_control_characters~,
    selections_on_line=selections_on_line_for(
      line_number, line_data, render_whitespace, selection_view_range,
    ),
    vertical_scrollbar_size=@core.editor_vertical_scrollbar_size,
  )
}

///|
/// Per-line selected-column offsets for `RenderWhitespace::Selection`, the port
/// of `viewLine.ts:122-149`. The whitespace renderer only paints dots inside a
/// selection in this mode, so it needs the columns the selection covers on this
/// line. Empty in every other mode and when the selection misses the line.
///
/// Deviations from the source: the high-contrast `inline-selected-text` push
/// (`viewLine.ts:137-139`) is dropped — the viewer has no high-contrast theme,
/// so the gather condition reduces to `render_whitespace == Selection`; and the
/// viewer carries a single `selection_view_range`, not Monaco's `selections`
/// array, so the loop is over zero-or-one selection.
fn selections_on_line_for(
  line_number : Int,
  line_data : @view_layout.ViewLineRenderingData,
  render_whitespace : @view_layout.RenderWhitespace,
  selection_view_range : @view_layout.ViewRange?,
) -> Array[@base_common.OffsetRange] {
  let result : Array[@base_common.OffsetRange] = []
  guard render_whitespace == Selection else { return result }
  guard selection_view_range is Some(selection) else { return result }
  // Selection does not intersect this line.
  if selection.end_line_number < line_number ||
    selection.start_line_number > line_number {
    return result
  }
  // On a non-anchor line the selection spans the line's full column extent;
  // only the anchor lines clip to the selection's own start/end column.
  let start_column = if selection.start_line_number == line_number {
    selection.start_column
  } else {
    line_data.min_column
  }
  let end_column = if selection.end_line_number == line_number {
    selection.end_column
  } else {
    line_data.max_column
  }
  if start_column < end_column {
    result.push(OffsetRange(start_column - 1, end_column - 1))
  }
  result
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
  input : @view_layout.RenderLineInput,
  top : Int,
  rewrite_html~ : Bool,
) -> @view_layout.CharacterMapping? {
  node.set_attribute(
    "class",
    @viewer_common.render_line_class(line, view_decorations),
  )
  node.set_attribute("data-line", line.line_number.to_string())
  node.set_attribute("style", line_node_style(top))
  if rewrite_html {
    let output = @view_layout.render_view_line2(input)
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
  @core.editor_line_height.to_string() +
  "px"
}
