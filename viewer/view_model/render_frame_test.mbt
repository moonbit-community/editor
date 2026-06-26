///|
fn frame_for(
  doc : @model.TextSnapshot,
  viewport : @view_model.FrameViewport,
  decorations? : @decorations.DecorationSet = @decorations.DecorationSet::empty(),
  providers? : @language.ProviderResult = @language.ProviderResult::empty(),
) -> @view_model.RenderFrame {
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  @view_model.build_frame(
    FrameSource(tokenized, decorations, providers),
    viewport,
  )
}

///|
fn join_span_text(line : @view_model.RenderLine) -> String {
  let mut out = ""
  for span in line.spans {
    out = out + line.span_text(span)
  }
  out
}

///|
test "render frame contains highlighted spans and provider surfaces" {
  let doc = @model.TextSnapshot("fn main { // TODO\n  let x = 1\n}")
  let decorations = @decorations.DecorationSet::from_array([
    Decoration(Range(1, 14, 1, 18), Diagnostic, "diag-warning", message="todo"),
  ])
  let providers = @language.ProviderResult::{
    hovers: [],
    diagnostics: [
      { range: Range(1, 14, 1, 18), severity: Warning, message: "todo" },
    ],
    definitions: [],
    symbols: [],
  }
  let frame = frame_for(
    doc,
    { start_line: 0, end_line: 2 },
    decorations~,
    providers~,
  )
  assert_eq(frame.lines.length(), 2)
  assert_true(frame.lines[0].spans.length() > 0)
  assert_eq(join_span_text(frame.lines[0]), frame.lines[0].text)
  assert_eq(frame.diagnostics.length(), 1)
  assert_true(frame.to_json().stringify().contains("\"lineCount\""))
}

///|
test "window builds match the matching slice of a whole-document build" {
  let doc = @model.TextSnapshot(
    "fn main { // TODO\n  let x = 1\n  let y = 2\n}\n\nfn other {\n  3\n}",
  )
  let providers = @language.ProviderResult::{
    hovers: [],
    diagnostics: [],
    definitions: [],
    symbols: [],
  }
  let whole = frame_for(
    doc,
    { start_line: 0, end_line: doc.line_count() },
    providers~,
  )
  let window = frame_for(doc, { start_line: 2, end_line: 5 }, providers~)
  assert_eq(window.line_count, whole.line_count)
  assert_eq(window.lines.length(), 3)
  for index in 0..<window.lines.length() {
    let windowed = window.lines[index]
    let full = whole.lines[index + 2]
    assert_eq(windowed.line_number, full.line_number)
    assert_eq(windowed.offset, full.offset)
    assert_eq(windowed.text, full.text)
    assert_eq(windowed.spans.length(), full.spans.length())
    for i in 0..<windowed.spans.length() {
      assert_eq(windowed.spans[i].start, full.spans[i].start)
      assert_eq(windowed.spans[i].end, full.spans[i].end)
      assert_eq(windowed.spans[i].class_name, full.spans[i].class_name)
    }
  }
}

///|
test "viewport bounds clamp to the document" {
  let doc = @model.TextSnapshot("a\nb\nc")
  let frame = frame_for(doc, { start_line: -5, end_line: 99 })
  debug_inspect(
    frame.viewport,
    content=(
      #|{ start_line: 0, end_line: 3 }
    ),
  )
  let pinned = frame_for(doc, { start_line: 99, end_line: 99 })
  debug_inspect(
    pinned.viewport,
    content=(
      #|{ start_line: 2, end_line: 3 }
    ),
  )
}
