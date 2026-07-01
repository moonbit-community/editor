// Ported from `vscode/src/vs/editor/browser/viewParts/selections/selections.ts`
// (`SelectionsOverlay`) plus the base-class DOM shell from
// `vscode/src/vs/editor/browser/view/viewOverlays.ts` (`ContentViewOverlays`),
// merged into one concrete type here since selection highlighting is the
// only dynamic overlay this viewer registers. The `ViewPart` trait impl for
// `ContentViewOverlays` lives in `viewer/browser/view/view_part.mbt`, not
// here — see the exec-plan's cycle backlog and
// `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` / `prepared` directly.
pub(all) struct ContentViewOverlaysPrepared {
  frame : @view_model.RenderFrame
  viewport : @view_layout.ViewportData
  selection_view_range : @view_layout.ViewRange?
  view_model : @view_model.ViewModel?
  space_width : Double
}

///|
pub(all) struct ContentViewOverlays {
  view_overlays : @rdom.Element
  mut should_render : Bool
  mut prepared : ContentViewOverlaysPrepared?
}

///|
pub fn ContentViewOverlays::new(
  document : @rdom.Document,
) -> ContentViewOverlays {
  let view_overlays = document.create_element("div")
  view_overlays.set_attribute("class", "view-overlays")
  view_overlays.set_attribute("data-view-part", "view-overlays")
  { view_overlays, should_render: true, prepared: None }
}

///|
pub fn ContentViewOverlays::dom(self : ContentViewOverlays) -> @rdom.Element {
  self.view_overlays
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
/// `LineVisibleRangesWithStyle`, plus the line's pixel top in the overlay.
priv struct LineSelectionRanges {
  top : Int
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
/// Renders the selection highlight as DOM-measured rectangles, Monaco's
/// `SelectionsOverlay`. The selection arrives as a view-coordinate range
/// (already bridged from the model selection through the `CoordinatesConverter`),
/// so this stays entirely in view `Position`s. It collects the per-line
/// horizontal ranges (`linesVisibleRangesForRange`), enriches them with
/// rounded-corner styles (`_enrichVisibleRangesWithStyle`), then paints each
/// range with its corner radii and reverse-corner pieces
/// (`_actualRenderOneSelection`). There is one selection, so the multi-selection
/// top/bottom margins are always zero; the previous-frame corner cache (a
/// repaint optimization) is intentionally omitted.
pub fn ContentViewOverlays::render_selection_overlays(
  self : ContentViewOverlays,
  frame : @view_model.RenderFrame,
  viewport : @view_layout.ViewportData,
  selection_view_range : @view_layout.ViewRange?,
  view_model : @view_model.ViewModel?,
  space_width : Double,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> Unit {
  self.view_overlays.set_inner_html("")
  let range = match selection_view_range {
    Some(range) => range
    None => return
  }
  let lines : Array[LineSelectionRanges] = []
  for index in 0..<frame.lines.length() {
    match
      collect_line_selection_ranges(
        frame.lines[index],
        range,
        view_model,
        viewport.relative_vertical_offset[index],
        space_width,
        measure,
      ) {
      Some(line_ranges) => lines.push(line_ranges)
      None => ()
    }
  }
  // Rounded selection is always on; enrich unless a line has multiple ranges.
  let styled = !visible_ranges_have_gaps(lines)
  if styled {
    enrich_visible_ranges_with_style(lines, space_width)
  }
  let document = @rdom.document()
  for line in lines {
    render_styled_line(self.view_overlays, document, line, styled)
  }
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
  line : @view_model.RenderLine,
  range : @view_layout.ViewRange,
  view_model : @view_model.ViewModel?,
  top : Int,
  space_width : Double,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
) -> LineSelectionRanges? {
  let view_line_number = line.line_number
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
    line.text.length() + 1
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
  Some({ top, ranges })
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
/// Paints one line's styled ranges, transcribing Monaco's
/// `_actualRenderOneSelection` for the single-selection case (no top/bottom
/// margins): reverse-corner pieces first (a selection layer plus a
/// background layer with the inverse radius), then the main rectangle with its
/// outward corner radii.
fn render_styled_line(
  parent : @rdom.Element,
  document : @rdom.Document,
  line : LineSelectionRanges,
  styled : Bool,
) -> Unit {
  for range in line.ranges {
    if styled {
      if range.start_top == Intern || range.start_bottom == Intern {
        let left = range.left - rounded_piece_width
        append_selection_piece(
          parent,
          document,
          line.top,
          left,
          rounded_piece_width,
          "selected-text",
        )
        let mut class_name = "selection-corner-piece"
        if range.start_top == Intern {
          class_name = class_name + " top-right-radius"
        }
        if range.start_bottom == Intern {
          class_name = class_name + " bottom-right-radius"
        }
        append_selection_piece(
          parent,
          document,
          line.top,
          left,
          rounded_piece_width,
          class_name,
        )
      }
      if range.end_top == Intern || range.end_bottom == Intern {
        let left = range.left + range.width
        append_selection_piece(
          parent,
          document,
          line.top,
          left,
          rounded_piece_width,
          "selected-text",
        )
        let mut class_name = "selection-corner-piece"
        if range.end_top == Intern {
          class_name = class_name + " top-left-radius"
        }
        if range.end_bottom == Intern {
          class_name = class_name + " bottom-left-radius"
        }
        append_selection_piece(
          parent,
          document,
          line.top,
          left,
          rounded_piece_width,
          class_name,
        )
      }
    }
    let mut class_name = "selected-text"
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
    append_selection_piece(
      parent,
      document,
      line.top,
      range.left,
      range.width,
      class_name,
    )
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
/// Width of a reverse-corner piece, Monaco's `ROUNDED_PIECE_WIDTH`.
let rounded_piece_width = 10.0

///|
/// Appends one absolutely-positioned selection piece (a `selected-text`
/// rectangle, or a `selection-corner-piece` reverse corner) with the given
/// class names, Monaco's `_createSelectionPiece`.
fn append_selection_piece(
  parent : @rdom.Element,
  document : @rdom.Document,
  top : Int,
  left : Double,
  width : Double,
  class_name : String,
) -> Unit {
  let node = document.create_element("div")
  node.set_attribute("class", class_name)
  node.set_attribute("style", selection_rect_style(top, left, width))
  parent.append_child(node.as_node())
}

///|
fn selection_rect_style(top : Int, left : Double, width : Double) -> String {
  "top:\{top}px;left:\{left}px;width:\{width}px;height:\{@core.editor_line_height}px"
}
