///|
/// Golden token-stream rendering: one `start-end css-class text` line per
/// token, so the snapshots read as the highlighted document.
fn render_tokens(source : String) -> String {
  let doc = @model.TextSnapshot(source, language_id="moonbit")
  let tokens = @syntax.tokenize_document(
    doc,
    @lang_moonbit.MoonbitTokenizer::new(),
  )
  let lines : Array[String] = []
  for token in tokens {
    lines.push(
      "\{token.range.start}-\{token.range.end} \{token.tag.css_class()} \{token.text}",
    )
  }
  lines.join("\n")
}

///|
test "fixture errors.mbt token stream" {
  // tests/fixtures/workspace/src/errors.mbt
  let source =
    #|///|
    #|suberror FixtureError String
    #|
    #|///|
    #|fn risky_step(flag : Bool) -> Int raise FixtureError {
    #|  if flag {
    #|    raise FixtureError("fixture failure")
    #|  }
    #|  1
    #|}
  inspect(
    render_tokens(source),
    content=(
      #|0-4 tok-comment-doc ///|
      #|5-13 tok-keyword suberror
      #|14-26 tok-type FixtureError
      #|27-33 tok-type String
      #|35-39 tok-comment-doc ///|
      #|40-42 tok-keyword fn
      #|43-53 tok-identifier risky_step
      #|53-54 tok-delimiter (
      #|54-58 tok-identifier flag
      #|59-60 tok-delimiter :
      #|61-65 tok-type Bool
      #|65-66 tok-delimiter )
      #|67-69 tok-operator ->
      #|70-73 tok-type Int
      #|74-79 tok-keyword raise
      #|80-92 tok-type FixtureError
      #|93-94 tok-delimiter {
      #|97-99 tok-keyword if
      #|100-104 tok-identifier flag
      #|105-106 tok-delimiter {
      #|111-116 tok-keyword raise
      #|117-129 tok-type FixtureError
      #|129-130 tok-delimiter (
      #|130-147 tok-string "fixture failure"
      #|147-148 tok-delimiter )
      #|151-152 tok-delimiter }
      #|155-156 tok-number 1
      #|157-158 tok-delimiter }
    ),
  )
}

///|
test "string interpolation and escapes" {
  let source =
    #|let s = "count \{n + 1} done\n"
  inspect(
    render_tokens(source),
    content=(
      #|0-3 tok-keyword let
      #|4-5 tok-identifier s
      #|6-7 tok-operator =
      #|8-15 tok-string "count 
      #|15-17 tok-string-escape \{
      #|17-18 tok-identifier n
      #|19-20 tok-operator +
      #|21-22 tok-number 1
      #|22-23 tok-string-escape }
      #|23-28 tok-string  done
      #|28-30 tok-string-escape \n
      #|30-31 tok-string "
    ),
  )
}

///|
test "multiline string lines" {
  let source =
    #|let text =
    #|  #|plain "line"
    #|  $|sum \{1 + 2} tail
  inspect(
    render_tokens(source),
    content=(
      #|0-3 tok-keyword let
      #|4-8 tok-identifier text
      #|9-10 tok-operator =
      #|13-27 tok-string #|plain "line"
      #|30-36 tok-string $|sum 
      #|36-38 tok-string-escape \{
      #|38-39 tok-number 1
      #|40-41 tok-operator +
      #|42-43 tok-number 2
      #|43-44 tok-string-escape }
      #|44-49 tok-string  tail
    ),
  )
}

///|
test "doc comments attributes numbers and package refs" {
  let source =
    #|///| Doc heading
    #|#external("js", "x")
    #|// plain comment
    #|let mask = 0xFF_a0 + 0b1010 + 3.14e-2 + 42U
    #|let v = @core.Range(1, 2)
  inspect(
    render_tokens(source),
    content=(
      #|0-16 tok-comment-doc ///| Doc heading
      #|17-26 tok-attribute #external
      #|26-27 tok-delimiter (
      #|27-31 tok-string "js"
      #|31-32 tok-delimiter ,
      #|33-36 tok-string "x"
      #|36-37 tok-delimiter )
      #|38-54 tok-comment // plain comment
      #|55-58 tok-keyword let
      #|59-63 tok-identifier mask
      #|64-65 tok-operator =
      #|66-73 tok-number 0xFF_a0
      #|74-75 tok-operator +
      #|76-82 tok-number 0b1010
      #|83-84 tok-operator +
      #|85-92 tok-number 3.14e-2
      #|93-94 tok-operator +
      #|95-98 tok-number 42U
      #|99-102 tok-keyword let
      #|103-104 tok-identifier v
      #|105-106 tok-operator =
      #|107-112 tok-type @core
      #|112-113 tok-delimiter .
      #|113-118 tok-type Range
      #|118-119 tok-delimiter (
      #|119-120 tok-number 1
      #|120-121 tok-delimiter ,
      #|122-123 tok-number 2
      #|123-124 tok-delimiter )
    ),
  )
}

///|
test "state carries through tokenize_line but resets at line end" {
  let lexer : &@syntax.LineTokenizer = @lang_moonbit.MoonbitTokenizer::new()
  // Unterminated string: the line still tokenizes and the carried state
  // returns to normal because MoonBit strings never span lines.
  let (_, after_unterminated) = lexer.tokenize_line(
    "let s = \"open",
    lexer.initial_state(),
  )
  assert_true(after_unterminated == lexer.initial_state())
}
