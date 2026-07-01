///|
/// `pub(all)`: `Viewer.view_zones : Array[BrowserViewZone]` (`viewer.mbt`) and
/// the `view_zones_host.mbt` glue construct/read these fields from `Viewer`'s
/// package, which cannot hold this file's other content (`ViewZones` is a
/// browser-tier view-part type, not `Viewer::`-owned).
pub(all) struct BrowserViewZone {
  id : String
  anchor_line : Int
  height_px : Int
  node : @rdom.Element
}

///|
priv struct ViewZonesPrepared {
  zones : Array[BrowserViewZone]
  viewport : @view_layout.ViewportData
}

///|
priv struct ViewZones {
  view_zones : @rdom.Element
  mut should_render : Bool
  mut prepared : ViewZonesPrepared?
}

///|
fn ViewZones::new(document : @rdom.Document) -> ViewZones {
  let view_zones = document.create_element("div")
  view_zones.set_attribute("class", "view-zones")
  view_zones.set_attribute("data-view-part", "view-zones")
  { view_zones, should_render: true, prepared: None }
}

///|
fn ViewZones::dom(self : ViewZones) -> @rdom.Element {
  self.view_zones
}

///|
impl ViewPart for ViewZones with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for ViewZones with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    ViewScrollChanged(e) =>
      e.window_changed || e.position_changed || e.dimensions_changed
    ViewZonesChanged => true
    _ => false
  }
}

///|
impl ViewPart for ViewZones with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for ViewZones with fn on_before_render(_self, _viewport) {
  ()
}

///|
impl ViewPart for ViewZones with fn prepare_render(self, context) {
  self.prepared = Some({
    zones: context.input.browser_view_zones,
    viewport: context.viewport,
  })
}

///|
impl ViewPart for ViewZones with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_view_zones(prepared.zones, prepared.viewport)
      self.view_zones.set_attribute("style", context.content_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for ViewZones with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

///|
fn ViewZones::render_view_zones(
  self : ViewZones,
  zones : Array[BrowserViewZone],
  viewport : @view_layout.ViewportData,
) -> Unit {
  self.view_zones.set_inner_html("")
  for data in viewport.view_zones {
    if data.zone_index < 0 || data.zone_index >= zones.length() {
      continue
    }
    let zone = zones[data.zone_index]
    zone.node.set_attribute("class", "view-zone")
    zone.node.set_attribute("data-view-zone-id", zone.id)
    zone.node.set_attribute(
      "style",
      view_zone_style(data.relative_vertical_offset, data.height_px),
    )
    self.view_zones.append_child(zone.node.as_node())
  }
}

///|
fn view_zone_style(top : Int, height : Int) -> String {
  "top:" + top.to_string() + "px;height:" + height.to_string() + "px"
}
