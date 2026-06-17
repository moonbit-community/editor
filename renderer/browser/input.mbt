///|
/// Hooks the view's native listeners: one container handler set on the
/// view root replaces per-span closures (update resolves targets
/// through `hit_test`), the editor scrollable element owns wheel and
/// scrollbar input, and document-level move/up listeners are installed
/// once and guarded by the drag state.
fn Viewer::hook_view_input(self : Viewer, view : View) -> Unit {
  view.root.add_event_listener("mousemove", event => {
    match event.to_mouse_event() {
      Some(mouse) => self.handle_mouse_move(view, mouse)
      None => ()
    }
  })
  view.root.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => self.handle_mouse_down(view, event, mouse)
      None => ()
    }
  })
  view.view_lines.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => self.handle_mouse_down(view, event, mouse)
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
        self.handle_editor_wheel(wheel)
      }
      None => ()
    }
  })
  self.hook_scrollable_scrollbar_input(
    view.editor_scrollable,
    EditorScrollableElement,
  )
  self.hook_browser_desperate_reveal(view)
  let document = @rdom.document()
  document.add_event_listener("mousemove", event => {
    self.handle_scrollable_drag_move(view, event)
    self.handle_selection_drag_move(view, event)
  })
  document.add_event_listener("mouseup", _ => {
    self.end_scrollable_drag(view)
    self.finish_selection()
  })
}

///|
fn Viewer::hook_scrollable_scrollbar_input(
  self : Viewer,
  scrollable : ScrollableElementDom,
  owner : ScrollableElementOwner,
) -> Unit {
  scrollable.wrapper.add_event_listener("mouseover", _ => {
    scrollable.mouse_entered()
  })
  scrollable.wrapper.add_event_listener("mousemove", _ => {
    scrollable.mouse_entered()
  })
  scrollable.wrapper.add_event_listener("mouseleave", _ => {
    scrollable.mouse_left()
  })
  scrollable
  .slider(true)
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.start_scrollable_drag(scrollable, owner, vertical=true, mouse)
      }
      None => ()
    }
  })
  scrollable
  .slider(false)
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.start_scrollable_drag(scrollable, owner, vertical=false, mouse)
      }
      None => ()
    }
  })
  scrollable
  .track(true)
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.scrollable_track_jump(scrollable, owner, vertical=true, mouse)
      }
      None => ()
    }
  })
  scrollable
  .track(false)
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.scrollable_track_jump(scrollable, owner, vertical=false, mouse)
      }
      None => ()
    }
  })
}

///|
/// Converts a container mouse event into view-relative coordinates
/// using the view root, so hit-testing is independent of page layout.
fn Viewer::handle_mouse_move(
  self : Viewer,
  view : View,
  mouse : @rdom.MouseEvent,
) -> Unit {
  guard self.frame is Some(frame) else { return }
  let rect = view.root.get_bounding_client_rect()
  let x = mouse.get_client_x().to_double() - rect.get_left()
  let y = mouse.get_client_y().to_double() - rect.get_top()
  let target = @renderer.hit_test(frame, self.view_metrics(frame), x, y)
  self.dispatch_editor_event(MouseMoved(target))
}

///|
fn Viewer::handle_mouse_down(
  self : Viewer,
  view : View,
  event : @rdom.Event,
  mouse : @rdom.MouseEvent,
) -> Unit {
  if mouse.get_button() != 0 {
    return
  }
  guard self.frame is Some(frame) else { return }
  focus_element(view.root)
  let rect = view.root.get_bounding_client_rect()
  let x = mouse.get_client_x().to_double() - rect.get_left()
  let y = mouse.get_client_y().to_double() - rect.get_top()
  let target = @renderer.hit_test(frame, self.view_metrics(frame), x, y)
  match target.kind {
    ContentText | ContentEmpty => {
      event.prevent_default()
      event.stop_propagation()
      self.begin_selection(target)
    }
    _ => ()
  }
}

///|
extern "js" fn focus_element(element : @rdom.Element) -> Unit = "(element) => element.focus?.()"

///|
fn Viewer::handle_selection_drag_move(
  self : Viewer,
  view : View,
  event : @rdom.Event,
) -> Unit {
  guard self.selection_dragging else { return }
  guard self.frame is Some(frame) else { return }
  guard event.to_mouse_event() is Some(mouse) else { return }
  event.prevent_default()
  let rect = view.root.get_bounding_client_rect()
  let x = mouse.get_client_x().to_double() - rect.get_left()
  let y = mouse.get_client_y().to_double() - rect.get_top()
  let target = @renderer.hit_test(frame, self.view_metrics(frame), x, y)
  self.update_selection(target)
}

///|
/// Wheel delta normalization is shared with widget scrollables: line and
/// page delta modes scale to pixels; pixel deltas pass through.
fn Viewer::handle_editor_wheel(self : Viewer, wheel : @rdom.WheelEvent) -> Unit {
  let (delta_left, delta_top) = normalized_wheel_delta(
    wheel,
    editor_line_height.to_double(),
    self.layout.dimensions().height,
  )
  self.apply_scroll_change(self.layout.scroll_by(delta_left~, delta_top~))
}

///|
fn Viewer::start_scrollable_drag(
  self : Viewer,
  scrollable : ScrollableElementDom,
  owner : ScrollableElementOwner,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Unit {
  scrollable.drag_started()
  self.drag = Some({
    owner,
    vertical,
    start_coord: drag_coord(mouse, vertical),
    start_slider: scrollable.state(vertical).slider_position(),
  })
  scrollable.set_slider_active(vertical~, true)
}

///|
fn Viewer::end_scrollable_drag(self : Viewer, view : View) -> Unit {
  match self.drag {
    Some(drag) =>
      match scrollable_for_drag(view, drag.owner) {
        Some(scrollable) => {
          scrollable.set_slider_active(vertical=drag.vertical, false)
          scrollable.drag_ended()
        }
        None => ()
      }
    None => ()
  }
  self.drag = None
}

///|
fn Viewer::handle_scrollable_drag_move(
  self : Viewer,
  view : View,
  event : @rdom.Event,
) -> Unit {
  guard self.drag is Some(drag) else { return }
  guard event.to_mouse_event() is Some(mouse) else { return }
  event.prevent_default()
  let delta = drag_coord(mouse, drag.vertical) - drag.start_coord
  guard scrollable_for_drag(view, drag.owner) is Some(scrollable) else {
    self.drag = None
    return
  }
  let desired = scrollable
    .state(drag.vertical)
    .desired_position_from_slider(drag.start_slider + delta)
  self.apply_scrollable_position(
    scrollable,
    drag.owner,
    vertical=drag.vertical,
    desired,
  )
}

///|
/// A mousedown on the track (outside the thumb, which stops propagation)
/// uses Monaco's editor default `scrollByPage: false`: jump so the thumb
/// centers on the pointer.
fn Viewer::scrollable_track_jump(
  self : Viewer,
  scrollable : ScrollableElementDom,
  owner : ScrollableElementOwner,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Unit {
  let desired = scrollable.desired_position_from_track(vertical~, mouse)
  self.apply_scrollable_position(scrollable, owner, vertical~, desired)
}

///|
fn Viewer::apply_scrollable_position(
  self : Viewer,
  scrollable : ScrollableElementDom,
  owner : ScrollableElementOwner,
  vertical~ : Bool,
  desired : Double,
) -> Unit {
  match owner {
    EditorScrollableElement =>
      if vertical {
        self.apply_scroll_change(self.layout.scroll_to(scroll_top=desired))
      } else {
        let position = self.layout.position()
        self.apply_scroll_change(
          self.layout.scroll_to(
            scroll_top=position.scroll_top,
            scroll_left=desired,
          ),
        )
      }
    HoverScrollableElement => scrollable.native_scroll_to(vertical~, desired)
  }
}

///|
fn scrollable_for_drag(
  view : View,
  owner : ScrollableElementOwner,
) -> ScrollableElementDom? {
  match owner {
    EditorScrollableElement => Some(view.editor_scrollable)
    HoverScrollableElement =>
      match view.hover_widget {
        Some(widget) => Some(widget.scrollable)
        None => None
      }
  }
}

///|
fn Viewer::hook_browser_desperate_reveal(self : Viewer, view : View) -> Unit {
  view.root.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      view.root,
      look_at_scroll_top=true,
      look_at_scroll_left=true,
    )
  })
  view.overflow_guard.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      view.overflow_guard,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
  view.lines_content.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      view.lines_content,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
  view.editor_scrollable.wrapper.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      view.editor_scrollable.wrapper,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
}

///|
/// Mirrors Monaco's editor scrollbar bridge for browser-driven reveal:
/// when focus or the browser mutates a DOM scroll offset, translate that
/// delta into the model and reset the DOM offset to zero.
fn Viewer::handle_browser_desperate_reveal(
  self : Viewer,
  element : @rdom.Element,
  look_at_scroll_top~ : Bool,
  look_at_scroll_left~ : Bool,
) -> Unit {
  let mut delta_top = 0.0
  let mut delta_left = 0.0
  if look_at_scroll_top {
    delta_top = element.get_scroll_top()
    if delta_top != 0.0 {
      element.set_scroll_top(0.0)
    }
  }
  if look_at_scroll_left {
    delta_left = element.get_scroll_left()
    if delta_left != 0.0 {
      element.set_scroll_left(0.0)
    }
  }
  if delta_top != 0.0 || delta_left != 0.0 {
    self.apply_scroll_change(self.layout.scroll_by(delta_left~, delta_top~))
  } else {
    ()
  }
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
) -> @renderer.ViewMetrics {
  {
    origin_x: 0.0,
    origin_y: 0.0,
    scroll_top: self.layout.position().scroll_top,
    viewport_height: self.layout.dimensions().height,
    line_height: editor_line_height,
    char_width: self.measured_char_width(),
    gutter_width: self.gutter_width(frame),
    view_zones: self.layout.view_zones(),
  }
}

///|
/// The span the target falls in, as absolute document offsets. Mirrors
/// the anchors the old per-span handlers produced.
fn span_anchor_for_target(
  frame : @view_model.RenderFrame,
  target : @renderer.MouseTarget,
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
  let line_start = line.model_line_start_offset()
  Some((line_start + span.source_start, line_start + span.source_end, span))
}
