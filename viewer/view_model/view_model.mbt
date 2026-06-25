///|
/// Converts between model document coordinates and rendered view coordinates.
pub(open) trait CoordinatesConverter {
  fn model_position_to_view_position(Self, @base_common.Position) -> @base_common.Position
  fn view_position_to_model_position(Self, @base_common.Position) -> @base_common.Position
  fn model_range_to_view_range(Self, @view_line_renderer.ViewRange) -> @view_line_renderer.ViewRange
  fn view_range_to_model_range(Self, @view_line_renderer.ViewRange) -> @view_line_renderer.ViewRange
}

///|
/// Converter for the no-wrap, no-projection case where model and view
/// coordinates are identical.
pub struct IdentityCoordinatesConverter {
  identity : Unit
}

///|
/// Creates an identity coordinate converter.
pub fn IdentityCoordinatesConverter::new() -> IdentityCoordinatesConverter {
  { identity: () }
}

///|
/// Identity model-to-view position conversion.
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn model_position_to_view_position(
  _self,
  position,
) {
  position
}

///|
/// Identity view-to-model position conversion.
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn view_position_to_model_position(
  _self,
  position,
) {
  position
}

///|
/// Identity model-to-view range conversion.
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn model_range_to_view_range(
  _self,
  range,
) {
  range
}

///|
/// Identity view-to-model range conversion.
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn view_range_to_model_range(
  _self,
  range,
) {
  range
}

///|
/// Active coordinate converter variant for a view model.
pub(all) enum ViewModelCoordinatesConverter {
  Identity(IdentityCoordinatesConverter)
  Projected(ProjectedCoordinatesConverter)
}

///|
/// Dispatches model-to-view position conversion to the active converter.
pub impl CoordinatesConverter for ViewModelCoordinatesConverter with fn model_position_to_view_position(
  self,
  position,
) {
  match self {
    Identity(converter) => converter.model_position_to_view_position(position)
    Projected(converter) => converter.model_position_to_view_position(position)
  }
}

///|
/// Dispatches view-to-model position conversion to the active converter.
pub impl CoordinatesConverter for ViewModelCoordinatesConverter with fn view_position_to_model_position(
  self,
  position,
) {
  match self {
    Identity(converter) => converter.view_position_to_model_position(position)
    Projected(converter) => converter.view_position_to_model_position(position)
  }
}

///|
/// Dispatches model-to-view range conversion to the active converter.
pub impl CoordinatesConverter for ViewModelCoordinatesConverter with fn model_range_to_view_range(
  self,
  range,
) {
  match self {
    Identity(converter) => converter.model_range_to_view_range(range)
    Projected(converter) => converter.model_range_to_view_range(range)
  }
}

///|
/// Dispatches view-to-model range conversion to the active converter.
pub impl CoordinatesConverter for ViewModelCoordinatesConverter with fn view_range_to_model_range(
  self,
  range,
) {
  match self {
    Identity(converter) => converter.view_range_to_model_range(range)
    Projected(converter) => converter.view_range_to_model_range(range)
  }
}

///|
/// View lines that preserve one visible view line per visible model line.
pub struct ViewModelLinesFromModelAsIs {
  source : FrameSource
  visible_model_line_numbers : Array[Int]
  hidden_model_lines : Array[Bool]
  injected_text_by_model_line : Array[Array[InjectedText]]
}

///|
/// Creates unprojected view lines with every model line visible.
pub fn ViewModelLinesFromModelAsIs::new(
  source : FrameSource,
) -> ViewModelLinesFromModelAsIs {
  ViewModelLinesFromModelAsIs::with_injected_text(source, [])
}

///|
/// Creates unwrapped view lines with injected text projected into each model
/// line.
pub fn ViewModelLinesFromModelAsIs::with_injected_text(
  source : FrameSource,
  injected_text : Array[InjectedText],
) -> ViewModelLinesFromModelAsIs {
  let line_count = source.tokenized.snapshot.line_count()
  let visible_model_line_numbers : Array[Int] = []
  let hidden_model_lines : Array[Bool] = []
  for line_number in 1..<=line_count {
    visible_model_line_numbers.push(line_number)
    hidden_model_lines.push(false)
  }
  {
    source,
    visible_model_line_numbers,
    hidden_model_lines,
    injected_text_by_model_line: bucket_injected_text(
      source.tokenized.snapshot,
      injected_text,
    ),
  }
}

///|
/// Creates unwrapped view lines while hiding folded model lines.
pub fn ViewModelLinesFromModelAsIs::with_folding_model(
  source : FrameSource,
  folding_model : FoldingModel,
) -> ViewModelLinesFromModelAsIs {
  ViewModelLinesFromModelAsIs::with_folding_model_and_injected_text(
    source,
    folding_model,
    [],
  )
}

///|
/// Creates unwrapped view lines with folding and injected text applied.
pub fn ViewModelLinesFromModelAsIs::with_folding_model_and_injected_text(
  source : FrameSource,
  folding_model : FoldingModel,
  injected_text : Array[InjectedText],
) -> ViewModelLinesFromModelAsIs {
  let line_count = source.tokenized.snapshot.line_count()
  let visible_model_line_numbers : Array[Int] = []
  let hidden_model_lines : Array[Bool] = []
  for line_number in 1..<=line_count {
    let hidden = folding_model.is_line_hidden(line_number)
    hidden_model_lines.push(hidden)
    if !hidden {
      visible_model_line_numbers.push(line_number)
    }
  }
  {
    source,
    visible_model_line_numbers,
    hidden_model_lines,
    injected_text_by_model_line: bucket_injected_text(
      source.tokenized.snapshot,
      injected_text,
    ),
  }
}

///|
/// Number of visible view lines.
pub fn ViewModelLinesFromModelAsIs::line_count(
  self : ViewModelLinesFromModelAsIs,
) -> Int {
  self.visible_model_line_numbers.length()
}

///|
/// Number of model lines in the source document.
pub fn ViewModelLinesFromModelAsIs::model_line_count(
  self : ViewModelLinesFromModelAsIs,
) -> Int {
  self.source.tokenized.snapshot.line_count()
}

///|
/// Whether a one-based model line is hidden by folding.
pub fn ViewModelLinesFromModelAsIs::is_model_line_hidden(
  self : ViewModelLinesFromModelAsIs,
  model_line_number : Int,
) -> Bool {
  match self.hidden_model_lines.get(model_line_number - 1) {
    Some(hidden) => hidden
    None => false
  }
}

///|
/// Returns the text of a one-based model line.
pub fn ViewModelLinesFromModelAsIs::get_model_line_content(
  self : ViewModelLinesFromModelAsIs,
  model_line_number : Int,
) -> String {
  let line_index = self.clamped_model_line_index(model_line_number)
  self.source.tokenized.snapshot.line_text(line_index)
}

///|
/// Returns the text of a one-based view line.
pub fn ViewModelLinesFromModelAsIs::get_view_line_content(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> String {
  self.get_model_line_content(self.model_line_number_of_view_line(line_number))
}

///|
/// Returns projected text for a one-based model line, including inlay hints.
pub fn ViewModelLinesFromModelAsIs::projected_text_line(
  self : ViewModelLinesFromModelAsIs,
  model_line_number : Int,
) -> ProjectedTextLine {
  let line_text = self.get_model_line_content(model_line_number)
  match self.injected_text_by_model_line.get(model_line_number - 1) {
    Some(injected_text) =>
      ProjectedTextLine::from_injected_text(line_text, injected_text)
    None => ProjectedTextLine::identity(line_text)
  }
}

///|
/// Minimum one-based column in an unwrapped view line.
pub fn ViewModelLinesFromModelAsIs::get_view_line_min_column(
  _self : ViewModelLinesFromModelAsIs,
  _line_number : Int,
) -> Int {
  1
}

///|
/// Maximum one-based column in an unwrapped view line.
pub fn ViewModelLinesFromModelAsIs::get_view_line_max_column(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> Int {
  self.get_view_line_content(line_number).length() + 1
}

///|
/// Maps a one-based view line number to its one-based model line number.
pub fn ViewModelLinesFromModelAsIs::model_line_number_of_view_line(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> Int {
  let index = self.clamped_line_index(line_number)
  self.visible_model_line_numbers[index]
}

///|
/// Renders a one-based view line.
pub fn ViewModelLinesFromModelAsIs::render_line(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> RenderLine {
  self.render_model_line(self.model_line_number_of_view_line(line_number))
}

///|
/// Renders a one-based model line regardless of folding visibility.
pub fn ViewModelLinesFromModelAsIs::render_model_line(
  self : ViewModelLinesFromModelAsIs,
  model_line_number : Int,
) -> RenderLine {
  let doc = self.source.tokenized.snapshot
  let line_index = self.clamped_model_line_index(model_line_number)
  let line_start = doc.line_start_offset(line_index)
  let line_end = doc.line_end_offset(line_index)
  let line_range = @base_common.OffsetRange(line_start, line_end)
  let spans = overlay_semantic_tokens(
    spans_for_line(
      line_range,
      self.source.tokenized.tokens_for_line(line_index),
    ),
    line_range,
    self.source.line_semantic_tokens[line_index],
  )
  {
    line_number: line_index + 1,
    offset: line_start,
    text: doc.line_text(line_index),
    model_columns: identity_model_columns(line_end - line_start),
    injected_text_indices: identity_injected_text_indices(line_end - line_start),
    spans,
  }
}

///|
/// Builds line-renderer input data for a one-based view line.
pub fn ViewModelLinesFromModelAsIs::view_line_rendering_data(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
  view_decorations? : Array[ViewModelDecoration] = [],
) -> @view_line_renderer.ViewLineRenderingData {
  view_line_rendering_data_from_render_line(
    self.render_line(line_number),
    view_decorations~,
  )
}

///|
fn ViewModelLinesFromModelAsIs::clamped_line_index(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> Int {
  @base_common.clamp_int(line_number - 1, 0, self.line_count() - 1)
}

///|
fn ViewModelLinesFromModelAsIs::clamped_model_line_index(
  self : ViewModelLinesFromModelAsIs,
  model_line_number : Int,
) -> Int {
  @base_common.clamp_int(model_line_number - 1, 0, self.model_line_count() - 1)
}

///|
fn bucket_injected_text(
  snapshot : @model.TextSnapshot,
  injected_text : Array[InjectedText],
) -> Array[Array[InjectedText]] {
  let buckets : Array[Array[InjectedText]] = []
  for _ in 0..<snapshot.line_count() {
    buckets.push([])
  }
  for item in injected_text {
    // Provider/inlay-hint positions are 1-based (Monaco); the projection
    // pipeline (`ProjectedTextLine::from_injected_text`) consumes 0-based model
    // line/column, so this boundary converts once and stores 0-based.
    let line = @base_common.clamp_int(
      item.position.line_number - 1,
      0,
      snapshot.line_count() - 1,
    )
    let line_text = snapshot.line_text(line)
    let column = @base_common.clamp_int(
      item.position.column - 1,
      0,
      line_text.length(),
    )
    if item.text.length() > 0 {
      buckets[line].push({ ..item, position: { line_number: line, column } })
    }
  }
  for bucket in buckets {
    bucket.sort_by((left, right) => {
      if left.position.column != right.position.column {
        left.position.column - right.position.column
      } else {
        left.source_index - right.source_index
      }
    })
  }
  buckets
}

///|
fn identity_model_columns(line_length : Int) -> Array[Int] {
  let columns : Array[Int] = []
  for column in 0..<=line_length {
    columns.push(column)
  }
  columns
}

///|
fn identity_injected_text_indices(line_length : Int) -> Array[Int] {
  let indices : Array[Int] = []
  for _ in 0..<line_length {
    indices.push(-1)
  }
  indices
}

///|
/// View-line implementation selected by the active view model options.
pub(all) enum ViewModelLines {
  ModelAsIs(ViewModelLinesFromModelAsIs)
  ProjectedModel(ViewModelLinesFromProjectedModel)
}

///|
/// Number of visible view lines.
pub fn ViewModelLines::line_count(self : ViewModelLines) -> Int {
  match self {
    ModelAsIs(lines) => lines.line_count()
    ProjectedModel(lines) => lines.line_count()
  }
}

///|
/// Returns text for a one-based view line.
pub fn ViewModelLines::get_view_line_content(
  self : ViewModelLines,
  line_number : Int,
) -> String {
  match self {
    ModelAsIs(lines) => lines.get_view_line_content(line_number)
    ProjectedModel(lines) => lines.get_view_line_content(line_number)
  }
}

///|
/// Minimum one-based column for a view line.
pub fn ViewModelLines::get_view_line_min_column(
  self : ViewModelLines,
  line_number : Int,
) -> Int {
  match self {
    ModelAsIs(lines) => lines.get_view_line_min_column(line_number)
    ProjectedModel(lines) => lines.get_view_line_min_column(line_number)
  }
}

///|
/// Maximum one-based column for a view line.
pub fn ViewModelLines::get_view_line_max_column(
  self : ViewModelLines,
  line_number : Int,
) -> Int {
  match self {
    ModelAsIs(lines) => lines.get_view_line_max_column(line_number)
    ProjectedModel(lines) => lines.get_view_line_max_column(line_number)
  }
}

///|
/// Maps a one-based view line to its one-based model line.
pub fn ViewModelLines::model_line_number_of_view_line(
  self : ViewModelLines,
  line_number : Int,
) -> Int {
  match self {
    ModelAsIs(lines) => lines.model_line_number_of_view_line(line_number)
    ProjectedModel(lines) => lines.model_line_number_of_view_line(line_number)
  }
}

///|
/// Renders a one-based view line.
pub fn ViewModelLines::render_line(
  self : ViewModelLines,
  line_number : Int,
) -> RenderLine {
  match self {
    ModelAsIs(lines) => lines.render_line(line_number)
    ProjectedModel(lines) => lines.render_line(line_number)
  }
}

///|
/// Builds line-renderer input data for a one-based view line.
pub fn ViewModelLines::view_line_rendering_data(
  self : ViewModelLines,
  line_number : Int,
  view_decorations? : Array[ViewModelDecoration] = [],
) -> @view_line_renderer.ViewLineRenderingData {
  match self {
    ModelAsIs(lines) =>
      lines.view_line_rendering_data(line_number, view_decorations~)
    ProjectedModel(lines) =>
      lines.view_line_rendering_data(line_number, view_decorations~)
  }
}

///|
/// Backend-neutral document view model: source data plus line projection,
/// decorations, and coordinate conversion.
pub struct ViewModel {
  source : FrameSource
  lines : ViewModelLines
  decorations : ViewModelDecorations
  coordinates_converter : ViewModelCoordinatesConverter
}

///|
/// Creates a view model with default no-wrap options.
pub fn ViewModel::ViewModel(source : FrameSource) -> ViewModel {
  ViewModel::with_options(source, ViewModelOptions::no_wrap())
}

///|
/// Creates a view model with wrapping/tab options.
pub fn ViewModel::with_options(
  source : FrameSource,
  options : ViewModelOptions,
) -> ViewModel {
  let as_is = ViewModelLinesFromModelAsIs::new(source)
  ViewModel::from_lines(source, options, as_is, force_projected=false)
}

///|
/// Creates a view model with wrapping/tab options and inlay hints.
pub fn ViewModel::with_options_and_inlay_hints(
  source : FrameSource,
  options : ViewModelOptions,
  inlay_hints : Array[@language.InlayHint],
) -> ViewModel {
  let injected_text = injected_text_from_inlay_hints(inlay_hints)
  let as_is = ViewModelLinesFromModelAsIs::with_injected_text(
    source, injected_text,
  )
  ViewModel::from_lines(
    source,
    options,
    as_is,
    force_projected=injected_text.length() > 0,
  )
}

///|
/// Creates a view model with wrapping/tab options and folding.
pub fn ViewModel::with_options_and_folding(
  source : FrameSource,
  options : ViewModelOptions,
  folding_model : FoldingModel,
) -> ViewModel {
  let as_is = ViewModelLinesFromModelAsIs::with_folding_model(
    source, folding_model,
  )
  ViewModel::from_lines(source, options, as_is, force_projected=true)
}

///|
/// Creates a view model with wrapping/tab options, folding, and inlay hints.
pub fn ViewModel::with_options_folding_and_inlay_hints(
  source : FrameSource,
  options : ViewModelOptions,
  folding_model : FoldingModel,
  inlay_hints : Array[@language.InlayHint],
) -> ViewModel {
  let injected_text = injected_text_from_inlay_hints(inlay_hints)
  let as_is = ViewModelLinesFromModelAsIs::with_folding_model_and_injected_text(
    source, folding_model, injected_text,
  )
  ViewModel::from_lines(source, options, as_is, force_projected=true)
}

///|
fn ViewModel::from_lines(
  source : FrameSource,
  options : ViewModelOptions,
  as_is : ViewModelLinesFromModelAsIs,
  force_projected~ : Bool,
) -> ViewModel {
  let (lines, coordinates_converter) = if options.is_soft_wrap_enabled() {
    let projected = ViewModelLinesFromProjectedModel::new(
      as_is,
      LineBreaksComputer(options.soft_wrap_column, tab_size=options.tab_size),
    )
    (
      ProjectedModel(projected),
      Projected(ProjectedCoordinatesConverter::new(projected)),
    )
  } else if force_projected {
    let projected = ViewModelLinesFromProjectedModel::new(
      as_is,
      LineBreaksComputer(0, tab_size=options.tab_size),
    )
    (
      ProjectedModel(projected),
      Projected(ProjectedCoordinatesConverter::new(projected)),
    )
  } else {
    (ModelAsIs(as_is), Identity(IdentityCoordinatesConverter::new()))
  }
  {
    source,
    lines,
    decorations: ViewModelDecorations::new(
      coordinates_converter,
      source.decorations,
    ),
    coordinates_converter,
  }
}

///|
/// Active line model for this view model.
pub fn ViewModel::lines(self : ViewModel) -> ViewModelLines {
  self.lines
}

///|
/// Decoration buckets for this view model.
pub fn ViewModel::decorations(self : ViewModel) -> ViewModelDecorations {
  self.decorations
}

///|
/// Coordinate converter selected for this view model.
pub fn ViewModel::coordinates_converter(
  self : ViewModel,
) -> ViewModelCoordinatesConverter {
  self.coordinates_converter
}

///|
/// Number of visible view lines.
pub fn ViewModel::line_count(self : ViewModel) -> Int {
  self.lines.line_count()
}

///|
/// Source document version.
pub fn ViewModel::version(self : ViewModel) -> Int {
  self.source.tokenized.snapshot.version
}

///|
/// Source document language id.
pub fn ViewModel::language_id(self : ViewModel) -> String {
  self.source.tokenized.snapshot.language_id
}

///|
/// Builds a render frame for the requested zero-based viewport line window.
pub fn ViewModel::render_frame(
  self : ViewModel,
  viewport : FrameViewport,
) -> RenderFrame {
  let start_line = @base_common.clamp_int(
    viewport.start_line,
    0,
    self.line_count() - 1,
  )
  let end_line = @base_common.clamp_int(
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
    diagnostics: self.source.providers.diagnostics,
    hovers: self.source.providers.hovers,
  }
}
