///|
/// Registers the generic fallback lexer for the `moonbit` language id the test
/// models carry (the real lexers are registered by the shell, not the common
/// tier). Idempotent; the registration lives for the test binary. Shared by
/// the view-model test files in this package.
fn register_plain_moonbit() -> Unit {
  @syntax.tokenization_registry.register(
    "moonbit",
    @syntax.PlainTokenizer::new(),
  )
  |> ignore
}

///|
/// A readonly model over `text` tokenizing with the fallback lexer.
fn plain_text_model(text : String) -> @model.TextModel {
  register_plain_moonbit()
  TextModel(@base_common.Uri::memory("plain.mbt"), "", "moonbit", 1, "", text)
}

///|
/// Whether any of a rendered line's tokens carries `class_name`.
fn line_has_token_class(
  line : @view_model.RenderLine,
  class_name : String,
) -> Bool {
  let tokens = line.tokens
  for i in 0..<tokens.get_count() {
    if tokens.get_class_name(i) == class_name {
      return true
    }
  }
  false
}

///|
/// Toy lexer for the multi-line coverage test: a leading `let` is a keyword,
/// `/* ... */` block comments carry across lines through the tokenizer state.
priv struct FrameToy {}

///|
let frame_toy_code : @syntax.TokenizerState = TokenizerState("code")

///|
let frame_toy_comment : @syntax.TokenizerState = TokenizerState("comment")

///|
impl @syntax.LineTokenizer for FrameToy with fn initial_state(_self) {
  frame_toy_code
}

///|
impl @syntax.LineTokenizer for FrameToy with fn tokenize_line(
  _self,
  line_text,
  state,
) {
  let tokens : Array[@syntax.LineToken] = []
  let mut at = 0
  let mut in_comment = state == frame_toy_comment
  if !in_comment &&
    line_text.length() >= 3 &&
    line_text[0] == 'l' &&
    line_text[1] == 'e' &&
    line_text[2] == 't' {
    tokens.push({ start: 0, end: 3, tag: Keyword })
    at = 3
  }
  while at < line_text.length() {
    if in_comment {
      let close = find_marker(line_text, at, '*', '/')
      let end = match close {
        Some(index) => index + 2
        None => line_text.length()
      }
      tokens.push({ start: at, end, tag: Comment })
      in_comment = close is None
      at = end
    } else {
      match find_marker(line_text, at, '/', '*') {
        Some(index) => {
          in_comment = true
          at = index
        }
        None => at = line_text.length()
      }
    }
  }
  (tokens, if in_comment { frame_toy_comment } else { frame_toy_code })
}

///|
fn find_marker(
  line_text : String,
  from : Int,
  first : Char,
  second : Char,
) -> Int? {
  for i in from..<(line_text.length() - 1) {
    if line_text[i].to_int() == first.to_int() &&
      line_text[i + 1].to_int() == second.to_int() {
      return Some(i)
    }
  }
  None
}

///|
test "grammar tokens land per line and multi-line tokens cover every line" {
  @syntax.tokenization_registry.register("frame-toy", FrameToy::{  }) |> ignore
  let model = @model.TextModel(
    @base_common.Uri::memory("frame-toy.mbt"),
    "",
    "frame-toy",
    1,
    "",
    (
      #|let a = 1
      #|/* two
      #|line comment */
      #|let b = 2
    ),
  )
  // Render the frame and read the encoded `mtk<colorId>` classes: line 0 opens
  // with the keyword color, and the block comment colors every line it covers.
  let source = @view_model.FrameSource(model, @language.ProviderResult::empty())
  let frame = @view_model.build_frame(source, {
    start_line: 1,
    end_line: model.get_line_count() + 1,
  })
  assert_eq(frame.lines[0].tokens.get_class_name(0), "mtk3") // Keyword
  assert_true(line_has_token_class(frame.lines[1], "mtk7")) // Comment
  assert_true(line_has_token_class(frame.lines[2], "mtk7")) // Comment
  assert_eq(frame.lines[3].tokens.get_class_name(0), "mtk3") // Keyword
  // Per-line segments: `let`+trailing fill, one comment run, one comment run,
  // `let`+trailing fill.
  assert_eq(model.tokenization.token_count(), 6)
}

///|
test "windowed frames read the memoized whole-document sweep" {
  let chunks = []
  for i in 0..<200 {
    chunks.push("pub fn generated_value_" + i.to_string() + "() -> Int {")
    chunks.push("  " + i.to_string())
    chunks.push("}")
  }
  let model = plain_text_model(chunks.join("\n"))
  let source = @view_model.FrameSource(model, @language.ProviderResult::empty())
  let frame = @view_model.build_frame(source, { start_line: 301, end_line: 361 })
  assert_eq(frame.lines.length(), 60)
  assert_eq(frame.lines[0].line_number, 301)
  for line in frame.lines {
    let mut joined = ""
    let tokens = line.tokens
    for i in 0..<tokens.get_count() {
      joined = joined + tokens.get_token_text(i)
    }
    assert_eq(joined, line.text)
  }
}
