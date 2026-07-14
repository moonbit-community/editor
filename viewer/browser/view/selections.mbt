// Ported from `vscode/src/vs/editor/browser/viewParts/selections/selections.ts`
// (`SelectionsOverlay`), vscode submodule commit
// b18492a288de038fbc7643aae6de8247029d11bd. The `ContentViewOverlays` rows
// shell lives with `viewer/browser/view` (`view_overlays.mbt`), mirroring
// Monaco's `viewOverlays.ts`; this package is the selection dynamic overlay
// only. Preparation is adapted at the private rendering-context boundary in
// `browser/view`.

///|
/// The package-private selection dynamic overlay state: the prepared per-line
/// HTML (`_renderResult`).
priv struct SelectionsOverlay {
  mut render_result : Array[String]
}

///|
fn SelectionsOverlay::SelectionsOverlay() -> SelectionsOverlay {
  { render_result: [] }
}

///|
/// The rounded-corner classification of a selection edge, Monaco's
/// `CornerStyle`: `Extern` rounds outward, `Intern` is a reverse (inverse)
/// corner cut into an adjacent line, `Flat` leaves a straight edge.
priv enum CornerStyle {
  Extern
  Intern
  Flat
} derive(Eq)

///|
/// One measured selection rectangle plus the corner styles of its four corners,
/// Monaco's `HorizontalRangeWithStyle`.
priv struct StyledRange {
  left : Double
  width : Double
  mut start_top : CornerStyle
  mut start_bottom : CornerStyle
  mut end_top : CornerStyle
  mut end_bottom : CornerStyle
}

///|
/// The styled selection rectangles for one view line, Monaco's
/// `LineVisibleRangesWithStyle`.
priv struct LineSelectionRanges {
  line_number : Int
  ranges : Array[StyledRange]
}

///|
fn new_styled_range(left : Double, width : Double) -> StyledRange {
  {
    left,
    width,
    start_top: Extern,
    start_bottom: Extern,
    end_top: Extern,
    end_bottom: Extern,
  }
}

///|
/// `SelectionsOverlay.prepareRender` (`selections.ts:361-390`) for the
/// viewer's single selection: collect the per-line horizontal ranges
/// (`linesVisibleRangesForRange` over the DOM caret-measurement seam), enrich
/// them with rounded-corner styles (`_enrichVisibleRangesWithStyle`), then
/// build each line's HTML with the inner-corner pieces placed before the
/// selection rectangles (`_actualRenderOneSelection`'s two buckets — issue
/// #77777's ordering). The previous-frame corner cache (a repaint
/// optimization) is intentionally omitted.
fn prepare_selections_render(
  viewport : @view_layout.ViewportData,
  selection_view_range : @base_common.Range?,
  view_model : @view_model.ViewModel?,
  space_width : Double,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> Array[String] {
  let range = match selection_view_range {
    Some(range) => range
    None =>
      // An empty selection renders nothing (`selection.isEmpty()` skip).
      return Array::make(viewport.lines.length(), "")
  }
  let lines : Array[LineSelectionRanges] = []
  for index in 0..<viewport.lines.length() {
    match
      collect_line_selection_ranges(
        viewport.start_line_number + index,
        viewport.lines[index].max_column,
        range,
        view_model,
        space_width,
        measure,
      ) {
      Some(line_ranges) => lines.push(line_ranges)
      None => ()
    }
  }
  render_selection_lines(viewport, lines, space_width)
}

///|
/// Production entrypoint for the pinned `SelectionsOverlay` query shape:
/// `RenderingContext.linesVisibleRangesForRange(selection, true)` has already
/// aggregated, rounded, and newline-extended the measured DOM ranges. This
/// package owns only styling and HTML, so the cross-package carrier is a tuple
/// of line number plus ordered `(left,width)` pairs.
fn prepare_selections_render_from_visible_ranges(
  viewport : @view_layout.ViewportData,
  visible_ranges : Array[(Int, Array[(Double, Double)])],
  space_width : Double,
) -> Array[String] {
  let lines : Array[LineSelectionRanges] = []
  for visible_line in visible_ranges {
    let ranges : Array[StyledRange] = []
    for range in visible_line.1 {
      ranges.push(new_styled_range(range.0, range.1))
    }
    if !ranges.is_empty() {
      lines.push({ line_number: visible_line.0, ranges })
    }
  }
  render_selection_lines(viewport, lines, space_width)
}

///|
fn render_selection_lines(
  viewport : @view_layout.ViewportData,
  lines : Array[LineSelectionRanges],
  space_width : Double,
) -> Array[String] {
  let inner_corners = Array::make(viewport.lines.length(), "")
  let rest_of_selection = Array::make(viewport.lines.length(), "")
  // Rounded selection is always on; enrich unless a line has multiple ranges.
  let styled = !visible_ranges_have_gaps(lines)
  if styled {
    enrich_visible_ranges_with_style(lines, space_width)
  }
  for line in lines {
    let line_index = line.line_number - viewport.start_line_number
    if line_index < 0 || line_index >= rest_of_selection.length() {
      continue
    }
    let (corner_html, selection_html) = render_styled_line_html(line, styled)
    inner_corners[line_index] = inner_corners[line_index] + corner_html
    rest_of_selection[line_index] = rest_of_selection[line_index] +
      selection_html
  }
  // `output.map(([innerCorners, rest]) => innerCorners + rest)`.
  let result : Array[String] = []
  for index in 0..<rest_of_selection.length() {
    result.push(inner_corners[index] + rest_of_selection[index])
  }
  result
}

///|
/// The styled horizontal ranges for one rendered view line, transcribing the
/// per-line body of `viewLines.linesVisibleRangesForRange`. The start column
/// applies only on the first selected line and the end column only on the last;
/// lines in between span their whole rendered width. A view line that ends a
/// model line inside the selection (a real newline, not a soft-wrap
/// continuation) has the trailing newline folded into the last range's width,
/// matching Monaco's end-of-line extension.
fn collect_line_selection_ranges(
  view_line_number : Int,
  max_column : Int,
  range : @base_common.Range,
  view_model : @view_model.ViewModel?,
  space_width : Double,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> LineSelectionRanges? {
  if view_line_number < range.start_line_number ||
    view_line_number > range.end_line_number {
    return None
  }
  let start_column = if view_line_number == range.start_line_number {
    range.start_column
  } else {
    1
  }
  let continues_in_next_line = view_line_number != range.end_line_number
  let end_column = if continues_in_next_line {
    max_column
  } else {
    range.end_column
  }
  let start_column0 = start_column - 1
  let end_column0 = end_column - 1
  let includes_newline = continues_in_next_line &&
    ends_model_line(view_model, view_line_number)
  let ranges : Array[StyledRange] = []
  if start_column0 < end_column0 {
    for rect in measure(view_line_number, start_column0, end_column0) {
      let (left, width) = rect
      ranges.push(new_styled_range(left, width))
    }
  }
  if includes_newline {
    if ranges.length() > 0 {
      let last = ranges[ranges.length() - 1]
      ranges[ranges.length() - 1] = { ..last, width: last.width + space_width }
    } else {
      let left = eol_anchor_x(view_line_number, start_column0, measure)
      ranges.push(new_styled_range(left, space_width))
    }
  }
  if ranges.length() == 0 {
    return None
  }
  Some({ line_number: view_line_number, ranges })
}

///|
/// Whether any line carries more than one range, in which case Monaco skips
/// corner enrichment (the staircase math assumes one range per line).
fn visible_ranges_have_gaps(lines : Array[LineSelectionRanges]) -> Bool {
  for line in lines {
    if line.ranges.length() > 1 {
      return true
    }
  }
  false
}

///|
/// Classifies each selection corner by comparing a line's single range to the
/// lines above and below, a transcription of Monaco's
/// `_enrichVisibleRangesWithStyle` (minus the previous-frame cache). Where edges
/// line up the corner is `Flat`, where this line is narrower the corner is
/// `Extern` (rounds outward), and where it is wider it is `Intern` (a reverse
/// corner cut into the neighbor).
fn enrich_visible_ranges_with_style(
  lines : Array[LineSelectionRanges],
  space_width : Double,
) -> Unit {
  let epsilon = space_width / 4.0
  for i in 0..<lines.length() {
    let cur = lines[i].ranges[0]
    let cur_left = cur.left
    let cur_right = cur.left + cur.width
    if i > 0 {
      let prev = lines[i - 1].ranges[0]
      let prev_left = prev.left
      let prev_right = prev.left + prev.width
      if (cur_left - prev_left).abs() < epsilon {
        cur.start_top = Flat
      } else if cur_left > prev_left {
        cur.start_top = Intern
      }
      if (cur_right - prev_right).abs() < epsilon {
        cur.end_top = Flat
      } else if prev_left < cur_right && cur_right < prev_right {
        cur.end_top = Intern
      }
    }
    if i + 1 < lines.length() {
      let next = lines[i + 1].ranges[0]
      let next_left = next.left
      let next_right = next.left + next.width
      if (cur_left - next_left).abs() < epsilon {
        cur.start_bottom = Flat
      } else if next_left < cur_left && cur_left < next_right {
        cur.start_bottom = Intern
      }
      if (cur_right - next_right).abs() < epsilon {
        cur.end_bottom = Flat
      } else if cur_right < next_right {
        cur.end_bottom = Intern
      }
    }
  }
}

///|
/// One line's `(innerCornerOutput, restOfSelectionOutput)` pair, transcribing
/// Monaco's `_actualRenderOneSelection` loop body for the single-selection
/// case (`hasMultipleSelections` false → `top`/`bottom` are `0`): reverse
/// corners are a selection layer plus an editor-background layer carrying the
/// inverse radius classes; the main rectangle carries its outward radius
/// classes.
fn render_styled_line_html(
  line : LineSelectionRanges,
  styled : Bool,
) -> (String, String) {
  let mut inner_corner_output = ""
  let mut rest_of_selection_output = ""
  for range in line.ranges {
    if styled {
      if range.start_top == Intern || range.start_bottom == Intern {
        // Reverse rounded corner to the left: first the selection (blue
        // layer), then the background (white layer) with inverse radius.
        let left = range.left - rounded_piece_width
        inner_corner_output = inner_corner_output +
          selection_piece_html(selection_class_name, left, rounded_piece_width)
        let mut class_name = editor_background_class_name
        if range.start_top == Intern {
          class_name = class_name + " top-right-radius"
        }
        if range.start_bottom == Intern {
          class_name = class_name + " bottom-right-radius"
        }
        inner_corner_output = inner_corner_output +
          selection_piece_html(class_name, left, rounded_piece_width)
      }
      if range.end_top == Intern || range.end_bottom == Intern {
        // Reverse rounded corner to the right.
        let left = range.left + range.width
        inner_corner_output = inner_corner_output +
          selection_piece_html(selection_class_name, left, rounded_piece_width)
        let mut class_name = editor_background_class_name
        if range.end_top == Intern {
          class_name = class_name + " top-left-radius"
        }
        if range.end_bottom == Intern {
          class_name = class_name + " bottom-left-radius"
        }
        inner_corner_output = inner_corner_output +
          selection_piece_html(class_name, left, rounded_piece_width)
      }
    }
    let mut class_name = selection_class_name
    if styled {
      if range.start_top == Extern {
        class_name = class_name + " top-left-radius"
      }
      if range.start_bottom == Extern {
        class_name = class_name + " bottom-left-radius"
      }
      if range.end_top == Extern {
        class_name = class_name + " top-right-radius"
      }
      if range.end_bottom == Extern {
        class_name = class_name + " bottom-right-radius"
      }
    }
    rest_of_selection_output = rest_of_selection_output +
      selection_piece_html(class_name, range.left, range.width)
  }
  (inner_corner_output, rest_of_selection_output)
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
      if view_line_number >= lines.get_view_line_count() {
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
/// `SelectionsOverlay.SELECTION_CLASS_NAME`.
let selection_class_name = "selected-text"

///|
/// `SelectionsOverlay.EDITOR_BACKGROUND_CLASS_NAME`: the reverse-corner white
/// layer's class.
let editor_background_class_name = "monaco-editor-background"

///|
/// Width of a reverse-corner piece, Monaco's `ROUNDED_PIECE_WIDTH`.
let rounded_piece_width = 10.0

///|
/// `_createSelectionPiece` (`selections.ts:258-269`); the single selection
/// makes `top`/`bottom` constantly `0`.
fn selection_piece_html(
  class_name : String,
  left : Double,
  width : Double,
) -> String {
  "<div class=\"cslr " +
  class_name +
  "\" style=\"top:0px;bottom:0px;left:" +
  left.to_string() +
  "px;width:" +
  width.to_string() +
  "px;\"></div>"
}
