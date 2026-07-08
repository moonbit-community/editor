// The viewer core's side of the `viewer/browser/view_parts/view_zones`
// seam: the public `ViewZoneChangeAccessor` mutation API and the `Viewer::`
// glue that keeps `Viewer.view_zones` normalized and synced with the layout
// model. Kept out of `view_zones.mbt` because it holds a `Viewer` reference
// (the foreign-method rule keeps every `Viewer::` method in `Viewer`'s own
// package), which `ViewZones`/`BrowserViewZone` — a browser-tier view-part
// type — cannot depend on without creating a
// `browser/view_parts/view_zones ↔ browser/widget/code_editor` cycle.

///|
/// Mutation accessor passed to `Viewer::change_view_zones`; callers describe
/// the complete set of changes inside one layout invalidation.
pub struct ViewZoneChangeAccessor {
  priv viewer : Viewer
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
/// Adds or replaces a view zone by id. `on_dom_node_top`/`on_computed_height`
/// are `IViewZone.onDomNodeTop`/`onComputedHeight`: fired on every render
/// with the zone's viewport-relative top / computed height, so widgets riding
/// the zone (zone widgets) can position themselves.
pub fn ViewZoneChangeAccessor::add_zone(
  self : ViewZoneChangeAccessor,
  id : String,
  anchor_line : Int,
  height_px : Int,
  node : @rdom.Element,
  on_dom_node_top? : (Double) -> Unit,
  on_computed_height? : (Int) -> Unit,
) -> Unit {
  self.viewer.upsert_view_zone(
    id, anchor_line, height_px, node, on_dom_node_top, on_computed_height,
  )
}

///|
/// Updates a view zone by id; currently equivalent to `add_zone`.
pub fn ViewZoneChangeAccessor::update_zone(
  self : ViewZoneChangeAccessor,
  id : String,
  anchor_line : Int,
  height_px : Int,
  node : @rdom.Element,
  on_dom_node_top? : (Double) -> Unit,
  on_computed_height? : (Int) -> Unit,
) -> Unit {
  self.viewer.upsert_view_zone(
    id, anchor_line, height_px, node, on_dom_node_top, on_computed_height,
  )
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
  on_dom_node_top : ((Double) -> Unit)?,
  on_computed_height : ((Int) -> Unit)?,
) -> Unit {
  let zone : @view_zones.BrowserViewZone = {
    id,
    anchor_line,
    height_px,
    node,
    on_dom_node_top,
    on_computed_height,
  }
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
  let normalized : Array[@view_zones.BrowserViewZone] = []
  let line_count = match self.get_view_model() {
    Some(view_model) => view_model.view_layout.line_count()
    None => 0
  }
  for zone in self.view_zones {
    let max_anchor = if line_count > 0 {
      line_count
    } else {
      zone.anchor_line.max(0)
    }
    normalized.push({
      ..zone,
      anchor_line: @base_common.clamp_int(zone.anchor_line, 0, max_anchor),
      height_px: zone.height_px.max(0),
    })
  }
  normalized.sort_by(compare_browser_view_zones)
  self.view_zones = normalized
}

///|
fn compare_browser_view_zones(
  left : @view_zones.BrowserViewZone,
  right : @view_zones.BrowserViewZone,
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
  // No model → no live layout; the zones re-sync at the next attach via
  // `apply_view_model_layout`.
  guard self.get_view_model() is Some(view_model) else { return }
  let zones : Array[@view_layout.ViewZone] = []
  for zone in self.view_zones {
    zones.push({ anchor_line: zone.anchor_line, height_px: zone.height_px })
  }
  self.apply_scroll_change(view_model.view_layout.set_view_zones(zones))
}
