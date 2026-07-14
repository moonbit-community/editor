// The viewer facade's public overlay-widget API delegates to
// `viewer/browser/view/overlay_widgets.mbt`. It lives here because every
// `Viewer::` method must be defined in `Viewer`'s package.

///|
/// Adds a null-position overlay widget — Monaco's
/// `ICodeEditor.addOverlayWidget` collapsed to `(id, dom_node)` because the
/// viewer's only consumers are widgets whose `getPosition()` returns `null`
/// (they position themselves; zone widgets ride `IViewZone.onDomNodeTop`).
/// Re-adding an id replaces the previous node — Monaco's `layoutOverlayWidget`
/// re-add semantics. The registration outlives any per-model view: the id →
/// node map is Monaco's `_overlayWidgets`, re-added to every new view
/// (`cew:1901-1905`).
pub fn Viewer::add_overlay_widget(
  self : Viewer,
  widget_id : String,
  node : @rdom.Element,
) -> Unit {
  self.overlay_widgets[widget_id] = node
  match self.get_view() {
    Some(view) => view.overlay_widgets.add_widget(widget_id, node)
    None => ()
  }
}

///|
/// Removes an overlay widget by id — Monaco's
/// `ICodeEditor.removeOverlayWidget`. Unknown ids and a missing view are
/// no-ops.
pub fn Viewer::remove_overlay_widget(self : Viewer, widget_id : String) -> Unit {
  self.overlay_widgets.remove(widget_id)
  match self.get_view() {
    Some(view) => view.overlay_widgets.remove_widget(widget_id)
    None => ()
  }
}
