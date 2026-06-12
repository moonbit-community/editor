///|
/// Hand-written MoonBit lexer behind the `syntax.LineTokenizer` contract.
/// Monarch's state-machine structure, but every rule set is a `lexmatch`
/// compiled to a tagged DFA at build time — no runtime regexes, no
/// grammar data.
///
/// The carried `TokenizerState` encodes the lexer mode stack as one
/// character per mode, bottom first:
///   'n' normal expression code (always the bottom)
///   's' inside a `"` string
///   'm' inside a `$|` multiline-string line
///   'i' inside a `\{ ... }` string interpolation
///   'b' inside a plain `{ ... }` brace pair nested in an interpolation
/// No MoonBit string construct survives a line end, so every line both
/// enters and leaves at "n"; the stack only drives the within-line modes.
pub enum MoonbitTokenizer {
  MoonbitTokenizer
}

///|
pub fn MoonbitTokenizer::new() -> MoonbitTokenizer {
  MoonbitTokenizer
}

///|
pub impl @syntax.LineTokenizer for MoonbitTokenizer with fn initial_state(_self) {
  TokenizerState("n")
}

///|
pub impl @syntax.LineTokenizer for MoonbitTokenizer with fn tokenize_line(
  _self,
  line_text,
  state,
) {
  let stack = decode_stack(state)
  let tokens : Array[@syntax.LineToken] = []
  let mut at = 0
  let mut view = line_text[:]
  while view.length() > 0 {
    let top = stack[stack.length() - 1]
    let (op, rest) = match top {
      's' => string_step(view)
      'm' => dollar_step(view)
      _ => normal_step(view, top)
    }
    let consumed = view.length() - rest.length()
    match op {
      Blank => ()
      Emit(tag) => push_token(tokens, at, at + consumed, tag)
      Push(tag, mode) => {
        push_token(tokens, at, at + consumed, tag)
        stack.push(mode)
      }
      Pop(tag) => {
        push_token(tokens, at, at + consumed, tag)
        if stack.length() > 1 {
          ignore(stack.pop())
        }
      }
    }
    at = at + consumed
    view = rest
  }
  (tokens, TokenizerState("n"))
}

///|
/// Contiguous same-tag lexemes coalesce into one token, so a plain
/// string renders as a single `tok-string` span (quote, content, quote)
/// instead of three.
fn push_token(
  tokens : Array[@syntax.LineToken],
  start : Int,
  end : Int,
  tag : @syntax.HighlightTag,
) -> Unit {
  if tokens.length() > 0 {
    let last = tokens[tokens.length() - 1]
    if last.tag == tag && last.end == start {
      tokens[tokens.length() - 1] = { start: last.start, end, tag }
      return
    }
  }
  tokens.push({ start, end, tag })
}

///|
fn decode_stack(state : @syntax.TokenizerState) -> Array[Char] {
  let stack : Array[Char] = []
  for mode in state.0 {
    stack.push(mode)
  }
  if stack.length() == 0 {
    stack.push('n')
  }
  stack
}

///|
/// What one lexeme does to the token stream and the mode stack.
priv enum StepOp {
  Blank
  Emit(@syntax.HighlightTag)
  Push(@syntax.HighlightTag, Char)
  Pop(@syntax.HighlightTag)
}

///|
/// Expression code: the rules for modes 'n', 'i', and 'b'. The brace
/// arms need the current mode because `}` closes an interpolation in 'i'
/// but is a plain delimiter elsewhere.
fn normal_step(view : StringView, top : Char) -> (StepOp, StringView) {
  lexmatch view with longest {
    ("[ \t]+", rest) => (Blank, rest)
    ("///.*", rest) => (Emit(CommentDoc), rest)
    ("//.*", rest) => (Emit(Comment), rest)
    ("#\|.*", rest) => (Emit(String), rest)
    ("\$\|", rest) => (Push(String, 'm'), rest)
    ("#[a-zA-Z_][a-zA-Z0-9_.]*", rest) => (Emit(Attribute), rest)
    ("b?\"", rest) => (Push(String, 's'), rest)
    ("b?'(?:\\.|[^'\\])+'", rest) => (Emit(String), rest)
    ("0[xX][0-9a-fA-F_]+[UL]*", rest) => (Emit(Number), rest)
    ("0[oO][0-7_]+[UL]*", rest) => (Emit(Number), rest)
    ("0[bB][01_]+[UL]*", rest) => (Emit(Number), rest)
    ("[0-9][0-9_]*(?:\.[0-9_]+)?(?:[eE][+\-]?[0-9]+)?[ULN]*", rest) =>
      (Emit(Number), rest)
    ("@[a-zA-Z_][a-zA-Z0-9_/]*", rest) => (Emit(Type), rest)
    ("[a-zA-Z_][a-zA-Z0-9_]*" as word, rest) =>
      (Emit(classify_word(word)), rest)
    ("[+\-*/%=<>!&^~?\|]+", rest) => (Emit(Operator), rest)
    ("[()\[\],;:.]", rest) => (Emit(Delimiter), rest)
    ("[{]", rest) =>
      if top == 'i' || top == 'b' {
        (Push(Delimiter, 'b'), rest)
      } else {
        (Emit(Delimiter), rest)
      }
    ("[}]", rest) =>
      match top {
        'i' => (Pop(StringEscape), rest)
        'b' => (Pop(Delimiter), rest)
        _ => (Emit(Delimiter), rest)
      }
    (".", rest) => (Emit(Punctuation), rest)
    // Unreachable while `.` covers the full charset (it includes lone
    // surrogates); consumes the rest defensively so the driver loop can
    // never stall on zero progress.
    _ => (Blank, ""[:])
  }
}

///|
/// Inside a `"` string: chunks, escapes, `\{` opening an interpolation,
/// and the closing quote. An unterminated string falls to the `.` arm
/// one character at a time and the line-end reset recovers the mode.
fn string_step(view : StringView) -> (StepOp, StringView) {
  lexmatch view with longest {
    ("\\u[{][0-9a-fA-F]+[}]", rest) => (Emit(StringEscape), rest)
    ("\\[{]", rest) => (Push(StringEscape, 'i'), rest)
    ("\\.", rest) => (Emit(StringEscape), rest)
    ("\"", rest) => (Pop(String), rest)
    ("[^\"\\]+", rest) => (Emit(String), rest)
    (".", rest) => (Emit(String), rest)
    _ => (Blank, ""[:])
  }
}

///|
/// The rest of a `$|` multiline-string line: literal text plus the same
/// escape and interpolation forms as `"` strings, terminated only by the
/// line end.
fn dollar_step(view : StringView) -> (StepOp, StringView) {
  lexmatch view with longest {
    ("\\[{]", rest) => (Push(StringEscape, 'i'), rest)
    ("\\.", rest) => (Emit(StringEscape), rest)
    ("[^\\]+", rest) => (Emit(String), rest)
    (".", rest) => (Emit(String), rest)
    _ => (Blank, ""[:])
  }
}

///|
/// The Monarch `@keywords` idiom: the identifier rule binds the word and
/// classification is a word-set lookup, so no `\b` boundary is needed.
fn classify_word(word : StringView) -> @syntax.HighlightTag {
  match word {
    "fn"
    | "let"
    | "mut"
    | "const"
    | "pub"
    | "priv"
    | "struct"
    | "enum"
    | "trait"
    | "impl"
    | "with"
    | "derive"
    | "type"
    | "typealias"
    | "traitalias"
    | "fnalias"
    | "suberror"
    | "raise"
    | "try"
    | "catch"
    | "noraise"
    | "async"
    | "test"
    | "if"
    | "else"
    | "match"
    | "guard"
    | "while"
    | "for"
    | "in"
    | "loop"
    | "break"
    | "continue"
    | "return"
    | "as"
    | "is"
    | "not"
    | "using"
    | "import"
    | "extern"
    | "declare"
    | "where"
    | "nobreak" => Keyword
    "true" | "false" => Constant
    "self" => Variable
    _ => if is_capitalized(word) { Type } else { Identifier }
  }
}

///|
fn is_capitalized(word : StringView) -> Bool {
  let unit = word[0].to_int()
  65 <= unit && unit <= 90
}
