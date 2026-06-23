///|
/// View-line implementation for projected model lines, used for wrapping and
/// injected text.
pub struct ViewModelLinesFromProjectedModel {
  base : ViewModelLinesFromModelAsIs
  projection : ModelLineProjection
  tab_size : Int
}

///|
/// Builds projected view lines from an unwrapped base and line-break computer.
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
/// Number of visible projected view lines.
pub fn ViewModelLinesFromProjectedModel::line_count(
  self : ViewModelLinesFromProjectedModel,
) -> Int {
  self.projection.view_line_count()
}

///|
/// Text for one projected view line segment.
pub fn ViewModelLinesFromProjectedModel::get_view_line_content(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> String {
  let segment = self.projection.segment_for_view_line_number(line_number)
  let line = self.projection.projected_line_for_model_line(
    segment.model_line_number,
  )
  line.text[segment.start_offset:segment.end_offset].to_owned()
}

///|
/// Minimum one-based column in a projected view line.
pub fn ViewModelLinesFromProjectedModel::get_view_line_min_column(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> Int {
  self.projection.segment_for_view_line_number(line_number).start_column
}

///|
/// Maximum one-based column in a projected view line.
pub fn ViewModelLinesFromProjectedModel::get_view_line_max_column(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> Int {
  self.projection.segment_for_view_line_number(line_number).end_column
}

///|
/// Maps a projected view line to its source model line.
pub fn ViewModelLinesFromProjectedModel::model_line_number_of_view_line(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> Int {
  self.projection.segment_for_view_line_number(line_number).model_line_number
}

///|
/// Renders one projected view line segment.
pub fn ViewModelLinesFromProjectedModel::render_line(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
) -> RenderLine {
  let segment = self.projection.segment_for_view_line_number(line_number)
  let projected_line = self.projection.projected_line_for_model_line(
    segment.model_line_number,
  )
  render_projected_line(
    self.base.render_model_line(segment.model_line_number),
    projected_line,
    @base_common.clamp_int(line_number, 1, self.line_count()),
    segment.start_offset,
    segment.end_offset,
  )
}

///|
/// Builds line-renderer input data for one projected view line.
pub fn ViewModelLinesFromProjectedModel::view_line_rendering_data(
  self : ViewModelLinesFromProjectedModel,
  line_number : Int,
  view_decorations? : Array[ViewModelDecoration] = [],
) -> @view_line_renderer.ViewLineRenderingData {
  let segment = self.projection.segment_for_view_line_number(line_number)
  let data = view_line_rendering_data_from_render_line(
    self.render_line(line_number),
    view_decorations~,
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
/// Converts a model position to its projected view position.
pub fn ViewModelLinesFromProjectedModel::model_position_to_view_position(
  self : ViewModelLinesFromProjectedModel,
  position : @base_common.Position,
) -> @base_common.Position {
  self.projection.model_position_to_view_position(position)
}

///|
/// Converts a projected view position back to the nearest model position.
pub fn ViewModelLinesFromProjectedModel::view_position_to_model_position(
  self : ViewModelLinesFromProjectedModel,
  position : @base_common.Position,
) -> @base_common.Position {
  self.projection.view_position_to_model_position(position)
}

///|
fn render_projected_line(
  line : RenderLine,
  projected_line : ProjectedTextLine,
  view_line_number : Int,
  start_offset : Int,
  end_offset : Int,
) -> RenderLine {
  let text = projected_line.text[start_offset:end_offset].to_owned()
  let line_start_offset = line.source_offset_at_column(0)
  let spans : Array[RenderSpan] = []
  let projected_spans = projected_render_spans(line, projected_line)
  append_sliced_projected_spans(
    spans, projected_line, projected_spans, start_offset, end_offset,
  )
  {
    line_number: view_line_number,
    offset: line_start_offset +
    projected_line.projected_column_to_model_column(start_offset),
    text,
    model_columns: projected_model_columns(
      projected_line, start_offset, end_offset,
    ),
    injected_text_indices: projected_injected_text_indices(
      projected_line, start_offset, end_offset,
    ),
    spans,
  }
}

///|
fn projected_render_spans(
  line : RenderLine,
  projected_line : ProjectedTextLine,
) -> Array[RenderSpan] {
  let spans : Array[RenderSpan] = []
  for part in projected_line.parts {
    match part.kind {
      SourceSegment(model_start~, model_end~) =>
        append_source_projected_spans(
          spans,
          line.spans,
          part.start,
          model_start,
          model_end,
        )
      InjectedSegment(model_column~, injected_text_index~, class_name~) =>
        spans.push({
          start: part.start,
          end: part.end,
          source_start: model_column,
          source_end: model_column,
          injected_text_index,
          class_name,
        })
    }
  }
  spans
}

///|
fn append_source_projected_spans(
  out : Array[RenderSpan],
  source_spans : Array[RenderSpan],
  projected_start : Int,
  model_start : Int,
  model_end : Int,
) -> Unit {
  for span in source_spans {
    if span.injected_text_index >= 0 {
      continue
    }
    let start = max_int(span.source_start, model_start)
    let end = min_int(span.source_end, model_end)
    if start < end {
      out.push({
        start: projected_start + (start - model_start),
        end: projected_start + (end - model_start),
        source_start: start,
        source_end: end,
        injected_text_index: -1,
        class_name: span.class_name,
      })
    }
  }
}

///|
fn append_sliced_projected_spans(
  out : Array[RenderSpan],
  projected_line : ProjectedTextLine,
  spans : Array[RenderSpan],
  start_offset : Int,
  end_offset : Int,
) -> Unit {
  for span in spans {
    let start = max_int(span.start, start_offset)
    let end = min_int(span.end, end_offset)
    if start < end {
      out.push({
        start: start - start_offset,
        end: end - start_offset,
        source_start: projected_line.projected_column_to_model_column(start),
        source_end: projected_line.projected_column_to_model_column(end),
        injected_text_index: span.injected_text_index,
        class_name: span.class_name,
      })
    }
  }
}

///|
fn projected_model_columns(
  projected_line : ProjectedTextLine,
  start_offset : Int,
  end_offset : Int,
) -> Array[Int] {
  let columns : Array[Int] = []
  for offset in start_offset..<=end_offset {
    columns.push(projected_line.projected_column_to_model_column(offset))
  }
  columns
}

///|
fn projected_injected_text_indices(
  projected_line : ProjectedTextLine,
  start_offset : Int,
  end_offset : Int,
) -> Array[Int] {
  let indices : Array[Int] = []
  for offset in start_offset..<end_offset {
    indices.push(projected_line.injected_text_index_at_projected_column(offset))
  }
  indices
}

///|
/// Coordinate converter backed by a `ModelLineProjection`.
pub struct ProjectedCoordinatesConverter {
  projection : ModelLineProjection
}

///|
/// Creates a coordinate converter from projected view lines.
pub fn ProjectedCoordinatesConverter::new(
  lines : ViewModelLinesFromProjectedModel,
) -> ProjectedCoordinatesConverter {
  { projection: lines.projection }
}

///|
/// Converts model positions through the projection table.
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn model_position_to_view_position(
  self,
  position,
) {
  self.projection.model_position_to_view_position(position)
}

///|
/// Converts view positions through the projection table.
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn view_position_to_model_position(
  self,
  position,
) {
  self.projection.view_position_to_model_position(position)
}

///|
/// Converts model ranges through the projection table.
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
/// Converts view ranges through the projection table.
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
