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
extern "js" fn read_horizontal_ranges(
  line_node : @rdom.Element,
  start_part : Int,
  start_char : Int,
  end_part : Int,
  end_char : Int,
) -> RectList =
  #| (lineNode, startPart, startChar, endPart, endChar) => {
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
  #|     if (r.width <= 0) { continue; }
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
/// Measured horizontal selection rectangles `(left, width)` for the zero-based
/// view-column range `[start_column, end_column)` on one rendered view line.
/// Returns an empty list when the line is outside the rendered window.
///
/// `CharacterMapping` is one-based, so each zero-based column is shifted by one
/// before resolving its DOM position.
fn View::measure_line_selection(
  self : View,
  view_line_number : Int,
  start_column : Int,
  end_column : Int,
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
  )
  let out : Array[(Double, Double)] = []
  let count = rects.length()
  for i = 0; i + 1 < count; i = i + 2 {
    out.push((rects.get(i), rects.get(i + 1)))
  }
  out
}
