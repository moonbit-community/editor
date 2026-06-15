///|
fn render_hover_shell(
  contents : Array[@language.HoverContent],
  language_id : String,
) -> String {
  let rows : Array[String] = []
  for content in contents {
    rows.push(
      "<div class=\"hover-row\"><div class=\"hover-row-contents\"><div class=\"markdown-hover\"><div class=\"hover-contents\">" +
      render_hover_content(content, language_id) +
      "</div></div></div></div>",
    )
  }
  rows.join("")
}

///|
fn render_hover_content(
  content : @language.HoverContent,
  language_id : String,
) -> String {
  match content {
    PlainText(text) => hover_plaintext_html(text)
    Markdown(markdown) => hover_markdown_html(markdown, language_id)
  }
}

///|
fn hover_plaintext_html(text : String) -> String {
  "<div class=\"hover-plaintext\">" + @renderer.escape_html(text) + "</div>"
}

///|
fn hover_markdown_html(markdown : String, language_id : String) -> String {
  let base = @cmark_html.renderer(safe=true)
  let code_override = @cmark_renderer.Renderer::new(block=fn(ctx, block) {
    match block {
      CodeBlock(code_block) => {
        ctx.string(render_hover_code_block(code_block.v, language_id))
        true
      }
      _ => false
    }
  })
  let doc = @cmark.Doc::from_string(markdown, strict=false)
  base.compose(code_override).doc_to_string(doc) catch {
    _ => hover_plaintext_html(markdown)
  }
}

///|
fn render_hover_code_block(
  code_block : @cmark.CodeBlock,
  active_language_id : String,
) -> String {
  let language_id = hover_code_language(code_block, active_language_id)
  let code = hover_code_text(code_block)
  let snapshot = @core.DocumentSnapshot(code, language_id~)
  let tokenizer : &@syntax.LineTokenizer = match
    tokenizer_registry.lookup(language_id) {
    Some(tokenizer) => tokenizer
    None => @syntax.PlainTokenizer::new()
  }
  let tokenized = @renderer.TokenizedDocument::build(
    snapshot,
    @syntax.tokenize_document(snapshot, tokenizer),
  )
  let source = @renderer.FrameSource(
    tokenized,
    @decorations.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  let frame = @renderer.build_frame(source, {
    start_line: 0,
    end_line: snapshot.line_count(),
  })
  let html = StringBuilder::new()
  html.write_string("<div class=\"monaco-tokenized-source\">")
  for index in 0..<frame.lines.length() {
    if index > 0 {
      html.write_string("<br/>")
    }
    html.write_string(@renderer.render_line_html(frame.lines[index], []))
  }
  html.write_string("</div>")
  html.to_string()
}

///|
fn hover_code_text(code_block : @cmark.CodeBlock) -> String {
  let lines : Array[String] = []
  for line in code_block.code {
    lines.push(line.v)
  }
  if lines.length() == 0 {
    ""
  } else {
    lines.join("\n") + "\n"
  }
}

///|
fn hover_code_language(
  code_block : @cmark.CodeBlock,
  active_language_id : String,
) -> String {
  let info = code_block.info_string.map(fn(info) { info.v })
  let language = match info.bind(@cmark.CodeBlock::language_of_info_string) {
    Some((language, _env)) => language
    None => active_language_id
  }
  normalize_hover_language_id(language)
}

///|
fn normalize_hover_language_id(language : String) -> String {
  match language {
    "mbt" => "moonbit"
    "js" => "javascript"
    "ts" => "typescript"
    _ => language
  }
}
