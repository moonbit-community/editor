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
/// Numeric value of the stickiness, matching Monaco's
/// `TrackedRangeStickiness` enum values (`model.ts`) — the interval tree
/// packs it into the node metadata byte.
pub fn TrackedRangeStickiness::to_int(self : TrackedRangeStickiness) -> Int {
  match self {
    AlwaysGrowsWhenTypingAtEdges => 0
    NeverGrowsWhenTypingAtEdges => 1
    GrowsOnlyWhenTypingBefore => 2
    GrowsOnlyWhenTypingAfter => 3
  }
}

///|
/// Inverse of `to_int`. Values outside 0..=3 cannot come out of the 2-bit
/// metadata field; the fallback mirrors Monaco's numeric default 0.
pub fn TrackedRangeStickiness::from_int(value : Int) -> TrackedRangeStickiness {
  match value {
    1 => NeverGrowsWhenTypingAtEdges
    2 => GrowsOnlyWhenTypingBefore
    3 => GrowsOnlyWhenTypingAfter
    _ => AlwaysGrowsWhenTypingAtEdges
  }
}

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
/// `cleanClassName` (`textModel.ts:2355-2357`): `[^a-z0-9\-_]/gi → ' '`,
/// applied per UTF-16 code unit like the JS regex (no /u flag).
pub fn clean_class_name(class_name : String) -> String {
  let sb = StringBuilder()
  for i in 0..<class_name.length() {
    let c = class_name[i].to_int()
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '-' ||
      c == '_' {
      sb.write_char(c.unsafe_to_char())
    } else {
      sb.write_char(' ')
    }
  }
  sb.to_string()
}

///|
/// The `ModelDecorationOptions` subset (`textModel.ts:2478-2580`) plus — for
/// the duration of the decoration-system migration — the legacy simplified
/// fields `range` and `kind` still consumed by the old render path (they are
/// deleted in the plan's Phases 3-4). Monaco field mapping: `class_name` =
/// `className` ("" = undefined), `message` = `hoverMessage`,
/// `inline_class_name` = `inlineClassName`, the rest keep their names.
///
/// Omitted `ModelDecorationOptions` fields (out of scope, plan
/// `monaco-decoration-system-port.md`): `blockClassName`/`blockIsAfterEnd`/
/// `blockDoesNotCollapse`/`blockPadding` (block decorations),
/// `before`/`after` (injected text via decoration storage),
/// `lineNumberClassName`/`lineNumberHoverMessage`/`linesDecorationsTooltip`/
/// `glyphMarginHoverMessage` (no consumer), `hideInCommentTokens`/
/// `hideInStringTokens`, `lineHeight`/`fontSize`/`affectsFont` (font/line-
/// height decorations), `textDirection`, `glyphMargin` lane options (glyph
/// margin view part deferred). `overview_ruler`/`minimap` colors are carried
/// as strings — no theme-object resolution (recorded theming design).
pub(all) struct Decoration {
  range : @base_common.Range
  kind : DecorationKind
  class_name : String
  message : String?
  inline_class_name : String?
  inline_class_name_affects_letter_spacing : Bool
  z_index : Int
  is_whole_line : Bool
  show_if_collapsed : Bool
  should_fill_line_on_line_break : Bool
  stickiness : TrackedRangeStickiness
  overview_ruler : OverviewRulerOptions?
  minimap : MinimapOptions?
  glyph_margin_class_name : String?
  lines_decorations_class_name : String?
  first_line_decoration_class_name : String?
  margin_class_name : String?
  collapse_on_replace_edit : Bool
  description : String
} derive(Debug)

///|
/// A (range, options) pair handed to `TextModel::delta_decorations` —
/// Monaco's `IModelDeltaDecoration`. The `options.range`/`options.kind`
/// legacy fields are ignored by decoration storage.
pub(all) struct DeltaDecoration {
  range : @base_common.Range
  options : Decoration
} derive(Debug)

///|
/// A decoration query result — Monaco's `IModelDecoration` (id + ownerId +
/// range + options). Monaco returns the tree's `IntervalNode`s cast to this
/// interface; the port materializes value copies (same data, no aliasing).
pub(all) struct ModelDecoration {
  id : String
  owner_id : Int
  range : @base_common.Range
  options : Decoration
} derive(Debug)

///|
/// `IModelDecorationsChangedEvent` (`textModelEvents.ts`), fired by
/// `TextModel::on_did_change_decorations`.
pub(all) struct ModelDecorationsChangedEvent {
  affects_minimap : Bool
  affects_overview_ruler : Bool
  affects_glyph_margin : Bool
  affects_line_number : Bool
} derive(Eq, Debug)

///|
/// Immutable-style decoration collection queried by viewport and hover code.
pub(all) struct DecorationSet {
  items : Array[Decoration]
} derive(Debug)

///|
/// The single decoration-options constructor. Monaco's `register`/
/// `createDynamic`/`_normalizeOptions` collapse into this one function (plan
/// Deviation 5 — `register` exists only to intern per-instance allocations).
/// Class names are normalized with `clean_class_name` like the
/// `ModelDecorationOptions` ctor; defaults mirror the source (`stickiness`
/// AlwaysGrows, `zIndex` 0). Direct record literals bypass the cleaning, like
/// nothing does in Monaco.
pub fn Decoration::Decoration(
  range : @base_common.Range,
  kind : DecorationKind,
  class_name : String,
  message? : String,
  inline_class_name? : String,
  inline_class_name_affects_letter_spacing? : Bool = false,
  z_index? : Int = 0,
  is_whole_line? : Bool = false,
  show_if_collapsed? : Bool = false,
  should_fill_line_on_line_break? : Bool = false,
  stickiness? : TrackedRangeStickiness = AlwaysGrowsWhenTypingAtEdges,
  overview_ruler? : OverviewRulerOptions,
  minimap? : MinimapOptions,
  glyph_margin_class_name? : String,
  lines_decorations_class_name? : String,
  first_line_decoration_class_name? : String,
  margin_class_name? : String,
  collapse_on_replace_edit? : Bool = false,
  description? : String = "",
) -> Decoration {
  {
    range,
    kind,
    class_name: clean_class_name(class_name),
    message,
    inline_class_name: inline_class_name.map(clean_class_name),
    inline_class_name_affects_letter_spacing,
    z_index,
    is_whole_line,
    show_if_collapsed,
    should_fill_line_on_line_break,
    stickiness,
    overview_ruler,
    minimap,
    glyph_margin_class_name: glyph_margin_class_name.map(clean_class_name),
    lines_decorations_class_name: lines_decorations_class_name.map(
      clean_class_name,
    ),
    first_line_decoration_class_name: first_line_decoration_class_name.map(
      clean_class_name,
    ),
    margin_class_name: margin_class_name.map(clean_class_name),
    collapse_on_replace_edit,
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
