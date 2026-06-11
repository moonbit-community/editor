///|
priv struct ReferenceViewItem {
  uri : String
  range : @core.Range
  line : Int
  column : Int
  line_text : String
}

///|
priv struct PeekView {
  anchor_line : Int
  items : Array[ReferenceViewItem]
  selected : Int
}

///|
/// Height of the peek widget body in editor lines, matching VS Code's
/// references widget default layout.
let peek_body_lines = 18

///|
/// References peek feature state: the open peek view and the request
/// anchor offset that decides which line the zone attaches to.
priv struct ReferencesController {
  peek : PeekView?
  anchor_offset : Int?
}

///|
fn ReferencesController::empty() -> ReferencesController {
  { peek: None, anchor_offset: None }
}

///|
fn ReferencesController::closed(
  self : ReferencesController,
) -> ReferencesController {
  { ..self, peek: None, anchor_offset: None }
}

///|
fn ReferencesController::on_event(
  self : ReferencesController,
  emit : @rabbita.Emit[BrowserMsg],
  event : EditorEvent,
  ctx : EditorContext,
) -> (@rabbita.Cmd, ReferencesController) {
  match event {
    ContextMenuRequested(target) => self.request(emit, ctx, Some(target))
    GotoKeyCommand(shift) =>
      if shift {
        self.request(emit, ctx, ctx.last_target)
      } else {
        (@rabbita.none, self)
      }
    EscapePressed => (@rabbita.none, self.closed())
    _ => (@rabbita.none, self)
  }
}

///|
fn ReferencesController::request(
  self : ReferencesController,
  emit : @rabbita.Emit[BrowserMsg],
  ctx : EditorContext,
  target : @renderer.MouseTarget?,
) -> (@rabbita.Cmd, ReferencesController) {
  match candidate_request_offset(ctx.frame, target) {
    Some(offset) =>
      (
        references_request_cmd(
          emit,
          ctx.source_document,
          offset,
          frame_version(ctx.frame),
        ),
        { ..self, peek: None, anchor_offset: Some(offset) },
      )
    None => (@rabbita.none, self)
  }
}

///|
/// A references result arrived: open the peek anchored at the request
/// offset's line. Stale frame versions are dropped.
fn ReferencesController::resolved(
  self : ReferencesController,
  payload : @remote_protocol.ReferencesResultPayload,
  frame : @renderer.RenderFrame?,
) -> ReferencesController {
  let current_version = frame_version(frame)
  if current_version != payload.version {
    return self
  }
  emit_event(
    "language:references",
    "{\"ok\":true,\"count\":" +
    payload.references.length().to_string() +
    ",\"version\":" +
    payload.version.to_string() +
    "}",
  )
  let anchor_line = match (self.anchor_offset, frame) {
    (Some(offset), Some(frame)) =>
      match line_col_for_offset(frame, offset) {
        Some((line_number, _)) => line_number
        None => 1
      }
    _ => 1
  }
  let items : Array[ReferenceViewItem] = []
  for reference in payload.references {
    items.push({
      uri: reference.uri.to_string(),
      range: reference.range,
      line: reference.line,
      column: reference.column,
      line_text: reference.line_text,
    })
  }
  { ..self, peek: Some({ anchor_line, items, selected: 0 }) }
}

///|
fn ReferencesController::selected(
  self : ReferencesController,
  index : Int,
) -> ReferencesController {
  match self.peek {
    Some(peek) =>
      if index >= 0 && index < peek.items.length() {
        { ..self, peek: Some({ ..peek, selected: index }) }
      } else {
        self
      }
    None => self
  }
}

///|
/// The item to navigate to when a peek row is opened, if it exists.
fn ReferencesController::item_at(
  self : ReferencesController,
  index : Int,
) -> ReferenceViewItem? {
  match self.peek {
    Some(peek) =>
      if index >= 0 && index < peek.items.length() {
        Some(peek.items[index])
      } else {
        None
      }
    None => None
  }
}

///|
fn ReferencesController::decorations(
  self : ReferencesController,
) -> Array[@decorations.Decoration] {
  []
}

///|
/// The vertical bands the open peek occupies, for mouse hit-testing.
fn ReferencesController::view_zones(
  self : ReferencesController,
) -> Array[@renderer.ViewZone] {
  match self.peek {
    Some(peek) => [
      { anchor_line: peek.anchor_line, height_px: peek_zone_height_px },
    ]
    None => []
  }
}

///|
/// The inline peek widget and the line it anchors below, if open.
fn ReferencesController::zone_widget(
  self : ReferencesController,
  emit : @rabbita.Emit[BrowserMsg],
  frame : @renderer.RenderFrame,
  document_uri : String,
) -> (Int, @html.Html)? {
  match self.peek {
    Some(peek) =>
      Some(
        (
          peek.anchor_line,
          view_peek_widget(emit, frame, document_uri, peek),
        ),
      )
    None => None
  }
}

///|
/// Inline references peek widget, inserted below the anchor line so the
/// following lines are displaced like a VS Code editor zone widget.
fn view_peek_widget(
  emit : @rabbita.Emit[BrowserMsg],
  frame : @renderer.RenderFrame,
  document_uri : String,
  peek : PeekView,
) -> @html.Html {
  let count = peek.items.length()
  let meta = if count == 0 {
    "No results"
  } else if count == 1 {
    "1 result"
  } else {
    count.to_string() + " results"
  }
  @html.div(
    class="peek-widget",
    attrs=widget_overlay_attrs(
      @html.Attrs::build().data_set("peek", "references"),
    ),
    [
      @html.div(class="peek-head", [
        @html.span(class="peek-title", "References"),
        @html.span(class="peek-meta", meta),
        @html.button(
          type_="button",
          class="peek-close",
          title="Close",
          on_click=emit(ClosePeek),
          attrs=@html.Attrs::build().aria_label("Close references"),
          icon_close(),
        ),
      ]),
      @html.div(class="peek-body", [
        view_peek_preview(frame, document_uri, peek),
        view_peek_list(emit, peek),
      ]),
    ],
  )
}

///|
fn view_peek_preview(
  frame : @renderer.RenderFrame,
  document_uri : String,
  peek : PeekView,
) -> @html.Html {
  if peek.items.length() == 0 {
    return @html.div(class="peek-preview", [
      @html.div(class="peek-empty", "No results found."),
    ])
  }
  let item = peek.items[peek.selected]
  if item.uri == document_uri {
    let children : Array[@html.Html] = []
    let half = peek_body_lines / 2
    let first = if item.line > half { item.line - half } else { 1 }
    let last = first + peek_body_lines - 1
    for line in frame.lines {
      if line.line_number >= first && line.line_number <= last {
        children.push(view_peek_preview_line(item, line))
      }
    }
    @html.div(class="peek-preview", children)
  } else {
    // Cross-file references preview only their server-enriched line text.
    @html.div(class="peek-preview", [
      @html.div(
        class="peek-preview-caption",
        display_name_from_uri(item.uri) + ":" + item.line.to_string(),
      ),
      @html.div(class="code-line", [
        @html.div(class="gutter", item.line.to_string()),
        @html.pre(class="code", line_text_match_nodes(item, "peek-match")),
      ]),
    ])
  }
}

///|
/// Non-interactive rendering of a source line for the peek preview pane.
fn view_peek_preview_line(
  item : ReferenceViewItem,
  line : @renderer.RenderLine,
) -> @html.Html {
  let code = if line.spans.length() == 0 {
    @html.pre(class="code", if line.text == "" { " " } else { line.text })
  } else {
    let spans : Array[@html.Html] = []
    for span in line.spans {
      let absolute_start = line.offset + span.start
      let absolute_end = line.offset + span.end
      let class_name = if item.range.start < absolute_end &&
        absolute_start < item.range.end {
        span.class_name + " peek-match"
      } else {
        span.class_name
      }
      spans.push(@html.span(class=class_name, span.text))
    }
    @html.pre(class="code", spans)
  }
  @html.div(class="code-line", [
    @html.div(class="gutter", line.line_number.to_string()),
    code,
  ])
}

///|
fn view_peek_list(
  emit : @rabbita.Emit[BrowserMsg],
  peek : PeekView,
) -> @html.Html {
  let children : Array[@html.Html] = []
  let mut current_uri = ""
  for index in 0..<peek.items.length() {
    let item = peek.items[index]
    if item.uri != current_uri {
      current_uri = item.uri
      let mut count = 0
      for other in peek.items {
        if other.uri == item.uri {
          count = count + 1
        }
      }
      children.push(
        @html.div(class="peek-file-row", [
          @html.span(class="peek-file-icon", icon_file()),
          @html.span(class="peek-file-name", display_name_from_uri(item.uri)),
          @html.span(class="peek-file-count", count.to_string()),
        ]),
      )
    }
    let row_class = if index == peek.selected {
      "peek-ref-row selected"
    } else {
      "peek-ref-row"
    }
    let mut attrs = @html.Attrs::build().data_set(
      "ref-index",
      index.to_string(),
    )
    attrs = attrs.on_dblclick(_ => emit(OpenReference(index)))
    attrs = attrs.on_keydown(event => {
      if event.key() == "Enter" {
        emit(OpenReference(index))
      } else {
        @rabbita.none
      }
    })
    children.push(
      @html.button(
        type_="button",
        class=row_class,
        on_click=emit(SelectReference(index)),
        attrs~,
        line_text_match_nodes(item, "peek-list-match"),
      ),
    )
  }
  if peek.items.length() == 0 {
    children.push(@html.div(class="peek-empty", "No results found."))
  }
  @html.div(class="peek-list", children)
}

///|
/// Splits a reference's line text into plain/highlighted spans around the
/// matched range, falling back to plain text when the enriched column data
/// cannot address the line safely.
fn line_text_match_nodes(
  item : ReferenceViewItem,
  highlight_class : String,
) -> Array[@html.Html] {
  let text = item.line_text
  let plain : Array[@html.Html] = [
    @html.span(class="", if text == "" { " " } else { text }),
  ]
  let len = text.length()
  let match_length = item.range.end - item.range.start
  let start = item.column - 1
  if start < 0 || start >= len || match_length <= 0 {
    return plain
  }
  let end = if start + match_length > len { len } else { start + match_length }
  match (try? text[0:start], try? text[start:end], try? text[end:len]) {
    (Ok(before), Ok(matched), Ok(after)) => {
      let nodes : Array[@html.Html] = []
      if start > 0 {
        nodes.push(@html.span(class="", before.to_owned()))
      }
      nodes.push(@html.span(class=highlight_class, matched.to_owned()))
      if end < len {
        nodes.push(@html.span(class="", after.to_owned()))
      }
      nodes
    }
    _ => plain
  }
}
