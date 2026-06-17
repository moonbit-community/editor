///|
/// One-based hidden line interval derived from a folded range. The folded start
/// line remains visible, so hidden ranges begin after it.
pub(all) struct HiddenRange {
  start_line_number : Int
  end_line_number : Int
} derive(Eq, Debug)

///|
/// Builds a hidden line interval.
pub fn HiddenRange::HiddenRange(
  start_line_number : Int,
  end_line_number : Int,
) -> HiddenRange {
  { start_line_number, end_line_number }
}

///|
/// Normalized folding state used to filter visible model lines.
pub struct FoldingModel {
  folding_ranges : Array[@language.FoldingRange]
  hidden_ranges : Array[HiddenRange]
} derive(Debug)

///|
/// Builds folding state from folded ranges and the source line count.
pub fn FoldingModel::from_folded_ranges(
  ranges : Array[@language.FoldingRange],
  line_count : Int,
) -> FoldingModel {
  let normalized = normalize_folding_ranges(ranges, line_count)
  {
    folding_ranges: normalized,
    hidden_ranges: hidden_ranges_from_folding_ranges(normalized),
  }
}

///|
/// Normalized folded ranges.
pub fn FoldingModel::folding_ranges(
  self : FoldingModel,
) -> Array[@language.FoldingRange] {
  self.folding_ranges
}

///|
/// Merged one-based hidden line intervals.
pub fn FoldingModel::hidden_ranges(self : FoldingModel) -> Array[HiddenRange] {
  self.hidden_ranges
}

///|
/// Whether a one-based model line is hidden.
pub fn FoldingModel::is_line_hidden(
  self : FoldingModel,
  line_number : Int,
) -> Bool {
  for hidden in self.hidden_ranges {
    if line_number >= hidden.start_line_number &&
      line_number <= hidden.end_line_number {
      return true
    }
  }
  false
}

///|
/// Visible line count after hiding folded ranges.
pub fn FoldingModel::visible_line_count(
  self : FoldingModel,
  line_count : Int,
) -> Int {
  let mut hidden_count = 0
  for hidden in self.hidden_ranges {
    hidden_count += hidden.end_line_number - hidden.start_line_number + 1
  }
  max_int(0, line_count - hidden_count)
}

///|
fn normalize_folding_ranges(
  ranges : Array[@language.FoldingRange],
  line_count : Int,
) -> Array[@language.FoldingRange] {
  let normalized : Array[@language.FoldingRange] = []
  for range in ranges {
    let start_line_number = @core.clamp_int(
      range.start_line_number,
      1,
      max_int(line_count, 1),
    )
    let end_line_number = @core.clamp_int(
      range.end_line_number,
      1,
      max_int(line_count, 1),
    )
    if start_line_number < end_line_number {
      normalized.push({ start_line_number, end_line_number, kind: range.kind })
    }
  }
  normalized.sort_by((left, right) => {
    if left.start_line_number != right.start_line_number {
      left.start_line_number - right.start_line_number
    } else {
      right.end_line_number - left.end_line_number
    }
  })
  normalized
}

///|
fn hidden_ranges_from_folding_ranges(
  ranges : Array[@language.FoldingRange],
) -> Array[HiddenRange] {
  let hidden : Array[HiddenRange] = []
  for range in ranges {
    hidden.push(HiddenRange(range.start_line_number + 1, range.end_line_number))
  }
  merge_hidden_ranges(hidden)
}

///|
fn merge_hidden_ranges(ranges : Array[HiddenRange]) -> Array[HiddenRange] {
  ranges.sort_by((left, right) => {
    if left.start_line_number != right.start_line_number {
      left.start_line_number - right.start_line_number
    } else {
      left.end_line_number - right.end_line_number
    }
  })
  let merged : Array[HiddenRange] = []
  for range in ranges {
    match merged.pop() {
      Some(previous) =>
        if range.start_line_number <= previous.end_line_number + 1 {
          merged.push(
            HiddenRange(
              previous.start_line_number,
              max_int(previous.end_line_number, range.end_line_number),
            ),
          )
        } else {
          merged.push(previous)
          merged.push(range)
        }
      None => merged.push(range)
    }
  }
  merged
}
