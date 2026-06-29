///|
/// Typed editor events produced by the input bridge. Feature controllers
/// consume these the way VS Code contributions consume editor events; no
/// controller sees raw DOM events.
priv enum EditorEvent {
  MouseMoved(@viewer_common.MouseTarget)
  MouseLeft
  EscapePressed
}

///|
/// Read-only viewer state controllers may consult while handling an event.
/// `view_to_model_offset` resolves a view position to a model document offset
/// through the active `CoordinatesConverter` and model snapshot — Monaco's
/// view→model boundary — so controllers anchor on the model without a bespoke
/// render-line offset helper.
priv struct EditorContext {
  frame : @view_model.RenderFrame?
  view_to_model_offset : (@base_common.Position) -> Int
}

///|
fn Viewer::editor_context(self : Viewer) -> EditorContext {
  {
    frame: self.frame,
    view_to_model_offset: view_position => {
      self.view_position_to_model_offset(view_position)
    },
  }
}

///|
/// Resolves a view position to a model document offset, routing through the
/// `CoordinatesConverter` (view→model position) and the model snapshot
/// (model position→offset), the way Monaco resolves a `MouseTarget`'s view
/// position. The offset only appears at this model boundary.
fn Viewer::view_position_to_model_offset(
  self : Viewer,
  view_position : @base_common.Position,
) -> Int {
  let model_position = self.view_to_model(view_position)
  match self.text_model {
    Some(model) => model.snapshot().offset_at_position(model_position)
    None => model_position.column
  }
}

///|
/// Mouse-move entry point (Monaco's `ContentHoverController._onEditorMouseMove`).
/// Once a hover widget is on screen, a move off the anchor is debounced by
/// `hover_hiding_delay_ms` so the pointer can travel onto the widget without it
/// closing; before the widget is visible the move reacts immediately. The
/// pointer entering the widget cancels the deferred reaction (see
/// `Viewer::keep_hover_open`).
fn Viewer::on_mouse_moved(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  self.hover_pending_target = Some(target)
  if self.hover.widget_visible() {
    // Grace period: keep the earliest pending timer (Monaco only schedules when
    // the runner is not already scheduled), so the reaction fires once the delay
    // elapses unless the pointer reaches the widget first.
    if !self.hover_react_pending {
      self.hover_react_pending = true
      let token = self.hover_react_token
      set_timeout(
        () => {
          if self.hover_react_pending && token == self.hover_react_token {
            self.run_hover_react()
          }
        },
        hover_hiding_delay_ms,
      )
      |> ignore
    }
  } else {
    self.run_hover_react()
  }
}

///|
/// Reacts to the latest mouse position, dispatching it as a `MouseMoved` event.
fn Viewer::run_hover_react(self : Viewer) -> Unit {
  self.hover_react_pending = false
  match self.hover_pending_target {
    Some(target) => self.dispatch_editor_event(MouseMoved(target))
    None => ()
  }
}

///|
/// Cancels any deferred mouse-move reaction (Monaco's
/// `_reactToEditorMouseMoveRunner.cancel()`). Bumping the token invalidates a
/// timer that is already in flight.
fn Viewer::cancel_hover_react(self : Viewer) -> Unit {
  self.hover_react_token += 1
  self.hover_react_pending = false
  self.hover_pending_target = None
}

///|
/// The pointer is on the hover widget: keep the current hover and drop any
/// pending hide. Monaco's `_shouldKeepCurrentHover` short-circuit when the mouse
/// is over the content hover widget.
fn Viewer::keep_hover_open(self : Viewer) -> Unit {
  self.cancel_hover_react()
}

///|
/// Hides the hover and drops any deferred mouse-move reaction, so a stale
/// pending target cannot re-open it after an imperative dismiss (mouse-down,
/// fold toggle, model reset, Escape). Monaco's `hideContentHover()` pairs with
/// `_cancelScheduler()`. Callers own their own re-render.
fn Viewer::dismiss_hover(self : Viewer) -> Unit {
  self.cancel_hover_react()
  self.hover = self.hover.cleared()
}

///|
/// Fans one editor event to every controller in a fixed order and applies
/// their effects; the contribution model with imperative sub-updates.
/// Hover is the only controller today.
fn Viewer::dispatch_editor_event(self : Viewer, event : EditorEvent) -> Unit {
  // A pointer leaving the editor or Escape hides immediately and must drop any
  // deferred mouse-move reaction so a stale target cannot re-open the hover.
  match event {
    MouseLeft | EscapePressed => self.cancel_hover_react()
    MouseMoved(_) => ()
  }
  let before = self.hover
  let (effect, hover) = self.hover.on_event(event, self.editor_context())
  self.hover = hover
  self.apply_hover_effect(effect)
  self.after_hover_transition(before)
}

///|
/// Repaints after a hover transition. The hover highlight is baked into
/// the line HTML as a span decoration, so a changed hover view also
/// invalidates the rendered lines.
fn Viewer::after_hover_transition(
  self : Viewer,
  before : HoverController,
) -> Unit {
  if before == self.hover {
    return
  }
  if before.view != self.hover.view {
    self.content_generation += 1
  }
  self.schedule_render()
}

///|
/// Interprets a hover transition. Monaco's `HoverOperation.start(Delayed)`
/// schedules only the async trigger and the loading message up front; the sync
/// trigger is scheduled by the async trigger (see `hover_trigger_async`).
fn Viewer::apply_hover_effect(self : Viewer, effect : HoverEffect) -> Unit {
  match effect {
    HoverNoEffect => ()
    HoverScheduleDelayed(token) => {
      set_timeout(() => self.hover_trigger_async(token), hover_first_wait_ms)
      |> ignore
      set_timeout(
        () => self.hover_trigger_loading(token),
        hover_loading_message_ms,
      )
      |> ignore
    }
  }
}

///|
/// Monaco `_triggerAsyncComputation` fired (at `hover_first_wait_ms`): advance
/// the operation to `SecondWait`, schedule the sync compute at
/// `hover_second_wait_ms`, and kick the streamed async compute. No view changes
/// yet (emission is still suppressed), so no re-render is needed here.
fn Viewer::hover_trigger_async(self : Viewer, token : Int) -> Unit {
  let (proceed, hover) = self.hover.op_trigger_async(token)
  self.hover = hover
  if proceed {
    set_timeout(() => self.hover_trigger_sync(token), hover_second_wait_ms)
    |> ignore
    self.kick_hover_async(token)
  }
}

///|
/// Monaco `_triggerSyncComputation` fired (at the full delay): run the sync
/// participants and feed their parts into the operation.
fn Viewer::hover_trigger_sync(self : Viewer, token : Int) -> Unit {
  if token != self.hover.operation.token {
    return
  }
  let before = self.hover
  self.hover = self.hover.op_trigger_sync(token, self.compute_hover_sync(token))
  self.after_hover_transition(before)
  self.maybe_notify_hover_resolved(token)
}

///|
/// Monaco `_triggerLoadingMessage` fired (at three times the delay): show the
/// loading message if the async compute is still pending.
fn Viewer::hover_trigger_loading(self : Viewer, token : Int) -> Unit {
  if token != self.hover.operation.token {
    return
  }
  let before = self.hover
  self.hover = self.hover.op_trigger_loading(token)
  self.after_hover_transition(before)
}

///|
/// Builds a content-hover computer over the current viewer services (Monaco
/// `ContentHoverWidgetWrapper._initializeHoverParticipants`).
fn Viewer::make_hover_computer(self : Viewer) -> @hover.ContentHoverComputer {
  let services : @hover.HoverParticipantServices = {
    languages: self.services.languages,
    marker_decorations: self.services.marker_decorations,
    log_service: self.services.log_service,
  }
  @hover.ContentHoverComputer::new(services)
}

///|
/// Runs the synchronous hover participants for the current anchor.
fn Viewer::compute_hover_sync(
  self : Viewer,
  token : Int,
) -> Array[@hover.HoverPart] {
  match (self.text_model, self.hover.anchor) {
    (Some(model), Some(anchor)) =>
      if token != self.hover.operation.token {
        []
      } else {
        match
          self
          .make_hover_computer()
          .compute_sync(
            model,
            OffsetRange(anchor.start, anchor.end),
            anchor.offset,
            injected_text_index=anchor.injected_text_index,
            inlay_hints=self.inlay_hints,
          ) {
          Some(hover) => hover.parts
          None => []
        }
      }
    _ => []
  }
}

///|
/// Kicks the streamed async hover compute (Monaco `computeAsync`): each
/// participant's parts are fed to the operation as they resolve, then the
/// operation is marked done. Results carry the requesting model and anchor token
/// so stale responses are dropped at their guards.
fn Viewer::kick_hover_async(self : Viewer, token : Int) -> Unit {
  match (self.text_model, self.hover.anchor) {
    (Some(model), Some(anchor)) => {
      let computer = self.make_hover_computer()
      let range = @base_common.OffsetRange(anchor.start, anchor.end)
      let offset = anchor.offset
      let injected_text_index = anchor.injected_text_index
      let inlay_hints = self.inlay_hints
      @js.async_run(() => {
        computer.compute_async_each(
          model,
          range,
          offset,
          injected_text_index~,
          inlay_hints~,
          emit=parts => self.hover_async_item(model, token, parts),
        )
        self.hover_async_done(model, token)
      })
    }
    _ => ()
  }
}

///|
fn Viewer::hover_async_item(
  self : Viewer,
  model : @model.TextModel,
  token : Int,
  parts : Array[@hover.HoverPart],
) -> Unit {
  if !self.is_current_model(model) || token != self.hover.operation.token {
    return
  }
  let before = self.hover
  self.hover = self.hover.op_async_item(token, parts)
  self.after_hover_transition(before)
}

///|
fn Viewer::hover_async_done(
  self : Viewer,
  model : @model.TextModel,
  token : Int,
) -> Unit {
  if !self.is_current_model(model) || token != self.hover.operation.token {
    return
  }
  let before = self.hover
  self.hover = self.hover.op_async_done(token)
  self.after_hover_transition(before)
  self.maybe_notify_hover_resolved(token)
}

///|
/// Fires the public hover-resolution status exactly once per anchor, when the
/// operation completes (reaches `Idle`): `ok` reports whether any hover content
/// was produced. Replaces the old per-result notification.
fn Viewer::maybe_notify_hover_resolved(self : Viewer, token : Int) -> Unit {
  if token != self.hover.operation.token || !self.hover.is_complete() {
    return
  }
  if self.hover_notified_token == token {
    return
  }
  self.hover_notified_token = token
  let revision = match self.text_model {
    Some(model) => model.revision
    None => ""
  }
  self.did_resolve_hover.fire({ ok: self.hover.view is Some(_), revision })
}

///|
/// Span decorations contributed by every controller for the current state.
fn Viewer::controller_decorations(
  self : Viewer,
) -> Array[@decorations.Decoration] {
  match self.text_model {
    Some(model) => self.hover.decorations(model.snapshot)
    None => []
  }
}

///|
fn Viewer::is_current_model(self : Viewer, model : @model.TextModel) -> Bool {
  match self.text_model {
    Some(current) => current.same_identity_and_version(model)
    None => false
  }
}
