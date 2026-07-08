///|
/// The selection as a view-coordinate range, the input the selection overlay
/// renders from. Mirrors the view selections Monaco's `SelectionsOverlay`
/// receives via `onCursorStateChanged`: the cursor already holds the selection
/// in view coordinates (its `viewState`), so the overlay never round-trips
/// through raw document offsets. Columns are one-based and local to each view
/// line (the convention `measure_line_selection` consumes).
fn Viewer::selection_view_range(self : Viewer) -> @base_common.Range? {
  guard self.view_model is Some(view_model) else { return None }
  let selection = view_model.cursor.get_view_selection()
  if selection.is_empty() {
    return None
  }
  Some(@base_common.Range::from_positions(selection.start(), selection.end()))
}

///|
/// The full view-space selection the render input carries for the cursor part
/// (Monaco's `ViewCursorStateChangedEvent.selections[0]`): unlike
/// `selection_view_range` it survives collapsing, so a caret-only
/// `set_position` still renders. `None` only without a model — the view
/// model's cursor always exists, collapsed at (1,1) like Monaco's.
fn Viewer::view_selection(self : Viewer) -> @core.Selection? {
  match self.view_model {
    Some(view_model) => Some(view_model.cursor.get_view_selection())
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
  self.set_selection(@core.Selection::new(position, position))
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
  selection : @core.Selection,
) -> Unit {
  guard self.text_model is Some(model) else { return }
  guard self.view_model is Some(view_model) else { return }
  let controller = view_model.cursor
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
  let anchor = selection.get_selection_start()
  let anchor_range = model.validate_range(
    Range(anchor.line_number, anchor.column, anchor.line_number, anchor.column),
  )
  let new_state = @cursor.SingleCursorState::new(
    Position(anchor_range.start_line_number, anchor_range.start_column),
    Position(anchor_range.end_line_number, anchor_range.end_column),
    Simple,
    model.validate_position(selection.get_position()),
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
  selections : Array[@core.Selection],
) -> Unit {
  guard selections.length() > 0 else { return }
  self.set_selection(selections[0])
}

///|
fn Viewer::handle_copy_event(self : Viewer, event : @rdom.Event) -> Bool {
  guard event.to_clipboard_event() is Some(clipboard_event) else {
    return false
  }
  match (self.view_model, self.text_model) {
    (Some(view_model), Some(model)) => {
      let selection = view_model.cursor.get_model_selection()
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
  selection : @core.Selection,
  snapshot : @model.TextSnapshot,
) -> String {
  match self.text_model {
    Some(model) =>
      get_rich_text_to_copy(
        model,
        Range(
          selection.start().line_number,
          selection.start().column,
          selection.end().line_number,
          selection.end().column,
        ),
        self.font_info,
      )
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
  selection : @core.Selection,
  snapshot : @model.TextSnapshot,
) -> @base_common.OffsetRange {
  OffsetRange(
    snapshot.get_offset_at(
      selection.start().line_number,
      selection.start().column,
    ),
    snapshot.get_offset_at(selection.end().line_number, selection.end().column),
  )
}

///|
/// Plain selected text for clipboard writes.
fn selection_plain_text_to_copy(
  selection : @core.Selection,
  snapshot : @model.TextSnapshot,
) -> String {
  snapshot.slice(selection_normalized_range(selection, snapshot))
}

///|
/// Minimal HTML clipboard payload preserving preformatted text, used as the
/// fallback when no model is available to produce styled spans.
fn selection_rich_text_to_copy(
  selection : @core.Selection,
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
/// Styled clipboard HTML for a model range, the faithful
/// `ViewModel.getRichTextToCopy` / `_getHTMLToCopy` pair
/// (`viewModelImpl.ts:1051-1134`): per model line, the model's `LineTokens`
/// render through `tokenize_line_to_html` (injected text never appears — it
/// lives in decorations, not the model tokens), wrapped in a styled `<div>`
/// carrying the default foreground/background and the configured `fontInfo`.
/// Deviation: no PLAINTEXT/multi-selection `null` arms (the viewer always
/// has a single selection and a concrete language).
fn get_rich_text_to_copy(
  model : @model.TextModel,
  model_range : @base_common.Range,
  font_info : @config.FontInfo,
) -> String {
  let color_map = @model_tokens.default_token_color_map()
  "<div style=\"" +
  "color: " +
  color_map[1] +
  ";" +
  "background-color: " +
  color_map[2] +
  ";" +
  "font-family: " +
  font_info.bare().get_massaged_font_family() +
  ";" +
  "font-weight: " +
  font_info.font_weight +
  ";" +
  "font-size: " +
  font_info.font_size.to_string() +
  "px;" +
  "line-height: " +
  font_info.line_height.to_string() +
  "px;" +
  "white-space: pre;" +
  "\">" +
  get_html_to_copy(model, model_range, color_map) +
  "</div>"
}

///|
/// `ViewModelImpl._getHTMLToCopy` (`viewModelImpl.ts:1110-1134`): one
/// `tokenize_line_to_html` div per model line clipped to the range's
/// columns; an empty line contributes a `<br>`.
fn get_html_to_copy(
  model : @model.TextModel,
  model_range : @base_common.Range,
  color_map : Array[String],
) -> String {
  let start_line_number = model_range.start_line_number
  let start_column = model_range.start_column
  let end_line_number = model_range.end_line_number
  let end_column = model_range.end_column
  let tab_size = 2
  let result = StringBuilder()
  for line_number in start_line_number..<=end_line_number {
    let line_tokens = model.tokenization.get_line_tokens(line_number)
    let line_content = line_tokens.get_line_content()
    let start_offset = if line_number == start_line_number {
      start_column - 1
    } else {
      0
    }
    let end_offset = if line_number == end_line_number {
      end_column - 1
    } else {
      line_content.length()
    }
    if line_content == "" {
      result.write_string("<br>")
    } else {
      result.write_string(
        @languages.tokenize_line_to_html(
          line_content,
          line_tokens.inflate(),
          color_map,
          start_offset,
          end_offset,
          tab_size,
          false,
        ),
      )
    }
  }
  result.to_string()
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
