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
/// Builds the token spans of one model line by walking its faithful
/// `LineTokens` — the Monaco `renderLine` input shape (one segment per
/// `[endOffset, metadata]` pair, classed `mtk<colorId>` via the theme). This
/// replaces the legacy `@syntax.Token`-driven `spans_for_line` as the
/// production seam. Zero-length tokens (e.g. the placeholder of a blank line)
/// are dropped so a blank line yields no span, matching the prior behavior.
fn spans_from_line_tokens(line_tokens : LineTokens) -> Array[RenderSpan] {
  let spans : Array[RenderSpan] = []
  let mut start = 0
  for i in 0..<line_tokens.get_count() {
    let end = line_tokens.get_end_offset(i)
    if start < end {
      spans.push({
        start,
        end,
        source_start: start,
        source_end: end,
        injected_text_index: -1,
        class_name: line_tokens.get_class_name(i),
      })
    }
    start = end
  }
  spans
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
fn range_json(range : @base_common.Range) -> Json {
  {
    "startLineNumber": range.start_line_number.to_json(),
    "startColumn": range.start_column.to_json(),
    "endLineNumber": range.end_line_number.to_json(),
    "endColumn": range.end_column.to_json(),
  }
}
