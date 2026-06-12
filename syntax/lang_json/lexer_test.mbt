///|
fn render_tokens(source : String) -> String {
  let doc = @core.DocumentSnapshot(source, language_id="json")
  let tokens = @syntax.tokenize_document(doc, @lang_json.JsonTokenizer::new())
  let lines : Array[String] = []
  for token in tokens {
    lines.push(
      "\{token.range.start}-\{token.range.end} \{token.tag.css_class()} \{token.text}",
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
      #|0-1 tok-delimiter {
      #|4-10 tok-attribute "name"
      #|10-11 tok-delimiter :
      #|12-21 tok-string "fixture"
      #|21-22 tok-delimiter ,
      #|25-31 tok-attribute "size"
      #|31-32 tok-delimiter :
      #|33-40 tok-number -12.5e2
      #|40-41 tok-delimiter ,
      #|44-48 tok-attribute "ok"
      #|48-49 tok-delimiter :
      #|50-54 tok-constant true
      #|54-55 tok-delimiter ,
      #|58-64 tok-attribute "tags"
      #|64-65 tok-delimiter :
      #|66-67 tok-delimiter [
      #|67-70 tok-string "a"
      #|70-71 tok-delimiter ,
      #|72-75 tok-string "b"
      #|75-76 tok-delimiter ]
      #|76-77 tok-delimiter ,
      #|80-86 tok-attribute "next"
      #|86-87 tok-delimiter :
      #|88-92 tok-constant null
      #|93-94 tok-delimiter }
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
      #|0-10 tok-comment // heading
      #|11-12 tok-delimiter {
      #|13-15 tok-comment /*
      #|15-21 tok-comment  multi
      #|22-27 tok-comment line 
      #|27-29 tok-comment */
      #|30-35 tok-attribute "key"
      #|35-36 tok-delimiter :
      #|37-38 tok-number 1
      #|39-40 tok-delimiter }
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
      #|0-1 tok-delimiter {
      #|2-5 tok-invalid bad
      #|5-6 tok-delimiter :
      #|7-8 tok-number 1
      #|9-10 tok-delimiter }
    ),
  )
}
