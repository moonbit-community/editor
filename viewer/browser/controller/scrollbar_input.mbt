// The viewer's scrollbar pointer/scroll input cluster, moved verbatim out of
// `mouse_handler.mbt` at the mouse-subsystem cutover. This is a local
// aggregation of base-scrollbar pointer logic (Monaco spreads it across
// `scrollableElement.ts`/`abstractScrollbar.ts`); it has no single Monaco
// mirror file. It rides on `MouseHandler` for the shared helper and the
// active-drag slot.

///|
/// Wires one scrollable element's scrollbar interactions: reveal-on-hover and
/// thumb/track drags. Shared by the editor scrollbar and the hover widget
/// scrollbar (Monaco's `ScrollableElement` pointer handling).
pub fn MouseHandler::hook_scrollable_scrollbar_input(
  self : MouseHandler,
  scrollable : @scrollbar.ScrollableElementDom,
  owner : @scrollbar.ScrollableElementOwner,
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
/// The editor's `ScrollableElement._onMouseWheel`: normalize into wheel
/// units, classify the device, run the shared delta pipeline, target the
/// future position, and choose Monaco's physical-wheel smooth path or its
/// trackpad immediate path. Returns whether the browser event is consumed.
pub fn MouseHandler::handle_editor_wheel(
  self : MouseHandler,
  event : @rdom.Event,
  wheel : @rdom.WheelEvent,
) -> Bool {
  if wheel_event_default_prevented(event) {
    return false
  }
  guard (self.view_helper.view_layout)() is Some(view_layout) else {
    return false
  }
  let standard_event = @scrollbar.StandardWheelEvent::new(wheel)
  let classifier = @scrollbar.global_mouse_wheel_classifier()
  classifier.accept_standard_wheel_event(standard_event)
  let (delta_left, delta_top) = @scrollbar.mouse_wheel_scroll_deltas(
    standard_event,
    alt_key=wheel.get_alt_key(),
    shift_key=wheel.get_shift_key(),
  )
  let future = view_layout.future_position()
  let desired = if standard_event.delta_y != 0.0 ||
    standard_event.delta_x != 0.0 {
    view_layout.validate_scroll_position({
      scroll_left: if delta_left != 0.0 {
        Some(future.scroll_left + delta_left)
      } else {
        None
      },
      scroll_top: if delta_top != 0.0 {
        Some(future.scroll_top + delta_top)
      } else {
        None
      },
    })
  } else {
    future
  }
  let did_scroll = desired != future
  if did_scroll {
    let scrollable = view_layout.get_scrollable()
    let update : @view_layout.ScrollPositionUpdate = {
      scroll_left: Some(desired.scroll_left),
      scroll_top: Some(desired.scroll_top),
    }
    if classifier.is_physical_mouse_wheel() {
      scrollable.set_position_smooth(update)
    } else {
      scrollable.set_position_now(update) |> ignore
    }
  }
  // EditorOption.scrollbar.alwaysConsumeMouseWheel defaults to true; the
  // `consumeMouseWheelIfScrollbarIsNeeded` branch is therefore unreachable
  // under the viewer's fixed resolved editor-scrollbar options.
  let mut consume_mouse_wheel = did_scroll
  let always_consume_mouse_wheel = true
  if !consume_mouse_wheel && always_consume_mouse_wheel {
    consume_mouse_wheel = true
  }
  consume_mouse_wheel
}

///|
extern "js" fn wheel_event_default_prevented(event : @rdom.Event) -> Bool =
  #| (event) => event.defaultPrevented

///|
fn MouseHandler::start_scrollable_drag(
  self : MouseHandler,
  scrollable : @scrollbar.ScrollableElementDom,
  owner : @scrollbar.ScrollableElementOwner,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Unit {
  scrollable.drag_started()
  self.drag = Some({
    owner,
    vertical,
    start_coord: @scrollbar.drag_coord(mouse, vertical),
    start_slider: scrollable.state(vertical).slider_position(),
  })
  scrollable.set_slider_active(vertical~, true)
}

///|
/// Ends an in-progress thumb drag (document `mouseup`).
pub fn MouseHandler::end_scrollable_drag(self : MouseHandler) -> Unit {
  match self.drag {
    Some(drag) =>
      match self.scrollable_for_drag(drag.owner) {
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
/// Applies an in-progress thumb drag (document `mousemove`).
pub fn MouseHandler::handle_scrollable_drag_move(
  self : MouseHandler,
  event : @rdom.Event,
) -> Unit {
  guard self.drag is Some(drag) else { return }
  guard event.to_mouse_event() is Some(mouse) else { return }
  event.prevent_default()
  let delta = @scrollbar.drag_coord(mouse, drag.vertical) - drag.start_coord
  guard self.scrollable_for_drag(drag.owner) is Some(scrollable) else {
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
fn MouseHandler::scrollable_track_jump(
  self : MouseHandler,
  scrollable : @scrollbar.ScrollableElementDom,
  owner : @scrollbar.ScrollableElementOwner,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Unit {
  let desired = scrollable.desired_position_from_track(vertical~, mouse)
  self.apply_scrollable_position(scrollable, owner, vertical~, desired)
}

///|
fn MouseHandler::apply_scrollable_position(
  self : MouseHandler,
  scrollable : @scrollbar.ScrollableElementDom,
  owner : @scrollbar.ScrollableElementOwner,
  vertical~ : Bool,
  desired : Double,
) -> Unit {
  match owner {
    EditorScrollableElement =>
      match (self.view_helper.view_layout)() {
        Some(view_layout) =>
          if vertical {
            view_layout.scroll_to(scroll_top=desired) |> ignore
          } else {
            let position = view_layout.position()
            view_layout.scroll_to(
              scroll_top=position.scroll_top,
              scroll_left=desired,
            )
            |> ignore
          }
        None => ()
      }
    HoverScrollableElement => scrollable.native_scroll_to(vertical~, desired)
  }
}

///|
fn MouseHandler::scrollable_for_drag(
  self : MouseHandler,
  owner : @scrollbar.ScrollableElementOwner,
) -> @scrollbar.ScrollableElementDom? {
  match owner {
    EditorScrollableElement => Some(self.view_helper.editor_scrollable)
    HoverScrollableElement => (self.view_helper.hover_scrollable)()
  }
}

///|
/// Wires the browser-driven reveal listeners: when focus or the browser mutates
/// a DOM scroll offset, the delta is translated into the model and the DOM
/// offset reset (Monaco's editor scrollbar bridge).
pub fn MouseHandler::hook_browser_desperate_reveal(self : MouseHandler) -> Unit {
  let editor_scrollable = self.view_helper.editor_scrollable
  self.view_helper.view_dom_node.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      self.view_helper.view_dom_node,
      look_at_scroll_top=true,
      look_at_scroll_left=true,
    )
  })
  self.view_helper.overflow_guard.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      self.view_helper.overflow_guard,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
  editor_scrollable.content.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      editor_scrollable.content,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
  editor_scrollable.wrapper.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      editor_scrollable.wrapper,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
}

///|
/// Mirrors Monaco's editor scrollbar bridge for browser-driven reveal:
/// when focus or the browser mutates a DOM scroll offset, translate that
/// delta into the model and reset the DOM offset to zero.
fn MouseHandler::handle_browser_desperate_reveal(
  self : MouseHandler,
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
    match (self.view_helper.view_layout)() {
      Some(view_layout) =>
        view_layout.scroll_by(delta_left~, delta_top~) |> ignore
      None => ()
    }
  }
}
