///|
/// A decoration resolved into view coordinates, the Monaco `ViewModelDecoration`
/// role: the model decoration's class/kind paired with its range already
/// converted to view `Position`s. The viewer never round-trips decorations
/// through raw document offsets when rendering; it converts once here and then
/// works in view columns, exactly like `viewModelDecorations.ts`.
pub(all) struct ViewModelDecoration {
  range : @view_line_renderer.ViewRange
  kind : @decorations.DecorationKind
  class_name : String
} derive(Eq, Debug)

///|
/// Decoration provider for one view model, the Monaco `ViewModelDecorations`
/// role: it maps model decorations (stored as document-offset ranges, the
/// model boundary) into view-coordinate `ViewModelDecoration`s through the
/// `CoordinatesConverter`. Replacing the offset-centric per-line bucket query,
/// every consumer downstream of this works in view `Position`s.
pub struct ViewModelDecorations {
  snapshot : @model.TextSnapshot
  converter : ViewModelCoordinatesConverter
  decorations : Array[ViewModelDecoration]
}

///|
/// Builds the view-coordinate decorations for a view model from its model
/// decorations, snapshot, and coordinate converter.
pub fn ViewModelDecorations::new(
  snapshot : @model.TextSnapshot,
  converter : ViewModelCoordinatesConverter,
  decorations : Array[@decorations.Decoration],
) -> ViewModelDecorations {
  let view_decorations = decorations.map(decoration => to_view_decoration(
    snapshot,
    converter,
    decoration,
  ))
  { snapshot, converter, decorations: view_decorations }
}

///|
/// The view-coordinate decorations baked into this view model (markers,
/// diagnostics, semantic-token and current-line decorations from the source).
pub fn ViewModelDecorations::view_decorations(
  self : ViewModelDecorations,
) -> Array[ViewModelDecoration] {
  self.decorations
}

///|
/// Converts controller-contributed model decorations (e.g. hover highlights)
/// into view coordinates using the same snapshot and converter, so they share
/// the rendering path with the baked-in decorations.
pub fn ViewModelDecorations::to_view_decorations(
  self : ViewModelDecorations,
  decorations : Array[@decorations.Decoration],
) -> Array[ViewModelDecoration] {
  decorations.map(decoration => to_view_decoration(
    self.snapshot,
    self.converter,
    decoration,
  ))
}

///|
/// Converts one model decoration to view coordinates: the offset range becomes
/// a model `Position` range at the model boundary, then the converter projects
/// it to a view `Position` range.
fn to_view_decoration(
  snapshot : @model.TextSnapshot,
  converter : ViewModelCoordinatesConverter,
  decoration : @decorations.Decoration,
) -> ViewModelDecoration {
  let start = snapshot.position_at_offset(decoration.range.start)
  let end = snapshot.position_at_offset(decoration.range.end)
  let model_range : @view_line_renderer.ViewRange = {
    start_line_number: start.line + 1,
    start_column: start.column + 1,
    end_line_number: end.line + 1,
    end_column: end.column + 1,
  }
  {
    range: converter.model_range_to_view_range(model_range),
    kind: decoration.kind,
    class_name: decoration.class_name,
  }
}

///|
/// Clips this decoration's view range to one view line, returning the one-based
/// half-open `[start_column, end_column)` span local to that line, or `None`
/// when the decoration does not cover the line or collapses to empty. This is
/// the per-line projection `linesVisibleRangesForRange` performs, in columns.
pub fn ViewModelDecoration::columns_on_view_line(
  self : ViewModelDecoration,
  view_line_number : Int,
  max_column : Int,
) -> (Int, Int)? {
  let range = self.range
  if view_line_number < range.start_line_number ||
    view_line_number > range.end_line_number {
    return None
  }
  let start_column = if range.start_line_number == view_line_number {
    range.start_column
  } else {
    1
  }
  let end_column = if range.end_line_number == view_line_number {
    range.end_column
  } else {
    max_column
  }
  let start_column = @base_common.clamp_int(start_column, 1, max_column)
  let end_column = @base_common.clamp_int(end_column, 1, max_column)
  if start_column >= end_column {
    None
  } else {
    Some((start_column, end_column))
  }
}
