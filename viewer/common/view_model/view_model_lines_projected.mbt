///|
/// The line collection for every view model — Monaco's
/// `ViewModelLinesFromProjectedModel` (`viewModelLines.ts:60`), which Monaco
/// uses for all normal editors, wrapping on or off (its
/// `ViewModelLinesFromModelAsIs` is only the too-large-for-tokenization
/// escape hatch, which a readonly viewer never needs). Lines that need no
/// mapping project as `Identity` and stay allocation-free; wrapping and
/// injected text produce per-line `Projected` data.
pub struct ViewModelLinesFromProjectedModel {
  model : @model.TextModel
  mut font_info : @config.FontInfo
  mut tab_size : Int
  mut wrapping_column : Int
  mut wrapping_indent : WrappingIndent
  mut model_line_projections : Array[ModelLineProjection]
  /// Monaco's `projectedModelLineLineCounts` (a
  /// `ConstantTimePrefixSumComputer` over per-line view-line counts). The
  /// viewer reconstructs wholesale instead of editing incrementally, so it
  /// stores the prefix sums directly: entry `i` is the number of view lines
  /// before one-based model line `i + 1`, and the last entry is the total.
  mut projected_model_line_line_counts : Array[Int]
}

///|
/// A view line as (model line, wrapped-line index) — Monaco's `ViewLineInfo`
/// (`viewModelLines.ts:1054`).
priv struct ViewLineInfo {
  model_line_number : Int
  model_line_wrapped_line_idx : Int
}

///|
/// Builds the collection and its projections — the constructor tail of
/// Monaco's `ViewModelLinesFromProjectedModel` (`viewModelLines.ts:85-112`),
/// minus the DOM/monospace computer-factory split (the viewer is
/// monospace-only, so the monospace factory is the only one).
pub fn ViewModelLinesFromProjectedModel::new(
  model : @model.TextModel,
  font_info~ : @config.FontInfo,
  tab_size~ : Int,
  wrapping_column~ : Int,
  wrapping_indent~ : WrappingIndent,
) -> ViewModelLinesFromProjectedModel {
  let lines = {
    model,
    font_info,
    tab_size,
    wrapping_column,
    wrapping_indent,
    model_line_projections: [],
    projected_model_line_line_counts: [0],
  }
  lines.construct_lines()
  lines
}

///|
/// Creates the coordinate converter over this collection —
/// `createCoordinatesConverter` (`viewModelLines.ts:118`).
pub fn ViewModelLinesFromProjectedModel::create_coordinates_converter(
  self : ViewModelLinesFromProjectedModel,
) -> ProjectedCoordinatesConverter {
  ProjectedCoordinatesConverter::new(self)
}

///|
/// Recomputes every line's projection — Monaco's `_constructLines`
/// (`viewModelLines.ts:122`), minus hidden-area reset (no folding) and
/// previous-line-break reuse (the readonly viewer rebuilds wholesale). A
/// `None` projection is the line-breaks computer's null result: a line that
/// neither wraps nor carries injected text needs no mapping and projects as
/// `Identity`.
fn ViewModelLinesFromProjectedModel::construct_lines(
  self : ViewModelLinesFromProjectedModel,
) -> Unit {
  let model_line_projections : Array[ModelLineProjection] = []
  let prefix_sums : Array[Int] = [0]
  let injected_text_buckets = line_injected_text_from_decorations(self.model)
  let computer = monospace_line_breaks_computer_factory.create_line_breaks_computer(
    font_info=self.font_info,
    tab_size=self.tab_size,
    wrapping_column=self.wrapping_column,
    wrapping_indent=self.wrapping_indent,
  )
  let line_count = self.model.snapshot.line_count()
  for model_line_number in 1..<=line_count {
    computer.add_request(
      model_line_number,
      self.model.snapshot.line_text(model_line_number - 1),
      injected_text_buckets[model_line_number - 1],
    )
  }
  let line_break_data = computer.finalize()
  for model_line_number in 1..<=line_count {
    let projection = create_model_line_projection(
      line_break_data[model_line_number - 1],
    )
    model_line_projections.push(projection)
    prefix_sums.push(
      prefix_sums[model_line_number - 1] + projection.get_view_line_count(),
    )
  }
  self.model_line_projections = model_line_projections
  self.projected_model_line_line_counts = prefix_sums
}

///|
/// Applies changed wrapping settings in place — `setWrappingSettings`
/// (`viewModelLines.ts:277`, which equally takes the `fontInfo` whose
/// full-width/half-width ratio feeds the break widths). Returns whether the
/// view-line mapping changed.
pub fn ViewModelLinesFromProjectedModel::set_wrapping_settings(
  self : ViewModelLinesFromProjectedModel,
  font_info : @config.FontInfo,
  wrapping_column : Int,
  wrapping_indent : WrappingIndent,
) -> Bool {
  if self.font_info == font_info &&
    self.wrapping_column == wrapping_column &&
    self.wrapping_indent == wrapping_indent {
    return false
  }
  self.font_info = font_info
  self.wrapping_column = wrapping_column
  self.wrapping_indent = wrapping_indent
  self.construct_lines()
  true
}

///|
/// Applies a changed tab size in place — `setTabSize`
/// (`viewModelLines.ts:266`). Returns whether the view-line mapping changed.
pub fn ViewModelLinesFromProjectedModel::set_tab_size(
  self : ViewModelLinesFromProjectedModel,
  new_tab_size : Int,
) -> Bool {
  if self.tab_size == new_tab_size {
    return false
  }
  self.tab_size = new_tab_size
  self.construct_lines()
  true
}

///|
/// Reprojects after the backing content or injected text changed —
/// `onModelFlushed` (`viewModelLines.ts:325`). Monaco also applies per-line
/// deltas (`onModelLineChanged` and friends); the readonly viewer's only
/// in-place change is an injected-text delta, and its granularity is the
/// whole-document reproject.
pub fn ViewModelLinesFromProjectedModel::on_model_flushed(
  self : ViewModelLinesFromProjectedModel,
) -> Unit {
  self.construct_lines()
}

///|
/// Total number of view lines — `getViewLineCount`.
pub fn ViewModelLinesFromProjectedModel::get_view_line_count(
  self : ViewModelLinesFromProjectedModel,
) -> Int {
  let prefix_sums = self.projected_model_line_line_counts
  prefix_sums[prefix_sums.length() - 1]
}

///|
/// Clamps a view line number into the document — `_toValidViewLineNumber`.
fn ViewModelLinesFromProjectedModel::to_valid_view_line_number(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
) -> Int {
  @base_common.clamp_int(view_line_number, 1, self.get_view_line_count())
}

///|
/// Decomposes a view line into (model line, wrapped-line index) —
/// `getViewLineInfo` (`viewModelLines.ts:478`), the prefix-sum `getIndexOf`
/// as a binary search over the stored sums.
fn ViewModelLinesFromProjectedModel::get_view_line_info(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
) -> ViewLineInfo {
  let view_index = self.to_valid_view_line_number(view_line_number) - 1
  let prefix_sums = self.projected_model_line_line_counts
  // Greatest model-line index whose first view line is at or before
  // `view_index`.
  let mut low = 0
  let mut high = self.model_line_projections.length() - 1
  while low < high {
    let mid = (low + high + 1) / 2
    if prefix_sums[mid] <= view_index {
      low = mid
    } else {
      high = mid - 1
    }
  }
  {
    model_line_number: low + 1,
    model_line_wrapped_line_idx: view_index - prefix_sums[low],
  }
}

///|
/// Returns text for a one-based view line — `getViewLineContent`.
pub fn ViewModelLinesFromProjectedModel::get_view_line_content(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
) -> String {
  let info = self.get_view_line_info(view_line_number)
  self.model_line_projections[info.model_line_number - 1].get_view_line_content(
    self.model,
    info.model_line_number,
    info.model_line_wrapped_line_idx,
  )
}

///|
/// Minimum one-based column for a view line — `getViewLineMinColumn`.
pub fn ViewModelLinesFromProjectedModel::get_view_line_min_column(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
) -> Int {
  let info = self.get_view_line_info(view_line_number)
  self.model_line_projections[info.model_line_number - 1].get_view_line_min_column(
    info.model_line_wrapped_line_idx,
  )
}

///|
/// Maximum one-based column for a view line — `getViewLineMaxColumn`.
pub fn ViewModelLinesFromProjectedModel::get_view_line_max_column(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
) -> Int {
  let info = self.get_view_line_info(view_line_number)
  self.model_line_projections[info.model_line_number - 1].get_view_line_max_column(
    self.model,
    info.model_line_number,
    info.model_line_wrapped_line_idx,
  )
}

///|
/// Maps a one-based view line to its one-based model line — the line-number
/// half of Monaco's `getViewLineInfo`, kept as the viewer's shorthand for
/// consumers that only need the line.
pub fn ViewModelLinesFromProjectedModel::model_line_number_of_view_line(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
) -> Int {
  self.get_view_line_info(view_line_number).model_line_number
}

///|
/// The view-line data of a one-based view line — `getViewLineData`.
pub fn ViewModelLinesFromProjectedModel::get_view_line_data(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
) -> ViewLineData {
  let info = self.get_view_line_info(view_line_number)
  self.model_line_projections[info.model_line_number - 1].get_view_line_data(
    self.model,
    info.model_line_number,
    info.model_line_wrapped_line_idx,
  )
}

///|
/// Builds line-renderer input data for a one-based view line — the viewer's
/// bridge to `ViewLineRenderingData` (Monaco builds it in
/// `ViewModel.getViewLineRenderingData`).
pub fn ViewModelLinesFromProjectedModel::view_line_rendering_data(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
  line_decorations? : Array[@view_layout.LineDecoration] = [],
) -> @view_layout.ViewLineRenderingData {
  view_line_rendering_data_from_view_line_data(
    self.get_view_line_data(view_line_number),
    line_decorations~,
    tab_size=self.tab_size,
  )
}

///|
/// The injected-text (inlay hint) source index at a 0-based view column of a
/// view line, or `-1` for source text — the index-valued form of Monaco's
/// `getInjectedTextAt` (`viewModelLines.ts:991`).
pub fn ViewModelLinesFromProjectedModel::injected_text_index_at(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
  column : Int,
) -> Int {
  let info = self.get_view_line_info(view_line_number)
  self.model_line_projections[info.model_line_number - 1].injected_text_index_at(
    info.model_line_wrapped_line_idx,
    column,
  )
}

///|
/// Snaps a view position at injected-text/wrap boundaries per the affinity —
/// `normalizePosition` (`viewModelLines.ts:996`).
pub fn ViewModelLinesFromProjectedModel::normalize_position(
  self : ViewModelLinesFromProjectedModel,
  position : @base_common.Position,
  affinity : @model.PositionAffinity,
) -> @base_common.Position {
  let info = self.get_view_line_info(position.line_number)
  self.model_line_projections[info.model_line_number - 1].normalize_position(
    info.model_line_wrapped_line_idx,
    position,
    affinity,
  )
}

///|
/// Converts a view position to model coordinates —
/// `convertViewPositionToModelPosition` (`viewModelLines.ts:834`).
pub fn ViewModelLinesFromProjectedModel::convert_view_position_to_model_position(
  self : ViewModelLinesFromProjectedModel,
  view_line_number : Int,
  view_column : Int,
) -> @base_common.Position {
  let info = self.get_view_line_info(view_line_number)
  let input_column = self.model_line_projections[info.model_line_number - 1].get_model_column_of_view_position(
    info.model_line_wrapped_line_idx,
    view_column,
  )
  Position(info.model_line_number, input_column)
}

///|
/// Converts a view range to model coordinates —
/// `convertViewRangeToModelRange` (`viewModelLines.ts:842`).
pub fn ViewModelLinesFromProjectedModel::convert_view_range_to_model_range(
  self : ViewModelLinesFromProjectedModel,
  view_range : @base_common.Range,
) -> @base_common.Range {
  let start = self.convert_view_position_to_model_position(
    view_range.start_line_number,
    view_range.start_column,
  )
  let end = self.convert_view_position_to_model_position(
    view_range.end_line_number,
    view_range.end_column,
  )
  Range(start.line_number, start.column, end.line_number, end.column)
}

///|
/// Converts a model position to view coordinates —
/// `convertModelPositionToViewPosition` (`viewModelLines.ts:848`), minus the
/// hidden-line walk (nothing can hide a line). The affinity picks the
/// boundary side at injected text and wrap breaks; absent it behaves as
/// Monaco's default `None`.
pub fn ViewModelLinesFromProjectedModel::convert_model_position_to_view_position(
  self : ViewModelLinesFromProjectedModel,
  model_line_number : Int,
  model_column : Int,
  affinity? : @model.PositionAffinity,
) -> @base_common.Position {
  let line_index = @base_common.clamp_int(
    model_line_number - 1,
    0,
    self.model_line_projections.length() - 1,
  )
  let delta_line_number = 1 + self.projected_model_line_line_counts[line_index]
  self.model_line_projections[line_index].get_view_position_of_model_position(
    delta_line_number,
    model_column,
    affinity?,
  )
}

///|
/// Converts a model range to view coordinates —
/// `convertModelRangeToViewRange` (`viewModelLines.ts:892-901`): the default
/// affinity is `Left` and only applies to empty ranges; a non-empty range
/// excludes injected text at its edges (start `Right`, end `Left`).
pub fn ViewModelLinesFromProjectedModel::convert_model_range_to_view_range(
  self : ViewModelLinesFromProjectedModel,
  model_range : @base_common.Range,
  affinity? : @model.PositionAffinity,
) -> @base_common.Range {
  if model_range.is_empty() {
    let affinity = match affinity {
      Some(a) => a
      None => Left
    }
    let start = self.convert_model_position_to_view_position(
      model_range.start_line_number,
      model_range.start_column,
      affinity~,
    )
    Range(start.line_number, start.column, start.line_number, start.column)
  } else {
    let start = self.convert_model_position_to_view_position(
      model_range.start_line_number,
      model_range.start_column,
      affinity=Right,
    )
    let end = self.convert_model_position_to_view_position(
      model_range.end_line_number,
      model_range.end_column,
      affinity=Left,
    )
    Range(start.line_number, start.column, end.line_number, end.column)
  }
}

///|
/// Derives per-model-line injected text from the backing model's
/// injected-text decorations — `LineInjectedText.fromDecorations`
/// (`textModelEvents.ts`): `before` lands at the range start (order 0),
/// `after` at the range end (order 1); sorted by line, column, order.
/// Positions convert to the 0-based line/column space
/// `ProjectedTextLine::from_injected_text` consumes.
fn line_injected_text_from_decorations(
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
/// Coordinate converter over the projected line collection — the
/// `CoordinatesConverter` class of `viewModelLines.ts:1073`. (That plain name
/// is taken by this package's `ICoordinatesConverter` trait, so the class
/// keeps the `Projected` prefix.)
pub struct ProjectedCoordinatesConverter {
  lines : ViewModelLinesFromProjectedModel
}

///|
/// Creates a coordinate converter from the projected line collection.
pub fn ProjectedCoordinatesConverter::new(
  lines : ViewModelLinesFromProjectedModel,
) -> ProjectedCoordinatesConverter {
  { lines, }
}

///|
/// Converts model positions through the line collection.
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn model_position_to_view_position(
  self,
  position,
  affinity? : @model.PositionAffinity,
) {
  self.lines.convert_model_position_to_view_position(
    position.line_number,
    position.column,
    affinity?,
  )
}

///|
/// Converts view positions through the line collection.
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn view_position_to_model_position(
  self,
  position,
) {
  self.lines.convert_view_position_to_model_position(
    position.line_number,
    position.column,
  )
}

///|
/// Converts model ranges through the line collection.
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn model_range_to_view_range(
  self,
  range,
  affinity? : @model.PositionAffinity,
) {
  self.lines.convert_model_range_to_view_range(range, affinity?)
}

///|
/// Converts view ranges through the line collection.
pub impl CoordinatesConverter for ProjectedCoordinatesConverter with fn view_range_to_model_range(
  self,
  range,
) {
  self.lines.convert_view_range_to_model_range(range)
}
