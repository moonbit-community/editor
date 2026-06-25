///|
/// Hooks the view's native pointer listeners. Copy and hover-relevant
/// mouseleave stay on the viewer; all pointer input (mouse-select, scrollbar,
/// wheel, drag-autoscroll, browser-reveal) is delegated to the
/// `viewer/controller` `MouseHandler`, which the viewer builds here with a
/// `PointerHandlerHelper` closing over the view — the local analog of Monaco's
/// `View._createPointerHandlerHelper`.
fn Viewer::hook_view_input(self : Viewer, view : View) -> Unit {
  let handler = @controller.MouseHandler::new(self.pointer_handler_helper(view))
  self.mouse_handler = Some(handler)
  view.root.add_event_listener("mousemove", event => {
    match event.to_mouse_event() {
      Some(mouse) => handler.handle_mouse_move(mouse)
      None => ()
    }
  })
  view.root.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => handler.handle_mouse_down(event, mouse)
      None => ()
    }
  })
  view.view_lines
  .dom()
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => handler.handle_mouse_down(event, mouse)
      None => ()
    }
  })
  view.root.add_event_listener("copy", event => {
    if self.handle_copy_event(event) {
      event.prevent_default()
      event.stop_propagation()
    }
  })
  view.root.add_event_listener("mouseleave", _ => {
    self.dispatch_editor_event(MouseLeft)
  })
  view.overflow_guard.add_event_listener("wheel", event => {
    match event.to_wheel_event() {
      Some(wheel) => {
        event.prevent_default()
        event.stop_propagation()
        handler.handle_editor_wheel(wheel)
      }
      None => ()
    }
  })
  handler.hook_scrollable_scrollbar_input(
    view.editor_scrollbar.scrollable(),
    @scrollbar.EditorScrollableElement,
  )
  handler.hook_browser_desperate_reveal()
  let document = @rdom.document()
  document.add_event_listener("mousemove", event => {
    handler.handle_scrollable_drag_move(event)
    handler.handle_selection_drag_move(event)
  })
  document.add_event_listener("mouseup", _ => {
    handler.end_scrollable_drag()
    handler.finish_selection()
  })
}

///|
/// Read phase of the render loop: the view box, the glyph probe, and
/// the derived gutter width feed the layout model and every later hit
/// test. DOM scroll offsets are treated only as browser reveal deltas;
/// `ViewLayout` owns the editor scroll truth.
fn Viewer::measure(self : Viewer, view : View) -> Unit {
  let rect = view.root.get_bounding_client_rect()
  let probe_width = view.probe.get_bounding_client_rect().get_width()
  if probe_width > 0.0 {
    self.char_width = probe_width / char_probe_text.length().to_double()
  }
  let gutter_width = match self.frame {
    Some(frame) => self.gutter_width(frame)
    None => 0.0
  }
  let content_width = rect.get_width() - gutter_width
  self.layout.set_viewport_size(
    width=if content_width > 0.0 { content_width } else { 0.0 },
    height=rect.get_height(),
  )
  |> ignore
  let next_wrap_column = self.options.soft_wrap_column_for_content_width(
    content_width,
    self.measured_char_width(),
  )
  if next_wrap_column != self.soft_wrap_column {
    self.soft_wrap_column = next_wrap_column
    self.rebuild_current_view_model_for_options()
  } else {
    self.sync_content_width()
  }
}

///|
fn Viewer::sync_content_width(self : Viewer) -> Unit {
  let content_width = if self.options.soft_wrap && self.soft_wrap_column > 0 {
    self.layout.dimensions().width
  } else {
    self.max_line_length.to_double() * self.measured_char_width() +
    code_right_padding
  }
  self.layout.set_content_width(content_width) |> ignore
}

///|
fn Viewer::measured_char_width(self : Viewer) -> Double {
  if self.char_width > 0.0 {
    self.char_width
  } else {
    fallback_char_width
  }
}

///|
/// The margin width: digit slots (at least the old `min-width: 5ch`)
/// plus the gutter padding, in measured glyph advances.
fn Viewer::gutter_width(
  self : Viewer,
  frame : @view_model.RenderFrame,
) -> Double {
  let digits = frame.line_count.to_string().length()
  let slots = if digits > gutter_min_digits {
    digits
  } else {
    gutter_min_digits
  }
  slots.to_double() * self.measured_char_width() + gutter_padding_px.to_double()
}

///|
/// Builds the hit-test geometry for the current frame from the layout
/// model, falling back to font constants before the first measurement.
fn Viewer::view_metrics(
  self : Viewer,
  frame : @view_model.RenderFrame,
) -> @viewer_common.ViewMetrics {
  {
    origin_x: 0.0,
    origin_y: 0.0,
    scroll_top: self.layout.position().scroll_top,
    scroll_left: self.layout.position().scroll_left,
    viewport_height: self.layout.dimensions().height,
    line_height: editor_line_height,
    char_width: self.measured_char_width(),
    gutter_width: self.gutter_width(frame),
    view_zones: self.layout.view_zones(),
  }
}

///|
/// The span the target falls in, as absolute document offsets. The span's view
/// columns are resolved to model offsets through `view_to_model_offset` (the
/// `CoordinatesConverter` + model snapshot boundary), the way Monaco maps a
/// `MouseTarget`'s view position to the model — not via a render-line offset
/// helper.
fn span_anchor_for_target(
  frame : @view_model.RenderFrame,
  target : @viewer_common.MouseTarget,
  view_to_model_offset : (@base_common.Position) -> Int,
) -> (Int, Int, @view_model.RenderSpan)? {
  if target.span_index < 0 {
    return None
  }
  let index = target.line_number - 1 - frame.viewport.start_line
  if index < 0 || index >= frame.lines.length() {
    return None
  }
  let line = frame.lines[index]
  if target.span_index >= line.spans.length() {
    return None
  }
  let span = line.spans[target.span_index]
  let view_line = target.line_number - 1
  let start = view_to_model_offset(
    @base_common.Position::Position(view_line, span.start),
  )
  let end = view_to_model_offset(
    @base_common.Position::Position(view_line, span.end),
  )
  Some((start, end, span))
}
