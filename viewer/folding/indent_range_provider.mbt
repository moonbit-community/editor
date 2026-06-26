// Port of Monaco/VS Code's indentation/marker folding-range computation.
//
// Source: vscode/src/vs/editor/contrib/folding/browser/indentRangeProvider.ts
//   and computeIndentLevel from
//   vscode/src/vs/editor/common/model/utils.ts
// (vscode submodule commit 294fb350837dbaee37b949533fead4df4e0e8971).
//
// Adaptation: VS Code's FoldingMarkers are RegExps; this viewer has no regex
// engine, so markers are modelled as line matcher closures. computeRanges'
// start-then-end precedence reproduces the upstream combined/alternation regex
// behaviour for the patterns these tests use.

///|
/// Start/end fold-marker matchers (e.g. `#region` / `#endregion`).
pub struct FoldingMarkers {
  start : (String) -> Bool
  end : (String) -> Bool
}

///|
pub fn FoldingMarkers::new(
  start : (String) -> Bool,
  end : (String) -> Bool,
) -> FoldingMarkers {
  { start, end }
}

///|
/// Reports/limits how many folding ranges are produced. `update` is called with
/// the computed count and whether the result was limited (`None` = not limited,
/// `Some(limit)` = limited to that many ranges), mirroring the upstream
/// `update(computed, limited)` where `limited` is `number | false`.
pub struct FoldingLimitReporter {
  limit : Int
  update : (Int, Int?) -> Unit
}

///|
pub fn FoldingLimitReporter::new(
  limit : Int,
  update? : (Int, Int?) -> Unit,
) -> FoldingLimitReporter {
  let update = match update {
    Some(u) => u
    None => fn(_computed, _limited) {  }
  }
  { limit, update }
}

///|
let max_folding_regions_for_indent_default : Int = 5000

///|
/// Accumulates folding ranges (inserted in reverse line order) and produces a
/// sorted `FoldingRegions`, honouring the configured limit.
pub struct RangesCollector {
  start_indexes : Array[Int]
  end_indexes : Array[Int]
  indent_occurrences : Array[Int]
  mut length : Int
  folding_ranges_limit : FoldingLimitReporter
}

///|
pub fn RangesCollector::new(
  folding_ranges_limit : FoldingLimitReporter,
) -> RangesCollector {
  {
    start_indexes: [],
    end_indexes: [],
    indent_occurrences: [],
    length: 0,
    folding_ranges_limit,
  }
}

///|
pub fn RangesCollector::insert_first(
  self : RangesCollector,
  start_line_number : Int,
  end_line_number : Int,
  indent : Int,
) -> Unit {
  if start_line_number > max_line_number || end_line_number > max_line_number {
    return
  }
  self.start_indexes.push(start_line_number)
  self.end_indexes.push(end_line_number)
  self.length += 1
  if indent < 1000 {
    while self.indent_occurrences.length() <= indent {
      self.indent_occurrences.push(0)
    }
    self.indent_occurrences[indent] = self.indent_occurrences[indent] + 1
  }
}

///|
pub fn RangesCollector::to_indent_ranges(
  self : RangesCollector,
  snapshot : @model.TextSnapshot,
  tab_size? : Int = 4,
) -> FoldingRegions raise {
  let limit = self.folding_ranges_limit.limit
  if self.length <= limit {
    (self.folding_ranges_limit.update)(self.length, None)
    // reverse and create arrays of the exact length
    let start_indexes = Array::make(self.length, 0)
    let end_indexes = Array::make(self.length, 0)
    let mut k = 0
    for i = self.length - 1; i >= 0; i = i - 1 {
      start_indexes[k] = self.start_indexes[i]
      end_indexes[k] = self.end_indexes[i]
      k += 1
    }
    FoldingRegions::new(start_indexes, end_indexes)
  } else {
    (self.folding_ranges_limit.update)(self.length, Some(limit))
    let mut entries = 0
    let mut max_indent = self.indent_occurrences.length()
    for i in 0..<self.indent_occurrences.length() {
      let n = self.indent_occurrences[i]
      if n != 0 {
        if n + entries > limit {
          max_indent = i
          break
        }
        entries += n
      }
    }
    // reverse and create arrays of the exact length
    let start_indexes = Array::make(limit, 0)
    let end_indexes = Array::make(limit, 0)
    let mut k = 0
    for i = self.length - 1; i >= 0; i = i - 1 {
      let start_index = self.start_indexes[i]
      let line_content = snapshot.line_text(start_index - 1)
      let indent = @model.compute_indent_level(line_content, tab_size)
      // Mirrors `indent < maxIndent || (indent === maxIndent && entries++ < limit)`:
      // when indent === maxIndent, entries is post-incremented regardless.
      let mut take = false
      if indent < max_indent {
        take = true
      } else if indent == max_indent {
        if entries < limit {
          take = true
        }
        entries += 1
      }
      if take {
        start_indexes[k] = start_index
        end_indexes[k] = self.end_indexes[i]
        k += 1
      }
    }
    FoldingRegions::new(start_indexes, end_indexes)
  }
}

///|
priv struct PreviousRegion {
  mut indent : Int // indent or -2 if a marker
  mut end_above : Int // end line number for the region above
  mut line : Int // start line of the region, only used for marker regions
}

///|
/// Computes folding ranges from indentation and optional fold markers.
/// `snapshot` lines are 1-based via `line_text(line - 1)`.
pub fn compute_ranges(
  snapshot : @model.TextSnapshot,
  offside : Bool,
  markers? : FoldingMarkers,
  tab_size? : Int = 4,
  folding_ranges_limit? : FoldingLimitReporter,
) -> FoldingRegions raise {
  let limit = match folding_ranges_limit {
    Some(l) => l
    None => FoldingLimitReporter::new(max_folding_regions_for_indent_default)
  }
  let result = RangesCollector::new(limit)
  let previous_regions : Array[PreviousRegion] = []
  let line_count = snapshot.line_count()
  let sentinel = line_count + 1
  // sentinel, to make sure there's at least one entry
  previous_regions.push({ indent: -1, end_above: sentinel, line: sentinel })
  for line = line_count; line > 0; line = line - 1 {
    let line_content = snapshot.line_text(line - 1)
    let indent = @model.compute_indent_level(line_content, tab_size)
    let mut previous = previous_regions[previous_regions.length() - 1]
    if indent == -1 {
      if offside {
        // for offSide languages, empty lines are associated to the previous
        // block. note: the next block is already written to the results, so
        // this only impacts the end position of the block before
        previous.end_above = line
      }
      continue // only whitespace
    }
    let mut is_start_match = false
    let mut is_end_match = false
    match markers {
      Some(m) =>
        if (m.start)(line_content) {
          is_start_match = true
        } else if (m.end)(line_content) {
          is_end_match = true
        }
      None => ()
    }
    if is_start_match || is_end_match {
      // folding pattern match
      if is_start_match {
        // discard all regions until the folding pattern
        let mut i = previous_regions.length() - 1
        while i > 0 && previous_regions[i].indent != -2 {
          i -= 1
        }
        if i > 0 {
          truncate_regions(previous_regions, i + 1)
          previous = previous_regions[i]

          // new folding range from pattern, includes the end line
          result.insert_first(line, previous.line, indent)
          previous.line = line
          previous.indent = indent
          previous.end_above = line
          continue
        }
        // else: no end marker found, treat line as a regular line
      } else {
        // end pattern match
        previous_regions.push({ indent: -2, end_above: line, line })
        continue
      }
    }
    if previous.indent > indent {
      // discard all regions with larger indent
      while previous.indent > indent {
        previous_regions.pop() |> ignore
        previous = previous_regions[previous_regions.length() - 1]
      }
      // new folding range
      let end_line_number = previous.end_above - 1
      if end_line_number - line >= 1 {
        // needs at least size 1
        result.insert_first(line, end_line_number, indent)
      }
    }
    if previous.indent == indent {
      previous.end_above = line
    } else {
      // new region with a bigger indent
      previous_regions.push({ indent, end_above: line, line })
    }
  }
  result.to_indent_ranges(snapshot, tab_size~)
}

///|
fn truncate_regions(regions : Array[PreviousRegion], new_length : Int) -> Unit {
  while regions.length() > new_length {
    regions.pop() |> ignore
  }
}
