///|
fn render_tokens(source : String) -> String {
  let doc = @model.TextSnapshot(source, language_id="javascript")
  let tokens = @syntax.tokenize_document(
    doc,
    @lang_javascript.JavascriptTokenizer::new(),
  )
  let lines : Array[String] = []
  for token in tokens {
    lines.push(
      "\{token.range.start}-\{token.range.end_exclusive} \{token.tag.css_class()} \{token.text}",
    )
  }
  lines.join("\n")
}

///|
test "functions strings numbers and keywords" {
  let source =
    #|// bootstrap
    #|export async function start(name) {
    #|  const greeting = 'hello ' + name;
    #|  let total = 0xFF + 1_000n + .5e3;
    #|  return new Map([[greeting, total]]);
    #|}
  inspect(
    render_tokens(source),
    content=(
      #|0-12 tok-comment // bootstrap
      #|13-19 tok-keyword export
      #|20-25 tok-keyword async
      #|26-34 tok-keyword function
      #|35-40 tok-identifier start
      #|40-41 tok-delimiter (
      #|41-45 tok-identifier name
      #|45-46 tok-delimiter )
      #|47-48 tok-delimiter {
      #|51-56 tok-keyword const
      #|57-65 tok-identifier greeting
      #|66-67 tok-operator =
      #|68-76 tok-string 'hello '
      #|77-78 tok-operator +
      #|79-83 tok-identifier name
      #|83-84 tok-delimiter ;
      #|87-90 tok-keyword let
      #|91-96 tok-identifier total
      #|97-98 tok-operator =
      #|99-103 tok-number 0xFF
      #|104-105 tok-operator +
      #|106-112 tok-number 1_000n
      #|113-114 tok-operator +
      #|115-119 tok-number .5e3
      #|119-120 tok-delimiter ;
      #|123-129 tok-keyword return
      #|130-133 tok-keyword new
      #|134-137 tok-type Map
      #|137-140 tok-delimiter ([[
      #|140-148 tok-identifier greeting
      #|148-149 tok-delimiter ,
      #|150-155 tok-identifier total
      #|155-159 tok-delimiter ]]);
      #|160-161 tok-delimiter }
    ),
  )
}

///|
test "block and doc comments span lines" {
  let source =
    #|/** Doc
    #| * line
    #| */
    #|/* plain
    #|comment */ var x;
  inspect(
    render_tokens(source),
    content=(
      #|0-7 tok-comment-doc /** Doc
      #|8-15 tok-comment-doc  * line
      #|16-19 tok-comment-doc  */
      #|20-28 tok-comment /* plain
      #|29-39 tok-comment comment */
      #|40-43 tok-keyword var
      #|44-45 tok-identifier x
      #|45-46 tok-delimiter ;
    ),
  )
}

///|
test "template literals span lines with interpolation" {
  let source =
    #|const msg = `head ${user.name + 1}
    #|tail line`;
  inspect(
    render_tokens(source),
    content=(
      #|0-5 tok-keyword const
      #|6-9 tok-identifier msg
      #|10-11 tok-operator =
      #|12-18 tok-string `head 
      #|18-20 tok-string-escape ${
      #|20-24 tok-identifier user
      #|24-25 tok-delimiter .
      #|25-29 tok-identifier name
      #|30-31 tok-operator +
      #|32-33 tok-number 1
      #|33-34 tok-string-escape }
      #|35-45 tok-string tail line`
      #|45-46 tok-delimiter ;
    ),
  )
}

///|
test "template state carries across lines through TokenizerState" {
  let lexer : &@syntax.LineTokenizer = @lang_javascript.JavascriptTokenizer::new()
  let (_, in_template) = lexer.tokenize_line(
    "const t = `open",
    lexer.initial_state(),
  )
  assert_true(in_template == TokenizerState("nt"))
  let (_, closed) = lexer.tokenize_line("close`;", in_template)
  assert_true(closed == lexer.initial_state())
}
