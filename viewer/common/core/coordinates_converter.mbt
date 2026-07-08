///|
/// Converts between model document coordinates and rendered view coordinates,
/// `ICoordinatesConverter` (`coordinatesConverter.ts:15-30`) with Monaco's
/// `convert` prefix dropped. `affinity` picks the side of an injected-text or
/// wrap boundary; absent it means the Monaco default of that member — `None`
/// for positions (`viewModelLines.ts:848`) and `Left` for ranges (`:892`,
/// where it only affects empty ranges).
///
/// Filing deviation: Monaco keeps this interface-only file at
/// `editor/common/coordinatesConverter.ts`, but the directory-mirror's
/// residual `viewer/common` package sits *above* `view_model` (it imports
/// it), so the nearest package below both `view_model` (the implementor)
/// and `cursor` (the consumer) is this `core/` mirror package.
pub(open) trait CoordinatesConverter {
  fn model_position_to_view_position(
    Self,
    @base_common.Position,
    affinity? : @model.PositionAffinity,
  ) -> @base_common.Position
  fn view_position_to_model_position(Self, @base_common.Position) -> @base_common.Position
  fn model_range_to_view_range(
    Self,
    @base_common.Range,
    affinity? : @model.PositionAffinity,
  ) -> @base_common.Range
  fn view_range_to_model_range(Self, @base_common.Range) -> @base_common.Range
}
