///|
pub(all) struct Viewport {
  start_line : Int
  end_line : Int
} derive(Debug)

///|
pub(all) struct RenderSpan {
  start : Int
  end : Int
  text : String
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
pub fn render(
  doc : @core.DocumentSnapshot,
  viewport : Viewport,
  tokens : Array[@syntax.Token],
  decoration_set : @decorations.DecorationSet,
  providers : @language.ProviderResult,
) -> RenderModel {
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
pub fn RenderModel::to_json(self : RenderModel) -> String {
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
fn spans_for_line(
  doc : @core.DocumentSnapshot,
  line_range : @core.Range,
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
fn viewport_json(viewport : Viewport) -> String {
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
  out = out + ",\"spans\":" + spans_json(line.spans)
  out + "}"
}

///|
fn spans_json(spans : Array[RenderSpan]) -> String {
  let mut out = "["
  for i in 0..<spans.length() {
    if i > 0 {
      out = out + ","
    }
    let span = spans[i]
    out = out + "{"
    out = out + "\"start\":" + span.start.to_string()
    out = out + ",\"end\":" + span.end.to_string()
    out = out + ",\"text\":" + json_string(span.text)
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
