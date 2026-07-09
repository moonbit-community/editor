// The hover-anchor types of Monaco's `hoverTypes.ts` (:42-82) and the
// wrapper's anchor-candidate pass (`contentHoverWidgetWrapper.ts:263-296`).
// The anchor is the *mouse position* as a collapsed model range (Monaco's
// `target.range`), not the hovered token's span — participants decide what
// spans the position covers.

///|
/// `HoverAnchorType` (`hoverTypes.ts:42-45`).
pub(all) enum HoverAnchorType {
  Range
  ForeignElement
} derive(Eq, Debug)

///|
/// Monaco `HoverRangeAnchor` / `HoverForeignElementAnchor`
/// (`hoverTypes.ts:47-82`). `range` is model-space. The foreign variant's
/// `owner` (the suggesting participant, compared by identity in the source)
/// has exactly one producer here — `InlayHintsHover` — so the owner is
/// implicit; `injected_text_index` is the anchor's payload, the viewer's
/// stand-in for `InlayHintsHoverAnchor.part` (the rendered hint the hover
/// describes), and takes no part in `equals` (the source inherits the
/// owner-only comparison). `initial_mouse_pos_*` are carried per the source
/// shape; the mouse-getting-closer seam reads the live recorded pointer
/// instead (`MouseCloserState`, Phase 4 increment 2).
pub(all) enum HoverAnchor {
  HoverRangeAnchor(
    priority~ : Int,
    range~ : @base_common.Range,
    initial_mouse_pos_x~ : Double?,
    initial_mouse_pos_y~ : Double?
  )
  HoverForeignElementAnchor(
    priority~ : Int,
    injected_text_index~ : Int,
    range~ : @base_common.Range,
    initial_mouse_pos_x~ : Double?,
    initial_mouse_pos_y~ : Double?,
    supports_marker_hover~ : Bool
  )
} derive(Eq)

///|
pub fn HoverAnchor::anchor_type(self : HoverAnchor) -> HoverAnchorType {
  match self {
    HoverRangeAnchor(..) => Range
    HoverForeignElementAnchor(..) => ForeignElement
  }
}

///|
pub fn HoverAnchor::priority(self : HoverAnchor) -> Int {
  match self {
    HoverRangeAnchor(priority~, ..)
    | HoverForeignElementAnchor(priority~, ..) => priority
  }
}

///|
pub fn HoverAnchor::range(self : HoverAnchor) -> @base_common.Range {
  match self {
    HoverRangeAnchor(range~, ..) | HoverForeignElementAnchor(range~, ..) =>
      range
  }
}

///|
/// `HoverForeignElementAnchor.supportsMarkerHover`; a range anchor reads as
/// Monaco's `undefined` (`false`) — its consumers gate on the anchor type
/// first (`anchor.type !== Range && !anchor.supportsMarkerHover`).
pub fn HoverAnchor::supports_marker_hover(self : HoverAnchor) -> Bool {
  match self {
    HoverRangeAnchor(..) => false
    HoverForeignElementAnchor(supports_marker_hover~, ..) =>
      supports_marker_hover
  }
}

///|
/// Monaco `HoverAnchor.equals` (`hoverTypes.ts:56-58,:75-77`): range anchors
/// compare their ranges; foreign anchors compare their owners only — with the
/// single foreign owner (`InlayHintsHover`), any two foreign anchors are
/// equal, exactly the source's inherited comparison (`InlayHintsHoverAnchor`
/// overrides no `equals`).
pub fn hover_anchor_equals(left : HoverAnchor, right : HoverAnchor) -> Bool {
  match left {
    HoverRangeAnchor(range=left_range, ..) =>
      right is HoverRangeAnchor(range=right_range, ..) &&
      left_range == right_range
    HoverForeignElementAnchor(..) => right is HoverForeignElementAnchor(..)
  }
}

///|
/// Monaco `HoverAnchor.canAdoptVisibleHover` (`hoverTypes.ts:59-61,:78-80`):
/// a new range anchor adopts a visible hover shown from a range anchor on the
/// same line (the source compares against the widget's shown position, which
/// `computeHoverPositions` clamps to the anchor line — the last anchor's
/// start line is that line); a new foreign anchor adopts a visible hover
/// shown from the same owner's foreign anchor.
pub fn hover_anchor_can_adopt(
  new_anchor : HoverAnchor,
  last_anchor : HoverAnchor,
) -> Bool {
  match new_anchor {
    HoverRangeAnchor(range~, ..) =>
      last_anchor is HoverRangeAnchor(..) &&
      last_anchor.range().start_line_number == range.start_line_number
    HoverForeignElementAnchor(..) =>
      last_anchor is HoverForeignElementAnchor(..)
  }
}
