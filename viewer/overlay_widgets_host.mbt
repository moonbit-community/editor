// The viewer core's side of the `viewer/browser/view_parts/overlay_widgets`
// seam: the public overlay-widget API. Kept here per the foreign-method rule
// (every `Viewer::` method lives in `Viewer`'s own package).

///|
/// Adds a null-position overlay widget — Monaco's
/// `ICodeEditor.addOverlayWidget` collapsed to `(id, dom_node)` because the
/// viewer's only consumers are widgets whose `getPosition()` returns `null`
/// (they position themselves; zone widgets ride `IViewZone.onDomNodeTop`).
/// Re-adding an id replaces the previous node — Monaco's `layoutOverlayWidget`
/// re-add semantics. No view attached → no-op.
pub fn Viewer::add_overlay_widget(
  self : Viewer,
  widget_id : String,
  node : @rdom.Element,
) -> Unit {
  match self.view {
    Some(view) => view.overlay_widgets.add_widget(widget_id, node)
    None => ()
  }
}

///|
/// Removes an overlay widget by id — Monaco's
/// `ICodeEditor.removeOverlayWidget`. Unknown ids and a missing view are
/// no-ops.
pub fn Viewer::remove_overlay_widget(self : Viewer, widget_id : String) -> Unit {
  match self.view {
    Some(view) => view.overlay_widgets.remove_widget(widget_id)
    None => ()
  }
}
