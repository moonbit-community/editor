///|
/// Toy two-state tokenizer: `/* ... */` block comments carried across
/// lines, everything else untokenized. Small enough to assert exact
/// offsets, real enough to prove the state contract.
priv struct BlockCommentToy {}

///|
let toy_code : @syntax.TokenizerState = TokenizerState("code")

///|
let toy_comment : @syntax.TokenizerState = TokenizerState("comment")

///|
impl @syntax.LineTokenizer for BlockCommentToy with fn initial_state(_self) {
  toy_code
}

///|
impl @syntax.LineTokenizer for BlockCommentToy with fn tokenize_line(
  _self,
  line_text,
  state,
) {
  let tokens : Array[@syntax.LineToken] = []
  let mut at = 0
  let mut in_comment = state == toy_comment
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
  (tokens, if in_comment { toy_comment } else { toy_code })
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
test "block comment state threads across lines" {
  let toy : &@syntax.LineTokenizer = BlockCommentToy::{  }
  let (line0, after_open) = toy.tokenize_line("aa /* bb", toy.initial_state())
  debug_inspect(
    line0,
    content=(
      #|[{ start: 3, end: 8, tag: Comment }]
    ),
  )
  let (line1, after_close) = toy.tokenize_line("cc */ dd", after_open)
  debug_inspect(
    line1,
    content=(
      #|[{ start: 0, end: 5, tag: Comment }]
    ),
  )
  assert_true(after_close == toy_code)
}

///|
test "tokenizer state equality detects convergence" {
  let toy : &@syntax.LineTokenizer = BlockCommentToy::{  }
  let (_, after_open) = toy.tokenize_line("aa /* bb", toy.initial_state())
  assert_true(after_open == toy_comment)
  let (_, after_close) = toy.tokenize_line("cc */ dd", after_open)
  assert_true(after_close == toy.initial_state())
  let (_, untouched) = toy.tokenize_line("plain line", toy.initial_state())
  assert_true(untouched == toy.initial_state())
}

///|
test "registry lookup resolves registered languages only" {
  let registry = @syntax.TokenizationRegistry::new()
  assert_true(registry.get("toy") is None)
  registry.register("toy", BlockCommentToy::{  }) |> ignore
  assert_true(registry.get("toy") is Some(_))
  assert_true(registry.get("unknown") is None)
}

///|
test "plain tokenizer counts UTF-16 code units and keeps pairs whole" {
  // 𐍈 (U+10348) is two UTF-16 code units; the identifier after it must
  // start at offset 4 and the pair must stay one token.
  let plain : &@syntax.LineTokenizer = @syntax.PlainTokenizer::new()
  let (tokens, _) = plain.tokenize_line("a \u{10348}b", plain.initial_state())
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  { start: 0, end: 1, tag: Identifier },
      #|  { start: 2, end: 4, tag: Punctuation },
      #|  { start: 4, end: 5, tag: Identifier },
      #|]
    ),
  )
}
