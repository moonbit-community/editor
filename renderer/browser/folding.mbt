///|
fn Viewer::set_folding_ranges(
  self : Viewer,
  ranges : Array[@language.FoldingRange],
) -> Unit {
  self.folding_ranges = ranges
  self.folded_ranges = preserved_folded_ranges(self.folded_ranges, ranges)
  self.render_feature_update()
}

///|
fn Viewer::toggle_fold(self : Viewer, model_line_number : Int) -> Unit {
  match folding_range_for_start_line(self.folding_ranges, model_line_number) {
    Some(range) => {
      let (folded_ranges, changed) = toggled_folded_ranges(
        self.folded_ranges,
        range,
      )
      if changed {
        self.folded_ranges = folded_ranges
        self.hover = self.hover.cleared()
        self.render_feature_update()
      }
    }
    None => ()
  }
}

///|
fn preserved_folded_ranges(
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
fn toggled_folded_ranges(
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
fn folding_range_for_start_line(
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
fn is_line_folded(
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
