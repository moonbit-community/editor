///|
/// The selection as a view-coordinate range, the input the selection overlay
/// renders from. Mirrors the view selections Monaco's `SelectionsOverlay`
/// receives via `onCursorStateChanged`: the cursor already holds the selection
/// in view coordinates (its `viewState`), so the overlay never round-trips
/// through raw document offsets. Columns are one-based and local to each view
/// line (the convention `measure_line_selection` consumes).
fn Viewer::selection_view_range(self : Viewer) -> @view_layout.ViewRange? {
  guard self.cursor is Some(controller) else { return None }
  let selection = controller.get_view_selection()
  if selection.is_empty() {
    return None
  }
  let start = selection.start()
  let end = selection.end()
  Some({
    start_line_number: start.line_number,
    start_column: start.column,
    end_line_number: end.line_number,
    end_column: end.column,
  })
}

///|
/// The full view-space selection the render input carries for the cursor part
/// (Monaco's `ViewCursorStateChangedEvent.selections[0]`): unlike
/// `selection_view_range` it survives collapsing, so a caret-only
/// `set_position` still renders. `None` until a cursor exists (deviation:
/// Monaco always has a cursor at (1,1); the viewer creates one lazily on the
/// first click / `set_position`, so no caret shows before that).
fn Viewer::view_selection(self : Viewer) -> @view_model.Selection? {
  match self.cursor {
    Some(controller) => Some(controller.get_view_selection())
    None => None
  }
}

///|
/// Moves the primary cursor to `position`, collapsing the selection there —
/// Monaco's `setPosition` (`codeEditorWidget.ts:670-682`), which builds a
/// selection with `selectionStart == position` and routes it through the
/// selection path. No model → no-op, no event. Like every Monaco mutator this
/// never scrolls; "move and reveal" is a composition with `reveal_*` at the
/// call site (the `gotoLocation` pattern).
pub fn Viewer::set_position(
  self : Viewer,
  position : @base_common.Position,
) -> Unit {
  self.set_selection(@view_model.Selection::new(position, position))
}

///|
/// Sets the primary selection from an anchor+active pair — Monaco's
/// `setSelection`/`_setSelectionImpl` (`codeEditorWidget.ts:797-830`) →
/// `ViewModel.setSelections` (`viewModelImpl.ts:1185-1187`) →
/// `CursorsController.setSelections`/`setStates` (`cursor.ts:309-311,118-134`),
/// collapsed onto the viewer's single cursor. Monaco's five input overloads
/// reduce to the one `Selection` type: the anchor may sit before or after the
/// active position and the resulting direction is preserved; a caller with a
/// plain range builds `Selection::from_positions(start, end)`. No model →
/// no-op, no event. Never scrolls (see `set_position`).
pub fn Viewer::set_selection(
  self : Viewer,
  selection : @view_model.Selection,
) -> Unit {
  guard self.text_model is Some(model) else { return }
  guard self.ensure_cursor() is Some(controller) else { return }
  // The outgoing-event facts Monaco captures before mutating
  // (`cursor.ts` `_emitStateChangedIfNecessary`): the previous selection set
  // and model version.
  let old_selections = [controller.get_model_selection()]
  let old_model_version_id = model.version
  // `CursorState.fromModelSelection` (cursorCommon.ts:283-289): the anchor
  // becomes a collapsed `Simple` range at `selectionStart`, the active end is
  // `position`. Then `_setState`'s model branch (oneCursor.ts:133-141):
  // `validateRange` on the anchor, `validatePosition` on the active end.
  // `set_model_cursor_state` trusts its input (its hit-test/converter callers
  // are pre-validated), so the clamp must happen here at the boundary.
  let snapshot = model.snapshot
  let anchor = selection.get_selection_start()
  let anchor_range = snapshot.validate_range(
    Range(anchor.line_number, anchor.column, anchor.line_number, anchor.column),
  )
  let new_state = @cursor.SingleCursorState::new(
    Position(anchor_range.start_line_number, anchor_range.start_column),
    Position(anchor_range.end_line_number, anchor_range.end_column),
    Simple,
    snapshot.validate_position(selection.get_position()),
  )
  // `_emitStateChangedIfNecessary`'s equality gate (cursor.ts:404-406):
  // setting the exact current state fires nothing. The view state is derived
  // deterministically from the model state, so comparing the model
  // `SingleCursorState` (`derive(Eq)`, anchor kind included — matching
  // Monaco's `SingleCursorState.equals`) covers both of Monaco's gates.
  if new_state == controller.model_state() {
    return
  }
  controller.set_model_cursor_state(new_state)
  // "Let the view get the event first" (cursor.ts:410-414): the selection
  // overlay repaints before the outgoing events fire, the same order the
  // mouse-driven path uses (`view_controller.mbt`).
  self.schedule_render()
  self.did_change_cursor_position.fire({
    position: new_state.position,
    secondary_positions: [],
    reason: Explicit,
    source: "api",
  })
  self.did_change_cursor_selection.fire({
    selection: controller.get_model_selection(),
    secondary_selections: [],
    model_version_id: model.version,
    old_selections,
    old_model_version_id,
    source: "api",
    reason: Explicit,
  })
}

///|
/// Sets all cursor selections — Monaco's `setSelections`
/// (`codeEditorWidget.ts:832-849`). The viewer is single-selection (a
/// documented scope cut, see `get_selections`), so the primary selection is
/// applied and any secondaries are dropped. Like Monaco, an empty array is
/// rejected as a no-op (Monaco throws an "Invalid arguments" error there; the
/// readonly viewer's mutators never throw).
pub fn Viewer::set_selections(
  self : Viewer,
  selections : Array[@view_model.Selection],
) -> Unit {
  guard selections.length() > 0 else { return }
  self.set_selection(selections[0])
}

///|
/// Lazily resolves the cursor controller, building it from the active view
/// model's coordinates converter on first use.
fn Viewer::ensure_cursor(self : Viewer) -> @cursor.CursorsController? {
  match self.cursor {
    Some(controller) => Some(controller)
    None =>
      match self.view_model {
        Some(view_model) => {
          let controller = @cursor.CursorsController::new(
            @cursor.CursorContext::new(view_model.coordinates_converter()),
          )
          self.cursor = Some(controller)
          Some(controller)
        }
        None => None
      }
  }
}

///|
/// Re-points the cursor at the rebuilt view model and re-projects its selection
/// from the model positions, keeping the view selection correct after a reflow
/// (folding, wrapping, inlay hints).
fn Viewer::refresh_cursor_context(self : Viewer) -> Unit {
  match (self.cursor, self.view_model) {
    (Some(controller), Some(view_model)) =>
      controller.set_context(
        @cursor.CursorContext::new(view_model.coordinates_converter()),
      )
    _ => ()
  }
}

///|
fn Viewer::handle_copy_event(self : Viewer, event : @rdom.Event) -> Bool {
  guard event.to_clipboard_event() is Some(clipboard_event) else {
    return false
  }
  match (self.cursor, self.text_model) {
    (Some(controller), Some(model)) => {
      let selection = controller.get_model_selection()
      let snapshot = model.snapshot
      if selection.is_empty() {
        return false
      }
      let plain = selection_plain_text_to_copy(selection, snapshot)
      let html = self.get_rich_text_to_copy(selection, snapshot)
      write_selection_clipboard_data(clipboard_event, plain, html)
      true
    }
    _ => false
  }
}

///|
fn Viewer::get_rich_text_to_copy(
  self : Viewer,
  selection : @view_model.Selection,
  snapshot : @model.TextSnapshot,
) -> String {
  match self.frame {
    Some(frame) =>
      match
        rich_text_to_copy_from_frame(
          selection_normalized_range(selection, snapshot),
          frame,
        ) {
        Some(html) => html
        None => selection_rich_text_to_copy(selection, snapshot)
      }
    None => selection_rich_text_to_copy(selection, snapshot)
  }
}

///|
/// Selection range normalized into ascending document offsets — the
/// model/clipboard boundary where the selection's view-`Position` geometry
/// crosses into raw document offsets. Monaco keeps this off the pure-geometry
/// `Selection` (`core/selection.ts`); the readonly viewer does the same, placing
/// it here in the controller layer. The offset round-trip is allowed only
/// because this is the model/clipboard boundary (the port's rule #3).
fn selection_normalized_range(
  selection : @view_model.Selection,
  snapshot : @model.TextSnapshot,
) -> @base_common.OffsetRange {
  OffsetRange(
    snapshot.offset_at_position(selection.start()),
    snapshot.offset_at_position(selection.end()),
  )
}

///|
/// Plain selected text for clipboard writes.
fn selection_plain_text_to_copy(
  selection : @view_model.Selection,
  snapshot : @model.TextSnapshot,
) -> String {
  snapshot.slice(selection_normalized_range(selection, snapshot))
}

///|
/// Minimal HTML clipboard payload preserving preformatted text, used as the
/// fallback when no render frame is available to produce styled spans.
fn selection_rich_text_to_copy(
  selection : @view_model.Selection,
  snapshot : @model.TextSnapshot,
) -> String {
  "<pre class=\"readonly-editor-copy\">" +
  escape_copy_html(selection_plain_text_to_copy(selection, snapshot)) +
  "</pre>"
}

///|
fn escape_copy_html(text : String) -> String {
  let out = StringBuilder()
  for ch in text {
    match ch {
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '&' => out.write_string("&amp;")
      '"' => out.write_string("&quot;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn rich_text_to_copy_from_frame(
  range : @base_common.OffsetRange,
  frame : @view_model.RenderFrame,
) -> String? {
  let html = StringBuilder()
  html.write_string("<pre class=\"readonly-editor-copy\">")
  let mut wrote_line = false
  let mut previous_model_line_start = -1
  for line in frame.lines {
    let model_line_start = line.model_line_start_offset()
    let model_line_end = line.source_offset_at_column(line.text.length())
    if model_line_start != previous_model_line_start &&
      range.start <= model_line_end &&
      model_line_start <= range.end_exclusive {
      if wrote_line {
        html.write_string("\n")
      }
      wrote_line = true
      previous_model_line_start = model_line_start
    }
    append_rich_copy_line_segments(html, line, range)
  }
  if !wrote_line {
    return None
  }
  html.write_string("</pre>")
  Some(html.to_string())
}

///|
fn append_rich_copy_line_segments(
  html : StringBuilder,
  line : @view_model.RenderLine,
  range : @base_common.OffsetRange,
) -> Unit {
  let tokens = line.tokens
  let mut token_start = 0
  for i in 0..<tokens.get_count() {
    let token_end = tokens.get_end_offset(i)
    // Injected (inlay-hint) tokens have no source text; skip them so the rich
    // copy holds only real document content (Monaco never copies injected text).
    if token_start < token_end &&
      line.injected_text_index_at_column(token_start) < 0 {
      let model_start = line.source_offset_at_column(token_start)
      let model_end = line.source_offset_at_column(token_end)
      if range.intersects(OffsetRange(model_start, model_end)) {
        let start_column = token_start +
          range.start.max(model_start) -
          model_start
        let end_column = token_start +
          range.end_exclusive.min(model_end) -
          model_start
        if start_column < end_column {
          html.write_string("<span class=\"")
          html.write_string(
            @viewer_common.escape_html(tokens.get_class_name(i)),
          )
          html.write_string("\">")
          html.write_string(
            @viewer_common.escape_html(
              line.text[start_column:end_column].to_owned(),
            ),
          )
          html.write_string("</span>")
        }
      }
    }
    token_start = token_end
  }
}

///|
extern "js" fn write_selection_clipboard_data(
  event : @rdom.ClipboardEvent,
  plain : String,
  html : String,
) -> Unit =
  #| (event, plain, html) => {
  #|   const data = event?.clipboardData;
  #|   if (data?.setData) {
  #|     data.setData("text/plain", plain);
  #|     data.setData("text/html", html);
  #|   }
  #|   globalThis.__readonlyEditorCopiedText = plain;
  #|   globalThis.__readonlyEditorCopiedHtml = html;
  #| }
