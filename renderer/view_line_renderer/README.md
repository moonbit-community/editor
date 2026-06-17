# renderer/view_line_renderer

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

- May depend on `renderer/core` and `syntax`.
- Must not depend on `renderer`, `renderer/browser`, `web`, server, transport,
  workspace, or host packages.
- Must not declare FFI.
- This package receives already-derived line content, token classes, and
  decorations. Document/provider conversion stays in `renderer/view_model`;
  viewport assembly stays in `renderer/view_layout`.

## Checks

- Package reference tests live in `monaco_render_line_reference_test.mbt`.
- Run `moon test --target js renderer/view_line_renderer` and
  `moon test --target native renderer/view_line_renderer` for this package.
