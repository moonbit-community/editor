///|
/// The conversion context a cursor needs, the readonly-viewer reduction of
/// Monaco's `cursorContext.ts` `CursorContext`. Monaco's holds the model, view
/// model, coordinates converter, and cursor config. The local context needs
/// only the converter to bridge model and view positions; the owning
/// `CursorsController` separately holds the mutable `TextModel` for validation
/// and content-version tracking. The converter is held through the
/// `ICoordinatesConverter` interface
/// (`viewer/common/core`), like Monaco's
/// `coordinatesConverter: ICoordinatesConverter` member.
pub struct CursorContext {
  coordinates_converter : &@core.CoordinatesConverter
}

///|
/// Builds a cursor context from the active view model's coordinates converter.
pub fn CursorContext::new(
  coordinates_converter : &@core.CoordinatesConverter,
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
/// Converts the complete view anchor range to model coordinates. The source's
/// missing-model cursor branch uses the converter's range member as one unit,
/// which can preserve boundary affinity differently from two unrelated point
/// conversions.
fn CursorContext::view_range_to_model(
  self : CursorContext,
  range : @base_common.Range,
) -> @base_common.Range {
  self.coordinates_converter.view_range_to_model_range(range)
}

///|
/// Converts a model position to its view position.
pub fn CursorContext::model_to_view(
  self : CursorContext,
  position : @base_common.Position,
) -> @base_common.Position {
  self.coordinates_converter.model_position_to_view_position(position)
}
