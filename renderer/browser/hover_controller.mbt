///|
priv struct HoverView {
  range : @core.Range
  contents : String
} derive(Eq)

///|
priv struct HoverAnchor {
  start : Int
  end : Int
  offset : Int
} derive(Eq)

///|
priv struct HoverPlacement {
  below : Bool
  shift_left : Double
} derive(Eq)

///|
/// VS Code's default `editor.hover.delay`.
let hover_delay_ms = 300

///|
/// Editor hover feature state, with Monaco's timing: the provider request
/// fires at half the hover delay, display is gated at the full delay, and
/// a loading hover appears at three times the delay if the provider has
/// not answered.
priv struct HoverController {
  anchor : HoverAnchor?
  token : Int
  view : HoverView?
  pending_view : HoverView?
  answered : Bool
  display_open : Bool
  loading : Bool
  placement : HoverPlacement?
} derive(Eq)

///|
fn HoverController::empty() -> HoverController {
  {
    anchor: None,
    token: 0,
    view: None,
    pending_view: None,
    answered: false,
    display_open: false,
    loading: false,
    placement: None,
  }
}

///|
fn HoverController::cleared(self : HoverController) -> HoverController {
  {
    ..self,
    anchor: None,
    view: None,
    pending_view: None,
    answered: false,
    display_open: false,
    loading: false,
    placement: None,
  }
}

///|
fn HoverController::on_event(
  self : HoverController,
  emit : @rabbita.Emit[ViewerMsg],
  event : EditorEvent,
  ctx : EditorContext,
) -> (@rabbita.Cmd, HoverController) {
  match event {
    MouseMoved(target) =>
      match ctx.frame {
        Some(frame) =>
          match span_anchor_for_target(frame, target) {
            Some((start, end, _)) => self.schedule(emit, start, end)
            None => (@rabbita.none, self.cleared())
          }
        None => (@rabbita.none, self)
      }
    MouseLeft | EscapePressed => (@rabbita.none, self.cleared())
  }
}

///|
/// A new anchor restarts the timers; the same anchor keeps the pending or
/// shown hover untouched.
fn HoverController::schedule(
  self : HoverController,
  emit : @rabbita.Emit[ViewerMsg],
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
      @rabbita.batch([
        @cmd.delay(emit(FireHover(token)), hover_delay_ms / 2),
        @cmd.delay(emit(HoverDisplayDue(token)), hover_delay_ms),
        @cmd.delay(emit(HoverLoadingDue(token)), hover_delay_ms * 3),
      ]),
      {
        token,
        anchor: Some({ start, end, offset: (start + end) / 2 }),
        view: None,
        pending_view: None,
        answered: false,
        display_open: false,
        loading: false,
        placement: None,
      },
    )
  }
}

///|
/// Half-delay timer fired: ask the hover provider if the token is current.
fn HoverController::fire(
  self : HoverController,
  emit : @rabbita.Emit[ViewerMsg],
  ctx : EditorContext,
  token : Int,
) -> (@rabbita.Cmd, HoverController) {
  if token == self.token {
    match self.anchor {
      Some(anchor) =>
        (
          hover_provider_cmd(emit, ctx.source_document, anchor.offset, token),
          self,
        )
      None => (@rabbita.none, self)
    }
  } else {
    (@rabbita.none, self)
  }
}

///|
/// Full-delay timer fired: open the display gate and promote an already
/// resolved hover.
fn HoverController::display_due(
  self : HoverController,
  emit : @rabbita.Emit[ViewerMsg],
  token : Int,
) -> (@rabbita.Cmd, HoverController) {
  if token != self.token {
    return (@rabbita.none, self)
  }
  match self.pending_view {
    Some(view) =>
      (
        measure_hover_cmd(emit),
        {
          ..self,
          display_open: true,
          view: Some(view),
          pending_view: None,
          placement: None,
        },
      )
    None => (@rabbita.none, { ..self, display_open: true })
  }
}

///|
/// Triple-delay timer fired with no provider answer: show a loading hover.
fn HoverController::loading_due(
  self : HoverController,
  token : Int,
) -> (@rabbita.Cmd, HoverController) {
  if token == self.token && !self.answered && self.anchor is Some(_) {
    (@rabbita.none, { ..self, loading: true })
  } else {
    (@rabbita.none, self)
  }
}

///|
/// A hover provider result arrived. Results are dropped when the document
/// version moved on or the anchor token changed since the request.
fn HoverController::resolved_hover(
  self : HoverController,
  notify : (ViewerNotification) -> Unit,
  emit : @rabbita.Emit[ViewerMsg],
  version : Int,
  token : Int,
  hover : @language.Hover?,
  current_version : Int,
) -> (@rabbita.Cmd, HoverController) {
  if current_version != version || token != self.token {
    return (@rabbita.none, self)
  }
  match hover {
    Some(hover) => {
      notify(ViewerHoverResolved(ok=true, version~))
      let view : HoverView = { range: hover.range, contents: hover.contents }
      if self.display_open {
        (
          measure_hover_cmd(emit),
          {
            ..self,
            answered: true,
            loading: false,
            view: Some(view),
            pending_view: None,
            placement: None,
          },
        )
      } else {
        (
          @rabbita.none,
          { ..self, answered: true, loading: false, pending_view: Some(view) },
        )
      }
    }
    None => {
      notify(ViewerHoverResolved(ok=false, version~))
      (@rabbita.none, { ..self, answered: true, loading: false })
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
fn HoverController::decorations(
  self : HoverController,
) -> Array[@decorations.Decoration] {
  match self.view {
    Some(hover) => [Decoration(hover.range, HoverHighlight, "has-hover")]
    None => []
  }
}

///|
/// Renders the hover widget inside `.code-lines`, anchored at the hovered
/// range like VS Code's editor hover: above the line by default, flipped
/// below when the measured widget would leave the viewport, and shifted left
/// when it would overflow the viewer's right edge. While the provider is
/// still resolving past the loading delay, an unmeasured loading hover is
/// shown at the anchor instead.
fn HoverController::widget(
  self : HoverController,
  frame : @renderer.RenderFrame,
) -> @html.Html? {
  match self.view {
    Some(hover) =>
      self.anchored_widget(frame, hover.range.start, hover.contents, true)
    None =>
      if self.loading {
        match self.anchor {
          Some(anchor) =>
            self.anchored_widget(frame, anchor.start, "Loading...", false)
          None => None
        }
      } else {
        None
      }
  }
}

///|
fn HoverController::anchored_widget(
  self : HoverController,
  frame : @renderer.RenderFrame,
  anchor_offset : Int,
  contents : String,
  measured : Bool,
) -> @html.Html? {
  match line_col_for_offset(frame, anchor_offset) {
    Some((line_number, column)) => {
      let mut class_name = "hover-widget"
      let mut shift_left = 0.0
      let mut below = false
      match self.placement {
        Some(placement) => {
          below = placement.below
          shift_left = placement.shift_left
        }
        None => if measured { class_name = class_name + " measuring" }
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
        attrs = attrs.style("margin-left", "-" + shift_left.to_string() + "px")
      }
      Some(
        @html.div(class=class_name, attrs~, [
          @html.div(class="hover-row", [
            @html.div(class="hover-contents", contents),
          ]),
        ]),
      )
    }
    None => None
  }
}

///|
/// Measures the rendered hover widget after paint and reports whether it
/// must flip below the anchor line or shift left to stay inside the viewer.
fn measure_hover_cmd(emit : @rabbita.Emit[ViewerMsg]) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    scheduler => {
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
          scheduler.add(emit(HoverMeasured(below, shift_left)))
        }
        _ => ()
      }
    },
    kind=@cmd.after_render,
  )
}
