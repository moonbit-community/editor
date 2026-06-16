///|
/// The `ViewLayer` recycler: tracks the rendered line range, splices
/// entering/leaving line and line-number nodes, and writes `innerHTML`
/// only on entering lines. A changed content generation (new frame
/// source or changed controller decorations) rewrites every rendered line
/// instead.
fn Island::render_lines(
  self : Island,
  frame : @renderer.RenderFrame,
  view_model : @renderer.ViewModel?,
  decorations : Array[@decorations.Decoration],
  generation : Int,
  space_width : Double,
) -> Unit {
  let viewport = match view_model {
    Some(model) =>
      @renderer.ViewportData::from_view_model(
        model,
        frame_window(frame),
        line_height=editor_line_height,
        decorations~,
      )
    None =>
      @renderer.ViewportData::from_render_frame(
        frame,
        line_height=editor_line_height,
        decorations~,
      )
  }
  let target = viewport_window(viewport)
  let document = @rdom.document()
  if generation != self.generation {
    while self.line_nodes.length() > viewport.lines.length() {
      match
        (
          self.line_nodes.pop(),
          self.gutter_nodes.pop(),
          self.render_inputs.pop(),
        ) {
        (Some(node), Some(gutter), _) => {
          self.view_lines.remove_child(node.as_node())
          self.line_numbers.remove_child(gutter.as_node())
        }
        _ => ()
      }
    }
    while self.line_nodes.length() < viewport.lines.length() {
      let node = document.create_element("div")
      self.view_lines.append_child(node.as_node())
      self.line_nodes.push(node)
      let gutter = document.create_element("div")
      self.line_numbers.append_child(gutter.as_node())
      self.gutter_nodes.push(gutter)
    }
    let previous_inputs = self.render_inputs.copy()
    self.render_inputs.clear()
    for index in 0..<viewport.lines.length() {
      let input = render_line_input_for_viewport(viewport, index, space_width)
      let rewrite_html = match previous_inputs.get(index) {
        Some(previous) => previous != input
        None => true
      }
      write_line_node(
        self.line_nodes[index],
        frame.lines[index],
        decorations,
        input,
        index,
        rewrite_html~,
      )
      write_line_number_node(
        self.gutter_nodes[index],
        frame.lines[index],
        index,
      )
      self.render_inputs.push(input)
    }
    self.generation = generation
    self.window = target
    return
  }
  if target == self.window {
    return
  }
  let previous = self.window
  let next_lines : Array[@rdom.Element] = []
  let next_gutters : Array[@rdom.Element] = []
  let next_inputs : Array[@view_line_renderer.RenderLineInput] = []
  for index in 0..<viewport.lines.length() {
    let line_index = target.start + index
    if line_index >= previous.start && line_index < previous.end {
      // Retained line: only its window-relative top moves.
      let node = self.line_nodes[line_index - previous.start]
      node.set_attribute("style", line_node_style(index))
      next_lines.push(node)
      let gutter = self.gutter_nodes[line_index - previous.start]
      gutter.set_attribute("style", line_node_style(index))
      next_gutters.push(gutter)
      next_inputs.push(self.render_inputs[line_index - previous.start])
    } else {
      let node = document.create_element("div")
      let input = render_line_input_for_viewport(viewport, index, space_width)
      write_line_node(
        node,
        frame.lines[index],
        decorations,
        input,
        index,
        rewrite_html=true,
      )
      self.view_lines.append_child(node.as_node())
      next_lines.push(node)
      let gutter = document.create_element("div")
      write_line_number_node(gutter, frame.lines[index], index)
      self.line_numbers.append_child(gutter.as_node())
      next_gutters.push(gutter)
      next_inputs.push(input)
    }
  }
  for line_index in previous.start..<previous.end {
    if line_index < target.start || line_index >= target.end {
      self.view_lines.remove_child(
        self.line_nodes[line_index - previous.start].as_node(),
      )
      self.line_numbers.remove_child(
        self.gutter_nodes[line_index - previous.start].as_node(),
      )
    }
  }
  self.line_nodes.clear()
  for node in next_lines {
    self.line_nodes.push(node)
  }
  self.gutter_nodes.clear()
  for gutter in next_gutters {
    self.gutter_nodes.push(gutter)
  }
  self.render_inputs.clear()
  for input in next_inputs {
    self.render_inputs.push(input)
  }
  self.window = target
}
