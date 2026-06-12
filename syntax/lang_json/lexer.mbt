///|
/// JSON (and JSONC comments) behind the `syntax.LineTokenizer` contract:
/// the trivial two-state machine. State "n" is normal; state "c" is
/// inside a `/* ... */` block comment, the one construct that carries
/// across lines.
pub enum JsonTokenizer {
  JsonTokenizer
}

///|
pub fn JsonTokenizer::new() -> JsonTokenizer {
  JsonTokenizer
}

///|
pub impl @syntax.LineTokenizer for JsonTokenizer with fn initial_state(_self) {
  TokenizerState("n")
}

///|
pub impl @syntax.LineTokenizer for JsonTokenizer with fn tokenize_line(
  _self,
  line_text,
  state,
) {
  let tokens : Array[@syntax.LineToken] = []
  let mut in_comment = state == TokenizerState("c")
  let mut at = 0
  let mut view = line_text[:]
  while view.length() > 0 {
    let (op, rest) = if in_comment {
      comment_step(view)
    } else {
      normal_step(view)
    }
    let consumed = view.length() - rest.length()
    match op {
      Blank => ()
      Emit(tag) => tokens.push({ start: at, end: at + consumed, tag })
      EnterComment => {
        tokens.push({ start: at, end: at + consumed, tag: Comment })
        in_comment = true
      }
      LeaveComment => {
        tokens.push({ start: at, end: at + consumed, tag: Comment })
        in_comment = false
      }
    }
    at = at + consumed
    view = rest
  }
  (tokens, TokenizerState(if in_comment { "c" } else { "n" }))
}

///|
priv enum StepOp {
  Blank
  Emit(@syntax.HighlightTag)
  EnterComment
  LeaveComment
}

///|
fn normal_step(view : StringView) -> (StepOp, StringView) {
  lexmatch view with longest {
    ("[ \t]+", rest) => (Blank, rest)
    ("//.*", rest) => (Emit(Comment), rest)
    ("/\*", rest) => (EnterComment, rest)
    // A terminated string is a property name when the next significant
    // character is a colon — the Monarch lookahead idiom done by peeking
    // the rest of the line instead.
    ("\"(?:\\.|[^\"\\])*\"", rest) =>
      (Emit(if colon_follows(rest) { Attribute } else { String }), rest)
    ("\"(?:\\.|[^\"\\])*", rest) => (Emit(String), rest)
    ("-?[0-9]+(?:\.[0-9]+)?(?:[eE][+\-]?[0-9]+)?", rest) => (Emit(Number), rest)
    ("[a-zA-Z_][a-zA-Z0-9_]*" as word, rest) =>
      (
        Emit(
          match word {
            "true" | "false" | "null" => Constant
            _ => Invalid
          },
        ),
        rest,
      )
    ("[{}\[\],:]", rest) => (Emit(Delimiter), rest)
    (".", rest) => (Emit(Punctuation), rest)
    // Unreachable: the loop never feeds an empty view and `.` matches
    // any character.
    _ => (Blank, view)
  }
}

///|
fn comment_step(view : StringView) -> (StepOp, StringView) {
  lexmatch view with longest {
    ("\*/", rest) => (LeaveComment, rest)
    ("[^*]+", rest) => (Emit(Comment), rest)
    ("\*", rest) => (Emit(Comment), rest)
    _ => (Blank, view)
  }
}

///|
fn colon_follows(rest : StringView) -> Bool {
  for i in 0..<rest.length() {
    let unit = rest[i].to_int()
    if unit == 32 || unit == 9 {
      continue
    }
    return unit == 58
  }
  false
}
