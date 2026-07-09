// Ported from `vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts`
// (vscode submodule commit b18492a288de038fbc7643aae6de8247029d11bd): the
// pieces the mouse hit test reads — `ViewLine.CLASS_NAME`, the module-level
// `getColumnOfNodeOffset`, and the rendered line's DOM width read.
//
// Omissions:
//   * The `FastRenderedViewLine`/`RenderedViewLine`/`WebKitRenderedViewLine`
//     class family — this recycler keeps parallel arrays per rendered window
//     (view_lines.mbt), not per-line rendered objects. `getWidth` therefore
//     always takes the source's DOM-measured arm
//     (`RenderedViewLine.getWidth`, viewLine.ts:522-531:
//     `_getReadingTarget(...).offsetWidth`) — which is also the arm every
//     line with foreign elements (e.g. a folded header's `inline-folded`
//     `::after` ellipsis) takes in the source, since
//     `FastRenderedViewLine`'s monospace shortcut is gated on
//     `containsForeignElements === None`.
//   * `_cachedWidth`: the width is re-read per call; the recycler has no
//     per-line invalidation hooks to reset a cache through
//     (`resetCachedWidth`), and the only caller is the per-gesture hit test.

///|
/// `ViewLine.CLASS_NAME` (viewLine.ts:53) — the exact string the caret hit
/// test's ancestor walk compares `className` against.
pub const VIEW_LINE_CLASS_NAME : String = "view-line"

///|
/// `getColumnOfNodeOffset` (viewLine.ts:724-733): resolves a browser caret
/// answer (token span + character offset) to a one-based column through the
/// line's `CharacterMapping`. The span index counts every previous sibling,
/// exactly like the source's `previousSibling` walk.
pub fn get_column_of_node_offset(
  character_mapping : @view_layout.CharacterMapping,
  span_node : @rdom.Element,
  offset : Int,
) -> Int {
  let span_node_text_content_length = element_text_content_length(span_node)
  let span_index = count_previous_siblings(span_node)
  character_mapping.get_column(
    { part_index: span_index, char_index: offset },
    span_node_text_content_length,
  )
}

///|
/// `RenderedViewLine.getWidth` (viewLine.ts:516-531): the rendered width of a
/// line node, read as the `offsetWidth` of its reading target — the
/// `.view-line-content` span (`_getReadingTarget`: the line node's first
/// child). This is a layout read; the passed context records it.
pub fn rendered_view_line_width(
  line_node : @rdom.Element,
  context : DomReadingContext?,
) -> Double {
  let width = reading_target_offset_width(line_node)
  match context {
    Some(ctx) => ctx.mark_did_dom_layout()
    None => ()
  }
  width
}

///|
/// FFI gap-fills (no `textContent`/`previousSibling`/`firstChild.offsetWidth`
/// bindings in the vendored `@rdom`).
extern "js" fn element_text_content_length(el : @rdom.Element) -> Int =
  #| (el) => (el.textContent || "").length

///|
/// The source's `while (spanNode) { spanNode = spanNode.previousSibling;
/// spanIndex++; }` starting from `spanIndex = -1`.
extern "js" fn count_previous_siblings(el : @rdom.Element) -> Int =
  #| (el) => {
  #|   let i = -1;
  #|   let n = el;
  #|   while (n) {
  #|     n = n.previousSibling;
  #|     i++;
  #|   }
  #|   return i;
  #| }

///|
extern "js" fn reading_target_offset_width(line_node : @rdom.Element) -> Double =
  #| (el) => {
  #|   const target = el.firstChild;
  #|   return target ? target.offsetWidth : 0;
  #| }
