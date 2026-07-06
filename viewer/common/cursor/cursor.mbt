///|
/// A single cursor, a faithful port of Monaco's `oneCursor.ts` `Cursor`. It
/// keeps both a model-coordinate and a view-coordinate `SingleCursorState` in
/// sync through the `CursorContext`'s coordinates converter. Setting one side
/// derives the other (`set_state`), exactly as Monaco's `_setState` does.
///
/// The readonly viewer's model is immutable, so the marker-tracked-range and
/// model-validation machinery of Monaco's `_setState` is dropped: positions
/// produced by the hit test and the converter are already valid, and the
/// converter clamps. That is the only deviation.
pub struct Cursor {
  mut model_state : SingleCursorState
  mut view_state : SingleCursorState
}

///|
/// A fresh cursor collapsed at the document origin.
pub fn Cursor::new() -> Cursor {
  let origin = @base_common.Position::Position(1, 1)
  {
    model_state: SingleCursorState::collapsed(origin),
    view_state: SingleCursorState::collapsed(origin),
  }
}

///|
/// Sets the cursor from a view-coordinate state, deriving the model state by
/// converting every endpoint through the coordinates converter. Mirrors the
/// "we only have the view state => compute the model state" branch of
/// Monaco's `_setState`.
fn Cursor::set_view_state(
  self : Cursor,
  context : CursorContext,
  view_state : SingleCursorState,
) -> Unit {
  self.view_state = view_state
  self.model_state = SingleCursorState::new(
    context.view_to_model(view_state.selection_start_start),
    context.view_to_model(view_state.selection_start_end),
    view_state.selection_start_kind,
    context.view_to_model(view_state.position),
  )
}

///|
/// Sets the cursor from a model-coordinate state, deriving the view state by
/// converting every endpoint through the coordinates converter. Mirrors the
/// "we only have the model state => compute the view state" branch of
/// Monaco's `_setState`; used to re-project an existing selection after the
/// view model reflows (wrapping, inlay hints).
pub fn Cursor::set_model_state(
  self : Cursor,
  context : CursorContext,
  model_state : SingleCursorState,
) -> Unit {
  self.model_state = model_state
  self.view_state = SingleCursorState::new(
    context.model_to_view(model_state.selection_start_start),
    context.model_to_view(model_state.selection_start_end),
    model_state.selection_start_kind,
    context.model_to_view(model_state.position),
  )
}

///|
/// Re-derives the view state from the current model state through `context`.
/// Used when the view model is rebuilt so an existing selection stays anchored
/// to the same model positions after the reflow.
fn Cursor::reproject(self : Cursor, context : CursorContext) -> Unit {
  self.set_model_state(context, self.model_state)
}
