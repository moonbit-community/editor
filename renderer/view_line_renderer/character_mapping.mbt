///|
/// DOM span/character coordinate for a rendered line.
pub(all) struct DomPosition {
  part_index : Int
  char_index : Int
} derive(Eq, Debug)

///|
/// Mapping entry from one line column to rendered DOM coordinates and visible
/// monospace column.
pub(all) struct CharacterMappingEntry {
  part_index : Int
  char_index : Int
  visible_column : Int
} derive(Eq, Debug)

///|
/// Column-to-DOM mapping produced while rendering a line.
pub(all) struct CharacterMapping {
  length : Int
  entries : Array[CharacterMappingEntry]
} derive(Eq, Debug)

///|
/// Creates a mapping with `length` column slots.
pub fn CharacterMapping::new(length : Int) -> CharacterMapping {
  let entries : Array[CharacterMappingEntry] = []
  for _ in 0..<length {
    entries.push({ part_index: 0, char_index: 0, visible_column: 0 })
  }
  { length, entries }
}

///|
/// Stores DOM and visible-column info for a one-based line column.
pub fn CharacterMapping::set_column_info(
  self : CharacterMapping,
  column : Int,
  part_index : Int,
  char_index : Int,
  visible_column : Int,
) -> Unit {
  let index = column - 1
  if index >= 0 && index < self.entries.length() {
    self.entries[index] = { part_index, char_index, visible_column }
  }
}

///|
/// Returns the DOM position nearest a one-based line column.
pub fn CharacterMapping::get_dom_position(
  self : CharacterMapping,
  column : Int,
) -> DomPosition {
  if self.length == 0 {
    return { part_index: 0, char_index: 0 }
  }
  let index = @core.clamp_int(column - 1, 0, self.length - 1)
  let entry = self.entries[index]
  { part_index: entry.part_index, char_index: entry.char_index }
}

///|
/// Returns the one-based line column nearest a DOM position.
pub fn CharacterMapping::get_column(
  self : CharacterMapping,
  dom_position : DomPosition,
  part_length : Int,
) -> Int {
  if self.length == 0 {
    return 1
  }
  let search = mapping_rank(dom_position.part_index, dom_position.char_index)
  let mut best = 0
  let mut best_distance = abs_int(mapping_rank_entry(self.entries[0]) - search)
  for index in 1..<self.entries.length() {
    let entry = self.entries[index]
    let rank = mapping_rank_entry(entry)
    if rank == search {
      return index + 1
    }
    let distance = if entry.part_index == dom_position.part_index {
      abs_int(entry.char_index - dom_position.char_index)
    } else if entry.part_index < dom_position.part_index {
      abs_int(part_length - entry.char_index + dom_position.char_index)
    } else {
      abs_int(part_length - dom_position.char_index + entry.char_index)
    }
    if distance < best_distance {
      best = index
      best_distance = distance
    }
  }
  best + 1
}

///|
/// Visible monospace column for a one-based line column.
pub fn CharacterMapping::get_horizontal_offset(
  self : CharacterMapping,
  column : Int,
) -> Int {
  if self.length == 0 {
    return 0
  }
  let index = @core.clamp_int(column - 1, 0, self.length - 1)
  self.entries[index].visible_column
}

///|
/// Horizontal CSS-pixel offset for a one-based line column.
pub fn CharacterMapping::column_horizontal_offset(
  self : CharacterMapping,
  column : Int,
  space_width~ : Double,
) -> Double {
  self.get_horizontal_offset(column).to_double() * space_width
}

///|
/// Copies the raw mapping entries for diagnostics and tests.
pub fn CharacterMapping::inflate(
  self : CharacterMapping,
) -> Array[CharacterMappingEntry] {
  self.entries.copy()
}

///|
fn mapping_rank(part_index : Int, char_index : Int) -> Int {
  part_index * 65536 + char_index
}

///|
fn mapping_rank_entry(entry : CharacterMappingEntry) -> Int {
  mapping_rank(entry.part_index, entry.char_index)
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
/// Render output when the caller owns the output builder.
pub(all) struct RenderLineOutput {
  character_mapping : CharacterMapping
  contains_foreign_elements : ForeignElementType
} derive(Eq, Debug)

///|
/// Render output including generated HTML.
pub(all) struct RenderLineOutput2 {
  html : String
  character_mapping : CharacterMapping
  contains_foreign_elements : ForeignElementType
} derive(Eq, Debug)
