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
      Some(mouse) => {
        // Record the pointer position + modifiers for the hover controller before
        // the hit test, then drive selection (which notifies the hover move).
        self.record_hover_pointer(
          mouse.get_client_x().to_double(),
          mouse.get_client_y().to_double(),
          mouse_modifiers(mouse),
        )
        handler.handle_mouse_move(mouse)
      }
      None => ()
    }
  })
  view.root.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        self.on_editor_mouse_down(
          mouse.get_client_x().to_double(),
          mouse.get_client_y().to_double(),
        )
        handler.handle_mouse_down(event, mouse)
      }
      None => ()
    }
  })
  view.view_lines
  .dom()
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        self.on_editor_mouse_down(
          mouse.get_client_x().to_double(),
          mouse.get_client_y().to_double(),
        )
        handler.handle_mouse_down(event, mouse)
      }
      None => ()
    }
  })
  view.root.add_event_listener("copy", event => {
    if self.handle_copy_event(event) {
      event.prevent_default()
      event.stop_propagation()
    }
  })
  view.root.add_event_listener("mouseleave", event => {
    let (posx, posy) = match event.to_mouse_event() {
      Some(mouse) =>
        (mouse.get_client_x().to_double(), mouse.get_client_y().to_double())
      None => (-1.0, -1.0)
    }
    self.on_editor_mouse_leave(posx, posy)
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
    EditorScrollableElement,
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
/// The pointer-event modifier flags the hover controller reads (`event.ctrlKey` /
/// `metaKey` / `altKey`), following the local-extern pattern already used for
/// `shiftKey` in `viewer/controller`.
fn mouse_modifiers(mouse : @rdom.MouseEvent) -> EventModifiers {
  {
    ctrl: mouse_ctrl_key(mouse),
    meta: mouse_meta_key(mouse),
    alt: mouse_alt_key(mouse),
  }
}

///|
extern "js" fn mouse_ctrl_key(mouse : @rdom.MouseEvent) -> Bool = "(m) => !!m.ctrlKey"

///|
extern "js" fn mouse_meta_key(mouse : @rdom.MouseEvent) -> Bool = "(m) => !!m.metaKey"

///|
extern "js" fn mouse_alt_key(mouse : @rdom.MouseEvent) -> Bool = "(m) => !!m.altKey"

///|
/// Read phase of the render loop: the view box, the glyph probe, and
/// the derived gutter width feed the layout model and every later hit
/// test. DOM scroll offsets are treated only as browser reveal deltas;
/// `ViewLayout` owns the editor scroll truth.
fn Viewer::measure(self : Viewer, view : View) -> Unit {
  let rect = view.root.get_bounding_client_rect()
  let probe_width = view.probe.get_bounding_client_rect().get_width()
  if probe_width > 0.0 {
    self.char_width = probe_width / @core.char_probe_text.length().to_double()
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
    @core.code_right_padding
  }
  self.layout.set_content_width(content_width) |> ignore
}

///|
fn Viewer::measured_char_width(self : Viewer) -> Double {
  if self.char_width > 0.0 {
    self.char_width
  } else {
    @core.fallback_char_width
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
  let slots = if digits > @core.gutter_min_digits {
    digits
  } else {
    @core.gutter_min_digits
  }
  slots.to_double() * self.measured_char_width() +
  @core.gutter_padding_px.to_double()
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
    line_height: @core.editor_line_height,
    char_width: self.measured_char_width(),
    gutter_width: self.gutter_width(frame),
    view_zones: self.layout.view_zones(),
  }
}

///|
/// The token the target falls in, as `(start, end, injected_text_index)` in
/// absolute document offsets. The token's view columns are resolved to model
/// offsets through `view_to_model_offset` (the `CoordinatesConverter` + model
/// snapshot boundary), the way Monaco maps a `MouseTarget`'s view position to
/// the model — not via a render-line offset helper.
fn token_anchor_for_target(
  frame : @view_model.RenderFrame,
  target : @viewer_common.MouseTarget,
  view_to_model_offset : (@base_common.Position) -> Int,
) -> (Int, Int, Int)? {
  if target.token_index < 0 {
    return None
  }
  let index = target.line_number - frame.viewport.start_line
  if index < 0 || index >= frame.lines.length() {
    return None
  }
  let line = frame.lines[index]
  let tokens = line.tokens
  if target.token_index >= tokens.get_count() {
    return None
  }
  // The token's view columns: `IViewLineTokens` exposes end offsets, so the
  // start is the previous token's end (or 0 for the first token).
  let token_start = if target.token_index > 0 {
    tokens.get_end_offset(target.token_index - 1)
  } else {
    0
  }
  let token_end = tokens.get_end_offset(target.token_index)
  // `target.line_number` is the 1-based view line; token columns are 0-based, so
  // shift them to 1-based `Position` columns.
  let view_line = target.line_number
  let start = view_to_model_offset(Position(view_line, token_start + 1))
  let end = view_to_model_offset(Position(view_line, token_end + 1))
  Some((start, end, target.injected_text_index))
}
