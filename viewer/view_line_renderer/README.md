# viewer/view_line_renderer

Pure common-layer line rendering, the MoonBit-owned package boundary for
Monaco's `viewLineRenderer`, `lineDecorations`, `inlineDecorations`, and
character-mapping roles.

## Responsibilities

- Own render-line data shapes: `LinePart`, `InlineDecoration`,
  `LineDecoration`, `ViewLineRenderingData`, and `RenderLineInput`.
- Own DOM-free line HTML generation through `render_view_line` and
  `render_view_line2`.
- Own character mapping data returned with rendered HTML:
  `CharacterMapping`, `DomPosition`, `RenderLineOutput`, and
  `RenderLineOutput2`.
- Preserve Monaco reference behavior for line decoration normalization and the
  readonly subset of view-line rendering.

## Boundaries

- May depend on `base/common` and `syntax`.
- Must not depend on `viewer/common`, `viewer`, `web`, server, transport,
  workspace, or host packages.
- Must not declare FFI.
- This package receives already-derived line content, token classes, and
  decorations. Document/provider conversion stays in `viewer/view_model`;
  viewport assembly stays in `viewer/view_layout`.

## Checks

- Package reference tests live in `monaco_render_line_reference_test.mbt`.
- Run `moon test --target js viewer/view_line_renderer` and
  `moon test --target native viewer/view_line_renderer` for this package.

## Fidelity to Monaco's `viewLineRenderer`

`render_view_line` / `render_view_line2` are a faithful 1:1 port of Monaco's
`renderViewLine` / `_renderLine` (`resolveRenderLineInput`,
`transformAndRemoveOverflowing`, `_applyRenderWhitespace`,
`_applyInlineDecorations`, `splitLargeTokens`, `splitLeadingWhitespaceFromRTL`,
`extractControlCharacters`). The conformance port
(`monaco_render_line_reference_test.mbt`) asserts Monaco's **exact** output for
all 72 upstream `viewLineRenderer.test.ts` cases — inner HTML byte-for-byte
against `__snapshots__/*.0.html`, and the inflated `CharacterMapping` against
`*.1.snap` — covering spaces (`U+00A0`), tab expansion, rendered/selection
whitespace (width-bearing `mtkz`/`mtkw` spans), RTL `unicode-bidi:isolate`
spans, control/bad-character substitution, faux indent, large-token splitting
(incl. surrogate-safe boundaries), and overflow.

### Sole deviation

**Line wrapper.** Monaco wraps a rendered line in `<span>…</span>`; this package
wraps it in `<span class="view-line-content">…</span>` because the browser layer
locates the content node via `querySelector(".view-line-content")` and styles it
by that class. The inner content (everything between the wrapper tags) and the
`CharacterMapping` are identical to Monaco.

Note: like Monaco, `"` is left literal in text content (only attribute values
are quote-escaped, via `viewer/common`'s `escape_html`), and spaces render as
`U+00A0` — both rely on the `.view-line` node being `white-space: pre`.
