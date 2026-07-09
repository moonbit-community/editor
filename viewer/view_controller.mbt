///|
/// Maps a pointer gesture to a `CoreNavigationCommands` call on the cursor
/// stack — Monaco's `ViewController.dispatchMouse`
/// (`vscode/src/vs/editor/browser/view/viewController.ts:217-311`, vscode
/// submodule commit b18492a288de038fbc7643aae6de8247029d11bd), branch for
/// branch over the full `IMouseDispatchData` (`@controller.MouseDispatchData`;
/// `data.position` is a 1-based view position).
///
/// Omitted branches (each an explicit early-out below, ledger):
///   * `middleButton` — no `ColumnSelect` command and no middle-click-scroll
///     contribution (viewController.ts:222-227);
///   * every `_hasMulticursorModifier` arm (`multiCursorModifier` reads as
///     the Monaco default `altKey`; the viewer's cursor stack is
///     single-cursor: no `_createCursor`/`_lastCursor*`,
///     viewController.ts:230-235, 246-251, 261-262, 282-294);
///   * `doubleClickSelectsBlock` (viewController.ts:267-278) — option not
///     modeled, no bracket-pair/tokenization query surface;
///   * `columnSelection` / alt-drag column select (viewController.ts:297-302)
///     — no column selection;
///   * `revealType` — the viewer's cursor commands take none.
fn Viewer::dispatch_mouse(
  self : Viewer,
  data : @controller.MouseDispatchData,
) -> Unit {
  guard self.get_view_model() is Some(view_model) else { return }
  let controller = view_model.cursor
  if data.middle_button {
    // `middleButton && !selectionClipboardIsOn` → middle-click scroll /
    // column select, both unported: a middle-button gesture must not fall
    // into the left-button arms.
    ()
  } else if data.started_on_line_numbers {
    // If the dragging started on the gutter, then have operations work on
    // the entire line
    if has_multicursor_modifier(data) {
      // `_lastCursorLineSelect` / `_createCursor` (multi-cursor) — unported.
      ()
    } else if data.in_selection_mode {
      self.line_select_drag(controller, data.position)
    } else {
      self.line_select(controller, data.position)
    }
  } else if data.mouse_down_count >= 4 {
    self.select_all(controller)
  } else if data.mouse_down_count == 3 {
    if has_multicursor_modifier(data) {
      // `_lastCursorLineSelect(Drag)` — unported.
      ()
    } else if data.in_selection_mode {
      self.line_select_drag(controller, data.position)
    } else {
      self.line_select(controller, data.position)
    }
  } else if data.mouse_down_count == 2 {
    // A double-click on injected text (an inlay hint) selects nothing
    // (viewController.ts:260).
    if !data.on_injected_text {
      if has_multicursor_modifier(data) {
        // `_lastCursorWordSelect` — unported.
        ()
      } else if data.in_selection_mode {
        self.word_select_drag(controller, data.position)
      } else {
        // `doubleClickSelectsBlock` bracket/string block select — unported.
        self.word_select(controller, data.position)
      }
    }
  } else if has_multicursor_modifier(data) {
    // Purely-alt multi-cursor operations and the shift+alt column select —
    // unported (`!_hasNonMulticursorModifier` inner gate included).
    ()
  } else if data.in_selection_mode {
    if data.alt_key {
      // alt-drag column select — unported.
      ()
    } else {
      // `columnSelection` reads as the Monaco default `false`.
      @cursor.move_to_select(controller, data.position)
    }
  } else {
    @cursor.move_to(controller, data.position)
  }
  self.schedule_render()
}

///|
/// `_hasMulticursorModifier` (viewController.ts:109-120) with
/// `multiCursorModifier` at its Monaco default `'altKey'`.
fn has_multicursor_modifier(data : @controller.MouseDispatchData) -> Bool {
  data.alt_key
}

///|
/// `CoreNavigationCommands.SelectAll`: select the whole document.
fn Viewer::select_all(
  self : Viewer,
  controller : @cursor.CursorsController,
) -> Unit {
  guard self.get_model() is Some(model) else { return }
  let snapshot = model.snapshot
  let last_line = snapshot.line_count() - 1
  let end = @base_common.Position::Position(
    last_line + 1,
    snapshot.line_text(last_line).length() + 1,
  )
  let origin = @base_common.Position::Position(1, 1)
  controller.set_model_cursor_state(
    @cursor.SingleCursorState::new(origin, end, Simple, end),
  )
}

///|
/// `CursorMoveCommands.line` (not in selection mode): select from the clicked
/// model line's start to the next line's start, anchoring `Line`.
fn Viewer::line_select(
  self : Viewer,
  controller : @cursor.CursorsController,
  view_position : @base_common.Position,
) -> Unit {
  guard self.get_model() is Some(model) else { return }
  let snapshot = model.snapshot
  let position = self.view_to_model(view_position)
  let (to_line, to_column) = line_select_end(snapshot, position.line_number - 1)
  let start = @base_common.Position::Position(position.line_number, 1)
  let active = @base_common.Position::Position(to_line + 1, to_column + 1)
  controller.set_model_cursor_state(
    @cursor.SingleCursorState::new(start, active, Line, active),
  )
}

///|
/// `CursorMoveCommands.line` (in selection mode): extend the whole-line
/// selection. Transcribed in model space — backward extends to the target
/// line start, forward to the line after the target, and re-entering the
/// anchor line resets to the anchor's far edge.
fn Viewer::line_select_drag(
  self : Viewer,
  controller : @cursor.CursorsController,
  view_position : @base_common.Position,
) -> Unit {
  guard self.get_model() is Some(model) else { return }
  let snapshot = model.snapshot
  let position = self.view_to_model(view_position)
  let state = controller.model_state()
  let entering_line = state.selection_start_start.line_number
  let next = if position.line_number < entering_line {
    state.moved(true, Position(position.line_number, 1))
  } else if position.line_number > entering_line {
    let (to_line, to_column) = line_select_end(
      snapshot,
      position.line_number - 1,
    )
    state.moved(true, Position(to_line + 1, to_column + 1))
  } else {
    state.moved(true, state.selection_start_end)
  }
  controller.set_model_cursor_state(next)
}

///|
/// `CursorMoveCommands.word` (not in selection mode): select the word at the
/// click, anchoring `Word`.
fn Viewer::word_select(
  self : Viewer,
  controller : @cursor.CursorsController,
  view_position : @base_common.Position,
) -> Unit {
  guard self.get_model() is Some(model) else { return }
  let snapshot = model.snapshot
  let position = self.view_to_model(view_position)
  let (start_column, end_column) = word_range(
    snapshot.line_text(position.line_number - 1),
    position.column - 1,
  )
  let start = @base_common.Position::Position(
    position.line_number,
    start_column + 1,
  )
  let active = @base_common.Position::Position(
    position.line_number,
    end_column + 1,
  )
  controller.set_model_cursor_state(
    @cursor.SingleCursorState::new(start, active, Word, active),
  )
}

///|
/// `CursorMoveCommands.word` (in selection mode): extend the selection to the
/// word boundary at the pointer — the word start when dragging before the
/// anchor, the word end when dragging at or after it.
fn Viewer::word_select_drag(
  self : Viewer,
  controller : @cursor.CursorsController,
  view_position : @base_common.Position,
) -> Unit {
  guard self.get_model() is Some(model) else { return }
  let snapshot = model.snapshot
  let position = self.view_to_model(view_position)
  let state = controller.model_state()
  let (start_column, end_column) = word_range(
    snapshot.line_text(position.line_number - 1),
    position.column - 1,
  )
  let anchor = state.selection_start_start
  let active : @base_common.Position = if position.line_number <
    anchor.line_number ||
    (
      position.line_number == anchor.line_number &&
      position.column < anchor.column
    ) {
    Position(position.line_number, start_column + 1)
  } else {
    Position(position.line_number, end_column + 1)
  }
  controller.set_model_cursor_state(state.moved(true, active))
}

///|
/// Converts a view position to a model position through the active converter.
fn Viewer::view_to_model(
  self : Viewer,
  view_position : @base_common.Position,
) -> @base_common.Position {
  match self.get_view_model() {
    Some(view_model) =>
      view_model
      .coordinates_converter()
      .view_position_to_model_position(view_position)
    None => view_position
  }
}

///|
/// The end position of a one-click line selection: the start of the next model
/// line, or the end of the last line when the clicked line is the last. Pure
/// 0-based helper (0-based `line` in, 0-based `(line, column)` out); callers
/// convert to/from 1-based `Position`.
fn line_select_end(snapshot : @model.TextSnapshot, line : Int) -> (Int, Int) {
  if line + 1 < snapshot.line_count() {
    (line + 1, 0)
  } else {
    (line, snapshot.line_text(line).length())
  }
}

///|
/// The half-open zero-based column range of the word touching `column` in
/// `line_text`. Mirrors Monaco's default word selection: a run of word
/// characters (alphanumerics plus `_$` and non-ASCII letters) bounds the word;
/// clicking off any word selects the single character under the pointer.
fn word_range(line_text : String, column : Int) -> (Int, Int) {
  let length = line_text.length()
  let column = @base_common.clamp_int(column, 0, length)
  let in_word = column < length && is_word_char(line_text[column].to_int())
  let at_word_end = column > 0 && is_word_char(line_text[column - 1].to_int())
  if !in_word && !at_word_end {
    // Off any word: select the single character under the pointer, if any.
    if column < length {
      return (column, column + 1)
    }
    return (column, column)
  }
  let mut start = column
  while start > 0 && is_word_char(line_text[start - 1].to_int()) {
    start = start - 1
  }
  let mut end = column
  while end < length && is_word_char(line_text[end].to_int()) {
    end = end + 1
  }
  (start, end)
}

///|
/// Whether a UTF-16 code unit is a word character (alphanumerics, `_`, `$`, and
/// non-ASCII), Monaco's default word-separator complement.
fn is_word_char(code : Int) -> Bool {
  (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
  (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
  (code >= '0'.to_int() && code <= '9'.to_int()) ||
  code == '_'.to_int() ||
  code == '$'.to_int() ||
  code > 127
}
