///|
/// Zero-based half-open view-line window to render.
pub(all) struct FrameViewport {
  start_line : Int
  end_line : Int
} derive(Debug)

///|
/// A styled segment of one line, as line-relative UTF-16 columns. Spans
/// carry no text of their own; views slice the owning line's text at
/// emission time.
pub(all) struct RenderSpan {
  start : Int
  end : Int
  source_start : Int
  source_end : Int
  injected_text_index : Int
  class_name : String
} derive(Debug)

///|
/// One rendered view line with text, source offset, per-column model mapping,
/// injected-text mapping, and styled spans.
pub(all) struct RenderLine {
  line_number : Int
  offset : Int
  text : String
  model_columns : Array[Int]
  injected_text_indices : Array[Int]
  spans : Array[RenderSpan]
} derive(Debug)

///|
/// A viewport-scoped render frame, the Monaco `ViewportData` role: only
/// the lines of the requested window, plus the document facts views need
/// to place them (`viewport`, `line_count`). Frames are cheap to rebuild
/// from a `FrameSource` whenever the window shifts.
pub(all) struct RenderFrame {
  version : Int
  language_id : String
  line_count : Int
  viewport : FrameViewport
  lines : Array[RenderLine]
  diagnostics : Array[@language.Diagnostic]
  hovers : Array[@language.Hover]
} derive(Debug)

///|
/// Builds the frame for one viewport window from the per-line buckets of
/// the source: O(window), independent of document length and token count.
pub fn build_frame(
  source : FrameSource,
  viewport : FrameViewport,
) -> RenderFrame {
  ViewModel(source).render_frame(viewport)
}

///|
/// JSON shape used by tests and browser observability.
pub impl ToJson for RenderFrame with fn to_json(self) {
  {
    "version": self.version.to_json(),
    "languageId": self.language_id.to_json(),
    "lineCount": self.line_count.to_json(),
    "viewport": viewport_json(self.viewport),
    "lines": Json::array(self.lines.map(line_json)),
    "diagnostics": Json::array(self.diagnostics.map(diagnostic_json)),
    "hovers": Json::array(self.hovers.map(hover_json)),
  }
}

///|
/// The text a span styles, sliced from its owning line.
pub fn RenderLine::span_text(self : RenderLine, span : RenderSpan) -> String {
  self.text[span.start:span.end].to_owned()
}

///|
/// Model column at a rendered view column.
pub fn RenderLine::model_column_at_column(
  self : RenderLine,
  column : Int,
) -> Int {
  let column = @base_common.clamp_int(column, 0, self.text.length())
  match self.model_columns.get(column) {
    Some(model_column) => model_column
    None => column
  }
}

///|
/// Source document offset at a rendered view column.
pub fn RenderLine::source_offset_at_column(
  self : RenderLine,
  column : Int,
) -> Int {
  self.model_line_start_offset() + self.model_column_at_column(column)
}

///|
/// Source offset of the model line that produced this rendered line.
pub fn RenderLine::model_line_start_offset(self : RenderLine) -> Int {
  self.offset - self.model_column_at_column(0)
}

///|
/// Inlay-hint source index at a rendered view column, or `-1` for source text.
pub fn RenderLine::injected_text_index_at_column(
  self : RenderLine,
  column : Int,
) -> Int {
  let column = @base_common.clamp_int(column, 0, self.text.length())
  match self.injected_text_indices.get(column) {
    Some(index) => index
    None => -1
  }
}

///|
/// Rendered view column corresponding to a source document offset.
pub fn RenderLine::view_column_at_source_offset(
  self : RenderLine,
  offset : Int,
) -> Int {
  let model_column = @base_common.clamp_int(
    offset - self.model_line_start_offset(),
    0,
    self.model_column_at_column(self.text.length()),
  )
  for column in 0..<=self.text.length() {
    if self.model_column_at_column(column) >= model_column {
      return column
    }
  }
  self.text.length()
}

///|
/// Builds the syntax-token spans of one model line. Decorations are no longer
/// overlaid onto token spans here: they are applied as view-coordinate inline
/// decorations at render time (`ViewModelDecorations`), so spans carry only the
/// tokenizer's classes.
fn spans_for_line(
  line_range : @base_common.OffsetRange,
  tokens : Array[@syntax.Token],
) -> Array[RenderSpan] {
  let spans = []
  let mut cursor = line_range.start
  for token in tokens {
    // The bucket holds exactly the tokens intersecting this line.
    let start = max_int(token.range.start, line_range.start)
    let end = min_int(token.range.end, line_range.end)
    if cursor < start {
      spans.push({
        start: cursor - line_range.start,
        end: start - line_range.start,
        source_start: cursor - line_range.start,
        source_end: start - line_range.start,
        injected_text_index: -1,
        class_name: @syntax.Plain.css_class(),
      })
    }
    spans.push({
      start: start - line_range.start,
      end: end - line_range.start,
      source_start: start - line_range.start,
      source_end: end - line_range.start,
      injected_text_index: -1,
      class_name: token.tag.css_class(),
    })
    cursor = end
  }
  if cursor < line_range.end {
    spans.push({
      start: cursor - line_range.start,
      end: line_range.end - line_range.start,
      source_start: cursor - line_range.start,
      source_end: line_range.end - line_range.start,
      injected_text_index: -1,
      class_name: @syntax.Plain.css_class(),
    })
  }
  spans
}

///|
/// Splits syntax spans at semantic token boundaries and appends a
/// `sem-<type>` class on the overlapping segments, so semantic colors win
/// over syntax colors where both apply.
fn overlay_semantic_tokens(
  spans : Array[RenderSpan],
  line_range : @base_common.OffsetRange,
  semantic_tokens : Array[@language.SemanticToken],
) -> Array[RenderSpan] {
  if semantic_tokens.length() == 0 {
    return spans
  }
  let out : Array[RenderSpan] = []
  for span in spans {
    let span_start = line_range.start + span.start
    let span_end = line_range.start + span.end
    let mut cursor = span_start
    for token in semantic_tokens {
      if token.token_type == "" {
        continue
      }
      let segment_start = max_int(token.range.start, cursor)
      let segment_end = min_int(token.range.end, span_end)
      if segment_start >= segment_end {
        continue
      }
      if cursor < segment_start {
        out.push(slice_span(span, span_start, cursor, segment_start, ""))
      }
      out.push(
        slice_span(
          span,
          span_start,
          segment_start,
          segment_end,
          " " + semantic_token_class(token.token_type),
        ),
      )
      cursor = segment_end
    }
    if cursor == span_start {
      out.push(span)
    } else if cursor < span_end {
      out.push(slice_span(span, span_start, cursor, span_end, ""))
    }
  }
  out
}

///|
fn slice_span(
  span : RenderSpan,
  span_start : Int,
  absolute_start : Int,
  absolute_end : Int,
  extra_class : String,
) -> RenderSpan {
  {
    start: span.start + (absolute_start - span_start),
    end: span.start + (absolute_end - span_start),
    source_start: absolute_start - span_start + span.source_start,
    source_end: absolute_end - span_start + span.source_start,
    injected_text_index: span.injected_text_index,
    class_name: span.class_name + extra_class,
  }
}

///|
/// Normalized CSS class for an LSP semantic token type.
pub fn semantic_token_class(token_type : String) -> String {
  "sem-" + token_type
}

///|
fn viewport_json(viewport : FrameViewport) -> Json {
  {
    "startLine": viewport.start_line.to_json(),
    "endLine": viewport.end_line.to_json(),
  }
}

///|
fn line_json(line : RenderLine) -> Json {
  {
    "lineNumber": line.line_number.to_json(),
    "offset": line.offset.to_json(),
    "text": line.text.to_json(),
    "spans": Json::array(line.spans.map(span => span_json(line, span))),
  }
}

///|
fn span_json(line : RenderLine, span : RenderSpan) -> Json {
  {
    "start": span.start.to_json(),
    "end": span.end.to_json(),
    "text": line.span_text(span).to_json(),
    "className": span.class_name.to_json(),
  }
}

///|
fn diagnostic_json(diagnostic : @language.Diagnostic) -> Json {
  {
    "range": range_json(diagnostic.range),
    "severity": diagnostic.severity.label().to_json(),
    "message": diagnostic.message.to_json(),
  }
}

///|
fn hover_json(hover : @language.Hover) -> Json {
  {
    "range": range_json(hover.range),
    "contents": Json::array(hover.contents.map(hover_content_json)),
  }
}

///|
fn hover_content_json(content : @language.HoverContent) -> Json {
  match content {
    PlainText(text) =>
      { "kind": Json::string("plaintext"), "value": text.to_json() }
    Markdown(text) =>
      { "kind": Json::string("markdown"), "value": text.to_json() }
  }
}

///|
fn range_json(range : @base_common.OffsetRange) -> Json {
  { "start": range.start.to_json(), "end": range.end.to_json() }
}

///|
fn min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}
