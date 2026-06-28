///|
/// Continuation-line indentation mode, Monaco's `WrappingIndent`
/// (`config/editorOptions.ts`). Controls how far a wrapped continuation line is
/// indented under the first: `None` flush-left, `Same` under the model line's
/// own indent, `Indent`/`DeepIndent` one/two extra tab stops past it.
pub(all) enum WrappingIndent {
  None
  Same
  Indent
  DeepIndent
} derive(Eq, Debug)

///|
/// Width, in columns, of a full-width character — Monaco's
/// `columnsForFullWidthChar` (`Math.round(fullwidth / halfwidth)`), which for the
/// viewer's monospace font is `2`, matching `code_unit_width` for `code > 0xff`.
const COLUMNS_FOR_FULL_WIDTH_CHAR : Int = 2

///|
/// Monaco-inspired line-break calculator for monospace soft wrapping.
pub(all) struct LineBreaksComputer {
  wrapping_column : Int
  tab_size : Int
  wrapping_indent : WrappingIndent
} derive(Eq, Debug)

///|
priv enum CharacterClass {
  NoBreakClass
  BreakBefore
  BreakAfter
  BreakIdeographic
} derive(Eq)

///|
let word_wrap_break_after_characters = " \t})]?|/&.,;¢°′″‰℃、。｡､￠，．：；？！％・･ゝゞヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎゕゖㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻ｧｨｩｪｫｬｭｮｯｰ”〉》」』】〕）］｝｣"

///|
let word_wrap_break_before_characters = "([{‘“〈《「『【〔（［｛｢£¥＄￡￥+＋"

///|
/// Builds a line-break calculator with clamped wrapping and tab settings.
/// `wrapping_indent` defaults to `Same`, Monaco's default.
pub fn LineBreaksComputer::LineBreaksComputer(
  wrapping_column : Int,
  tab_size? : Int = 2,
  wrapping_indent? : WrappingIndent = Same,
) -> LineBreaksComputer {
  {
    wrapping_column: wrapping_column.max(0),
    tab_size: tab_size.max(1),
    wrapping_indent,
  }
}

///|
/// Computes wrapping segments for a raw model line.
pub fn LineBreaksComputer::compute_model_line_projection(
  self : LineBreaksComputer,
  model_line_number : Int,
  line_text : String,
) -> ModelLineProjectionData {
  self.compute_projected_line_projection(
    model_line_number,
    ProjectedTextLine::identity(line_text),
  )
}

///|
/// Computes wrapping segments for a projected line that may include injected
/// text.
pub fn LineBreaksComputer::compute_projected_line_projection(
  self : LineBreaksComputer,
  model_line_number : Int,
  projected_line : ProjectedTextLine,
) -> ModelLineProjectionData {
  let line_text = projected_line.text
  if self.wrapping_column <= 0 {
    return ModelLineProjectionData(
      model_line_number,
      projected_line.model_line_length,
      projected_line,
      [
        model_line_projection_segment(
          model_line_number,
          0,
          line_text.length(),
          0,
          false,
          0,
        ),
      ],
    )
  }
  if line_text.length() <= 1 {
    return ModelLineProjectionData(
      model_line_number,
      projected_line.model_line_length,
      projected_line,
      [
        model_line_projection_segment(
          model_line_number,
          0,
          line_text.length(),
          0,
          false,
          0,
        ),
      ],
    )
  }
  // Continuation lines are indented by `wrapped_text_indent_length` columns,
  // which shrinks their available break width to `wrapped_line_break_column`
  // (Monaco's `firstLineBreakColumn - wrappedTextIndentLength`). The first
  // segment still breaks at the full `wrapping_column`.
  let wrapped_text_indent_length = compute_wrapped_text_indent_length(
    line_text,
    self.tab_size,
    self.wrapping_column,
    self.wrapping_indent,
  )
  let wrapped_line_break_column = self.wrapping_column - wrapped_text_indent_length
  let segments : Array[ModelLineProjectionSegment] = []
  let mut segment_start = 0
  let mut segment_start_visible_column = 0
  let mut break_offset = 0
  let mut break_offset_visible_column = 0
  let mut breaking_column = self.wrapping_column
  let first_char = line_text[0]
  let mut previous_char_class = wrapping_character_class(first_char)
  let mut visible_column = code_unit_width(
    first_char.to_int(),
    0,
    self.tab_size,
  )
  for offset in 1..<line_text.length() {
    let ch = line_text[offset]
    let ch_class = wrapping_character_class(ch)
    let width = code_unit_width(ch.to_int(), visible_column, self.tab_size)
    if can_break(previous_char_class, ch, ch_class) {
      break_offset = offset
      break_offset_visible_column = visible_column
    }
    visible_column = visible_column + width
    if visible_column > breaking_column {
      if break_offset == 0 ||
        visible_column - break_offset_visible_column > wrapped_line_break_column {
        break_offset = offset
        break_offset_visible_column = visible_column - width
      }
      segments.push(
        model_line_projection_segment(
          model_line_number,
          segment_start,
          break_offset,
          segment_start_visible_column,
          segment_start > 0,
          indent_for_segment(segment_start, wrapped_text_indent_length),
        ),
      )
      segment_start = break_offset
      segment_start_visible_column = break_offset_visible_column
      breaking_column = break_offset_visible_column + wrapped_line_break_column
      break_offset = 0
      break_offset_visible_column = 0
    }
    previous_char_class = ch_class
  }
  segments.push(
    model_line_projection_segment(
      model_line_number,
      segment_start,
      line_text.length(),
      segment_start_visible_column,
      segment_start > 0,
      indent_for_segment(segment_start, wrapped_text_indent_length),
    ),
  )
  ModelLineProjectionData(
    model_line_number,
    projected_line.model_line_length,
    projected_line,
    segments,
  )
}

///|
/// The indent applied to one view-line segment: `0` for a model line's first
/// segment, `wrapped_text_indent_length` for every continuation segment. Mirrors
/// Monaco's `deltaStartIndex = (outputLineIndex > 0 ? wrappedTextIndentLength :
/// 0)` and `ModelLineProjectionData.getMinOutputOffset`.
fn indent_for_segment(
  segment_start : Int,
  wrapped_text_indent_length : Int,
) -> Int {
  if segment_start > 0 {
    wrapped_text_indent_length
  } else {
    0
  }
}

///|
/// Visible-column indent for continuation lines, Monaco's
/// `computeWrappedTextIndentLength` (`monospaceLineBreaksComputer.ts`). The
/// model line's own leading whitespace width, plus one/two extra tab stops for
/// `Indent`/`DeepIndent`; dropped to `0` when it would leave no room for content.
fn compute_wrapped_text_indent_length(
  line_text : String,
  tab_size : Int,
  first_line_break_column : Int,
  wrapping_indent : WrappingIndent,
) -> Int {
  let mut wrapped_text_indent_length = 0
  if wrapping_indent != None {
    let first_non_whitespace_index = @base_common.first_non_whitespace_index(
      line_text,
    )
    if first_non_whitespace_index != -1 {
      for i in 0..<first_non_whitespace_index {
        let char_width = if line_text[i].to_int() == 9 {
          code_unit_width(9, wrapped_text_indent_length, tab_size)
        } else {
          1
        }
        wrapped_text_indent_length = wrapped_text_indent_length + char_width
      }
      let number_of_additional_tabs = match wrapping_indent {
        DeepIndent => 2
        Indent => 1
        _ => 0
      }
      for _ in 0..<number_of_additional_tabs {
        let char_width = code_unit_width(9, wrapped_text_indent_length, tab_size)
        wrapped_text_indent_length = wrapped_text_indent_length + char_width
      }

      // If wrapping indent is greater than the entire wrapping column, leave it
      // out so a continuation line still has room for at least one character.
      if wrapped_text_indent_length + COLUMNS_FOR_FULL_WIDTH_CHAR >
        first_line_break_column {
        wrapped_text_indent_length = 0
      }
    }
  }
  wrapped_text_indent_length
}

///|
fn wrapping_character_class(ch : UInt16) -> CharacterClass {
  let code = ch.to_int()
  if code < 128 {
    return ascii_character_class(code)
  }
  if contains_code_unit(word_wrap_break_before_characters, code) {
    BreakBefore
  } else if contains_code_unit(word_wrap_break_after_characters, code) {
    BreakAfter
  } else if (code >= 0x3040 && code <= 0x30ff) ||
    (code >= 0x3400 && code <= 0x4dbf) ||
    (code >= 0x4e00 && code <= 0x9fff) {
    BreakIdeographic
  } else {
    NoBreakClass
  }
}

///|
fn ascii_character_class(code : Int) -> CharacterClass {
  if code == 40 || code == 91 || code == 123 || code == 43 {
    BreakBefore
  } else if code == 9 ||
    code == 32 ||
    code == 38 ||
    code == 41 ||
    code == 44 ||
    code == 46 ||
    code == 47 ||
    code == 59 ||
    code == 63 ||
    code == 93 ||
    code == 124 ||
    code == 125 {
    BreakAfter
  } else {
    NoBreakClass
  }
}

///|
fn can_break(
  previous_class : CharacterClass,
  ch : UInt16,
  ch_class : CharacterClass,
) -> Bool {
  ch.to_int() != 32 &&
  (
    (previous_class == BreakAfter && ch_class != BreakAfter) ||
    (previous_class != BreakBefore && ch_class == BreakBefore) ||
    (previous_class == BreakIdeographic && ch_class != BreakAfter) ||
    (ch_class == BreakIdeographic && previous_class != BreakBefore)
  )
}

///|
fn contains_code_unit(text : String, code : Int) -> Bool {
  for index in 0..<text.length() {
    if text[index].to_int() == code {
      return true
    }
  }
  false
}

///|
fn code_unit_width(code : Int, visible_column : Int, tab_size : Int) -> Int {
  if code == 9 {
    let remainder = visible_column % tab_size
    if remainder == 0 {
      tab_size
    } else {
      tab_size - remainder
    }
  } else if code > 0xff {
    2
  } else {
    1
  }
}
