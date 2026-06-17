///|
/// Optional semantic category for a foldable range.
pub(all) enum FoldingRangeKind {
  Comment
  Imports
  Region
} derive(Eq, Debug)

///|
/// One foldable line range using one-based line numbers to match LSP and
/// Monaco-facing feature data.
pub(all) struct FoldingRange {
  start_line_number : Int
  end_line_number : Int
  kind : FoldingRangeKind?
} derive(Eq, Debug)

///|
/// Builds a foldable range without normalizing line order; providers are
/// expected to return valid ranges.
pub fn FoldingRange::FoldingRange(
  start_line_number : Int,
  end_line_number : Int,
  kind? : FoldingRangeKind,
) -> FoldingRange {
  { start_line_number, end_line_number, kind }
}

///|
/// Document-level folding range provider.
pub(open) trait FoldingRangeProvider {
  async fn folding_ranges(Self, @model.TextModel) -> Array[FoldingRange]
}
