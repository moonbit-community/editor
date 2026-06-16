///|
priv struct OverlayWidgetSlots {
  overlay_widgets : @rdom.Element
  overflowing_overlay_widgets : @rdom.Element
}

///|
fn create_overlay_widget_slots(document : @rdom.Document) -> OverlayWidgetSlots {
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
  { overlay_widgets, overflowing_overlay_widgets }
}
