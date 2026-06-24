// Backend-neutral folding model for the readonly viewing path. A port of the
// pure parts of Monaco's `contrib/folding/`: the folded-range set operations
// the folding controller drives, plus the fallback indentation/brace
// folding-range computation used when no provider answers. The browser-side
// folding controls (the gutter toggle and re-render) stay on the viewer.

///|
/// Default folding ranges derived from the model text when no provider supplies
/// them. Today only MoonBit gets an indentation/brace heuristic.
pub fn fallback_folding_ranges(
  model : @model.TextModel,
) -> Array[@language.FoldingRange] {
  if model.language_id == "moonbit" {
    moonbit_indentation_folding_ranges(model.snapshot)
  } else {
    []
  }
}

///|
fn moonbit_indentation_folding_ranges(
  snapshot : @model.TextSnapshot,
) -> Array[@language.FoldingRange] {
  let ranges : Array[@language.FoldingRange] = []
  for line_index in 0..<snapshot.line_count() {
    let line = snapshot.line_text(line_index)
    let trimmed = line.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    let next = next_non_empty_line(snapshot, line_index + 1)
    match next {
      Some(next_line_index) => {
        let indent = line_indent(line)
        let next_indent = line_indent(snapshot.line_text(next_line_index))
        let mut end_line_index = -1
        if next_indent > indent {
          end_line_index = indentation_block_end(snapshot, line_index, indent)
        }
        if trimmed.has_suffix("{") {
          let brace_end = brace_block_end(snapshot, line_index, indent)
          if brace_end > end_line_index {
            end_line_index = brace_end
          }
        }
        if end_line_index > line_index {
          ranges.push(FoldingRange(line_index + 1, end_line_index + 1))
        }
      }
      None => ()
    }
  }
  ranges
}

///|
fn next_non_empty_line(
  snapshot : @model.TextSnapshot,
  start_index : Int,
) -> Int? {
  for index in start_index..<snapshot.line_count() {
    if snapshot.line_text(index).trim(char_set=" \t\r\n") != "" {
      return Some(index)
    }
  }
  None
}

///|
fn indentation_block_end(
  snapshot : @model.TextSnapshot,
  start_index : Int,
  indent : Int,
) -> Int {
  let mut end_line_index = start_index
  for index in (start_index + 1)..<snapshot.line_count() {
    let text = snapshot.line_text(index)
    let trimmed = text.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    if line_indent(text) <= indent {
      return end_line_index
    }
    end_line_index = index
  }
  end_line_index
}

///|
fn brace_block_end(
  snapshot : @model.TextSnapshot,
  start_index : Int,
  indent : Int,
) -> Int {
  for index in (start_index + 1)..<snapshot.line_count() {
    let text = snapshot.line_text(index)
    let trimmed = text.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    if line_indent(text) <= indent && trimmed.has_prefix("}") {
      return index
    }
  }
  -1
}

///|
fn line_indent(line : String) -> Int {
  let mut indent = 0
  for index in 0..<line.length() {
    let code = line[index].to_int()
    if code == 32 {
      indent += 1
    } else if code == 9 {
      indent += 2
    } else {
      return indent
    }
  }
  indent
}

///|
/// Keeps only the folded ranges that are still foldable after a ranges update.
pub fn preserved_folded_ranges(
  folded : Array[@language.FoldingRange],
  foldable : Array[@language.FoldingRange],
) -> Array[@language.FoldingRange] {
  let preserved : Array[@language.FoldingRange] = []
  for range in folded {
    if contains_folding_range(foldable, range) {
      preserved.push(range)
    }
  }
  preserved
}

///|
/// Toggles one foldable range in the folded set, returning the next set and
/// whether it changed.
pub fn toggled_folded_ranges(
  folded : Array[@language.FoldingRange],
  range : @language.FoldingRange,
) -> (Array[@language.FoldingRange], Bool) {
  let next : Array[@language.FoldingRange] = []
  let mut removed = false
  for folded_range in folded {
    if !removed && same_folding_range(folded_range, range) {
      removed = true
    } else {
      next.push(folded_range)
    }
  }
  if removed {
    (next, true)
  } else {
    next.push(range)
    (next, true)
  }
}

///|
/// The widest foldable range that starts on a model line, if any.
pub fn folding_range_for_start_line(
  ranges : Array[@language.FoldingRange],
  model_line_number : Int,
) -> @language.FoldingRange? {
  let mut found : @language.FoldingRange? = None
  for range in ranges {
    if range.start_line_number == model_line_number {
      match found {
        Some(previous) =>
          if range.end_line_number > previous.end_line_number {
            found = Some(range)
          }
        None => found = Some(range)
      }
    }
  }
  found
}

///|
/// Whether a model line is the start of a currently folded range.
pub fn is_line_folded(
  folded : Array[@language.FoldingRange],
  model_line_number : Int,
) -> Bool {
  match folding_range_for_start_line(folded, model_line_number) {
    Some(_) => true
    None => false
  }
}

///|
fn contains_folding_range(
  ranges : Array[@language.FoldingRange],
  range : @language.FoldingRange,
) -> Bool {
  for item in ranges {
    if same_folding_range(item, range) {
      return true
    }
  }
  false
}

///|
fn same_folding_range(
  left : @language.FoldingRange,
  right : @language.FoldingRange,
) -> Bool {
  left.start_line_number == right.start_line_number &&
  left.end_line_number == right.end_line_number
}
