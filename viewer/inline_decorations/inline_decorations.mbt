///|
/// Faithful 1:1 port of Monaco's `viewModel/inlineDecorations.ts`
/// (`InlineDecoration`, `InlineDecorationType`, `InlineModelDecorationsComputer`,
/// `InjectedTextInlineDecorationsComputer`) plus the minimal collaborators its
/// unit suite needs (`ViewModelDecoration` + `isModelDecorationVisible` from
/// `viewModel/viewModelDecoration.ts`, `IdentityCoordinatesConverter` from
/// `coordinatesConverter.ts`, and a `createTextModel`-style text model), from
/// vscode submodule commit 294fb350837dbaee37b949533fead4df4e0e8971.
///
/// This lives in its own package rather than `viewer/view_model` to keep the
/// faithful Monaco type names (`InlineDecoration`, `ViewModelDecoration`) — the
/// existing view-model pipeline already defines a simplified `ViewModelDecoration`
/// (`{range, kind, class_name}`) and reuses the renderer's column-span
/// `InlineDecoration`, both of which would collide here.
///
/// DEVIATIONS (recorded; none exercised by the suite):
///   * `isModelDecorationVisible` always returns `true`: the
///     `hideInCommentTokens`/`hideInStringTokens` paths need a tokenization seam
///     this readonly port does not carry, and no `inlineDecorations.test.ts` case
///     sets those flags.
///   * line lengths use `String::length()` (UTF-16 code units, matching Monaco)
///     over a `\n`-split model; the fixtures are single-`\n`, ASCII text.

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
/// Decoration render options — the subset of `IModelDecorationOptions` the
/// inline-decoration computer reads.
pub(all) struct ModelDecorationOptions {
  description : String
  class_name : String?
  inline_class_name : String?
  inline_class_name_affects_letter_spacing : Bool
  before_content_class_name : String?
  after_content_class_name : String?
  affects_font : Bool
  is_whole_line : Bool
} derive(Eq, Debug)

///|
/// Builds decoration options, defaulting every optional field the way an absent
/// JS property would.
pub fn ModelDecorationOptions::new(
  description? : String = "",
  class_name? : String,
  inline_class_name? : String,
  inline_class_name_affects_letter_spacing? : Bool = false,
  before_content_class_name? : String,
  after_content_class_name? : String,
  affects_font? : Bool = false,
  is_whole_line? : Bool = false,
) -> ModelDecorationOptions {
  {
    description,
    class_name,
    inline_class_name,
    inline_class_name_affects_letter_spacing,
    before_content_class_name,
    after_content_class_name,
    affects_font,
    is_whole_line,
  }
}

///|
/// A model decoration (Monaco `IModelDecoration`).
pub(all) struct ModelDecoration {
  id : String
  owner_id : Int
  range : @base_common.Range
  options : ModelDecorationOptions
} derive(Eq, Debug)

///|
/// A model decoration resolved into view coordinates (Monaco
/// `ViewModelDecoration`). Held as the cache value / `decorations` output of the
/// computer; the suite checks its identity and count, not its fields.
pub(all) struct ViewModelDecoration {
  range : @base_common.Range
  options : ModelDecorationOptions
} derive(Eq, Debug)

///|
/// Builds a view-model decoration.
pub fn ViewModelDecoration::new(
  range : @base_common.Range,
  options : ModelDecorationOptions,
) -> ViewModelDecoration {
  { range, options }
}

///|
/// Whether a model decoration is visible. See the file deviation: the
/// comment/string-token hiding paths are not ported (no tokenization seam, and
/// unused by the suite), so this is always `true`.
pub fn is_model_decoration_visible(
  _model : TextModel,
  _decoration : ModelDecoration,
) -> Bool {
  true
}

///|
/// Minimal `ITextModel` stand-in (Monaco `createTextModel`): holds the document
/// lines and answers the column/validation queries the computer and converter
/// need.
pub(all) struct TextModel {
  lines : Array[String]
}

///|
/// Splits `text` into logical lines on `\n` (the suite uses `\n` only).
pub fn TextModel::create(text : String) -> TextModel {
  let lines : Array[String] = []
  let mut buf = StringBuilder::new()
  for ch in text {
    if ch == '\n' {
      lines.push(buf.to_string())
      buf = StringBuilder::new()
    } else {
      buf.write_char(ch)
    }
  }
  lines.push(buf.to_string())
  { lines, }
}

///|
/// Number of logical lines.
pub fn TextModel::get_line_count(self : TextModel) -> Int {
  self.lines.length()
}

///|
/// One past the last column of `line_number` (1-based; UTF-16 length + 1).
pub fn TextModel::get_line_max_column(
  self : TextModel,
  line_number : Int,
) -> Int {
  self.lines[line_number - 1].length() + 1
}

///|
/// Clamps a position into the document (Monaco `validatePosition`).
pub fn TextModel::validate_position(
  self : TextModel,
  pos : @base_common.Position,
) -> @base_common.Position {
  let line = @base_common.clamp_int(pos.line_number, 1, self.get_line_count())
  let column = @base_common.clamp_int(
    pos.column,
    1,
    self.get_line_max_column(line),
  )
  Position(line, column)
}

///|
/// Clamps a range into the document (Monaco `validateRange`).
pub fn TextModel::validate_range(
  self : TextModel,
  range : @base_common.Range,
) -> @base_common.Range {
  let start = self.validate_position(
    Position(range.start_line_number, range.start_column),
  )
  let end = self.validate_position(
    Position(range.end_line_number, range.end_column),
  )
  Range(start.line_number, start.column, end.line_number, end.column)
}

///|
/// The trivial 1:1 view↔model converter (Monaco `IdentityCoordinatesConverter`):
/// every conversion is a validation against the model. `PositionAffinity` is
/// irrelevant here and omitted.
pub(all) struct IdentityCoordinatesConverter {
  model : TextModel
}

///|
/// Builds an identity coordinates converter.
pub fn IdentityCoordinatesConverter::new(
  model : TextModel,
) -> IdentityCoordinatesConverter {
  { model, }
}

///|
pub fn IdentityCoordinatesConverter::convert_model_position_to_view_position(
  self : IdentityCoordinatesConverter,
  model_position : @base_common.Position,
) -> @base_common.Position {
  self.model.validate_position(model_position)
}

///|
pub fn IdentityCoordinatesConverter::convert_model_range_to_view_range(
  self : IdentityCoordinatesConverter,
  model_range : @base_common.Range,
) -> @base_common.Range {
  self.model.validate_range(model_range)
}

///|
/// Decorations in a range of lines: ungrouped, grouped per line as inline
/// decorations, and a per-line "affects fonts" flag (Monaco
/// `IViewDecorationsCollection`).
pub(all) struct ViewDecorationsCollection {
  decorations : Array[ViewModelDecoration]
  inline_decorations : Array[Array[InlineDecoration]]
  has_variable_fonts : Array[Bool]
}

///|
/// Context for `InlineModelDecorationsComputer`: yields model decorations for a
/// view range (Monaco `IInlineModelDecorationsComputerContext`).
pub(all) struct InlineModelContext {
  get_model_decorations : (@base_common.Range, Bool, Bool) -> Array[
    ModelDecoration,
  ]
}

///|
/// Computes inline decorations from a model's decorations, mapped into view
/// coordinates and grouped per view line (Monaco
/// `InlineModelDecorationsComputer`).
pub struct InlineModelDecorationsComputer {
  priv context : InlineModelContext
  priv model : TextModel
  priv coordinates_converter : IdentityCoordinatesConverter
  priv mut decorations_cache : Map[String, ViewModelDecoration]
}

///|
/// Builds an inline-model-decorations computer.
pub fn InlineModelDecorationsComputer::new(
  context : InlineModelContext,
  model : TextModel,
  coordinates_converter : IdentityCoordinatesConverter,
) -> InlineModelDecorationsComputer {
  { context, model, coordinates_converter, decorations_cache: {} }
}

///|
/// Inline decorations for one model line, split by view line.
pub fn InlineModelDecorationsComputer::get_inline_decorations(
  self : InlineModelDecorationsComputer,
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
pub fn InlineModelDecorationsComputer::get_decorations(
  self : InlineModelDecorationsComputer,
  view_range : @base_common.Range,
  only_minimap_decorations : Bool,
  only_margin_decorations : Bool,
) -> ViewDecorationsCollection {
  let model_decorations = (self.context.get_model_decorations)(
    view_range, only_minimap_decorations, only_margin_decorations,
  )
  let start_line_number = view_range.start_line_number
  let end_line_number = view_range.end_line_number
  let decorations_in_viewport : Array[ViewModelDecoration] = []
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
    match decoration_options.inline_class_name {
      Some(inline_class_name) => {
        let type_ = if decoration_options.inline_class_name_affects_letter_spacing {
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
          if decoration_options.affects_font {
            has_variable_fonts[j - start_line_number] = true
          }
        }
      }
      None => ()
    }
    match decoration_options.before_content_class_name {
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
          if decoration_options.affects_font {
            has_variable_fonts[view_range.start_line_number - start_line_number] = true
          }
        }
      None => ()
    }
    match decoration_options.after_content_class_name {
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
          if decoration_options.affects_font {
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
pub fn InlineModelDecorationsComputer::reset(
  self : InlineModelDecorationsComputer,
) -> Unit {
  self.decorations_cache = {}
}

///|
/// Re-resolve, or reuse the cached, view-model decoration for a model decoration.
fn InlineModelDecorationsComputer::get_or_create_view_model_decoration(
  self : InlineModelDecorationsComputer,
  model_decoration : ModelDecoration,
) -> ViewModelDecoration {
  let id = model_decoration.id
  match self.decorations_cache.get(id) {
    Some(r) => r
    None => {
      let model_range = model_decoration.range
      let options = model_decoration.options
      let view_range = if options.is_whole_line {
        // For backwards compatibility, whole-line decorations span min..max col.
        let start = self.coordinates_converter.convert_model_position_to_view_position(
          Position(model_range.start_line_number, 1),
        )
        let end = self.coordinates_converter.convert_model_position_to_view_position(
          Position(
            model_range.end_line_number,
            self.model.get_line_max_column(model_range.end_line_number),
          ),
        )
        @base_common.Range::Range(
          start.line_number,
          start.column,
          end.line_number,
          end.column,
        )
      } else {
        self.coordinates_converter.convert_model_range_to_view_range(
          model_range,
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
