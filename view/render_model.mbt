///|
/// Compatibility viewport window used by the legacy render model.
pub(all) struct Viewport {
  start_line : Int
  end_line : Int
} derive(Debug)

///|
/// Compatibility rendered span with owned text.
pub(all) struct RenderSpan {
  start : Int
  end : Int
  text : String
  class_name : String
} derive(Debug)

///|
/// Compatibility rendered line with owned text spans.
pub(all) struct RenderLine {
  line_number : Int
  offset : Int
  text : String
  spans : Array[RenderSpan]
} derive(Debug)

///|
/// Compatibility render model kept separate from the active `renderer` path.
pub(all) struct RenderModel {
  version : Int
  language_id : String
  line_count : Int
  viewport : Viewport
  lines : Array[RenderLine]
  diagnostics : Array[@language.Diagnostic]
  hovers : Array[@language.Hover]
} derive(Debug)

///|
/// Builds the legacy viewport render model.
pub fn render(
  doc : @model.TextSnapshot,
  viewport : Viewport,
  tokens : Array[@syntax.Token],
  decoration_set : @decorations.DecorationSet,
  providers : @language.ProviderResult,
) -> RenderModel {
  let start_line = @base_common.clamp_int(
    viewport.start_line,
    0,
    doc.line_count() - 1,
  )
  let end_line = @base_common.clamp_int(
    viewport.end_line,
    start_line + 1,
    doc.line_count(),
  )
  let lines = []
  for line in start_line..<end_line {
    let line_start = doc.line_start_offset(line)
    let line_end = doc.line_end_offset(line)
    let line_range = @base_common.Range(line_start, line_end)
    let spans = spans_for_line(doc, line_range, tokens, decoration_set)
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
    diagnostics: providers.diagnostics,
    hovers: providers.hovers,
  }
}

///|
/// JSON shape used by older tests and compatibility callers.
pub impl ToJson for RenderModel with fn to_json(self) {
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
fn spans_for_line(
  doc : @model.TextSnapshot,
  line_range : @base_common.Range,
  tokens : Array[@syntax.Token],
  decoration_set : @decorations.DecorationSet,
) -> Array[RenderSpan] {
  let spans = []
  let line_decorations = decoration_set.between(line_range)
  let mut cursor = line_range.start
  for token in tokens {
    if token.range.intersects(line_range) {
      let start = max_int(token.range.start, line_range.start)
      let end = min_int(token.range.end, line_range.end)
      if cursor < start {
        spans.push({
          start: cursor - line_range.start,
          end: start - line_range.start,
          text: doc.text[cursor:start].to_owned(),
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
        text: doc.text[start:end].to_owned(),
        class_name,
      })
      cursor = end
    }
  }
  if cursor < line_range.end {
    spans.push({
      start: cursor - line_range.start,
      end: line_range.end - line_range.start,
      text: doc.text[cursor:line_range.end].to_owned(),
      class_name: @syntax.Plain.css_class(),
    })
  }
  spans
}

///|
fn viewport_json(viewport : Viewport) -> Json {
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
    "spans": Json::array(line.spans.map(span_json)),
  }
}

///|
fn span_json(span : RenderSpan) -> Json {
  {
    "start": span.start.to_json(),
    "end": span.end.to_json(),
    "text": span.text.to_json(),
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
