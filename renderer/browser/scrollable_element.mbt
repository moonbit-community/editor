///|
/// Browser-side counterpart to the renderer `Scrollable` model. This owns the
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
  vertical_state : @renderer.ScrollbarState
  horizontal_state : @renderer.ScrollbarState
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
    vertical_state: @renderer.ScrollbarState::new(scrollbar_size=vertical_size),
    horizontal_state: @renderer.ScrollbarState::new(
      scrollbar_size=horizontal_size,
      opposite_scrollbar_size=vertical_size,
    ),
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
  dimensions : @renderer.ScrollDimensions,
  position : @renderer.ScrollPosition,
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
  if self.vertical_state.is_needed() {
    self.vertical_bar.set_attribute("class", "visible scrollbar vertical")
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
    self.vertical_bar.set_attribute("class", "invisible scrollbar vertical")
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
  if self.horizontal_state.is_needed() {
    self.horizontal_bar.set_attribute("class", "visible scrollbar horizontal")
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
    self.horizontal_bar.set_attribute("class", "invisible scrollbar horizontal")
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
fn ScrollableElementDom::write_shadows(
  self : ScrollableElementDom,
  position : @renderer.ScrollPosition,
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
) -> @renderer.ScrollbarState {
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
