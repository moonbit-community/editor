///|
/// The selection as a view-coordinate range, the input the selection overlay
/// renders from. Mirrors the view selections Monaco's `SelectionsOverlay`
/// receives via `onCursorStateChanged`: the cursor already holds the selection
/// in view coordinates (its `viewState`), so the overlay never round-trips
/// through raw document offsets. Columns are one-based and local to each view
/// line (the convention `measure_line_selection` consumes).
fn Viewer::selection_view_range(
  self : Viewer,
) -> @view_line_renderer.ViewRange? {
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
  let model_line_start = line.model_line_start_offset()
  for span in line.spans {
    if span.injected_text_index >= 0 {
      continue
    }
    let span_start = model_line_start + span.source_start
    let span_end = model_line_start + span.source_end
    if range.intersects(OffsetRange(span_start, span_end)) {
      let start_column = span.start +
        max_int(range.start, span_start) -
        span_start
      let end_column = span.start +
        min_int(range.end_exclusive, span_end) -
        span_start
      if start_column < end_column {
        html.write_string("<span class=\"")
        html.write_string(@viewer_common.escape_html(span.class_name))
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
