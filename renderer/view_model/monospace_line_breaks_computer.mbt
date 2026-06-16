///|
pub(all) struct LineBreaksComputer {
  wrapping_column : Int
  tab_size : Int
} derive(Eq, Debug)

///|
pub fn LineBreaksComputer::LineBreaksComputer(
  wrapping_column : Int,
  tab_size? : Int = 2,
) -> LineBreaksComputer {
  {
    wrapping_column: max_int(wrapping_column, 0),
    tab_size: max_int(tab_size, 1),
  }
}

///|
pub fn LineBreaksComputer::compute_model_line_projection(
  self : LineBreaksComputer,
  model_line_number : Int,
  line_text : String,
) -> ModelLineProjectionData {
  if self.wrapping_column <= 0 {
    return ModelLineProjectionData(model_line_number, line_text.length(), [
      model_line_projection_segment(
        model_line_number,
        0,
        line_text.length(),
        0,
        false,
      ),
    ])
  }
  let segments : Array[ModelLineProjectionSegment] = []
  let mut segment_start = 0
  let mut segment_start_visible_column = 0
  let mut visible_column = 0
  for offset in 0..<line_text.length() {
    let width = code_unit_width(
      line_text[offset].to_int(),
      visible_column,
      self.tab_size,
    )
    if offset > segment_start &&
      visible_column - segment_start_visible_column + width >
      self.wrapping_column {
      segments.push(
        model_line_projection_segment(
          model_line_number,
          segment_start,
          offset,
          segment_start_visible_column,
          segment_start > 0,
        ),
      )
      segment_start = offset
      segment_start_visible_column = visible_column
    }
    visible_column = visible_column + width
  }
  segments.push(
    model_line_projection_segment(
      model_line_number,
      segment_start,
      line_text.length(),
      segment_start_visible_column,
      segment_start > 0,
    ),
  )
  ModelLineProjectionData(model_line_number, line_text.length(), segments)
}

///|
fn code_unit_width(code : Int, visible_column : Int, tab_size : Int) -> Int {
  if code == 9 {
    let remainder = visible_column % tab_size
    if remainder == 0 {
      tab_size
    } else {
      tab_size - remainder
    }
  } else if code > 0xff {
    2
  } else {
    1
  }
}
