///|
/// The Monaco `ViewLayout` role: combines the scroll truth (`Scrollable`)
/// with the line layout (`LinesLayout`) and derives the render viewport
/// from them, absorbing the `visible_window`/`window_needs_update`
/// semantics the browser cell uses today. Pure model state — input
/// capture and DOM application stay backend-side.
///
/// This is a zero-based view-zone adapter over the faithful, 1-based
/// `LinesLayout` port: the viewer addresses lines with zero-based indices and
/// models view zones as `ViewZone { anchor_line, height_px }`, which map onto
/// Monaco whitespaces as `afterLineNumber = anchor_line` (a zero-based line `L`
/// is Monaco's 1-based line `L + 1`, and a whitespace before `L` is "after"
/// 1-based line `L`). The `LinesLayout` held here is exactly the type the
/// conformance suite validates.
pub struct ViewLayout {
  scrollable : Scrollable
  priv mut lines : LinesLayout
  priv line_height : Int
  priv mut line_count : Int
  priv mut view_zones_arr : Array[ViewZone]
  priv mut content_width : Double
}

///|
/// Builds a faithful `LinesLayout` from the zero-based view-zone array: each
/// zone becomes a whitespace with `afterLineNumber = anchor_line`, inserted in
/// the array's (already normalized) order via `ordinal`.
fn build_lines(
  line_count : Int,
  line_height : Int,
  zones : Array[ViewZone],
) -> LinesLayout {
  let lines = LinesLayout::new(line_count, line_height, 0, 0)
  lines.change_whitespace(fn(accessor) {
    for i, zone in zones {
      accessor.insert_whitespace(zone.anchor_line, i, zone.height_px, 0)
      |> ignore
    }
  })
  |> ignore
  lines
}

///|
/// Creates a view layout with a fixed line height and optional line count.
pub fn ViewLayout::new(line_height~ : Int, line_count? : Int = 0) -> ViewLayout {
  let line_count = line_count.max(0)
  let layout : ViewLayout = {
    scrollable: Scrollable::new(),
    lines: build_lines(line_count, line_height, []),
    line_height,
    line_count,
    view_zones_arr: [],
    content_width: 0.0,
  }
  layout.sync_dimensions() |> ignore
  layout
}

///|
/// Replaces the document extent (line count) and re-derives the scroll
/// dimensions; the position re-clamps when the document shrank.
pub fn ViewLayout::set_line_count(
  self : ViewLayout,
  line_count : Int,
) -> ScrollChange? {
  self.line_count = line_count.max(0)
  self.view_zones_arr = normalized_view_zones(
    self.view_zones_arr,
    self.line_count,
  )
  self.lines = build_lines(
    self.line_count,
    self.line_height,
    self.view_zones_arr,
  )
  self.sync_dimensions()
}

///|
/// Sets the viewport box measured by the backend.
pub fn ViewLayout::set_viewport_size(
  self : ViewLayout,
  width~ : Double,
  height~ : Double,
) -> ScrollChange? {
  let dimensions = self.scrollable.dimensions()
  self.scrollable.set_dimensions({ ..dimensions, width, height }) |> ignore
  self.sync_dimensions()
}

///|
/// Sets the widest measured content width (horizontal scrolling extent).
pub fn ViewLayout::set_content_width(
  self : ViewLayout,
  content_width : Double,
) -> ScrollChange? {
  self.content_width = max_double(content_width, 0.0)
  self.sync_dimensions()
}

///|
/// Replaces view zones and re-derives scroll dimensions.
pub fn ViewLayout::set_view_zones(
  self : ViewLayout,
  view_zones : Array[ViewZone],
) -> ScrollChange? {
  self.view_zones_arr = normalized_view_zones(view_zones, self.line_count)
  self.lines = build_lines(
    self.line_count,
    self.line_height,
    self.view_zones_arr,
  )
  self.sync_dimensions()
}

///|
/// Current view-zone slots.
pub fn ViewLayout::view_zones(self : ViewLayout) -> Array[ViewZone] {
  self.view_zones_arr
}

///|
/// Current number of lines.
pub fn ViewLayout::line_count(self : ViewLayout) -> Int {
  self.line_count
}

///|
/// Total scrollable content height, including view zones.
pub fn ViewLayout::content_height(self : ViewLayout) -> Double {
  self.lines.get_lines_total_height().to_double()
}

///|
/// The top of a zero-based `line` in content space. Indices clamp to the
/// document so callers can probe one-past-the-end for a bottom edge.
pub fn ViewLayout::vertical_offset_for_line(
  self : ViewLayout,
  line : Int,
) -> Double {
  let line = @base_common.clamp_int(line, 0, self.line_count)
  self.lines.get_vertical_offset_for_line_number(line + 1).to_double()
}

///|
/// The zero-based line whose band contains a content-space vertical offset,
/// clamped to the document (`0` for an empty one).
pub fn ViewLayout::line_at_vertical_offset(
  self : ViewLayout,
  offset : Double,
) -> Int {
  if self.line_count <= 0 {
    return 0
  }
  let line_number = self.lines.get_line_number_at_or_after_vertical_offset(
    offset.to_int(),
  )
  (0).max(line_number - 1)
}

///|
/// Content-space top offset of a view zone by index.
pub fn ViewLayout::view_zone_vertical_offset(
  self : ViewLayout,
  index : Int,
) -> Double {
  if index < 0 || index >= self.view_zones_arr.length() {
    return 0.0
  }
  self.lines.get_vertical_offset_for_whitespace_index(index).to_double()
}

///|
/// View-zone geometry relative to a rendered line window.
pub fn ViewLayout::view_zone_viewport_data(
  self : ViewLayout,
  window : LineWindow,
) -> Array[ViewZoneViewportData] {
  let out : Array[ViewZoneViewportData] = []
  let window_top = self.vertical_offset_for_line(window.start)
  let window_bottom = self.vertical_offset_for_line(window.end)
  for index in 0..<self.view_zones_arr.length() {
    let zone = self.view_zones_arr[index]
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
/// Top offset of zero-based `line` relative to the rendered window start.
pub fn ViewLayout::relative_vertical_offset_for_line(
  self : ViewLayout,
  window : LineWindow,
  line : Int,
) -> Int {
  (self.vertical_offset_for_line(line) -
  self.vertical_offset_for_line(window.start)).to_int()
}

///|
/// Sets the synthetic scroll position, preserving horizontal position unless
/// `scroll_left` is supplied.
pub fn ViewLayout::scroll_to(
  self : ViewLayout,
  scroll_top~ : Double,
  scroll_left? : Double,
) -> ScrollChange? {
  let position = self.scrollable.position()
  let scroll_left = match scroll_left {
    Some(value) => value
    None => position.scroll_left
  }
  self.scrollable.set_position({ scroll_left, scroll_top })
}

///|
/// Applies a relative synthetic scroll delta.
pub fn ViewLayout::scroll_by(
  self : ViewLayout,
  delta_left? : Double = 0.0,
  delta_top? : Double = 0.0,
) -> ScrollChange? {
  self.scrollable.scroll_by(delta_left~, delta_top~)
}

///|
/// Current synthetic scroll position.
pub fn ViewLayout::position(self : ViewLayout) -> ScrollPosition {
  self.scrollable.position()
}

///|
/// Current viewport and content dimensions.
pub fn ViewLayout::dimensions(self : ViewLayout) -> ScrollDimensions {
  self.scrollable.dimensions()
}

///|
/// The window of lines worth rendering for the current scroll state: the
/// visible band plus `overscan` lines on each side, clamped to the
/// document — including the unmeasured-viewport default band.
pub fn ViewLayout::visible_window(
  self : ViewLayout,
  overscan~ : Int,
) -> LineWindow {
  let scroll_top = self.scrollable.position().scroll_top
  let viewport_height = self.scrollable.dimensions().height
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
/// Hysteresis for window updates, unchanged from `window_needs_update`:
/// re-render only when the desired window drifted by more than half the
/// overscan from the rendered one.
pub fn ViewLayout::window_needs_update(
  self : ViewLayout,
  rendered : LineWindow,
  overscan~ : Int,
) -> Bool {
  window_needs_update(rendered, self.visible_window(overscan~), overscan)
}

///|
/// The content-space top of a window's first line: the translation the
/// view applies to the lines layer (`window_origin - scroll_top`).
pub fn ViewLayout::window_origin(
  self : ViewLayout,
  window : LineWindow,
) -> Double {
  self.vertical_offset_for_line(window.start)
}

///|
fn ViewLayout::sync_dimensions(self : ViewLayout) -> ScrollChange? {
  let dimensions = self.scrollable.dimensions()
  self.scrollable.set_dimensions({
    ..dimensions,
    scroll_width: max_double(self.content_width, dimensions.width),
    scroll_height: max_double(self.content_height(), dimensions.height),
  })
}

///|
/// Clamps view-zone anchors into `[0, line_count]`, floors heights at zero, and
/// sorts by `(anchor_line, height_px)` — the zero-based normalization the
/// adapter applies before translating zones into faithful whitespaces.
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
        line_count.max(0),
      ),
      height_px: zone.height_px.max(0),
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
