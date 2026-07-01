///|
/// Direction metadata for a rendered line.
pub(all) enum TextDirection {
  LTR
  RTL
} derive(Eq, Debug)

///|
/// Whitespace rendering mode, matching the subset needed by the viewer.
pub(all) enum RenderWhitespace {
  None
  Boundary
  Selection
  Trailing
  All
} derive(Eq, Debug)

///|
/// Inline decoration placement relative to source text.
pub(all) enum InlineDecorationType {
  Regular
  Before
  After
  RegularAffectingLetterSpacing
} derive(Eq, Debug)

///|
/// Whether a rendered line contains pseudo-elements before or after text.
pub(all) enum ForeignElementType {
  None
  Before
  After
} derive(Eq, Debug)

///|
/// One-based line/column range used by line-renderer contracts.
pub(all) struct ViewRange {
  start_line_number : Int
  start_column : Int
  end_line_number : Int
  end_column : Int
} derive(Eq, Debug)

///|
/// Tokenized segment ending at `end_index` with CSS and metadata flags.
pub(all) struct LinePart {
  end_index : Int
  class_name : String
  metadata : Int
  contains_rtl : Bool
} derive(Eq, Debug)

///|
/// Builds a line part.
pub fn LinePart::LinePart(
  end_index : Int,
  class_name : String,
  metadata? : Int = 0,
  contains_rtl? : Bool = false,
) -> LinePart {
  { end_index, class_name, metadata, contains_rtl }
}

///|
/// Whether this part represents visible whitespace.
pub fn LinePart::is_whitespace(self : LinePart) -> Bool {
  (self.metadata & line_part_metadata_is_whitespace) != 0
}

///|
/// Whether this part is a before pseudo-element.
pub fn LinePart::is_pseudo_before(self : LinePart) -> Bool {
  (self.metadata & line_part_metadata_pseudo_before) != 0
}

///|
/// Whether this part is an after pseudo-element.
pub fn LinePart::is_pseudo_after(self : LinePart) -> Bool {
  (self.metadata & line_part_metadata_pseudo_after) != 0
}

///|
let line_part_metadata_is_whitespace = 1

///|
let line_part_metadata_pseudo_before = 2

///|
let line_part_metadata_pseudo_after = 4
