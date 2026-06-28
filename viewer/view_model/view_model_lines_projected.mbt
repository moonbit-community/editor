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
    self.base.model_line_tokens(segment.model_line_number),
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
/// Builds one view line the Monaco `getViewLinesData` way: splice the injected
/// text into the model line's tokens with `with_inserted`
/// (`getLineTokensWithInjections`), then slice the output line's segment with
/// `slice_and_inflate` (`_getViewLineData`). Injected-text classes become inline
/// decorations (`InjectedTextInlineDecorationsComputer`), never token colors —
/// the spliced injected tokens carry only default syntactic metadata.
fn render_projected_line(
  line : RenderLine,
  base_tokens : LineTokens,
  projected_line : ProjectedTextLine,
  view_line_number : Int,
  start_offset : Int,
  end_offset : Int,
) -> RenderLine {
  let text = projected_line.text[start_offset:end_offset].to_owned()
  let line_start_offset = line.source_offset_at_column(0)
  let with_injections = base_tokens.with_inserted(
    injected_tokens_for_projected_line(projected_line),
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
    tokens: with_injections.slice_and_inflate(start_offset, end_offset, 0),
    injected_inline_decorations: projected_injected_inline_decorations(
      projected_line, start_offset, end_offset,
    ),
  }
}

///|
/// The injected text of a projected line as `with_inserted` splice tokens —
/// Monaco's `getLineTokensWithInjections`. Each run inserts at its 0-based model
/// column with default token metadata (no per-token color); the inlay color is
/// applied as an inline decoration instead. Offsets are ascending, satisfying
/// `with_inserted`'s precondition.
fn injected_tokens_for_projected_line(
  projected_line : ProjectedTextLine,
) -> Array[InsertedToken] {
  let inserts : Array[InsertedToken] = []
  for part in projected_line.parts {
    match part.kind {
      InjectedSegment(model_column~, ..) =>
        inserts.push(
          InsertedToken::new(
            model_column,
            projected_line.text[part.start:part.end].to_owned(),
            LineTokens::default_token_metadata(),
          ),
        )
      SourceSegment(_) => ()
    }
  }
  inserts
}

///|
/// Inline decorations for the injected text of a projected line, clipped to the
/// output (view-local) segment `[start_offset, end_offset)` — Monaco's
/// `InjectedTextInlineDecorationsComputer.getInlineDecorations`. Each injected
/// run with a class emits one decoration over its projected columns.
fn projected_injected_inline_decorations(
  projected_line : ProjectedTextLine,
  start_offset : Int,
  end_offset : Int,
) -> Array[@view_line_renderer.InlineDecoration] {
  let decorations : Array[@view_line_renderer.InlineDecoration] = []
  for part in projected_line.parts {
    match part.kind {
      InjectedSegment(class_name~, ..) => {
        let start = part.start.max(start_offset)
        let end = part.end.min(end_offset)
        if start < end {
          decorations.push(
            InlineDecoration(
              OffsetRange(start - start_offset, end - start_offset),
              class_name,
            ),
          )
        }
      }
      SourceSegment(_) => ()
    }
  }
  decorations
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
    Position(range.start_line_number, range.start_column),
  )
  let end = self.model_position_to_view_position(
    Position(range.end_line_number, range.end_column),
  )
  {
    start_line_number: start.line_number,
    start_column: start.column,
    end_line_number: end.line_number,
    end_column: end.column,
  }
}

///|
/// Converts view ranges through the projection table.
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn view_range_to_model_range(
  self,
  range,
) {
  let start = self.view_position_to_model_position(
    Position(range.start_line_number, range.start_column),
  )
  let end = self.view_position_to_model_position(
    Position(range.end_line_number, range.end_column),
  )
  {
    start_line_number: start.line_number,
    start_column: start.column,
    end_line_number: end.line_number,
    end_column: end.column,
  }
}
