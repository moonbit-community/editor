// Ported from `vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts`
// (`ViewLines`, the recycler) and `viewLine.ts` (the per-line render input +
// DOM write). The `ViewPart` trait impl for `ViewLines` lives in
// `viewer/browser/view/view_part.mbt`, not here — see the exec-plan's cycle
// backlog and `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` / `prepared` / `last_render_whitespace` directly.
pub(all) struct ViewLinesPrepared {
  viewport : @view_layout.ViewportData
  generation : Int
  decorations_generation : Int
  space_width : Double
  render_whitespace : @view_layout.RenderWhitespace
  render_control_characters : Bool
  selection_view_range : @base_common.Range?
}

///|
pub(all) struct ViewLines {
  view_lines : @rdom.Element
  mut window : @view_layout.LineWindow
  mut generation : Int
  mut decorations_generation : Int
  line_nodes : Array[@rdom.Element]
  render_inputs : Array[@view_layout.RenderLineInput]
  line_mappings : Array[@view_layout.CharacterMapping]
  mut should_render : Bool
  mut prepared : ViewLinesPrepared?
  // The selection and whitespace mode of the last render, the viewer analog of
  // Monaco `ViewLine`'s `_renderedViewLine.input`. They drive the selection-mode
  // re-render coupling (`onSelectionChanged`, `viewLine.ts:94-100`): a selection
  // change only invalidates the lines when whitespace is rendered under the
  // selection.
  mut last_selection : @base_common.Range?
  mut last_render_whitespace : @view_layout.RenderWhitespace
}

///|
pub fn ViewLines::new(document : @rdom.Document) -> ViewLines {
  let view_lines = document.create_element("div")
  view_lines.set_attribute("class", "view-lines")
  view_lines.set_attribute("data-view-part", "view-lines")
  {
    view_lines,
    window: { start: 0, end: 0 },
    generation: -1,
    decorations_generation: -1,
    line_nodes: [],
    render_inputs: [],
    line_mappings: [],
    should_render: true,
    prepared: None,
    last_selection: None,
    last_render_whitespace: None,
  }
}

///|
pub fn ViewLines::dom(self : ViewLines) -> @rdom.Element {
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
pub fn ViewLines::mapping_at(
  self : ViewLines,
  view_line_number : Int,
) -> @view_layout.CharacterMapping? {
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
pub fn ViewLines::line_node_at(
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
/// The `ViewLayer` recycler: tracks the rendered line range, splices
/// entering/leaving text line nodes, and writes `innerHTML` only on entering
/// lines. A changed content generation (new view model) or decorations
/// generation (model decoration change) rewrites every rendered line instead
/// — the per-line `previous != input` diff then limits the actual HTML
/// writes to lines whose rendered input changed.
pub fn ViewLines::render_text(
  self : ViewLines,
  viewport : @view_layout.ViewportData,
  generation : Int,
  decorations_generation : Int,
  space_width : Double,
  render_whitespace : @view_layout.RenderWhitespace,
  render_control_characters : Bool,
  selection_view_range : @base_common.Range?,
) -> Unit {
  let target = viewport_window(viewport)
  let document = @rdom.document()
  // In `Selection` mode the per-line input depends on the selection, so a
  // selection change must rewrite the affected lines even when the generation
  // and window are unchanged (`viewLine.ts:94-100` `onSelectionChanged`). The
  // `previous != input` diff inside the full-rewrite branch then limits the
  // actual HTML writes to lines whose selected columns changed.
  let selection_invalidated = render_whitespace == Selection &&
    selection_view_range != self.last_selection
  self.last_selection = selection_view_range
  self.last_render_whitespace = render_whitespace
  if generation != self.generation ||
    decorations_generation != self.decorations_generation ||
    selection_invalidated {
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
      let input = render_line_input_for_viewport(
        viewport,
        index,
        space_width,
        render_whitespace~,
        render_control_characters~,
        selection_view_range~,
      )
      let rewrite_html = match previous_inputs.get(index) {
        Some(previous) => previous != input
        None => true
      }
      let mapping = write_line_node(
        self.line_nodes[index],
        viewport.start_line_number + index,
        input,
        viewport.relative_vertical_offset[index],
        rewrite_html~,
      )
      self.render_inputs.push(input)
      // `None` only when `!rewrite_html`, which only happens when the line was
      // present last render with the same input — so its mapping is unchanged.
      self.line_mappings.push(
        resolve_line_mapping(mapping, previous_mappings.get(index)),
      )
    }
    self.generation = generation
    self.decorations_generation = decorations_generation
    self.window = target
    return
  }
  if target == self.window {
    return
  }
  let previous = self.window
  let next_lines : Array[@rdom.Element] = []
  let next_inputs : Array[@view_layout.RenderLineInput] = []
  let next_mappings : Array[@view_layout.CharacterMapping] = []
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
      let input = render_line_input_for_viewport(
        viewport,
        index,
        space_width,
        render_whitespace~,
        render_control_characters~,
        selection_view_range~,
      )
      let mapping = write_line_node(
        node,
        viewport.start_line_number + index,
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
  fresh : @view_layout.CharacterMapping?,
  previous : @view_layout.CharacterMapping?,
) -> @view_layout.CharacterMapping {
  match (fresh, previous) {
    (Some(mapping), _) => mapping
    (None, Some(mapping)) => mapping
    (None, None) => @view_layout.CharacterMapping::new(0)
  }
}

///|
/// `pub`: called cross-package by `margin.mbt`'s line-number gutter render,
/// which recycles its nodes the same way `ViewLines::render_text` does.
pub fn viewport_window(
  viewport : @view_layout.ViewportData,
) -> @view_layout.LineWindow {
  // ViewportData is a 1-based inclusive range `[start, end]`; the render window
  // is the equivalent 1-based half-open `[start, end + 1)`.
  { start: viewport.start_line_number, end: viewport.end_line_number + 1 }
}

///|
/// `pub`: also called directly by `render_whitespace_options_test.mbt`'s
/// (root `viewer` package) integration test proving `ViewerOptions` flow into
/// the per-line render input, the same wiring `flush_render` performs.
pub fn render_line_input_for_viewport(
  viewport : @view_layout.ViewportData,
  index : Int,
  space_width : Double,
  render_whitespace~ : @view_layout.RenderWhitespace,
  render_control_characters~ : Bool,
  selection_view_range~ : @base_common.Range?,
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
  selection_view_range : @base_common.Range?,
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
  line_number : Int,
  input : @view_layout.RenderLineInput,
  top : Int,
  rewrite_html~ : Bool,
) -> @view_layout.CharacterMapping? {
  node.set_attribute("class", @viewer_common.render_line_class())
  node.set_attribute("data-line", line_number.to_string())
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
/// `pub`: called cross-package by `margin.mbt`'s line-number gutter render.
pub fn write_line_number_node(
  gutter : @rdom.Element,
  line_number : Int,
  top : Int,
) -> Unit {
  gutter.set_attribute("class", "line-number")
  gutter.set_attribute("data-line", line_number.to_string())
  gutter.set_attribute("style", line_node_style(top))
  gutter.set_inner_html(line_number.to_string())
}

///|
/// `pub`: called cross-package by `margin.mbt`'s line-number render
/// (which positions its nodes the same way `ViewLines` positions text
/// lines).
pub fn line_node_style(top : Int) -> String {
  "top:" +
  top.to_string() +
  "px;height:" +
  @core.editor_line_height.to_string() +
  "px"
}
