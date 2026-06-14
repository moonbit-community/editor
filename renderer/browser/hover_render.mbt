///|
fn render_hover_shell(contents : Array[@language.HoverContent]) -> String {
  let rows : Array[String] = []
  for content in contents {
    rows.push(
      "<div class=\"hover-row markdown-hover\"><div class=\"hover-contents\">" +
      render_hover_content(content) +
      "</div></div>",
    )
  }
  "<div class=\"moonbit-viewer-hover-content\">" + rows.join("") + "</div>"
}

///|
fn render_hover_content(content : @language.HoverContent) -> String {
  match content {
    PlainText(text) => hover_plaintext_html(text)
    Markdown(markdown) => hover_markdown_html(markdown)
  }
}

///|
fn hover_plaintext_html(text : String) -> String {
  "<div class=\"hover-plaintext\">" + @renderer.escape_html(text) + "</div>"
}

///|
fn hover_markdown_html(markdown : String) -> String {
  @cmark_html.render(safe=true, strict=false, markdown) catch {
    _ => hover_plaintext_html(markdown)
  }
}
