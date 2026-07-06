// 1:1 port of Monaco's `viewModel/viewModelDecorations.ts` (whole file) plus
// the `viewModelLines.ts:923` `getDecorationsInRange` slice its context
// closure delegates to, from vscode submodule commit
// 294fb350837dbaee37b949533fead4df4e0e8971 (decoration plan Phase 3 — this
// replaces the previous simplified eager-conversion `ViewModelDecorations`).
//
// Deviations:
// - The editor configuration reads (`filterValidationDecorations(options)`,
//   `filterFontDecorations(options)`) are resolved once at construction: the
//   readonly viewer rebuilds its view model on every option change, so the
//   per-call read has no observable difference. Font decorations are out of
//   scope, so that filter is constantly `false`.
// - `getMinimapDecorationsInRange` is DEFERRED with the minimap view part
//   (plan out-of-scope list); `onlyMinimapDecorations` is carried through the
//   context signature (it only forwards to the out-of-scope bracket provider
//   in the source).
// - `dispose` is folded into `reset` (no dispose lifecycle in the readonly
//   view model; both bodies are identical in the source).

///|
/// The production instantiation of the faithful inline-decorations middle
/// layer: options are the real `@model.ModelDecorationOptions`.
pub type ViewModelDecoration = @inline_decorations.ViewModelDecoration[
  @model.ModelDecorationOptions,
]

///|
pub type ViewDecorationsCollection = @inline_decorations.ViewDecorationsCollection[
  @model.ModelDecorationOptions,
]

///|
/// `renderValidationDecorations` (`editorOptions.ts`): whether validation
/// (squiggly) decorations render. Monaco's default is `Editable`; the
/// `Viewer` defaults its option to `On` instead — the readonly viewer's
/// diagnostics rendering is a shipped feature that `Editable` (which hides
/// validation decorations in readonly editors) would turn off.
pub(all) enum RenderValidationDecorations {
  Editable
  On
  Off
} derive(Eq, Debug)

///|
/// `filterValidationDecorations` (`editorOptions.ts`): `editable` defers to
/// `readOnly`, which is constantly `true` for this viewer.
pub fn filter_validation_decorations(
  option : RenderValidationDecorations,
) -> Bool {
  match option {
    Editable => true // editable → readOnly; the viewer is always readonly
    On => false
    Off => true
  }
}

///|
/// The `ICoordinatesConverter` seam of the promoted inline-decorations
/// computer, implemented by the view model's converter.
pub impl @inline_decorations.CoordinatesConverter for ViewModelCoordinatesConverter with fn convert_model_position_to_view_position(
  self,
  model_position,
  affinity? : @model.PositionAffinity,
) {
  self.model_position_to_view_position(model_position, affinity?)
}

///|
pub impl @inline_decorations.CoordinatesConverter for ViewModelCoordinatesConverter with fn convert_model_range_to_view_range(
  self,
  model_range,
  affinity? : @model.PositionAffinity,
) {
  self.model_range_to_view_range(model_range, affinity?)
}

///|
/// `ViewModelDecorations` (`viewModelDecorations.ts:16`): the lazy,
/// viewport-cached decoration provider for one view model.
pub struct ViewModelDecorations {
  priv computer : @inline_decorations.InlineModelDecorationsComputer[
    @model.ModelDecorationOptions,
  ]
  priv mut cached_model_decorations_resolver : ViewDecorationsCollection?
  priv mut cached_model_decorations_resolver_view_range : @base_common.Range?
}

///|
/// Constructor (`viewModelDecorations.ts:27-37`): the context closure hands
/// the computer model decorations for a view range via the lines collection.
pub fn ViewModelDecorations::new(
  editor_id : Int,
  model : @model.TextModel,
  filter_validation : Bool,
  lines : ViewModelLines,
  coordinates_converter : ViewModelCoordinatesConverter,
) -> ViewModelDecorations {
  let context : @inline_decorations.InlineModelContext[
    @model.ModelDecorationOptions,
  ] = {
    get_model_decorations: (
      view_range,
      only_minimap_decorations,
      only_margin_decorations,
    ) => {
      view_model_lines_get_decorations_in_range(
        lines, model, coordinates_converter, view_range, editor_id, filter_validation,
        only_minimap_decorations, only_margin_decorations,
      )
    },
  }
  {
    computer: @inline_decorations.InlineModelDecorationsComputer::new(
      context, model, coordinates_converter,
    ),
    cached_model_decorations_resolver: None,
    cached_model_decorations_resolver_view_range: None,
  }
}

///|
/// `_clearCachedModelDecorationsResolver` (`viewModelDecorations.ts:39-42`).
fn ViewModelDecorations::clear_cached_model_decorations_resolver(
  self : ViewModelDecorations,
) -> Unit {
  self.cached_model_decorations_resolver = None
  self.cached_model_decorations_resolver_view_range = None
}

///|
/// `reset` (`viewModelDecorations.ts:49-52`; `dispose` has the same body).
pub fn ViewModelDecorations::reset(self : ViewModelDecorations) -> Unit {
  self.computer.reset()
  self.clear_cached_model_decorations_resolver()
}

///|
/// `onModelDecorationsChanged` (`viewModelDecorations.ts:54-57`).
pub fn ViewModelDecorations::on_model_decorations_changed(
  self : ViewModelDecorations,
) -> Unit {
  self.computer.on_model_decorations_changed()
  self.clear_cached_model_decorations_resolver()
}

///|
/// `onLineMappingChanged` (`viewModelDecorations.ts:59-63`).
pub fn ViewModelDecorations::on_line_mapping_changed(
  self : ViewModelDecorations,
) -> Unit {
  self.computer.on_line_mapping_changed()
  self.clear_cached_model_decorations_resolver()
}

///|
/// `getDecorationsViewportData` (`viewModelDecorations.ts:69-77`): one-entry
/// cache keyed by the exact view range.
pub fn ViewModelDecorations::get_decorations_viewport_data(
  self : ViewModelDecorations,
  view_range : @base_common.Range,
) -> ViewDecorationsCollection {
  let mut cache_is_valid = self.cached_model_decorations_resolver is Some(_)
  cache_is_valid = cache_is_valid &&
    self.cached_model_decorations_resolver_view_range == Some(view_range)
  if !cache_is_valid {
    self.cached_model_decorations_resolver = Some(
      self.compute_decorations(view_range),
    )
    self.cached_model_decorations_resolver_view_range = Some(view_range)
  }
  self.cached_model_decorations_resolver.unwrap()
}

///|
/// `getDecorationsOnLine` (`viewModelDecorations.ts:79-82`).
pub fn ViewModelDecorations::get_decorations_on_line(
  self : ViewModelDecorations,
  lines : ViewModelLines,
  line_number : Int,
  only_minimap_decorations? : Bool = false,
  only_margin_decorations? : Bool = false,
) -> ViewDecorationsCollection {
  let range : @base_common.Range = Range(
    line_number,
    lines.get_view_line_min_column(line_number),
    line_number,
    lines.get_view_line_max_column(line_number),
  )
  self.computer.get_decorations(
    range, only_minimap_decorations, only_margin_decorations,
  )
}

///|
fn ViewModelDecorations::compute_decorations(
  self : ViewModelDecorations,
  view_range : @base_common.Range,
) -> ViewDecorationsCollection {
  self.computer.get_decorations(view_range, false, false)
}

///|
/// `getDecorationsInRange` (`viewModelLines.ts:923-975`): view-range query
/// against the model with hidden-line splitting. The fast path
/// covers the no-hidden-lines case; otherwise visible model-line runs are
/// fetched separately, sorted, and deduplicated. Like the source, the
/// split-path requests drop the `onlyMarginDecorations` argument.
fn view_model_lines_get_decorations_in_range(
  lines : ViewModelLines,
  model : @model.TextModel,
  converter : ViewModelCoordinatesConverter,
  range : @base_common.Range,
  owner_id : Int,
  filter_out_validation : Bool,
  only_minimap_decorations : Bool,
  only_margin_decorations : Bool,
) -> Array[@inline_decorations.ModelDecoration[@model.ModelDecorationOptions]] {
  // onlyMinimapDecorations only forwards to the out-of-scope bracket
  // provider in the source's model.getDecorationsInRange.
  ignore(only_minimap_decorations)
  let model_start = converter.view_position_to_model_position(
    Position(range.start_line_number, range.start_column),
  )
  let model_end = converter.view_position_to_model_position(
    Position(range.end_line_number, range.end_column),
  )
  if model_end.line_number - model_start.line_number <=
    range.end_line_number - range.start_line_number {
    // most likely there are no hidden lines => fast path
    // fetch decorations from column 1 to cover the case of wrapped lines that
    // have whole line decorations at column 1
    return to_inline_model_decorations(
      model.get_decorations_in_range(
        Range(
          model_start.line_number,
          1,
          model_end.line_number,
          model_end.column,
        ),
        owner_id~,
        filter_out_validation~,
        only_margin_decorations~,
      ),
    )
  }
  let result : Array[@model.ModelDecoration] = []
  let model_start_line_index = model_start.line_number - 1
  let model_end_line_index = model_end.line_number - 1
  let mut req_start : @base_common.Position? = None
  for model_line_index in model_start_line_index..<=model_end_line_index {
    if !lines.is_model_line_hidden(model_line_index + 1) {
      // merge into previous request
      if req_start is None {
        req_start = Some(
          Position(
            model_line_index + 1,
            if model_line_index == model_start_line_index {
              model_start.column
            } else {
              1
            },
          ),
        )
      }
    } else if req_start is Some(start) {
      // hit invisible line => flush request
      let max_line_column = model.snapshot.get_line_max_column(model_line_index)
      result.append(
        model.get_decorations_in_range(
          Range(
            start.line_number,
            start.column,
            model_line_index,
            max_line_column,
          ),
          owner_id~,
          filter_out_validation~,
        ),
      )
      req_start = None
    }
  }
  if req_start is Some(start) {
    result.append(
      model.get_decorations_in_range(
        Range(
          start.line_number,
          start.column,
          model_end.line_number,
          model_end.column,
        ),
        owner_id~,
        filter_out_validation~,
      ),
    )
    req_start = None
  }
  result.sort_by((a, b) => {
    let res = @base_common.Range::compare_ranges_using_starts(a.range, b.range)
    if res == 0 {
      // JS `<` on decoration ids; ids share one `<instance>;` prefix, where
      // MoonBit's length-first compare and JS lexicographic order agree for
      // the numeric suffixes only when lengths match — compare code units.
      lexicographic_id_compare(a.id, b.id)
    } else {
      res
    }
  })

  // Eliminate duplicate decorations that might have intersected our visible
  // ranges multiple times
  let final_result : Array[
    @inline_decorations.ModelDecoration[@model.ModelDecorationOptions],
  ] = []
  let mut last_dec_id = ""
  for dec in result {
    let dec_id = dec.id
    if last_dec_id == dec_id {
      continue
    }
    last_dec_id = dec_id
    final_result.push({
      id: dec.id,
      owner_id: dec.owner_id,
      range: dec.range,
      options: dec.options,
    })
  }
  final_result
}

///|
fn lexicographic_id_compare(left : String, right : String) -> Int {
  let min_len = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<min_len {
    let l = left[i].to_int()
    let r = right[i].to_int()
    if l != r {
      return l - r
    }
  }
  left.length() - right.length()
}

///|
fn to_inline_model_decorations(
  decorations : Array[@model.ModelDecoration],
) -> Array[@inline_decorations.ModelDecoration[@model.ModelDecorationOptions]] {
  decorations.map(dec => {
    id: dec.id,
    owner_id: dec.owner_id,
    range: dec.range,
    options: dec.options,
  })
}
