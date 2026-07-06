// Ported from `vscode/src/vs/editor/browser/viewParts/margin/margin.ts` (the
// line-number gutter). The
// `ViewPart` trait impl for `MarginViewOverlays` lives in
// `viewer/browser/view/view_part.mbt`, not here — see the exec-plan's cycle
// backlog and `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` / `prepared` directly.
pub(all) struct MarginViewOverlaysPrepared {
  frame : @view_model.RenderFrame
  viewport : @view_layout.ViewportData
  view_model : @view_model.ViewModel?
  generation : Int
  /// Viewport decorations for the line-decorations lane
  /// (`LinesDecorationsOverlay`; see `lines_decorations.mbt`).
  decorations : Array[@view_model.ViewModelDecoration]
  /// The lane width, `layoutInfo.decorationsWidth`. `0` renders no lane.
  line_decorations_width : Double
  /// Current-line margin highlight inputs (`currentLineHighlight.ts`; see
  /// `current_line_highlight.mbt`).
  cursor_view_line : Int?
  selection_is_empty : Bool
  editor_has_focus : Bool
  word_wrap : Bool
  render_line_highlight : @view_layout.RenderLineHighlight
  render_line_highlight_only_when_focus : Bool
}

///|
pub(all) struct MarginViewOverlays {
  margin : @rdom.Element
  current_line : @rdom.Element
  lines_decorations : @rdom.Element
  line_numbers : @rdom.Element
  line_number_nodes : Array[@rdom.Element]
  mut line_number_window : @view_layout.LineWindow
  mut line_number_generation : Int
  mut should_render : Bool
  mut prepared : MarginViewOverlaysPrepared?
}

///|
pub fn MarginViewOverlays::new(document : @rdom.Document) -> MarginViewOverlays {
  let margin = document.create_element("div")
  margin.set_attribute("class", "margin")
  margin.set_attribute("data-view-part", "margin")
  margin.set_attribute("aria-hidden", "true")
  let margin_view_overlays = document.create_element("div")
  margin_view_overlays.set_attribute("class", "margin-view-overlays")
  margin_view_overlays.set_attribute("data-view-part", "margin-view-overlays")
  // First margin overlay, before line numbers — Monaco registers
  // `CurrentLineMarginHighlightOverlay` first (`view.ts:225-229`).
  let current_line = document.create_element("div")
  current_line.set_attribute("class", "view-layer current-line-highlight")
  current_line.set_attribute("data-view-part", "current-line-highlight")
  // The line-decorations lane renders before line numbers, preserving
  // Monaco's margin dynamic-overlay registration order
  // (`LinesDecorationsOverlay` before `LineNumbersOverlay`, `view.ts`).
  let lines_decorations = document.create_element("div")
  lines_decorations.set_attribute("class", "view-layer lines-decorations")
  lines_decorations.set_attribute("data-view-part", "lines-decorations")
  let line_numbers = document.create_element("div")
  line_numbers.set_attribute("class", "view-layer line-numbers")
  line_numbers.set_attribute("data-view-part", "line-numbers")
  margin_view_overlays.append_child(current_line.as_node())
  margin_view_overlays.append_child(lines_decorations.as_node())
  margin_view_overlays.append_child(line_numbers.as_node())
  margin.append_child(margin_view_overlays.as_node())
  {
    margin,
    current_line,
    lines_decorations,
    line_numbers,
    line_number_nodes: [],
    line_number_window: { start: 0, end: 0 },
    line_number_generation: -1,
    should_render: true,
    prepared: None,
  }
}

///|
pub fn MarginViewOverlays::dom(self : MarginViewOverlays) -> @rdom.Element {
  self.margin
}

///|
pub fn MarginViewOverlays::render_line_numbers(
  self : MarginViewOverlays,
  frame : @view_model.RenderFrame,
  viewport : @view_layout.ViewportData,
  generation : Int,
) -> Unit {
  let target = @view_lines.viewport_window(viewport)
  let document = @rdom.document()
  if generation != self.line_number_generation {
    while self.line_number_nodes.length() > viewport.lines.length() {
      match self.line_number_nodes.pop() {
        Some(node) => self.line_numbers.remove_child(node.as_node())
        None => ()
      }
    }
    while self.line_number_nodes.length() < viewport.lines.length() {
      let node = document.create_element("div")
      self.line_numbers.append_child(node.as_node())
      self.line_number_nodes.push(node)
    }
    for index in 0..<viewport.lines.length() {
      @view_lines.write_line_number_node(
        self.line_number_nodes[index],
        frame.lines[index],
        viewport.relative_vertical_offset[index],
      )
    }
    self.line_number_generation = generation
    self.line_number_window = target
    return
  }
  if target == self.line_number_window {
    return
  }
  let previous = self.line_number_window
  let next_numbers : Array[@rdom.Element] = []
  for index in 0..<viewport.lines.length() {
    let line_index = target.start + index
    if line_index >= previous.start && line_index < previous.end {
      let node = self.line_number_nodes[line_index - previous.start]
      node.set_attribute(
        "style",
        @view_lines.line_node_style(viewport.relative_vertical_offset[index]),
      )
      next_numbers.push(node)
    } else {
      let node = document.create_element("div")
      @view_lines.write_line_number_node(
        node,
        frame.lines[index],
        viewport.relative_vertical_offset[index],
      )
      self.line_numbers.append_child(node.as_node())
      next_numbers.push(node)
    }
  }
  for line_index in previous.start..<previous.end {
    if line_index < target.start || line_index >= target.end {
      self.line_numbers.remove_child(
        self.line_number_nodes[line_index - previous.start].as_node(),
      )
    }
  }
  self.line_number_nodes.clear()
  for node in next_numbers {
    self.line_number_nodes.push(node)
  }
  self.line_number_window = target
}
