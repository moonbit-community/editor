///|
/// Typed editor events produced by the input bridge. Feature controllers
/// consume these the way VS Code contributions consume editor events; no
/// controller sees raw DOM events.
priv enum EditorEvent {
  MouseMoved(@viewer_common.MouseTarget)
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
/// Monaco `ContentHoverController._onEditorMouseMove`. Records the move; keeps
/// the current hover (cancelling the reaction) when the pointer is on it
/// (sticky) or keep-open is set; gives a visible sticky hover the `hidingDelay`
/// grace period — so the pointer can travel onto the widget without it closing —
/// before reacting; otherwise reacts immediately. The grace runner mirrors
/// Monaco's "only schedule when not already scheduled". `posx` / `posy` are read
/// from the last recorded pointer position (`record_hover_pointer`).
fn Viewer::on_editor_mouse_move(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  if self.hover_ignore_mouse_events {
    return
  }
  self.hover_pending_target = Some(target)
  let mouse_on_widget = self.mouse_on_hover_widget(
    self.hover_mouse_posx,
    self.hover_mouse_posy,
  )
  if should_keep_current_hover(
      self.hover_keep_open,
      self.hover_settings.sticky,
      mouse_on_widget,
    ) {
    self.cancel_hover_react()
    return
  }
  if should_reschedule_hover(
      self.hover.widget_visible(),
      self.hover_settings.sticky,
      self.hover_settings.hiding_delay,
    ) {
    if !self.hover_react_pending {
      self.hover_react_pending = true
      let token = self.hover_react_token
      set_timeout(
        () => {
          if self.hover_react_pending && token == self.hover_react_token {
            self.run_hover_react()
          }
        },
        self.hover_settings.hiding_delay,
      )
      |> ignore
    }
    return
  }
  self.react_to_editor_mouse_move()
}

///|
/// Monaco `ContentHoverController._reactToEditorMouseMove`: when the hover may be
/// shown for this pointer (`shouldShowHover` — always true for the default
/// `enabled: 'on'`), drive the show-or-update path (Monaco's `showsOrWillShow`,
/// here the `MouseMoved` → `start_delayed` arm, which clears when the pointer is
/// off any token); otherwise, unless the dev sticky flag is set, hide.
fn Viewer::react_to_editor_mouse_move(self : Viewer) -> Unit {
  if should_show_hover(
      self.hover_settings.enabled,
      hover_multi_cursor_modifier,
      self.hover_last_modifiers,
    ) {
    self.run_hover_react()
    return
  }
  if hover_sticky_debug {
    return
  }
  self.hide_content_hover()
}

///|
/// Records the latest pointer client position and modifier flags so the
/// controller handlers — which run from the pointer-handler seam that only
/// carries a hit target — can evaluate `_isMouseOnContentHoverWidget` and
/// `shouldShowHover`. Called by the input bridge before dispatching the move.
fn Viewer::record_hover_pointer(
  self : Viewer,
  posx : Double,
  posy : Double,
  modifiers : EventModifiers,
) -> Unit {
  self.hover_mouse_posx = posx
  self.hover_mouse_posy = posy
  self.hover_last_modifiers = modifiers
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
/// Monaco `ContentHoverController.hideContentHover`: the dev sticky kill-switch
/// (and the inline-completion dropdown guard, N-A here) suppress hiding;
/// otherwise the widget hides. Wraps `dismiss_hover` with the repaint the
/// imperative callers would otherwise own.
fn Viewer::hide_content_hover(self : Viewer) -> Unit {
  if hover_sticky_debug {
    return
  }
  // `InlineSuggestionHintsContentWidget.dropDownVisible` guard is N-A — the
  // viewer has no inline-completion hints widget.
  let before = self.hover
  self.dismiss_hover()
  self.after_hover_transition(before)
}

///|
/// Monaco `ContentHoverController._isMouseOnContentHoverWidget`: whether the
/// pointer at client `(posx, posy)` is within the hover widget's box (false when
/// no widget exists). The widget is measured with `getBoundingClientRect`, so the
/// coordinates are client-space (see the plan's Deviations on client- vs page).
fn Viewer::mouse_on_hover_widget(
  self : Viewer,
  posx : Double,
  posy : Double,
) -> Bool {
  guard self.view is Some(view) else { return false }
  guard view.content_widgets.hover_wrapper() is Some(wrapper) else {
    return false
  }
  let rect = wrapper.get_bounding_client_rect()
  mouse_within_element(
    rect.get_left(),
    rect.get_top(),
    rect.get_width(),
    rect.get_height(),
    posx,
    posy,
  )
}

///|
/// Monaco `ContentHoverController._onEditorMouseDown`: a press that is not on the
/// hover widget hides it; a press on it keeps it. `_isMouseDown` tracking and the
/// `_onEditorMouseUp` reset are omitted — only the color-picker arm of
/// `_shouldKeepCurrentHover` reads them, and that arm is N-A.
fn Viewer::on_editor_mouse_down(
  self : Viewer,
  posx : Double,
  posy : Double,
) -> Unit {
  if self.hover_ignore_mouse_events {
    return
  }
  if should_keep_hover_widget_visible(self.mouse_on_hover_widget(posx, posy)) {
    return
  }
  self.hide_content_hover()
}

///|
/// Monaco `ContentHoverController._onEditorMouseLeave`: with mouse events not
/// ignored and keep-open unset, cancel the scheduler and hide — unless the
/// pointer is still on the widget (or the dev sticky flag is set).
fn Viewer::on_editor_mouse_leave(
  self : Viewer,
  posx : Double,
  posy : Double,
) -> Unit {
  if self.hover_ignore_mouse_events {
    return
  }
  if self.hover_keep_open {
    return
  }
  self.cancel_hover_react()
  if should_keep_hover_widget_visible(self.mouse_on_hover_widget(posx, posy)) {
    return
  }
  if hover_sticky_debug {
    return
  }
  self.hide_content_hover()
}

///|
/// Monaco `ContentHoverController._onEditorScrollChanged`: a vertical or
/// horizontal editor scroll hides the hover (unless mouse events are ignored).
fn Viewer::on_editor_scroll_changed(
  self : Viewer,
  change : @view_layout.ScrollChange,
) -> Unit {
  if self.hover_ignore_mouse_events {
    return
  }
  if change.top_changed || change.left_changed {
    self.hide_content_hover()
  }
}

///|
/// Fans one editor event to every controller in a fixed order and applies
/// their effects; the contribution model with imperative sub-updates.
/// Hover is the only controller today.
fn Viewer::dispatch_editor_event(self : Viewer, event : EditorEvent) -> Unit {
  // Escape hides immediately and must drop any deferred mouse-move reaction so a
  // stale target cannot re-open the hover.
  match event {
    EscapePressed => self.cancel_hover_react()
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
