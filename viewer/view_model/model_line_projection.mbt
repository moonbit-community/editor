///|
/// Projection table from model lines to visible view-line segments.
pub struct ModelLineProjection {
  projections : Array[ModelLineProjectionData]
  model_line_start_view_indices : Array[Int]
  view_line_segments : Array[ModelLineProjectionSegment]
}

///|
/// Builds a full projection table from visible/unwrapped model lines.
pub fn ModelLineProjection::build(
  lines : ViewModelLinesFromModelAsIs,
  computer : LineBreaksComputer,
) -> ModelLineProjection {
  let projections : Array[ModelLineProjectionData] = []
  let starts : Array[Int] = []
  let segments : Array[ModelLineProjectionSegment] = []
  for model_line_number in 1..<=lines.model_line_count() {
    starts.push(segments.length())
    let projected_line = lines.projected_text_line(model_line_number)
    let data = if lines.is_model_line_hidden(model_line_number) {
      ModelLineProjectionData(
        model_line_number,
        projected_line.model_line_length,
        projected_line,
        [],
      )
    } else {
      computer.compute_projected_line_projection(
        model_line_number, projected_line,
      )
    }
    projections.push(data)
    for segment in data.segments {
      segments.push(segment)
    }
  }
  {
    projections,
    model_line_start_view_indices: starts,
    view_line_segments: segments,
  }
}

///|
/// Total number of visible projected view lines.
pub fn ModelLineProjection::view_line_count(self : ModelLineProjection) -> Int {
  self.view_line_segments.length()
}

///|
/// Segment for a one-based view line number.
pub fn ModelLineProjection::segment_for_view_line_number(
  self : ModelLineProjection,
  view_line_number : Int,
) -> ModelLineProjectionSegment {
  let index = @base_common.clamp_int(
    view_line_number - 1,
    0,
    self.view_line_segments.length() - 1,
  )
  self.view_line_segments[index]
}

///|
/// Projected text for a one-based model line.
pub fn ModelLineProjection::projected_line_for_model_line(
  self : ModelLineProjection,
  model_line_number : Int,
) -> ProjectedTextLine {
  let index = @base_common.clamp_int(
    model_line_number - 1,
    0,
    self.projections.length() - 1,
  )
  self.projections[index].projected_line
}

///|
/// Converts a model position to the corresponding projected view position.
///
/// Monaco's `translateToOutputPosition` takes a `PositionAffinity`; this does
/// not (see the deviation note on `ProjectedTextLine`). The boundary side is
/// fixed by the column lookup table, which suffices for the caret-free readonly
/// viewer.
pub fn ModelLineProjection::model_position_to_view_position(
  self : ModelLineProjection,
  position : @base_common.Position,
) -> @base_common.Position {
  // `position` is 1-based (Monaco); the projection tables are 0-based, so undo
  // the +1 on entry and re-apply it when building the view `Position`.
  let model_line = @base_common.clamp_int(
    position.line_number - 1,
    0,
    self.projections.length() - 1,
  )
  let data = self.projections[model_line]
  let model_column = @base_common.clamp_int(
    position.column - 1,
    0,
    data.line_length,
  )
  if data.view_line_count() == 0 {
    return self.hidden_model_position_to_view_position(model_line)
  }
  let projected_column = data.projected_line.model_column_to_projected_column(
    model_column,
  )
  let segment_index = data.view_line_index_for_projected_column(
    projected_column,
  )
  let segment = data.segment_at_view_line_index(segment_index)
  {
    line_number: self.model_line_start_view_indices[model_line] +
    segment_index +
    1,
    // A continuation line's content sits past its indent, so the view column
    // gains `wrapped_text_indent_length` (Monaco's `getOutputPositionOfInputOffset`).
    column: projected_column -
    segment.start_offset +
    1 +
    segment.wrapped_text_indent_length,
  }
}

///|
/// Converts a projected view position back to model coordinates.
pub fn ModelLineProjection::view_position_to_model_position(
  self : ModelLineProjection,
  position : @base_common.Position,
) -> @base_common.Position {
  // `position` is a 1-based view position; segments and the projection tables
  // are 0-based internally. `model_line_number` is already 1-based, so the model
  // `Position` keeps it as-is and only the column re-gains the +1.
  let segment = self.segment_for_view_line_number(position.line_number)
  let data = self.projections[segment.model_line_number - 1]
  let width = segment.end_offset - segment.start_offset
  // Undo the continuation indent before mapping back to the model column
  // (Monaco's `translateToInputOffset`, which clamps `outputOffset - indent`).
  let projected_column = segment.start_offset +
    @base_common.clamp_int(
      position.column - 1 - segment.wrapped_text_indent_length,
      0,
      width,
    )
  {
    line_number: segment.model_line_number,
    column: data.projected_line.projected_column_to_model_column(
      projected_column,
    ) +
    1,
  }
}

///|
fn ModelLineProjection::hidden_model_position_to_view_position(
  self : ModelLineProjection,
  model_line : Int,
) -> @base_common.Position {
  let mut previous = model_line - 1
  while previous >= 0 {
    let data = self.projections[previous]
    if data.view_line_count() > 0 {
      let view_line = self.model_line_start_view_indices[previous] +
        data.view_line_count() -
        1
      let segment = self.view_line_segments[view_line]
      return Position(
        view_line + 1,
        segment.end_offset -
        segment.start_offset +
        1 +
        segment.wrapped_text_indent_length,
      )
    }
    previous = previous - 1
  }
  for next in (model_line + 1)..<self.projections.length() {
    let data = self.projections[next]
    if data.view_line_count() > 0 {
      return Position(self.model_line_start_view_indices[next] + 1, 1)
    }
  }
  Position(1, 1)
}
