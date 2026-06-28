///|
priv struct ViewLinesPrepared {
  frame : @view_model.RenderFrame
  viewport : @view_layout.ViewportData
  view_decorations : Array[@view_model.ViewModelDecoration]
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
  line_mappings : Array[@view_line_renderer.CharacterMapping]
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
    line_mappings: [],
    should_render: true,
    prepared: None,
  }
}

///|
fn ViewLines::dom(self : ViewLines) -> @rdom.Element {
  self.view_lines
}

///|
/// Index of a one-based view-line number within the currently rendered
/// window, or `-1` when the line is outside the window.
fn ViewLines::window_index(self : ViewLines, view_line_number : Int) -> Int {
  let index = view_line_number - self.window.start
  if index >= 0 && index < self.line_nodes.length() {
    index
  } else {
    -1
  }
}

///|
/// The retained column-to-DOM `CharacterMapping` for a one-based view-line
/// number, if in window.
fn ViewLines::mapping_at(
  self : ViewLines,
  view_line_number : Int,
) -> @view_line_renderer.CharacterMapping? {
  let index = self.window_index(view_line_number)
  if index < 0 {
    None
  } else {
    Some(self.line_mappings[index])
  }
}

///|
/// The rendered line node for a one-based view-line number, if in window. Used
/// by selection measurement to read DOM client rects off the live line DOM.
fn ViewLines::line_node_at(
  self : ViewLines,
  view_line_number : Int,
) -> @rdom.Element? {
  let index = self.window_index(view_line_number)
  if index < 0 {
    None
  } else {
    Some(self.line_nodes[index])
  }
}

///|
impl ViewPart for ViewLines with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for ViewLines with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    // Line content, tokens, and decorations are regenerated together.
    ViewLinesChanged => true
    ViewScrollChanged(e) =>
      e.window_changed || e.position_changed || e.dimensions_changed
    ViewConfigurationChanged(e) => e.gutter_width_changed || e.font_changed
    _ => false
  }
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
  // The line node's own class carries current-line decorations; convert the
  // controller decorations to view coordinates so the class test stays in
  // view `Position`s like the inline path.
  let view_decorations = match context.input.view_model {
    Some(view_model) =>
      view_model.decorations().to_view_decorations(context.input.decorations)
    None => []
  }
  self.prepared = Some({
    frame: context.input.frame,
    viewport: context.viewport,
    view_decorations,
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
        prepared.view_decorations,
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
  view_decorations : Array[@view_model.ViewModelDecoration],
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
    let previous_mappings = self.line_mappings.copy()
    self.render_inputs.clear()
    self.line_mappings.clear()
    for index in 0..<viewport.lines.length() {
      let input = render_line_input_for_viewport(viewport, index, space_width)
      let rewrite_html = match previous_inputs.get(index) {
        Some(previous) => previous != input
        None => true
      }
      let mapping = write_line_node(
        self.line_nodes[index],
        frame.lines[index],
        view_decorations,
        input,
        viewport.relative_vertical_offset[index],
        rewrite_html~,
      )
      self.render_inputs.push(input)
      // `None` only when `!rewrite_html`, which only happens when the line was
      // present last frame with the same input — so its mapping is unchanged.
      self.line_mappings.push(
        resolve_line_mapping(mapping, previous_mappings.get(index)),
      )
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
  let next_mappings : Array[@view_line_renderer.CharacterMapping] = []
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
      next_mappings.push(self.line_mappings[line_index - previous.start])
    } else {
      let node = document.create_element("div")
      let input = render_line_input_for_viewport(viewport, index, space_width)
      let mapping = write_line_node(
        node,
        frame.lines[index],
        view_decorations,
        input,
        viewport.relative_vertical_offset[index],
        rewrite_html=true,
      )
      self.view_lines.append_child(node.as_node())
      next_lines.push(node)
      next_inputs.push(input)
      next_mappings.push(resolve_line_mapping(mapping, None))
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
  self.line_mappings.clear()
  for mapping in next_mappings {
    self.line_mappings.push(mapping)
  }
  self.window = target
}

///|
/// Resolves the mapping to store for a line: the freshly rendered one when the
/// HTML was rewritten, otherwise the carried-over previous mapping. The empty
/// fallback only occurs on a logic error (no fresh and no previous mapping).
fn resolve_line_mapping(
  fresh : @view_line_renderer.CharacterMapping?,
  previous : @view_line_renderer.CharacterMapping?,
) -> @view_line_renderer.CharacterMapping {
  match (fresh, previous) {
    (Some(mapping), _) => mapping
    (None, Some(mapping)) => mapping
    (None, None) => @view_line_renderer.CharacterMapping::new(0)
  }
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
