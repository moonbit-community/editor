///|
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
  class_name : String
} derive(Debug)

///|
pub(all) struct RenderLine {
  line_number : Int
  offset : Int
  text : String
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
  let doc = source.tokenized.snapshot
  let start_line = @core.clamp_int(viewport.start_line, 0, doc.line_count() - 1)
  let end_line = @core.clamp_int(
    viewport.end_line,
    start_line + 1,
    doc.line_count(),
  )
  let lines = []
  for line in start_line..<end_line {
    let line_start = doc.line_start_offset(line)
    let line_end = doc.line_end_offset(line)
    let line_range = @core.Range(line_start, line_end)
    let spans = overlay_semantic_tokens(
      spans_for_line(
        line_range,
        source.tokenized.tokens_for_line(line),
        source.line_decorations[line],
      ),
      line_range,
      source.line_semantic_tokens[line],
    )
    lines.push(RenderLine::{
      line_number: line + 1,
      offset: line_start,
      text: doc.line_text(line),
      spans,
    })
  }
  {
    version: doc.version,
    language_id: doc.language_id,
    line_count: doc.line_count(),
    viewport: { start_line, end_line },
    lines,
    diagnostics: source.providers.diagnostics,
    hovers: source.providers.hovers,
  }
}

///|
pub fn RenderFrame::to_json(self : RenderFrame) -> String {
  let mut out = "{"
  out = out + "\"version\":" + self.version.to_string()
  out = out + ",\"languageId\":" + json_string(self.language_id)
  out = out + ",\"lineCount\":" + self.line_count.to_string()
  out = out + ",\"viewport\":" + viewport_json(self.viewport)
  out = out + ",\"lines\":" + lines_json(self.lines)
  out = out + ",\"diagnostics\":" + diagnostics_json(self.diagnostics)
  out = out + ",\"hovers\":" + hovers_json(self.hovers)
  out + "}"
}

///|
/// The text a span styles, sliced from its owning line.
pub fn RenderLine::span_text(self : RenderLine, span : RenderSpan) -> String {
  self.text[span.start:span.end].to_owned()
}

///|
fn spans_for_line(
  line_range : @core.Range,
  tokens : Array[@syntax.Token],
  line_decorations : Array[@decorations.Decoration],
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
        class_name: @syntax.Plain.css_class(),
      })
    }
    let mut class_name = token.tag.css_class()
    for decoration in line_decorations {
      if decoration.range.intersects(Range(start, end)) {
        class_name = class_name + " " + decoration.class_name
      }
    }
    spans.push({
      start: start - line_range.start,
      end: end - line_range.start,
      class_name,
    })
    cursor = end
  }
  if cursor < line_range.end {
    spans.push({
      start: cursor - line_range.start,
      end: line_range.end - line_range.start,
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
  line_range : @core.Range,
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
    class_name: span.class_name + extra_class,
  }
}

///|
pub fn semantic_token_class(token_type : String) -> String {
  "sem-" + token_type
}

///|
fn viewport_json(viewport : FrameViewport) -> String {
  let mut out = "{"
  out = out + "\"startLine\":" + viewport.start_line.to_string()
  out = out + ",\"endLine\":" + viewport.end_line.to_string()
  out + "}"
}

///|
fn lines_json(lines : Array[RenderLine]) -> String {
  let mut out = "["
  for i in 0..<lines.length() {
    if i > 0 {
      out = out + ","
    }
    out = out + line_json(lines[i])
  }
  out + "]"
}

///|
fn line_json(line : RenderLine) -> String {
  let mut out = "{"
  out = out + "\"lineNumber\":" + line.line_number.to_string()
  out = out + ",\"offset\":" + line.offset.to_string()
  out = out + ",\"text\":" + json_string(line.text)
  out = out + ",\"spans\":" + spans_json(line)
  out + "}"
}

///|
fn spans_json(line : RenderLine) -> String {
  let mut out = "["
  for i in 0..<line.spans.length() {
    if i > 0 {
      out = out + ","
    }
    let span = line.spans[i]
    out = out + "{"
    out = out + "\"start\":" + span.start.to_string()
    out = out + ",\"end\":" + span.end.to_string()
    out = out + ",\"text\":" + json_string(line.span_text(span))
    out = out + ",\"className\":" + json_string(span.class_name)
    out = out + "}"
  }
  out + "]"
}

///|
fn diagnostics_json(diagnostics : Array[@language.Diagnostic]) -> String {
  let mut out = "["
  for i in 0..<diagnostics.length() {
    if i > 0 {
      out = out + ","
    }
    let diagnostic = diagnostics[i]
    out = out + "{"
    out = out + "\"range\":" + range_json(diagnostic.range)
    out = out + ",\"severity\":" + json_string(diagnostic.severity.label())
    out = out + ",\"message\":" + json_string(diagnostic.message)
    out = out + "}"
  }
  out + "]"
}

///|
fn hovers_json(hovers : Array[@language.Hover]) -> String {
  let mut out = "["
  for i in 0..<hovers.length() {
    if i > 0 {
      out = out + ","
    }
    let hover = hovers[i]
    out = out + "{"
    out = out + "\"range\":" + range_json(hover.range)
    out = out + ",\"contents\":" + json_string(hover.contents)
    out = out + "}"
  }
  out + "]"
}

///|
fn range_json(range : @core.Range) -> String {
  let mut out = "{"
  out = out + "\"start\":" + range.start.to_string()
  out = out + ",\"end\":" + range.end.to_string()
  out + "}"
}

///|
fn json_string(value : String) -> String {
  value.escape(quote=true)
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
