///|
priv enum ContentWidgetPlacement {
  ContentWidgetAbove
  ContentWidgetBelow
}

///|
priv struct ContentWidgetAnchor {
  column : Int
  top : Int
}

///|
priv struct ContentWidget {
  id : String
  node : @rdom.Element
  anchor : ContentWidgetAnchor
  preferred_placement : ContentWidgetPlacement
  allow_overflow : Bool
  shift_left : Double
}

///|
priv struct HoverWidgetDom {
  wrapper : @rdom.Element
  hover : @rdom.Element
  scrollable : @scrollbar.ScrollableElementDom
}

///|
priv struct ContentWidgetsPrepared {
  frame : @view_model.RenderFrame
  layout : @view_layout.ViewLayout
  hover_state : HoverController
  on_hover_measured : (Bool, Double) -> Unit
}

///|
priv struct ContentWidgets {
  content_widgets : @rdom.Element
  overflowing_content_widgets : @rdom.Element
  mut hover_widget : HoverWidgetDom?
  mut should_render : Bool
  mut prepared : ContentWidgetsPrepared?
}

///|
fn ContentWidgets::new(document : @rdom.Document) -> ContentWidgets {
  let content_widgets = document.create_element("div")
  content_widgets.set_attribute("class", "contentWidgets")
  content_widgets.set_attribute("data-view-part", "contentWidgets")
  let overflowing_content_widgets = document.create_element("div")
  overflowing_content_widgets.set_attribute(
    "class", "overflowingContentWidgets",
  )
  overflowing_content_widgets.set_attribute(
    "data-view-part", "overflowingContentWidgets",
  )
  {
    content_widgets,
    overflowing_content_widgets,
    hover_widget: None,
    should_render: true,
    prepared: None,
  }
}

///|
fn ContentWidgets::dom(self : ContentWidgets) -> @rdom.Element {
  self.content_widgets
}

///|
fn ContentWidgets::overflowing_dom(self : ContentWidgets) -> @rdom.Element {
  self.overflowing_content_widgets
}

///|
fn ContentWidgets::hover_scrollable(
  self : ContentWidgets,
) -> @scrollbar.ScrollableElementDom? {
  match self.hover_widget {
    Some(widget) => Some(widget.scrollable)
    None => None
  }
}

///|
impl ViewPart for ContentWidgets with fn should_render(self) {
  self.should_render
}

///|
// Hover content changes invalidate this part directly (see `View::render`),
// mirroring Monaco's contrib hover widget rather than a view event.
impl ViewPart for ContentWidgets with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    ViewScrollChanged(e) =>
      e.window_changed || e.position_changed || e.dimensions_changed
    ViewZonesChanged => true
    _ => false
  }
}

///|
impl ViewPart for ContentWidgets with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for ContentWidgets with fn on_before_render(_self, _viewport) {
  ()
}

///|
impl ViewPart for ContentWidgets with fn prepare_render(self, context) {
  self.prepared = Some({
    frame: context.input.frame,
    layout: context.input.layout,
    hover_state: context.input.hover_state,
    on_hover_measured: context.input.on_hover_measured,
  })
}

///|
impl ViewPart for ContentWidgets with fn render(self, context) {
  self.content_widgets.set_attribute("style", context.content_transform)
  match self.prepared {
    Some(prepared) =>
      self.render_hover_widget(
        context.view_context,
        prepared.frame,
        prepared.layout,
        prepared.hover_state,
        prepared.on_hover_measured,
      )
    None => ()
  }
}

///|
impl ViewPart for ContentWidgets with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

///|
/// Renders, positions, and (once) measures the hover content widget,
/// which shares the lines transform so it tracks content space. The
/// placement measurement is a read-after-write on the freshly written
/// widget, applied in the same flush.
fn ContentWidgets::render_hover_widget(
  self : ContentWidgets,
  context : ViewContext,
  frame : @view_model.RenderFrame,
  layout : @view_layout.ViewLayout,
  hover_state : HoverController,
  on_hover_measured : (Bool, Double) -> Unit,
) -> Unit {
  let hover_view = match hover_state.widget_view() {
    Some(hover_view) => hover_view
    None => {
      self.remove_hover_widget()
      return
    }
  }
  let (line_number, column) = match
    line_col_for_offset(frame, hover_view.anchor_offset) {
    Some(anchor) => anchor
    None => {
      self.remove_hover_widget()
      return
    }
  }
  let widget = self.ensure_hover_widget(context)
  let mut class_name = "monaco-resizable-hover"
  let mut shift_left = 0.0
  let mut preferred_placement = ContentWidgetAbove
  match hover_view.placement {
    Some(placement) => {
      if placement.below {
        preferred_placement = ContentWidgetBelow
      }
      shift_left = placement.shift_left
    }
    None => if hover_view.measurable { class_name = class_name + " measuring" }
  }
  match preferred_placement {
    ContentWidgetBelow => class_name = class_name + " below"
    ContentWidgetAbove => ()
  }
  let content_widget : ContentWidget = {
    id: "hover",
    node: widget.wrapper,
    anchor: {
      column,
      top: layout.relative_vertical_offset_for_line(
        frame_window(frame),
        line_number - 1,
      ),
    },
    preferred_placement,
    allow_overflow: false,
    shift_left,
  }
  widget.wrapper.set_attribute("class", class_name)
  widget.hover.set_attribute("class", "monaco-hover fade-in")
  widget.clear_sizing()
  widget.scrollable.content.set_inner_html(
    @hover.render_hover_shell(
      hover_view.parts,
      frame.language_id,
      language_registry=context.languages,
    ),
  )
  self.mount_content_widget(content_widget)
  widget.apply_sizing(context.root)
  if hover_view.measurable && hover_view.placement is None {
    // Read-after-write: decide the flip/shift from the real geometry.
    let widget_rect = widget.wrapper.get_bounding_client_rect()
    let root_rect = context.root.get_bounding_client_rect()
    let below = widget_rect.get_top() < root_rect.get_top()
    let overflow = widget_rect.get_right() - root_rect.get_right() + 12.0
    let shift_left = if overflow > 0.0 { overflow } else { 0.0 }
    on_hover_measured(below, shift_left)
    self.render_hover_widget(
      context,
      frame,
      layout,
      hover_state.measured(below, shift_left),
      on_hover_measured,
    )
  }
}

///|
fn ContentWidgets::ensure_hover_widget(
  self : ContentWidgets,
  context : ViewContext,
) -> HoverWidgetDom {
  match self.hover_widget {
    Some(widget) => widget
    None => {
      let document = @rdom.document()
      let wrapper = document.create_element("div")
      let hover = document.create_element("div")
      hover.set_attribute("class", "monaco-hover fade-in")
      hover.set_attribute("role", "tooltip")
      hover.set_attribute("tabindex", "0")
      let scrollable = @scrollbar.ScrollableElementDom::new(
        "monaco-hover-content",
      )
      hover.append_child(scrollable.wrapper.as_node())
      wrapper.append_child(hover.as_node())
      let widget : HoverWidgetDom = { wrapper, hover, scrollable }
      // Content widgets swallow pointer motion, but a hover may overlap source
      // text; non-interactive mousedown should still start editor selection at
      // the underlying coordinate.
      widget.wrapper.add_event_listener("mousemove", event => {
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("mousedown", event => {
        if hover_mousedown_is_interactive(event) {
          event.stop_propagation()
        } else {
          match event.to_mouse_event() {
            Some(mouse) => (context.handle_hover_mousedown)(event, mouse)
            None => event.stop_propagation()
          }
        }
      })
      widget.wrapper.add_event_listener("click", event => {
        if handle_hover_copy_click(event) {
          event.prevent_default()
        }
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("contextmenu", event => {
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("focusin", event => {
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("focusout", event => {
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("wheel", event => {
        match event.to_wheel_event() {
          Some(wheel) => {
            event.prevent_default()
            event.stop_propagation()
            handle_hover_wheel(widget, wheel)
          }
          None => event.stop_propagation()
        }
      })
      widget.scrollable.content.add_event_listener("wheel", event => {
        match event.to_wheel_event() {
          Some(wheel) => {
            event.prevent_default()
            event.stop_propagation()
            handle_hover_wheel(widget, wheel)
          }
          None => event.stop_propagation()
        }
      })
      widget.scrollable.content.add_event_listener("scroll", _ => {
        widget.scrollable.update_from_native_content()
      })
      (context.hook_scrollable_scrollbar_input)(
        widget.scrollable,
        @scrollbar.HoverScrollableElement,
      )
      widget.wrapper.add_event_listener("keydown", event => {
        match event.to_keyboard_event() {
          Some(keyboard) =>
            (context.handle_hover_keydown)(widget, event, keyboard)
          None => event.stop_propagation()
        }
      })
      self.hover_widget = Some(widget)
      widget
    }
  }
}

///|
fn Viewer::handle_hover_keydown(
  self : Viewer,
  widget : HoverWidgetDom,
  event : @rdom.Event,
  keyboard : @rdom.KeyboardEvent,
) -> Unit {
  event.stop_propagation()
  match keyboard.key() {
    "Escape" => {
      event.prevent_default()
      self.hover = self.hover.cleared()
      self.schedule_render()
    }
    "ArrowDown" => {
      event.prevent_default()
      scroll_hover_content(widget, editor_line_height.to_double())
    }
    "ArrowUp" => {
      event.prevent_default()
      scroll_hover_content(widget, -editor_line_height.to_double())
    }
    "PageDown" => {
      event.prevent_default()
      scroll_hover_content(widget, hover_content_page_delta(widget))
    }
    "PageUp" => {
      event.prevent_default()
      scroll_hover_content(widget, -hover_content_page_delta(widget))
    }
    "Home" => {
      event.prevent_default()
      widget.scrollable.native_scroll_to(vertical=true, 0.0)
    }
    "End" => {
      event.prevent_default()
      widget.scrollable.native_scroll_to(
        vertical=true,
        widget.scrollable.content.get_scroll_height(),
      )
    }
    "ArrowRight" => {
      event.prevent_default()
      scroll_hover_content_horizontal(widget, self.measured_char_width() * 4.0)
    }
    "ArrowLeft" => {
      event.prevent_default()
      scroll_hover_content_horizontal(
        widget,
        -(self.measured_char_width() * 4.0),
      )
    }
    _ => ()
  }
}

///|
fn handle_hover_wheel(
  widget : HoverWidgetDom,
  wheel : @rdom.WheelEvent,
) -> Unit {
  let (delta_left, delta_top) = @scrollbar.normalized_wheel_delta(
    wheel,
    editor_line_height.to_double(),
    widget.scrollable.native_page_delta(),
  )
  widget.scrollable.native_scroll_by(delta_left~, delta_top~)
}

///|
fn scroll_hover_content(widget : HoverWidgetDom, delta : Double) -> Unit {
  widget.scrollable.native_scroll_by(delta_top=delta)
}

///|
fn scroll_hover_content_horizontal(
  widget : HoverWidgetDom,
  delta : Double,
) -> Unit {
  widget.scrollable.native_scroll_by(delta_left=delta)
}

///|
fn hover_content_page_delta(widget : HoverWidgetDom) -> Double {
  widget.scrollable.native_page_delta()
}

///|
fn ContentWidgets::remove_hover_widget(self : ContentWidgets) -> Unit {
  match self.hover_widget {
    Some(widget) => {
      self.content_widgets.remove_child(widget.wrapper.as_node())
      self.hover_widget = None
    }
    None => ()
  }
}

///|
fn HoverWidgetDom::clear_sizing(self : HoverWidgetDom) -> Unit {
  self.scrollable.content.set_attribute("style", "")
}

///|
fn HoverWidgetDom::apply_sizing(
  self : HoverWidgetDom,
  root : @rdom.Element,
) -> Unit {
  let root_rect = root.get_bounding_client_rect()
  let max_width = max_hover_double(160.0, root_rect.get_width() - 24.0)
  let max_height = max_hover_double(80.0, root_rect.get_height() - 24.0)
  self.scrollable.content.set_attribute(
    "style",
    "max-width:" +
    max_width.to_string() +
    "px;max-height:" +
    max_height.to_string() +
    "px",
  )
  self.scrollable.update_from_native_content()
}

///|
fn max_hover_double(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn ContentWidgets::mount_content_widget(
  self : ContentWidgets,
  widget : ContentWidget,
) -> Unit {
  let parent = if widget.allow_overflow {
    self.overflowing_content_widgets
  } else {
    self.content_widgets
  }
  parent.append_child(widget.node.as_node())
  widget.node.set_attribute("data-content-widget", widget.id)
  widget.node.set_attribute("style", widget.style())
}

///|
fn ContentWidget::style(self : ContentWidget) -> String {
  let top = match self.preferred_placement {
    ContentWidgetBelow => self.anchor.top + editor_line_height
    ContentWidgetAbove => self.anchor.top
  }
  let mut style = "top:" +
    top.to_string() +
    "px;left:calc(" +
    self.anchor.column.to_string() +
    "ch)"
  if self.shift_left > 0.0 {
    style = style + ";margin-left:-" + self.shift_left.to_string() + "px"
  }
  style
}

///|
fn line_col_for_offset(
  frame : @view_model.RenderFrame,
  offset : Int,
) -> (Int, Int)? {
  for line in frame.lines {
    let start = line.source_offset_at_column(0)
    let end = line.source_offset_at_column(line.text.length())
    if offset >= start && offset <= end {
      return Some((line.line_number, line.view_column_at_source_offset(offset)))
    }
  }
  None
}

///|
extern "js" fn handle_hover_copy_click(event : @rdom.Event) -> Bool =
  #| (event) => {
  #|   const target = event?.target;
  #|   const button = target?.closest?.(".hover-copy-button");
  #|   if (!button || !button.closest?.('[data-content-widget="hover"]')) {
  #|     return false;
  #|   }
  #|   const row = button.closest(".hover-row");
  #|   const content = button.getAttribute("data-hover-copy") || row?.innerText || "";
  #|   globalThis.__readonlyEditorCopiedText = content;
  #|   try {
  #|     const write = globalThis.navigator?.clipboard?.writeText;
  #|     if (typeof write === "function") {
  #|       write.call(globalThis.navigator.clipboard, content).catch(() => {});
  #|     }
  #|   } catch {
  #|   }
  #|   return true;
  #| }

///|
extern "js" fn hover_mousedown_is_interactive(event : @rdom.Event) -> Bool =
  #| (event) => {
  #|   const target = event?.target;
  #|   return Boolean(target?.closest?.("button, a, input, textarea, select, [role='button'], .hover-copy-button"));
  #| }
