///|
pub(all) struct ModelLineProjectionSegment {
  model_line_number : Int
  start_offset : Int
  end_offset : Int
  start_column : Int
  end_column : Int
  start_visible_column : Int
  continues_with_wrapped_line : Bool
} derive(Eq, Debug)

///|
pub(all) struct ModelLineProjectionData {
  model_line_number : Int
  line_length : Int
  segments : Array[ModelLineProjectionSegment]
} derive(Eq, Debug)

///|
pub fn ModelLineProjectionData::ModelLineProjectionData(
  model_line_number : Int,
  line_length : Int,
  segments : Array[ModelLineProjectionSegment],
) -> ModelLineProjectionData {
  { model_line_number, line_length, segments }
}

///|
pub fn ModelLineProjectionData::view_line_count(
  self : ModelLineProjectionData,
) -> Int {
  self.segments.length()
}

///|
pub fn ModelLineProjectionData::segment_at_view_line_index(
  self : ModelLineProjectionData,
  index : Int,
) -> ModelLineProjectionSegment {
  let index = @core.clamp_int(index, 0, self.segments.length() - 1)
  self.segments[index]
}

///|
pub fn ModelLineProjectionData::view_line_index_for_model_column(
  self : ModelLineProjectionData,
  column : Int,
) -> Int {
  let column = @core.clamp_int(column, 0, self.line_length)
  for index in 0..<self.segments.length() {
    let segment = self.segments[index]
    if column < segment.end_offset || index + 1 == self.segments.length() {
      return index
    }
  }
  self.segments.length() - 1
}

///|
fn model_line_projection_segment(
  model_line_number : Int,
  start_offset : Int,
  end_offset : Int,
  start_visible_column : Int,
  continues_with_wrapped_line : Bool,
) -> ModelLineProjectionSegment {
  {
    model_line_number,
    start_offset,
    end_offset,
    start_column: start_offset + 1,
    end_column: end_offset + 1,
    start_visible_column,
    continues_with_wrapped_line,
  }
}
