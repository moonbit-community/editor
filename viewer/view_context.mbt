///|
/// Shared browser render state passed to view parts during one coordinated
/// render. It exposes only the explicit capabilities parts need; the public
/// facade remains `Viewer` and browser DOM ownership stays on each part.
priv struct ViewContext {
  root : @rdom.Element
  languages : @languages.Languages
  handle_hover_mousedown : (@rdom.Event, @rdom.MouseEvent) -> Unit
  handle_hover_keydown : (HoverWidgetDom, @rdom.Event, @rdom.KeyboardEvent) -> Unit
  // The pointer is over the hover widget: keep the hover open and drop any
  // pending hide (Monaco's `_shouldKeepCurrentHover` over the content widget).
  keep_hover_open : () -> Unit
  hook_scrollable_scrollbar_input : (
    @scrollbar.ScrollableElementDom,
    @scrollbar.ScrollableElementOwner,
  ) -> Unit
  // Monaco's `RenderingContext.linesVisibleRangesForRange` seam: measures the
  // pixel rects of a zero-based view-column range on a view line off the live
  // line DOM, which the selection overlay renders after `ViewLines` writes.
  measure_line_selection : (Int, Int, Int) -> Array[(Double, Double)]
}

///|
fn ViewContext::new(viewer : Viewer, view : View) -> ViewContext {
  {
    root: view.root,
    languages: viewer.services.languages,
    handle_hover_mousedown: (event, mouse) => {
      match viewer.mouse_handler {
        Some(handler) => handler.handle_mouse_down(event, mouse)
        None => ()
      }
    },
    handle_hover_keydown: (widget, event, keyboard) => {
      viewer.handle_hover_keydown(widget, event, keyboard)
    },
    keep_hover_open: () => viewer.keep_hover_open(),
    hook_scrollable_scrollbar_input: (scrollable, owner) => {
      match viewer.mouse_handler {
        Some(handler) =>
          handler.hook_scrollable_scrollbar_input(scrollable, owner)
        None => ()
      }
    },
    measure_line_selection: (line_number, start_column, end_column) => {
      view.measure_line_selection(line_number, start_column, end_column)
    },
  }
}
