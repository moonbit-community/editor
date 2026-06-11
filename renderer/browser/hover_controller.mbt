///|
priv struct HoverView {
  range : @core.Range
  contents : String
}

///|
priv struct HoverAnchor {
  start : Int
  end : Int
  offset : Int
}

///|
priv struct HoverPlacement {
  below : Bool
  shift_left : Double
}

///|
/// VS Code's default `editor.hover.delay`.
let hover_delay_ms = 300

///|
/// Editor hover feature state: the anchored range under the mouse, the
/// delay token gating stale timers, the resolved hover, and its measured
/// placement.
priv struct HoverController {
  anchor : HoverAnchor?
  token : Int
  view : HoverView?
  placement : HoverPlacement?
}

///|
fn HoverController::empty() -> HoverController {
  { anchor: None, token: 0, view: None, placement: None }
}

///|
fn HoverController::cleared(self : HoverController) -> HoverController {
  { ..self, anchor: None, view: None, placement: None }
}

///|
fn HoverController::on_event(
  self : HoverController,
  emit : @rabbita.Emit[BrowserMsg],
  event : EditorEvent,
  ctx : EditorContext,
) -> (@rabbita.Cmd, HoverController) {
  match event {
    MouseMoved(target, _) =>
      match ctx.frame {
        Some(frame) =>
          match span_anchor_for_target(frame, target) {
            Some((start, end, _)) => self.schedule(emit, start, end)
            None => (@rabbita.none, self.cleared())
          }
        None => (@rabbita.none, self)
      }
    MouseLeft | EscapePressed => (@rabbita.none, self.cleared())
    _ => (@rabbita.none, self)
  }
}

///|
/// VS Code's hover scheduling: a new anchor restarts the delay timer; the
/// same anchor keeps the pending or shown hover untouched.
fn HoverController::schedule(
  self : HoverController,
  emit : @rabbita.Emit[BrowserMsg],
  start : Int,
  end : Int,
) -> (@rabbita.Cmd, HoverController) {
  let same = match self.anchor {
    Some(anchor) => anchor.start == start && anchor.end == end
    None => false
  }
  if same {
    (@rabbita.none, self)
  } else {
    let token = self.token + 1
    (
      @cmd.delay(emit(FireHover(token)), hover_delay_ms),
      {
        ..self,
        token,
        anchor: Some({ start, end, offset: (start + end) / 2 }),
        view: None,
        placement: None,
      },
    )
  }
}

///|
/// The delay timer fired: request the hover if the token is still current.
fn HoverController::fire(
  self : HoverController,
  emit : @rabbita.Emit[BrowserMsg],
  ctx : EditorContext,
  token : Int,
) -> (@rabbita.Cmd, HoverController) {
  if token == self.token {
    match self.anchor {
      Some(anchor) =>
        (
          hover_request_cmd(
            emit,
            ctx.source_document,
            anchor.offset,
            frame_version(ctx.frame),
          ),
          self,
        )
      None => (@rabbita.none, self)
    }
  } else {
    (@rabbita.none, self)
  }
}

///|
/// A hover result arrived from the provider; stale frame versions are
/// dropped, successful results trigger an after-paint measurement.
fn HoverController::resolved(
  self : HoverController,
  payload : @remote_protocol.HoverResultPayload,
  current_version : Int,
) -> (@rabbita.Cmd, HoverController) {
  if current_version != payload.version {
    return (@rabbita.none, self)
  }
  match payload.hover {
    Some(hover) => {
      emit_event(
        "language:hover",
        "{\"ok\":true,\"version\":" + payload.version.to_string() + "}",
      )
      (
        measure_hover_cmd(),
        {
          ..self,
          view: Some({ range: hover.range, contents: hover.contents }),
          placement: None,
        },
      )
    }
    None => {
      emit_event(
        "language:hover",
        "{\"ok\":false,\"version\":" + payload.version.to_string() + "}",
      )
      (@rabbita.none, self)
    }
  }
}

///|
fn HoverController::measured(
  self : HoverController,
  below : Bool,
  shift_left : Double,
) -> HoverController {
  { ..self, placement: Some({ below, shift_left }) }
}

///|
fn HoverController::anchor_matches(
  self : HoverController,
  start : Int,
  end : Int,
) -> Bool {
  match self.anchor {
    Some(anchor) => anchor.start == start && anchor.end == end
    None => false
  }
}

///|
fn HoverController::decorations(
  self : HoverController,
) -> Array[@decorations.Decoration] {
  match self.view {
    Some(hover) => [
      @decorations.Decoration(hover.range, HoverHighlight, "has-hover"),
    ]
    None => []
  }
}

///|
/// Renders the hover widget inside `.code-lines`, anchored at the hovered
/// range like VS Code's editor hover: above the line by default, flipped
/// below when the measured widget would leave the viewport, and shifted left
/// when it would overflow the viewer's right edge.
fn HoverController::widget(
  self : HoverController,
  frame : @renderer.RenderFrame,
) -> @html.Html? {
  match self.view {
    Some(hover) =>
      match line_col_for_offset(frame, hover.range.start) {
        Some((line_number, column)) => {
          let mut class_name = "hover-widget"
          let mut shift_left = 0.0
          let mut below = false
          match self.placement {
            Some(placement) => {
              below = placement.below
              shift_left = placement.shift_left
            }
            None => class_name = class_name + " measuring"
          }
          let top = if below {
            line_number * editor_line_height
          } else {
            (line_number - 1) * editor_line_height
          }
          if below {
            class_name = class_name + " below"
          }
          let digits = frame.line_count.to_string().length()
          let mut attrs = widget_overlay_attrs(@html.Attrs::build())
            .role("tooltip")
            .style("top", top.to_string() + "px")
            .style(
              "left",
              "calc(" +
              (digits + column).to_string() +
              "ch + " +
              gutter_padding_px.to_string() +
              "px)",
            )
          if shift_left > 0.0 {
            attrs = attrs.style(
              "margin-left",
              "-" + shift_left.to_string() + "px",
            )
          }
          Some(
            @html.div(class=class_name, attrs~, [
              @html.div(class="hover-row", [
                @html.div(class="hover-contents", hover.contents),
              ]),
            ]),
          )
        }
        None => None
      }
    None => None
  }
}

///|
/// Measures the rendered hover widget after paint and reports whether it
/// must flip below the anchor line or shift left to stay inside the viewer.
fn measure_hover_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      let document = @rdom.document()
      match
        (
          document.query_selector(".hover-widget").to_option(),
          document.query_selector(".code-viewer").to_option(),
        ) {
        (Some(widget), Some(viewer)) => {
          let widget_rect = widget.get_bounding_client_rect()
          let viewer_rect = viewer.get_bounding_client_rect()
          let below = widget_rect.get_top() < viewer_rect.get_top()
          let overflow = widget_rect.get_right() - viewer_rect.get_right()
          let shift_left = if overflow > 0.0 { overflow } else { 0.0 }
          dispatch_browser_msg(HoverMeasured(below, shift_left))
        }
        _ => ()
      }
    },
    kind=@cmd.after_render,
  )
}
