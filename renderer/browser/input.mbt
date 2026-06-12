///|
/// An active scrollbar thumb drag: the slider position captured at drag
/// start plus the pointer travel decides the scroll position, like the
/// reference.
priv struct ScrollbarDrag {
  vertical : Bool
  start_coord : Double
  start_slider : Double
}

///|
/// Hooks the island's native listeners: one container handler set on the
/// island root replaces per-span closures (update resolves targets
/// through `hit_test`), the wheel listener owns scrolling (the island
/// always consumes wheel events), and the scrollbar parts implement
/// thumb drags and track page jumps. Document-level move/up listeners
/// are installed once and guarded by the drag state.
fn Viewer::hook_island_input(self : Viewer, island : Island) -> Unit {
  island.root.add_event_listener("mousemove", event => {
    match event.to_mouse_event() {
      Some(mouse) => self.handle_mouse_move(island, mouse)
      None => ()
    }
  })
  island.root.add_event_listener("mouseleave", _ => {
    self.dispatch_editor_event(MouseLeft)
  })
  island.root.add_event_listener("wheel", event => {
    match event.to_wheel_event() {
      Some(wheel) => {
        event.prevent_default()
        self.handle_wheel(wheel)
      }
      None => ()
    }
  })
  island.vertical_slider.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.start_scrollbar_drag(island, vertical=true, mouse)
      }
      None => ()
    }
  })
  island.horizontal_slider.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.start_scrollbar_drag(island, vertical=false, mouse)
      }
      None => ()
    }
  })
  island.vertical_bar.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        self.scrollbar_track_jump(island, vertical=true, mouse)
      }
      None => ()
    }
  })
  island.horizontal_bar.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        self.scrollbar_track_jump(island, vertical=false, mouse)
      }
      None => ()
    }
  })
  let document = @rdom.document()
  document.add_event_listener("mousemove", event => {
    self.handle_drag_move(island, event)
  })
  document.add_event_listener("mouseup", _ => self.drag = None)
}

///|
/// Converts a container mouse event into island-relative coordinates
/// using the island root, so hit-testing is independent of page layout.
fn Viewer::handle_mouse_move(
  self : Viewer,
  island : Island,
  mouse : @rdom.MouseEvent,
) -> Unit {
  guard self.frame is Some(frame) else { return }
  let rect = island.root.get_bounding_client_rect()
  let x = mouse.get_client_x().to_double() - rect.get_left()
  let y = mouse.get_client_y().to_double() - rect.get_top()
  let target = @renderer.hit_test(frame, self.view_metrics(frame), x, y)
  self.dispatch_editor_event(MouseMoved(target))
}

///|
/// Simplified wheel delta normalization: line and page delta modes scale
/// to pixels; pixel deltas pass through.
fn Viewer::handle_wheel(self : Viewer, wheel : @rdom.WheelEvent) -> Unit {
  let scale = match wheel.get_delta_mode() {
    1 => editor_line_height.to_double()
    2 => self.layout.dimensions().height
    _ => 1.0
  }
  self.apply_scroll_change(
    self.layout.scroll_by(
      delta_left=wheel.get_delta_x() * scale,
      delta_top=wheel.get_delta_y() * scale,
    ),
  )
}

///|
fn Viewer::start_scrollbar_drag(
  self : Viewer,
  island : Island,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Unit {
  let state = if vertical {
    island.vertical_state
  } else {
    island.horizontal_state
  }
  self.drag = Some({
    vertical,
    start_coord: drag_coord(mouse, vertical),
    start_slider: state.slider_position(),
  })
}

///|
fn Viewer::handle_drag_move(
  self : Viewer,
  island : Island,
  event : @rdom.Event,
) -> Unit {
  guard self.drag is Some(drag) else { return }
  guard event.to_mouse_event() is Some(mouse) else { return }
  event.prevent_default()
  let delta = drag_coord(mouse, drag.vertical) - drag.start_coord
  if drag.vertical {
    let desired = island.vertical_state.desired_position_from_slider(
      drag.start_slider + delta,
    )
    self.apply_scroll_change(self.layout.scroll_to(scroll_top=desired))
  } else {
    let desired = island.horizontal_state.desired_position_from_slider(
      drag.start_slider + delta,
    )
    let position = self.layout.position()
    self.apply_scroll_change(
      self.layout.scroll_to(scroll_top=position.scroll_top, scroll_left=desired),
    )
  }
}

///|
/// A mousedown on the track (outside the thumb, which stops propagation)
/// pages towards the clicked side.
fn Viewer::scrollbar_track_jump(
  self : Viewer,
  island : Island,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Unit {
  if vertical {
    let rect = island.vertical_bar.get_bounding_client_rect()
    let offset = mouse.get_client_y().to_double() - rect.get_top()
    let desired = island.vertical_state.desired_position_from_offset_paged(
      offset,
    )
    self.apply_scroll_change(self.layout.scroll_to(scroll_top=desired))
  } else {
    let rect = island.horizontal_bar.get_bounding_client_rect()
    let offset = mouse.get_client_x().to_double() - rect.get_left()
    let desired = island.horizontal_state.desired_position_from_offset_paged(
      offset,
    )
    let position = self.layout.position()
    self.apply_scroll_change(
      self.layout.scroll_to(scroll_top=position.scroll_top, scroll_left=desired),
    )
  }
}

///|
fn drag_coord(mouse : @rdom.MouseEvent, vertical : Bool) -> Double {
  if vertical {
    mouse.get_client_y().to_double()
  } else {
    mouse.get_client_x().to_double()
  }
}

///|
/// Read phase of the render loop: the island box, the glyph probe, and
/// the derived gutter width feed the layout model and every later hit
/// test. No DOM scroll reads — the layout owns scroll truth.
fn Viewer::measure(self : Viewer, island : Island) -> Unit {
  let rect = island.root.get_bounding_client_rect()
  let probe_width = island.probe.get_bounding_client_rect().get_width()
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
  self.sync_content_width()
}

///|
fn Viewer::sync_content_width(self : Viewer) -> Unit {
  self.layout.set_content_width(
    self.max_line_length.to_double() * self.measured_char_width() +
    code_right_padding,
  )
  |> ignore
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
fn Viewer::gutter_width(self : Viewer, frame : @renderer.RenderFrame) -> Double {
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
  frame : @renderer.RenderFrame,
) -> @renderer.ViewMetrics {
  {
    origin_x: 0.0,
    origin_y: 0.0,
    scroll_top: self.layout.position().scroll_top,
    viewport_height: self.layout.dimensions().height,
    line_height: editor_line_height,
    char_width: self.measured_char_width(),
    gutter_width: self.gutter_width(frame),
    view_zones: [],
  }
}

///|
/// The span the target falls in, as absolute document offsets. Mirrors
/// the anchors the old per-span handlers produced.
fn span_anchor_for_target(
  frame : @renderer.RenderFrame,
  target : @renderer.MouseTarget,
) -> (Int, Int, @renderer.RenderSpan)? {
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
  Some((line.offset + span.start, line.offset + span.end, span))
}
