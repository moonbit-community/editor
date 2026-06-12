///|
/// Vertical line layout, the uniform-height subset of Monaco's
/// `LinesLayout` interface: every line is `line_height` pixels tall and
/// lines are addressed by zero-based index. View zones are carried as
/// layout slots only — they feed `ViewMetrics.view_zones`, and their
/// displacement math stays deferred until zones render again.
pub struct LinesLayout {
  priv mut line_count : Int
  priv mut line_height : Int
  priv mut view_zones : Array[ViewZone]
}

///|
pub fn LinesLayout::new(
  line_height~ : Int,
  line_count? : Int = 0,
) -> LinesLayout {
  { line_count: max_int(line_count, 0), line_height, view_zones: [] }
}

///|
pub fn LinesLayout::line_count(self : LinesLayout) -> Int {
  self.line_count
}

///|
pub fn LinesLayout::line_height(self : LinesLayout) -> Int {
  self.line_height
}

///|
pub fn LinesLayout::set_line_count(
  self : LinesLayout,
  line_count : Int,
) -> Unit {
  self.line_count = max_int(line_count, 0)
}

///|
pub fn LinesLayout::set_line_height(
  self : LinesLayout,
  line_height : Int,
) -> Unit {
  self.line_height = line_height
}

///|
/// View-zone slots for hit-test geometry; layout displacement is deferred.
pub fn LinesLayout::view_zones(self : LinesLayout) -> Array[ViewZone] {
  self.view_zones
}

///|
pub fn LinesLayout::set_view_zones(
  self : LinesLayout,
  view_zones : Array[ViewZone],
) -> Unit {
  self.view_zones = view_zones
}

///|
/// The top of a line in content space. Indices clamp to the document so
/// callers can probe one-past-the-end for a bottom edge.
pub fn LinesLayout::vertical_offset_for_line(
  self : LinesLayout,
  line : Int,
) -> Double {
  let line = @core.clamp_int(line, 0, self.line_count)
  (line * self.line_height).to_double()
}

///|
/// The line whose band contains a content-space vertical offset, clamped
/// to the document (`0` for an empty one).
pub fn LinesLayout::line_at_vertical_offset(
  self : LinesLayout,
  offset : Double,
) -> Int {
  if self.line_count <= 0 || self.line_height <= 0 {
    return 0
  }
  let line = (offset / self.line_height.to_double()).to_int()
  @core.clamp_int(line, 0, self.line_count - 1)
}

///|
pub fn LinesLayout::content_height(self : LinesLayout) -> Double {
  (self.line_count * self.line_height).to_double()
}
