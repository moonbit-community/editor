///|
/// Everything needed to emit viewport-scoped frames for one document
/// version: the backing text model (whose `tokenization` part memoizes the
/// grammar tokens and whose decoration storage the view model queries
/// lazily per viewport) plus the feature data pushed by providers.
/// Building a frame from a source never re-tokenizes.
pub struct FrameSource {
  model : @model.TextModel
  providers : @language.ProviderResult
}

///|
/// Builds a frame source.
pub fn FrameSource::FrameSource(
  model : @model.TextModel,
  providers : @language.ProviderResult,
) -> FrameSource {
  { model, providers }
}

///|
/// 1-based half-open view-line window to render: covers 1-based view lines
/// `start_line ..< end_line` (Monaco's view coordinate space).
pub(all) struct FrameViewport {
  start_line : Int
  end_line : Int
} derive(Debug)

///|
/// One rendered view line, the Monaco `ViewLineData` shape: text, source
/// offset, per-column model/injected-text maps, the line's faithful token
/// stream (`tokens : IViewLineTokens`), and the inline decorations injected
/// text contributes (`injected_inline_decorations`). The token stream is the
/// single source of styled segments; views derive `LinePart`s straight from it.
pub(all) struct RenderLine {
  line_number : Int
  offset : Int
  text : String
  model_columns : Array[Int]
  injected_text_indices : Array[Int]
  tokens : &@tokens.IViewLineTokens
  injected_inline_decorations : Array[@view_layout.InlineDecoration]
}

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
}

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
    "tokens": Json::array(tokens_json(line)),
  }
}

///|
/// The line's styled token segments, the Monaco `ViewLineData.tokens` shape:
/// one `{ endOffset, className, text }` per non-empty token. Zero-length tokens
/// (e.g. a blank line's placeholder) are dropped, matching the rendered spans.
fn tokens_json(line : RenderLine) -> Array[Json] {
  let out : Array[Json] = []
  let tokens = line.tokens
  let mut start = 0
  for i in 0..<tokens.get_count() {
    let end = tokens.get_end_offset(i)
    if start < end {
      out.push({
        "endOffset": end.to_json(),
        "className": tokens.get_class_name(i).to_json(),
        "text": tokens.get_token_text(i).to_json(),
      })
    }
    start = end
  }
  out
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
