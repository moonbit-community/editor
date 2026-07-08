# viewer/browser/view_parts/decorations

Mirrors `vscode/src/vs/editor/browser/viewParts/decorations`
(`DecorationsOverlay`): whole-line and inline decoration rectangles,
including the marker squiggles, as per-line `div.cdr` HTML for
`viewer/browser/view`'s `ContentViewOverlays` rows (`view_overlays.mbt`,
Monaco's `viewOverlays.ts`) — the last registered content overlay
(current-line → selection → decorations, `view.ts:218-221`).

## Responsibilities

- The pure piece computation (`compute_decoration_overlay_pieces`):
  filter/sort, whole-line spans, same-class touching merge,
  `showIfCollapsed` widening, `shouldFillLineOnLineBreak` expansion.
- `DecorationsOverlay` (the `_renderResult` state) and
  `prepare_decorations_render`, serializing the pieces into Monaco's exact
  per-line strings.

## Boundaries

- The `DynamicViewOverlay` impl lives in `viewer/browser/view/view_part.mbt`,
  the trait-owning package — see its README for the orphan-rule/cycle
  reasoning. That is also why the types here are `pub(all)`.
- Pure per-line HTML: no DOM writes (the rows belong to `browser/view`).
