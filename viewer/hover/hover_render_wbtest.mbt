///|
fn hover_test_languages() -> @languages.Languages {
  let languages = @languages.Languages::new()
  languages.set_tokens_provider("moonbit", @syntax.PlainTokenizer::new())
  |> ignore
  languages
}

///|
test "hover markdown rows use the Monaco-shaped row wrappers" {
  let html = render_hover_shell(
    [
      MarkdownHover(
        range=Range(0, 1),
        contents=[Markdown("**bold**")],
        ordinal=100,
      ),
    ],
    "moonbit",
  )
  assert_true(
    html.contains(
      "<div class=\"hover-row\"><div class=\"hover-row-contents\"><div class=\"markdown-hover\"><div class=\"hover-contents\">",
    ),
  )
  assert_true(html.contains("<strong>bold</strong>"))
}

///|
test "hover markdown remains sanitized and plaintext remains escaped" {
  let sanitized = render_hover_shell(
    [
      MarkdownHover(
        range=Range(0, 1),
        contents=[
          Markdown(
            "<img src=x onerror=\"globalThis.__hoverUnsafe=1\"> [bad](javascript:alert(1))",
          ),
        ],
        ordinal=100,
      ),
    ],
    "moonbit",
  )
  assert_false(sanitized.contains("<img"))
  assert_false(sanitized.contains("javascript:"))
  let plain = render_hover_shell(
    [
      MarkdownHover(
        range=Range(0, 1),
        contents=[PlainText("<img src=x> plain")],
        ordinal=100,
      ),
    ],
    "moonbit",
  )
  assert_true(plain.contains("&lt;img src=x&gt; plain"))
}

///|
test "hover fenced code renders through the viewer token classes" {
  let languages = hover_test_languages()
  let moonbit = render_hover_shell(
    [
      MarkdownHover(
        range=Range(0, 1),
        contents=[Markdown("```moonbit\nfn rendered() -> Unit {}\n```")],
        ordinal=100,
      ),
    ],
    "moonbit",
    language_registry=languages,
  )
  assert_true(moonbit.contains("monaco-tokenized-source"))
  assert_true(moonbit.contains("tok-keyword"))
  assert_true(moonbit.contains("fn"))
  let mbt_alias = render_hover_shell(
    [
      MarkdownHover(
        range=Range(0, 1),
        contents=[Markdown("```mbt\nlet answer = 42\n```")],
        ordinal=100,
      ),
    ],
    "moonbit",
    language_registry=languages,
  )
  assert_true(mbt_alias.contains("monaco-tokenized-source"))
  assert_true(mbt_alias.contains("tok-keyword"))
}

///|
test "hover unknown fenced code keeps content as default plain text" {
  let languages = hover_test_languages()
  let html = render_hover_shell(
    [
      MarkdownHover(
        range=Range(0, 1),
        contents=[Markdown("```unknown\nnot really code\n```")],
        ordinal=100,
      ),
    ],
    "moonbit",
    language_registry=languages,
  )
  assert_true(html.contains("monaco-tokenized-source"))
  assert_true(html.contains("not"))
  assert_true(html.contains("really"))
  assert_true(html.contains("code"))
  assert_true(html.contains("tok-plain"))
  assert_false(html.contains("tok-identifier"))
}

///|
test "marker hover renders Monaco status and copy affordances" {
  let marker : @markers.Marker = {
    owner: "test",
    resource: "memory://test.mbt",
    range: Range(0, 1),
    severity: Warning,
    message: "Configured diagnostic",
    source: None,
    code: None,
  }
  let html = render_hover_shell(
    [MarkerHover(range=Range(0, 1), marker~)],
    "moonbit",
  )
  assert_true(html.contains("hover-row-with-copy"))
  assert_true(html.contains("hover-copy-button"))
  assert_true(html.contains("aria-label=\"Copy\""))
  assert_true(html.contains("data-hover-copy=\"Configured diagnostic\""))
  assert_true(html.contains("hover-row status-bar"))
  assert_true(html.contains("View Problem"))
}
