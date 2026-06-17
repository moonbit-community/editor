///|
fn create_view_overlays_part(document : @rdom.Document) -> @rdom.Element {
  let view_overlays = document.create_element("div")
  view_overlays.set_attribute("class", "view-overlays")
  view_overlays.set_attribute("data-view-part", "view-overlays")
  view_overlays
}

///|
/// Drives both scrollbars from the layout state: thumb geometry through
/// the `ScrollbarState` arithmetic, hidden entirely while the content
/// fits.
fn View::update_scrollbars(
  self : View,
  dimensions : @view_layout.ScrollDimensions,
  position : @view_layout.ScrollPosition,
  gutter_width : Double,
) -> Unit {
  self.editor_scrollable.update_from_model(
    dimensions,
    position,
    horizontal_left=gutter_width,
  )
}
