///|
priv struct ContentViewOverlaysPrepared {
  frame : @view_model.RenderFrame
  viewport : @view_layout.ViewportData
  selection_view_range : @view_line_renderer.ViewRange?
  view_model : @view_model.ViewModel?
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
impl ViewPart for ContentViewOverlays with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for ContentViewOverlays with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    ViewScrollChanged(e) => e.window_changed || e.position_changed
    ViewCursorStateChanged => true
    ViewZonesChanged => true
    _ => false
  }
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
    selection_view_range: context.input.selection_view_range,
    view_model: context.input.view_model,
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
        prepared.selection_view_range,
        prepared.view_model,
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
/// `SelectionsOverlay` role driven by `RenderingContext.linesVisibleRangesForRange`.
/// The selection arrives as a view-coordinate range (already bridged from the
/// model selection through the `CoordinatesConverter`), so this stays entirely
/// in view `Position`s: each visible line contributes one rectangle per
/// measured horizontal range, lines that end a model line inside the selection
/// get an end-of-line extension, and empty lines inside the selection get a
/// stub, so multi-line selections read as continuous. There is no raw-offset
/// round-trip.
fn ContentViewOverlays::render_selection_overlays(
  self : ContentViewOverlays,
  frame : @view_model.RenderFrame,
  viewport : @view_layout.ViewportData,
  selection_view_range : @view_line_renderer.ViewRange?,
  view_model : @view_model.ViewModel?,
  space_width : Double,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> Unit {
  self.view_overlays.set_inner_html("")
  let range = match selection_view_range {
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
      view_model,
      viewport.relative_vertical_offset[index],
      space_width,
      measure,
    )
  }
}

///|
/// Appends the selection rectangles for one rendered view line, transcribing
/// the per-line body of Monaco's `viewLines.linesVisibleRangesForRange`.
/// `range` is the selection in view coordinates (one-based, local to each view
/// line). The start column applies only on the first selected line and the end
/// column only on the last; lines in between span their whole rendered width.
/// Text rectangles come from DOM measurement of that view-column range. A view
/// line that ends a model line inside the selection (a real newline, not a
/// soft-wrap continuation) gets a one-space marker past the text so the
/// included line break is visible.
fn append_line_selection_rects(
  parent : @rdom.Element,
  document : @rdom.Document,
  line : @view_model.RenderLine,
  range : @view_line_renderer.ViewRange,
  view_model : @view_model.ViewModel?,
  top : Int,
  space_width : Double,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> Unit {
  let view_line_number = line.line_number
  if view_line_number < range.start_line_number ||
    view_line_number > range.end_line_number {
    return
  }
  // `startColumn = lineNumber === range.startLineNumber ? range.startColumn : 1`
  let start_column = if view_line_number == range.start_line_number {
    range.start_column
  } else {
    1
  }
  // `continuesInNextLine = lineNumber !== originalEndLineNumber`
  let continues_in_next_line = view_line_number != range.end_line_number
  // `endColumn = continuesInNextLine ? getLineMaxColumn(lineNumber) : range.endColumn`.
  // The rendered text length is the view line's local length, so the local
  // one-based max column is `text.length() + 1`.
  let end_column = if continues_in_next_line {
    line.text.length() + 1
  } else {
    range.end_column
  }
  // `measure` consumes zero-based local view columns.
  let start_column0 = start_column - 1
  let end_column0 = end_column - 1
  // Monaco's `includeNewLines` branch: only extend past the text when this
  // view line ends a *model* line, so soft-wrap continuations stay seamless.
  let includes_newline = continues_in_next_line &&
    ends_model_line(view_model, view_line_number)
  let has_text_selection = start_column0 < end_column0
  if !has_text_selection && !includes_newline {
    return
  }
  let mut right_edge = 0.0
  let mut drew_text = false
  if has_text_selection {
    for rect in measure(view_line_number, start_column0, end_column0) {
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
      eol_anchor_x(view_line_number, start_column0, measure)
    }
    append_selection_rect(parent, document, top, left, space_width)
  }
}

///|
/// Whether `view_line_number` ends the model line it belongs to (i.e. the next
/// view line maps to a different model line). A soft-wrap continuation returns
/// `false`; a real line break returns `true`. Mirrors the model-line-boundary
/// check in `linesVisibleRangesForRange`. Without a view model, falls back to
/// the identity assumption that every view line is its own model line.
fn ends_model_line(
  view_model : @view_model.ViewModel?,
  view_line_number : Int,
) -> Bool {
  match view_model {
    Some(view_model) => {
      let lines = view_model.lines()
      if view_line_number >= lines.line_count() {
        true
      } else {
        lines.model_line_number_of_view_line(view_line_number) !=
        lines.model_line_number_of_view_line(view_line_number + 1)
      }
    }
    None => true
  }
}

///|
/// The pixel x where a selection that begins at `start_column0` (with no
/// selected text on the line) should anchor its end-of-line marker: the right
/// edge of the line's text up to that column, or `0` at the line start.
/// Columns are zero-based local view columns.
fn eol_anchor_x(
  view_line_number : Int,
  start_column0 : Int,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> Double {
  if start_column0 <= 0 {
    return 0.0
  }
  let mut edge = 0.0
  for rect in measure(view_line_number, 0, start_column0) {
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
