///|
pub struct ViewModelLinesFromProjectedModel {
  base : ViewModelLinesFromModelAsIs
  projection : ModelLineProjection
  tab_size : Int
}

///|
pub fn ViewModelLinesFromProjectedModel::new(
  base : ViewModelLinesFromModelAsIs,
  computer : LineBreaksComputer,
) -> ViewModelLinesFromProjectedModel {
  {
    base,
    projection: ModelLineProjection::build(base, computer),
    tab_size: computer.tab_size,
  }
}

///|
pub fn ViewModelLinesFromProjectedModel::line_count(
  self : ViewModelLinesFromProjectedModel,
) -> Int {
  self.projection.view_line_count()
}

///|
pub fn ViewModelLinesFromProjectedModel::get_view_line_content(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> String {
  let segment = self.projection.segment_for_view_line_number(line_number)
  let text = self.base.get_model_line_content(segment.model_line_number)
  text[segment.start_offset:segment.end_offset].to_owned()
}

///|
pub fn ViewModelLinesFromProjectedModel::get_view_line_min_column(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> Int {
  self.projection.segment_for_view_line_number(line_number).start_column
}

///|
pub fn ViewModelLinesFromProjectedModel::get_view_line_max_column(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> Int {
  self.projection.segment_for_view_line_number(line_number).end_column
}

///|
pub fn ViewModelLinesFromProjectedModel::model_line_number_of_view_line(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> Int {
  self.projection.segment_for_view_line_number(line_number).model_line_number
}

///|
pub fn ViewModelLinesFromProjectedModel::render_line(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> RenderLine {
  let segment = self.projection.segment_for_view_line_number(line_number)
  slice_render_line(
    self.base.render_model_line(segment.model_line_number),
    @core.clamp_int(line_number, 1, self.line_count()),
    segment.start_offset,
    segment.end_offset,
  )
}

///|
pub fn ViewModelLinesFromProjectedModel::view_line_rendering_data(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
  decorations? : Array[@decorations.Decoration] = [],
) -> @view_line_renderer.ViewLineRenderingData {
  let segment = self.projection.segment_for_view_line_number(line_number)
  let data = view_line_rendering_data_from_render_line(
    self.render_line(line_number),
    decorations~,
  )
  {
    ..data,
    min_column: segment.start_column,
    max_column: segment.end_column,
    continues_with_wrapped_line: segment.continues_with_wrapped_line,
    tab_size: self.tab_size,
    start_visible_column: segment.start_visible_column,
  }
}

///|
pub fn ViewModelLinesFromProjectedModel::model_position_to_view_position(
  self : ViewModelLinesFromProjectedModel,
  position : @core.Position,
) -> @core.Position {
  self.projection.model_position_to_view_position(position)
}

///|
pub fn ViewModelLinesFromProjectedModel::view_position_to_model_position(
  self : ViewModelLinesFromProjectedModel,
  position : @core.Position,
) -> @core.Position {
  self.projection.view_position_to_model_position(position)
}

///|
fn slice_render_line(
  line : RenderLine,
  view_line_number : Int,
  start_offset : Int,
  end_offset : Int,
) -> RenderLine {
  let text = line.text[start_offset:end_offset].to_owned()
  let spans : Array[RenderSpan] = []
  for span in line.spans {
    let start = max_int(span.start, start_offset)
    let end = min_int(span.end, end_offset)
    if start < end {
      spans.push({
        start: start - start_offset,
        end: end - start_offset,
        class_name: span.class_name,
      })
    }
  }
  {
    line_number: view_line_number,
    offset: line.offset + start_offset,
    text,
    spans,
  }
}

///|
pub struct ProjectedCoordinatesConverter {
  projection : ModelLineProjection
}

///|
pub fn ProjectedCoordinatesConverter::new(
  lines : ViewModelLinesFromProjectedModel,
) -> ProjectedCoordinatesConverter {
  { projection: lines.projection }
}

///|
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn model_position_to_view_position(
  self,
  position,
) {
  self.projection.model_position_to_view_position(position)
}

///|
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn view_position_to_model_position(
  self,
  position,
) {
  self.projection.view_position_to_model_position(position)
}

///|
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn model_range_to_view_range(
  self,
  range,
) {
  let start = self.model_position_to_view_position(
    Position(range.start_line_number - 1, range.start_column - 1),
  )
  let end = self.model_position_to_view_position(
    Position(range.end_line_number - 1, range.end_column - 1),
  )
  {
    start_line_number: start.line + 1,
    start_column: start.column + 1,
    end_line_number: end.line + 1,
    end_column: end.column + 1,
  }
}

///|
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn view_range_to_model_range(
  self,
  range,
) {
  let start = self.view_position_to_model_position(
    Position(range.start_line_number - 1, range.start_column - 1),
  )
  let end = self.view_position_to_model_position(
    Position(range.end_line_number - 1, range.end_column - 1),
  )
  {
    start_line_number: start.line + 1,
    start_column: start.column + 1,
    end_line_number: end.line + 1,
    end_column: end.column + 1,
  }
}
