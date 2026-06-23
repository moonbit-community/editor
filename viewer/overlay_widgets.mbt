///|
priv struct OverlayWidgets {
  overlay_widgets : @rdom.Element
  overflowing_overlay_widgets : @rdom.Element
  mut should_render : Bool
}

///|
fn OverlayWidgets::new(document : @rdom.Document) -> OverlayWidgets {
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
fn OverlayWidgets::dom(self : OverlayWidgets) -> @rdom.Element {
  self.overlay_widgets
}

///|
fn OverlayWidgets::overflowing_dom(self : OverlayWidgets) -> @rdom.Element {
  self.overflowing_overlay_widgets
}

///|
impl ViewPart for OverlayWidgets with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for OverlayWidgets with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewScrollChanged(e) => e.dimensions_changed
    _ => false
  }
}

///|
impl ViewPart for OverlayWidgets with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for OverlayWidgets with fn on_before_render(_self, _viewport) {
  ()
}

///|
impl ViewPart for OverlayWidgets with fn prepare_render(_self, _context) {
  ()
}

///|
impl ViewPart for OverlayWidgets with fn render(_self, _context) {
  ()
}

///|
impl ViewPart for OverlayWidgets with fn on_did_render(self) {
  self.should_render = false
}
