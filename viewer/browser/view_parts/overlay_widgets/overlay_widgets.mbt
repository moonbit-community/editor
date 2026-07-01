// Ported from `vscode/src/vs/editor/browser/viewParts/overlayWidgets/overlayWidgets.ts`.
// The viewer has no overlay-widget content yet (no minimap, no find widget),
// so this port is just the DOM shell; render/prepare_render are no-ops. The
// `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, not
// here — see the exec-plan's cycle backlog and
// `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` directly.
pub(all) struct OverlayWidgets {
  overlay_widgets : @rdom.Element
  overflowing_overlay_widgets : @rdom.Element
  mut should_render : Bool
}

///|
pub fn OverlayWidgets::new(document : @rdom.Document) -> OverlayWidgets {
  let overlay_widgets = document.create_element("div")
  overlay_widgets.set_attribute("class", "overlayWidgets")
  overlay_widgets.set_attribute("data-view-part", "overlayWidgets")
  let overflowing_overlay_widgets = document.create_element("div")
  overflowing_overlay_widgets.set_attribute(
    "class", "overflowingOverlayWidgets",
  )
  overflowing_overlay_widgets.set_attribute(
    "data-view-part", "overflowingOverlayWidgets",
  )
  { overlay_widgets, overflowing_overlay_widgets, should_render: true }
}

///|
pub fn OverlayWidgets::dom(self : OverlayWidgets) -> @rdom.Element {
  self.overlay_widgets
}

///|
pub fn OverlayWidgets::overflowing_dom(self : OverlayWidgets) -> @rdom.Element {
  self.overflowing_overlay_widgets
}
