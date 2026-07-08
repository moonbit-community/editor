# viewer/browser/view_parts/margin

The margin dynamic overlays, ported from Monaco's
`viewParts/lineNumbers/lineNumbers.ts` (`LineNumbersOverlay`),
`viewParts/linesDecorations/linesDecorations.ts` (`LinesDecorationsOverlay`),
and the margin half of `viewParts/currentLineHighlight/currentLineHighlight.ts`
(`CurrentLineMarginHighlightOverlay`) — each a pure per-line HTML builder for
`viewer/browser/view`'s `MarginViewOverlays` rows (`view_overlays.mbt`,
Monaco's `viewOverlays.ts`), registered in Monaco's margin order
(`view.ts:225-231`; the glyph-margin overlay between them is unported).

## Responsibilities

- `CurrentLineMarginHighlightOverlay` + `prepare_current_line_margin_render`.
- `LinesDecorationsOverlay` + `prepare_lines_decorations_render` (the `.cldr`
  lane pieces; the DOM-free filtering/dedup lives in
  `viewer/common/view_model/margin_decorations.mbt`).
- `LineNumbersOverlay` + `prepare_line_numbers_render`: the readonly
  `lineNumbers: 'on'` subset — the model line number on a model line's first
  view line, nothing on soft-wrap continuations.

## Boundaries

- The `DynamicViewOverlay` impls live in `viewer/browser/view/view_part.mbt`,
  the trait-owning package — see its README for the orphan-rule/cycle
  reasoning. That is also why the types here are `pub(all)`.
- Pure per-line HTML: no DOM writes (the `.margin` container and its rows
  belong to `browser/view`). Holds no `Viewer::` method.
