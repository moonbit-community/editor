///|
/// Pixel height of one rendered code line. Keep in sync with
/// `--editor-line-height` in app/src/style.css.
let editor_line_height = 18

///|
/// Total horizontal padding of the line-number gutter. Keep in sync with
/// `.line-number` padding in app/src/style.css.
let gutter_padding_px = 34

///|
/// Right padding of `.view-line-content`, part of the horizontal scroll extent.
let code_right_padding = 16.0

///|
/// Minimum line-number digit slots.
let gutter_min_digits = 5

///|
/// Thickness of the custom scrollbars, matching the old webkit styling.
let scrollbar_thickness = 14.0

///|
/// Lines rendered beyond each viewport edge so scrolling stays inside
/// already-rendered DOM between window updates.
let line_overscan = 20

///|
let char_probe_text = "0000000000"

///|
/// Fallback advance width for the editor's 12px monospace stack, used
/// until the char probe is measured after attach.
let fallback_char_width = 7.2

///|
priv enum ContentWidgetPlacement {
  ContentWidgetAbove
  ContentWidgetBelow
}

///|
priv struct ContentWidgetAnchor {
  line_number : Int
  column : Int
}

///|
priv struct ContentWidget {
  id : String
  node : @rdom.Element
  anchor : ContentWidgetAnchor
  preferred_placement : ContentWidgetPlacement
  allow_overflow : Bool
  shift_left : Double
  window_start_line : Int
}

///|
/// The imperative view island, the Monaco `View` role: an
/// root editor node owning an overflow guard, margin and content view
/// parts, widget slots, custom scrollbars, and the line/line-number node
/// recycler state (the `ViewLayer` role).
priv struct Island {
  root : @rdom.Element
  probe : @rdom.Element
  message_text : @rdom.Element
  overflow_guard : @rdom.Element
  margin : @rdom.Element
  margin_view_overlays : @rdom.Element
  line_numbers : @rdom.Element
  lines_content : @rdom.Element
  view_overlays : @rdom.Element
  view_zones : @rdom.Element
  view_lines : @rdom.Element
  content_widgets : @rdom.Element
  overlay_widgets : @rdom.Element
  overflowing_content_widgets : @rdom.Element
  overflowing_overlay_widgets : @rdom.Element
  vertical_bar : @rdom.Element
  vertical_slider : @rdom.Element
  horizontal_bar : @rdom.Element
  horizontal_slider : @rdom.Element
  vertical_state : @renderer.ScrollbarState
  horizontal_state : @renderer.ScrollbarState
  mut hover_widget : @rdom.Element?
  mut window : @renderer.LineWindow
  mut generation : Int
  line_nodes : Array[@rdom.Element]
  gutter_nodes : Array[@rdom.Element]
}

///|
fn frame_window(frame : @renderer.RenderFrame) -> @renderer.LineWindow {
  { start: frame.viewport.start_line, end: frame.viewport.end_line }
}

///|
fn Island::build() -> Island {
  let document = @rdom.document()
  let root = document.create_element("section")
  root.set_attribute("class", "moonbit-viewer readonly-editor source-empty")
  root.set_attribute("aria-label", "Readonly code viewer")
  let probe = document.create_element("span")
  probe.set_attribute("class", "char-probe")
  probe.set_attribute("aria-hidden", "true")
  probe.append_child(document.create_text_node(char_probe_text).as_node())
  let message = document.create_element("div")
  message.set_attribute("class", "source-message")
  let message_text = document.create_text_node("")
  message.append_child(message_text.as_node())
  let overflow_guard = document.create_element("div")
  overflow_guard.set_attribute("class", "overflow-guard")
  overflow_guard.set_attribute("data-view-part", "overflow-guard")
  let margin = document.create_element("div")
  margin.set_attribute("class", "margin")
  margin.set_attribute("data-view-part", "margin")
  margin.set_attribute("aria-hidden", "true")
  let margin_view_overlays = document.create_element("div")
  margin_view_overlays.set_attribute("class", "margin-view-overlays")
  margin_view_overlays.set_attribute("data-view-part", "margin-view-overlays")
  let line_numbers = document.create_element("div")
  line_numbers.set_attribute("class", "view-layer line-numbers")
  line_numbers.set_attribute("data-view-part", "line-numbers")
  margin_view_overlays.append_child(line_numbers.as_node())
  margin.append_child(margin_view_overlays.as_node())
  let lines_content = document.create_element("div")
  lines_content.set_attribute(
    "class", "lines-content moonbit-viewer-background",
  )
  lines_content.set_attribute("data-view-part", "lines-content")
  let view_overlays = document.create_element("div")
  view_overlays.set_attribute("class", "view-overlays")
  view_overlays.set_attribute("data-view-part", "view-overlays")
  let view_zones = document.create_element("div")
  view_zones.set_attribute("class", "view-zones")
  view_zones.set_attribute("data-view-part", "view-zones")
  let view_lines = document.create_element("div")
  view_lines.set_attribute("class", "view-lines")
  view_lines.set_attribute("data-view-part", "view-lines")
  let content_widgets = document.create_element("div")
  content_widgets.set_attribute("class", "contentWidgets")
  content_widgets.set_attribute("data-view-part", "contentWidgets")
  let overlay_widgets = document.create_element("div")
  overlay_widgets.set_attribute("class", "overlayWidgets")
  overlay_widgets.set_attribute("data-view-part", "overlayWidgets")
  lines_content.append_child(view_overlays.as_node())
  lines_content.append_child(view_zones.as_node())
  lines_content.append_child(view_lines.as_node())
  lines_content.append_child(content_widgets.as_node())
  lines_content.append_child(overlay_widgets.as_node())
  let overflowing_content_widgets = document.create_element("div")
  overflowing_content_widgets.set_attribute(
    "class", "overflowingContentWidgets",
  )
  overflowing_content_widgets.set_attribute(
    "data-view-part", "overflowingContentWidgets",
  )
  let overflowing_overlay_widgets = document.create_element("div")
  overflowing_overlay_widgets.set_attribute(
    "class", "overflowingOverlayWidgets",
  )
  overflowing_overlay_widgets.set_attribute(
    "data-view-part", "overflowingOverlayWidgets",
  )
  let vertical_bar = document.create_element("div")
  vertical_bar.set_attribute("class", "scrollbar vertical")
  let vertical_slider = document.create_element("div")
  vertical_slider.set_attribute("class", "slider")
  vertical_bar.append_child(vertical_slider.as_node())
  let horizontal_bar = document.create_element("div")
  horizontal_bar.set_attribute("class", "scrollbar horizontal")
  let horizontal_slider = document.create_element("div")
  horizontal_slider.set_attribute("class", "slider")
  horizontal_bar.append_child(horizontal_slider.as_node())
  overflow_guard.append_child(margin.as_node())
  overflow_guard.append_child(lines_content.as_node())
  overflow_guard.append_child(vertical_bar.as_node())
  overflow_guard.append_child(horizontal_bar.as_node())
  root.append_child(probe.as_node())
  root.append_child(message.as_node())
  root.append_child(overflow_guard.as_node())
  root.append_child(overflowing_content_widgets.as_node())
  root.append_child(overflowing_overlay_widgets.as_node())
  let island : Island = {
    root,
    probe,
    message_text,
    overflow_guard,
    margin,
    margin_view_overlays,
    line_numbers,
    lines_content,
    view_overlays,
    view_zones,
    view_lines,
    content_widgets,
    overlay_widgets,
    overflowing_content_widgets,
    overflowing_overlay_widgets,
    vertical_bar,
    vertical_slider,
    horizontal_bar,
    horizontal_slider,
    vertical_state: @renderer.ScrollbarState::new(
      scrollbar_size=scrollbar_thickness,
    ),
    horizontal_state: @renderer.ScrollbarState::new(
      scrollbar_size=scrollbar_thickness,
    ),
    hover_widget: None,
    window: { start: 0, end: 0 },
    generation: -1,
    line_nodes: [],
    gutter_nodes: [],
  }
  island.sync_static_view_parts()
  island
}

///|
fn Island::sync_static_view_parts(self : Island) -> Unit {
  self.overflow_guard.set_attribute("data-view-part", "overflow-guard")
  self.margin_view_overlays.set_attribute(
    "data-view-part", "margin-view-overlays",
  )
  self.overlay_widgets.set_attribute("data-view-part", "overlayWidgets")
  self.overflowing_overlay_widgets.set_attribute(
    "data-view-part", "overflowingOverlayWidgets",
  )
}

///|
/// The rAF-coalesced render loop entry: reads (measurement) before
/// writes (transforms, recycling, scrollbars, hover), then reports the
/// paint facts that were waiting on this flush.
fn Viewer::flush_render(self : Viewer) -> Unit {
  self.render_pending = false
  guard self.island is Some(island) else { return }
  // Read phase: measure only when a re-measure was requested.
  if self.measure_requested {
    self.measure_requested = false
    self.measure(island)
  }
  // Write phase.
  let write_started = @dom.now_ms()
  match self.frame {
    None => {
      island.root.set_attribute(
        "class", "moonbit-viewer readonly-editor source-empty",
      )
      island.message_text.set_node_value(
        @js.Nullable::from_option(Some(self.placeholder)),
      )
    }
    Some(frame) => {
      island.root.set_attribute(
        "class", "moonbit-viewer readonly-editor source-loaded",
      )
      let frame = self.synced_window_frame(frame)
      island.render_lines(
        frame,
        self.controller_decorations(),
        self.content_generation,
      )
      let gutter_width = self.gutter_width(frame)
      let position = self.layout.position()
      let origin = self.layout.window_origin(frame_window(frame))
      island.apply_geometry(
        gutter_width,
        position.scroll_left,
        origin - position.scroll_top,
      )
      island.update_scrollbars(self.layout.dimensions(), position, gutter_width)
      self.render_hover_widget(island, frame)
    }
  }
  let patch_ms = @dom.now_ms() - write_started
  match (self.pending_rendered, self.frame) {
    (Some(pending), Some(frame)) => {
      self.pending_rendered = None
      (self.notify_host)(
        ViewerDocumentRendered(
          pending.document,
          line_count=frame.line_count,
          rendered_lines=frame.lines.length(),
          diagnostics=frame.diagnostics,
          patch_ms~,
          fresh=pending.fresh,
        ),
      )
    }
    _ => ()
  }
  if self.scroll_dirty {
    self.scroll_dirty = false
    let position = self.layout.position()
    (self.notify_host)(
      ViewerScrolled(
        scroll_top=position.scroll_top,
        scroll_left=position.scroll_left,
      ),
    )
  }
}

///|
fn Viewer::schedule_render(self : Viewer) -> Unit {
  if self.render_pending || self.island is None {
    return
  }
  self.render_pending = true
  @rdom.window().request_animation_frame(_ => self.flush_render()) |> ignore
}

///|
/// When scroll or viewport changes moved the desired window past the
/// hysteresis band, rebuilds the window frame from the cached source (an
/// O(window) build) so hit tests and the recycler stay aligned.
fn Viewer::synced_window_frame(
  self : Viewer,
  frame : @renderer.RenderFrame,
) -> @renderer.RenderFrame {
  guard self.frame_source is Some(source) else { return frame }
  let rendered = frame_window(frame)
  let desired = self.layout.visible_window(overscan=line_overscan)
  if desired != rendered &&
    @renderer.window_needs_update(rendered, desired, line_overscan) {
    let rebuilt = @renderer.build_frame(source, {
      start_line: desired.start,
      end_line: desired.end,
    })
    self.frame = Some(rebuilt)
    rebuilt
  } else {
    frame
  }
}

///|
/// The `ViewLayer` recycler: tracks the rendered line range, splices
/// entering/leaving line and line-number nodes, and writes `innerHTML`
/// only on entering lines. A changed content generation (new frame
/// source or changed controller decorations) rewrites every rendered line
/// instead.
fn Island::render_lines(
  self : Island,
  frame : @renderer.RenderFrame,
  decorations : Array[@decorations.Decoration],
  generation : Int,
) -> Unit {
  let target = frame_window(frame)
  let document = @rdom.document()
  if generation != self.generation {
    while self.line_nodes.length() > frame.lines.length() {
      match (self.line_nodes.pop(), self.gutter_nodes.pop()) {
        (Some(node), Some(gutter)) => {
          self.view_lines.remove_child(node.as_node())
          self.line_numbers.remove_child(gutter.as_node())
        }
        _ => ()
      }
    }
    while self.line_nodes.length() < frame.lines.length() {
      let node = document.create_element("div")
      self.view_lines.append_child(node.as_node())
      self.line_nodes.push(node)
      let gutter = document.create_element("div")
      self.line_numbers.append_child(gutter.as_node())
      self.gutter_nodes.push(gutter)
    }
    for index in 0..<frame.lines.length() {
      write_line_node(
        self.line_nodes[index],
        frame.lines[index],
        decorations,
        index,
      )
      write_line_number_node(
        self.gutter_nodes[index],
        frame.lines[index],
        index,
      )
    }
    self.generation = generation
    self.window = target
    return
  }
  if target == self.window {
    return
  }
  let previous = self.window
  let next_lines : Array[@rdom.Element] = []
  let next_gutters : Array[@rdom.Element] = []
  for index in 0..<frame.lines.length() {
    let line_index = target.start + index
    if line_index >= previous.start && line_index < previous.end {
      // Retained line: only its window-relative top moves.
      let node = self.line_nodes[line_index - previous.start]
      node.set_attribute("style", line_node_style(index))
      next_lines.push(node)
      let gutter = self.gutter_nodes[line_index - previous.start]
      gutter.set_attribute("style", line_node_style(index))
      next_gutters.push(gutter)
    } else {
      let node = document.create_element("div")
      write_line_node(node, frame.lines[index], decorations, index)
      self.view_lines.append_child(node.as_node())
      next_lines.push(node)
      let gutter = document.create_element("div")
      write_line_number_node(gutter, frame.lines[index], index)
      self.line_numbers.append_child(gutter.as_node())
      next_gutters.push(gutter)
    }
  }
  for line_index in previous.start..<previous.end {
    if line_index < target.start || line_index >= target.end {
      self.view_lines.remove_child(
        self.line_nodes[line_index - previous.start].as_node(),
      )
      self.line_numbers.remove_child(
        self.gutter_nodes[line_index - previous.start].as_node(),
      )
    }
  }
  self.line_nodes.clear()
  for node in next_lines {
    self.line_nodes.push(node)
  }
  self.gutter_nodes.clear()
  for gutter in next_gutters {
    self.gutter_nodes.push(gutter)
  }
  self.window = target
}

///|
fn write_line_node(
  node : @rdom.Element,
  line : @renderer.RenderLine,
  decorations : Array[@decorations.Decoration],
  window_index : Int,
) -> Unit {
  node.set_attribute("class", @renderer.render_line_class(line, decorations))
  node.set_attribute("data-line", line.line_number.to_string())
  node.set_attribute("style", line_node_style(window_index))
  node.set_inner_html(@renderer.render_line_html(line, decorations))
}

///|
fn write_line_number_node(
  gutter : @rdom.Element,
  line : @renderer.RenderLine,
  window_index : Int,
) -> Unit {
  gutter.set_attribute("class", "line-number")
  gutter.set_attribute("data-line", line.line_number.to_string())
  gutter.set_attribute("style", line_node_style(window_index))
  gutter.set_inner_html(line.line_number.to_string())
}

///|
fn line_node_style(window_index : Int) -> String {
  "top:" +
  (window_index * editor_line_height).to_string() +
  "px;height:" +
  editor_line_height.to_string() +
  "px"
}

///|
/// One style write per view part per flush: text-like content parts carry
/// the content transform, overlay widgets stay viewport-positioned, and
/// the margin translates vertically only.
fn Island::apply_geometry(
  self : Island,
  gutter_width : Double,
  scroll_left : Double,
  translate_y : Double,
) -> Unit {
  self.lines_content.set_attribute(
    "style",
    "left:" + gutter_width.to_string() + "px",
  )
  let content_transform = "transform:translate(" +
    (-scroll_left).to_string() +
    "px," +
    translate_y.to_string() +
    "px)"
  self.view_lines.set_attribute("style", content_transform)
  self.view_overlays.set_attribute("style", content_transform)
  self.view_zones.set_attribute("style", content_transform)
  self.content_widgets.set_attribute("style", content_transform)
  self.margin.set_attribute("style", "width:" + gutter_width.to_string() + "px")
  self.line_numbers.set_attribute(
    "style",
    "transform:translateY(" + translate_y.to_string() + "px)",
  )
}

///|
/// Drives both scrollbars from the layout state: thumb geometry through
/// the `ScrollbarState` arithmetic, hidden entirely while the content
/// fits.
fn Island::update_scrollbars(
  self : Island,
  dimensions : @renderer.ScrollDimensions,
  position : @renderer.ScrollPosition,
  gutter_width : Double,
) -> Unit {
  self.vertical_state.set_visible_size(dimensions.height) |> ignore
  self.vertical_state.set_scroll_size(dimensions.scroll_height) |> ignore
  self.vertical_state.set_scroll_position(position.scroll_top) |> ignore
  if self.vertical_state.is_needed() {
    self.vertical_bar.set_attribute("style", "display:block")
    self.vertical_slider.set_attribute(
      "style",
      "height:" +
      self.vertical_state.slider_size().to_string() +
      "px;transform:translateY(" +
      self.vertical_state.slider_position().to_string() +
      "px)",
    )
  } else {
    self.vertical_bar.set_attribute("style", "display:none")
  }
  self.horizontal_state.set_visible_size(dimensions.width) |> ignore
  self.horizontal_state.set_scroll_size(dimensions.scroll_width) |> ignore
  self.horizontal_state.set_scroll_position(position.scroll_left) |> ignore
  if self.horizontal_state.is_needed() {
    self.horizontal_bar.set_attribute(
      "style",
      "display:block;left:" + gutter_width.to_string() + "px",
    )
    self.horizontal_slider.set_attribute(
      "style",
      "width:" +
      self.horizontal_state.slider_size().to_string() +
      "px;transform:translateX(" +
      self.horizontal_state.slider_position().to_string() +
      "px)",
    )
  } else {
    self.horizontal_bar.set_attribute("style", "display:none")
  }
}

///|
/// Renders, positions, and (once) measures the hover widget in the hover
/// layer, which shares the lines transform so the widget tracks content
/// space. The placement measurement is a read-after-write on the freshly
/// written widget, applied in the same flush.
fn Viewer::render_hover_widget(
  self : Viewer,
  island : Island,
  frame : @renderer.RenderFrame,
) -> Unit {
  let view = match self.hover.widget_view() {
    Some(view) => view
    None => {
      island.remove_hover_widget()
      return
    }
  }
  let (line_number, column) = match
    line_col_for_offset(frame, view.anchor_offset) {
    Some(anchor) => anchor
    None => {
      island.remove_hover_widget()
      return
    }
  }
  let widget = island.ensure_hover_widget(self)
  let mut class_name = "hover-widget"
  let mut shift_left = 0.0
  let mut preferred_placement = ContentWidgetAbove
  match view.placement {
    Some(placement) => {
      if placement.below {
        preferred_placement = ContentWidgetBelow
      }
      shift_left = placement.shift_left
    }
    None => if view.measurable { class_name = class_name + " measuring" }
  }
  match preferred_placement {
    ContentWidgetBelow => class_name = class_name + " below"
    ContentWidgetAbove => ()
  }
  let content_widget : ContentWidget = {
    id: "hover",
    node: widget,
    anchor: { line_number, column },
    preferred_placement,
    allow_overflow: false,
    shift_left,
    window_start_line: frame.viewport.start_line,
  }
  widget.set_attribute("class", class_name)
  widget.set_attribute("role", "tooltip")
  widget.set_inner_html(
    "<div class=\"hover-row\"><div class=\"hover-contents\">" +
    @renderer.escape_html(view.contents) +
    "</div></div>",
  )
  island.mount_content_widget(content_widget)
  if view.measurable && view.placement is None {
    // Read-after-write: decide the flip/shift from the real geometry.
    let widget_rect = widget.get_bounding_client_rect()
    let root_rect = island.root.get_bounding_client_rect()
    let below = widget_rect.get_top() < root_rect.get_top()
    let overflow = widget_rect.get_right() - root_rect.get_right()
    let shift_left = if overflow > 0.0 { overflow } else { 0.0 }
    self.hover = self.hover.measured(below, shift_left)
    self.render_hover_widget(island, frame)
  }
}

///|
fn Island::ensure_hover_widget(self : Island, viewer : Viewer) -> @rdom.Element {
  match self.hover_widget {
    Some(widget) => widget
    None => {
      let widget = @rdom.document().create_element("div")
      // Content widgets swallow mouse events so container hit-testing
      // never resolves targets beneath them.
      widget.add_event_listener("mousemove", event => event.stop_propagation())
      widget.add_event_listener("click", event => event.stop_propagation())
      widget.add_event_listener("contextmenu", event => event.stop_propagation())
      self.hover_widget = Some(widget)
      ignore(viewer)
      widget
    }
  }
}

///|
fn Island::remove_hover_widget(self : Island) -> Unit {
  match self.hover_widget {
    Some(widget) => {
      self.content_widgets.remove_child(widget.as_node())
      self.hover_widget = None
    }
    None => ()
  }
}

///|
fn Island::mount_content_widget(self : Island, widget : ContentWidget) -> Unit {
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
  let window_line = self.anchor.line_number - 1 - self.window_start_line
  let top = match self.preferred_placement {
    ContentWidgetBelow => (window_line + 1) * editor_line_height
    ContentWidgetAbove => window_line * editor_line_height
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
  frame : @renderer.RenderFrame,
  offset : Int,
) -> (Int, Int)? {
  for line in frame.lines {
    let end = line.offset + line.text.length()
    if offset >= line.offset && offset <= end {
      return Some((line.line_number, offset - line.offset))
    }
  }
  None
}
