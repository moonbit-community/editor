///|
pub struct ModelLineProjection {
  projections : Array[ModelLineProjectionData]
  model_line_start_view_indices : Array[Int]
  view_line_segments : Array[ModelLineProjectionSegment]
}

///|
pub fn ModelLineProjection::build(
  lines : ViewModelLinesFromModelAsIs,
  computer : LineBreaksComputer,
) -> ModelLineProjection {
  let projections : Array[ModelLineProjectionData] = []
  let starts : Array[Int] = []
  let segments : Array[ModelLineProjectionSegment] = []
  for line_index in 0..<lines.line_count() {
    starts.push(segments.length())
    let data = computer.compute_model_line_projection(
      line_index + 1,
      lines.get_view_line_content(line_index + 1),
    )
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
pub fn ModelLineProjection::view_line_count(self : ModelLineProjection) -> Int {
  self.view_line_segments.length()
}

///|
pub fn ModelLineProjection::segment_for_view_line_number(
  self : ModelLineProjection,
  view_line_number : Int,
) -> ModelLineProjectionSegment {
  let index = @core.clamp_int(
    view_line_number - 1,
    0,
    self.view_line_segments.length() - 1,
  )
  self.view_line_segments[index]
}

///|
pub fn ModelLineProjection::model_position_to_view_position(
  self : ModelLineProjection,
  position : @core.Position,
) -> @core.Position {
  let model_line = @core.clamp_int(
    position.line,
    0,
    self.projections.length() - 1,
  )
  let data = self.projections[model_line]
  let model_column = @core.clamp_int(position.column, 0, data.line_length)
  let segment_index = data.view_line_index_for_model_column(model_column)
  let segment = data.segment_at_view_line_index(segment_index)
  {
    line: self.model_line_start_view_indices[model_line] + segment_index,
    column: model_column - segment.start_offset,
  }
}

///|
pub fn ModelLineProjection::view_position_to_model_position(
  self : ModelLineProjection,
  position : @core.Position,
) -> @core.Position {
  let segment = self.segment_for_view_line_number(position.line + 1)
  let width = segment.end_offset - segment.start_offset
  {
    line: segment.model_line_number - 1,
    column: segment.start_offset + @core.clamp_int(position.column, 0, width),
  }
}
