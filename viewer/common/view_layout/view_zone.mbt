///|
/// An inline widget that displaces the lines after `anchor_line` by
/// `height_px` pixels (the references peek is the only zone today).
/// `anchor_line` is Monaco's `IViewZone.afterLineNumber`: the 1-based view line
/// the zone is shown after (`0` = above the first line), valid in
/// `[0, line_count]`.
pub(all) struct ViewZone {
  anchor_line : Int
  height_px : Int
} derive(Eq, Debug)

///|
/// View-zone geometry after it has been positioned relative to a rendered
/// viewport.
pub(all) struct ViewZoneViewportData {
  zone_index : Int
  anchor_line : Int
  height_px : Int
  relative_vertical_offset : Int
} derive(Eq, Debug)
