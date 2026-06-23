///|
priv struct BrowserViewZone {
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
/// Mutation accessor passed to `Viewer::change_view_zones`; callers describe
/// the complete set of changes inside one layout invalidation.
pub(all) struct ViewZoneChangeAccessor {
  viewer : Viewer
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
/// Applies a batch of browser view-zone mutations and reflows the viewer.
pub fn Viewer::change_view_zones(
  self : Viewer,
  update : (ViewZoneChangeAccessor) -> Unit,
) -> Unit {
  update({ viewer: self })
  self.normalize_browser_view_zones()
  self.sync_view_zones_with_layout()
  self.content_generation += 1
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Adds or replaces a view zone by id.
pub fn ViewZoneChangeAccessor::add_zone(
  self : ViewZoneChangeAccessor,
  id : String,
  anchor_line : Int,
  height_px : Int,
  node : @rdom.Element,
) -> Unit {
  self.viewer.upsert_view_zone(id, anchor_line, height_px, node)
}

///|
/// Updates a view zone by id; currently equivalent to `add_zone`.
pub fn ViewZoneChangeAccessor::update_zone(
  self : ViewZoneChangeAccessor,
  id : String,
  anchor_line : Int,
  height_px : Int,
  node : @rdom.Element,
) -> Unit {
  self.viewer.upsert_view_zone(id, anchor_line, height_px, node)
}

///|
/// Removes a view zone by id.
pub fn ViewZoneChangeAccessor::remove_zone(
  self : ViewZoneChangeAccessor,
  id : String,
) -> Unit {
  for index in 0..<self.viewer.view_zones.length() {
    if self.viewer.view_zones[index].id == id {
      self.viewer.view_zones.remove(index) |> ignore
      return
    }
  }
}

///|
fn Viewer::upsert_view_zone(
  self : Viewer,
  id : String,
  anchor_line : Int,
  height_px : Int,
  node : @rdom.Element,
) -> Unit {
  let zone : BrowserViewZone = { id, anchor_line, height_px, node }
  for index in 0..<self.view_zones.length() {
    if self.view_zones[index].id == id {
      self.view_zones[index] = zone
      return
    }
  }
  self.view_zones.push(zone)
}

///|
fn Viewer::normalize_browser_view_zones(self : Viewer) -> Unit {
  let normalized : Array[BrowserViewZone] = []
  let line_count = self.layout.line_count()
  for zone in self.view_zones {
    let max_anchor = if line_count > 0 {
      line_count
    } else {
      max_int(zone.anchor_line, 0)
    }
    normalized.push({
      ..zone,
      anchor_line: @base_common.clamp_int(zone.anchor_line, 0, max_anchor),
      height_px: max_int(zone.height_px, 0),
    })
  }
  normalized.sort_by(compare_browser_view_zones)
  self.view_zones = normalized
}

///|
fn compare_browser_view_zones(
  left : BrowserViewZone,
  right : BrowserViewZone,
) -> Int {
  let anchor = left.anchor_line - right.anchor_line
  if anchor != 0 {
    return anchor
  }
  let height = left.height_px - right.height_px
  if height != 0 {
    return height
  }
  if left.id < right.id {
    -1
  } else if left.id > right.id {
    1
  } else {
    0
  }
}

///|
fn Viewer::sync_view_zones_with_layout(self : Viewer) -> Unit {
  let zones : Array[@view_layout.ViewZone] = []
  for zone in self.view_zones {
    zones.push({ anchor_line: zone.anchor_line, height_px: zone.height_px })
  }
  self.apply_scroll_change(self.layout.set_view_zones(zones))
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
