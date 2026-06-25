///|
/// How a selection was anchored, mirroring Monaco's `SelectionStartKind`. A
/// plain click anchors `Simple`; double/triple-click would anchor `Word`/`Line`
/// (the word/line drag-extend behavior is a follow-up, but the kind is tracked
/// so `move` can preserve it).
pub(all) enum SelectionStartKind {
  Simple
  Word
  Line
} derive(Eq, Debug)

///|
/// The cursor state on either the model or the view model, a faithful port of
/// Monaco's `cursorCommon.ts` `SingleCursorState`. `selection_start` is the
/// anchor *range* (a region for word/line selection, collapsed for simple) and
/// `position` is the moving active end; the derived `selection` carries the
/// orientation. Positions are zero-based (line, UTF-16 column).
///
/// `leftover_visible_column` (Monaco's `leftoverVisibleColumns` for sticky
/// vertical movement) has no readonly mouse-selection role and is omitted until
/// keyboard navigation lands.
pub(all) struct SingleCursorState {
  selection_start_start : @base_common.Position
  selection_start_end : @base_common.Position
  selection_start_kind : SelectionStartKind
  position : @base_common.Position
} derive(Eq, Debug)

///|
/// Builds a cursor state from an explicit anchor range and active position.
pub fn SingleCursorState::new(
  selection_start_start : @base_common.Position,
  selection_start_end : @base_common.Position,
  selection_start_kind : SelectionStartKind,
  position : @base_common.Position,
) -> SingleCursorState {
  { selection_start_start, selection_start_end, selection_start_kind, position }
}

///|
/// A collapsed cursor at `position` (anchor and active coincide, `Simple`).
pub fn SingleCursorState::collapsed(
  position : @base_common.Position,
) -> SingleCursorState {
  SingleCursorState::new(position, position, Simple, position)
}

///|
/// Whether the anchor range is collapsed to a point.
fn SingleCursorState::selection_start_is_empty(
  self : SingleCursorState,
) -> Bool {
  position_eq(self.selection_start_start, self.selection_start_end)
}

///|
/// The derived selection (anchor, active) carrying orientation. Transcribes
/// Monaco's `SingleCursorState._computeSelection`: when the active end is at or
/// after the anchor's start, the anchor is the start; when it has moved before
/// the anchor's start (selecting backward over a word/line), the anchor is the
/// end.
pub fn SingleCursorState::selection(
  self : SingleCursorState,
) -> @view_model.Selection {
  if self.selection_start_is_empty() ||
    not_before_or_equal(self.position, self.selection_start_start) {
    @view_model.Selection::new(self.selection_start_start, self.position)
  } else {
    @view_model.Selection::new(self.selection_start_end, self.position)
  }
}

///|
/// Whether this state selects any text (mirrors Monaco `hasSelection`).
pub fn SingleCursorState::has_selection(self : SingleCursorState) -> Bool {
  !self.selection().is_empty() || !self.selection_start_is_empty()
}

///|
/// Moves the cursor, transcribing Monaco's `SingleCursorState.move` (`move` is
/// a reserved word here). In selection mode only the active `position` moves
/// (the anchor is kept); out of selection mode the whole state collapses to the
/// new point.
pub fn SingleCursorState::moved(
  self : SingleCursorState,
  in_selection_mode : Bool,
  position : @base_common.Position,
) -> SingleCursorState {
  if in_selection_mode {
    { ..self, position, }
  } else {
    SingleCursorState::new(position, position, Simple, position)
  }
}

///|
/// Whether `a` is strictly after `b` in reading order, i.e. `!a.isBeforeOrEqual(b)`.
fn not_before_or_equal(
  a : @base_common.Position,
  b : @base_common.Position,
) -> Bool {
  if a.line != b.line {
    a.line > b.line
  } else {
    a.column > b.column
  }
}

///|
fn position_eq(a : @base_common.Position, b : @base_common.Position) -> Bool {
  a.line == b.line && a.column == b.column
}
