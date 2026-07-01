///|
/// Private Monaco-shaped render lifecycle for browser view concerns. The
/// event-handling half (`on_view_event` / `should_render` / `set_should_render`
/// / `on_did_render`) mirrors Monaco's `ViewEventHandler`: a typed view event is
/// offered to every part, and a part that returns `true` is marked dirty for the
/// next render. `should_render` returns that accumulated flag (no longer a
/// snapshot diff). The render half (`on_before_render` / `prepare_render` /
/// `render`) mirrors Monaco's `ViewPart`/`DynamicViewOverlay`.
priv trait ViewPart {
  fn on_view_event(Self, ViewEvent) -> Bool
  fn should_render(Self) -> Bool
  fn set_should_render(Self, Bool) -> Unit
  fn on_before_render(Self, @view_layout.ViewportData) -> Unit
  fn prepare_render(Self, RenderingContext) -> Unit
  fn render(Self, RestrictedRenderingContext) -> Unit
  fn on_did_render(Self) -> Unit
}

///|
/// Dispatches a frame's view events to one part, accumulating its dirty flag.
/// Mirrors `ViewEventHandler.handleEvents`.
fn ViewPartHandle::handle_view_events(
  self : ViewPartHandle,
  events : Array[ViewEvent],
) -> Unit {
  for event in events {
    if self.on_view_event(event) {
      self.set_should_render(true)
    }
  }
}

///|
priv enum ViewPartHandle {
  ViewLinesPart(ViewLines)
  ViewZonesPart(@view_zones.ViewZones)
  ContentViewOverlaysPart(ContentViewOverlays)
  MarginViewOverlaysPart(MarginViewOverlays)
  ContentWidgetsPart(ContentWidgets)
  OverlayWidgetsPart(OverlayWidgets)
  EditorScrollbarPart(EditorScrollbar)
}

///|
fn default_view_parts(
  view_lines : ViewLines,
  view_zones : @view_zones.ViewZones,
  content_view_overlays : ContentViewOverlays,
  margin_view_overlays : MarginViewOverlays,
  content_widgets : ContentWidgets,
  overlay_widgets : OverlayWidgets,
  editor_scrollbar : EditorScrollbar,
) -> Array[ViewPartHandle] {
  [
    ViewLinesPart(view_lines),
    ViewZonesPart(view_zones),
    ContentViewOverlaysPart(content_view_overlays),
    MarginViewOverlaysPart(margin_view_overlays),
    ContentWidgetsPart(content_widgets),
    OverlayWidgetsPart(overlay_widgets),
    EditorScrollbarPart(editor_scrollbar),
  ]
}

///|
impl ViewPart for ViewPartHandle with fn on_view_event(self, event) {
  match self {
    ViewLinesPart(part) => part.on_view_event(event)
    ViewZonesPart(part) => ViewPart::on_view_event(part, event)
    ContentViewOverlaysPart(part) => part.on_view_event(event)
    MarginViewOverlaysPart(part) => part.on_view_event(event)
    ContentWidgetsPart(part) => part.on_view_event(event)
    OverlayWidgetsPart(part) => part.on_view_event(event)
    EditorScrollbarPart(part) => part.on_view_event(event)
  }
}

///|
impl ViewPart for ViewPartHandle with fn should_render(self) {
  match self {
    ViewLinesPart(part) => part.should_render()
    ViewZonesPart(part) => ViewPart::should_render(part)
    ContentViewOverlaysPart(part) => part.should_render()
    MarginViewOverlaysPart(part) => part.should_render()
    ContentWidgetsPart(part) => part.should_render()
    OverlayWidgetsPart(part) => part.should_render()
    EditorScrollbarPart(part) => part.should_render()
  }
}

///|
impl ViewPart for ViewPartHandle with fn set_should_render(self, value) {
  match self {
    ViewLinesPart(part) => part.set_should_render(value)
    ViewZonesPart(part) => ViewPart::set_should_render(part, value)
    ContentViewOverlaysPart(part) => part.set_should_render(value)
    MarginViewOverlaysPart(part) => part.set_should_render(value)
    ContentWidgetsPart(part) => part.set_should_render(value)
    OverlayWidgetsPart(part) => part.set_should_render(value)
    EditorScrollbarPart(part) => part.set_should_render(value)
  }
}

///|
impl ViewPart for ViewPartHandle with fn on_before_render(self, viewport) {
  match self {
    ViewLinesPart(part) => part.on_before_render(viewport)
    ViewZonesPart(part) => ViewPart::on_before_render(part, viewport)
    ContentViewOverlaysPart(part) => part.on_before_render(viewport)
    MarginViewOverlaysPart(part) => part.on_before_render(viewport)
    ContentWidgetsPart(part) => part.on_before_render(viewport)
    OverlayWidgetsPart(part) => part.on_before_render(viewport)
    EditorScrollbarPart(part) => part.on_before_render(viewport)
  }
}

///|
impl ViewPart for ViewPartHandle with fn prepare_render(self, context) {
  match self {
    ViewLinesPart(part) => part.prepare_render(context)
    ViewZonesPart(part) => ViewPart::prepare_render(part, context)
    ContentViewOverlaysPart(part) => part.prepare_render(context)
    MarginViewOverlaysPart(part) => part.prepare_render(context)
    ContentWidgetsPart(part) => part.prepare_render(context)
    OverlayWidgetsPart(part) => part.prepare_render(context)
    EditorScrollbarPart(part) => part.prepare_render(context)
  }
}

///|
impl ViewPart for ViewPartHandle with fn render(self, context) {
  match self {
    ViewLinesPart(part) => part.render(context)
    ViewZonesPart(part) => ViewPart::render(part, context)
    ContentViewOverlaysPart(part) => part.render(context)
    MarginViewOverlaysPart(part) => part.render(context)
    ContentWidgetsPart(part) => part.render(context)
    OverlayWidgetsPart(part) => part.render(context)
    EditorScrollbarPart(part) => part.render(context)
  }
}

///|
impl ViewPart for ViewPartHandle with fn on_did_render(self) {
  match self {
    ViewLinesPart(part) => part.on_did_render()
    ViewZonesPart(part) => ViewPart::on_did_render(part)
    ContentViewOverlaysPart(part) => part.on_did_render()
    MarginViewOverlaysPart(part) => part.on_did_render()
    ContentWidgetsPart(part) => part.on_did_render()
    OverlayWidgetsPart(part) => part.on_did_render()
    EditorScrollbarPart(part) => part.on_did_render()
  }
}

// `ViewPart` impl for `@view_zones.ViewZones` (`browser/view_parts/view_zones`).
// Kept here, not in that package, per the cycle-backlog fix: MoonBit's orphan
// rule lets the trait-owning package implement a trait for a foreign type,
// and `view_part.mbt` needs `ViewZones` as a concrete type anyway (the
// `ViewPartHandle` enum above), so this keeps `browser/view_parts/view_zones`
// from needing an import back into `browser/view/`.

///|
impl ViewPart for @view_zones.ViewZones with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for @view_zones.ViewZones with fn on_view_event(_self, event) {
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
impl ViewPart for @view_zones.ViewZones with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for @view_zones.ViewZones with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
impl ViewPart for @view_zones.ViewZones with fn prepare_render(self, context) {
  self.prepared = Some({
    zones: context.input.browser_view_zones,
    viewport: context.viewport,
  })
}

///|
impl ViewPart for @view_zones.ViewZones with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_view_zones(prepared.zones, prepared.viewport)
      self.view_zones.set_attribute("style", context.content_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for @view_zones.ViewZones with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}
