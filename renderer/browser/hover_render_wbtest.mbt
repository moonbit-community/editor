///|
test "hover markdown rows use the Monaco-shaped row wrappers" {
  let html = render_hover_shell([Markdown("**bold**")], "moonbit")
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
      Markdown(
        "<img src=x onerror=\"globalThis.__hoverUnsafe=1\"> [bad](javascript:alert(1))",
      ),
    ],
    "moonbit",
  )
  assert_false(sanitized.contains("<img"))
  assert_false(sanitized.contains("javascript:"))
  let plain = render_hover_shell([PlainText("<img src=x> plain")], "moonbit")
  assert_true(plain.contains("&lt;img src=x&gt; plain"))
}

///|
test "hover fenced code renders through the viewer token classes" {
  let moonbit = render_hover_shell(
    [Markdown("```moonbit\nfn rendered() -> Unit {}\n```")],
    "moonbit",
  )
  assert_true(moonbit.contains("monaco-tokenized-source"))
  assert_true(moonbit.contains("tok-keyword"))
  assert_true(moonbit.contains("fn"))
  let mbt_alias = render_hover_shell(
    [Markdown("```mbt\nlet answer = 42\n```")],
    "moonbit",
  )
  assert_true(mbt_alias.contains("monaco-tokenized-source"))
  assert_true(mbt_alias.contains("tok-keyword"))
}

///|
test "hover unknown fenced code keeps content with the plain fallback" {
  let html = render_hover_shell(
    [Markdown("```unknown\nnot really code\n```")],
    "moonbit",
  )
  assert_true(html.contains("monaco-tokenized-source"))
  assert_true(html.contains("not"))
  assert_true(html.contains("really"))
  assert_true(html.contains("code"))
}
