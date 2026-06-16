///|
/// The `ViewLayer` recycler: tracks the rendered line range, splices
/// entering/leaving line and line-number nodes, and writes `innerHTML`
/// only on entering lines. A changed content generation (new frame
/// source or changed controller decorations) rewrites every rendered line
/// instead.
fn Island::render_lines(
  self : Island,
  frame : @view_model.RenderFrame,
  view_model : @view_model.ViewModel?,
  layout : @view_layout.ViewLayout,
  browser_view_zones : Array[BrowserViewZone],
  decorations : Array[@decorations.Decoration],
  selection_range : @core.Range?,
  folding_ranges : Array[@language.FoldingRange],
  folded_ranges : Array[@language.FoldingRange],
  on_toggle_fold~ : (Int) -> Unit,
  generation : Int,
  space_width : Double,
) -> Unit {
  let viewport = match view_model {
    Some(model) =>
      @view_layout.ViewportData::from_view_model(
        model,
        frame_window(frame),
        line_height=editor_line_height,
        decorations~,
        layout~,
      )
    None =>
      @view_layout.ViewportData::from_render_frame(
        frame,
        line_height=editor_line_height,
        decorations~,
      )
  }
  let target = viewport_window(viewport)
  let document = @rdom.document()
  self.render_folding_markers(
    viewport,
    view_model,
    folding_ranges,
    folded_ranges,
    on_toggle_fold~,
  )
  self.render_selection_overlays(frame, viewport, selection_range)
  self.render_view_zones(browser_view_zones, viewport)
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
        viewport.relative_vertical_offset[index],
        rewrite_html~,
      )
      write_line_number_node(
        self.gutter_nodes[index],
        frame.lines[index],
        viewport.relative_vertical_offset[index],
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
      node.set_attribute(
        "style",
        line_node_style(viewport.relative_vertical_offset[index]),
      )
      next_lines.push(node)
      let gutter = self.gutter_nodes[line_index - previous.start]
      gutter.set_attribute(
        "style",
        line_node_style(viewport.relative_vertical_offset[index]),
      )
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
        viewport.relative_vertical_offset[index],
        rewrite_html=true,
      )
      self.view_lines.append_child(node.as_node())
      next_lines.push(node)
      let gutter = document.create_element("div")
      write_line_number_node(
        gutter,
        frame.lines[index],
        viewport.relative_vertical_offset[index],
      )
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

///|
fn Island::render_selection_overlays(
  self : Island,
  frame : @view_model.RenderFrame,
  viewport : @view_layout.ViewportData,
  selection_range : @core.Range?,
) -> Unit {
  self.view_overlays.set_inner_html("")
  let range = match selection_range {
    Some(range) => range
    None => return
  }
  let document = @rdom.document()
  for index in 0..<frame.lines.length() {
    let line = frame.lines[index]
    append_line_selection_segments(
      self.view_overlays,
      document,
      line,
      range,
      viewport.relative_vertical_offset[index],
    )
  }
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
fn Island::render_folding_markers(
  self : Island,
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
    if !is_first_view_line_for_model_line(lines, view_line_number) {
      continue
    }
    match folding_range_for_start_line(folding_ranges, model_line_number) {
      Some(_) => {
        let marker = document.create_element("button")
        let folded = is_line_folded(folded_ranges, model_line_number)
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
          line_node_style(viewport.relative_vertical_offset[index]),
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
