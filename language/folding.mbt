///|
pub(all) enum FoldingRangeKind {
  Comment
  Imports
  Region
} derive(Eq, Debug)

///|
pub(all) struct FoldingRange {
  start_line_number : Int
  end_line_number : Int
  kind : FoldingRangeKind?
} derive(Eq, Debug)

///|
pub fn FoldingRange::FoldingRange(
  start_line_number : Int,
  end_line_number : Int,
  kind? : FoldingRangeKind,
) -> FoldingRange {
  { start_line_number, end_line_number, kind }
}

///|
pub(open) trait FoldingRangeProvider {
  async fn folding_ranges(Self, @workspace.SourceDocument) -> Array[
    FoldingRange,
  ]
}
