///|
pub(open) trait CoordinatesConverter {
  fn model_position_to_view_position(Self, @core.Position) -> @core.Position
  fn view_position_to_model_position(Self, @core.Position) -> @core.Position
  fn model_range_to_view_range(Self, @view_line_renderer.ViewRange) -> @view_line_renderer.ViewRange
  fn view_range_to_model_range(Self, @view_line_renderer.ViewRange) -> @view_line_renderer.ViewRange
}

///|
pub struct IdentityCoordinatesConverter {
  identity : Unit
}

///|
pub fn IdentityCoordinatesConverter::new() -> IdentityCoordinatesConverter {
  { identity: () }
}

///|
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn model_position_to_view_position(
  _self,
  position,
) {
  position
}

///|
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn view_position_to_model_position(
  _self,
  position,
) {
  position
}

///|
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn model_range_to_view_range(
  _self,
  range,
) {
  range
}

///|
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn view_range_to_model_range(
  _self,
  range,
) {
  range
}

///|
pub struct ViewModelDecorations {
  line_decorations : Array[Array[@decorations.Decoration]]
}

///|
pub fn ViewModelDecorations::from_frame_source(
  source : FrameSource,
) -> ViewModelDecorations {
  { line_decorations: source.line_decorations }
}

///|
pub fn ViewModelDecorations::decorations_for_line(
  self : ViewModelDecorations,
  line_number : Int,
) -> Array[@decorations.Decoration] {
  let index = line_number - 1
  match self.line_decorations.get(index) {
    Some(decorations) => decorations
    None => []
  }
}

///|
pub struct ViewModelLinesFromModelAsIs {
  source : FrameSource
}

///|
pub fn ViewModelLinesFromModelAsIs::new(
  source : FrameSource,
) -> ViewModelLinesFromModelAsIs {
  { source, }
}

///|
pub fn ViewModelLinesFromModelAsIs::line_count(
  self : ViewModelLinesFromModelAsIs,
) -> Int {
  self.source.tokenized.snapshot.line_count()
}

///|
pub fn ViewModelLinesFromModelAsIs::get_view_line_content(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> String {
  let line_index = self.clamped_line_index(line_number)
  self.source.tokenized.snapshot.line_text(line_index)
}

///|
pub fn ViewModelLinesFromModelAsIs::get_view_line_min_column(
  _self : ViewModelLinesFromModelAsIs,
  _line_number : Int,
) -> Int {
  1
}

///|
pub fn ViewModelLinesFromModelAsIs::get_view_line_max_column(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> Int {
  self.get_view_line_content(line_number).length() + 1
}

///|
pub fn ViewModelLinesFromModelAsIs::model_line_number_of_view_line(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> Int {
  self.clamped_line_index(line_number) + 1
}

///|
pub fn ViewModelLinesFromModelAsIs::render_line(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> RenderLine {
  let doc = self.source.tokenized.snapshot
  let line_index = self.clamped_line_index(line_number)
  let line_start = doc.line_start_offset(line_index)
  let line_end = doc.line_end_offset(line_index)
  let line_range = @core.Range(line_start, line_end)
  let spans = overlay_semantic_tokens(
    spans_for_line(
      line_range,
      self.source.tokenized.tokens_for_line(line_index),
      self.source.line_decorations[line_index],
    ),
    line_range,
    self.source.line_semantic_tokens[line_index],
  )
  {
    line_number: line_index + 1,
    offset: line_start,
    text: doc.line_text(line_index),
    spans,
  }
}

///|
pub fn ViewModelLinesFromModelAsIs::view_line_rendering_data(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
  decorations? : Array[@decorations.Decoration] = [],
) -> @view_line_renderer.ViewLineRenderingData {
  view_line_rendering_data_from_render_line(
    self.render_line(line_number),
    decorations~,
  )
}

///|
fn ViewModelLinesFromModelAsIs::clamped_line_index(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> Int {
  @core.clamp_int(line_number - 1, 0, self.line_count() - 1)
}

///|
pub struct ViewModel {
  lines : ViewModelLinesFromModelAsIs
  decorations : ViewModelDecorations
  coordinates_converter : IdentityCoordinatesConverter
}

///|
pub fn ViewModel::ViewModel(source : FrameSource) -> ViewModel {
  {
    lines: ViewModelLinesFromModelAsIs::new(source),
    decorations: ViewModelDecorations::from_frame_source(source),
    coordinates_converter: IdentityCoordinatesConverter::new(),
  }
}

///|
pub fn ViewModel::lines(self : ViewModel) -> ViewModelLinesFromModelAsIs {
  self.lines
}

///|
pub fn ViewModel::decorations(self : ViewModel) -> ViewModelDecorations {
  self.decorations
}

///|
pub fn ViewModel::coordinates_converter(
  self : ViewModel,
) -> IdentityCoordinatesConverter {
  self.coordinates_converter
}

///|
pub fn ViewModel::line_count(self : ViewModel) -> Int {
  self.lines.line_count()
}

///|
pub fn ViewModel::version(self : ViewModel) -> Int {
  self.lines.source.tokenized.snapshot.version
}

///|
pub fn ViewModel::language_id(self : ViewModel) -> String {
  self.lines.source.tokenized.snapshot.language_id
}

///|
pub fn ViewModel::render_frame(
  self : ViewModel,
  viewport : FrameViewport,
) -> RenderFrame {
  let start_line = @core.clamp_int(
    viewport.start_line,
    0,
    self.line_count() - 1,
  )
  let end_line = @core.clamp_int(
    viewport.end_line,
    start_line + 1,
    self.line_count(),
  )
  let lines : Array[RenderLine] = []
  for line in start_line..<end_line {
    lines.push(self.lines.render_line(line + 1))
  }
  {
    version: self.version(),
    language_id: self.language_id(),
    line_count: self.line_count(),
    viewport: { start_line, end_line },
    lines,
    diagnostics: self.lines.source.providers.diagnostics,
    hovers: self.lines.source.providers.hovers,
  }
}

///|
pub fn ViewModel::viewport_data(
  self : ViewModel,
  window : @view_layout.LineWindow,
  line_height~ : Int,
  decorations? : Array[@decorations.Decoration] = [],
) -> ViewportData {
  let start_line = @core.clamp_int(window.start, 0, self.line_count() - 1)
  let end_line = @core.clamp_int(window.end, start_line + 1, self.line_count())
  let lines : Array[@view_line_renderer.ViewLineRenderingData] = []
  let line_decorations : Array[Array[@view_line_renderer.LineDecoration]] = []
  let relative_vertical_offset : Array[Int] = []
  for index in start_line..<end_line {
    let render_line = self.lines.render_line(index + 1)
    lines.push(
      view_line_rendering_data_from_render_line(render_line, decorations~),
    )
    line_decorations.push(line_decorations_for_line(render_line, decorations))
    relative_vertical_offset.push((index - start_line) * line_height)
  }
  let start_line_number = start_line + 1
  let end_line_number = end_line
  let end_column = match lines.last() {
    Some(line) => line.max_column
    None => 1
  }
  {
    start_line_number,
    end_line_number,
    relative_vertical_offset,
    line_height,
    visible_range: {
      start_line_number,
      start_column: 1,
      end_line_number,
      end_column,
    },
    big_numbers_delta: 0,
    lines,
    line_decorations,
  }
}
