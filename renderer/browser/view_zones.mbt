///|
fn create_view_zones_part(document : @rdom.Document) -> @rdom.Element {
  let view_zones = document.create_element("div")
  view_zones.set_attribute("class", "view-zones")
  view_zones.set_attribute("data-view-part", "view-zones")
  view_zones
}
