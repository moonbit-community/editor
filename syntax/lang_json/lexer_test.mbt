///|
fn render_tokens(source : String) -> String {
  let doc = @model.TextSnapshot(source)
  let tokens = @syntax.tokenize_document(doc, @lang_json.JsonTokenizer::new())
  let lines : Array[String] = []
  for token in tokens {
    lines.push(
      "\{token.range.start}-\{token.range.end_exclusive} \{token.tag} \{token.text}",
    )
  }
  lines.join("\n")
}

///|
test "object with property names values and literals" {
  let source =
    #|{
    #|  "name": "fixture",
    #|  "size": -12.5e2,
    #|  "ok": true,
    #|  "tags": ["a", "b"],
    #|  "next": null
    #|}
  inspect(
    render_tokens(source),
    content=(
      #|0-1 Delimiter {
      #|4-10 Attribute "name"
      #|10-11 Delimiter :
      #|12-21 String "fixture"
      #|21-22 Delimiter ,
      #|25-31 Attribute "size"
      #|31-32 Delimiter :
      #|33-40 Number -12.5e2
      #|40-41 Delimiter ,
      #|44-48 Attribute "ok"
      #|48-49 Delimiter :
      #|50-54 Constant true
      #|54-55 Delimiter ,
      #|58-64 Attribute "tags"
      #|64-65 Delimiter :
      #|66-67 Delimiter [
      #|67-70 String "a"
      #|70-71 Delimiter ,
      #|72-75 String "b"
      #|75-76 Delimiter ]
      #|76-77 Delimiter ,
      #|80-86 Attribute "next"
      #|86-87 Delimiter :
      #|88-92 Constant null
      #|93-94 Delimiter }
    ),
  )
}

///|
test "jsonc comments carry block state across lines" {
  let source =
    #|// heading
    #|{ /* multi
    #|line */ "key": 1 }
  inspect(
    render_tokens(source),
    content=(
      #|0-10 Comment // heading
      #|11-12 Delimiter {
      #|13-15 Comment /*
      #|15-21 Comment  multi
      #|22-27 Comment line 
      #|27-29 Comment */
      #|30-35 Attribute "key"
      #|35-36 Delimiter :
      #|37-38 Number 1
      #|39-40 Delimiter }
    ),
  )
}

///|
test "block comment state round-trips through TokenizerState" {
  let lexer : &@syntax.LineTokenizer = @lang_json.JsonTokenizer::new()
  let (_, open_state) = lexer.tokenize_line("{ /* open", lexer.initial_state())
  assert_true(open_state == TokenizerState("c"))
  let (_, closed_state) = lexer.tokenize_line("still */ }", open_state)
  assert_true(closed_state == lexer.initial_state())
}

///|
test "bare words are invalid outside strings" {
  inspect(
    render_tokens("{ bad: 1 }"),
    content=(
      #|0-1 Delimiter {
      #|2-5 Invalid bad
      #|5-6 Delimiter :
      #|7-8 Number 1
      #|9-10 Delimiter }
    ),
  )
}
