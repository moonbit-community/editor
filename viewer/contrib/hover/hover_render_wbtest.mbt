///|
fn hover_test_languages() -> @languages.Languages {
  let languages = @languages.Languages::new()
  languages.set_tokens_provider("moonbit", @syntax.PlainTokenizer::new())
  |> ignore
  languages
}

///|
test "hover markdown rows use the Monaco-shaped row wrappers" {
  let html = render_hover_parts(
    [
      MarkdownHover(
        range=Range(1, 1, 1, 2),
        contents=[Markdown("**bold**")],
        ordinal=100,
      ),
    ],
    "moonbit",
  ).join("")
  assert_true(
    html.contains(
      "<div class=\"hover-row\"><div class=\"hover-row-contents\"><div class=\"markdown-hover\"><div class=\"hover-contents\">",
    ),
  )
  assert_true(html.contains("<strong>bold</strong>"))
}

///|
test "a markdown part with several contents renders one grouped hover row" {
  // Monaco `renderMarkdown` appends every content into a single `.hover-row`, so
  // a multi-content part is one row carrying one `.markdown-hover` per content —
  // not one row per content.
  let rows = render_hover_parts(
    [
      MarkdownHover(
        range=Range(1, 1, 1, 2),
        contents=[Markdown("**first**"), Markdown("**second**")],
        ordinal=100,
      ),
    ],
    "moonbit",
  )
  assert_eq(rows.length(), 1)
  let html = rows[0]
  // One row wrapper, two `.markdown-hover` blocks inside it.
  assert_eq(html.split("hover-row-contents").count() - 1, 1)
  assert_eq(html.split("markdown-hover").count() - 1, 2)
  assert_true(html.contains("<strong>first</strong>"))
  assert_true(html.contains("<strong>second</strong>"))
}

///|
test "hover markdown remains sanitized and plaintext remains escaped" {
  let sanitized = render_hover_parts(
    [
      MarkdownHover(
        range=Range(1, 1, 1, 2),
        contents=[
          Markdown(
            "<img src=x onerror=\"globalThis.__hoverUnsafe=1\"> [bad](javascript:alert(1))",
          ),
        ],
        ordinal=100,
      ),
    ],
    "moonbit",
  ).join("")
  assert_false(sanitized.contains("<img"))
  assert_false(sanitized.contains("javascript:"))
  let plain = render_hover_parts(
    [
      MarkdownHover(
        range=Range(1, 1, 1, 2),
        contents=[PlainText("<img src=x> plain")],
        ordinal=100,
      ),
    ],
    "moonbit",
  ).join("")
  assert_true(plain.contains("&lt;img src=x&gt; plain"))
}

///|
test "hover fenced code renders through the viewer token classes" {
  let languages = hover_test_languages()
  let moonbit = render_hover_parts(
    [
      MarkdownHover(
        range=Range(1, 1, 1, 2),
        contents=[Markdown("```moonbit\nfn rendered() -> Unit {}\n```")],
        ordinal=100,
      ),
    ],
    "moonbit",
    language_registry=languages,
  ).join("")
  assert_true(moonbit.contains("monaco-tokenized-source"))
  assert_true(moonbit.contains("mtk3")) // keyword color id
  assert_true(moonbit.contains("fn"))
  let mbt_alias = render_hover_parts(
    [
      MarkdownHover(
        range=Range(1, 1, 1, 2),
        contents=[Markdown("```mbt\nlet answer = 42\n```")],
        ordinal=100,
      ),
    ],
    "moonbit",
    language_registry=languages,
  ).join("")
  assert_true(mbt_alias.contains("monaco-tokenized-source"))
  assert_true(mbt_alias.contains("mtk3")) // keyword color id
}

///|
test "hover unknown fenced code keeps content as default plain text" {
  let languages = hover_test_languages()
  let html = render_hover_parts(
    [
      MarkdownHover(
        range=Range(1, 1, 1, 2),
        contents=[Markdown("```unknown\nnot really code\n```")],
        ordinal=100,
      ),
    ],
    "moonbit",
    language_registry=languages,
  ).join("")
  assert_true(html.contains("monaco-tokenized-source"))
  assert_true(html.contains("not"))
  assert_true(html.contains("really"))
  assert_true(html.contains("code"))
  // No tokenizer for `unknown`: the whole line is one default-metadata token
  // (`mtk1`), never the variable/identifier color (`mtk4`).
  assert_true(html.contains("class=\"mtk1\""))
  assert_false(html.contains("mtk4"))
}

///|
test "marker hover renders the row and status bar as separate rendered parts" {
  let marker = @markers.Marker::from_diagnostic(
    "test",
    @base_common.Uri::memory("test.mbt"),
    {
      range: Range(1, 1, 1, 2),
      severity: Warning,
      message: "Configured diagnostic",
      tags: None,
    },
  )
  // Monaco renders a marker hover as its own part plus a distinct `statusBar`
  // part, so the viewer emits two single-root rows.
  let rows = render_hover_parts(
    [MarkerHover(range=Range(1, 1, 1, 2), marker~)],
    "moonbit",
  )
  assert_eq(rows.length(), 2)
  let marker_row = rows[0]
  assert_true(marker_row.contains("hover-row-with-copy"))
  assert_true(marker_row.contains("hover-copy-button"))
  assert_true(marker_row.contains("aria-label=\"Copy\""))
  assert_true(marker_row.contains("data-hover-copy=\"Configured diagnostic\""))
  assert_false(marker_row.contains("status-bar"))
  let status_bar = rows[1]
  assert_true(status_bar.contains("hover-row status-bar"))
  assert_true(status_bar.contains("View Problem"))
  // Monaco's `HoverAction.render` (`hoverWidget.ts:52-92`) puts `tabindex` on
  // `.action-container`, never on the `<a>`, and wraps the label in a `<span>`.
  assert_true(
    status_bar.contains("<div class=\"action-container\" tabindex=\"0\">"),
  )
  assert_true(
    status_bar.contains(
      "<a class=\"action\" role=\"button\"><span>View Problem</span></a>",
    ),
  )
}

///|
test "marker + later-ordinal hover part: status bar renders last, not sandwiched" {
  let marker = @markers.Marker::from_diagnostic(
    "test",
    @base_common.Uri::memory("test.mbt"),
    {
      range: Range(1, 1, 1, 2),
      severity: Warning,
      message: "Unused variable 'c'",
      tags: None,
    },
  )
  // Sorted-by-ordinal input (MarkerHover=0, MarkdownHover=100), matching what
  // `HoverController` actually feeds `render_hover_parts`. Monaco's
  // `_renderParts` collects every participant's content row first and appends
  // the single shared status bar last — never interleaved.
  let rows = render_hover_parts(
    [
      MarkerHover(range=Range(1, 1, 1, 2), marker~),
      MarkdownHover(
        range=Range(1, 1, 1, 2),
        contents=[PlainText("Int")],
        ordinal=100,
      ),
    ],
    "moonbit",
  )
  assert_eq(rows.length(), 3)
  assert_true(rows[0].contains("Unused variable"))
  assert_false(rows[0].contains("status-bar"))
  assert_true(rows[1].contains("Int"))
  assert_false(rows[1].contains("status-bar"))
  assert_true(rows[2].contains("hover-row status-bar"))
}
