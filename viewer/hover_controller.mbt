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
/// The placement decided by the read-after-write measurement pass: which side
/// of the anchor the widget renders on, how far it shifts left to stay inside
/// the editor, and the available-space height cap (Monaco
/// `ContentHoverWidget._findMaximumRenderingHeight`) the content scrolls within.
priv struct HoverPlacement {
  below : Bool
  shift_left : Double
  max_height : Double
} derive(Eq)

///|
/// VS Code's default `editor.hover.delay`.
let hover_delay_ms = 300

///|
/// Monaco `HoverOperation` schedule offsets derived from the hover delay
/// (`hoverOperation.ts`): the async (semantic) compute is kicked at half the
/// delay, the sync (markers / decorations) compute runs after the remaining
/// half — so at the full delay — and a loading message is shown at three times
/// the delay if the async compute has not finished.
let hover_first_wait_ms : Int = hover_delay_ms / 2

///|
let hover_second_wait_ms : Int = hover_delay_ms - hover_first_wait_ms

///|
let hover_loading_message_ms : Int = 3 * hover_delay_ms

///|
/// VS Code's default `editor.hover.hidingDelay`: once the widget is on screen,
/// a mouse move off the anchor is debounced by this grace period before the
/// hover reacts, so the pointer can travel onto the hover widget without it
/// closing. Mirrors `ContentHoverController`'s `_reactToEditorMouseMoveRunner`
/// scheduled at `hidingDelay`.
let hover_hiding_delay_ms = 300

///|
/// Monaco `HoverOperationState` (`hoverOperation.ts`). `FirstWait` / `SecondWait`
/// suppress result emission — nothing shows before the hover delay; the two
/// `WaitingForAsync*` states cover the post-delay window while the async compute
/// is still in flight (the second one shows the loading message); `Idle` is the
/// complete (or quiescent) state.
priv enum HoverOpState {
  HoverOpIdle
  HoverOpFirstWait
  HoverOpSecondWait
  HoverOpWaitingForAsync
  HoverOpWaitingForAsyncShowingLoading
} derive(Eq)

///|
/// Monaco `HoverOperation`: the fine-tuned hover timing / aggregation core. It
/// is a pure state container; the viewer drives the three debounced schedulers
/// and the sync / async computes (through the browser-host timers and the
/// participant registry) and feeds their results back through the transition
/// methods. `parts` is Monaco's accumulating `_result`; `token` rotates per
/// anchor so stale timers and streamed async results are dropped at their guards
/// (the role Monaco's scheduler / iterable cancellation plays).
priv struct HoverOperation {
  state : HoverOpState
  token : Int
  parts : Array[@hover.HoverPart]
  async_done : Bool
} derive(Eq)

///|
fn HoverOperation::idle() -> HoverOperation {
  { state: HoverOpIdle, token: 0, parts: [], async_done: false }
}

///|
/// What a hover transition asks the viewer to do; the controller stays a pure
/// state machine and the viewer interprets these (timers through the
/// browser-host timer bindings, computes through the hover computer).
priv enum HoverEffect {
  HoverNoEffect
  /// Delayed start (Monaco `start(Delayed)`): schedule the async trigger at
  /// `hover_first_wait_ms` and the loading message at `hover_loading_message_ms`
  /// for this anchor token.
  HoverScheduleDelayed(Int)
}

///|
/// Editor hover feature state. The timing lives in the embedded `HoverOperation`
/// (Monaco's `HoverOperation`); the controller adds the editor-facing concerns
/// the operation does not: the anchor, the shown view, and its measured
/// placement.
priv struct HoverController {
  anchor : HoverAnchor?
  operation : HoverOperation
  view : HoverView?
  placement : HoverPlacement?
} derive(Eq)

///|
fn HoverController::empty() -> HoverController {
  {
    anchor: None,
    operation: HoverOperation::idle(),
    view: None,
    placement: None,
  }
}

///|
/// Monaco `HoverOperation.cancel()` paired with hiding the widget: drop the
/// anchor and the shown view, reset the operation to Idle, and rotate the token
/// so in-flight timers and streamed async results are dropped at their guards.
fn HoverController::cleared(self : HoverController) -> HoverController {
  {
    anchor: None,
    operation: {
      state: HoverOpIdle,
      token: self.operation.token + 1,
      parts: [],
      async_done: false,
    },
    view: None,
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
            token_anchor_for_target(frame, target, ctx.view_to_model_offset) {
            Some((start, end, injected_text_index)) =>
              self.start_delayed(start, end, injected_text_index~)
            None => (HoverNoEffect, self.cleared())
          }
        None => (HoverNoEffect, self)
      }
    EscapePressed => (HoverNoEffect, self.cleared())
  }
}

///|
/// Monaco `HoverOperation.start(Delayed)`: a new anchor rotates the token and
/// arms the operation (Idle → FirstWait), asking the viewer to schedule the
/// async and loading timers. The same anchor keeps the in-flight or shown hover
/// untouched.
fn HoverController::start_delayed(
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
    return (HoverNoEffect, self)
  }
  let token = self.operation.token + 1
  let anchor : HoverAnchor = {
    start,
    end,
    offset: (start + end) / 2,
    injected_text_index,
  }
  (
    HoverScheduleDelayed(token),
    {
      anchor: Some(anchor),
      operation: {
        state: HoverOpFirstWait,
        token,
        parts: [],
        async_done: false,
      },
      view: None,
      placement: None,
    },
  )
}

///|
/// Monaco `_triggerAsyncComputation`: move to `SecondWait`. The viewer then
/// schedules the sync compute at `hover_second_wait_ms` and kicks the async
/// compute. Returns whether the transition applied (the token is still current);
/// a stale timer is a no-op. Invoking this then `op_trigger_sync` back to back
/// — without the schedulers — is Monaco's immediate (`start(Immediate)`) path.
fn HoverController::op_trigger_async(
  self : HoverController,
  token : Int,
) -> (Bool, HoverController) {
  if token != self.operation.token {
    return (false, self)
  }
  (true, { ..self, operation: { ..self.operation, state: HoverOpSecondWait } })
}

///|
/// Monaco `_triggerSyncComputation`: append the sync parts, then move to `Idle`
/// if the async compute already finished or `WaitingForAsync` otherwise, and
/// emit the accumulated result.
fn HoverController::op_trigger_sync(
  self : HoverController,
  token : Int,
  sync_parts : Array[@hover.HoverPart],
) -> HoverController {
  if token != self.operation.token {
    return self
  }
  let parts = self.operation.parts.copy()
  parts.append(sync_parts)
  let state = if self.operation.async_done {
    HoverOpIdle
  } else {
    HoverOpWaitingForAsync
  }
  { ..self, operation: { ..self.operation, parts, state } }.emit()
}

///|
/// Monaco `_triggerLoadingMessage`: when still waiting on the async compute,
/// switch to showing the loading message.
fn HoverController::op_trigger_loading(
  self : HoverController,
  token : Int,
) -> HoverController {
  if token != self.operation.token {
    return self
  }
  match self.operation.state {
    HoverOpWaitingForAsync =>
      {
        ..self,
        operation: {
          ..self.operation,
          state: HoverOpWaitingForAsyncShowingLoading,
        },
      }.emit()
    _ => self
  }
}

///|
/// One streamed async result arrived (Monaco pushes each iterable item onto
/// `_result` and re-fires): accumulate and emit.
fn HoverController::op_async_item(
  self : HoverController,
  token : Int,
  parts : Array[@hover.HoverPart],
) -> HoverController {
  if token != self.operation.token {
    return self
  }
  let merged = self.operation.parts.copy()
  merged.append(parts)
  { ..self, operation: { ..self.operation, parts: merged } }.emit()
}

///|
/// The async compute finished (Monaco's `_asyncIterableDone`): mark it done and,
/// if we were waiting on it, complete to `Idle`, then emit.
fn HoverController::op_async_done(
  self : HoverController,
  token : Int,
) -> HoverController {
  if token != self.operation.token {
    return self
  }
  let done = { ..self.operation, async_done: true }
  let advanced = match done.state {
    HoverOpWaitingForAsync | HoverOpWaitingForAsyncShowingLoading =>
      { ..done, state: HoverOpIdle }
    _ => done
  }
  { ..self, operation: advanced }.emit()
}

///|
/// Monaco `HoverOperation._fireResult`: results are suppressed before the hover
/// delay (`FirstWait` / `SecondWait`); otherwise the accumulated parts become
/// the shown view. Placement is reset only when the shown parts actually change,
/// so streamed additions re-measure but identical re-emits keep their placement.
fn HoverController::emit(self : HoverController) -> HoverController {
  match self.operation.state {
    HoverOpFirstWait | HoverOpSecondWait => self
    _ => {
      if self.operation.parts.length() == 0 {
        return { ..self, view: None }
      }
      let parts = self.operation.parts.copy()
      parts.sort_by(@hover.compare_hover_parts)
      // The fallback anchor span is built inline so the expected `OffsetRange`
      // type flows from `hover_parts_range`'s parameter (the bare constructor
      // does not resolve without an expected type on the JS target).
      let range = @hover.hover_parts_range(
        parts,
        match self.anchor {
          Some(anchor) => OffsetRange(anchor.start, anchor.end)
          None => OffsetRange(0, 0)
        },
      )
      let new_view : HoverView = { range, parts }
      let placement = match self.view {
        Some(existing) =>
          if existing.parts == new_view.parts {
            self.placement
          } else {
            None
          }
        None => None
      }
      { ..self, view: Some(new_view), placement }
    }
  }
}

///|
/// Whether the async compute has finished for the current operation; the viewer
/// reads this to fire the resolution status exactly once per anchor.
fn HoverController::is_complete(self : HoverController) -> Bool {
  self.operation.state is HoverOpIdle
}

///|
fn HoverController::measured(
  self : HoverController,
  below : Bool,
  shift_left : Double,
  max_height : Double,
) -> HoverController {
  { ..self, placement: Some({ below, shift_left, max_height }) }
}

///|
fn HoverController::decorations(
  self : HoverController,
  snapshot : @model.TextSnapshot,
) -> Array[@decorations.Decoration] {
  // The hover view holds an offset span (the widget anchors by offset);
  // decorations are line/column `Range`, so convert at this boundary.
  match self.view {
    Some(hover) =>
      [Decoration(snapshot.range_of(hover.range), HoverHighlight, "has-hover")]
    None => []
  }
}

///|
/// What the hover layer should draw, as data: the widget anchored at the
/// hovered range like VS Code's editor hover (above the line by default,
/// flipped below when the after-write measurement detects viewport
/// overflow, shifted left when it would overflow the right edge), or the
/// unmeasured loading hover while the async compute is still resolving past
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
      match self.operation.state {
        HoverOpWaitingForAsyncShowingLoading =>
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
        _ => None
      }
  }
}
