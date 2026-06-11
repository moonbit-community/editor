///|
test "render frame contains highlighted spans and provider surfaces" {
  let doc = @core.DocumentSnapshot("fn main { // TODO\n  let x = 1\n}")
  let tokens = @syntax.highlight(doc)
  let decorations = @decorations.DecorationSet::from_array([
    Decoration(Range(13, 17), Diagnostic, "diag-warning", message="todo"),
  ])
  let providers = @language.ProviderResult::{
    hovers: [],
    diagnostics: [{ range: Range(13, 17), severity: Warning, message: "todo" }],
    definitions: [],
    symbols: [],
    semantic_tokens: [],
  }
  let frame = @renderer.build_frame(
    doc,
    { start_line: 0, end_line: 2 },
    tokens,
    decorations,
    providers,
  )
  assert_eq(frame.lines.length(), 2)
  assert_true(frame.lines[0].spans.length() > 0)
  assert_eq(join_span_text(frame.lines[0].spans), frame.lines[0].text)
  assert_eq(frame.diagnostics.length(), 1)
  assert_true(frame.to_json().contains("\"lineCount\""))
}

///|
fn join_span_text(spans : Array[@renderer.RenderSpan]) -> String {
  let mut out = ""
  for span in spans {
    out = out + span.text
  }
  out
}

///|
test "semantic tokens split spans and win on the overlapping segment" {
  let doc = @core.DocumentSnapshot("fn main { run() }")
  let tokens = @syntax.highlight(doc)
  let providers = @language.ProviderResult::{
    hovers: [],
    diagnostics: [],
    definitions: [],
    symbols: [],
    // `main` is offsets 3..7; cover only `mai` to force a span split.
    semantic_tokens: [
      { range: Range(3, 6), token_type: "function" },
      { range: Range(10, 13), token_type: "function" },
    ],
  }
  let frame = @renderer.build_frame(
    doc,
    { start_line: 0, end_line: 1 },
    tokens,
    @decorations.DecorationSet::empty(),
    providers,
  )
  let line = frame.lines[0]
  assert_eq(join_span_text(line.spans), line.text)
  let classes : Array[String] = []
  for span in line.spans {
    if span.class_name.contains("sem-function") {
      classes.push(span.text + ":" + span.class_name)
    }
  }
  debug_inspect(
    classes,
    content=(
      #|["mai:tok-identifier sem-function", "run:tok-identifier sem-function"]
    ),
  )
  // The split keeps the rest of the identifier on the syntax class alone.
  let mut tail = ""
  for span in line.spans {
    if span.text == "n" {
      tail = span.class_name
    }
  }
  assert_eq(tail, "tok-identifier")
}
