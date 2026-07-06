///|
/// Converts between model document coordinates and rendered view coordinates,
/// `ICoordinatesConverter` (`coordinatesConverter.ts:15-30`). `affinity`
/// picks the side of an injected-text or wrap boundary; absent it means the
/// Monaco default of that member — `None` for positions
/// (`viewModelLines.ts:848`) and `Left` for ranges (`:892`, where it only
/// affects empty ranges).
pub(open) trait CoordinatesConverter {
  fn model_position_to_view_position(
    Self,
    @base_common.Position,
    affinity? : @model.PositionAffinity,
  ) -> @base_common.Position
  fn view_position_to_model_position(Self, @base_common.Position) -> @base_common.Position
  fn model_range_to_view_range(
    Self,
    @base_common.Range,
    affinity? : @model.PositionAffinity,
  ) -> @base_common.Range
  fn view_range_to_model_range(Self, @base_common.Range) -> @base_common.Range
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
/// Identity model-to-view position conversion (affinity has no boundary to
/// disambiguate — the identity tier has no injected text or wraps).
pub impl CoordinatesConverter for IdentityCoordinatesConverter with fn model_position_to_view_position(
  _self,
  position,
  affinity? : @model.PositionAffinity,
) {
  ignore(affinity)
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
  affinity? : @model.PositionAffinity,
) {
  ignore(affinity)
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
  affinity? : @model.PositionAffinity,
) {
  match self {
    Identity(converter) =>
      converter.model_position_to_view_position(position, affinity?)
    Projected(converter) =>
      converter.model_position_to_view_position(position, affinity?)
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
  affinity? : @model.PositionAffinity,
) {
  match self {
    Identity(converter) => converter.model_range_to_view_range(range, affinity?)
    Projected(converter) =>
      converter.model_range_to_view_range(range, affinity?)
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
/// Whether any model line carries injected text.
fn ViewModelLinesFromModelAsIs::has_injected_text(
  self : ViewModelLinesFromModelAsIs,
) -> Bool {
  for bucket in self.injected_text_by_model_line {
    if bucket.length() > 0 {
      return true
    }
  }
  false
}

///|
/// Creates unprojected view lines with every model line visible. Injected
/// text is derived from the backing model's decoration storage
/// (`getInjectedTextDecorations` — deviations-closeout Track F deleted the
/// parallel `Array[InjectedText]` plumbing).
pub fn ViewModelLinesFromModelAsIs::new(
  source : FrameSource,
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
    injected_text_by_model_line: bucket_injected_text_from_decorations(source),
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
/// Whether a one-based model line is hidden.
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
/// Renders a one-based model line regardless of visibility.
pub fn ViewModelLinesFromModelAsIs::render_model_line(
  self : ViewModelLinesFromModelAsIs,
  model_line_number : Int,
) -> RenderLine {
  let doc = self.source.tokenized.snapshot
  let line_index = self.clamped_model_line_index(model_line_number)
  let line_start = doc.line_start_offset(line_index)
  let line_end = doc.line_end_offset(line_index)
  {
    line_number: line_index + 1,
    offset: line_start,
    text: doc.line_text(line_index),
    model_columns: identity_model_columns(line_end - line_start),
    injected_text_indices: identity_injected_text_indices(line_end - line_start),
    tokens: self.model_line_tokens(model_line_number).inflate(),
    injected_inline_decorations: [],
  }
}

///|
/// The faithful `LineTokens` for a one-based model line, the concrete token
/// store the projection slices through `with_inserted` / `slice_and_inflate`.
pub fn ViewModelLinesFromModelAsIs::model_line_tokens(
  self : ViewModelLinesFromModelAsIs,
  model_line_number : Int,
) -> LineTokens {
  let line_index = self.clamped_model_line_index(model_line_number)
  self.source.tokenized.line_tokens_for_line(line_index)
}

///|
/// Builds line-renderer input data for a one-based view line.
pub fn ViewModelLinesFromModelAsIs::view_line_rendering_data(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
  line_decorations? : Array[@view_layout.LineDecoration] = [],
) -> @view_layout.ViewLineRenderingData {
  view_line_rendering_data_from_render_line(
    self.render_line(line_number),
    line_decorations~,
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
/// Derives per-model-line injected text from the backing model's
/// injected-text decorations — `LineInjectedText.fromDecorations`
/// (`textModelEvents.ts`): `before` lands at the range start (order 0),
/// `after` at the range end (order 1); sorted by line, column, order.
/// Positions convert to the 0-based line/column space
/// `ProjectedTextLine::from_injected_text` consumes. Headless frames
/// (`source.model = None`) have no injected text.
fn bucket_injected_text_from_decorations(
  source : FrameSource,
) -> Array[Array[InjectedText]] {
  let snapshot = source.tokenized.snapshot
  let buckets : Array[Array[InjectedText]] = []
  for _ in 0..<snapshot.line_count() {
    buckets.push([])
  }
  guard source.model is Some(model) else { return buckets }
  let entries : Array[(Int, Int, Int, @model.ModelInjectedTextOptions)] = []
  for decoration in model.get_injected_text_decorations() {
    match decoration.options.before {
      Some(before) =>
        if before.content.length() > 0 {
          entries.push(
            (
              decoration.range.start_line_number,
              decoration.range.start_column,
              0,
              before,
            ),
          )
        }
      None => ()
    }
    match decoration.options.after {
      Some(after) =>
        if after.content.length() > 0 {
          entries.push(
            (
              decoration.range.end_line_number,
              decoration.range.end_column,
              1,
              after,
            ),
          )
        }
      None => ()
    }
  }
  entries.sort_by((left, right) => {
    let (l_line, l_column, l_order, _) = left
    let (r_line, r_column, r_order, _) = right
    if l_line != r_line {
      l_line - r_line
    } else if l_column != r_column {
      l_column - r_column
    } else {
      l_order - r_order
    }
  })
  for entry in entries {
    let (line_number, column, _, options) = entry
    let line = @base_common.clamp_int(
      line_number - 1,
      0,
      snapshot.line_count() - 1,
    )
    let line_text = snapshot.line_text(line)
    let column0 = @base_common.clamp_int(column - 1, 0, line_text.length())
    buckets[line].push(
      InjectedText(
        Position(line, column0),
        options.content,
        options.inline_class_name.unwrap_or(""),
        source_index=options.attached_index,
      ),
    )
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
  line_decorations? : Array[@view_layout.LineDecoration] = [],
) -> @view_layout.ViewLineRenderingData {
  match self {
    ModelAsIs(lines) =>
      lines.view_line_rendering_data(line_number, line_decorations~)
    ProjectedModel(lines) =>
      lines.view_line_rendering_data(line_number, line_decorations~)
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
fn ViewModel::from_lines(
  source : FrameSource,
  options : ViewModelOptions,
  as_is : ViewModelLinesFromModelAsIs,
  force_projected~ : Bool,
) -> ViewModel {
  // Injected text (from the model's decoration storage) needs the projected
  // tier even without wrapping.
  let force_projected = force_projected || as_is.has_injected_text()
  let (lines, coordinates_converter) = if options.is_soft_wrap_enabled() {
    let projected = ViewModelLinesFromProjectedModel::new(
      as_is,
      LineBreaksComputer(
        options.soft_wrap_column,
        tab_size=options.tab_size,
        wrapping_indent=options.wrapping_indent,
      ),
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
      options.editor_id,
      source.model,
      filter_validation_decorations(options.render_validation_decorations),
      lines,
      coordinates_converter,
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
/// Snaps a view position at injected-text/wrap boundaries per the affinity —
/// `ViewModel.normalizePosition` (`viewModelImpl.ts:1281-1283`). The identity
/// tier delegates to the model in Monaco (`viewModelLines.ts:1260-1262`),
/// which is the identity here: the as-is tier carries no injected text.
pub fn ViewModel::normalize_position(
  self : ViewModel,
  position : @base_common.Position,
  affinity : @model.PositionAffinity,
) -> @base_common.Position {
  match self.coordinates_converter {
    Identity(_) => position
    Projected(converter) =>
      converter.projection.normalize_view_position(position, affinity)
  }
}

///|
/// Number of visible view lines.
pub fn ViewModel::line_count(self : ViewModel) -> Int {
  self.lines.line_count()
}

///|
/// Source document version.
pub fn ViewModel::version(self : ViewModel) -> Int {
  self.source.tokenized.version
}

///|
/// Source document language id.
pub fn ViewModel::language_id(self : ViewModel) -> String {
  self.source.tokenized.language_id
}

///|
/// Builds a render frame for the requested 1-based viewport line window.
pub fn ViewModel::render_frame(
  self : ViewModel,
  viewport : FrameViewport,
) -> RenderFrame {
  let start_line = @base_common.clamp_int(
    viewport.start_line,
    1,
    self.line_count(),
  )
  let end_line = @base_common.clamp_int(
    viewport.end_line,
    start_line + 1,
    self.line_count() + 1,
  )
  let lines : Array[RenderLine] = []
  for line in start_line..<end_line {
    lines.push(self.lines.render_line(line))
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
