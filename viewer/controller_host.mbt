// The viewer core's side of the `viewer/browser/controller` seam: it builds the input
// controller's `PointerHandlerHelper`, the local analog of Monaco's
// `View._createPointerHandlerHelper`. The closures capture the view and the
// viewer so the controller never names the concrete `View`/`Viewer`.

///|
fn Viewer::pointer_handler_helper(
  self : Viewer,
  view : @view.View,
) -> @controller.PointerHandlerHelper {
  {
    view_root: view.root,
    overflow_guard: view.overflow_guard,
    editor_scrollable: view.editor_scrollbar.scrollable(),
    hover_scrollable: () => view.content_widgets.hover_scrollable(),
    view_layout: () => self.view_layout,
    apply_scroll: change => self.apply_scroll_change(change),
    line_height: () => @core.editor_line_height.to_double(),
    frame: () => self.frame,
    view_metrics: frame => self.view_metrics(frame),
    refine_content_target: (frame, client_x, client_y, fallback) => {
      self.dom_refine_content_target(view, frame, client_x, client_y, fallback)
    },
    dispatch_mouse: payload => {
      self.dispatch_mouse({
        view_position: payload.view_position,
        in_selection_mode: payload.in_selection_mode,
        mouse_down_count: payload.mouse_down_count,
        started_on_line_numbers: payload.started_on_line_numbers,
      })
    },
    notify_mouse_moved: target => self.on_editor_mouse_move(target),
    schedule_render: () => self.schedule_render(),
  }
}

///|
/// Cancels an in-progress mouse selection on viewer lifecycle resets (model
/// change/clear). No-op before the view (and its controller) exist.
fn Viewer::cancel_mouse_selection(self : Viewer) -> Unit {
  match self.mouse_handler {
    Some(handler) => handler.cancel_selection()
    None => ()
  }
}
