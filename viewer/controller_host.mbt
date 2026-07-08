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
    hit_test: (x, y) => self.hit_test_at(x, y),
    refine_content_target: (client_x, client_y, fallback) => {
      self.dom_refine_content_target(view, client_x, client_y, fallback)
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
    // `ViewController.emitMouseDown/Up` land on the public `onMouseDown`/
    // `onMouseUp` events (`mouse_events.mbt`); the seams only fire for the
    // left button, so `left_button` is constantly true here.
    notify_mouse_down: target => {
      self.did_mouse_down.fire({ target, left_button: true })
    },
    notify_mouse_up: target => {
      self.did_mouse_up.fire({ target, left_button: true })
    },
    schedule_render: () => self.schedule_render(),
  }
}

///|
/// Hit-tests view-relative coordinates against the rendered view model —
/// the `MouseTargetFactory.createMouseTarget` seam the pointer handler calls
/// back into. `None` when no model is rendered. Before the first flush the
/// rendered window is not yet fixed; the layout's visible window stands in.
fn Viewer::hit_test_at(
  self : Viewer,
  x : Double,
  y : Double,
) -> @viewer_common.MouseTarget? {
  match self.view_model {
    Some(view_model) => {
      let window = match self.rendered_window {
        Some(window) => window
        None => view_model.clamp_window(self.view_layout.visible_window())
      }
      Some(
        @viewer_common.hit_test(
          view_model,
          window,
          self.view_metrics(view_model.line_count()),
          x,
          y,
        ),
      )
    }
    None => None
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
