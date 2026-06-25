///|
/// Semantic reason for a renderer decoration. Browser code maps these kinds to
/// stable CSS classes and feature ownership.
pub(all) enum DecorationKind {
  Diagnostic
  SearchMatch
  Link
  SemanticToken
  CurrentLine
  HoverHighlight
} derive(Eq, Debug)

///|
/// One half-open range decoration with the CSS class and optional message the
/// renderer should attach to matching line spans.
pub(all) struct Decoration {
  range : @base_common.OffsetRange
  kind : DecorationKind
  class_name : String
  message : String?
} derive(Debug)

///|
/// Immutable-style decoration collection queried by viewport and hover code.
pub(all) struct DecorationSet {
  items : Array[Decoration]
} derive(Debug)

///|
/// Builds a decoration from an explicit range, kind, CSS class, and optional
/// message.
pub fn Decoration::Decoration(
  range : @base_common.OffsetRange,
  kind : DecorationKind,
  class_name : String,
  message? : String,
) -> Decoration {
  { range, kind, class_name, message }
}

///|
/// Empty decoration collection.
pub fn DecorationSet::empty() -> DecorationSet {
  { items: [] }
}

///|
/// Wraps an array of decorations as a queryable set.
pub fn DecorationSet::from_array(items : Array[Decoration]) -> DecorationSet {
  { items, }
}

///|
/// Decorations whose ranges intersect `range`.
pub fn DecorationSet::between(
  self : DecorationSet,
  range : @base_common.OffsetRange,
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
/// Decorations whose ranges contain `offset`.
pub fn DecorationSet::at_offset(
  self : DecorationSet,
  offset : Int,
) -> Array[Decoration] {
  let found = []
  for item in self.items {
    if item.range.contains(offset) {
      found.push(item)
    }
  }
  found
}
