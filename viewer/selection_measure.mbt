///|
/// A flat `[left0, width0, left1, width1, ...]` JS array of measured selection
/// rectangles, in CSS pixels relative to the line node's left edge.
#external
priv type RectList

///|
/// Measures the pixel rectangles covering a DOM character range on one rendered
/// line, Monaco's `RangeUtil.readHorizontalRanges` role. It builds a DOM
/// `Range` between the `(part, char)` endpoints — token span child index and
/// offset into that span's text node — and returns its `getClientRects`, left
/// values normalized against the line node so they are independent of scroll
/// and page position.
/// `keep_empty` mirrors Monaco's `RangeUtil._createHorizontalRangesFromClientRects`,
/// which keeps every client rect — including the zero-width caret rect a
/// collapsed range yields. Selection rendering passes `false` (zero-width
/// slivers are noise there); horizontal reveal passes `true` so a collapsed
/// `reveal_position` can still measure its caret x.
extern "js" fn read_horizontal_ranges(
  line_node : @rdom.Element,
  start_part : Int,
  start_char : Int,
  end_part : Int,
  end_char : Int,
  keep_empty : Bool,
) -> RectList =
  #| (lineNode, startPart, startChar, endPart, endChar, keepEmpty) => {
  #|   const content = lineNode.querySelector(".view-line-content");
  #|   if (!content || !content.children || content.children.length === 0) { return []; }
  #|   const kids = content.children;
  #|   const endpoint = (partIndex, charIndex) => {
  #|     let p = partIndex;
  #|     if (p < 0) { p = 0; }
  #|     if (p >= kids.length) { p = kids.length - 1; }
  #|     const span = kids[p];
  #|     const textNode = span.firstChild;
  #|     if (!textNode || textNode.nodeType !== 3) {
  #|       return { node: span, offset: 0, isText: false };
  #|     }
  #|     const len = textNode.textContent ? textNode.textContent.length : 0;
  #|     let ci = charIndex;
  #|     if (ci < 0) { ci = 0; }
  #|     if (ci > len) { ci = len; }
  #|     return { node: textNode, offset: ci, isText: true };
  #|   };
  #|   const s = endpoint(startPart, startChar);
  #|   const e = endpoint(endPart, endChar);
  #|   const range = lineNode.ownerDocument.createRange();
  #|   try {
  #|     if (s.isText) { range.setStart(s.node, s.offset); } else { range.setStartBefore(s.node); }
  #|     if (e.isText) { range.setEnd(e.node, e.offset); } else { range.setEndAfter(e.node); }
  #|   } catch (_e) { return []; }
  #|   const lineLeft = lineNode.getBoundingClientRect().left;
  #|   const rects = range.getClientRects();
  #|   const out = [];
  #|   for (let i = 0; i < rects.length; i++) {
  #|     const r = rects[i];
  #|     if (r.width <= 0 && !keepEmpty) { continue; }
  #|     out.push(r.left - lineLeft);
  #|     out.push(r.width);
  #|   }
  #|   return out;
  #| }

///|
extern "js" fn RectList::length(self : RectList) -> Int = "(a) => a.length"

///|
extern "js" fn RectList::get(self : RectList, index : Int) -> Double = "(a, i) => a[i]"

///|
/// Whether a one-based view line currently has a rendered DOM node — the gate
/// the deferred horizontal reveal waits on before measuring (the line node may
/// not exist until a vertical scroll brings the line into the window).
fn View::is_line_rendered(self : View, view_line_number : Int) -> Bool {
  self.view_lines.line_node_at(view_line_number) is Some(_)
}

///|
/// Measured horizontal selection rectangles `(left, width)` for the zero-based
/// view-column range `[start_column, end_column)` on one rendered view line.
/// Returns an empty list when the line is outside the rendered window.
///
/// `CharacterMapping` is one-based, so each zero-based column is shifted by one
/// before resolving its DOM position. `keep_empty` (default `false`) keeps
/// zero-width rects so a collapsed range still yields its caret rect — horizontal
/// reveal needs it, selection rendering does not.
fn View::measure_line_selection(
  self : View,
  view_line_number : Int,
  start_column : Int,
  end_column : Int,
  keep_empty? : Bool = false,
) -> Array[(Double, Double)] {
  guard self.view_lines.mapping_at(view_line_number) is Some(mapping) else {
    return []
  }
  guard self.view_lines.line_node_at(view_line_number) is Some(node) else {
    return []
  }
  let start_dom = mapping.get_dom_position(start_column + 1)
  let end_dom = mapping.get_dom_position(end_column + 1)
  let rects = read_horizontal_ranges(
    node,
    start_dom.part_index,
    start_dom.char_index,
    end_dom.part_index,
    end_dom.char_index,
    keep_empty,
  )
  let out : Array[(Double, Double)] = []
  let count = rects.length()
  for i = 0; i + 1 < count; i = i + 2 {
    out.push((rects.get(i), rects.get(i + 1)))
  }
  merge_adjacent_ranges(out)
}

///|
/// Coalesces adjacent/overlapping horizontal ranges into contiguous ones,
/// Monaco's `RangeUtil._mergeAdjacentRanges`. `getClientRects` returns one
/// rectangle per token span a selection crosses; without merging, a single
/// contiguous selection paints as several abutting (and, after sub-pixel
/// rounding, overlapping) pieces. Sorting by left edge and joining ranges whose
/// gap is within the browser-rounding tolerance yields one range per contiguous
/// run, so the overlay paints a single rectangle and keeps its rounded corners.
fn merge_adjacent_ranges(
  ranges : Array[(Double, Double)],
) -> Array[(Double, Double)] {
  if ranges.length() <= 1 {
    return ranges
  }
  let sorted = ranges.copy()
  sorted.sort_by((left, right) => {
    if left.0 != right.0 {
      if left.0 < right.0 {
        -1
      } else {
        1
      }
    } else if left.1 < right.1 {
      -1
    } else if left.1 > right.1 {
      1
    } else {
      0
    }
  })
  let result : Array[(Double, Double)] = []
  let mut prev_left = sorted[0].0
  let mut prev_width = sorted[0].1
  for index in 1..<sorted.length() {
    let left = sorted[index].0
    let width = sorted[index].1
    // 0.9px accounts for the browser's client-rect rounding errors.
    if prev_left + prev_width + 0.9 >= left {
      let candidate = left + width - prev_left
      if candidate > prev_width {
        prev_width = candidate
      }
    } else {
      result.push((prev_left, prev_width))
      prev_left = left
      prev_width = width
    }
  }
  result.push((prev_left, prev_width))
  result
}
