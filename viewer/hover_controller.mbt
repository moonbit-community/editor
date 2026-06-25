///|
priv struct HoverView {
  range : @base_common.OffsetRange
  parts : Array[@hover.HoverPart]
} derive(Eq)

///|
priv struct HoverAnchor {
  start : Int
  end : Int
  offset : Int
  injected_text_index : Int
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
/// VS Code's default `editor.hover.hidingDelay`: once the widget is on screen,
/// a mouse move off the anchor is debounced by this grace period before the
/// hover reacts, so the pointer can travel onto the hover widget without it
/// closing. Mirrors `ContentHoverController`'s `_reactToEditorMouseMoveRunner`
/// scheduled at `hidingDelay`.
let hover_hiding_delay_ms = 300

///|
/// What a hover transition asks the viewer to do; the controller stays a
/// pure state machine and the viewer interprets these (timers through the
/// browser-host timer bindings, provider requests through the registry).
priv enum HoverEffect {
  HoverNoEffect
  /// Start the half/full/triple delay timers for this anchor token.
  HoverSchedule(Int)
  /// Ask the hover provider at this offset for this token.
  HoverRequest(HoverAnchor, Int)
}

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
  event : EditorEvent,
  ctx : EditorContext,
) -> (HoverEffect, HoverController) {
  match event {
    MouseMoved(target) =>
      match ctx.frame {
        Some(frame) =>
          match
            span_anchor_for_target(frame, target, ctx.view_to_model_offset) {
            Some((start, end, span)) =>
              self.schedule(
                start,
                end,
                injected_text_index=span.injected_text_index,
              )
            None => (HoverNoEffect, self.cleared())
          }
        None => (HoverNoEffect, self)
      }
    MouseLeft | EscapePressed => (HoverNoEffect, self.cleared())
  }
}

///|
/// A new anchor restarts the timers; the same anchor keeps the pending or
/// shown hover untouched.
fn HoverController::schedule(
  self : HoverController,
  start : Int,
  end : Int,
  injected_text_index? : Int = -1,
) -> (HoverEffect, HoverController) {
  let same = match self.anchor {
    Some(anchor) =>
      anchor.start == start &&
      anchor.end == end &&
      anchor.injected_text_index == injected_text_index
    None => false
  }
  if same {
    (HoverNoEffect, self)
  } else {
    let token = self.token + 1
    (
      HoverSchedule(token),
      {
        token,
        anchor: Some({
          start,
          end,
          offset: (start + end) / 2,
          injected_text_index,
        }),
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
  token : Int,
) -> (HoverEffect, HoverController) {
  if token == self.token {
    match self.anchor {
      Some(anchor) => (HoverRequest(anchor, token), self)
      None => (HoverNoEffect, self)
    }
  } else {
    (HoverNoEffect, self)
  }
}

///|
/// Full-delay timer fired: open the display gate and promote an already
/// resolved hover.
fn HoverController::display_due(
  self : HoverController,
  token : Int,
) -> HoverController {
  if token != self.token {
    return self
  }
  match self.pending_view {
    Some(view) =>
      {
        ..self,
        display_open: true,
        view: Some(view),
        pending_view: None,
        placement: None,
      }
    None => { ..self, display_open: true }
  }
}

///|
/// Triple-delay timer fired with no provider answer: show a loading hover.
fn HoverController::loading_due(
  self : HoverController,
  token : Int,
) -> HoverController {
  if token == self.token && !self.answered && self.anchor is Some(_) {
    { ..self, loading: true }
  } else {
    self
  }
}

///|
/// A hover provider result arrived. Results are dropped when the document
/// revision moved on or the anchor token changed since the request.
fn HoverController::resolved_hover(
  self : HoverController,
  notify : (ViewerHoverResolvedEvent) -> Unit,
  revision : String,
  token : Int,
  hover : @hover.ComputedHover?,
) -> HoverController {
  if token != self.token {
    return self
  }
  match hover {
    Some(hover) => {
      notify({ ok: true, revision })
      let view : HoverView = { range: hover.range, parts: hover.parts }
      if self.display_open {
        {
          ..self,
          answered: true,
          loading: false,
          view: Some(merge_hover_view(self.view, view)),
          pending_view: None,
          placement: None,
        }
      } else {
        {
          ..self,
          answered: true,
          loading: false,
          pending_view: Some(merge_hover_view(self.pending_view, view)),
        }
      }
    }
    None => {
      if self.view is None && self.pending_view is None {
        notify({ ok: false, revision })
      }
      { ..self, answered: true, loading: false }
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
/// What the hover layer should draw, as data: the widget anchored at the
/// hovered range like VS Code's editor hover (above the line by default,
/// flipped below when the after-write measurement detects viewport
/// overflow, shifted left when it would overflow the right edge), or the
/// unmeasured loading hover while the provider is still resolving past
/// the loading delay.
priv struct HoverWidgetView {
  anchor_offset : Int
  parts : Array[@hover.HoverPart]
  /// Whether this widget participates in placement measurement (the
  /// loading hover renders unmeasured at the anchor).
  measurable : Bool
  placement : HoverPlacement?
}

///|
/// Whether a hover widget is currently on screen (resolved content or the
/// loading placeholder). Monaco's `_contentWidget.isVisible`; the mouse-move
/// grace period only applies once the widget is shown.
fn HoverController::widget_visible(self : HoverController) -> Bool {
  self.widget_view() is Some(_)
}

///|
fn HoverController::widget_view(self : HoverController) -> HoverWidgetView? {
  match self.view {
    Some(hover) =>
      Some({
        anchor_offset: hover.range.start,
        parts: hover.parts,
        measurable: true,
        placement: self.placement,
      })
    None =>
      if self.loading {
        match self.anchor {
          Some(anchor) =>
            Some({
              anchor_offset: anchor.start,
              parts: [
                LoadingHover(
                  range=OffsetRange(anchor.start, anchor.end),
                  message="Loading...",
                ),
              ],
              measurable: false,
              placement: self.placement,
            })
          None => None
        }
      } else {
        None
      }
  }
}

///|
fn merge_hover_view(existing : HoverView?, incoming : HoverView) -> HoverView {
  match existing {
    Some(view) => {
      let parts = view.parts.copy()
      parts.append(incoming.parts)
      parts.sort_by(@hover.compare_hover_parts)
      {
        range: OffsetRange(
          min_int(view.range.start, incoming.range.start),
          max_int(view.range.end, incoming.range.end),
        ),
        parts,
      }
    }
    None => incoming
  }
}
