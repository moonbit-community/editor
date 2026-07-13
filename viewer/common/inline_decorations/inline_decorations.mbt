///|
/// Faithful 1:1 port of Monaco's `viewModel/inlineDecorations.ts`
/// (`InlineDecoration`, `InlineDecorationType`, `InlineModelDecorationsComputer`,
/// `InjectedTextInlineDecorationsComputer`) plus `ViewModelDecoration` +
/// `isModelDecorationVisible` from `viewModel/viewModelDecoration.ts`, from
/// vscode submodule commit 294fb350837dbaee37b949533fead4df4e0e8971.
///
/// Production middle layer (decoration plan Phase 3): the computer is generic
/// over three seams so the real model tier plugs in while its conformance
/// suite keeps Monaco's test doubles (Monaco's own test setup does the same):
///   * `InlineDecorationsModel` — the line-geometry queries the computer makes
///     (statically dispatched); implemented for the real `@model.TextModel` here and
///     by the suite's mini text model double (kept inside the reference test).
///   * `CoordinatesConverter` — `ICoordinatesConverter`'s two used members;
///     implemented by the view model's converter (in `view_model`, the type's
///     package) and by the suite's `IdentityCoordinatesConverter` double.
///   * `InlineDecorationOptions` — the `IModelDecorationOptions` reads
///     (type parameter `O`); implemented for the real `@model.ModelDecorationOptions`
///     here and by the suite's options double.
///
/// DEVIATIONS (recorded; none exercised by the suite):
///   * `isModelDecorationVisible` always returns `true`: the
///     `hideInCommentTokens`/`hideInStringTokens` paths need a tokenization seam
///     this readonly port does not carry, and no `inlineDecorations.test.ts` case
///     sets those flags.
///   * `@model.ModelDecorationOptions` carries no `beforeContentClassName`/
///     `affectsFont` (out of decoration-plan scope), so those trait impls
///     answer `None`/`false`; `afterContentClassName` is ported (folding's
///     `inline-folded` is the producer), so the After arm runs in production.

///|
/// The line-geometry seam the computer needs from `ITextModel`.
pub(open) trait InlineDecorationsModel {
  fn get_line_max_column(Self, Int) -> Int
}

///|
/// `ICoordinatesConverter`, reduced to the two members the computer calls.
/// `affinity` follows the source's optional parameter
/// (`coordinatesConverter.ts:22-26`); absent means the Monaco default of the
/// member (`None` for positions, `Left` for ranges).
pub(open) trait CoordinatesConverter {
  fn convert_model_position_to_view_position(
    Self,
    @base_common.Position,
    affinity? : @model.PositionAffinity,
  ) -> @base_common.Position
  fn convert_model_range_to_view_range(
    Self,
    @base_common.Range,
    affinity? : @model.PositionAffinity,
  ) -> @base_common.Range
}

///|
/// The `IModelDecorationOptions` reads the computer makes.
pub(open) trait InlineDecorationOptions {
  fn inline_class_name(Self) -> String?
  fn inline_class_name_affects_letter_spacing(Self) -> Bool
  fn before_content_class_name(Self) -> String?
  fn after_content_class_name(Self) -> String?
  fn affects_font(Self) -> Bool
  fn is_whole_line(Self) -> Bool
}

///|
/// The real model tier: line geometry from the snapshot.
pub impl InlineDecorationsModel for @model.TextModel with fn get_line_max_column(
  self,
  line_number,
) {
  self.snapshot.get_line_max_column(line_number)
}

///|
/// The real options tier. `beforeContentClassName` and `affectsFont` are
/// not ported model fields (see header deviation), hence constant.
pub impl InlineDecorationOptions for @model.ModelDecorationOptions with fn inline_class_name(
  self,
) {
  self.inline_class_name
}

///|
pub impl InlineDecorationOptions for @model.ModelDecorationOptions with fn inline_class_name_affects_letter_spacing(
  self,
) {
  self.inline_class_name_affects_letter_spacing
}

///|
pub impl InlineDecorationOptions for @model.ModelDecorationOptions with fn before_content_class_name(
  _self,
) {
  None
}

///|
pub impl InlineDecorationOptions for @model.ModelDecorationOptions with fn after_content_class_name(
  self,
) {
  self.after_content_class_name
}

///|
pub impl InlineDecorationOptions for @model.ModelDecorationOptions with fn affects_font(
  _self,
) {
  false
}

///|
pub impl InlineDecorationOptions for @model.ModelDecorationOptions with fn is_whole_line(
  self,
) {
  self.is_whole_line
}

///|
/// Placement of an inline decoration relative to the source text (Monaco's
/// `InlineDecorationType`, declared in `inlineDecorations.ts`).
pub(all) enum InlineDecorationType {
  Regular
  Before
  After
  RegularAffectingLetterSpacing
} derive(Eq, Debug)

///|
/// An inline decoration over a line/column `Range`.
pub(all) struct InlineDecoration {
  range : @base_common.Range
  inline_class_name : String
  type_ : InlineDecorationType
} derive(Eq, Debug)

///|
/// Builds an inline decoration (Monaco `new InlineDecoration(range, className, type)`).
pub fn InlineDecoration::new(
  range : @base_common.Range,
  inline_class_name : String,
  type_ : InlineDecorationType,
) -> InlineDecoration {
  { range, inline_class_name, type_ }
}

///|
/// A model decoration (Monaco `IModelDecoration`), generic in its options
/// tier `O` (see header).
pub(all) struct ModelDecoration[O] {
  id : String
  owner_id : Int
  range : @base_common.Range
  options : O
}

///|
/// A model decoration resolved into view coordinates (Monaco
/// `ViewModelDecoration`).
pub(all) struct ViewModelDecoration[O] {
  range : @base_common.Range
  options : O
}

///|
/// Builds a view-model decoration.
pub fn[O] ViewModelDecoration::new(
  range : @base_common.Range,
  options : O,
) -> ViewModelDecoration[O] {
  { range, options }
}

///|
/// Whether a model decoration is visible. See the file deviation: the
/// comment/string-token hiding paths are not ported (no tokenization seam, and
/// unused by the suite), so this is always `true`.
pub fn[O, M] is_model_decoration_visible(
  _model : M,
  _decoration : ModelDecoration[O],
) -> Bool {
  true
}

///|
/// Decorations in a range of lines: ungrouped, grouped per line as inline
/// decorations, and a per-line "affects fonts" flag (Monaco
/// `IViewDecorationsCollection`).
pub(all) struct ViewDecorationsCollection[O] {
  decorations : Array[ViewModelDecoration[O]]
  inline_decorations : Array[Array[InlineDecoration]]
  has_variable_fonts : Array[Bool]
}

///|
/// Context for `InlineModelDecorationsComputer`: yields model decorations for a
/// view range (Monaco `IInlineModelDecorationsComputerContext`).
pub(all) struct InlineModelContext[O] {
  get_model_decorations : (@base_common.Range, Bool, Bool) -> Array[
    ModelDecoration[O],
  ]
}

///|
/// Computes inline decorations from a model's decorations, mapped into view
/// coordinates and grouped per view line (Monaco
/// `InlineModelDecorationsComputer`).
pub struct InlineModelDecorationsComputer[O, M, C] {
  priv context : InlineModelContext[O]
  priv model : M
  priv coordinates_converter : C
  priv mut decorations_cache : Map[String, ViewModelDecoration[O]]
}

///|
/// Builds an inline-model-decorations computer.
pub fn[O, M, C] InlineModelDecorationsComputer::new(
  context : InlineModelContext[O],
  model : M,
  coordinates_converter : C,
) -> InlineModelDecorationsComputer[O, M, C] {
  { context, model, coordinates_converter, decorations_cache: Map([]) }
}

///|
/// Inline decorations for one model line, split by view line.
pub fn[
  O : InlineDecorationOptions,
  M : InlineDecorationsModel,
  C : CoordinatesConverter,
] InlineModelDecorationsComputer::get_inline_decorations(
  self : InlineModelDecorationsComputer[O, M, C],
  model_line_number : Int,
) -> Array[Array[InlineDecoration]] {
  let model_range = @base_common.Range::Range(
    model_line_number,
    1,
    model_line_number,
    self.model.get_line_max_column(model_line_number),
  )
  let view_range = self.coordinates_converter.convert_model_range_to_view_range(
    model_range,
  )
  self.get_decorations(view_range, false, false).inline_decorations
}

///|
/// Resolve the decorations intersecting a view range.
pub fn[
  O : InlineDecorationOptions,
  M : InlineDecorationsModel,
  C : CoordinatesConverter,
] InlineModelDecorationsComputer::get_decorations(
  self : InlineModelDecorationsComputer[O, M, C],
  view_range : @base_common.Range,
  only_minimap_decorations : Bool,
  only_margin_decorations : Bool,
) -> ViewDecorationsCollection[O] {
  let model_decorations = (self.context.get_model_decorations)(
    view_range, only_minimap_decorations, only_margin_decorations,
  )
  let start_line_number = view_range.start_line_number
  let end_line_number = view_range.end_line_number
  let decorations_in_viewport : Array[ViewModelDecoration[O]] = []
  let inline_decorations : Array[Array[InlineDecoration]] = []
  let has_variable_fonts : Array[Bool] = []
  for _j in start_line_number..<=end_line_number {
    inline_decorations.push([])
    has_variable_fonts.push(false)
  }
  for model_decoration in model_decorations {
    let decoration_options = model_decoration.options
    if !is_model_decoration_visible(self.model, model_decoration) {
      continue
    }
    let view_model_decoration = self.get_or_create_view_model_decoration(
      model_decoration,
    )
    let view_range = view_model_decoration.range
    decorations_in_viewport.push(view_model_decoration)
    match decoration_options.inline_class_name() {
      Some(inline_class_name) => {
        let type_ = if decoration_options.inline_class_name_affects_letter_spacing() {
          RegularAffectingLetterSpacing
        } else {
          Regular
        }
        let inline_decoration = InlineDecoration::new(
          view_range, inline_class_name, type_,
        )
        let intersected_start_line_number = start_line_number.max(
          view_range.start_line_number,
        )
        let intersected_end_line_number = end_line_number.min(
          view_range.end_line_number,
        )
        for j in intersected_start_line_number..<=intersected_end_line_number {
          inline_decorations[j - start_line_number].push(inline_decoration)
          if decoration_options.affects_font() {
            has_variable_fonts[j - start_line_number] = true
          }
        }
      }
      None => ()
    }
    match decoration_options.before_content_class_name() {
      Some(before_content_class_name) =>
        if start_line_number <= view_range.start_line_number &&
          view_range.start_line_number <= end_line_number {
          let inline_decoration = InlineDecoration::new(
            Range(
              view_range.start_line_number,
              view_range.start_column,
              view_range.start_line_number,
              view_range.start_column,
            ),
            before_content_class_name,
            Before,
          )
          inline_decorations[view_range.start_line_number - start_line_number].push(
            inline_decoration,
          )
          if decoration_options.affects_font() {
            has_variable_fonts[view_range.start_line_number - start_line_number] = true
          }
        }
      None => ()
    }
    match decoration_options.after_content_class_name() {
      Some(after_content_class_name) =>
        if start_line_number <= view_range.end_line_number &&
          view_range.end_line_number <= end_line_number {
          let inline_decoration = InlineDecoration::new(
            Range(
              view_range.end_line_number,
              view_range.end_column,
              view_range.end_line_number,
              view_range.end_column,
            ),
            after_content_class_name,
            After,
          )
          inline_decorations[view_range.end_line_number - start_line_number].push(
            inline_decoration,
          )
          if decoration_options.affects_font() {
            has_variable_fonts[view_range.end_line_number - start_line_number] = true
          }
        }
      None => ()
    }
  }
  {
    decorations: decorations_in_viewport,
    inline_decorations,
    has_variable_fonts,
  }
}

///|
/// Drop the per-decoration view-model cache.
pub fn[O, M, C] InlineModelDecorationsComputer::reset(
  self : InlineModelDecorationsComputer[O, M, C],
) -> Unit {
  self.decorations_cache = Map([])
}

///|
/// `onModelDecorationsChanged` (`inlineDecorations.ts:155-157`).
pub fn[O, M, C] InlineModelDecorationsComputer::on_model_decorations_changed(
  self : InlineModelDecorationsComputer[O, M, C],
) -> Unit {
  self.reset()
}

///|
/// `onLineMappingChanged` (`inlineDecorations.ts:159-161`).
pub fn[O, M, C] InlineModelDecorationsComputer::on_line_mapping_changed(
  self : InlineModelDecorationsComputer[O, M, C],
) -> Unit {
  self.reset()
}

///|
/// Re-resolve, or reuse the cached, view-model decoration for a model decoration.
fn[
  O : InlineDecorationOptions,
  M : InlineDecorationsModel,
  C : CoordinatesConverter,
] InlineModelDecorationsComputer::get_or_create_view_model_decoration(
  self : InlineModelDecorationsComputer[O, M, C],
  model_decoration : ModelDecoration[O],
) -> ViewModelDecoration[O] {
  let id = model_decoration.id
  match self.decorations_cache.get(id) {
    Some(r) => r
    None => {
      let model_range = model_decoration.range
      let options = model_decoration.options
      let view_range = if options.is_whole_line() {
        // For backwards compatibility, whole-line decorations span min..max
        // col, kept outside injected text (`inlineDecorations.ts:171-172`;
        // the source's `belowHiddenRanges` third argument has no viewer
        // counterpart — hidden-line handling lives in the projection).
        let start = self.coordinates_converter.convert_model_position_to_view_position(
          Position(model_range.start_line_number, 1),
          affinity=Left,
        )
        let end = self.coordinates_converter.convert_model_position_to_view_position(
          Position(
            model_range.end_line_number,
            self.model.get_line_max_column(model_range.end_line_number),
          ),
          affinity=Right,
        )
        @base_common.Range::Range(
          start.line_number,
          start.column,
          end.line_number,
          end.column,
        )
      } else {
        // `inlineDecorations.ts:177`: `Right` keeps an empty decoration
        // right of injected text at its position.
        self.coordinates_converter.convert_model_range_to_view_range(
          model_range,
          affinity=Right,
        )
      }
      let r = ViewModelDecoration::new(view_range, options)
      self.decorations_cache[id] = r
      r
    }
  }
}

///|
/// Injected-text rendering options (Monaco `InjectedTextOptions`).
pub(all) struct InjectedTextOptions {
  content : String
  inline_class_name : String?
  inline_class_name_affects_letter_spacing : Bool
} derive(Eq, Debug)

///|
/// Builds injected-text options.
pub fn InjectedTextOptions::new(
  content~ : String,
  inline_class_name? : String,
  inline_class_name_affects_letter_spacing? : Bool = false,
) -> InjectedTextOptions {
  { content, inline_class_name, inline_class_name_affects_letter_spacing }
}

///|
/// Context for `InjectedTextInlineDecorationsComputer` (Monaco
/// `IInjectedTextInlineDecorationsComputerContext`).
pub(all) struct InjectedTextContext {
  get_injection_options : (Int) -> Array[InjectedTextOptions]?
  get_injection_offsets : (Int) -> Array[Int]?
  get_break_offsets : (Int) -> Array[Int]
  get_wrapped_text_indent_length : (Int) -> Int
  get_base_view_line_number : (Int) -> Int
}

///|
/// Computes inline decorations for injected text, split by wrapped output line
/// (Monaco `InjectedTextInlineDecorationsComputer`).
pub struct InjectedTextInlineDecorationsComputer {
  priv context : InjectedTextContext
}

///|
/// Builds an injected-text inline-decorations computer.
pub fn InjectedTextInlineDecorationsComputer::new(
  context : InjectedTextContext,
) -> InjectedTextInlineDecorationsComputer {
  { context, }
}

///|
/// Inline decorations for the injected text of one model line, split by output
/// (wrapped) line.
pub fn InjectedTextInlineDecorationsComputer::get_inline_decorations(
  self : InjectedTextInlineDecorationsComputer,
  model_line_number : Int,
) -> Array[Array[InlineDecoration]] {
  let injection_offsets = (self.context.get_injection_offsets)(
    model_line_number,
  )
  guard injection_offsets is Some(injection_offsets) else { [] }
  let line_inline_decorations : Array[Array[InlineDecoration]] = []
  let mut total_injected_text_length_before = 0
  let mut current_injected_offset = 0
  let injection_options = (self.context.get_injection_options)(
    model_line_number,
  )
  let break_offsets = (self.context.get_break_offsets)(model_line_number)
  for output_line_index in 0..<break_offsets.length() {
    let inline_decorations : Array[InlineDecoration] = []
    line_inline_decorations.push(inline_decorations)
    let line_start_offset_in_input_with_injections = if output_line_index > 0 {
      break_offsets[output_line_index - 1]
    } else {
      0
    }
    let line_end_offset_in_input_with_injections = break_offsets[output_line_index]
    while current_injected_offset < injection_offsets.length() {
      let options = injection_options.unwrap()[current_injected_offset]
      let length = options.content.length()
      let injected_text_start_offset_in_input_with_injections = injection_offsets[current_injected_offset] +
        total_injected_text_length_before
      let injected_text_end_offset_in_input_with_injections = injected_text_start_offset_in_input_with_injections +
        length
      if injected_text_start_offset_in_input_with_injections >
        line_end_offset_in_input_with_injections {
        // Injected text only starts in later wrapped lines.
        break
      }
      if line_start_offset_in_input_with_injections <
        injected_text_end_offset_in_input_with_injections {
        // Injected text ends after or in this line (but also starts in/before).
        match options.inline_class_name {
          Some(inline_class_name) => {
            let wrapped_text_indent_length = (self.context.get_wrapped_text_indent_length)(
              model_line_number,
            )
            let offset = if output_line_index > 0 {
              wrapped_text_indent_length
            } else {
              0
            }
            let start = offset +
              (injected_text_start_offset_in_input_with_injections -
              line_start_offset_in_input_with_injections).max(0)
            let end = offset +
              (injected_text_end_offset_in_input_with_injections -
              line_start_offset_in_input_with_injections).min(
                line_end_offset_in_input_with_injections -
                line_start_offset_in_input_with_injections,
              )
            if start != end {
              let view_line_number = (self.context.get_base_view_line_number)(
                  model_line_number,
                ) +
                output_line_index
              let range = @base_common.Range::Range(
                view_line_number,
                start + 1,
                view_line_number,
                end + 1,
              )
              let type_ = if options.inline_class_name_affects_letter_spacing {
                RegularAffectingLetterSpacing
              } else {
                Regular
              }
              inline_decorations.push(
                InlineDecoration::new(range, inline_class_name, type_),
              )
            }
          }
          None => ()
        }
      }
      if injected_text_end_offset_in_input_with_injections <=
        line_end_offset_in_input_with_injections {
        total_injected_text_length_before = total_injected_text_length_before +
          length
        current_injected_offset = current_injected_offset + 1
      } else {
        // injected text breaks into next line, process it again
        break
      }
    }
  }
  line_inline_decorations
}
