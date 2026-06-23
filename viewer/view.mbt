///|
/// Pixel height of one rendered code line. Keep in sync with
/// `--editor-line-height` in internal/shell/workbench/theme.css.
let editor_line_height = 18

///|
/// Total horizontal padding of the line-number gutter. Keep in sync with
/// `.line-number` padding in viewer/margin.css.
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
/// The imperative browser `View` role: a root editor node owning an
/// overflow guard, root scheduling, and an ordered list of stateful parts.
/// Each part owns its own DOM nodes, private state, dirty flag, prepare step,
/// and write step.
priv struct View {
  root : @rdom.Element
  probe : @rdom.Element
  message_text : @rdom.Element
  overflow_guard : @rdom.Element
  view_lines : ViewLines
  view_zones : ViewZones
  content_view_overlays : ContentViewOverlays
  margin_view_overlays : MarginViewOverlays
  content_widgets : ContentWidgets
  overlay_widgets : OverlayWidgets
  editor_scrollbar : EditorScrollbar
  view_parts : Array[ViewPartHandle]
  mut last_snapshot : ViewRenderSnapshot?
}

///|
fn frame_window(frame : @view_model.RenderFrame) -> @view_layout.LineWindow {
  { start: frame.viewport.start_line, end: frame.viewport.end_line }
}

///|
fn View::build() -> View {
  let document = @rdom.document()
  let root = document.create_element("section")
  root.set_attribute("class", view_root_class("source-empty"))
  root.set_attribute("aria-label", "Readonly code viewer")
  root.set_attribute("tabindex", "0")
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
  let margin_view_overlays = MarginViewOverlays::new(document)
  let editor_scrollbar = EditorScrollbar::new()
  let content_view_overlays = ContentViewOverlays::new(document)
  let view_zones = ViewZones::new(document)
  let view_lines = ViewLines::new(document)
  let content_widgets = ContentWidgets::new(document)
  let overlay_widgets = OverlayWidgets::new(document)
  let lines_content = editor_scrollbar.content()
  lines_content.append_child(content_view_overlays.dom().as_node())
  lines_content.append_child(view_zones.dom().as_node())
  lines_content.append_child(view_lines.dom().as_node())
  lines_content.append_child(content_widgets.dom().as_node())
  lines_content.append_child(overlay_widgets.dom().as_node())
  overflow_guard.append_child(margin_view_overlays.dom().as_node())
  overflow_guard.append_child(editor_scrollbar.wrapper().as_node())
  root.append_child(probe.as_node())
  root.append_child(message.as_node())
  root.append_child(overflow_guard.as_node())
  root.append_child(content_widgets.overflowing_dom().as_node())
  root.append_child(overlay_widgets.overflowing_dom().as_node())
  let view_parts = default_view_parts(
    view_lines, view_zones, content_view_overlays, margin_view_overlays, content_widgets,
    overlay_widgets, editor_scrollbar,
  )
  let view : View = {
    root,
    probe,
    message_text,
    overflow_guard,
    view_lines,
    view_zones,
    content_view_overlays,
    margin_view_overlays,
    content_widgets,
    overlay_widgets,
    editor_scrollbar,
    view_parts,
    last_snapshot: None,
  }
  view
}

///|
fn view_root_class(source_state : String) -> String {
  "monaco-editor moonbit-viewer readonly-editor " + source_state
}

///|
/// Shows the host-provided placeholder when no document frame is loaded.
fn View::render_empty(self : View, placeholder : String) -> Unit {
  self.root.set_attribute("class", view_root_class("source-empty"))
  self.message_text.set_node_value(@js.Nullable::from_option(Some(placeholder)))
  self.last_snapshot = None
  self.mark_parts_dirty()
}

///|
fn View::mark_parts_dirty(self : View) -> Unit {
  self.view_lines.set_should_render(true)
  self.view_zones.set_should_render(true)
  self.content_view_overlays.set_should_render(true)
  self.margin_view_overlays.set_should_render(true)
  self.content_widgets.set_should_render(true)
  self.overlay_widgets.set_should_render(true)
  self.editor_scrollbar.set_should_render(true)
}

///|
/// Monaco-shaped coordinated rendering: collect dirty view parts, let them
/// observe viewport data, render text lines first, then prepare/write the
/// remaining browser concerns.
fn View::render(self : View, viewer : Viewer, input : ViewRenderInput) -> Unit {
  self.root.set_attribute("class", view_root_class("source-loaded"))
  let rendering = RenderingContext::from_input(
    ViewContext::new(viewer, self),
    input,
    self.last_snapshot,
  )
  let dirty_parts = self.dirty_view_parts(rendering)
  for part in dirty_parts {
    part.on_before_render(rendering.viewport)
  }
  let restricted = rendering.restricted()
  for part in dirty_parts {
    match part {
      ViewLinesPart(_) => {
        part.prepare_render(rendering)
        part.render(restricted)
      }
      _ => ()
    }
  }
  let dirty_parts = self.dirty_view_parts(rendering)
  for part in dirty_parts {
    match part {
      ViewLinesPart(_) => ()
      _ => part.prepare_render(rendering)
    }
  }
  for part in dirty_parts {
    match part {
      ViewLinesPart(_) => ()
      _ => part.render(restricted)
    }
  }
  for part in dirty_parts {
    part.on_did_render()
  }
  self.last_snapshot = Some(rendering.snapshot)
}

///|
fn View::dirty_view_parts(
  self : View,
  rendering : RenderingContext,
) -> Array[ViewPartHandle] {
  let parts : Array[ViewPartHandle] = []
  for part in self.view_parts {
    if part.should_render(rendering) {
      parts.push(part)
    }
  }
  parts
}

///|
/// The rAF-coalesced render loop entry: reads (measurement) before
/// writes, delegates browser DOM work to `View`, then reports the paint
/// facts that were waiting on this flush.
fn Viewer::flush_render(self : Viewer) -> Unit {
  self.render_pending = false
  guard self.view is Some(view) else { return }
  // Read phase: measure only when a re-measure was requested.
  if self.measure_requested {
    self.measure_requested = false
    self.measure(view)
  }
  // Write phase.
  let write_started = now_ms()
  match self.frame {
    None => view.render_empty(self.placeholder)
    Some(frame) => {
      let frame = self.synced_window_frame(frame)
      view.render(self, {
        frame,
        view_model: self.view_model,
        layout: self.layout,
        browser_view_zones: self.view_zones,
        decorations: self.controller_decorations(),
        selection_range: self.selection_range(),
        folding_ranges: self.folding_ranges,
        folded_ranges: self.folded_ranges,
        hover_state: self.hover,
        on_toggle_fold: line => self.toggle_fold(line),
        on_hover_measured: (below, shift_left) => {
          self.hover = self.hover.measured(below, shift_left)
        },
        generation: self.content_generation,
        gutter_width: self.gutter_width(frame),
        space_width: self.measured_char_width(),
      })
    }
  }
  let patch_ms = now_ms() - write_started
  match (self.pending_rendered, self.frame) {
    (Some(pending), Some(frame)) => {
      self.pending_rendered = None
      self.did_render_model.fire({
        model: pending.model,
        line_count: frame.line_count,
        rendered_lines: frame.lines.length(),
        diagnostics: frame.diagnostics,
        patch_ms,
        fresh: pending.fresh,
      })
    }
    _ => ()
  }
  if self.scroll_dirty {
    self.scroll_dirty = false
    let position = self.layout.position()
    self.did_scroll.fire({
      scroll_top: position.scroll_top,
      scroll_left: position.scroll_left,
    })
  }
}

///|
fn Viewer::schedule_render(self : Viewer) -> Unit {
  if self.render_pending || self.view is None {
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
  frame : @view_model.RenderFrame,
) -> @view_model.RenderFrame {
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
