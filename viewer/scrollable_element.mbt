///|
/// Browser-side counterpart to the common `Scrollable` model. This owns the
/// Monaco-shaped DOM shell and the custom scrollbar node geometry; callers
/// decide whether scroll positions are written back into `ViewLayout` or a
/// native content element.
priv struct ScrollableElementDom {
  wrapper : @rdom.Element
  content : @rdom.Element
  vertical_bar : @rdom.Element
  vertical_slider : @rdom.Element
  horizontal_bar : @rdom.Element
  horizontal_slider : @rdom.Element
  left_shadow : @rdom.Element
  top_shadow : @rdom.Element
  top_left_shadow : @rdom.Element
  vertical_size : Double
  horizontal_size : Double
  vertical_state : @view_layout.ScrollbarState
  horizontal_state : @view_layout.ScrollbarState
  mut vertical_revealed : Bool
  mut horizontal_revealed : Bool
  mut vertical_fade : Bool
  mut horizontal_fade : Bool
  mut mouse_is_over : Bool
  mut is_dragging : Bool
  mut hide_generation : Int
}

///|
priv enum ScrollableElementOwner {
  EditorScrollableElement
  HoverScrollableElement
}

///|
/// An active scrollbar thumb drag. The owner tag lets document-level
/// mousemove/up handling stay shared while still applying the resulting
/// position to the correct scroll target.
priv struct ScrollbarDrag {
  owner : ScrollableElementOwner
  vertical : Bool
  start_coord : Double
  start_slider : Double
}

///|
let default_scrollbar_size = 10.0

///|
let scrollbar_hide_timeout_ms = 500

///|
fn ScrollableElementDom::new(
  content_class : String,
  vertical_size? : Double = default_scrollbar_size,
  horizontal_size? : Double = default_scrollbar_size,
) -> ScrollableElementDom {
  let document = @rdom.document()
  let wrapper = document.create_element("div")
  wrapper.set_attribute("class", "monaco-scrollable-element")
  wrapper.set_attribute("role", "presentation")
  let content = document.create_element("div")
  content.set_attribute("class", content_class)
  let horizontal_bar = document.create_element("div")
  horizontal_bar.set_attribute("class", "scrollbar horizontal invisible")
  horizontal_bar.set_attribute("role", "presentation")
  horizontal_bar.set_attribute("aria-hidden", "true")
  let horizontal_slider = document.create_element("div")
  horizontal_slider.set_attribute("class", "slider")
  horizontal_bar.append_child(horizontal_slider.as_node())
  let vertical_bar = document.create_element("div")
  vertical_bar.set_attribute("class", "scrollbar vertical invisible")
  vertical_bar.set_attribute("role", "presentation")
  vertical_bar.set_attribute("aria-hidden", "true")
  let vertical_slider = document.create_element("div")
  vertical_slider.set_attribute("class", "slider")
  vertical_bar.append_child(vertical_slider.as_node())
  let left_shadow = document.create_element("div")
  left_shadow.set_attribute("class", "shadow")
  let top_shadow = document.create_element("div")
  top_shadow.set_attribute("class", "shadow")
  let top_left_shadow = document.create_element("div")
  top_left_shadow.set_attribute("class", "shadow")
  wrapper.append_child(content.as_node())
  wrapper.append_child(horizontal_bar.as_node())
  wrapper.append_child(vertical_bar.as_node())
  wrapper.append_child(left_shadow.as_node())
  wrapper.append_child(top_shadow.as_node())
  wrapper.append_child(top_left_shadow.as_node())
  {
    wrapper,
    content,
    vertical_bar,
    vertical_slider,
    horizontal_bar,
    horizontal_slider,
    left_shadow,
    top_shadow,
    top_left_shadow,
    vertical_size,
    horizontal_size,
    vertical_state: @view_layout.ScrollbarState::new(
      scrollbar_size=vertical_size,
    ),
    horizontal_state: @view_layout.ScrollbarState::new(
      scrollbar_size=horizontal_size,
      opposite_scrollbar_size=vertical_size,
    ),
    vertical_revealed: false,
    horizontal_revealed: false,
    vertical_fade: false,
    horizontal_fade: false,
    mouse_is_over: false,
    is_dragging: false,
    hide_generation: 0,
  }
}

///|
fn ScrollableElementDom::set_wrapper_class(
  self : ScrollableElementDom,
  class_name : String,
) -> Unit {
  self.wrapper.set_attribute("class", class_name)
}

///|
fn ScrollableElementDom::update_from_model(
  self : ScrollableElementDom,
  dimensions : @view_layout.ScrollDimensions,
  position : @view_layout.ScrollPosition,
  horizontal_left? : Double,
) -> Unit {
  self.vertical_state.set_visible_size(dimensions.height) |> ignore
  self.vertical_state.set_scroll_size(dimensions.scroll_height) |> ignore
  self.vertical_state.set_scroll_position(position.scroll_top) |> ignore
  self.write_vertical_bar()
  self.horizontal_state.set_visible_size(dimensions.width) |> ignore
  self.horizontal_state.set_scroll_size(dimensions.scroll_width) |> ignore
  self.horizontal_state.set_scroll_position(position.scroll_left) |> ignore
  self.write_horizontal_bar(horizontal_left?)
  self.write_shadows(position)
}

///|
fn ScrollableElementDom::update_from_native_content(
  self : ScrollableElementDom,
) -> Unit {
  let content_rect = self.content.get_bounding_client_rect()
  self.update_from_model(
    {
      width: content_rect.get_width(),
      scroll_width: self.content.get_scroll_width(),
      height: content_rect.get_height(),
      scroll_height: self.content.get_scroll_height(),
    },
    {
      scroll_left: self.content.get_scroll_left(),
      scroll_top: self.content.get_scroll_top(),
    },
  )
}

///|
fn ScrollableElementDom::write_vertical_bar(
  self : ScrollableElementDom,
) -> Unit {
  let needed = self.vertical_state.is_needed()
  if !needed {
    self.set_bar_visibility(vertical=true, revealed=false, fade=false)
  }
  self.vertical_bar.set_attribute(
    "class",
    self.scrollbar_class(vertical=true, needed~),
  )
  if self.vertical_state.is_needed() {
    self.vertical_bar.set_attribute(
      "style",
      "width:" +
      self.vertical_size.to_string() +
      "px;height:" +
      self.vertical_state.rectangle_large_size().to_string() +
      "px;right:0px;top:0px",
    )
    self.vertical_slider.set_attribute(
      "style",
      "width:" +
      self.vertical_size.to_string() +
      "px;" +
      "height:" +
      self.vertical_state.slider_size().to_string() +
      "px;transform:translateY(" +
      self.vertical_state.slider_position().to_string() +
      "px)",
    )
  } else {
    self.vertical_bar.set_attribute(
      "style",
      "width:" +
      self.vertical_size.to_string() +
      "px;height:" +
      self.vertical_state.rectangle_large_size().to_string() +
      "px;right:0px;top:0px",
    )
    self.vertical_slider.set_attribute("style", "")
  }
}

///|
fn ScrollableElementDom::write_horizontal_bar(
  self : ScrollableElementDom,
  horizontal_left? : Double,
) -> Unit {
  let needed = self.horizontal_state.is_needed()
  if !needed {
    self.set_bar_visibility(vertical=false, revealed=false, fade=false)
  }
  self.horizontal_bar.set_attribute(
    "class",
    self.scrollbar_class(vertical=false, needed~),
  )
  if self.horizontal_state.is_needed() {
    let mut bar_style = "height:" +
      self.horizontal_size.to_string() +
      "px;width:" +
      self.horizontal_state.rectangle_large_size().to_string() +
      "px;bottom:0px"
    match horizontal_left {
      Some(left) => bar_style = bar_style + ";left:" + left.to_string() + "px"
      None => ()
    }
    self.horizontal_bar.set_attribute("style", bar_style)
    self.horizontal_slider.set_attribute(
      "style",
      "height:" +
      self.horizontal_size.to_string() +
      "px;" +
      "width:" +
      self.horizontal_state.slider_size().to_string() +
      "px;transform:translateX(" +
      self.horizontal_state.slider_position().to_string() +
      "px)",
    )
  } else {
    let mut bar_style = "height:" +
      self.horizontal_size.to_string() +
      "px;width:" +
      self.horizontal_state.rectangle_large_size().to_string() +
      "px;bottom:0px"
    match horizontal_left {
      Some(left) => bar_style = bar_style + ";left:" + left.to_string() + "px"
      None => ()
    }
    self.horizontal_bar.set_attribute("style", bar_style)
    self.horizontal_slider.set_attribute("style", "")
  }
}

///|
fn ScrollableElementDom::scrollbar_class(
  self : ScrollableElementDom,
  vertical~ : Bool,
  needed~ : Bool,
) -> String {
  let axis = if vertical { "vertical" } else { "horizontal" }
  if needed && self.bar_is_revealed(vertical) {
    "visible scrollbar " + axis
  } else {
    let mut class_name = "invisible scrollbar " + axis
    if needed && self.bar_has_fade(vertical) {
      class_name = class_name + " fade"
    }
    class_name
  }
}

///|
fn ScrollableElementDom::bar_is_revealed(
  self : ScrollableElementDom,
  vertical : Bool,
) -> Bool {
  if vertical {
    self.vertical_revealed
  } else {
    self.horizontal_revealed
  }
}

///|
fn ScrollableElementDom::bar_has_fade(
  self : ScrollableElementDom,
  vertical : Bool,
) -> Bool {
  if vertical {
    self.vertical_fade
  } else {
    self.horizontal_fade
  }
}

///|
fn ScrollableElementDom::set_bar_visibility(
  self : ScrollableElementDom,
  vertical~ : Bool,
  revealed~ : Bool,
  fade~ : Bool,
) -> Unit {
  if vertical {
    self.vertical_revealed = revealed
    self.vertical_fade = fade
  } else {
    self.horizontal_revealed = revealed
    self.horizontal_fade = fade
  }
}

///|
fn ScrollableElementDom::write_bar_visibility_class(
  self : ScrollableElementDom,
  vertical : Bool,
) -> Unit {
  let needed = self.state(vertical).is_needed()
  self
  .track(vertical)
  .set_attribute("class", self.scrollbar_class(vertical~, needed~))
}

///|
fn ScrollableElementDom::reveal_scrollbars(self : ScrollableElementDom) -> Unit {
  self.hide_generation += 1
  if self.vertical_state.is_needed() {
    self.set_bar_visibility(vertical=true, revealed=true, fade=false)
    self.write_bar_visibility_class(true)
  }
  if self.horizontal_state.is_needed() {
    self.set_bar_visibility(vertical=false, revealed=true, fade=false)
    self.write_bar_visibility_class(false)
  }
}

///|
fn ScrollableElementDom::hide_scrollbars_if_idle(
  self : ScrollableElementDom,
) -> Unit {
  if self.mouse_is_over || self.is_dragging {
    return
  }
  self.set_bar_visibility(
    vertical=true,
    revealed=false,
    fade=self.vertical_state.is_needed(),
  )
  self.set_bar_visibility(
    vertical=false,
    revealed=false,
    fade=self.horizontal_state.is_needed(),
  )
  self.write_bar_visibility_class(true)
  self.write_bar_visibility_class(false)
}

///|
fn ScrollableElementDom::schedule_hide_scrollbars(
  self : ScrollableElementDom,
) -> Unit {
  if self.mouse_is_over || self.is_dragging {
    return
  }
  self.hide_generation += 1
  let generation = self.hide_generation
  set_timeout(
    () => {
      if self.hide_generation == generation {
        self.hide_scrollbars_if_idle()
      }
    },
    scrollbar_hide_timeout_ms,
  )
  |> ignore
}

///|
fn ScrollableElementDom::reveal_for_scroll(self : ScrollableElementDom) -> Unit {
  self.reveal_scrollbars()
  self.schedule_hide_scrollbars()
}

///|
fn ScrollableElementDom::mouse_entered(self : ScrollableElementDom) -> Unit {
  if self.mouse_is_over {
    return
  }
  self.mouse_is_over = true
  self.reveal_scrollbars()
}

///|
fn ScrollableElementDom::mouse_left(self : ScrollableElementDom) -> Unit {
  self.mouse_is_over = false
  self.hide_scrollbars_if_idle()
}

///|
fn ScrollableElementDom::drag_started(self : ScrollableElementDom) -> Unit {
  self.is_dragging = true
  self.reveal_scrollbars()
}

///|
fn ScrollableElementDom::drag_ended(self : ScrollableElementDom) -> Unit {
  self.is_dragging = false
  self.hide_scrollbars_if_idle()
}

///|
fn ScrollableElementDom::write_shadows(
  self : ScrollableElementDom,
  position : @view_layout.ScrollPosition,
) -> Unit {
  let top = position.scroll_top > 0.0
  let left = position.scroll_left > 0.0
  self.top_shadow.set_attribute(
    "class",
    if top {
      "shadow top"
    } else {
      "shadow"
    },
  )
  self.left_shadow.set_attribute(
    "class",
    if left {
      "shadow left"
    } else {
      "shadow"
    },
  )
  let mut top_left = "shadow"
  if top || left {
    top_left = top_left + " top-left-corner"
  }
  if top {
    top_left = top_left + " top"
  }
  if left {
    top_left = top_left + " left"
  }
  self.top_left_shadow.set_attribute("class", top_left)
}

///|
fn ScrollableElementDom::state(
  self : ScrollableElementDom,
  vertical : Bool,
) -> @view_layout.ScrollbarState {
  if vertical {
    self.vertical_state
  } else {
    self.horizontal_state
  }
}

///|
fn ScrollableElementDom::track(
  self : ScrollableElementDom,
  vertical : Bool,
) -> @rdom.Element {
  if vertical {
    self.vertical_bar
  } else {
    self.horizontal_bar
  }
}

///|
fn ScrollableElementDom::slider(
  self : ScrollableElementDom,
  vertical : Bool,
) -> @rdom.Element {
  if vertical {
    self.vertical_slider
  } else {
    self.horizontal_slider
  }
}

///|
fn ScrollableElementDom::desired_position_from_track(
  self : ScrollableElementDom,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Double {
  let rect = self.track(vertical).get_bounding_client_rect()
  let offset = if vertical {
    mouse.get_client_y().to_double() - rect.get_top()
  } else {
    mouse.get_client_x().to_double() - rect.get_left()
  }
  self.state(vertical).desired_position_from_offset(offset)
}

///|
fn ScrollableElementDom::set_slider_active(
  self : ScrollableElementDom,
  vertical~ : Bool,
  active : Bool,
) -> Unit {
  let slider = self.slider(vertical)
  if active {
    slider.set_attribute("class", "slider active")
  } else {
    slider.set_attribute("class", "slider")
  }
}

///|
fn ScrollableElementDom::native_scroll_to(
  self : ScrollableElementDom,
  vertical~ : Bool,
  position : Double,
) -> Unit {
  if vertical {
    self.content.set_scroll_top(position)
  } else {
    self.content.set_scroll_left(position)
  }
  self.update_from_native_content()
  self.reveal_for_scroll()
}

///|
fn ScrollableElementDom::native_scroll_by(
  self : ScrollableElementDom,
  delta_left? : Double = 0.0,
  delta_top? : Double = 0.0,
) -> Unit {
  self.content.set_scroll_top(self.content.get_scroll_top() + delta_top)
  self.content.set_scroll_left(self.content.get_scroll_left() + delta_left)
  self.update_from_native_content()
  self.reveal_for_scroll()
}

///|
fn ScrollableElementDom::native_page_delta(
  self : ScrollableElementDom,
) -> Double {
  self.content.get_bounding_client_rect().get_height()
}

///|
fn normalized_wheel_delta(
  wheel : @rdom.WheelEvent,
  line_height : Double,
  page_size : Double,
) -> (Double, Double) {
  let scale = match wheel.get_delta_mode() {
    1 => line_height
    2 => page_size
    _ => 1.0
  }
  (wheel.get_delta_x() * scale, wheel.get_delta_y() * scale)
}

///|
fn drag_coord(mouse : @rdom.MouseEvent, vertical : Bool) -> Double {
  if vertical {
    mouse.get_client_y().to_double()
  } else {
    mouse.get_client_x().to_double()
  }
}
