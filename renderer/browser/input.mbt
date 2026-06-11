///|
/// Fallback advance width for the editor's 12px monospace stack, used until
/// the char probe is measured after mount.
let fallback_char_width = 7.2

///|
/// Pixel height of the references peek view zone: head row, body lines, and
/// the top/bottom borders. Keep in sync with `.peek-head`/`.peek-body` in
/// app/src/style.css.
let peek_zone_height_px : Int = 22 + peek_body_lines * editor_line_height + 4

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
  let view_zones : Array[@renderer.ViewZone] = []
  match model.peek {
    Some(peek) =>
      view_zones.push({
        anchor_line: peek.anchor_line,
        height_px: peek_zone_height_px,
      })
    None => ()
  }
  {
    origin_x: 0.0,
    origin_y: 0.0,
    scroll_top: model.scroll_top,
    viewport_height: model.viewer_height,
    line_height: editor_line_height,
    char_width,
    gutter_width,
    view_zones,
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
fn clear_hover(model : BrowserAppModel) -> BrowserAppModel {
  { ..model, hover: None, hover_anchor: None, hover_placement: None }
}

///|
fn editor_mouse_moved_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  x : Double,
  y : Double,
  modifier : Bool,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match model.frame {
    Some(frame) => {
      let target = @renderer.hit_test(frame, view_metrics(model, frame), x, y)
      let model = {
        ..model,
        goto_modifier: modifier,
        last_target: Some(target),
      }
      match span_anchor_for_target(frame, target) {
        Some((start, end, _)) =>
          schedule_hover_update(emit, model, start, end, (start + end) / 2)
        None => (@rabbita.none, clear_hover(model))
      }
    }
    None => (@rabbita.none, model)
  }
}

///|
/// VS Code's hover scheduling: a new anchor restarts the delay timer; the
/// same anchor keeps the pending or shown hover untouched.
fn schedule_hover_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  start : Int,
  end : Int,
  offset : Int,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let same = match model.hover_anchor {
    Some(anchor) => anchor.start == start && anchor.end == end
    None => false
  }
  if same {
    (@rabbita.none, model)
  } else {
    let token = model.hover_token + 1
    (
      @cmd.delay(emit(FireHover(token)), hover_delay_ms),
      {
        ..model,
        hover_token: token,
        hover_anchor: Some({ start, end, offset }),
        hover: None,
        hover_placement: None,
      },
    )
  }
}

///|
fn editor_mouse_down_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  x : Double,
  y : Double,
  modifier : Bool,
) -> (@rabbita.Cmd, BrowserAppModel) {
  if !modifier {
    return (@rabbita.none, model)
  }
  match candidate_anchor_at(model, x, y) {
    Some(offset) => request_definition_update(emit, model, offset)
    None => (@rabbita.none, model)
  }
}

///|
fn editor_context_menu_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  x : Double,
  y : Double,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match candidate_anchor_at(model, x, y) {
    Some(offset) => request_references_update(emit, model, offset)
    None => (@rabbita.none, model)
  }
}

///|
/// F12 / Shift+F12 act on the last mouse target, the readonly stand-in for
/// VS Code commands acting at the cursor.
fn editor_key_command_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  shift : Bool,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match candidate_anchor_for_target(model, model.last_target) {
    Some(offset) =>
      if shift {
        request_references_update(emit, model, offset)
      } else {
        request_definition_update(emit, model, offset)
      }
    None => (@rabbita.none, model)
  }
}

///|
fn request_definition_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  offset : Int,
) -> (@rabbita.Cmd, BrowserAppModel) {
  (
    definition_resolution_cmd(
      emit,
      model.source_document,
      offset,
      frame_version(model.frame),
    ),
    { ..model, definition: None },
  )
}

///|
fn request_references_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  offset : Int,
) -> (@rabbita.Cmd, BrowserAppModel) {
  (
    references_resolution_cmd(
      emit,
      model.source_document,
      offset,
      frame_version(model.frame),
    ),
    { ..model, peek: None, peek_anchor_offset: Some(offset) },
  )
}

///|
fn candidate_anchor_at(
  model : BrowserAppModel,
  x : Double,
  y : Double,
) -> Int? {
  match model.frame {
    Some(frame) =>
      candidate_anchor_for_target(
        model,
        Some(@renderer.hit_test(frame, view_metrics(model, frame), x, y)),
      )
    None => None
  }
}

///|
/// The request offset for a target over a definition candidate span: the
/// span's midpoint, matching the old per-span handlers.
fn candidate_anchor_for_target(
  model : BrowserAppModel,
  target : @renderer.MouseTarget?,
) -> Int? {
  match (model.frame, target) {
    (Some(frame), Some(target)) =>
      match span_anchor_for_target(frame, target) {
        Some((start, end, span)) =>
          if is_definition_candidate(span) {
            Some((start + end) / 2)
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
/// Container handlers for the code viewer: one listener set replaces the
/// per-span closures; update resolves targets through `hit_test`.
fn code_viewer_attrs(emit : @rabbita.Emit[BrowserMsg]) -> @html.Attrs {
  @html.Attrs::build()
  .aria_label("Readonly code viewer")
  .on_mousemove(event => match viewer_mouse_position(event) {
    Some((x, y)) =>
      emit(
        EditorMouseMoved(x, y, event.get_ctrl_key() || event.get_meta_key()),
      )
    None => @rabbita.none
  })
  .on_click(event => match viewer_mouse_position(event) {
    Some((x, y)) =>
      emit(EditorMouseDown(x, y, event.get_ctrl_key() || event.get_meta_key()))
    None => @rabbita.none
  })
  .on_contextmenu(event => {
    event.prevent_default()
    match viewer_mouse_position(event) {
      Some((x, y)) => emit(EditorContextMenu(x, y))
      None => @rabbita.none
    }
  })
  .on_mouseleave(_ => emit(EditorMouseLeft))
  .on_scroll(event => match event.target().to_element() {
    Some(element) => emit(EditorScrolled(element.get_scroll_top()))
    None => @rabbita.none
  })
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
