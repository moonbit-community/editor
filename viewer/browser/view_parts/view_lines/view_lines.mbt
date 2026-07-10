// Ported from `vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts`
// (`ViewLines`, the recycler) and `viewLine.ts` (the per-line render input +
// DOM write). The `ViewPart` trait impl for `ViewLines` lives in
// `viewer/browser/view/view_part.mbt`, not here — see the exec-plan's cycle
// backlog and `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` / `last_render_whitespace` directly.
pub(all) struct ViewLines {
  dom_node : @scrollbar.CachedDomNode
  lines_content : @scrollbar.CachedDomNode
  /// Monaco's `_textRangeRestingSpot` (viewLines.ts ctor): the detached node
  /// `DomReadingContext.endNode` parks DOM ranges on between reads.
  text_range_resting_spot : @rdom.Element
  mut window : @view_layout.LineWindow
  mut lines : Array[ViewLine]
  can_use_layer_hinting : Bool
  mut should_render : Bool
  // The selection and whitespace mode of the last render, the viewer analog of
  // Monaco `ViewLine`'s `_renderedViewLine.input`. They drive the selection-mode
  // re-render coupling (`onSelectionChanged`, `viewLine.ts:94-100`): a selection
  // change only invalidates the lines when whitespace is rendered under the
  // selection.
  mut last_render_whitespace : @view_layout.RenderWhitespace
}

///|
pub fn ViewLines::new(
  document : @rdom.Document,
  lines_content : @scrollbar.CachedDomNode,
) -> ViewLines {
  let dom_element = document.create_element("div")
  dom_element.set_attribute("class", "view-lines")
  dom_element.set_attribute("data-view-part", "view-lines")
  {
    dom_node: @scrollbar.CachedDomNode::new(dom_element),
    lines_content,
    text_range_resting_spot: document.create_element("div"),
    window: { start: 0, end: 0 },
    lines: [],
    can_use_layer_hinting: true,
    should_render: true,
    last_render_whitespace: None,
  }
}

///|
pub fn ViewLines::get_dom_node(self : ViewLines) -> @rdom.Element {
  self.dom_node.element()
}

///|
/// Index of a one-based view-line number within the currently rendered
/// window, or `-1` when the line is outside the window.
fn ViewLines::window_index(self : ViewLines, view_line_number : Int) -> Int {
  let index = view_line_number - self.window.start
  if index >= 0 && index < self.lines.length() {
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
    self.lines[index].mapping()
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
    self.lines[index].get_dom_node()
  }
}

///|
/// Monaco `ViewLines.renderText` (`viewLines.ts:613-677`): reconcile the
/// retained rows through the shared `ViewLayerRenderer`, size the row layer,
/// then move the single lines-content rail for both axes.
pub fn ViewLines::render_text(
  self : ViewLines,
  viewport : @view_layout.ViewportData,
  layout : @view_layout.ViewLayout,
  space_width : Double,
  can_use_halfwidth_rightwards_arrow : Bool,
  render_whitespace : @view_layout.RenderWhitespace,
  render_control_characters : Bool,
  selection_view_range : @base_common.Range?,
) -> Unit {
  let target = viewport_window(viewport)
  self.last_render_whitespace = render_whitespace
  let renderer = @view_layer.ViewLayerRenderer::new(
    self.dom_node.element(),
    () => ViewLine::new(),
    line => line.get_dom_node(),
    (line, node) => line.set_dom_node(node),
    (line, line_number, delta_top, line_height) => {
      line.layout_line(line_number, delta_top, line_height)
    },
    (line, line_number, delta_top, line_height, viewport, builder) => {
      let index = line_number - viewport.start_line_number
      let input = render_line_input_for_viewport(
        viewport,
        index,
        space_width,
        can_use_halfwidth_rightwards_arrow~,
        render_whitespace~,
        render_control_characters~,
        selection_view_range~,
      )
      line.render_line(line_number, input, delta_top, line_height, builder)
    },
    viewport,
    _line_number => viewport.line_height,
  )
  let result = renderer.render(
    {
      rend_line_number_start: self.window.start,
      lines: self.lines,
      lines_length: self.lines.length(),
    },
    viewport.start_line_number,
    viewport.end_line_number,
    viewport.relative_vertical_offset,
  )
  self.lines = result.lines
  self.window = target
  let dimensions = layout.dimensions()
  self.dom_node.set_width(Pixels(dimensions.scroll_width))
  self.dom_node.set_height(Pixels(dimensions.scroll_height.min(1000000.0)))
  self.lines_content.set_layer_hinting(self.can_use_layer_hinting)
  self.lines_content.set_contain("strict")
  let position = layout.position()
  let adjusted_scroll_top = position.scroll_top -
    viewport.big_numbers_delta.to_double()
  self.lines_content.set_top(Pixels(-adjusted_scroll_top))
  self.lines_content.set_left(Pixels(-position.scroll_left))
}

///|
/// `pub`: called cross-package by `browser/view`'s `ViewOverlays` row
/// recycler, which windows its rows the same way `ViewLines::render_text`
/// windows text lines.
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
  can_use_halfwidth_rightwards_arrow? : Bool = true,
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
    can_use_halfwidth_rightwards_arrow~,
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
/// `getPositionFromDOMInfo` (viewLines.ts:337-372): resolves a browser caret
/// answer (token span node + character offset) to a view `Position`, walking
/// the span up to its `.view-line` node, scanning the rendered window for the
/// line number, and mapping the span/offset through the line's
/// `CharacterMapping`. `view_model` is passed per call — this recycler has no
/// `ViewContext` (the port's standing deviation).
pub fn ViewLines::get_position_from_dom_info(
  self : ViewLines,
  view_model : @view_model.ViewModel,
  span_node : @rdom.Element,
  offset : Int,
) -> @base_common.Position? {
  guard get_view_line_dom_node(span_node) is Some(view_line_dom_node) else {
    // Couldn't find view line node
    return None
  }
  let line_number = self.get_line_number_for(view_line_dom_node)
  if line_number == -1 {
    // Couldn't find view line node
    return None
  }
  if line_number < 1 || line_number > view_model.line_count() {
    // lineNumber is outside range
    return None
  }
  if view_model.get_line_max_column(line_number) == 1 {
    // Line is empty
    return Some(Position(line_number, 1))
  }
  guard self.mapping_at(line_number) is Some(mapping) else {
    // Couldn't find line
    return None
  }
  let mut column = get_column_of_node_offset(mapping, span_node, offset)
  let min_column = view_model.get_line_min_column(line_number)
  if column < min_column {
    column = min_column
  }
  Some(Position(line_number, column))
}

///|
/// `_getViewLineDomNode` (viewLines.ts:375-384): the enclosing `.view-line`
/// node of a DOM node, or `None`.
fn get_view_line_dom_node(node : @rdom.Element) -> @rdom.Element? {
  for current = Some(node)
      current is Some(el)
      current = view_lines_parent_element(el) {
    if element_class_name(el) == VIEW_LINE_CLASS_NAME {
      return Some(el)
    }
  } nobreak {
    None
  }
}

///|
/// `_getLineNumberFor` (viewLines.ts:388-398): the view-line number of a
/// rendered `.view-line` node, by scanning the window; `-1` when not found.
fn ViewLines::get_line_number_for(
  self : ViewLines,
  dom_node : @rdom.Element,
) -> Int {
  for index, line in self.lines {
    if line.get_dom_node().map(node => node.is_same_node(dom_node.as_node())) ==
      Some(true) {
      return self.window.start + index
    }
  }
  -1
}

///|
/// `getLineWidth` (viewLines.ts:400-413): the rendered width of a view line
/// in pixels, `-1` when the line is outside the rendered window. The read
/// includes CSS-generated content (`::after` ellipses etc.) because it is the
/// reading target's `offsetWidth`. The source's
/// `_updateLineWidthsSlowIfDomDidLayout` piggyback (its `scrollWidth`
/// machinery) is not ported — this layout model computes scroll width from
/// line content, not DOM sweeps.
pub fn ViewLines::get_line_width(self : ViewLines, line_number : Int) -> Double {
  let index = self.window_index(line_number)
  if index < 0 {
    // Couldn't find line
    return -1.0
  }
  let context = DomReadingContext::new(
    self.dom_node.element(),
    self.text_range_resting_spot,
  )
  rendered_view_line_width(
    self.lines[index].get_dom_node().unwrap(),
    Some(context),
  )
}

///|
/// FFI gap-fills for the `.view-line` ancestor walk (element-typed
/// `parentElement` / `className` are not bound in the vendored `@rdom`).
extern "js" fn element_class_name(el : @rdom.Element) -> String =
  #| (el) => el.className || ""

///|
extern "js" fn view_lines_parent_element_raw(
  el : @rdom.Element,
) -> @rdom.Element =
  #| (el) => el.parentElement

///|
extern "js" fn has_parent_element(el : @rdom.Element) -> Bool =
  #| (el) => el.parentElement !== null && el.parentElement.nodeType === 1

///|
fn view_lines_parent_element(el : @rdom.Element) -> @rdom.Element? {
  if has_parent_element(el) {
    Some(view_lines_parent_element_raw(el))
  } else {
    None
  }
}
