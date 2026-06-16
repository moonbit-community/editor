///|
/// An inline widget that displaces the lines after `anchor_line` by
/// `height_px` pixels (the references peek is the only zone today).
pub(all) struct ViewZone {
  anchor_line : Int
  height_px : Int
} derive(Debug)
