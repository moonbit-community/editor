///|
/// Owns the editor's cursor(s), the readonly-viewer reduction of Monaco's
/// `cursor.ts` `CursorsController` over `cursorCollection.ts`. The viewer has a
/// single selection, so this holds one `Cursor`; the surface (set states, read
/// the model/view selections, re-project on reflow) is the faithful subset the
/// viewing path needs. Multi-cursor is a deliberate omission.
pub struct CursorsController {
  mut context : CursorContext
  cursor : Cursor
}

///|
/// Builds a controller with a single collapsed cursor at the origin.
pub fn CursorsController::new(context : CursorContext) -> CursorsController {
  { context, cursor: Cursor::new() }
}

///|
/// Swaps in a new conversion context (after the view model is rebuilt) and
/// re-projects the current selection from its model positions, so the view
/// selection stays correct across reflows.
pub fn CursorsController::set_context(
  self : CursorsController,
  context : CursorContext,
) -> Unit {
  self.context = context
  self.cursor.reproject(context)
}

///|
/// Moves the cursor to a view position. `in_selection_mode` distinguishes
/// `MoveToSelect` (extend, keep the anchor) from `MoveTo` (collapse). The view
/// state moves and the model state is derived through the converter — the
/// view-driven half of Monaco's `CursorMoveCommands.moveTo` for the `Simple`
/// selection kind.
pub fn CursorsController::move_to(
  self : CursorsController,
  view_position : @base_common.Position,
  in_selection_mode : Bool,
) -> Unit {
  let next = self.cursor.view_state.moved(in_selection_mode, view_position)
  self.cursor.set_view_state(self.context, next)
}

///|
/// The current cursor state in model coordinates. Read by the `ViewController`
/// for the model-dependent commands (word/line select) whose continuation logic
/// needs the existing anchor and kind.
pub fn CursorsController::model_state(
  self : CursorsController,
) -> SingleCursorState {
  self.cursor.model_state
}

///|
/// Sets the cursor from an explicit model-coordinate state, deriving the view
/// state through the converter. Used by the model-dependent navigation commands
/// (word/line select, select all) that compute anchor ranges from the model.
pub fn CursorsController::set_model_cursor_state(
  self : CursorsController,
  model_state : SingleCursorState,
) -> Unit {
  self.cursor.set_model_state(self.context, model_state)
}

///|
/// The selection in model coordinates (for the clipboard boundary).
pub fn CursorsController::get_model_selection(
  self : CursorsController,
) -> @core.Selection {
  self.cursor.model_state.selection()
}

///|
/// The selection in view coordinates (for the selection overlay).
pub fn CursorsController::get_view_selection(
  self : CursorsController,
) -> @core.Selection {
  self.cursor.view_state.selection()
}
