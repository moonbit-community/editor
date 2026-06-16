///|
fn create_view_overlays_part(document : @rdom.Document) -> @rdom.Element {
  let view_overlays = document.create_element("div")
  view_overlays.set_attribute("class", "view-overlays")
  view_overlays.set_attribute("data-view-part", "view-overlays")
  view_overlays
}

///|
/// One style write per view part per flush: text-like content parts carry
/// the content transform, overlay widgets stay viewport-positioned, and
/// the margin translates vertically only.
fn Island::apply_geometry(
  self : Island,
  gutter_width : Double,
  scroll_left : Double,
  translate_y : Double,
) -> Unit {
  self.lines_content.set_attribute(
    "style",
    "left:" + gutter_width.to_string() + "px",
  )
  let content_transform = "transform:translate(" +
    (-scroll_left).to_string() +
    "px," +
    translate_y.to_string() +
    "px)"
  self.view_lines.set_attribute("style", content_transform)
  self.view_overlays.set_attribute("style", content_transform)
  self.view_zones.set_attribute("style", content_transform)
  self.content_widgets.set_attribute("style", content_transform)
  self.margin.set_attribute("style", "width:" + gutter_width.to_string() + "px")
  self.line_numbers.set_attribute(
    "style",
    "transform:translateY(" + translate_y.to_string() + "px)",
  )
}

///|
/// Drives both scrollbars from the layout state: thumb geometry through
/// the `ScrollbarState` arithmetic, hidden entirely while the content
/// fits.
fn Island::update_scrollbars(
  self : Island,
  dimensions : @renderer.ScrollDimensions,
  position : @renderer.ScrollPosition,
  gutter_width : Double,
) -> Unit {
  self.editor_scrollable.update_from_model(
    dimensions,
    position,
    horizontal_left=gutter_width,
  )
}
