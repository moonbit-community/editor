// Port of Monaco/VS Code's folding-range storage and merge logic.
//
// Source: vscode/src/vs/editor/contrib/folding/browser/foldingRanges.ts
// (vscode submodule commit 294fb350837dbaee37b949533fead4df4e0e8971).
//
// Adaptation: upstream packs parent indexes into the high bytes of the
// start/end Uint32Arrays and uses a bitfield for the collapse/source state.
// This port keeps the line numbers unpacked, stores parent indexes and state
// in plain arrays, and is otherwise behaviourally identical for the index
// ranges these tests exercise (< MAX_FOLDING_REGIONS regions).

///|
pub let max_folding_regions : Int = 0xFFFF

///|
pub let max_line_number : Int = 0xFFFFFF

///|
/// Where a fold range came from, mirroring upstream `FoldSource`.
pub(all) enum FoldSource {
  Provider
  UserDefined
  Recovered
} derive(Eq, Debug)

///|
pub fn FoldSource::abbr(self : FoldSource) -> String {
  match self {
    Provider => " "
    UserDefined => "u"
    Recovered => "r"
  }
}

///|
/// A plain fold-range record (the merge/round-trip representation).
pub(all) struct FoldRange {
  start_line_number : Int
  end_line_number : Int
  type_ : String?
  mut is_collapsed : Bool
  mut source : FoldSource
}

///|
pub fn FoldRange::new(
  start_line_number : Int,
  end_line_number : Int,
  is_collapsed? : Bool = false,
  source? : FoldSource = Provider,
  type_? : String,
) -> FoldRange {
  { start_line_number, end_line_number, type_, is_collapsed, source }
}

///|
/// Stores folding regions, sorted by start line, with lazy parent computation.
pub struct FoldingRegions {
  start_indexes : Array[Int]
  end_indexes : Array[Int]
  collapse_states : Array[Bool]
  user_defined_states : Array[Bool]
  recovered_states : Array[Bool]
  parent_indexes : Array[Int]
  mut parents_computed : Bool
  types : Array[String?]?
}

///|
pub fn FoldingRegions::new(
  start_indexes : Array[Int],
  end_indexes : Array[Int],
  types? : Array[String?],
) -> FoldingRegions raise {
  if start_indexes.length() != end_indexes.length() ||
    start_indexes.length() > max_folding_regions {
    fail("invalid startIndexes or endIndexes size")
  }
  let len = start_indexes.length()
  {
    start_indexes,
    end_indexes,
    collapse_states: Array::make(len, false),
    user_defined_states: Array::make(len, false),
    recovered_states: Array::make(len, false),
    parent_indexes: Array::make(len, -1),
    parents_computed: false,
    types,
  }
}

///|
fn FoldingRegions::ensure_parent_indices(self : FoldingRegions) -> Unit raise {
  if self.parents_computed {
    return
  }
  self.parents_computed = true
  let parent_stack : Array[Int] = []
  fn is_inside_last(start_line_number : Int, end_line_number : Int) -> Bool {
    let index = parent_stack[parent_stack.length() - 1]
    self.get_start_line_number(index) <= start_line_number &&
    self.get_end_line_number(index) >= end_line_number
  }
  for i in 0..<self.start_indexes.length() {
    let start_line_number = self.start_indexes[i]
    let end_line_number = self.end_indexes[i]
    if start_line_number > max_line_number || end_line_number > max_line_number {
      fail(
        "startLineNumber or endLineNumber must not exceed " +
        max_line_number.to_string(),
      )
    }
    while parent_stack.length() > 0 &&
          !is_inside_last(start_line_number, end_line_number) {
      parent_stack.pop() |> ignore
    }
    let parent_index = if parent_stack.length() > 0 {
      parent_stack[parent_stack.length() - 1]
    } else {
      -1
    }
    parent_stack.push(i)
    self.parent_indexes[i] = parent_index
  }
}

///|
pub fn FoldingRegions::length(self : FoldingRegions) -> Int {
  self.start_indexes.length()
}

///|
pub fn FoldingRegions::get_start_line_number(
  self : FoldingRegions,
  index : Int,
) -> Int {
  self.start_indexes[index]
}

///|
pub fn FoldingRegions::get_end_line_number(
  self : FoldingRegions,
  index : Int,
) -> Int {
  self.end_indexes[index]
}

///|
pub fn FoldingRegions::get_type(self : FoldingRegions, index : Int) -> String? {
  match self.types {
    Some(types) => types[index]
    None => None
  }
}

///|
pub fn FoldingRegions::has_types(self : FoldingRegions) -> Bool {
  !(self.types is None)
}

///|
pub fn FoldingRegions::is_collapsed(self : FoldingRegions, index : Int) -> Bool {
  self.collapse_states[index]
}

///|
pub fn FoldingRegions::set_collapsed(
  self : FoldingRegions,
  index : Int,
  new_state : Bool,
) -> Unit {
  self.collapse_states[index] = new_state
}

///|
pub fn FoldingRegions::get_source(
  self : FoldingRegions,
  index : Int,
) -> FoldSource {
  if self.user_defined_states[index] {
    UserDefined
  } else if self.recovered_states[index] {
    Recovered
  } else {
    Provider
  }
}

///|
pub fn FoldingRegions::set_source(
  self : FoldingRegions,
  index : Int,
  source : FoldSource,
) -> Unit {
  match source {
    UserDefined => {
      self.user_defined_states[index] = true
      self.recovered_states[index] = false
    }
    Recovered => {
      self.user_defined_states[index] = false
      self.recovered_states[index] = true
    }
    Provider => {
      self.user_defined_states[index] = false
      self.recovered_states[index] = false
    }
  }
}

///|
pub fn FoldingRegions::set_collapsed_all_of_type(
  self : FoldingRegions,
  type_ : String,
  new_state : Bool,
) -> Bool {
  let mut has_changed = false
  match self.types {
    Some(types) =>
      for i in 0..<types.length() {
        if types[i] is Some(t) && t == type_ {
          self.set_collapsed(i, new_state)
          has_changed = true
        }
      }
    None => ()
  }
  has_changed
}

///|
pub fn FoldingRegions::get_parent_index(
  self : FoldingRegions,
  index : Int,
) -> Int raise {
  self.ensure_parent_indices()
  self.parent_indexes[index]
}

///|
pub fn FoldingRegions::contains(
  self : FoldingRegions,
  index : Int,
  line : Int,
) -> Bool {
  self.get_start_line_number(index) <= line &&
  self.get_end_line_number(index) >= line
}

///|
fn FoldingRegions::find_index(self : FoldingRegions, line : Int) -> Int {
  let mut low = 0
  let mut high = self.start_indexes.length()
  if high == 0 {
    return -1
  }
  while low < high {
    let mid = (low + high) / 2
    if line < self.get_start_line_number(mid) {
      high = mid
    } else {
      low = mid + 1
    }
  }
  low - 1
}

///|
pub fn FoldingRegions::find_range(
  self : FoldingRegions,
  line : Int,
) -> Int raise {
  let mut index = self.find_index(line)
  if index >= 0 {
    let end_line_number = self.get_end_line_number(index)
    if end_line_number >= line {
      return index
    }
    index = self.get_parent_index(index)
    while index != -1 {
      if self.contains(index, line) {
        return index
      }
      index = self.get_parent_index(index)
    }
  }
  -1
}

///|
pub fn FoldingRegions::to_fold_range(
  self : FoldingRegions,
  index : Int,
) -> FoldRange {
  {
    start_line_number: self.start_indexes[index],
    end_line_number: self.end_indexes[index],
    type_: match self.types {
      Some(types) => types[index]
      None => None
    },
    is_collapsed: self.is_collapsed(index),
    source: self.get_source(index),
  }
}

///|
pub fn FoldingRegions::to_fold_ranges(
  self : FoldingRegions,
) -> Array[FoldRange] {
  let result : Array[FoldRange] = []
  for i in 0..<self.length() {
    result.push(self.to_fold_range(i))
  }
  result
}

///|
pub fn FoldingRegions::from_fold_ranges(
  ranges : Array[FoldRange],
) -> FoldingRegions raise {
  let ranges_length = ranges.length()
  let start_indexes = Array::make(ranges_length, 0)
  let end_indexes = Array::make(ranges_length, 0)
  let types : Array[String?] = []
  let mut got_types = false
  for i in 0..<ranges_length {
    let range = ranges[i]
    start_indexes[i] = range.start_line_number
    end_indexes[i] = range.end_line_number
    types.push(range.type_)
    if range.type_ is Some(_) {
      got_types = true
    }
  }
  let regions = if got_types {
    FoldingRegions::new(start_indexes, end_indexes, types~)
  } else {
    FoldingRegions::new(start_indexes, end_indexes)
  }
  for i in 0..<ranges_length {
    if ranges[i].is_collapsed {
      regions.set_collapsed(i, true)
    }
    regions.set_source(i, ranges[i].source)
  }
  regions
}

///|
/// Merge two pre-sorted fold-range lists. The first list holds all
/// provider-defined regions; the second holds previously collapsed and manual
/// ranges. Mirrors `FoldingRegions.sanitizeAndMerge` (FoldRange[] inputs).
pub fn FoldingRegions::sanitize_and_merge(
  ranges_a : Array[FoldRange],
  ranges_b : Array[FoldRange],
  max_line_number? : Int,
) -> Array[FoldRange] {
  let max_line = match max_line_number {
    Some(v) => v
    None => 0x7FFFFFFF
  }
  fn get_a(i : Int) -> FoldRange? {
    if i < ranges_a.length() {
      Some(ranges_a[i])
    } else {
      None
    }
  }

  fn get_b(i : Int) -> FoldRange? {
    if i < ranges_b.length() {
      Some(ranges_b[i])
    } else {
      None
    }
  }
  let mut index_a = 0
  let mut index_b = 0
  let mut next_a = get_a(0)
  let mut next_b = get_b(0)
  let stacked_ranges : Array[FoldRange] = []
  let mut top_stacked_range : FoldRange? = None
  let mut prev_line_number = 0
  let result_ranges : Array[FoldRange] = []
  while next_a is Some(_) || next_b is Some(_) {
    let mut use_range : FoldRange? = None
    if next_b is Some(nb) &&
      (
        next_a is None ||
        (next_a is Some(na) && na.start_line_number >= nb.start_line_number)
      ) {
      if next_a is Some(na) && na.start_line_number == nb.start_line_number {
        if nb.source is UserDefined {
          use_range = Some(nb)
        } else {
          na.is_collapsed = nb.is_collapsed &&
            na.end_line_number == nb.end_line_number
          na.source = Provider
          use_range = Some(na)
        }
        index_a += 1
        next_a = get_a(index_a)
      } else {
        if nb.is_collapsed && nb.source is Provider {
          nb.source = Recovered
        }
        use_range = Some(nb)
      }
      index_b += 1
      next_b = get_b(index_b)
    } else {
      // nextA is next. The user folded B set takes precedence and we sometimes
      // need to look ahead in it to check for an upcoming conflict.
      let na = next_a.unwrap()
      let mut scan_index = index_b
      let mut prescan_b = next_b
      let mut skip = false
      while true {
        match prescan_b {
          None => {
            use_range = Some(na)
            break
          }
          Some(pb) => {
            if pb.start_line_number > na.end_line_number {
              use_range = Some(na)
              break
            }
            if pb.source is UserDefined &&
              pb.end_line_number > na.end_line_number {
              // a user folded range wins; skip this nextA
              skip = true
              break
            }
            scan_index += 1
            prescan_b = get_b(scan_index)
          }
        }
      }
      ignore(skip)
      index_a += 1
      next_a = get_a(index_a)
    }
    match use_range {
      Some(ur) => {
        let mut keep_popping = true
        while keep_popping {
          match top_stacked_range {
            Some(ts) =>
              if ts.end_line_number < ur.start_line_number {
                top_stacked_range = stacked_ranges.pop()
              } else {
                keep_popping = false
              }
            None => keep_popping = false
          }
        }
        let top_ok = match top_stacked_range {
          None => true
          Some(ts) => ts.end_line_number >= ur.end_line_number
        }
        if ur.end_line_number > ur.start_line_number &&
          ur.start_line_number > prev_line_number &&
          ur.end_line_number <= max_line &&
          top_ok {
          result_ranges.push(ur)
          prev_line_number = ur.start_line_number
          match top_stacked_range {
            Some(ts) => stacked_ranges.push(ts)
            None => ()
          }
          top_stacked_range = Some(ur)
        }
      }
      None => ()
    }
  }
  result_ranges
}
