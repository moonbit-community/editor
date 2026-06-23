///|
/// The orientation of a selection: whether the active `position` is at the
/// end (`LTR`) or the start (`RTL`) of the selected range. Mirrors Monaco's
/// `SelectionDirection`.
pub(all) enum SelectionDirection {
  LTR
  RTL
} derive(Eq, Debug)

///|
/// A selection in the editor: a range that carries an orientation. Mirrors
/// Monaco's `core/selection.ts` `Selection`. Both endpoints are model
/// positions (zero-based line, UTF-16 column); `selection_start` is the fixed
/// anchor and `position` is the moving active end (the cursor).
///
/// Everything in the cursor/selection/hit-test path stays in `Position`
/// space; the conversion to raw document offsets happens only at the
/// model/clipboard boundary (`normalized_range`).
pub(all) struct Selection {
  selection_start : @base_common.Position
  position : @base_common.Position
} derive(Eq, Debug)

///|
/// Builds a selection from its anchor (`selection_start`) and active
/// (`position`) endpoints without reordering them; the orientation is kept.
pub fn Selection::new(
  selection_start : @base_common.Position,
  position : @base_common.Position,
) -> Selection {
  { selection_start, position }
}

///|
/// Builds a collapsed-or-oriented selection from two model positions, anchor
/// first. Mirrors Monaco's `Selection.fromPositions`.
pub fn Selection::from_positions(
  start : @base_common.Position,
  end : @base_common.Position,
) -> Selection {
  { selection_start: start, position: end }
}

///|
/// Builds a selection from document offsets, anchor at `anchor_offset`.
pub fn Selection::from_offsets(
  snapshot : @model.TextSnapshot,
  anchor_offset : Int,
  focus_offset : Int,
) -> Selection {
  Selection::new(
    snapshot.position_at_offset(anchor_offset),
    snapshot.position_at_offset(focus_offset),
  )
}

///|
/// The active end of the selection (the cursor). Mirrors `getPosition`.
pub fn Selection::get_position(self : Selection) -> @base_common.Position {
  self.position
}

///|
/// The fixed anchor of the selection. Mirrors `getSelectionStart`.
pub fn Selection::get_selection_start(
  self : Selection,
) -> @base_common.Position {
  self.selection_start
}

///|
/// The ordered start position (top-left). Mirrors `Range.getStartPosition`.
pub fn Selection::start(self : Selection) -> @base_common.Position {
  if position_le(self.selection_start, self.position) {
    self.selection_start
  } else {
    self.position
  }
}

///|
/// The ordered end position (bottom-right). Mirrors `Range.getEndPosition`.
pub fn Selection::end(self : Selection) -> @base_common.Position {
  if position_le(self.selection_start, self.position) {
    self.position
  } else {
    self.selection_start
  }
}

///|
/// The orientation of the selection. Mirrors `Selection.getDirection`.
pub fn Selection::direction(self : Selection) -> SelectionDirection {
  if position_eq(self.selection_start, self.start()) {
    LTR
  } else {
    RTL
  }
}

///|
/// Moves the active end while keeping the anchor fixed (drag-to-extend).
/// Direction-agnostic: the anchor stays put and `position` follows the
/// pointer, matching Monaco's `MoveToSelect`.
pub fn Selection::with_position(
  self : Selection,
  position : @base_common.Position,
) -> Selection {
  { ..self, position }
}

///|
/// Whether the selection covers no text (anchor and active coincide).
pub fn Selection::is_empty(self : Selection) -> Bool {
  position_eq(self.selection_start, self.position)
}

///|
/// Selection range normalized into ascending document offsets, the
/// model/clipboard boundary where `Position` space crosses into raw offsets.
pub fn Selection::normalized_range(
  self : Selection,
  snapshot : @model.TextSnapshot,
) -> @base_common.Range {
  Range(
    snapshot.offset_at_position(self.start()),
    snapshot.offset_at_position(self.end()),
  )
}

///|
/// Plain selected text for clipboard writes.
pub fn Selection::get_plain_text_to_copy(
  self : Selection,
  snapshot : @model.TextSnapshot,
) -> String {
  snapshot.slice(self.normalized_range(snapshot))
}

///|
/// Minimal HTML clipboard payload preserving preformatted text.
pub fn Selection::get_rich_text_to_copy(
  self : Selection,
  snapshot : @model.TextSnapshot,
) -> String {
  "<pre class=\"readonly-editor-copy\">" +
  escape_copy_html(self.get_plain_text_to_copy(snapshot)) +
  "</pre>"
}

///|
/// Whether `a` is at or before `b` in reading order (line, then column).
fn position_le(a : @base_common.Position, b : @base_common.Position) -> Bool {
  if a.line != b.line {
    a.line < b.line
  } else {
    a.column <= b.column
  }
}

///|
fn position_eq(a : @base_common.Position, b : @base_common.Position) -> Bool {
  a.line == b.line && a.column == b.column
}

///|
fn escape_copy_html(text : String) -> String {
  let out = StringBuilder()
  for ch in text {
    match ch {
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '&' => out.write_string("&amp;")
      '"' => out.write_string("&quot;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}
