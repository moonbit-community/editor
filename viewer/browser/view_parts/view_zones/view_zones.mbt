// Ported from `vscode/src/vs/editor/browser/viewParts/viewZones/viewZones.ts`.
// The `ViewPart` trait impl for `ViewZones` lives in
// `viewer/browser/view/view_part.mbt`, not here: MoonBit's orphan rule only lets
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
  /// `IViewZone.onDomNodeTop`: called on render with the zone's
  /// viewport-relative top (widgets riding the zone position themselves from
  /// it). Zones outside the rendered viewport report a large negative top so
  /// followers park offscreen (`viewZones.ts:396`).
  on_dom_node_top : ((Double) -> Unit)?
  /// `IViewZone.onComputedHeight`: called on render with the zone's height.
  on_computed_height : ((Int) -> Unit)?
}

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` directly.
pub(all) struct ViewZones {
  dom_node : @rdom.Element
  mounted_nodes : Map[String, @rdom.Element]
  styles : Map[String, String]
  mut should_render : Bool
}

///|
pub fn ViewZones::new(document : @rdom.Document) -> ViewZones {
  let dom_node = document.create_element("div")
  dom_node.set_attribute("class", "view-zones")
  dom_node.set_attribute("data-view-part", "view-zones")
  { dom_node, mounted_nodes: {}, styles: {}, should_render: true }
}

///|
pub fn ViewZones::dom_node(self : ViewZones) -> @rdom.Element {
  self.dom_node
}

///|
pub fn ViewZones::render_view_zones(
  self : ViewZones,
  zones : Array[BrowserViewZone],
  viewport : @view_layout.ViewportData,
  translate_y : Double,
) -> Unit {
  // Monaco retains every zone node and only updates cached geometry/display
  // styles. Reconcile registrations without rebuilding the container.
  let current_ids : Map[String, Bool] = {}
  for zone in zones {
    current_ids.set(zone.id, true)
    match self.mounted_nodes.get(zone.id) {
      Some(node) if !node.is_same_node(zone.node.as_node()) => {
        self.dom_node.remove_child(node.as_node())
        self.styles.remove(zone.id)
        self.mount_zone(zone)
      }
      Some(_) => ()
      None => self.mount_zone(zone)
    }
  }
  let removed : Array[String] = []
  for id, node in self.mounted_nodes {
    if !current_ids.contains(id) {
      self.dom_node.remove_child(node.as_node())
      removed.push(id)
    }
  }
  for id in removed {
    self.mounted_nodes.remove(id)
    self.styles.remove(id)
  }
  let visible = Array::make(zones.length(), false)
  for data in viewport.view_zones {
    if data.zone_index < 0 || data.zone_index >= zones.length() {
      continue
    }
    visible[data.zone_index] = true
    let zone = zones[data.zone_index]
    self.set_zone_style(
      zone,
      view_zone_style(data.relative_vertical_offset, data.height_px, true),
    )
    // `_safeCallOnComputedHeight` / `_safeCallOnDomNodeTop`
    // (`viewZones.ts:336-352`, invoked from `render` :382-395). The
    // viewport-relative top is the window-relative offset plus the content
    // translate — the analog of `getScrolledTopFromAbsoluteTop`.
    match zone.on_computed_height {
      Some(callback) => callback(data.height_px)
      None => ()
    }
    match zone.on_dom_node_top {
      Some(callback) =>
        callback(data.relative_vertical_offset.to_double() + translate_y)
      None => ()
    }
  }
  // Zones outside the rendered viewport park their followers offscreen
  // (`viewZones.ts:396` `getScrolledTopFromAbsoluteTop(-1000000)`).
  for index in 0..<zones.length() {
    if !visible[index] {
      self.set_zone_style(zones[index], view_zone_style(0, 0, false))
      match zones[index].on_dom_node_top {
        Some(callback) => callback(offscreen_zone_top)
        None => ()
      }
    }
  }
}

///|
fn ViewZones::mount_zone(self : ViewZones, zone : BrowserViewZone) -> Unit {
  zone.node.set_attribute("class", "view-zone")
  zone.node.set_attribute("data-view-zone-id", zone.id)
  self.dom_node.append_child(zone.node.as_node())
  self.mounted_nodes.set(zone.id, zone.node)
}

///|
fn ViewZones::set_zone_style(
  self : ViewZones,
  zone : BrowserViewZone,
  style : String,
) -> Unit {
  if self.styles.get(zone.id) != Some(style) {
    zone.node.set_attribute("style", style)
    self.styles.set(zone.id, style)
  }
}

///|
/// `viewZones.ts:396`: the parked top for zones outside the viewport.
let offscreen_zone_top : Double = -1000000.0

///|
fn view_zone_style(top : Int, height : Int, visible : Bool) -> String {
  "top:" +
  top.to_string() +
  "px;height:" +
  height.to_string() +
  "px;display:" +
  (if visible { "block" } else { "none" })
}
