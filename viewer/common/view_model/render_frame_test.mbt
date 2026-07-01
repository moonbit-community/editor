///|
fn frame_for(
  doc : @model.TextSnapshot,
  viewport : @view_model.FrameViewport,
  decorations? : @model.DecorationSet = @model.DecorationSet::empty(),
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
fn join_token_text(line : @view_model.RenderLine) -> String {
  let mut out = ""
  let tokens = line.tokens
  for i in 0..<tokens.get_count() {
    out = out + tokens.get_token_text(i)
  }
  out
}

///|
test "render frame contains highlighted spans and provider surfaces" {
  let doc = @model.TextSnapshot("fn main { // TODO\n  let x = 1\n}")
  let decorations = @model.DecorationSet::from_array([
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
    { start_line: 1, end_line: 3 },
    decorations~,
    providers~,
  )
  assert_eq(frame.lines.length(), 2)
  assert_true(frame.lines[0].tokens.get_count() > 0)
  assert_eq(join_token_text(frame.lines[0]), frame.lines[0].text)
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
    { start_line: 1, end_line: doc.line_count() + 1 },
    providers~,
  )
  let window = frame_for(doc, { start_line: 3, end_line: 6 }, providers~)
  assert_eq(window.line_count, whole.line_count)
  assert_eq(window.lines.length(), 3)
  for index in 0..<window.lines.length() {
    let windowed = window.lines[index]
    let full = whole.lines[index + 2]
    assert_eq(windowed.line_number, full.line_number)
    assert_eq(windowed.offset, full.offset)
    assert_eq(windowed.text, full.text)
    assert_eq(windowed.tokens.get_count(), full.tokens.get_count())
    for i in 0..<windowed.tokens.get_count() {
      assert_eq(
        windowed.tokens.get_end_offset(i),
        full.tokens.get_end_offset(i),
      )
      assert_eq(
        windowed.tokens.get_class_name(i),
        full.tokens.get_class_name(i),
      )
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
      #|{ start_line: 1, end_line: 4 }
    ),
  )
  let pinned = frame_for(doc, { start_line: 99, end_line: 99 })
  debug_inspect(
    pinned.viewport,
    content=(
      #|{ start_line: 3, end_line: 4 }
    ),
  )
}
