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
    view_to_model_offset: view_position => self.view_position_to_model_offset(view_position),
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
      set_timeout(() => {
        if self.hover_react_pending && token == self.hover_react_token {
          self.run_hover_react()
        }
      }, hover_hiding_delay_ms)
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
fn Viewer::apply_hover_effect(self : Viewer, effect : HoverEffect) -> Unit {
  match effect {
    HoverNoEffect => ()
    HoverSchedule(token) => {
      set_timeout(() => self.hover_fire(token), hover_delay_ms / 2) |> ignore
      set_timeout(() => self.hover_display_due(token), hover_delay_ms) |> ignore
      set_timeout(() => self.hover_loading_due(token), hover_delay_ms * 3)
      |> ignore
    }
    HoverRequest(anchor, token) => self.request_hover(anchor, token)
  }
}

///|
fn Viewer::hover_fire(self : Viewer, token : Int) -> Unit {
  let (effect, hover) = self.hover.fire(token)
  self.hover = hover
  self.apply_hover_effect(effect)
}

///|
fn Viewer::hover_display_due(self : Viewer, token : Int) -> Unit {
  let before = self.hover
  self.hover = self.hover.display_due(token)
  self.after_hover_transition(before)
}

///|
fn Viewer::hover_loading_due(self : Viewer, token : Int) -> Unit {
  let before = self.hover
  self.hover = self.hover.loading_due(token)
  self.after_hover_transition(before)
}

///|
fn Viewer::hover_resolved(
  self : Viewer,
  model : @model.TextModel,
  token : Int,
  hover : @hover.ComputedHover?,
) -> Unit {
  if !self.is_current_model(model) {
    return
  }
  let before = self.hover
  self.hover = self.hover.resolved_hover(
    event => self.did_resolve_hover.fire(event),
    model.revision,
    token,
    hover,
  )
  self.after_hover_transition(before)
}

///|
/// Span decorations contributed by every controller for the current state.
fn Viewer::controller_decorations(
  self : Viewer,
) -> Array[@decorations.Decoration] {
  self.hover.decorations()
}

///|
fn Viewer::is_current_model(self : Viewer, model : @model.TextModel) -> Bool {
  match self.text_model {
    Some(current) => current.same_identity_and_version(model)
    None => false
  }
}
