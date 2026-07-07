///|
/// The conversion context a cursor needs, the readonly-viewer reduction of
/// Monaco's `cursorContext.ts` `CursorContext`. Monaco's holds the model, view
/// model, coordinates converter, and cursor config; the immutable readonly
/// viewer needs only the coordinates converter to bridge model and view
/// positions (no validation against a mutating model, no edit config).
pub struct CursorContext {
  coordinates_converter : @view_model.ProjectedCoordinatesConverter
}

///|
/// Builds a cursor context from the active view model's coordinates converter.
pub fn CursorContext::new(
  coordinates_converter : @view_model.ProjectedCoordinatesConverter,
) -> CursorContext {
  { coordinates_converter, }
}

///|
/// Converts a view position to its model position.
pub fn CursorContext::view_to_model(
  self : CursorContext,
  position : @base_common.Position,
) -> @base_common.Position {
  self.coordinates_converter.view_position_to_model_position(position)
}

///|
/// Converts a model position to its view position.
pub fn CursorContext::model_to_view(
  self : CursorContext,
  position : @base_common.Position,
) -> @base_common.Position {
  self.coordinates_converter.model_position_to_view_position(position)
}
