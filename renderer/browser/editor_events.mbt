///|
/// Typed editor events produced by the input bridge. Feature controllers
/// consume these the way VS Code contributions consume editor events; no
/// controller sees raw DOM events.
priv enum EditorEvent {
  MouseMoved(@renderer.MouseTarget, Bool)
  MouseDown(@renderer.MouseTarget, Bool)
  ContextMenuRequested(@renderer.MouseTarget)
  MouseLeft
  EscapePressed
  GotoKeyCommand(Bool)
  GotoModifierChanged(Bool)
}

///|
/// Read-only app state controllers may consult while handling an event.
priv struct EditorContext {
  frame : @renderer.RenderFrame?
  source_document : @workspace.SourceDocument?
  document_uri : String
  last_target : @renderer.MouseTarget?
}

///|
fn editor_context(model : BrowserAppModel) -> EditorContext {
  {
    frame: model.frame,
    source_document: model.source_document,
    document_uri: active_document_uri(model.document),
    last_target: model.last_target,
  }
}

///|
/// Fans one editor event to every controller in a fixed order and merges
/// their commands; the contribution model with Elm-shaped sub-updates.
fn editor_event_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  event : EditorEvent,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let ctx = editor_context(model)
  let (hover_cmd, hover) = model.hover.on_event(emit, event, ctx)
  let (definition_cmd, definition) = model.definition.on_event(
    emit, event, ctx,
  )
  let (references_cmd, references) = model.references.on_event(
    emit, event, ctx,
  )
  (
    @rabbita.batch([hover_cmd, definition_cmd, references_cmd]),
    { ..model, hover, definition, references },
  )
}

///|
/// Span decorations contributed by every controller for the current state.
fn controller_decorations(
  model : BrowserAppModel,
) -> Array[@decorations.Decoration] {
  let items : Array[@decorations.Decoration] = []
  items.append(model.hover.decorations())
  items.append(
    model.definition.decorations(active_document_uri(model.document)),
  )
  items.append(model.references.decorations())
  items
}

///|
/// The offset a definition/references request should use when the target
/// rests on a navigable identifier span: the span midpoint, matching the
/// old per-span handlers.
fn candidate_request_offset(
  frame : @renderer.RenderFrame?,
  target : @renderer.MouseTarget?,
) -> Int? {
  match (frame, target) {
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
