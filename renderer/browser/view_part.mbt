///|
/// Private Monaco-shaped render lifecycle for browser view concerns.
priv trait ViewPart {
  fn should_render(Self, RenderingContext) -> Bool
  fn set_should_render(Self, Bool) -> Unit
  fn on_before_render(Self, @view_layout.ViewportData) -> Unit
  fn prepare_render(Self, RenderingContext) -> Unit
  fn render(Self, RestrictedRenderingContext) -> Unit
  fn on_did_render(Self) -> Unit
}

///|
priv enum ViewPartHandle {
  ViewLinesPart(ViewLines)
  ViewZonesPart(ViewZones)
  ContentViewOverlaysPart(ContentViewOverlays)
  MarginViewOverlaysPart(MarginViewOverlays)
  ContentWidgetsPart(ContentWidgets)
  OverlayWidgetsPart(OverlayWidgets)
  EditorScrollbarPart(EditorScrollbar)
}

///|
fn default_view_parts(
  view_lines : ViewLines,
  view_zones : ViewZones,
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
impl ViewPart for ViewPartHandle with fn should_render(self, context) {
  match self {
    ViewLinesPart(part) => part.should_render(context)
    ViewZonesPart(part) => part.should_render(context)
    ContentViewOverlaysPart(part) => part.should_render(context)
    MarginViewOverlaysPart(part) => part.should_render(context)
    ContentWidgetsPart(part) => part.should_render(context)
    OverlayWidgetsPart(part) => part.should_render(context)
    EditorScrollbarPart(part) => part.should_render(context)
  }
}

///|
impl ViewPart for ViewPartHandle with fn set_should_render(self, value) {
  match self {
    ViewLinesPart(part) => part.set_should_render(value)
    ViewZonesPart(part) => part.set_should_render(value)
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
    ViewZonesPart(part) => part.on_before_render(viewport)
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
    ViewZonesPart(part) => part.prepare_render(context)
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
    ViewZonesPart(part) => part.render(context)
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
    ViewZonesPart(part) => part.on_did_render()
    ContentViewOverlaysPart(part) => part.on_did_render()
    MarginViewOverlaysPart(part) => part.on_did_render()
    ContentWidgetsPart(part) => part.on_did_render()
    OverlayWidgetsPart(part) => part.on_did_render()
    EditorScrollbarPart(part) => part.on_did_render()
  }
}
