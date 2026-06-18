///|
/// Shared browser render state passed to view parts during one coordinated
/// render. It exposes only the explicit capabilities parts need; the public
/// facade remains `Viewer` and browser DOM ownership stays on each part.
priv struct ViewContext {
  root : @rdom.Element
  handle_hover_mousedown : (@rdom.Event, @rdom.MouseEvent) -> Unit
  handle_hover_keydown : (HoverWidgetDom, @rdom.Event, @rdom.KeyboardEvent) -> Unit
  hook_scrollable_scrollbar_input : (
    ScrollableElementDom,
    ScrollableElementOwner,
  ) -> Unit
}

///|
fn ViewContext::new(viewer : Viewer, view : View) -> ViewContext {
  {
    root: view.root,
    handle_hover_mousedown: (event, mouse) => {
      viewer.handle_mouse_down(view, event, mouse)
    },
    handle_hover_keydown: (widget, event, keyboard) => {
      viewer.handle_hover_keydown(widget, event, keyboard)
    },
    hook_scrollable_scrollbar_input: (scrollable, owner) => {
      viewer.hook_scrollable_scrollbar_input(scrollable, owner)
    },
  }
}
