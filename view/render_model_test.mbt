///|
test "render model contains highlighted spans and diagnostics" {
  let doc = @core.DocumentSnapshot("fn main { // TODO\n  let x = 1\n}")
  let tokens = @syntax.highlight(doc)
  let decorations = @decorations.DecorationSet::from_array([
    Decoration(Range(13, 17), Diagnostic, "diag-warning", message="todo"),
  ])
  let provider = @language.demo_provider()
  let providers = @language.collect_provider_result(provider, doc)
  let model = render(
    doc,
    { start_line: 0, end_line: 2 },
    tokens,
    decorations,
    providers,
  )
  assert_eq(model.lines.length(), 2)
  assert_true(model.lines[0].spans.length() > 0)
  assert_eq(join_span_text(model.lines[0].spans), model.lines[0].text)
  assert_eq(model.diagnostics.length(), 1)
  assert_true(model.to_json().contains("\"lineCount\""))
}

///|
fn join_span_text(spans : Array[RenderSpan]) -> String {
  let mut out = ""
  for span in spans {
    out = out + span.text
  }
  out
}
