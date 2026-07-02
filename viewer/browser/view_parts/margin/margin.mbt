// Ported from `vscode/src/vs/editor/browser/viewParts/margin/margin.ts` (the
// line-number gutter) and the folding-marker half of
// `vscode/src/vs/editor/contrib/folding/browser/foldingDecorations.ts`. The
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
  folding_ranges : Array[@language.FoldingRange]
  folded_ranges : Array[@language.FoldingRange]
  on_toggle_fold : (Int) -> Unit
  generation : Int
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
  folding : @rdom.Element
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
  let folding = document.create_element("div")
  folding.set_attribute("class", "view-layer folding")
  folding.set_attribute("data-view-part", "folding")
  let line_numbers = document.create_element("div")
  line_numbers.set_attribute("class", "view-layer line-numbers")
  line_numbers.set_attribute("data-view-part", "line-numbers")
  margin_view_overlays.append_child(current_line.as_node())
  margin_view_overlays.append_child(folding.as_node())
  margin_view_overlays.append_child(line_numbers.as_node())
  margin.append_child(margin_view_overlays.as_node())
  {
    margin,
    current_line,
    folding,
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

///|
pub fn MarginViewOverlays::render_folding_markers(
  self : MarginViewOverlays,
  viewport : @view_layout.ViewportData,
  view_model : @view_model.ViewModel?,
  folding_ranges : Array[@language.FoldingRange],
  folded_ranges : Array[@language.FoldingRange],
  on_toggle_fold~ : (Int) -> Unit,
) -> Unit {
  self.folding.set_inner_html("")
  if folding_ranges.length() == 0 {
    return
  }
  let document = @rdom.document()
  let lines = match view_model {
    Some(model) => Some(model.lines())
    None => None
  }
  for index in 0..<viewport.lines.length() {
    let view_line_number = viewport.start_line_number + index
    let model_line_number = match lines {
      Some(view_model_lines) =>
        view_model_lines.model_line_number_of_view_line(view_line_number)
      None => view_line_number
    }
    if !@view_lines.is_first_view_line_for_model_line(lines, view_line_number) {
      continue
    }
    match
      @folding.folding_range_for_start_line(folding_ranges, model_line_number) {
      Some(_) => {
        let marker = document.create_element("button")
        let folded = @folding.is_line_folded(folded_ranges, model_line_number)
        let class_name = if folded {
          "folding-marker collapsed"
        } else {
          "folding-marker expanded"
        }
        marker.set_attribute("class", class_name)
        marker.set_attribute("type", "button")
        marker.set_attribute("data-line", model_line_number.to_string())
        marker.set_attribute("data-folded", folded.to_string())
        marker.set_attribute(
          "style",
          @view_lines.line_node_style(viewport.relative_vertical_offset[index]),
        )
        marker.set_inner_html(
          if folded {
            "<span class=\"codicon codicon-chevron-right\" aria-hidden=\"true\"></span>"
          } else {
            "<span class=\"codicon codicon-chevron-down\" aria-hidden=\"true\"></span>"
          },
        )
        marker.add_event_listener("click", event => {
          event.prevent_default()
          event.stop_propagation()
          on_toggle_fold(model_line_number)
        })
        self.folding.append_child(marker.as_node())
      }
      None => ()
    }
  }
}
