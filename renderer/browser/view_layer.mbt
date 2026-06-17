///|
priv struct ViewLinesPrepared {
  frame : @view_model.RenderFrame
  viewport : @view_layout.ViewportData
  decorations : Array[@decorations.Decoration]
  generation : Int
  space_width : Double
}

///|
priv struct ViewLines {
  view_lines : @rdom.Element
  mut window : @view_layout.LineWindow
  mut generation : Int
  line_nodes : Array[@rdom.Element]
  render_inputs : Array[@view_line_renderer.RenderLineInput]
  mut should_render : Bool
  mut prepared : ViewLinesPrepared?
}

///|
fn ViewLines::new(document : @rdom.Document) -> ViewLines {
  let view_lines = document.create_element("div")
  view_lines.set_attribute("class", "view-lines")
  view_lines.set_attribute("data-view-part", "view-lines")
  {
    view_lines,
    window: { start: 0, end: 0 },
    generation: -1,
    line_nodes: [],
    render_inputs: [],
    should_render: true,
    prepared: None,
  }
}

///|
fn ViewLines::dom(self : ViewLines) -> @rdom.Element {
  self.view_lines
}

///|
impl ViewPart for ViewLines with fn should_render(self, context) {
  self.should_render ||
  context.change.first_render ||
  context.change.frame_generation_changed ||
  context.change.viewport_window_changed ||
  context.change.scroll_position_changed ||
  context.change.layout_dimensions_changed ||
  context.change.gutter_width_changed ||
  context.change.glyph_width_changed ||
  context.change.decorations_changed
}

///|
impl ViewPart for ViewLines with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for ViewLines with fn on_before_render(_self, _viewport) {
  ()
}

///|
impl ViewPart for ViewLines with fn prepare_render(self, context) {
  self.prepared = Some({
    frame: context.input.frame,
    viewport: context.viewport,
    decorations: context.input.decorations,
    generation: context.input.generation,
    space_width: context.input.space_width,
  })
}

///|
impl ViewPart for ViewLines with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_text(
        prepared.frame,
        prepared.viewport,
        prepared.decorations,
        prepared.generation,
        prepared.space_width,
      )
      self.view_lines.set_attribute("style", context.content_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for ViewLines with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

///|
/// The `ViewLayer` recycler: tracks the rendered line range, splices
/// entering/leaving text line nodes, and writes `innerHTML` only on entering
/// lines. A changed content generation (new frame source or changed
/// controller decorations) rewrites every rendered line instead.
fn ViewLines::render_text(
  self : ViewLines,
  frame : @view_model.RenderFrame,
  viewport : @view_layout.ViewportData,
  decorations : Array[@decorations.Decoration],
  generation : Int,
  space_width : Double,
) -> Unit {
  let target = viewport_window(viewport)
  let document = @rdom.document()
  if generation != self.generation {
    while self.line_nodes.length() > viewport.lines.length() {
      match (self.line_nodes.pop(), self.render_inputs.pop()) {
        (Some(node), _) => self.view_lines.remove_child(node.as_node())
        _ => ()
      }
    }
    while self.line_nodes.length() < viewport.lines.length() {
      let node = document.create_element("div")
      self.view_lines.append_child(node.as_node())
      self.line_nodes.push(node)
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
        viewport.relative_vertical_offset[index],
        rewrite_html~,
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
  let next_inputs : Array[@view_line_renderer.RenderLineInput] = []
  for index in 0..<viewport.lines.length() {
    let line_index = target.start + index
    if line_index >= previous.start && line_index < previous.end {
      let node = self.line_nodes[line_index - previous.start]
      node.set_attribute(
        "style",
        line_node_style(viewport.relative_vertical_offset[index]),
      )
      next_lines.push(node)
      next_inputs.push(self.render_inputs[line_index - previous.start])
    } else {
      let node = document.create_element("div")
      let input = render_line_input_for_viewport(viewport, index, space_width)
      write_line_node(
        node,
        frame.lines[index],
        decorations,
        input,
        viewport.relative_vertical_offset[index],
        rewrite_html=true,
      )
      self.view_lines.append_child(node.as_node())
      next_lines.push(node)
      next_inputs.push(input)
    }
  }
  for line_index in previous.start..<previous.end {
    if line_index < target.start || line_index >= target.end {
      self.view_lines.remove_child(
        self.line_nodes[line_index - previous.start].as_node(),
      )
    }
  }
  self.line_nodes.clear()
  for node in next_lines {
    self.line_nodes.push(node)
  }
  self.render_inputs.clear()
  for input in next_inputs {
    self.render_inputs.push(input)
  }
  self.window = target
}

///|
fn append_line_selection_segments(
  parent : @rdom.Element,
  document : @rdom.Document,
  line : @view_model.RenderLine,
  range : @core.Range,
  top : Int,
) -> Unit {
  let model_line_start = line.model_line_start_offset()
  for span in line.spans {
    if span.injected_text_index >= 0 {
      continue
    }
    let span_start = model_line_start + span.source_start
    let span_end = model_line_start + span.source_end
    if range.intersects(Range(span_start, span_end)) {
      let start = span.start + max_int(range.start, span_start) - span_start
      let end = span.start + min_int(range.end, span_end) - span_start
      if start < end {
        let node = document.create_element("div")
        node.set_attribute("class", "selected-text")
        node.set_attribute("style", selection_segment_style(top, start, end))
        parent.append_child(node.as_node())
      }
    }
  }
}

///|
fn selection_segment_style(
  top : Int,
  start_column : Int,
  end_column : Int,
) -> String {
  "top:" +
  top.to_string() +
  "px;left:" +
  start_column.to_string() +
  "ch;width:" +
  (end_column - start_column).to_string() +
  "ch;height:" +
  editor_line_height.to_string() +
  "px"
}

///|
fn is_first_view_line_for_model_line(
  lines : @view_model.ViewModelLines?,
  view_line_number : Int,
) -> Bool {
  match lines {
    Some(view_model_lines) =>
      view_model_lines.get_view_line_min_column(view_line_number) == 1
    None => true
  }
}
