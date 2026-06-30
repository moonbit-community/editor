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
/// How a decoration's range grows when text is typed at its edges,
/// `TrackedRangeStickiness` (`model.ts`). Inert in the readonly viewer; carried
/// for fidelity.
pub(all) enum TrackedRangeStickiness {
  AlwaysGrowsWhenTypingAtEdges
  NeverGrowsWhenTypingAtEdges
  GrowsOnlyWhenTypingBefore
  GrowsOnlyWhenTypingAfter
} derive(Eq, Debug)

///|
/// Overview-ruler lane, `OverviewRulerLane` (`model.ts`).
pub(all) enum OverviewRulerLane {
  Left
  Center
  Right
  Full
} derive(Eq, Debug)

///|
/// Minimap decoration position, `MinimapPosition` (`model.ts`).
pub(all) enum MinimapPosition {
  Inline
  Gutter
} derive(Eq, Debug)

///|
/// Overview-ruler decoration options, `IModelDecorationOverviewRulerOptions`.
/// `color` is a theme-color id (`themeColorFromId`), carried inert (no overview
/// ruler part paints it — plan D4).
pub(all) struct OverviewRulerOptions {
  color : String?
  position : OverviewRulerLane
} derive(Eq, Debug)

///|
/// Minimap decoration options, `IModelDecorationMinimapOptions`. `color` is a
/// theme-color id, carried inert (plan D4).
pub(all) struct MinimapOptions {
  color : String
  position : MinimapPosition
} derive(Eq, Debug)

///|
/// One line/column `Range` decoration with the CSS class and optional message
/// the renderer should attach to matching line spans. Mirrors Monaco's
/// `IModelDeltaDecoration` (range) plus the `IModelDecorationOptions` fields the
/// marker transform sets. An empty `class_name` means Monaco's
/// `className: undefined` (e.g. Hint+Deprecated). The `overview_ruler`/`minimap`
/// carriers are inert (plan D4).
pub(all) struct Decoration {
  range : @base_common.Range
  kind : DecorationKind
  class_name : String
  message : String?
  inline_class_name : String?
  z_index : Int
  show_if_collapsed : Bool
  stickiness : TrackedRangeStickiness
  overview_ruler : OverviewRulerOptions?
  minimap : MinimapOptions?
  description : String
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
  range : @base_common.Range,
  kind : DecorationKind,
  class_name : String,
  message? : String,
  inline_class_name? : String,
  z_index? : Int = 0,
  show_if_collapsed? : Bool = false,
  stickiness? : TrackedRangeStickiness = AlwaysGrowsWhenTypingAtEdges,
  overview_ruler? : OverviewRulerOptions,
  minimap? : MinimapOptions,
  description? : String = "",
) -> Decoration {
  {
    range,
    kind,
    class_name,
    message,
    inline_class_name,
    z_index,
    show_if_collapsed,
    stickiness,
    overview_ruler,
    minimap,
    description,
  }
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
/// Decorations whose ranges intersect or touch `range`.
pub fn DecorationSet::between(
  self : DecorationSet,
  range : @base_common.Range,
) -> Array[Decoration] {
  let found = []
  for item in self.items {
    if @base_common.Range::are_intersecting_or_touching(item.range, range) {
      found.push(item)
    }
  }
  found
}

///|
/// Decorations whose ranges contain `position`.
pub fn DecorationSet::at_position(
  self : DecorationSet,
  position : @base_common.Position,
) -> Array[Decoration] {
  let found = []
  for item in self.items {
    if item.range.contains_position(position) {
      found.push(item)
    }
  }
  found
}
