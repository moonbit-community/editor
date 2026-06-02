///|
pub(all) enum DecorationKind {
  Diagnostic
  SearchMatch
  Link
  SemanticToken
  CurrentLine
} derive(Eq, Debug)

///|
pub(all) struct Decoration {
  range : @core.Range
  kind : DecorationKind
  class_name : String
  message : String?
} derive(Debug)

///|
pub(all) struct DecorationSet {
  items : Array[Decoration]
} derive(Debug)

///|
pub fn Decoration::Decoration(
  range : @core.Range,
  kind : DecorationKind,
  class_name : String,
  message? : String,
) -> Decoration {
  { range, kind, class_name, message }
}

///|
pub fn DecorationSet::empty() -> DecorationSet {
  { items: [] }
}

///|
pub fn DecorationSet::from_array(items : Array[Decoration]) -> DecorationSet {
  { items, }
}

///|
pub fn DecorationSet::between(
  self : DecorationSet,
  range : @core.Range,
) -> Array[Decoration] {
  let found = []
  for item in self.items {
    if item.range.intersects(range) {
      found.push(item)
    }
  }
  found
}

///|
pub fn DecorationSet::at_offset(
  self : DecorationSet,
  offset : Int,
) -> Array[Decoration] {
  let found = []
  for item in self.items {
    if item.range.contains_offset(offset) {
      found.push(item)
    }
  }
  found
}
