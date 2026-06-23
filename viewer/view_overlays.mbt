///|
priv struct ContentViewOverlaysPrepared {
  frame : @view_model.RenderFrame
  viewport : @view_layout.ViewportData
  selection_range : @base_common.Range?
  space_width : Double
}

///|
priv struct ContentViewOverlays {
  view_overlays : @rdom.Element
  mut should_render : Bool
  mut prepared : ContentViewOverlaysPrepared?
}

///|
fn ContentViewOverlays::new(document : @rdom.Document) -> ContentViewOverlays {
  let view_overlays = document.create_element("div")
  view_overlays.set_attribute("class", "view-overlays")
  view_overlays.set_attribute("data-view-part", "view-overlays")
  { view_overlays, should_render: true, prepared: None }
}

///|
fn ContentViewOverlays::dom(self : ContentViewOverlays) -> @rdom.Element {
  self.view_overlays
}

///|
impl ViewPart for ContentViewOverlays with fn should_render(self, context) {
  self.should_render ||
  context.change.first_render ||
  context.change.frame_generation_changed ||
  context.change.viewport_window_changed ||
  context.change.scroll_position_changed ||
  context.change.selection_changed ||
  context.change.view_zones_changed
}

///|
impl ViewPart for ContentViewOverlays with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for ContentViewOverlays with fn on_before_render(_self, _viewport) {
  ()
}

///|
impl ViewPart for ContentViewOverlays with fn prepare_render(self, context) {
  self.prepared = Some({
    frame: context.input.frame,
    viewport: context.viewport,
    selection_range: context.input.selection_range,
    space_width: context.input.space_width,
  })
}

///|
impl ViewPart for ContentViewOverlays with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_selection_overlays(
        prepared.frame,
        prepared.viewport,
        prepared.selection_range,
        prepared.space_width,
        context.view_context.measure_line_selection,
      )
      self.view_overlays.set_attribute("style", context.content_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for ContentViewOverlays with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

///|
/// Renders the selection highlight as DOM-measured rectangles, Monaco's
/// `SelectionsOverlay` role. Each visible line in the selection contributes one
/// rectangle per measured horizontal range (no per-token seams); lines whose
/// trailing newline is selected get a small end-of-line extension, and empty
/// lines inside the selection get a stub, so multi-line selections read as
/// continuous.
fn ContentViewOverlays::render_selection_overlays(
  self : ContentViewOverlays,
  frame : @view_model.RenderFrame,
  viewport : @view_layout.ViewportData,
  selection_range : @base_common.Range?,
  space_width : Double,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> Unit {
  self.view_overlays.set_inner_html("")
  let range = match selection_range {
    Some(range) => range
    None => return
  }
  let document = @rdom.document()
  for index in 0..<frame.lines.length() {
    append_line_selection_rects(
      self.view_overlays,
      document,
      frame.lines[index],
      range,
      viewport.relative_vertical_offset[index],
      space_width,
      measure,
    )
  }
}

///|
/// Appends the selection rectangles for one rendered view line. Text rectangles
/// come from DOM measurement of the clipped column range; a selected trailing
/// newline adds a one-space marker past the text so the included line break is
/// visible.
fn append_line_selection_rects(
  parent : @rdom.Element,
  document : @rdom.Document,
  line : @view_model.RenderLine,
  range : @base_common.Range,
  top : Int,
  space_width : Double,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> Unit {
  let model_line_start = line.model_line_start_offset()
  let model_line_end = line.source_offset_at_column(line.text.length())
  let text_sel_start = max_int(range.start, model_line_start)
  let text_sel_end = min_int(range.end, model_line_end)
  let has_text_selection = text_sel_start < text_sel_end
  // The trailing newline occupies [model_line_end, model_line_end + 1); a
  // selection reaching into it marks this line's end-of-line as selected. The
  // document's last line has no newline, so this stays false there.
  let includes_newline = range.start <= model_line_end &&
    range.end > model_line_end
  if !has_text_selection && !includes_newline {
    return
  }
  let mut right_edge = 0.0
  let mut drew_text = false
  if has_text_selection {
    let start_column = line.view_column_at_source_offset(text_sel_start)
    let end_column = line.view_column_at_source_offset(text_sel_end)
    for rect in measure(line.line_number, start_column, end_column) {
      let (left, width) = rect
      append_selection_rect(parent, document, top, left, width)
      let edge = left + width
      if edge > right_edge {
        right_edge = edge
      }
      drew_text = true
    }
  }
  if includes_newline {
    let left = if drew_text {
      right_edge
    } else {
      let start_column = line.view_column_at_source_offset(text_sel_start)
      eol_anchor_x(line, start_column, measure)
    }
    append_selection_rect(parent, document, top, left, space_width)
  }
}

///|
/// The pixel x where a selection that begins at `start_column` (with no
/// selected text on the line) should anchor its end-of-line marker: the right
/// edge of the line's text up to that column, or `0` at the line start.
fn eol_anchor_x(
  line : @view_model.RenderLine,
  start_column : Int,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> Double {
  if start_column <= 0 {
    return 0.0
  }
  let mut edge = 0.0
  for rect in measure(line.line_number, 0, start_column) {
    let (left, width) = rect
    let candidate = left + width
    if candidate > edge {
      edge = candidate
    }
  }
  edge
}

///|
fn append_selection_rect(
  parent : @rdom.Element,
  document : @rdom.Document,
  top : Int,
  left : Double,
  width : Double,
) -> Unit {
  let node = document.create_element("div")
  node.set_attribute("class", "selected-text")
  node.set_attribute("style", selection_rect_style(top, left, width))
  parent.append_child(node.as_node())
}

///|
fn selection_rect_style(top : Int, left : Double, width : Double) -> String {
  "top:\{top}px;left:\{left}px;width:\{width}px;height:\{editor_line_height}px"
}
