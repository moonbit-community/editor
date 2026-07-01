///|
/// Renders the content-hover widget's parts, one HTML string per rendered hover
/// part (Monaco `RenderedContentHoverParts._renderParts`: each participant's
/// parts become their own `hoverElement`). Each returned string is a single root
/// element so the viewer core can give every part its own focusable node. A
/// markdown part with several contents is one `.hover-row` carrying one
/// `.markdown-hover` block per content (Monaco `renderMarkdown`), and a marker
/// part contributes its `.hover-row` plus a separate status-bar row (Monaco's
/// distinct `statusBar` rendered part). Called by the viewer core's
/// content-widget render pass.
pub fn render_hover_parts(
  parts : Array[HoverPart],
  language_id : String,
  language_registry? : @languages.Languages = @languages.default_languages(),
) -> Array[String] {
  let rows : Array[String] = []
  for part in parts {
    match part {
      MarkdownHover(contents~, ..) =>
        rows.push(
          render_markdown_hover_row(contents, language_id, language_registry),
        )
      MarkerHover(marker~, ..) => {
        rows.push(marker_hover_row(marker.message))
        rows.push(marker_status_bar_row())
      }
      LoadingHover(message~, ..) =>
        rows.push(standard_hover_row(hover_plaintext_html(message)))
    }
  }
  rows
}

///|
/// One markdown hover part → one `.hover-row` whose `.hover-row-contents` holds a
/// `.markdown-hover` block per content. Mirrors Monaco `renderMarkdown`, which
/// appends every content's element into the single row rather than emitting one
/// row per content.
fn render_markdown_hover_row(
  contents : Array[@language.HoverContent],
  language_id : String,
  language_registry : @languages.Languages,
) -> String {
  let inner = StringBuilder::new()
  for content in contents {
    inner.write_string(
      "<div class=\"markdown-hover\"><div class=\"hover-contents\">",
    )
    inner.write_string(
      render_markdown_hover_content(content, language_id, language_registry),
    )
    inner.write_string("</div></div>")
  }
  "<div class=\"hover-row\"><div class=\"hover-row-contents\">" +
  inner.to_string() +
  "</div></div>"
}

///|
fn render_markdown_hover_content(
  content : @language.HoverContent,
  language_id : String,
  language_registry : @languages.Languages,
) -> String {
  match content {
    PlainText(text) => hover_plaintext_html(text)
    Markdown(markdown) =>
      hover_markdown_html(markdown, language_id, language_registry)
  }
}

///|
fn standard_hover_row(content_html : String) -> String {
  "<div class=\"hover-row\"><div class=\"hover-row-contents\"><div class=\"markdown-hover\"><div class=\"hover-contents\">" +
  content_html +
  "</div></div></div></div>"
}

///|
fn hover_plaintext_html(text : String) -> String {
  "<div class=\"hover-plaintext\">" +
  @viewer_common.escape_html(text) +
  "</div>"
}

///|
/// The marker hover part's own `.hover-row` (Monaco `MarkerHover` rendered part),
/// carrying the diagnostic message and the copy affordance.
fn marker_hover_row(text : String) -> String {
  let escaped = @viewer_common.escape_html(text)
  "<div class=\"hover-row hover-row-with-copy\" tabindex=\"0\"><div class=\"marker hover-contents\">" +
  escaped +
  "</div><button type=\"button\" class=\"hover-copy-button\" aria-label=\"Copy\" data-hover-copy=\"" +
  escaped +
  "\"><span class=\"codicon codicon-copy\" aria-hidden=\"true\"></span></button></div>"
}

///|
/// The status-bar row Monaco renders as its own `statusBar` part below a marker
/// hover (`RenderedStatusBar` / `_renderStatusBar`). The real action-backed
/// `EditorHoverStatusBar` lands in Phase 5; for now this keeps the static
/// "View Problem" affordance as a distinct rendered part.
fn marker_status_bar_row() -> String {
  "<div class=\"hover-row status-bar\" tabindex=\"0\"><div class=\"actions\"><div class=\"action-container\"><a class=\"action\" role=\"button\" tabindex=\"0\">View Problem</a></div></div></div>"
}

///|
fn hover_markdown_html(
  markdown : String,
  language_id : String,
  language_registry : @languages.Languages,
) -> String {
  let base = @cmark_html.renderer(safe=true)
  let code_override = @cmark_renderer.Renderer::new(block=fn(ctx, block) {
    match block {
      CodeBlock(code_block) => {
        ctx.string(
          render_hover_code_block(code_block.v, language_id, language_registry),
        )
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
  language_registry : @languages.Languages,
) -> String {
  let language_id = hover_code_language(code_block, active_language_id)
  let code = hover_code_text(code_block)
  let snapshot = @model.TextSnapshot(code, language_id~)
  let tokens : Array[@syntax.Token] = match
    language_registry.lookup_tokens_provider(language_id) {
    Some(tokenizer) => @syntax.tokenize_document(snapshot, tokenizer)
    None => []
  }
  let tokenized = @view_model.TokenizedDocument::build(snapshot, tokens)
  let source = @view_model.FrameSource(
    tokenized,
    @model.DecorationSet::empty(),
    @language.ProviderResult::empty(),
  )
  let frame = @view_model.build_frame(source, {
    start_line: 1,
    end_line: snapshot.line_count() + 1,
  })
  let html = StringBuilder::new()
  html.write_string("<div class=\"monaco-tokenized-source\">")
  for index in 0..<frame.lines.length() {
    if index > 0 {
      html.write_string("<br/>")
    }
    html.write_string(
      @viewer_common.render_source_line_html(frame.lines[index]),
    )
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
