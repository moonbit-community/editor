// Ported from `vscode/src/vs/editor/browser/viewParts/overlayWidgets/overlayWidgets.ts`.
// The port carries the DOM shell plus the null-position widget registry
// (`addWidget`/`removeWidget` for widgets whose `getPosition()` is `null` —
// they position themselves, so `render`/`prepare_render` stay no-ops; the
// preference-position placement Monaco layers on top has no consumer yet).
// The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, not
// here — see the exec-plan's cycle backlog and
// `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` directly.
pub(all) struct OverlayWidgets {
  dom_node : @rdom.Element
  overflowing_overlay_widgets_dom_node : @rdom.Element
  widgets : Map[String, @rdom.Element]
  mut should_render : Bool
}

///|
pub fn OverlayWidgets::new(document : @rdom.Document) -> OverlayWidgets {
  let dom_node = document.create_element("div")
  dom_node.set_attribute("class", "overlayWidgets")
  dom_node.set_attribute("data-view-part", "overlayWidgets")
  let overflowing_overlay_widgets_dom_node = document.create_element("div")
  overflowing_overlay_widgets_dom_node.set_attribute(
    "class", "overflowingOverlayWidgets",
  )
  overflowing_overlay_widgets_dom_node.set_attribute(
    "data-view-part", "overflowingOverlayWidgets",
  )
  {
    dom_node,
    overflowing_overlay_widgets_dom_node,
    widgets: {},
    should_render: true,
  }
}

///|
/// `OverlayWidgets.addWidget` for a null-position widget: mounts the node in
/// the viewport-fixed `.overlayWidgets` container. Re-adding an id replaces
/// the previous node. The container is `pointer-events: none`; interactive
/// widgets set `pointer-events: auto` on their own node.
pub fn OverlayWidgets::add_widget(
  self : OverlayWidgets,
  widget_id : String,
  node : @rdom.Element,
) -> Unit {
  self.remove_widget(widget_id)
  node.set_attribute("data-overlay-widget-id", widget_id)
  self.dom_node.append_child(node.as_node())
  self.widgets.set(widget_id, node)
}

///|
/// `OverlayWidgets.removeWidget`: unmounts the widget's node. Unknown ids are
/// ignored.
pub fn OverlayWidgets::remove_widget(
  self : OverlayWidgets,
  widget_id : String,
) -> Unit {
  match self.widgets.get(widget_id) {
    Some(node) => {
      self.dom_node.remove_child(node.as_node())
      self.widgets.remove(widget_id)
    }
    None => ()
  }
}

///|
pub fn OverlayWidgets::get_dom_node(self : OverlayWidgets) -> @rdom.Element {
  self.dom_node
}

///|
pub fn OverlayWidgets::overflowing_overlay_widgets_dom_node(
  self : OverlayWidgets,
) -> @rdom.Element {
  self.overflowing_overlay_widgets_dom_node
}
