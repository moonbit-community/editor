// Ported from `vscode/src/vs/editor/browser/viewParts/margin/margin.ts` (the
// line-number gutter). The
// `ViewPart` trait impl for `MarginViewOverlays` lives in
// `viewer/browser/view/view_part.mbt`, not here — see the exec-plan's cycle
// backlog and `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` directly.
pub(all) struct MarginViewOverlays {
  dom_node : @rdom.Element
  current_line : @rdom.Element
  lines_decorations : @rdom.Element
  line_numbers : @rdom.Element
  line_number_nodes : Array[@rdom.Element]
  mut line_number_window : @view_layout.LineWindow
  mut line_number_generation : Int
  mut should_render : Bool
}

///|
pub fn MarginViewOverlays::new(document : @rdom.Document) -> MarginViewOverlays {
  let dom_node = document.create_element("div")
  dom_node.set_attribute("class", "margin")
  dom_node.set_attribute("data-view-part", "margin")
  dom_node.set_attribute("aria-hidden", "true")
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
  dom_node.append_child(margin_view_overlays.as_node())
  {
    dom_node,
    current_line,
    lines_decorations,
    line_numbers,
    line_number_nodes: [],
    line_number_window: { start: 0, end: 0 },
    line_number_generation: -1,
    should_render: true,
  }
}

///|
pub fn MarginViewOverlays::get_dom_node(
  self : MarginViewOverlays,
) -> @rdom.Element {
  self.dom_node
}

///|
pub fn MarginViewOverlays::render_line_numbers(
  self : MarginViewOverlays,
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
        viewport.start_line_number + index,
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
        viewport.start_line_number + index,
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
