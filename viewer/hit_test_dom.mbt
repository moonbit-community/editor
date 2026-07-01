///|
/// Opaque result of a DOM caret hit test. Always a plain object (never null);
/// `ok` distinguishes a resolved content hit from a miss.
#external
priv type CaretHit

///|
/// Runs the browser's native caret hit test at viewport coordinates and walks
/// the resolved DOM node back to (view-line, token-part, char-offset). This is
/// Monaco's `MouseTargetFactory.doHitTest` role: the browser does the
/// pixel-accurate, font-aware caret placement; we only translate its DOM answer
/// into the part/char coordinates the line's `CharacterMapping` understands.
///
/// `part` is the hit token span's index among `.view-line-content` children,
/// which equals the `part_index` the renderer stored in the mapping. `line` is
/// the one-based view-line number from the line node's `data-line`.
extern "js" fn dom_caret_hit(
  root : @rdom.Element,
  client_x : Double,
  client_y : Double,
) -> CaretHit =
  #| (root, clientX, clientY) => {
  #|   const miss = { ok: 0, line: -1, part: -1, charIndex: -1, partLength: 0 };
  #|   const doc = root.ownerDocument || globalThis.document;
  #|   if (!doc) { return miss; }
  #|   let node = null, offset = 0;
  #|   if (typeof doc.caretRangeFromPoint === "function") {
  #|     const range = doc.caretRangeFromPoint(clientX, clientY);
  #|     if (range) { node = range.startContainer; offset = range.startOffset; }
  #|   } else if (typeof doc.caretPositionFromPoint === "function") {
  #|     const pos = doc.caretPositionFromPoint(clientX, clientY);
  #|     if (pos) { node = pos.offsetNode; offset = pos.offset; }
  #|   }
  #|   if (!node || node.nodeType !== 3) { return miss; }
  #|   const tokenSpan = node.parentNode;
  #|   const lineContent = tokenSpan && tokenSpan.parentNode;
  #|   if (!lineContent || !lineContent.children) { return miss; }
  #|   let part = -1;
  #|   const kids = lineContent.children;
  #|   for (let i = 0; i < kids.length; i++) {
  #|     if (kids[i] === tokenSpan) { part = i; break; }
  #|   }
  #|   if (part < 0) { return miss; }
  #|   let el = lineContent.parentNode, line = -1;
  #|   while (el) {
  #|     if (el.getAttribute) {
  #|       const dl = el.getAttribute("data-line");
  #|       if (dl !== null) { line = parseInt(dl, 10); break; }
  #|     }
  #|     el = el.parentNode;
  #|   }
  #|   if (!(line >= 0)) { return miss; }
  #|   const text = node.textContent || "";
  #|   return { ok: 1, line: line, part: part, charIndex: offset, partLength: text.length };
  #| }

///|
extern "js" fn CaretHit::ok(self : CaretHit) -> Bool = "(h) => h.ok === 1"

///|
extern "js" fn CaretHit::line(self : CaretHit) -> Int = "(h) => h.line"

///|
extern "js" fn CaretHit::part(self : CaretHit) -> Int = "(h) => h.part"

///|
extern "js" fn CaretHit::char_index(self : CaretHit) -> Int = "(h) => h.charIndex"

///|
extern "js" fn CaretHit::part_length(self : CaretHit) -> Int = "(h) => h.partLength"

///|
/// The render line for a one-based view-line number within the frame window.
fn frame_render_line(
  frame : @view_model.RenderFrame,
  line_number : Int,
) -> @view_model.RenderLine? {
  let index = line_number - 1 - frame.viewport.start_line
  if index >= 0 && index < frame.lines.length() {
    Some(frame.lines[index])
  } else {
    None
  }
}

///|
/// Refines a monospace content hit test into a pixel-accurate one using the
/// browser caret APIs bridged through the line's `CharacterMapping`. Returns
/// `fallback` unchanged when the caret API misses, the line is outside the
/// window, or its mapping is unavailable.
///
/// The mapping is one-based (Monaco semantics); `RenderLine` columns are
/// zero-based, so the resolved column is shifted by one before deriving the
/// document offset.
fn Viewer::dom_refine_content_target(
  self : Viewer,
  view : @view.View,
  frame : @view_model.RenderFrame,
  client_x : Double,
  client_y : Double,
  fallback : @viewer_common.MouseTarget,
) -> @viewer_common.MouseTarget {
  ignore(self)
  let hit = dom_caret_hit(view.root, client_x, client_y)
  guard hit.ok() else { return fallback }
  let line_number = hit.line()
  guard view.view_lines.mapping_at(line_number) is Some(mapping) else {
    return fallback
  }
  guard frame_render_line(frame, line_number) is Some(line) else {
    return fallback
  }
  let column1 = mapping.get_column(
    { part_index: hit.part(), char_index: hit.char_index() },
    hit.part_length(),
  )
  let column0 = column1 - 1
  let kind : @viewer_common.MouseTargetKind = if column0 < line.text.length() {
    ContentText
  } else {
    ContentEmpty
  }
  {
    kind,
    line_number,
    column: column0,
    token_index: -1,
    injected_text_index: line.injected_text_index_at_column(column0),
  }
}
