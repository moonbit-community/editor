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
/// Editor scrollbar defaults from Monaco's `EditorScrollbar` option.
let editor_vertical_scrollbar_size = 14.0

///|
let editor_horizontal_scrollbar_size = 12.0

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
  editor_scrollable : ScrollableElementDom
  lines_content : @rdom.Element
  view_overlays : @rdom.Element
  view_zones : @rdom.Element
  view_lines : @rdom.Element
  content_widgets : @rdom.Element
  overlay_widgets : @rdom.Element
  overflowing_content_widgets : @rdom.Element
  overflowing_overlay_widgets : @rdom.Element
  mut hover_widget : HoverWidgetDom?
  mut window : @view_layout.LineWindow
  mut generation : Int
  line_nodes : Array[@rdom.Element]
  gutter_nodes : Array[@rdom.Element]
  render_inputs : Array[@view_line_renderer.RenderLineInput]
}

///|
fn frame_window(frame : @renderer.RenderFrame) -> @view_layout.LineWindow {
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
  let margin_part = create_margin_part(document)
  let margin = margin_part.margin
  let margin_view_overlays = margin_part.margin_view_overlays
  let line_numbers = margin_part.line_numbers
  let editor_scrollable = ScrollableElementDom::new(
    "lines-content moonbit-viewer-background",
    vertical_size=editor_vertical_scrollbar_size,
    horizontal_size=editor_horizontal_scrollbar_size,
  )
  editor_scrollable.set_wrapper_class(
    "monaco-scrollable-element editor-scrollable",
  )
  editor_scrollable.wrapper.set_attribute("data-view-part", "editor-scrollable")
  let lines_content = editor_scrollable.content
  lines_content.set_attribute("data-view-part", "lines-content")
  let view_overlays = create_view_overlays_part(document)
  let view_zones = create_view_zones_part(document)
  let view_lines = document.create_element("div")
  view_lines.set_attribute("class", "view-lines")
  view_lines.set_attribute("data-view-part", "view-lines")
  let content_widget_slots = create_content_widget_slots(document)
  let content_widgets = content_widget_slots.content_widgets
  let overlay_widget_slots = create_overlay_widget_slots(document)
  let overlay_widgets = overlay_widget_slots.overlay_widgets
  lines_content.append_child(view_overlays.as_node())
  lines_content.append_child(view_zones.as_node())
  lines_content.append_child(view_lines.as_node())
  lines_content.append_child(content_widgets.as_node())
  lines_content.append_child(overlay_widgets.as_node())
  let overflowing_content_widgets = content_widget_slots.overflowing_content_widgets
  let overflowing_overlay_widgets = overlay_widget_slots.overflowing_overlay_widgets
  editor_scrollable.update_from_model(
    { width: 0.0, scroll_width: 0.0, height: 0.0, scroll_height: 0.0 },
    { scroll_left: 0.0, scroll_top: 0.0 },
  )
  overflow_guard.append_child(margin.as_node())
  overflow_guard.append_child(editor_scrollable.wrapper.as_node())
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
    editor_scrollable,
    lines_content,
    view_overlays,
    view_zones,
    view_lines,
    content_widgets,
    overlay_widgets,
    overflowing_content_widgets,
    overflowing_overlay_widgets,
    hover_widget: None,
    window: { start: 0, end: 0 },
    generation: -1,
    line_nodes: [],
    gutter_nodes: [],
    render_inputs: [],
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
        self.view_model,
        self.controller_decorations(),
        self.content_generation,
        self.measured_char_width(),
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
  guard self.view_model is Some(view_model) else { return frame }
  let rendered = frame_window(frame)
  let desired = self.layout.visible_window(overscan=line_overscan)
  if desired != rendered &&
    @view_layout.window_needs_update(rendered, desired, line_overscan) {
    let rebuilt = view_model.render_frame({
      start_line: desired.start,
      end_line: desired.end,
    })
    self.frame = Some(rebuilt)
    rebuilt
  } else {
    frame
  }
}
