///|
/// The selection as a view-coordinate range, the input the selection overlay
/// renders from. Mirrors the view selections Monaco's `SelectionsOverlay`
/// receives via `onCursorStateChanged`: the model selection is converted to
/// view positions through the `CoordinatesConverter`, so the overlay never
/// round-trips through raw document offsets. Columns are one-based and local
/// to each view line (the convention `measure_line_selection` consumes).
fn Viewer::selection_view_range(
  self : Viewer,
) -> @view_line_renderer.ViewRange? {
  guard self.selection is Some(selection) else { return None }
  if selection.is_empty() {
    return None
  }
  guard self.view_model is Some(view_model) else { return None }
  let converter = view_model.coordinates_converter()
  let view_start = converter.model_position_to_view_position(selection.start())
  let view_end = converter.model_position_to_view_position(selection.end())
  Some({
    start_line_number: view_start.line + 1,
    start_column: view_start.column + 1,
    end_line_number: view_end.line + 1,
    end_column: view_end.column + 1,
  })
}

///|
fn Viewer::begin_selection(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  match self.model_position_for_selection_target(target) {
    Some(position) => {
      self.selection = Some(@view_model.Selection::new(position, position))
      self.selection_dragging = true
      self.hover = self.hover.cleared()
      self.schedule_render()
    }
    None => {
      self.selection = None
      self.selection_dragging = false
      self.schedule_render()
    }
  }
}

///|
fn Viewer::update_selection(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  guard self.selection_dragging else { return }
  guard self.selection is Some(selection) else { return }
  match self.model_position_for_selection_target(target) {
    Some(position) => {
      self.selection = Some(selection.with_position(position))
      self.schedule_render()
    }
    None => ()
  }
}

///|
fn Viewer::finish_selection(self : Viewer) -> Unit {
  if !self.selection_dragging {
    return
  }
  self.selection_dragging = false
  match self.selection {
    Some(selection) =>
      if selection.is_empty() {
        self.selection = None
      }
    None => ()
  }
  self.schedule_render()
}

///|
/// The model position a content hit resolves to, bridged from the hit's view
/// position through the `CoordinatesConverter` (never through a raw document
/// offset). The hit test already yields a view line/column; we keep the
/// selection state in model `Position`s, like Monaco's cursor.
fn Viewer::model_position_for_selection_target(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> @base_common.Position? {
  guard target.line_number >= 1 else { return None }
  match target.kind {
    ContentText | ContentEmpty => {
      guard self.view_model is Some(view_model) else { return None }
      let view_position = @base_common.Position::Position(
        target.line_number - 1,
        target.column,
      )
      Some(
        view_model
        .coordinates_converter()
        .view_position_to_model_position(view_position),
      )
    }
    _ => None
  }
}

///|
fn Viewer::handle_copy_event(self : Viewer, event : @rdom.Event) -> Bool {
  guard event.to_clipboard_event() is Some(clipboard_event) else {
    return false
  }
  match (self.selection, self.text_model) {
    (Some(selection), Some(model)) => {
      let snapshot = model.snapshot
      if selection.is_empty() {
        return false
      }
      let plain = selection.get_plain_text_to_copy(snapshot)
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
          selection.normalized_range(snapshot),
          frame,
        ) {
        Some(html) => html
        None => selection.get_rich_text_to_copy(snapshot)
      }
    None => selection.get_rich_text_to_copy(snapshot)
  }
}

///|
fn rich_text_to_copy_from_frame(
  range : @base_common.Range,
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
      model_line_start <= range.end {
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
  range : @base_common.Range,
) -> Unit {
  let model_line_start = line.model_line_start_offset()
  for span in line.spans {
    if span.injected_text_index >= 0 {
      continue
    }
    let span_start = model_line_start + span.source_start
    let span_end = model_line_start + span.source_end
    if range.intersects(Range(span_start, span_end)) {
      let start_column = span.start +
        max_int(range.start, span_start) -
        span_start
      let end_column = span.start + min_int(range.end, span_end) - span_start
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
