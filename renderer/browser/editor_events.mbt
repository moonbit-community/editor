///|
/// Typed editor events produced by the input bridge. Feature controllers
/// consume these the way VS Code contributions consume editor events; no
/// controller sees raw DOM events.
priv enum EditorEvent {
  MouseMoved(@renderer.MouseTarget)
  MouseLeft
  EscapePressed
}

///|
/// Read-only app state controllers may consult while handling an event.
priv struct EditorContext {
  frame : @renderer.RenderFrame?
  source_document : @workspace.SourceDocument?
}

///|
fn editor_context(model : BrowserAppModel) -> EditorContext {
  { frame: model.frame, source_document: model.source_document }
}

///|
/// Fans one editor event to every controller in a fixed order and merges
/// their commands; the contribution model with Elm-shaped sub-updates.
/// Hover is the only controller today.
fn editor_event_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  event : EditorEvent,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let ctx = editor_context(model)
  let (hover_cmd, hover) = model.hover.on_event(emit, event, ctx)
  (hover_cmd, { ..model, hover, })
}

///|
/// Span decorations contributed by every controller for the current state.
fn controller_decorations(
  surface : CodeSurface,
) -> Array[@decorations.Decoration] {
  surface.hover.decorations()
}
