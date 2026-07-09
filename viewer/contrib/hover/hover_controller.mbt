///|
pub(all) struct HoverView {
  range : @base_common.Range
  parts : Array[HoverPart]
} derive(Eq)

///|
/// Monaco `IHoverPart.isValidForHoverAnchor` (markdown + marker participants):
/// the part still applies to the new anchor when the anchor is a range anchor
/// and the part's range contains the anchor range (`anchor.type ===
/// HoverAnchorType.Range && startColumn <= anchor.range.startColumn &&
/// endColumn >= anchor.range.endColumn`, the source's column-only comparison).
pub fn hover_part_valid_for_anchor(
  part : HoverPart,
  anchor : HoverAnchor,
) -> Bool {
  guard anchor is HoverRangeAnchor(range=anchor_range, ..) else { return false }
  let range = hover_part_range(part)
  range.start_column <= anchor_range.start_column &&
  range.end_column >= anchor_range.end_column
}

///|
/// Monaco `ContentHoverResult.filter`: keep the parts that are still valid for
/// the new anchor.
pub fn filter_hover_parts(
  parts : Array[HoverPart],
  anchor : HoverAnchor,
) -> Array[HoverPart] {
  let kept : Array[HoverPart] = []
  for part in parts {
    if hover_part_valid_for_anchor(part, anchor) {
      kept.push(part)
    }
  }
  kept
}

///|
/// VS Code's default `editor.hover.delay`.
let hover_delay_ms = 300

///|
/// Monaco `HoverOperation` schedule offsets derived from the hover delay
/// (`hoverOperation.ts`): the async (semantic) compute is kicked at half the
/// delay, the sync (markers / decorations) compute runs after the remaining
/// half — so at the full delay — and a loading message is shown at three times
/// the delay if the async compute has not finished.
pub let hover_first_wait_ms : Int = hover_delay_ms / 2

///|
pub let hover_second_wait_ms : Int = hover_delay_ms - hover_first_wait_ms

///|
pub let hover_loading_message_ms : Int = 3 * hover_delay_ms

///|
/// VS Code's default `editor.hover.hidingDelay`: once the widget is on screen,
/// a mouse move off the anchor is debounced by this grace period before the
/// hover reacts, so the pointer can travel onto the hover widget without it
/// closing. Mirrors `ContentHoverController`'s `_reactToEditorMouseMoveRunner`
/// scheduled at `hidingDelay`.
pub let hover_hiding_delay_ms = 300

///|
/// Monaco `HoverOperationState` (`hoverOperation.ts`). `FirstWait` / `SecondWait`
/// suppress result emission — nothing shows before the hover delay; the two
/// `WaitingForAsync*` states cover the post-delay window while the async compute
/// is still in flight (the second one shows the loading message); `Idle` is the
/// complete (or quiescent) state.
pub(all) enum HoverOpState {
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
pub(all) struct HoverOperation {
  state : HoverOpState
  token : Int
  parts : Array[HoverPart]
  async_done : Bool
} derive(Eq)

///|
pub fn HoverOperation::idle() -> HoverOperation {
  { state: HoverOpIdle, token: 0, parts: [], async_done: false }
}

///|
/// What a hover transition asks the viewer to do; the controller stays a pure
/// state machine and the viewer interprets these (timers through the
/// browser-host timer bindings, computes through the hover computer).
pub(all) enum HoverEffect {
  HoverNoEffect
  /// Delayed start (Monaco `start(Delayed)`): schedule the async trigger at
  /// `hover_first_wait_ms` and the loading message at `hover_loading_message_ms`
  /// for this anchor token.
  HoverScheduleDelayed(Int)
}

///|
/// Editor hover feature state. The timing lives in the embedded `HoverOperation`
/// (Monaco's `HoverOperation`); the controller adds the editor-facing concerns
/// the operation does not: the in-flight anchor and the currently shown result
/// (the `_currentResult` analog — its parts, the anchor it was computed for,
/// and whether it was complete). Placement (above/below, sizing) is the
/// content-hover widget's own state, as in the source
/// (`ContentHoverWidget._positionPreference`).
pub(all) struct HoverController {
  /// Monaco `_hoverOperation.options.anchor`: the anchor the operation is
  /// currently computing for (`None` once cleared).
  anchor : HoverAnchor?
  operation : HoverOperation
  /// Monaco `ContentHoverWidgetWrapper._startHoverOperationIfNecessary`'s
  /// `insistOnKeepingHoverVisible` for the in-flight operation. Set only by the
  /// sticky mouse-getting-closer keep, which the viewer handles at the input
  /// seam, so it is currently always `false` (see the plan's Deviation 11).
  insist_on_keeping : Bool
  /// Monaco `_currentResult`: the shown hover parts (`view`), the anchor that
  /// produced them (`current_anchor`), and whether that result was complete
  /// (`current_complete`). `view` is `None` exactly when no hover is shown.
  view : HoverView?
  current_anchor : HoverAnchor?
  current_complete : Bool
} derive(Eq)

///|
pub fn HoverController::empty() -> HoverController {
  {
    anchor: None,
    operation: HoverOperation::idle(),
    insist_on_keeping: false,
    view: None,
    current_anchor: None,
    current_complete: false,
  }
}

///|
/// Monaco `HoverOperation.cancel()` paired with hiding the widget: drop the
/// in-flight anchor and the shown result, reset the operation to Idle, and rotate
/// the token so in-flight timers and streamed async results are dropped at their
/// guards.
pub fn HoverController::cleared(self : HoverController) -> HoverController {
  {
    anchor: None,
    operation: {
      state: HoverOpIdle,
      token: self.operation.token + 1,
      parts: [],
      async_done: false,
    },
    insist_on_keeping: false,
    view: None,
    current_anchor: None,
    current_complete: false,
  }
}

///|
/// Monaco `ContentHoverWidgetWrapper._startShowingOrUpdateHover`. With no hover
/// shown, start an operation for the anchor. With one shown: the sticky
/// mouse-getting-closer case keeps the current result untouched and kicks an
/// `insist`-update operation at the new anchor; the same anchor keeps the hover
/// untouched; a compatible anchor (same line) keeps the parts still valid for it
/// and kicks a fresh operation; an incompatible anchor hides the current hover
/// and restarts. `sticky_mouse_getting_closer` is computed at the input seam
/// (`sticky && isMouseGettingCloser`, both host concerns).
pub fn HoverController::start_showing_or_update_hover(
  self : HoverController,
  anchor : HoverAnchor,
  sticky_mouse_getting_closer : Bool,
) -> (HoverEffect, HoverController) {
  let content_hover_is_visible = self.view is Some(_)
  if !content_hover_is_visible {
    return self.start_hover_operation_if_necessary(anchor, insist=false)
  }
  // The pointer is approaching the shown hover: keep the current result
  // untouched and kick an operation that insists on keeping it visible.
  if sticky_mouse_getting_closer {
    return self.start_hover_operation_if_necessary(anchor, insist=true)
  }
  // A hover is shown. The new anchor equals the shown one: keep it untouched.
  match self.current_anchor {
    Some(current) =>
      if hover_anchor_equals(current, anchor) {
        return (HoverNoEffect, self)
      }
    None => ()
  }
  let compatible = match self.current_anchor {
    Some(current) => hover_anchor_can_adopt(anchor, current)
    None => false
  }
  if !compatible {
    // Hide the incompatible hover, then start a fresh operation.
    let hidden = self.set_current_result([], false, anchor)
    return hidden.start_hover_operation_if_necessary(anchor, insist=false)
  }
  // Compatible: keep the parts still valid for the new anchor (Monaco
  // `_currentResult.filter(anchor)`, which preserves the previous anchor and
  // completeness), then kick a fresh operation.
  let filtered_parts = match self.view {
    Some(view) => filter_hover_parts(view.parts, anchor)
    None => []
  }
  let result_anchor = match self.current_anchor {
    Some(current) => current
    None => anchor
  }
  let filtered = self.set_current_result(
    filtered_parts,
    self.current_complete,
    result_anchor,
  )
  filtered.start_hover_operation_if_necessary(anchor, insist=false)
}

///|
/// Monaco `ContentHoverWidgetWrapper._startHoverOperationIfNecessary`: skip when
/// the operation is already computing this anchor; otherwise cancel the previous
/// operation (rotating the token so its timers / async results are dropped) and
/// arm a fresh delayed operation. The shown result is left untouched — it is
/// replaced only when the new operation produces one.
pub fn HoverController::start_hover_operation_if_necessary(
  self : HoverController,
  anchor : HoverAnchor,
  insist~ : Bool,
) -> (HoverEffect, HoverController) {
  match self.anchor {
    Some(current) =>
      if hover_anchor_equals(current, anchor) {
        return (HoverNoEffect, self)
      }
    None => ()
  }
  let token = self.operation.token + 1
  (
    HoverScheduleDelayed(token),
    {
      ..self,
      anchor: Some(anchor),
      operation: {
        state: HoverOpFirstWait,
        token,
        parts: [],
        async_done: false,
      },
      insist_on_keeping: insist,
    },
  )
}

///|
/// Monaco `_triggerAsyncComputation`: move to `SecondWait`. The viewer then
/// schedules the sync compute at `hover_second_wait_ms` and kicks the async
/// compute. Returns whether the transition applied (the token is still current);
/// a stale timer is a no-op. Invoking this then `op_trigger_sync` back to back
/// — without the schedulers — is Monaco's immediate (`start(Immediate)`) path.
pub fn HoverController::op_trigger_async(
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
pub fn HoverController::op_trigger_sync(
  self : HoverController,
  token : Int,
  sync_parts : Array[HoverPart],
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
pub fn HoverController::op_trigger_loading(
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
pub fn HoverController::op_async_item(
  self : HoverController,
  token : Int,
  parts : Array[HoverPart],
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
pub fn HoverController::op_async_done(
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
/// Monaco `HoverOperation._fireResult` feeding `ContentHoverWidgetWrapper._withResult`.
/// `_fireResult` suppresses results before the hover delay (`FirstWait` /
/// `SecondWait`). `_withResult` then gates the swap: while a complete hover is
/// already shown, a still-incomplete result is held back (no flicker to a partial
/// result); a complete-but-empty result is held back too when the operation
/// insisted on keeping the hover visible; otherwise the accumulated parts become
/// the shown result via `_setCurrentResult`.
pub fn HoverController::emit(self : HoverController) -> HoverController {
  match self.operation.state {
    HoverOpFirstWait | HoverOpSecondWait => self
    _ => {
      let result_anchor = match self.anchor {
        Some(anchor) => anchor
        None => return self
      }
      let result_parts = self.operation.parts
      let result_is_complete = self.operation.state is HoverOpIdle
      let previous_visible_complete = self.view is Some(_) &&
        self.current_complete
      let updated = if !previous_visible_complete {
        self.set_current_result(result_parts, result_is_complete, result_anchor)
      } else {
        self
      }
      if !result_is_complete {
        return updated
      }
      let result_empty = result_parts.length() == 0
      let should_keep_previous = result_empty && self.insist_on_keeping
      if should_keep_previous {
        return updated
      }
      updated.set_current_result(
        result_parts, result_is_complete, result_anchor,
      )
    }
  }
}

///|
/// Monaco `ContentHoverWidgetWrapper._setCurrentResult`: dedupe an unchanged
/// result, treat an empty result as hiding the hover, and otherwise show the
/// sorted parts.
pub fn HoverController::set_current_result(
  self : HoverController,
  parts : Array[HoverPart],
  is_complete : Bool,
  result_anchor : HoverAnchor,
) -> HoverController {
  if parts.length() == 0 {
    // An empty result hides the hover (Monaco maps it to `null`).
    return match self.view {
      None => self
      Some(_) =>
        { ..self, view: None, current_anchor: None, current_complete: false }
    }
  }
  let sorted = parts.copy()
  sorted.sort_by(compare_hover_parts)
  // Dedupe: identical shown parts at the same completeness are a no-op.
  match self.view {
    Some(existing) =>
      if existing.parts == sorted && self.current_complete == is_complete {
        return self
      }
    None => ()
  }
  let range = hover_parts_range(sorted, result_anchor.range())
  let new_view : HoverView = { range, parts: sorted }
  {
    ..self,
    view: Some(new_view),
    current_anchor: Some(result_anchor),
    current_complete: is_complete,
  }
}

///|
/// Whether the async compute has finished for the current operation; the viewer
/// reads this to fire the resolution status exactly once per anchor.
pub fn HoverController::is_complete(self : HoverController) -> Bool {
  self.operation.state is HoverOpIdle
}

///|
/// The hover highlight's model decoration, Monaco's
/// `ContentHoverController` `_highlightDecorations` collection entry
/// (`className: 'hoverHighlight'`, `contentHoverWidgetParticipants`): the
/// range under the visible hover, used directly.
pub fn HoverController::highlight_decorations(
  self : HoverController,
) -> Array[@model.ModelDeltaDecoration] {
  match self.view {
    Some(hover) =>
      [
        {
          range: hover.range,
          options: ModelDecorationOptions(
            "hoverHighlight",
            description="content-hover-highlight",
          ),
        },
      ]
    None => []
  }
}

///|
/// What the hover widget should show, as data: the anchor range and the
/// resolved hover parts (or the loading placeholder while the async compute
/// is still resolving past the loading delay). The `Viewer` renders this into
/// a `RenderedContentHover` and drives the content-hover widget's `show` /
/// `hide` when it changes — Monaco's `_setCurrentResult` →
/// `_showHover`/`_hideHover` seam. Placement is the widget's own concern.
pub(all) struct HoverWidgetView {
  anchor_range : @base_common.Range
  parts : Array[HoverPart]
} derive(Eq)

///|
/// Whether a hover widget is currently on screen (resolved content or the
/// loading placeholder). Monaco's `_contentWidget.isVisible`; the mouse-move
/// grace period only applies once the widget is shown.
pub fn HoverController::widget_visible(self : HoverController) -> Bool {
  self.widget_view() is Some(_)
}

///|
pub fn HoverController::widget_view(self : HoverController) -> HoverWidgetView? {
  match self.view {
    Some(hover) => Some({ anchor_range: hover.range, parts: hover.parts })
    None =>
      match self.operation.state {
        HoverOpWaitingForAsyncShowingLoading =>
          match self.anchor {
            Some(anchor) =>
              Some({
                anchor_range: anchor.range(),
                parts: [
                  LoadingHover(range=anchor.range(), message="Loading..."),
                ],
              })
            None => None
          }
        _ => None
      }
  }
}
