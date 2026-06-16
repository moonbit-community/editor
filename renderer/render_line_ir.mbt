///|
pub(all) enum TextDirection {
  LTR
  RTL
} derive(Eq, Debug)

///|
pub(all) enum RenderWhitespace {
  None
  Boundary
  Selection
  Trailing
  All
} derive(Eq, Debug)

///|
pub(all) enum InlineDecorationType {
  Regular
  Before
  After
  RegularAffectingLetterSpacing
} derive(Eq, Debug)

///|
pub(all) enum ForeignElementType {
  None
  Before
  After
} derive(Eq, Debug)

///|
pub(all) struct ViewRange {
  start_line_number : Int
  start_column : Int
  end_line_number : Int
  end_column : Int
} derive(Eq, Debug)

///|
pub(all) struct LinePart {
  end_index : Int
  class_name : String
  metadata : Int
  contains_rtl : Bool
} derive(Eq, Debug)

///|
pub fn LinePart::LinePart(
  end_index : Int,
  class_name : String,
  metadata? : Int = 0,
  contains_rtl? : Bool = false,
) -> LinePart {
  { end_index, class_name, metadata, contains_rtl }
}

///|
pub fn LinePart::is_whitespace(self : LinePart) -> Bool {
  (self.metadata & line_part_metadata_is_whitespace) != 0
}

///|
pub fn LinePart::is_pseudo_before(self : LinePart) -> Bool {
  (self.metadata & line_part_metadata_pseudo_before) != 0
}

///|
pub fn LinePart::is_pseudo_after(self : LinePart) -> Bool {
  (self.metadata & line_part_metadata_pseudo_after) != 0
}

///|
let line_part_metadata_is_whitespace = 1

///|
let line_part_metadata_pseudo_before = 2

///|
let line_part_metadata_pseudo_after = 4

///|
pub(all) struct InlineDecoration {
  range : @core.Range
  class_name : String
  decoration_type : InlineDecorationType
} derive(Eq, Debug)

///|
pub fn InlineDecoration::InlineDecoration(
  range : @core.Range,
  class_name : String,
  decoration_type? : InlineDecorationType = Regular,
) -> InlineDecoration {
  { range, class_name, decoration_type }
}

///|
pub(all) struct LineDecoration {
  start_column : Int
  end_column : Int
  class_name : String
  decoration_type : InlineDecorationType
} derive(Eq, Debug)

///|
pub fn LineDecoration::LineDecoration(
  start_column : Int,
  end_column : Int,
  class_name : String,
  decoration_type? : InlineDecorationType = Regular,
) -> LineDecoration {
  { start_column, end_column, class_name, decoration_type }
}

///|
pub fn LineDecoration::compare(
  left : LineDecoration,
  right : LineDecoration,
) -> Int {
  if left.start_column != right.start_column {
    left.start_column - right.start_column
  } else if left.end_column != right.end_column {
    left.end_column - right.end_column
  } else {
    let type_cmp = inline_decoration_type_order(left.decoration_type) -
      inline_decoration_type_order(right.decoration_type)
    if type_cmp != 0 {
      type_cmp
    } else if left.class_name < right.class_name {
      -1
    } else if left.class_name > right.class_name {
      1
    } else {
      0
    }
  }
}

///|
fn inline_decoration_type_order(decoration_type : InlineDecorationType) -> Int {
  match decoration_type {
    Before => 0
    After => 1
    Regular => 2
    RegularAffectingLetterSpacing => 3
  }
}

///|
pub(all) struct DecorationSegment {
  start_offset : Int
  end_offset : Int
  class_name : String
  metadata : Int
} derive(Eq, Debug)

///|
pub(all) struct LineDecorationsNormalizer {}

///|
pub fn LineDecorationsNormalizer::normalize(
  line_content : String,
  line_decorations : Array[LineDecoration],
) -> Array[DecorationSegment] {
  if line_decorations.length() == 0 {
    return []
  }
  let result : Array[DecorationSegment] = []
  let stack = DecorationSegmentStack::new()
  let line_length = line_content.length()
  let mut next_start_offset = 0
  for decoration in line_decorations {
    let mut start_column = decoration.start_column
    let mut end_column = decoration.end_column
    if start_column > 1 &&
      start_column - 2 < line_length &&
      is_high_surrogate(line_content[start_column - 2].to_int()) {
      start_column = start_column - 1
    }
    if end_column > 1 &&
      end_column - 2 < line_length &&
      is_high_surrogate(line_content[end_column - 2].to_int()) {
      end_column = end_column - 1
    }
    let start_offset = @core.clamp_int(start_column - 1, 0, line_length)
    let max_end_offset = if line_length == 0 {
      start_offset - 1
    } else {
      line_length - 1
    }
    let end_offset_high = if max_end_offset < start_offset - 1 {
      start_offset - 1
    } else {
      max_end_offset
    }
    let end_offset = @core.clamp_int(
      end_column - 2,
      start_offset - 1,
      end_offset_high,
    )
    next_start_offset = stack.consume_lower_than(
      start_offset, next_start_offset, result,
    )
    if stack.count == 0 {
      next_start_offset = start_offset
    }
    stack.insert(
      end_offset,
      decoration.class_name,
      line_decoration_metadata(decoration.decoration_type),
    )
  }
  stack.consume_lower_than(2147483647, next_start_offset, result) |> ignore
  result
}

///|
priv struct DecorationSegmentStack {
  stop_offsets : Array[Int]
  class_names : Array[String]
  metadata : Array[Int]
  mut count : Int
}

///|
fn DecorationSegmentStack::new() -> DecorationSegmentStack {
  { stop_offsets: [], class_names: [], metadata: [], count: 0 }
}

///|
fn DecorationSegmentStack::consume_lower_than(
  self : DecorationSegmentStack,
  max_stop_offset : Int,
  next_start_offset : Int,
  result : Array[DecorationSegment],
) -> Int {
  let mut offset = next_start_offset
  while self.count > 0 && self.stop_offsets[0] < max_stop_offset {
    let mut stop_index = 0
    while stop_index + 1 < self.count &&
          self.stop_offsets[stop_index] == self.stop_offsets[stop_index + 1] {
      stop_index = stop_index + 1
    }
    result.push({
      start_offset: offset,
      end_offset: self.stop_offsets[stop_index],
      class_name: self.class_names.join(" "),
      metadata: decoration_stack_metadata(self.metadata),
    })
    offset = self.stop_offsets[stop_index] + 1
    for _ in 0..<=stop_index {
      self.stop_offsets.remove(0) |> ignore
      self.class_names.remove(0) |> ignore
      self.metadata.remove(0) |> ignore
    }
    self.count = self.count - stop_index - 1
  }
  if self.count > 0 && offset < max_stop_offset {
    result.push({
      start_offset: offset,
      end_offset: max_stop_offset - 1,
      class_name: self.class_names.join(" "),
      metadata: decoration_stack_metadata(self.metadata),
    })
    offset = max_stop_offset
  }
  offset
}

///|
fn DecorationSegmentStack::insert(
  self : DecorationSegmentStack,
  stop_offset : Int,
  class_name : String,
  metadata : Int,
) -> Unit {
  if self.count == 0 || self.stop_offsets[self.count - 1] <= stop_offset {
    self.stop_offsets.push(stop_offset)
    self.class_names.push(class_name)
    self.metadata.push(metadata)
  } else {
    let mut inserted = false
    let mut index = 0
    while index < self.count && !inserted {
      if self.stop_offsets[index] >= stop_offset {
        self.stop_offsets.insert(index, stop_offset)
        self.class_names.insert(index, class_name)
        self.metadata.insert(index, metadata)
        inserted = true
      }
      index = index + 1
    }
  }
  self.count = self.count + 1
}

///|
fn decoration_stack_metadata(metadata : Array[Int]) -> Int {
  let mut result = 0
  for item in metadata {
    result = result | item
  }
  result
}

///|
fn line_decoration_metadata(decoration_type : InlineDecorationType) -> Int {
  match decoration_type {
    Regular => 0
    Before => line_part_metadata_pseudo_before
    After => line_part_metadata_pseudo_after
    RegularAffectingLetterSpacing => 0
  }
}

///|
fn is_high_surrogate(code : Int) -> Bool {
  code >= 0xd800 && code <= 0xdbff
}

///|
pub(all) struct ViewLineRenderingData {
  min_column : Int
  max_column : Int
  content : String
  continues_with_wrapped_line : Bool
  contains_rtl : Bool
  is_basic_ascii : Bool
  tokens : Array[LinePart]
  inline_decorations : Array[InlineDecoration]
  tab_size : Int
  start_visible_column : Int
  text_direction : TextDirection
  has_variable_fonts : Bool
} derive(Eq, Debug)

///|
pub fn ViewLineRenderingData::from_render_line(
  line : RenderLine,
  decorations? : Array[@decorations.Decoration] = [],
) -> ViewLineRenderingData {
  {
    min_column: 1,
    max_column: line.text.length() + 1,
    content: line.text,
    continues_with_wrapped_line: false,
    contains_rtl: contains_rtl(line.text),
    is_basic_ascii: is_basic_ascii(line.text),
    tokens: line_parts_from_render_line(line),
    inline_decorations: inline_decorations_for_line(line, decorations),
    tab_size: 2,
    start_visible_column: 0,
    text_direction: LTR,
    has_variable_fonts: false,
  }
}

///|
pub(all) struct ViewportData {
  start_line_number : Int
  end_line_number : Int
  relative_vertical_offset : Array[Int]
  line_height : Int
  visible_range : ViewRange
  big_numbers_delta : Int
  lines : Array[ViewLineRenderingData]
  line_decorations : Array[Array[LineDecoration]]
} derive(Eq, Debug)

///|
pub fn ViewportData::from_render_frame(
  frame : RenderFrame,
  line_height~ : Int,
  decorations? : Array[@decorations.Decoration] = [],
) -> ViewportData {
  let lines : Array[ViewLineRenderingData] = []
  let line_decorations : Array[Array[LineDecoration]] = []
  let relative_vertical_offset : Array[Int] = []
  for index in 0..<frame.lines.length() {
    let line = frame.lines[index]
    lines.push(ViewLineRenderingData::from_render_line(line, decorations~))
    line_decorations.push(line_decorations_for_line(line, decorations))
    relative_vertical_offset.push(index * line_height)
  }
  let start_line_number = frame.viewport.start_line + 1
  let end_line_number = frame.viewport.end_line
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

///|
pub fn ViewportData::line_data(
  self : ViewportData,
  line_number : Int,
) -> ViewLineRenderingData? {
  let index = line_number - self.start_line_number
  if index >= 0 && index < self.lines.length() {
    Some(self.lines[index])
  } else {
    None
  }
}

///|
pub fn ViewportData::decorations_for_line(
  self : ViewportData,
  line_number : Int,
) -> Array[LineDecoration] {
  let index = line_number - self.start_line_number
  match self.line_decorations.get(index) {
    Some(decorations) => decorations
    None => []
  }
}

///|
pub fn ViewportData::decorations_in_viewport(
  self : ViewportData,
) -> Array[LineDecoration] {
  let out : Array[LineDecoration] = []
  for line in self.line_decorations {
    for decoration in line {
      out.push(decoration)
    }
  }
  out
}

///|
pub fn RenderFrame::to_viewport_data(
  self : RenderFrame,
  line_height~ : Int,
  decorations? : Array[@decorations.Decoration] = [],
) -> ViewportData {
  ViewportData::from_render_frame(self, line_height~, decorations~)
}

///|
pub(all) struct RenderLineInput {
  use_monospace_optimizations : Bool
  can_use_halfwidth_rightwards_arrow : Bool
  line_content : String
  continues_with_wrapped_line : Bool
  is_basic_ascii : Bool
  contains_rtl : Bool
  faux_indent_length : Int
  line_tokens : Array[LinePart]
  line_decorations : Array[LineDecoration]
  tab_size : Int
  start_visible_column : Int
  space_width : Double
  middot_width : Double
  wsmiddot_width : Double
  stop_rendering_line_after : Int
  render_whitespace : RenderWhitespace
  render_control_characters : Bool
  font_ligatures : Bool
  selections_on_line : Array[@core.Range]
  text_direction : TextDirection
  vertical_scrollbar_size : Double
  render_new_line_when_empty : Bool
} derive(Eq, Debug)

///|
pub fn RenderLineInput::from_view_line(
  data : ViewLineRenderingData,
  line_decorations? : Array[LineDecoration] = [],
  use_monospace_optimizations? : Bool = true,
  can_use_halfwidth_rightwards_arrow? : Bool = true,
  faux_indent_length? : Int = 0,
  space_width? : Double = 7.2,
  middot_width? : Double = 7.2,
  wsmiddot_width? : Double = 7.2,
  stop_rendering_line_after? : Int = -1,
  render_whitespace? : RenderWhitespace = None,
  render_control_characters? : Bool = false,
  font_ligatures? : Bool = false,
  selections_on_line? : Array[@core.Range] = [],
  vertical_scrollbar_size? : Double = 0.0,
  render_new_line_when_empty? : Bool = false,
) -> RenderLineInput {
  let sorted_line_decorations = line_decorations.copy()
  sorted_line_decorations.sort_by(LineDecoration::compare)
  {
    use_monospace_optimizations,
    can_use_halfwidth_rightwards_arrow,
    line_content: data.content,
    continues_with_wrapped_line: data.continues_with_wrapped_line,
    is_basic_ascii: data.is_basic_ascii,
    contains_rtl: data.contains_rtl,
    faux_indent_length,
    line_tokens: data.tokens,
    line_decorations: sorted_line_decorations,
    tab_size: data.tab_size,
    start_visible_column: data.start_visible_column,
    space_width,
    middot_width,
    wsmiddot_width,
    stop_rendering_line_after,
    render_whitespace,
    render_control_characters,
    font_ligatures,
    selections_on_line,
    text_direction: data.text_direction,
    vertical_scrollbar_size,
    render_new_line_when_empty,
  }
}

///|
pub fn RenderLineInput::from_render_line(
  line : RenderLine,
  decorations? : Array[@decorations.Decoration] = [],
  space_width? : Double = 7.2,
  vertical_scrollbar_size? : Double = 0.0,
) -> RenderLineInput {
  let data = ViewLineRenderingData::from_render_line(line, decorations~)
  RenderLineInput::from_view_line(
    data,
    line_decorations=line_decorations_for_line(line, decorations),
    space_width~,
    vertical_scrollbar_size~,
  )
}

///|
pub(all) struct DomPosition {
  part_index : Int
  char_index : Int
} derive(Eq, Debug)

///|
pub(all) struct CharacterMappingEntry {
  part_index : Int
  char_index : Int
  visible_column : Int
} derive(Eq, Debug)

///|
pub(all) struct CharacterMapping {
  length : Int
  entries : Array[CharacterMappingEntry]
} derive(Eq, Debug)

///|
pub fn CharacterMapping::new(length : Int) -> CharacterMapping {
  let entries : Array[CharacterMappingEntry] = []
  for _ in 0..<length {
    entries.push({ part_index: 0, char_index: 0, visible_column: 0 })
  }
  { length, entries }
}

///|
pub fn CharacterMapping::set_column_info(
  self : CharacterMapping,
  column : Int,
  part_index : Int,
  char_index : Int,
  visible_column : Int,
) -> Unit {
  let index = column - 1
  if index >= 0 && index < self.entries.length() {
    self.entries[index] = { part_index, char_index, visible_column }
  }
}

///|
pub fn CharacterMapping::get_dom_position(
  self : CharacterMapping,
  column : Int,
) -> DomPosition {
  if self.length == 0 {
    return { part_index: 0, char_index: 0 }
  }
  let index = @core.clamp_int(column - 1, 0, self.length - 1)
  let entry = self.entries[index]
  { part_index: entry.part_index, char_index: entry.char_index }
}

///|
pub fn CharacterMapping::get_column(
  self : CharacterMapping,
  dom_position : DomPosition,
  part_length : Int,
) -> Int {
  if self.length == 0 {
    return 1
  }
  let search = mapping_rank(dom_position.part_index, dom_position.char_index)
  let mut best = 0
  let mut best_distance = abs_int(mapping_rank_entry(self.entries[0]) - search)
  for index in 1..<self.entries.length() {
    let entry = self.entries[index]
    let rank = mapping_rank_entry(entry)
    if rank == search {
      return index + 1
    }
    let distance = if entry.part_index == dom_position.part_index {
      abs_int(entry.char_index - dom_position.char_index)
    } else if entry.part_index < dom_position.part_index {
      abs_int(part_length - entry.char_index + dom_position.char_index)
    } else {
      abs_int(part_length - dom_position.char_index + entry.char_index)
    }
    if distance < best_distance {
      best = index
      best_distance = distance
    }
  }
  best + 1
}

///|
pub fn CharacterMapping::get_horizontal_offset(
  self : CharacterMapping,
  column : Int,
) -> Int {
  if self.length == 0 {
    return 0
  }
  let index = @core.clamp_int(column - 1, 0, self.length - 1)
  self.entries[index].visible_column
}

///|
pub fn CharacterMapping::column_horizontal_offset(
  self : CharacterMapping,
  column : Int,
  space_width~ : Double,
) -> Double {
  self.get_horizontal_offset(column).to_double() * space_width
}

///|
pub fn CharacterMapping::inflate(
  self : CharacterMapping,
) -> Array[CharacterMappingEntry] {
  self.entries.copy()
}

///|
fn mapping_rank(part_index : Int, char_index : Int) -> Int {
  part_index * 65536 + char_index
}

///|
fn mapping_rank_entry(entry : CharacterMappingEntry) -> Int {
  mapping_rank(entry.part_index, entry.char_index)
}

///|
pub(all) struct RenderLineOutput {
  character_mapping : CharacterMapping
  contains_foreign_elements : ForeignElementType
} derive(Eq, Debug)

///|
pub(all) struct RenderLineOutput2 {
  html : String
  character_mapping : CharacterMapping
  contains_foreign_elements : ForeignElementType
} derive(Eq, Debug)

///|
fn line_parts_from_render_line(line : RenderLine) -> Array[LinePart] {
  let parts : Array[LinePart] = []
  if line.spans.length() == 0 {
    if line.text.length() > 0 {
      parts.push(LinePart(line.text.length(), @syntax.Plain.css_class()))
    }
    return parts
  }
  for span in line.spans {
    parts.push(
      LinePart(
        span.end,
        span.class_name,
        contains_rtl=contains_rtl(line.span_text(span)),
      ),
    )
  }
  parts
}

///|
fn inline_decorations_for_line(
  line : RenderLine,
  decorations : Array[@decorations.Decoration],
) -> Array[InlineDecoration] {
  let inline : Array[InlineDecoration] = []
  let line_start = line.offset
  let line_end = line.offset + line.text.length()
  for decoration in decorations {
    if decoration.kind == CurrentLine {
      continue
    }
    let range = decoration.range
    if range.intersects(Range(line_start, line_end)) {
      inline.push(
        InlineDecoration(
          Range(
            max_int(line_start, range.start) - line_start,
            min_int(line_end, range.end) - line_start,
          ),
          decoration.class_name,
        ),
      )
    }
  }
  inline
}

///|
fn line_decorations_for_line(
  line : RenderLine,
  decorations : Array[@decorations.Decoration],
) -> Array[LineDecoration] {
  let line_decorations : Array[LineDecoration] = []
  let line_start = line.offset
  let line_end = line.offset + line.text.length()
  for decoration in decorations {
    if decoration.kind == CurrentLine {
      continue
    }
    let range = decoration.range
    if range.intersects(Range(line_start, line_end)) {
      line_decorations.push(
        LineDecoration(
          max_int(line_start, range.start) - line_start + 1,
          min_int(line_end, range.end) - line_start + 1,
          decoration.class_name,
        ),
      )
    }
  }
  line_decorations
}

///|
fn is_basic_ascii(text : String) -> Bool {
  for i in 0..<text.length() {
    if text[i].to_int() > 127 {
      return false
    }
  }
  true
}

///|
fn contains_rtl(text : String) -> Bool {
  for i in 0..<text.length() {
    let code = text[i].to_int()
    if (code >= 0x0590 && code <= 0x08ff) ||
      (code >= 0xfb1d && code <= 0xfdff) ||
      (code >= 0xfe70 && code <= 0xfeff) {
      return true
    }
  }
  false
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}
