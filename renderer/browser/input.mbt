///|
/// Hooks the island's native listeners: one container handler set on the
/// island root replaces per-span closures (update resolves targets
/// through `hit_test`), the editor scrollable element owns wheel and
/// scrollbar input, and document-level move/up listeners are installed
/// once and guarded by the drag state.
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
  island.overflow_guard.add_event_listener("wheel", event => {
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
    island.editor_scrollable,
    EditorScrollableElement,
  )
  self.hook_browser_desperate_reveal(island)
  let document = @rdom.document()
  document.add_event_listener("mousemove", event => {
    self.handle_scrollable_drag_move(island, event)
  })
  document.add_event_listener("mouseup", _ => self.drag = None)
}

///|
fn Viewer::hook_scrollable_scrollbar_input(
  self : Viewer,
  scrollable : ScrollableElementDom,
  owner : ScrollableElementOwner,
) -> Unit {
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
  self.drag = Some({
    owner,
    vertical,
    start_coord: drag_coord(mouse, vertical),
    start_slider: scrollable.state(vertical).slider_position(),
  })
}

///|
fn Viewer::handle_scrollable_drag_move(
  self : Viewer,
  island : Island,
  event : @rdom.Event,
) -> Unit {
  guard self.drag is Some(drag) else { return }
  guard event.to_mouse_event() is Some(mouse) else { return }
  event.prevent_default()
  let delta = drag_coord(mouse, drag.vertical) - drag.start_coord
  guard scrollable_for_drag(island, drag.owner) is Some(scrollable) else {
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
/// pages towards the clicked side.
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
  island : Island,
  owner : ScrollableElementOwner,
) -> ScrollableElementDom? {
  match owner {
    EditorScrollableElement => Some(island.editor_scrollable)
    HoverScrollableElement =>
      match island.hover_widget {
        Some(widget) => Some(widget.scrollable)
        None => None
      }
  }
}

///|
fn Viewer::hook_browser_desperate_reveal(
  self : Viewer,
  island : Island,
) -> Unit {
  island.root.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      island.root,
      look_at_scroll_top=true,
      look_at_scroll_left=true,
    )
  })
  island.overflow_guard.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      island.overflow_guard,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
  island.lines_content.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      island.lines_content,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
  island.editor_scrollable.wrapper.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      island.editor_scrollable.wrapper,
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
/// Read phase of the render loop: the island box, the glyph probe, and
/// the derived gutter width feed the layout model and every later hit
/// test. DOM scroll offsets are treated only as browser reveal deltas;
/// `ViewLayout` owns the editor scroll truth.
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
