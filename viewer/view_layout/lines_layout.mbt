///|
/// Vertical line layout, the uniform-height subset of Monaco's
/// `LinesLayout` interface: every line is `line_height` pixels tall,
/// lines are addressed by zero-based index, and view zones displace the
/// lines after their anchor the way Monaco view whitespaces do.
pub struct LinesLayout {
  priv mut line_count : Int
  priv mut line_height : Int
  priv mut view_zones : Array[ViewZone]
}

///|
/// Creates a uniform-height line layout.
pub fn LinesLayout::new(
  line_height~ : Int,
  line_count? : Int = 0,
) -> LinesLayout {
  { line_count: max_int(line_count, 0), line_height, view_zones: [] }
}

///|
/// Number of model/view lines tracked by the layout.
pub fn LinesLayout::line_count(self : LinesLayout) -> Int {
  self.line_count
}

///|
/// Fixed line height in CSS pixels.
pub fn LinesLayout::line_height(self : LinesLayout) -> Int {
  self.line_height
}

///|
/// Updates the line count and clamps existing view zones into the new extent.
pub fn LinesLayout::set_line_count(
  self : LinesLayout,
  line_count : Int,
) -> Unit {
  self.line_count = max_int(line_count, 0)
  self.view_zones = normalized_view_zones(self.view_zones, self.line_count)
}

///|
/// Updates the fixed line height in CSS pixels.
pub fn LinesLayout::set_line_height(
  self : LinesLayout,
  line_height : Int,
) -> Unit {
  self.line_height = line_height
}

///|
/// View-zone slots for hit-test geometry and line displacement.
pub fn LinesLayout::view_zones(self : LinesLayout) -> Array[ViewZone] {
  self.view_zones
}

///|
/// Replaces view-zone geometry, normalizing anchor lines and heights.
pub fn LinesLayout::set_view_zones(
  self : LinesLayout,
  view_zones : Array[ViewZone],
) -> Unit {
  self.view_zones = normalized_view_zones(view_zones, self.line_count)
}

///|
/// The top of a line in content space. Indices clamp to the document so
/// callers can probe one-past-the-end for a bottom edge.
pub fn LinesLayout::vertical_offset_for_line(
  self : LinesLayout,
  line : Int,
) -> Double {
  let line = @base_common.clamp_int(line, 0, self.line_count)
  let offset = line * self.line_height +
    zone_height_before_line(self.view_zones, line)
  offset.to_double()
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
  let mut zone_offset = 0
  for zone in self.view_zones {
    let zone_top = zone.anchor_line * self.line_height + zone_offset
    if offset < zone_top.to_double() {
      break
    }
    if offset < (zone_top + zone.height_px).to_double() {
      return @base_common.clamp_int(zone.anchor_line, 0, self.line_count - 1)
    }
    zone_offset = zone_offset + zone.height_px
  }
  let offset = offset - zone_offset.to_double()
  let line = (offset / self.line_height.to_double()).to_int()
  @base_common.clamp_int(line, 0, self.line_count - 1)
}

///|
/// Total scrollable content height, including view zones.
pub fn LinesLayout::content_height(self : LinesLayout) -> Double {
  let height = self.line_count * self.line_height +
    total_zone_height(self.view_zones)
  height.to_double()
}

///|
/// Computes the zero-based half-open line window intersecting the viewport plus
/// overscan.
pub fn LinesLayout::visible_window(
  self : LinesLayout,
  scroll_top : Double,
  viewport_height : Double,
  overscan : Int,
) -> LineWindow {
  if self.line_count <= 0 {
    return { start: 0, end: 0 }
  }
  if viewport_height <= 0.0 {
    let end = @base_common.clamp_int(
      default_visible_lines + overscan,
      0,
      self.line_count,
    )
    return { start: 0, end }
  }
  let first_visible = self.line_at_vertical_offset(scroll_top)
  let last_visible = self.line_at_vertical_offset(scroll_top + viewport_height)
  let start = @base_common.clamp_int(
    first_visible - overscan,
    0,
    self.line_count,
  )
  let end = @base_common.clamp_int(
    last_visible + 1 + overscan,
    start,
    self.line_count,
  )
  { start, end }
}

///|
/// Content-space top offset of a view zone by index.
pub fn LinesLayout::view_zone_vertical_offset(
  self : LinesLayout,
  index : Int,
) -> Double {
  if index < 0 || index >= self.view_zones.length() {
    return 0.0
  }
  let zone = self.view_zones[index]
  let mut previous_height = 0
  for i in 0..<index {
    previous_height = previous_height + self.view_zones[i].height_px
  }
  (zone.anchor_line * self.line_height + previous_height).to_double()
}

///|
/// View-zone geometry relative to a rendered line window.
pub fn LinesLayout::view_zone_viewport_data(
  self : LinesLayout,
  window : LineWindow,
) -> Array[ViewZoneViewportData] {
  let out : Array[ViewZoneViewportData] = []
  let window_top = self.vertical_offset_for_line(window.start)
  let window_bottom = self.vertical_offset_for_line(window.end)
  for index in 0..<self.view_zones.length() {
    let zone = self.view_zones[index]
    let zone_top = self.view_zone_vertical_offset(index)
    let zone_bottom = zone_top + zone.height_px.to_double()
    if zone_bottom >= window_top && zone_top <= window_bottom {
      out.push({
        zone_index: index,
        anchor_line: zone.anchor_line,
        height_px: zone.height_px,
        relative_vertical_offset: (zone_top - window_top).to_int(),
      })
    }
  }
  out
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn normalized_view_zones(
  view_zones : Array[ViewZone],
  line_count : Int,
) -> Array[ViewZone] {
  let normalized : Array[ViewZone] = []
  for zone in view_zones {
    normalized.push({
      anchor_line: @base_common.clamp_int(
        zone.anchor_line,
        0,
        max_int(line_count, 0),
      ),
      height_px: max_int(zone.height_px, 0),
    })
  }
  normalized.sort_by(compare_view_zones)
  normalized
}

///|
fn compare_view_zones(left : ViewZone, right : ViewZone) -> Int {
  let anchor = left.anchor_line - right.anchor_line
  if anchor != 0 {
    anchor
  } else {
    left.height_px - right.height_px
  }
}

///|
fn zone_height_before_line(view_zones : Array[ViewZone], line : Int) -> Int {
  let mut height = 0
  for zone in view_zones {
    if zone.anchor_line <= line {
      height = height + zone.height_px
    }
  }
  height
}

///|
fn total_zone_height(view_zones : Array[ViewZone]) -> Int {
  let mut height = 0
  for zone in view_zones {
    height = height + zone.height_px
  }
  height
}
