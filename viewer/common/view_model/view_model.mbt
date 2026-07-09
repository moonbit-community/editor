///|
/// Backend-neutral document view model: the backing text model plus line
/// projection, decorations, and coordinate conversion. Long-lived like
/// Monaco's `ViewModel` (`viewModelImpl.ts`): constructed once at model
/// attach and updated in place through `on_configuration_changed` and
/// `on_did_change_content_or_injected_text`. Like Monaco, the line collection
/// is always `ViewModelLinesFromProjectedModel` — no-wrap documents stay
/// cheap through per-line `Identity` projections, not through a swapped
/// collection.
pub struct ViewModel {
  model : @model.TextModel
  mut options : ViewModelOptions
  lines : ViewModelLinesFromProjectedModel
  /// The cursor state, owned per view model like Monaco's `_cursor`
  /// (`viewModelImpl.ts:65,124`): a new model starts with a fresh cursor at
  /// the origin, and reflows re-point it internally
  /// (`_cursor.onLineMappingChanged`, `viewModelImpl.ts:287`).
  cursor : @cursor.CursorsController
  /// The scroll/layout model, owned per view model like Monaco's
  /// `public readonly viewLayout` (`viewModelImpl.ts:64,126`): a new model
  /// starts at the scroll origin structurally. The viewport box is seeded
  /// from the widget's measured dimensions after construction (Monaco's
  /// `ViewLayout` reads `EditorOption.layoutInfo` from the configuration).
  view_layout : @view_layout.ViewLayout
  mut decorations : ViewModelDecorations
  coordinates_converter : ProjectedCoordinatesConverter
  /// Per-source hidden-area sets, merged before they reach the line
  /// collection — Monaco's `hiddenAreasModel` (`viewModelImpl.ts:70`).
  priv hidden_areas_model : HiddenAreasModel
  /// The last merged hidden-area union, for `setHiddenAreas`'s no-change
  /// short-circuit — Monaco's `previousHiddenAreas` (`viewModelImpl.ts:71`).
  priv mut previous_hidden_areas : Array[@base_common.Range]
}

///|
/// Creates a view model with default no-wrap options.
pub fn ViewModel::ViewModel(model : @model.TextModel) -> ViewModel {
  ViewModel::with_options(model, ViewModelOptions::no_wrap())
}

///|
/// Creates a view model with wrapping/tab options — the line-collection
/// construction of Monaco's `ViewModel` constructor
/// (`viewModelImpl.ts:98-122`).
pub fn ViewModel::with_options(
  model : @model.TextModel,
  options : ViewModelOptions,
) -> ViewModel {
  let lines = ViewModelLinesFromProjectedModel::new(
    model,
    font_info=options.font_info,
    tab_size=options.tab_size,
    wrapping_column=options.soft_wrap_column,
    wrapping_indent=options.wrapping_indent,
  )
  let coordinates_converter = lines.create_coordinates_converter()
  // Monaco's member order: `_lines` → `coordinatesConverter` → `_cursor` →
  // `viewLayout` (`viewModelImpl.ts:122-126`) → `_decorations` (`:146`).
  let cursor = @cursor.CursorsController::new(
    @cursor.CursorContext::new(coordinates_converter),
  )
  let view_layout = @view_layout.ViewLayout::new(
    line_height=options.font_info.line_height,
    line_count=lines.get_view_line_count(),
  )
  let decorations = ViewModelDecorations::new(
    options.editor_id,
    model,
    filter_validation_decorations(options.render_validation_decorations),
    lines,
    coordinates_converter,
  )
  {
    model,
    options,
    lines,
    cursor,
    view_layout,
    decorations,
    coordinates_converter,
    hidden_areas_model: HiddenAreasModel::new(),
    previous_hidden_areas: [],
  }
}

///|
/// Applies changed options to the live view model — Monaco's
/// `ViewModel._onConfigurationChanged` (`viewModelImpl.ts:274`) over the one
/// options struct: `_lines.setWrappingSettings` + `setTabSize` update the
/// collection in place, and a changed decoration filter input
/// (`renderValidationDecorations`, `editorId`) rotates the decoration
/// provider (Monaco's `_decorations.reset()` — the viewer's provider closes
/// over the filter at construction). Returns whether the view-line mapping
/// changed (Monaco emits `ViewFlushedEvent`/`ViewLineMappingChangedEvent`),
/// so the caller re-flushes the layout.
pub fn ViewModel::on_configuration_changed(
  self : ViewModel,
  options : ViewModelOptions,
) -> Bool {
  let previous = self.options
  if previous == options {
    return false
  }
  self.options = options
  let wrapping_changed = self.lines.set_wrapping_settings(
    options.font_info,
    options.soft_wrap_column,
    options.wrapping_indent,
  )
  let tab_size_changed = self.lines.set_tab_size(options.tab_size)
  let mapping_changed = wrapping_changed || tab_size_changed
  if mapping_changed {
    self.decorations.on_line_mapping_changed()
    // `this._cursor.onLineMappingChanged(...)` (`viewModelImpl.ts:287`): the
    // view model re-points its own cursor, re-projecting the selection from
    // its model positions.
    self.cursor.set_context(
      @cursor.CursorContext::new(self.coordinates_converter),
    )
  }
  if previous.editor_id != options.editor_id ||
    previous.render_validation_decorations !=
    options.render_validation_decorations {
    self.decorations = ViewModelDecorations::new(
      options.editor_id,
      self.model,
      filter_validation_decorations(options.render_validation_decorations),
      self.lines,
      self.coordinates_converter,
    )
  }
  mapping_changed
}

///|
/// Injected-text decorations changed — the readonly viewer's form of
/// Monaco's `onDidChangeContentOrInjectedText` (`viewModelImpl.ts:319`,
/// called directly by the text model). Monaco re-runs the line-breaks
/// computer per changed line; the viewer's granularity is the model flush
/// (`_lines.onModelFlushed()` + `_decorations.reset()`).
pub fn ViewModel::on_did_change_content_or_injected_text(
  self : ViewModel,
) -> Unit {
  self.lines.on_model_flushed()
  self.decorations.reset()
  // The reprojection changed the view-line mapping; re-point the cursor
  // (Monaco's `onDidChangeContentOrInjectedText` handling routes the
  // line-mapping change into `_cursor.onLineMappingChanged`).
  self.cursor.set_context(
    @cursor.CursorContext::new(self.coordinates_converter),
  )
}

///|
/// The line collection for this view model.
pub fn ViewModel::lines(self : ViewModel) -> ViewModelLinesFromProjectedModel {
  self.lines
}

///|
/// ModelDecorationOptions buckets for this view model.
pub fn ViewModel::decorations(self : ViewModel) -> ViewModelDecorations {
  self.decorations
}

///|
/// Coordinate converter for this view model, typed as the interface like
/// Monaco's `public readonly coordinatesConverter: ICoordinatesConverter`
/// (`viewModelImpl.ts:62,122`).
pub fn ViewModel::coordinates_converter(
  self : ViewModel,
) -> &@core.CoordinatesConverter {
  self.coordinates_converter
}

///|
/// Snaps a view position at injected-text/wrap boundaries per the affinity —
/// `ViewModel.normalizePosition` (`viewModelImpl.ts:1281-1283`).
pub fn ViewModel::normalize_position(
  self : ViewModel,
  position : @base_common.Position,
  affinity : @model.PositionAffinity,
) -> @base_common.Position {
  self.lines.normalize_position(position, affinity)
}

///|
/// Number of view lines.
pub fn ViewModel::line_count(self : ViewModel) -> Int {
  self.lines.get_view_line_count()
}

///|
/// The injected-text (inlay hint) source index at a view position, or `-1`
/// for source text — the viewer's index-valued form of Monaco's
/// `ViewModel.getInjectedTextAt` (`viewModelImpl.ts`, delegating to the line
/// projection).
pub fn ViewModel::injected_text_index_at(
  self : ViewModel,
  position : @base_common.Position,
) -> Int {
  self.lines.injected_text_index_at(position.line_number, position.column - 1)
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

///|
/// Monaco `ViewModel.getLineContent`: the text of a view line.
pub fn ViewModel::get_line_content(
  self : ViewModel,
  line_number : Int,
) -> String {
  self.lines.get_view_line_data(line_number).content
}

///|
/// Monaco `ViewModel.getLineLength`: the text length of a view line.
pub fn ViewModel::get_line_length(self : ViewModel, line_number : Int) -> Int {
  self.lines.get_view_line_data(line_number).content.length()
}

///|
/// Monaco `ViewModel.getInjectedTextAt` (`viewModelImpl.ts`): the injected
/// text at a view position, or `None` on source text. The object is
/// re-derived from the position's model line (the projections retain only
/// per-column indices); `source_index` is the decoration's `attached_index`,
/// the same value `injected_text_index_at` reports.
pub fn ViewModel::get_injected_text_at(
  self : ViewModel,
  position : @base_common.Position,
) -> InjectedText? {
  let index = self.injected_text_index_at(position)
  if index < 0 {
    return None
  }
  let info = self.lines.get_view_line_info(position.line_number)
  for text in injected_text_for_model_line(self.model, info.model_line_number) {
    if text.source_index == index {
      return Some(text)
    }
  }
  None
}
