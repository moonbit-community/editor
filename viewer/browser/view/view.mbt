///|
/// The imperative browser `View` role: a root editor node owning an
/// overflow guard, root scheduling, and an ordered list of stateful parts.
/// Each part owns its own DOM nodes, private state, dirty flag, prepare step,
/// and write step.
///
/// `pub(all)`: `Viewer` (root `viewer` package) holds `view : View?` and
/// reads several fields directly (`root`, `probe`, `overflow_guard`,
/// `view_lines`, `editor_scrollbar`, `content_widgets`) from `view_host.mbt`,
/// `input.mbt`, `hit_test_dom.mbt`, `controller_host.mbt`, and `reveal.mbt` —
/// the foreign-method rule keeps those `Viewer::` methods out of this
/// package, so cross-package field access is the only option.
pub(all) struct View {
  root : @rdom.Element
  probe : @rdom.Element
  message_text : @rdom.Element
  overflow_guard : @rdom.Element
  squiggly_style : @rdom.Element
  view_lines : @view_lines.ViewLines
  view_zones : @view_zones.ViewZones
  content_view_overlays : @selections.ContentViewOverlays
  margin_view_overlays : @margin.MarginViewOverlays
  content_widgets : @content_widgets.ContentWidgets
  view_cursors : @view_cursors.ViewCursors
  overlay_widgets : @overlay_widgets.OverlayWidgets
  editor_scrollbar : @editor_scrollbar.EditorScrollbar
  priv view_parts : Array[ViewPartHandle]
  priv mut last_snapshot : ViewRenderSnapshot?
}

///|
/// `pub`: `Viewer::synced_window_frame` (`view_host.mbt`) needs the same
/// window derivation to decide whether a rebuild is due.
pub fn frame_window(frame : @view_model.RenderFrame) -> @view_layout.LineWindow {
  { start: frame.viewport.start_line, end: frame.viewport.end_line }
}

///|
pub fn View::build() -> View {
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
  let squiggly_style = document.create_element("style")
  squiggly_style.set_attribute("data-squiggly-theme", "")
  let overflow_guard = document.create_element("div")
  overflow_guard.set_attribute("class", "overflow-guard")
  overflow_guard.set_attribute("data-view-part", "overflow-guard")
  let margin_view_overlays = @margin.MarginViewOverlays::new(document)
  let editor_scrollbar = @editor_scrollbar.EditorScrollbar::new()
  let content_view_overlays = @selections.ContentViewOverlays::new(document)
  let view_zones = @view_zones.ViewZones::new(document)
  let view_lines = @view_lines.ViewLines::new(document)
  let content_widgets = @content_widgets.ContentWidgets::new(document)
  let view_cursors = @view_cursors.ViewCursors::new(document)
  let overlay_widgets = @overlay_widgets.OverlayWidgets::new(document)
  let lines_content = editor_scrollbar.content()
  lines_content.append_child(content_view_overlays.dom().as_node())
  lines_content.append_child(view_zones.dom().as_node())
  lines_content.append_child(view_lines.dom().as_node())
  lines_content.append_child(content_widgets.dom().as_node())
  // Cursors render after (above) content widgets in lines content
  // (`view.ts:280`).
  lines_content.append_child(view_cursors.dom().as_node())
  overflow_guard.append_child(margin_view_overlays.dom().as_node())
  overflow_guard.append_child(editor_scrollbar.wrapper().as_node())
  // Overlay widgets are viewport-fixed: they live in the overflow guard, not
  // the scrolling lines content (`view.ts:287`).
  overflow_guard.append_child(overlay_widgets.dom().as_node())
  root.append_child(probe.as_node())
  root.append_child(message.as_node())
  root.append_child(squiggly_style.as_node())
  root.append_child(overflow_guard.as_node())
  root.append_child(content_widgets.overflowing_dom().as_node())
  root.append_child(overlay_widgets.overflowing_dom().as_node())
  let view_parts = default_view_parts(
    view_lines, view_zones, content_view_overlays, margin_view_overlays, content_widgets,
    view_cursors, overlay_widgets, editor_scrollbar,
  )
  let view : View = {
    root,
    probe,
    message_text,
    overflow_guard,
    squiggly_style,
    view_lines,
    view_zones,
    content_view_overlays,
    margin_view_overlays,
    content_widgets,
    view_cursors,
    overlay_widgets,
    editor_scrollbar,
    view_parts,
    last_snapshot: None,
  }
  view
}

///|
/// Root classes, Monaco's `EditorClassName.compute`
/// (`editorOptions.ts:1660-1690`): `showUnused`/`showDeprecated` mirror the
/// editor options of the same names (defaults `true`), gating the
/// unnecessary / deprecated marker styling (`editor.css:114-119`). `focused`
/// mirrors `_getEditorClassName` (`view.ts:459-462`), appended while the
/// editor root has DOM focus.
fn view_root_class(
  source_state : String,
  focused? : Bool = false,
  show_unused? : Bool = true,
  show_deprecated? : Bool = true,
) -> String {
  "monaco-editor moonbit-viewer readonly-editor" +
  (if show_unused { " showUnused" } else { "" }) +
  (if show_deprecated { " showDeprecated" } else { "" }) +
  " " +
  source_state +
  (if focused { " focused" } else { "" })
}

///|
/// Shows the host-provided placeholder when no document frame is loaded.
pub fn View::render_empty(
  self : View,
  placeholder : String,
  show_unused? : Bool = true,
  show_deprecated? : Bool = true,
) -> Unit {
  self.root.set_attribute(
    "class",
    view_root_class("source-empty", show_unused~, show_deprecated~),
  )
  self.message_text.set_node_value(@js.Nullable::from_option(Some(placeholder)))
  self.last_snapshot = None
  self.mark_parts_dirty()
}

///|
fn View::mark_parts_dirty(self : View) -> Unit {
  ViewPart::set_should_render(self.view_lines, true)
  ViewPart::set_should_render(self.view_zones, true)
  ViewPart::set_should_render(self.content_view_overlays, true)
  ViewPart::set_should_render(self.margin_view_overlays, true)
  ViewPart::set_should_render(self.content_widgets, true)
  ViewPart::set_should_render(self.view_cursors, true)
  ViewPart::set_should_render(self.overlay_widgets, true)
  ViewPart::set_should_render(self.editor_scrollbar, true)
}

///|
/// Monaco-shaped coordinated rendering: collect dirty view parts, let them
/// observe viewport data, render text lines first, then prepare/write the
/// remaining browser concerns.
pub fn View::render(
  self : View,
  view_context : ViewContext,
  input : ViewRenderInput,
) -> Unit {
  self.root.set_attribute(
    "class",
    view_root_class(
      "source-loaded",
      focused=input.editor_has_focus,
      show_unused=input.show_unused,
      show_deprecated=input.show_deprecated,
    ),
  )
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
    ViewPart::set_should_render(self.content_widgets, true)
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
