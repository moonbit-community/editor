///|
fn Viewer::selection_range(self : Viewer) -> @base_common.Range? {
  match (self.selection, self.text_model) {
    (Some(selection), Some(model)) => {
      let snapshot = model.snapshot
      if selection.is_empty(snapshot) {
        None
      } else {
        Some(selection.normalized_range(snapshot))
      }
    }
    _ => None
  }
}

///|
fn Viewer::begin_selection(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  match self.position_for_selection_target(target) {
    Some(position) => {
      self.selection = Some(Selection(position, position))
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
  match self.position_for_selection_target(target) {
    Some(position) => {
      self.selection = Some({ ..selection, focus: position })
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
  match (self.selection, self.text_model) {
    (Some(selection), Some(model)) =>
      if selection.is_empty(model.snapshot) {
        self.selection = None
      }
    _ => ()
  }
  self.schedule_render()
}

///|
fn Viewer::position_for_selection_target(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> @base_common.Position? {
  if target.offset < 0 {
    return None
  }
  match target.kind {
    ContentText | ContentEmpty =>
      match self.source_document {
        Some(document) => Some(document.position_at_offset(target.offset))
        None => None
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
      if selection.is_empty(snapshot) {
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
          @viewer_common.escape_html(line.text[start_column:end_column].to_owned()),
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
