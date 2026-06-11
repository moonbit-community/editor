///|
priv struct DefinitionView {
  uri : String
  range : @core.Range
} derive(Eq)

///|
/// Go-to-definition feature state: the Ctrl/Cmd modifier, the candidate
/// span under the mouse (for the link affordance), the navigated-to
/// definition, and a reveal deferred until another file renders.
priv struct DefinitionController {
  goto_modifier : Bool
  link_anchor : (Int, Int)?
  active : DefinitionView?
  pending_reveal : DefinitionView?
} derive(Eq)

///|
fn DefinitionController::empty() -> DefinitionController {
  {
    goto_modifier: false,
    link_anchor: None,
    active: None,
    pending_reveal: None,
  }
}

///|
fn DefinitionController::deactivated(
  self : DefinitionController,
) -> DefinitionController {
  { ..self, active: None }
}

///|
fn DefinitionController::on_event(
  self : DefinitionController,
  emit : @rabbita.Emit[BrowserMsg],
  event : EditorEvent,
  ctx : EditorContext,
) -> (@rabbita.Cmd, DefinitionController) {
  match event {
    MouseMoved(target, modifier) => {
      let link_anchor = match ctx.frame {
        Some(frame) =>
          match span_anchor_for_target(frame, target) {
            Some((start, end, span)) =>
              if is_definition_candidate(span) {
                Some((start, end))
              } else {
                None
              }
            None => None
          }
        None => None
      }
      (@rabbita.none, { ..self, goto_modifier: modifier, link_anchor })
    }
    MouseDown(target, modifier) =>
      if modifier {
        self.request(emit, ctx, Some(target))
      } else {
        (@rabbita.none, self)
      }
    GotoKeyCommand(shift) =>
      if shift {
        (@rabbita.none, self)
      } else {
        self.request(emit, ctx, ctx.last_target)
      }
    GotoModifierChanged(modifier) =>
      (@rabbita.none, { ..self, goto_modifier: modifier })
    MouseLeft => (@rabbita.none, { ..self, link_anchor: None })
    EscapePressed => (@rabbita.none, self.deactivated())
    _ => (@rabbita.none, self)
  }
}

///|
fn DefinitionController::request(
  self : DefinitionController,
  emit : @rabbita.Emit[BrowserMsg],
  ctx : EditorContext,
  target : @renderer.MouseTarget?,
) -> (@rabbita.Cmd, DefinitionController) {
  match candidate_request_offset(ctx.frame, target) {
    Some(offset) =>
      (
        definition_provider_cmd(emit, ctx.source_document, offset),
        self.deactivated(),
      )
    None => (@rabbita.none, self)
  }
}

///|
/// Records the definition the app navigated to in the active document.
fn DefinitionController::navigated(
  self : DefinitionController,
  view : DefinitionView,
) -> DefinitionController {
  { ..self, active: Some(view), pending_reveal: None }
}

///|
/// Stores a definition whose document must open before it can be revealed.
fn DefinitionController::deferred(
  self : DefinitionController,
  view : DefinitionView,
) -> DefinitionController {
  { ..self, pending_reveal: Some(view) }
}

///|
/// Claims the pending reveal if it addresses the just-rendered document.
fn DefinitionController::claim_pending(
  self : DefinitionController,
  uri : String,
) -> (DefinitionView?, DefinitionController) {
  match self.pending_reveal {
    Some(view) =>
      if view.uri == uri {
        (Some(view), { ..self, active: Some(view), pending_reveal: None })
      } else {
        (None, { ..self, active: None })
      }
    None => (None, { ..self, active: None })
  }
}

///|
fn DefinitionController::decorations(
  self : DefinitionController,
  document_uri : String,
) -> Array[@decorations.Decoration] {
  let items : Array[@decorations.Decoration] = []
  if self.goto_modifier {
    match self.link_anchor {
      Some((start, end)) =>
        items.push(Decoration(Range(start, end), Link, "goto-definition-link"))
      None => ()
    }
  }
  match self.active {
    Some(definition) =>
      if definition.uri == document_uri {
        items.push(
          Decoration(
            definition.range,
            SearchMatch,
            "has-definition definition-target",
          ),
        )
        items.push(Decoration(definition.range, CurrentLine, "range-highlight"))
      }
    None => ()
  }
  items
}
