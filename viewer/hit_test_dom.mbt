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
/// Refines a monospace content hit test into a pixel-accurate one using the
/// browser caret APIs bridged through the line's `CharacterMapping`. Returns
/// `fallback` unchanged when the caret API misses, the line is outside the
/// window, or its mapping is unavailable.
///
/// The mapping is one-based (Monaco semantics); `MouseTarget` columns are
/// zero-based, so the resolved column shifts by one at the boundary.
fn Viewer::dom_refine_content_target(
  self : Viewer,
  view : @view.View,
  client_x : Double,
  client_y : Double,
  fallback : @viewer_common.MouseTarget,
) -> @viewer_common.MouseTarget {
  let hit = dom_caret_hit(view.root, client_x, client_y)
  guard hit.ok() else { return fallback }
  let line_number = hit.line()
  guard view.view_lines.mapping_at(line_number) is Some(mapping) else {
    return fallback
  }
  guard self.view_model is Some(view_model) else { return fallback }
  guard line_number >= 1 && line_number <= view_model.line_count() else {
    return fallback
  }
  let line = view_model.lines().get_view_line_data(line_number)
  let column1 = mapping.get_column(
    { part_index: hit.part(), char_index: hit.char_index() },
    hit.part_length(),
  )
  let column0 = column1 - 1
  let kind : @viewer_common.MouseTargetType = if column0 < line.content.length() {
    ContentText
  } else {
    ContentEmpty
  }
  // `doHitTest` (`mouseTarget.ts:1104-1112`): normalize the caret answer with
  // affinity `None` so a hit inside injected text snaps to a cursor stop; the
  // injected-text identity is taken from the *original* position, matching
  // the source's `ContentHitTestResult(normalizedPosition, …, injectedText)`.
  let normalized = match self.view_model {
    Some(view_model) => {
      // (`PositionAffinity.None` — the annotation-free variant name is
      // enforced by warn 73.)
      let affinity : @model.PositionAffinity = None
      view_model.normalize_position(Position(line_number, column1), affinity)
    }
    None => Position(line_number, column1)
  }
  {
    kind,
    line_number: normalized.line_number,
    column: normalized.column - 1,
    token_index: -1,
    injected_text_index: view_model.injected_text_index_at(
      Position(line_number, column1),
    ),
    gutter_offset_x: 0.0,
    // This refinement only feeds the mouse-down/selection path; the hover's
    // CONTENT_EMPTY epsilon arm reads the monospace hit test's distance.
    horizontal_distance_to_text: -1.0,
  }
}
