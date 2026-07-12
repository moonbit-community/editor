///|
/// Inputs `Viewer` provides to `View` for one readonly browser render.
/// `pub(all)`: `Viewer::flush_render` (`view_host.mbt`, root `viewer`
/// package) builds this via a struct literal passed straight into
/// `View::render` — the foreign-method rule keeps that call out of this
/// package, so the literal construction crosses the package boundary.
pub(all) struct ViewRenderInput {
  /// The rendered 1-based half-open view-line window: exactly the lines
  /// intersecting the viewport (already clamped to the document).
  window : @view_layout.LineWindow
  view_model : @view_model.ViewModel
  layout : @view_layout.ViewLayout
  selection_view_range : @base_common.Range?
  /// The full view-space selection (anchor + active position), Monaco's
  /// `ViewCursorStateChangedEvent.selections[0]`. Unlike
  /// `selection_view_range` (which is `None` when collapsed), this carries the
  /// caret position of an empty selection — the cursor part renders from it.
  view_selection : @core.Selection?
  gutter_width : Double
  /// Width of the line-decorations lane inside the gutter,
  /// `layoutInfo.decorationsWidth` (the margin part renders the lane at
  /// `left = gutter_width - line_decorations_width`).
  line_decorations_width : Double
  space_width : Double
  /// `fontInfo.typicalFullwidthCharacterWidth`: the content-widget layer's
  /// `_reduceAnchorCoordinates` clamp unit.
  typical_fullwidth_character_width : Double
  /// Whether the editor root has DOM focus (Monaco `ViewFocusChangedEvent`
  /// state; see `Viewer.editor_has_focus`).
  editor_has_focus : Bool
  /// Whether soft wrapping is in effect (Monaco `layoutInfo.isViewportWrapping`)
  /// — gates the current-line highlight's wrapped-line pass.
  word_wrap : Bool
  /// The current-line highlight options (`renderLineHighlight` /
  /// `renderLineHighlightOnlyWhenFocus`, Monaco defaults `'line'`/`false`).
  render_line_highlight : @view_layout.RenderLineHighlight
  render_line_highlight_only_when_focus : Bool
  /// Root-class flags from Monaco's `showUnused`/`showDeprecated` editor
  /// options (`EditorClassName.compute`, `editorOptions.ts:1680-1686`).
  show_unused : Bool
  show_deprecated : Bool
}

///|
/// Read/prepare context for view parts. It owns measured viewport data and
/// derived geometry so parts can prepare without recomputing shared inputs.
priv struct RenderingContext {
  view_context : ViewContext
  input : ViewRenderInput
  view_lines : @view_lines.ViewLines
  viewport : @view_layout.ViewportData
  gutter_width : Double
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  translate_y : Double
}

///|
/// Write-phase render context for view parts — Monaco's
/// `RestrictedRenderingContext`, which carries the viewport data, scroll
/// state, and viewport decorations into `render`. The viewer's frame inputs
/// ride along as `input` (its stand-in for Monaco parts reading
/// `this._context` and event-tracked fields during render).
priv struct RestrictedRenderingContext {
  view_context : ViewContext
  input : ViewRenderInput
  viewport : @view_layout.ViewportData
  gutter_width : Double
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  translate_y : Double
  margin_transform : String
  line_height : Int
}

///|
/// Source `prepareRenderText` viewport construction. Keeping this separate
/// lets `View::render` retain the exact viewport across text rendering while
/// deferring scroll/dimension snapshots until after that write phase.
fn RenderingContext::viewport_from_input(
  input : ViewRenderInput,
) -> @view_layout.ViewportData {
  // Pulled from the view model per render pass — Monaco's `view.ts` building
  // a fresh `ViewportData` over `viewLayout.getLinesViewportData()`.
  let partial_viewport = input.layout.get_lines_viewport_data()
  @view_model.viewport_data_from_view_model(
    input.view_model,
    input.window,
    line_height=input.layout.line_height(),
    layout=input.layout,
    partial_viewport~,
  )
}

///|
/// Source post-`renderText` RenderingContext construction: reuse the prepared
/// viewport, but snapshot current layout position/dimensions only after line
/// width feedback and any synchronous scroll events have completed.
fn RenderingContext::from_viewport(
  view_context : ViewContext,
  input : ViewRenderInput,
  view_lines : @view_lines.ViewLines,
  viewport : @view_layout.ViewportData,
) -> RenderingContext {
  let current_viewport = input.layout.get_current_viewport()
  let layout_dimensions = input.layout.dimensions()
  let position : @view_layout.ScrollPosition = {
    scroll_top: current_viewport.top,
    scroll_left: current_viewport.left,
  }
  let dimensions : @view_layout.ScrollDimensions = {
    width: current_viewport.width,
    scroll_width: layout_dimensions.scroll_width,
    height: current_viewport.height,
    scroll_height: layout_dimensions.scroll_height,
  }
  {
    view_context,
    input,
    view_lines,
    viewport,
    gutter_width: input.gutter_width,
    position,
    dimensions,
    translate_y: viewport.big_numbers_delta.to_double() - position.scroll_top,
  }
}

///|
fn RenderingContext::restricted(
  self : RenderingContext,
) -> RestrictedRenderingContext {
  {
    view_context: self.view_context,
    input: self.input,
    viewport: self.viewport,
    gutter_width: self.gutter_width,
    position: self.position,
    dimensions: self.dimensions,
    translate_y: self.translate_y,
    margin_transform: self.margin_transform(),
    line_height: self.viewport.line_height,
  }
}

///|
fn RenderingContext::margin_transform(self : RenderingContext) -> String {
  "transform:translateY(" + self.translate_y.to_string() + "px)"
}

///|
/// Scoped `RestrictedRenderingContext.getVerticalOffsetForLineNumber`.
fn RenderingContext::vertical_offset_for_line(
  self : RenderingContext,
  line_number : Int,
  include_view_zones? : Bool = false,
) -> Double {
  self.input.layout.get_vertical_offset_for_line_number(
    line_number,
    include_view_zones~,
  )
}

///|
/// Scoped `RestrictedRenderingContext.getLineHeightForLineNumber`.
fn RenderingContext::line_height_for_line(
  self : RenderingContext,
  line_number : Int,
) -> Double {
  self.input.layout.get_line_height_for_line_number(line_number).to_double()
}

///|
/// Monaco `RenderingContext.visibleRangeForPosition` with the currently
/// available DOM ViewLines producer. A negative capability result is the
/// source's `null`; GPU fallback remains explicitly deferred.
fn RenderingContext::visible_range_for_position(
  self : RenderingContext,
  position : @base_common.Position,
) -> HorizontalPosition? {
  match
    self.view_lines.raw_visible_range_for_position(
      position.line_number,
      position.column,
    ) {
    Some((outside_rendered_line, left)) =>
      Some(HorizontalPosition::new(outside_rendered_line, left))
    None => None
  }
}

///|
/// Monaco `RenderingContext.linesVisibleRangesForRange`, DOM-only at this
/// approved phase. ViewLines owns DOM/range production; this facade converts
/// its cycle-free tuples into the source rendering carriers. Optional GPU
/// concatenation/sorting remains explicitly deferred.
fn RenderingContext::lines_visible_ranges_for_range(
  self : RenderingContext,
  range : @base_common.Range,
  include_new_lines : Bool,
) -> Array[LineVisibleRanges]? {
  match
    self.view_lines.raw_lines_visible_ranges_for_range(range, include_new_lines) {
    Some(raw_lines) => Some(line_visible_ranges_from_raw(raw_lines))
    None => None
  }
}

///|
/// Cycle-free tuple-carrier conversion at the ViewLines/RenderingContext
/// package boundary. Input and per-line range order are preserved exactly.
fn line_visible_ranges_from_raw(
  raw_lines : Array[(Bool, Int, Array[(Int, Int)], Bool)],
) -> Array[LineVisibleRanges] {
  let result : Array[LineVisibleRanges] = []
  for raw in raw_lines {
    let horizontal_ranges : Array[HorizontalRange] = []
    for range in raw.2 {
      horizontal_ranges.push({ left: range.0, width: range.1 })
    }
    result.push(LineVisibleRanges::new(raw.0, raw.1, horizontal_ranges, raw.3))
  }
  result
}

///|
/// Cycle-free capability projection consumed by ContentWidgets. The measured
/// `HorizontalPosition.left` is intentionally rounded before crossing the
/// package boundary, matching the source anchor arithmetic.
fn RenderingContext::content_widgets_render_context(
  self : RenderingContext,
) -> @content_widgets.ContentWidgetsRenderContext {
  {
    vertical_offset_for_line: line => self.vertical_offset_for_line(line),
    line_height_for_line: line => self.line_height_for_line(line),
    visible_range_for_position: position => {
      match self.visible_range_for_position(position) {
        Some(horizontal) => Some(horizontal.left.to_double())
        None => None
      }
    },
    typical_fullwidth_character_width: self.input.typical_fullwidth_character_width,
    scroll_top: self.position.scroll_top,
    scroll_left: self.position.scroll_left,
    viewport_width: self.dimensions.width,
    viewport_height: self.dimensions.height,
  }
}

///|
/// `HorizontalPosition` (`vscode/src/vs/editor/browser/view/renderingContext.ts:196-209`,
/// vscode submodule commit b18492a288de038fbc7643aae6de8247029d11bd): a
/// measured caret x on a rendered line. `left` is `Math.round(original_left)`.
pub(all) struct HorizontalPosition {
  outside_rendered_line : Bool
  left : Int
  original_left : Double
} derive(Eq, Debug)

///|
pub fn HorizontalPosition::new(
  outside_rendered_line : Bool,
  left : Double,
) -> HorizontalPosition {
  {
    outside_rendered_line,
    original_left: left,
    left: (left + 0.5).floor().to_int(),
  }
}

///|
/// Monaco `LineVisibleRanges`: the measured horizontal ranges owned by one
/// view line plus continuation/outside-rendered facts.
pub(all) struct LineVisibleRanges {
  outside_rendered_line : Bool
  line_number : Int
  ranges : Array[HorizontalRange]
  continues_on_next_line : Bool
} derive(Eq, Debug)

///|
pub fn LineVisibleRanges::new(
  outside_rendered_line : Bool,
  line_number : Int,
  ranges : Array[HorizontalRange],
  continues_on_next_line : Bool,
) -> LineVisibleRanges {
  { outside_rendered_line, line_number, ranges, continues_on_next_line }
}

///|
/// Smallest line number independent of input order. Ties retain the first
/// carrier, and null/empty inputs return `None`.
pub fn LineVisibleRanges::first_line(
  ranges : Array[LineVisibleRanges]?,
) -> LineVisibleRanges? {
  guard ranges is Some(ranges) else { return None }
  let mut result : LineVisibleRanges? = None
  for range in ranges {
    match result {
      Some(current) =>
        if range.line_number < current.line_number {
          result = Some(range)
        }
      None => result = Some(range)
    }
  }
  result
}

///|
/// Largest line number independent of input order. Ties retain the first
/// carrier, and null/empty inputs return `None`.
pub fn LineVisibleRanges::last_line(
  ranges : Array[LineVisibleRanges]?,
) -> LineVisibleRanges? {
  guard ranges is Some(ranges) else { return None }
  let mut result : LineVisibleRanges? = None
  for range in ranges {
    match result {
      Some(current) =>
        if range.line_number > current.line_number {
          result = Some(range)
        }
      None => result = Some(range)
    }
  }
  result
}

///|
/// Monaco `HorizontalRange`: integerized DOM geometry.
pub(all) struct HorizontalRange {
  left : Int
  width : Int
} derive(Eq, Debug)

///|
pub fn HorizontalRange::new(left : Double, width : Double) -> HorizontalRange {
  { left: js_math_round_to_int(left), width: js_math_round_to_int(width) }
}

///|
pub fn HorizontalRange::from(
  ranges : Array[FloatHorizontalRange],
) -> Array[HorizontalRange] {
  let len = ranges.length()
  let result = Array::make(len, HorizontalRange::new(0.0, 0.0))
  for index in 0..<len {
    let range = ranges[index]
    result[index] = HorizontalRange::new(range.left, range.width)
  }
  result
}

///|
pub fn HorizontalRange::to_string(self : HorizontalRange) -> String {
  "[\{self.left},\{self.width}]"
}

///|
/// Monaco `FloatHorizontalRange`: preserve fractional DOM geometry.
pub(all) struct FloatHorizontalRange {
  left : Double
  width : Double
} derive(Eq, Debug)

///|
pub fn FloatHorizontalRange::new(
  left : Double,
  width : Double,
) -> FloatHorizontalRange {
  { left, width }
}

///|
pub fn FloatHorizontalRange::to_string(self : FloatHorizontalRange) -> String {
  "[\{self.left},\{self.width}]"
}

///|
pub fn FloatHorizontalRange::compare(
  left : FloatHorizontalRange,
  right : FloatHorizontalRange,
) -> Double {
  left.left - right.left
}

///|
/// Monaco `VisibleRanges`: unrounded ranges plus their aggregate outside bit.
pub(all) struct VisibleRanges {
  outside_rendered_line : Bool
  ranges : Array[FloatHorizontalRange]
} derive(Eq, Debug)

///|
pub fn VisibleRanges::new(
  outside_rendered_line : Bool,
  ranges : Array[FloatHorizontalRange],
) -> VisibleRanges {
  { outside_rendered_line, ranges }
}

///|
fn js_math_round_to_int(value : Double) -> Int {
  (value + 0.5).floor().to_int()
}
