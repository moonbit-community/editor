// Ported from `vscode/src/vs/editor/browser/viewParts/decorations/decorations.ts`
// (`DecorationsOverlay`), vscode submodule commit
// 294fb350837dbaee37b949533fead4df4e0e8971. Registered in this package's
// `ContentViewOverlays` merge after the current-line and selection pieces —
// Monaco's dynamic-overlay registration order (`view.ts:218-221`:
// CurrentLine, Selections, [IndentGuides — unported], Decorations).
//
// Deviations (decoration plan 7-8):
// - Flat overlay pieces: absolutely positioned divs appended to the shared
//   overlay container (the selections/current-line precedent) instead of
//   Monaco's per-line container HTML strings; the per-line piece computation
//   is the pure transcription below and unit-testable headlessly.
// - `linesVisibleRangesForRange` reuses the DOM caret-measurement seam
//   (`measure_line_decorations`, `keep_empty=true` so a collapsed range
//   yields its zero-width caret rect) — Monaco reads the same geometry from
//   its rendered lines.
// - The `className === 'findMatch'` special-case second argument of
//   `linesVisibleRangesForRange` toggles Monaco's include-new-lines
//   measurement; no find feature exists here, so it is dropped.

///|
/// One absolutely positioned decoration piece (`<div class="cdr {className}">`),
/// positioned at `top`/`left` with either a pixel width or `width:100%`.
pub(all) struct DecorationOverlayPiece {
  line_index : Int
  class_name : String
  left : Double
  /// `None` renders `width:100%` (whole-line pieces and the
  /// `shouldFillLineOnLineBreak` expansion).
  width : Double?
} derive(Eq, Debug)

///|
/// `prepareRender`'s filter + sort (`decorations.ts:67-113`): keep only
/// decorations with a `className`, then order by zIndex, className (JS `<`,
/// i.e. code-unit lexicographic), and range starts.
fn filter_and_sort_overlay_decorations(
  decorations : Array[@view_model.ViewModelDecoration],
) -> Array[@view_model.ViewModelDecoration] {
  // Keep only decorations with `className`
  let result = decorations.filter(d => d.options.class_name != "")

  // Sort decorations for consistent render output
  result.sort_by((a, b) => {
    if a.options.z_index < b.options.z_index {
      return -1
    }
    if a.options.z_index > b.options.z_index {
      return 1
    }
    let class_cmp = code_unit_compare(
      a.options.class_name,
      b.options.class_name,
    )
    if class_cmp != 0 {
      return class_cmp
    }
    @base_common.Range::compare_ranges_using_starts(a.range, b.range)
  })
  result
}

///|
/// JS `<`/`>` string order: lexicographic by UTF-16 code unit (MoonBit's
/// `String::compare` is length-first, so compare code units explicitly).
fn code_unit_compare(left : String, right : String) -> Int {
  let min_len = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<min_len {
    let l = left[i].to_int()
    let r = right[i].to_int()
    if l != r {
      return l - r
    }
  }
  left.length() - right.length()
}

///|
/// The pure piece computation of `prepareRender` (`decorations.ts:67-113`):
/// whole-line pieces first, then the merged normal pieces.
pub fn compute_decoration_overlay_pieces(
  decorations : Array[@view_model.ViewModelDecoration],
  visible_start_line_number : Int,
  visible_end_line_number : Int,
  get_line_max_column : (Int) -> Int,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
  typical_half_width : Double,
) -> Array[DecorationOverlayPiece] {
  let sorted = filter_and_sort_overlay_decorations(decorations)
  let output : Array[DecorationOverlayPiece] = []
  // Render first whole line decorations and then regular decorations
  render_whole_line_decorations(
    sorted, visible_start_line_number, visible_end_line_number, output,
  )
  render_normal_decorations(
    sorted, visible_start_line_number, visible_end_line_number, get_line_max_column,
    measure, typical_half_width, output,
  )
  output
}

///|
/// `_renderWholeLineDecorations` (`decorations.ts:115-139`).
fn render_whole_line_decorations(
  decorations : Array[@view_model.ViewModelDecoration],
  visible_start_line_number : Int,
  visible_end_line_number : Int,
  output : Array[DecorationOverlayPiece],
) -> Unit {
  for d in decorations {
    if !d.options.is_whole_line {
      continue
    }
    let start_line_number = if d.range.start_line_number >
      visible_start_line_number {
      d.range.start_line_number
    } else {
      visible_start_line_number
    }
    let end_line_number = if d.range.end_line_number < visible_end_line_number {
      d.range.end_line_number
    } else {
      visible_end_line_number
    }
    for j in start_line_number..<=end_line_number {
      output.push({
        line_index: j - visible_start_line_number,
        class_name: d.options.class_name,
        left: 0.0,
        width: None,
      })
    }
  }
}

///|
/// `_renderNormalDecorations` (`decorations.ts:141-184`): the same-class
/// touching-range merge loop with the `showIfCollapsed` endColumn-1 pullback.
fn render_normal_decorations(
  decorations : Array[@view_model.ViewModelDecoration],
  visible_start_line_number : Int,
  visible_end_line_number : Int,
  get_line_max_column : (Int) -> Int,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
  typical_half_width : Double,
  output : Array[DecorationOverlayPiece],
) -> Unit {
  let mut prev_class_name : String? = None
  let mut prev_show_if_collapsed = false
  let mut prev_range : @base_common.Range? = None
  let mut prev_should_fill_line_on_line_break = false
  for d in decorations {
    if d.options.is_whole_line {
      continue
    }
    let class_name = d.options.class_name
    let show_if_collapsed = d.options.show_if_collapsed
    let mut range = d.range
    if show_if_collapsed &&
      range.end_column == 1 &&
      range.end_line_number != range.start_line_number {
      range = Range(
        range.start_line_number,
        range.start_column,
        range.end_line_number - 1,
        get_line_max_column(range.end_line_number - 1),
      )
    }
    if prev_class_name == Some(class_name) &&
      prev_show_if_collapsed == show_if_collapsed &&
      @base_common.Range::are_intersecting_or_touching(
        prev_range.unwrap(),
        range,
      ) {
      // merge into previous decoration
      prev_range = Some(
        @base_common.Range::plus_range(prev_range.unwrap(), range),
      )
      continue
    }

    // flush previous decoration
    if prev_class_name is Some(flush_class_name) {
      render_normal_decoration(
        prev_range.unwrap(),
        flush_class_name,
        prev_should_fill_line_on_line_break,
        prev_show_if_collapsed,
        visible_start_line_number,
        visible_end_line_number,
        get_line_max_column,
        measure,
        typical_half_width,
        output,
      )
    }
    prev_class_name = Some(class_name)
    prev_show_if_collapsed = show_if_collapsed
    prev_range = Some(range)
    prev_should_fill_line_on_line_break = d.options.should_fill_line_on_line_break
  }
  if prev_class_name is Some(flush_class_name) {
    render_normal_decoration(
      prev_range.unwrap(),
      flush_class_name,
      prev_should_fill_line_on_line_break,
      prev_show_if_collapsed,
      visible_start_line_number,
      visible_end_line_number,
      get_line_max_column,
      measure,
      typical_half_width,
      output,
    )
  }
}

///|
/// `_renderNormalDecoration` (`decorations.ts:186-228`): measure the range's
/// per-line rects, widen a collapsed/very-small single rect to a centered
/// half-width, and expand to `width:100%` for `shouldFillLineOnLineBreak`
/// when the range continues on the next line.
fn render_normal_decoration(
  range : @base_common.Range,
  class_name : String,
  should_fill_line_on_line_break : Bool,
  show_if_collapsed : Bool,
  visible_start_line_number : Int,
  visible_end_line_number : Int,
  get_line_max_column_local : (Int) -> Int,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
  typical_half_width : Double,
  output : Array[DecorationOverlayPiece],
) -> Unit {
  // `linesVisibleRangesForRange` over the measurement seam (header
  // deviation): per visible line of the range, the DOM rects of its
  // zero-based column span; a line outside the rendered window yields no
  // rects (`outsideRenderedLine`).
  let start_line_number = if range.start_line_number > visible_start_line_number {
    range.start_line_number
  } else {
    visible_start_line_number
  }
  let end_line_number = if range.end_line_number < visible_end_line_number {
    range.end_line_number
  } else {
    visible_end_line_number
  }
  for line_number in start_line_number..<=end_line_number {
    let line_index = line_number - visible_start_line_number
    let start_column = if line_number == range.start_line_number {
      range.start_column
    } else {
      1
    }
    let continues_on_next_line = line_number != range.end_line_number
    // Lines before the range's last line span to their max column (Monaco
    // measures through the line's rendered spans).
    let end_column = if continues_on_next_line {
      get_line_max_column_local(line_number)
    } else {
      range.end_column
    }
    let ranges = measure(line_number, start_column - 1, end_column - 1)
    if ranges.length() == 0 {
      continue
    }
    let mut widened_first : (Double, Double)? = None
    if show_if_collapsed && ranges.length() == 1 {
      let (left, width) = ranges[0]
      if width < typical_half_width {
        // collapsed/very small range case => make the decoration visible by
        // expanding its width; expand its size on both sides (both to the
        // left and to the right, keeping it centered). `Math.round` is
        // half-up on positives: `floor(x + 0.5)`.
        let center = (left + width / 2.0 + 0.5).floor()
        let expanded_left = (center - typical_half_width / 2.0 + 0.5).floor()
        let left = if expanded_left > 0.0 { expanded_left } else { 0.0 }
        widened_first = Some((left, typical_half_width))
      }
    }
    let len_k = ranges.length()
    for k in 0..<len_k {
      let expand_to_left = should_fill_line_on_line_break &&
        continues_on_next_line &&
        len_k == 1
      let (left, width) = match widened_first {
        Some(widened) => if k == 0 { widened } else { ranges[k] }
        None => ranges[k]
      }
      output.push({
        line_index,
        class_name,
        left,
        width: if expand_to_left {
          None
        } else {
          Some(width)
        },
      })
    }
  }
}

///|
/// The DOM half: appends one `div.cdr.{className}` per computed piece to the
/// shared overlay container (flat-overlay deviation; `decorations.css`).
pub fn ContentViewOverlays::render_decorations_overlay(
  self : ContentViewOverlays,
  decorations : Array[@view_model.ViewModelDecoration],
  viewport : @view_layout.ViewportData,
  get_line_max_column : (Int) -> Int,
  measure : (Int, Int, Int) -> Array[(Double, Double)],
  typical_half_width : Double,
) -> Unit {
  let pieces = compute_decoration_overlay_pieces(
    decorations,
    viewport.start_line_number,
    viewport.end_line_number,
    get_line_max_column,
    measure,
    typical_half_width,
  )
  let document = @rdom.document()
  for piece in pieces {
    let node = document.create_element("div")
    node.set_attribute("class", "cdr " + piece.class_name)
    let top = viewport.relative_vertical_offset[piece.line_index]
    let width_css = match piece.width {
      Some(width) => width.to_string() + "px"
      None => "100%"
    }
    node.set_attribute(
      "style",
      "top:" +
      top.to_string() +
      "px;height:" +
      viewport.line_height.to_string() +
      "px;left:" +
      piece.left.to_string() +
      "px;width:" +
      width_css +
      ";",
    )
    self.view_overlays.append_child(node.as_node())
  }
}
