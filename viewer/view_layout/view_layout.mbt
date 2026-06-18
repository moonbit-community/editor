///|
/// The Monaco `ViewLayout` role: combines the scroll truth (`Scrollable`)
/// with the line layout (`LinesLayout`) and derives the render viewport
/// from them, absorbing the `visible_window`/`window_needs_update`
/// semantics the browser cell uses today. Pure model state — input
/// capture and DOM application stay backend-side.
pub struct ViewLayout {
  scrollable : Scrollable
  lines : LinesLayout
  priv mut content_width : Double
}

///|
/// Creates a view layout with a fixed line height and optional line count.
pub fn ViewLayout::new(line_height~ : Int, line_count? : Int = 0) -> ViewLayout {
  let layout : ViewLayout = {
    scrollable: Scrollable::new(),
    lines: LinesLayout::new(line_height~, line_count~),
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
  self.lines.set_line_count(line_count)
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
  self.lines.set_view_zones(view_zones)
  self.sync_dimensions()
}

///|
/// Current view-zone slots.
pub fn ViewLayout::view_zones(self : ViewLayout) -> Array[ViewZone] {
  self.lines.view_zones()
}

///|
/// Current number of lines.
pub fn ViewLayout::line_count(self : ViewLayout) -> Int {
  self.lines.line_count()
}

///|
/// Content-space top offset of a view zone by index.
pub fn ViewLayout::view_zone_vertical_offset(
  self : ViewLayout,
  index : Int,
) -> Double {
  self.lines.view_zone_vertical_offset(index)
}

///|
/// View-zone geometry relative to a rendered line window.
pub fn ViewLayout::view_zone_viewport_data(
  self : ViewLayout,
  window : LineWindow,
) -> Array[ViewZoneViewportData] {
  self.lines.view_zone_viewport_data(window)
}

///|
/// Top offset of `line` relative to the rendered window start.
pub fn ViewLayout::relative_vertical_offset_for_line(
  self : ViewLayout,
  window : LineWindow,
  line : Int,
) -> Int {
  (self.lines.vertical_offset_for_line(line) -
  self.lines.vertical_offset_for_line(window.start)).to_int()
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
/// document — `visible_window` over the layout's own state, including its
/// unmeasured-viewport default band.
pub fn ViewLayout::visible_window(
  self : ViewLayout,
  overscan~ : Int,
) -> LineWindow {
  self.lines.visible_window(
    self.scrollable.position().scroll_top,
    self.scrollable.dimensions().height,
    overscan,
  )
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
  self.lines.vertical_offset_for_line(window.start)
}

///|
fn ViewLayout::sync_dimensions(self : ViewLayout) -> ScrollChange? {
  let dimensions = self.scrollable.dimensions()
  self.scrollable.set_dimensions({
    ..dimensions,
    scroll_width: max_double(self.content_width, dimensions.width),
    scroll_height: max_double(self.lines.content_height(), dimensions.height),
  })
}
