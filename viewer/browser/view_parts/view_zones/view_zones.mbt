// Ported from `vscode/src/vs/editor/browser/viewParts/viewZones/viewZones.ts`.
// The `ViewPart` trait impl for `ViewZones` lives in `viewer/view_part.mbt`
// (destined for `browser/view/`), not here: MoonBit's orphan rule only lets
// the trait-owning package implement a trait for a foreign type, and
// `browser/view/` needs the concrete view-part types anyway (`View`'s fields,
// the `ViewPartHandle` enum) — keeping the impls there is what keeps this
// package from needing an import back, see the exec-plan's cycle backlog.

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
/// `pub(all)`: constructed by the `ViewPart` impl in `view_part.mbt`.
pub(all) struct ViewZonesPrepared {
  zones : Array[BrowserViewZone]
  viewport : @view_layout.ViewportData
}

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render`/`prepared` directly.
pub(all) struct ViewZones {
  view_zones : @rdom.Element
  mut should_render : Bool
  mut prepared : ViewZonesPrepared?
}

///|
pub fn ViewZones::new(document : @rdom.Document) -> ViewZones {
  let view_zones = document.create_element("div")
  view_zones.set_attribute("class", "view-zones")
  view_zones.set_attribute("data-view-part", "view-zones")
  { view_zones, should_render: true, prepared: None }
}

///|
pub fn ViewZones::dom(self : ViewZones) -> @rdom.Element {
  self.view_zones
}

///|
pub fn ViewZones::render_view_zones(
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
