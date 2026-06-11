///|
/// Fallback advance width for the editor's 12px monospace stack, used until
/// the char probe is measured after mount.
let fallback_char_width = 7.2

///|
/// Builds the hit-test geometry for the current frame from tracked view
/// state, falling back to font constants before the first measurement.
fn view_metrics(
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
) -> @renderer.ViewMetrics {
  let char_width = if model.char_width > 0.0 {
    model.char_width
  } else {
    fallback_char_width
  }
  let gutter_width = if model.gutter_width > 0.0 {
    model.gutter_width
  } else {
    let digits = frame.line_count.to_string().length()
    digits.to_double() * char_width + gutter_padding_px.to_double()
  }
  {
    origin_x: 0.0,
    origin_y: 0.0,
    scroll_top: model.scroll_top,
    viewport_height: model.viewer_height,
    line_height: editor_line_height,
    char_width,
    gutter_width,
    view_zones: [],
  }
}

///|
/// Converts a container mouse event into viewer-relative coordinates using
/// the listener's own element, so hit-testing is independent of page layout.
fn viewer_mouse_position(event : @rdom.MouseEvent) -> (Double, Double)? {
  match event.current_target().to_option() {
    Some(target) =>
      match target.to_element() {
        Some(element) => {
          let rect = element.get_bounding_client_rect()
          Some(
            (
              event.get_client_x().to_double() - rect.get_left(),
              event.get_client_y().to_double() - rect.get_top(),
            ),
          )
        }
        None => None
      }
    None => None
  }
}

///|
/// Measures the viewer box, the glyph probe, and the rendered gutter after
/// paint; these feed `ViewMetrics` for every later hit test.
fn measure_viewer_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      let document = @rdom.document()
      match document.query_selector(".code-viewer").to_option() {
        Some(viewer) => {
          let height = viewer.get_bounding_client_rect().get_height()
          let char_width = match
            document.query_selector(".char-probe").to_option() {
            Some(probe) =>
              probe.get_bounding_client_rect().get_width() /
              char_probe_text.length().to_double()
            None => 0.0
          }
          let gutter_width = match
            document.query_selector(".gutter").to_option() {
            Some(gutter) => gutter.get_bounding_client_rect().get_width()
            None => 0.0
          }
          dispatch_browser_msg(ViewerMeasured(height, char_width, gutter_width))
        }
        None => ()
      }
    },
    kind=@cmd.after_render,
  )
}

///|
let char_probe_text = "0000000000"

///|
/// The span the target falls in, as absolute document offsets. Mirrors the
/// anchors the old per-span handlers produced.
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

///|
fn editor_mouse_moved_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  x : Double,
  y : Double,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match model.frame {
    Some(frame) => {
      let target = @renderer.hit_test(frame, view_metrics(model, frame), x, y)
      editor_event_update(emit, model, MouseMoved(target))
    }
    None => (@rabbita.none, model)
  }
}

///|
/// Container handlers for the code viewer: one listener set replaces the
/// per-span closures; update resolves targets through `hit_test`.
fn code_viewer_attrs(emit : @rabbita.Emit[BrowserMsg]) -> @html.Attrs {
  @html.Attrs::build()
  .aria_label("Readonly code viewer")
  .on_mousemove(event => {
    match viewer_mouse_position(event) {
      Some((x, y)) => emit(EditorMouseMoved(x, y))
      None => @rabbita.none
    }
  })
  .on_mouseleave(_ => emit(EditorMouseLeft))
}

///|
/// Browser scroll events are plain `Event`s, not `UIEvent`s, so Rabbita's
/// typed `on_scroll` cannot deliver them; the viewer attaches a native
/// listener after mount instead. The property marker keeps one listener
/// per mounted element (remounts produce a fresh element).
fn attach_scroll_hook_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      match @rdom.document().query_selector(".code-viewer").to_option() {
        Some(viewer) =>
          match viewer.get_property("readonlyEditorScrollHook").to_option() {
            Some(_) => ()
            None => {
              viewer.set_property(
                "readonlyEditorScrollHook",
                @js.Value::cast_from("attached"),
              )
              viewer.add_event_listener("scroll", _event => {
                dispatch_browser_msg(EditorScrolled(viewer.get_scroll_top()))
              })
            }
          }
        None => ()
      }
    },
    kind=@cmd.after_render,
  )
}

///|
/// Overlay widgets swallow mouse events so container hit-testing never
/// resolves targets beneath them (Monaco's "target is widget" case).
fn widget_overlay_attrs(attrs : @html.Attrs) -> @html.Attrs {
  attrs
  .on_mousemove(event => {
    event.stop_propagation()
    @rabbita.none
  })
  .on_click(event => {
    event.stop_propagation()
    @rabbita.none
  })
  .on_contextmenu(event => {
    event.stop_propagation()
    @rabbita.none
  })
}
