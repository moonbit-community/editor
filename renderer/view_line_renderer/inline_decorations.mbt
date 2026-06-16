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
