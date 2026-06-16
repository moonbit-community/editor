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
