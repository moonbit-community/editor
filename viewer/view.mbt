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
  view_lines : @view_lines.ViewLines
  view_zones : @view_zones.ViewZones
  content_view_overlays : ContentViewOverlays
  margin_view_overlays : @margin.MarginViewOverlays
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
  probe.append_child(document.create_text_node(@core.char_probe_text).as_node())
  let message = document.create_element("div")
  message.set_attribute("class", "source-message")
  let message_text = document.create_text_node("")
  message.append_child(message_text.as_node())
  let overflow_guard = document.create_element("div")
  overflow_guard.set_attribute("class", "overflow-guard")
  overflow_guard.set_attribute("data-view-part", "overflow-guard")
  let margin_view_overlays = @margin.MarginViewOverlays::new(document)
  let editor_scrollbar = EditorScrollbar::new()
  let content_view_overlays = ContentViewOverlays::new(document)
  let view_zones = @view_zones.ViewZones::new(document)
  let view_lines = @view_lines.ViewLines::new(document)
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
/// Root classes. `showUnused`/`showDeprecated` mirror Monaco's editor options,
/// which default to `true` (`editorOptions.ts`); they gate the unnecessary /
/// deprecated marker styling (`editor.css:114-119`).
fn view_root_class(source_state : String) -> String {
  "monaco-editor moonbit-viewer readonly-editor showUnused showDeprecated " +
  source_state
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
  ViewPart::set_should_render(self.view_lines, true)
  ViewPart::set_should_render(self.view_zones, true)
  self.content_view_overlays.set_should_render(true)
  ViewPart::set_should_render(self.margin_view_overlays, true)
  self.content_widgets.set_should_render(true)
  self.overlay_widgets.set_should_render(true)
  self.editor_scrollbar.set_should_render(true)
}

///|
/// Monaco-shaped coordinated rendering: collect dirty view parts, let them
/// observe viewport data, render text lines first, then prepare/write the
/// remaining browser concerns.
fn View::render(
  self : View,
  view_context : ViewContext,
  input : ViewRenderInput,
) -> Unit {
  self.root.set_attribute("class", view_root_class("source-loaded"))
  let rendering = RenderingContext::from_input(view_context, input)
  // Dispatch this frame's typed view events to every part, accumulating each
  // part's dirty flag (Monaco's `ViewEventHandler.handleEvents`).
  let events = view_events_from_snapshots(
    self.last_snapshot,
    rendering.snapshot,
  )
  for part in self.view_parts {
    part.handle_view_events(events)
  }
  // Hover content is not a view event: invalidate the hover content widget
  // directly, mirroring Monaco's contrib hover.
  if hover_changed_between(self.last_snapshot, rendering.snapshot) {
    self.content_widgets.set_should_render(true)
  }
  let dirty_parts = self.dirty_view_parts()
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
fn View::dirty_view_parts(self : View) -> Array[ViewPartHandle] {
  let parts : Array[ViewPartHandle] = []
  for part in self.view_parts {
    if part.should_render() {
      parts.push(part)
    }
  }
  parts
}
