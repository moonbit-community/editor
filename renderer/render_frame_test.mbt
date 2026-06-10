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
