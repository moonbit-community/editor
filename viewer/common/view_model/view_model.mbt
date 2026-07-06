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
  model : @model.TextModel
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
/// (`getInjectedTextDecorations`).
pub fn ViewModelLinesFromModelAsIs::new(
  model : @model.TextModel,
) -> ViewModelLinesFromModelAsIs {
  let line_count = model.snapshot.line_count()
  let visible_model_line_numbers : Array[Int] = []
  let hidden_model_lines : Array[Bool] = []
  for line_number in 1..<=line_count {
    visible_model_line_numbers.push(line_number)
    hidden_model_lines.push(false)
  }
  {
    model,
    visible_model_line_numbers,
    hidden_model_lines,
    injected_text_by_model_line: bucket_injected_text_from_decorations(model),
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
  self.model.snapshot.line_count()
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
  self.model.snapshot.line_text(line_index)
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
/// The view-line data of a one-based view line — Monaco
/// `ViewModelLinesFromModelAsIs.getViewLineData` (`viewModelLines.ts`): the
/// as-is tier serves the model line whole, with no wrapping and no injected
/// text.
pub fn ViewModelLinesFromModelAsIs::get_view_line_data(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
) -> ViewLineData {
  let model_line_number = self.model_line_number_of_view_line(line_number)
  let doc = self.model.snapshot
  let line_index = self.clamped_model_line_index(model_line_number)
  let content = doc.line_text(line_index)
  {
    content,
    continues_with_wrapped_line: false,
    min_column: 1,
    max_column: content.length() + 1,
    start_visible_column: 0,
    tokens: self.model_line_tokens(model_line_number).inflate(),
    inline_decorations: [],
  }
}

///|
/// The faithful `LineTokens` for a one-based model line, the concrete token
/// store the projection slices through `with_inserted` / `slice_and_inflate`.
/// Reads `model.tokenization.get_line_tokens` (Monaco's
/// `model.tokenization.getLineTokens`), which clamps out-of-range lines.
pub fn ViewModelLinesFromModelAsIs::model_line_tokens(
  self : ViewModelLinesFromModelAsIs,
  model_line_number : Int,
) -> @tokens.LineTokens {
  self.model.tokenization.get_line_tokens(model_line_number)
}

///|
/// Builds line-renderer input data for a one-based view line.
pub fn ViewModelLinesFromModelAsIs::view_line_rendering_data(
  self : ViewModelLinesFromModelAsIs,
  line_number : Int,
  line_decorations? : Array[@view_layout.LineDecoration] = [],
) -> @view_layout.ViewLineRenderingData {
  view_line_rendering_data_from_view_line_data(
    self.get_view_line_data(line_number),
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
/// `ProjectedTextLine::from_injected_text` consumes.
fn bucket_injected_text_from_decorations(
  model : @model.TextModel,
) -> Array[Array[InjectedText]] {
  let snapshot = model.snapshot
  let buckets : Array[Array[InjectedText]] = []
  for _ in 0..<snapshot.line_count() {
    buckets.push([])
  }
  let entries : Array[(Int, Int, Int, @model.InjectedTextOptions)] = []
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
/// The view-line data of a one-based view line, Monaco's
/// `IViewModelLines.getViewLineData`.
pub fn ViewModelLines::get_view_line_data(
  self : ViewModelLines,
  line_number : Int,
) -> ViewLineData {
  match self {
    ModelAsIs(lines) => lines.get_view_line_data(line_number)
    ProjectedModel(lines) => lines.get_view_line_data(line_number)
  }
}

///|
/// The model's tab size as the renderer consumes it (Monaco threads
/// `model.getOptions().tabSize` into `ViewLineRenderingData`; the viewer's
/// tab size rides the projection options).
pub fn ViewModelLines::tab_size(self : ViewModelLines) -> Int {
  match self {
    ModelAsIs(_) => 2
    ProjectedModel(lines) => lines.tab_size
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
/// Backend-neutral document view model: the backing text model plus line
/// projection, decorations, and coordinate conversion. Long-lived like
/// Monaco's `ViewModel` (`viewModelImpl.ts`): constructed once at model
/// attach and updated in place through `on_configuration_changed` and
/// `on_did_change_content_or_injected_text`.
pub struct ViewModel {
  model : @model.TextModel
  mut options : ViewModelOptions
  mut lines : ViewModelLines
  mut decorations : ViewModelDecorations
  mut coordinates_converter : ViewModelCoordinatesConverter
}

///|
/// Creates a view model with default no-wrap options.
pub fn ViewModel::ViewModel(model : @model.TextModel) -> ViewModel {
  ViewModel::with_options(model, ViewModelOptions::no_wrap())
}

///|
/// Creates a view model with wrapping/tab options.
pub fn ViewModel::with_options(
  model : @model.TextModel,
  options : ViewModelOptions,
) -> ViewModel {
  let (lines, coordinates_converter, decorations) = construct_lines(
    model, options,
  )
  { model, options, lines, decorations, coordinates_converter }
}

///|
/// Selects the line tier and builds its converter and decoration provider —
/// Monaco's `_constructLines` (`viewModelLines.ts`), lifted onto the view
/// model because the viewer re-picks the tier on every reconstruct: injected
/// text (from the model's decoration storage) needs the projected tier even
/// without wrapping.
fn construct_lines(
  model : @model.TextModel,
  options : ViewModelOptions,
) -> (ViewModelLines, ViewModelCoordinatesConverter, ViewModelDecorations) {
  let as_is = ViewModelLinesFromModelAsIs::new(model)
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
  } else if as_is.has_injected_text() {
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
  let decorations = ViewModelDecorations::new(
    options.editor_id,
    model,
    filter_validation_decorations(options.render_validation_decorations),
    lines,
    coordinates_converter,
  )
  (lines, coordinates_converter, decorations)
}

///|
/// Reconstructs the line tier in place; the converter and decoration
/// provider close over the lines, so they rotate with it.
fn ViewModel::reconstruct_lines(self : ViewModel) -> Unit {
  let (lines, coordinates_converter, decorations) = construct_lines(
    self.model,
    self.options,
  )
  self.lines = lines
  self.coordinates_converter = coordinates_converter
  self.decorations = decorations
}

///|
/// Applies changed options to the live view model — Monaco's
/// `ViewModel._onConfigurationChanged` (`viewModelImpl.ts:274`) collapsed
/// onto the one options struct: `_lines.setWrappingSettings` + `setTabSize`
/// become one wrapping comparison that reconstructs the projection in place,
/// and a changed decoration filter input (`renderValidationDecorations`,
/// `editorId`) rotates the decoration provider (Monaco's
/// `_decorations.reset()` — the viewer's provider closes over the filter at
/// construction). Returns whether the view-line mapping changed (Monaco
/// emits `ViewFlushedEvent`/`ViewLineMappingChangedEvent`), so the caller
/// re-flushes the layout.
pub fn ViewModel::on_configuration_changed(
  self : ViewModel,
  options : ViewModelOptions,
) -> Bool {
  let previous = self.options
  if previous == options {
    return false
  }
  self.options = options
  if previous.soft_wrap_column != options.soft_wrap_column ||
    previous.tab_size != options.tab_size ||
    previous.wrapping_indent != options.wrapping_indent {
    self.reconstruct_lines()
    return true
  }
  self.decorations = ViewModelDecorations::new(
    options.editor_id,
    self.model,
    filter_validation_decorations(options.render_validation_decorations),
    self.lines,
    self.coordinates_converter,
  )
  false
}

///|
/// Injected-text decorations changed — the readonly viewer's form of
/// Monaco's `onDidChangeContentOrInjectedText` (`viewModelImpl.ts:319`,
/// called directly by the text model). Monaco re-runs the line-breaks
/// computer per changed line; the viewer's granularity is the
/// whole-projection reconstruct, which also re-picks the tier (injected
/// text forces the projected one).
pub fn ViewModel::on_did_change_content_or_injected_text(
  self : ViewModel,
) -> Unit {
  self.reconstruct_lines()
}

///|
/// Active line model for this view model.
pub fn ViewModel::lines(self : ViewModel) -> ViewModelLines {
  self.lines
}

///|
/// ModelDecorationOptions buckets for this view model.
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
/// The injected-text (inlay hint) source index at a view position, or `-1`
/// for source text — the viewer's index-valued form of Monaco's
/// `ViewModel.getInjectedTextAt` (`viewModelImpl.ts`, delegating to the line
/// projection). The as-is tier carries no injected text by construction
/// (injected text forces the projected tier).
pub fn ViewModel::injected_text_index_at(
  self : ViewModel,
  position : @base_common.Position,
) -> Int {
  match self.lines {
    ModelAsIs(_) => -1
    ProjectedModel(lines) =>
      lines.injected_text_index_at(position.line_number, position.column - 1)
  }
}

///|
/// Source document version.
pub fn ViewModel::version(self : ViewModel) -> Int {
  self.model.version
}

///|
/// Source document language id.
pub fn ViewModel::language_id(self : ViewModel) -> String {
  self.model.language_id
}

///|
/// Clamps a 1-based half-open view-line window to the document, the same
/// clamping the viewport-data builder applies (`viewport_data_from_view_model`)
/// so window consumers (the DOM recycler, hit tests) agree on the rendered
/// range.
pub fn ViewModel::clamp_window(
  self : ViewModel,
  window : @view_layout.LineWindow,
) -> @view_layout.LineWindow {
  let start = @base_common.clamp_int(window.start, 1, self.line_count())
  let end = @base_common.clamp_int(window.end, start + 1, self.line_count() + 1)
  { start, end }
}
