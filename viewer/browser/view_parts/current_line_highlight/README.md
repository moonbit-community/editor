# viewer/browser/view_parts/current_line_highlight

Mirrors `vscode/src/vs/editor/browser/viewParts/currentLineHighlight`
(content half of `CurrentLineHighlightOverlay`): the current-line highlight
as per-line HTML for `viewer/browser/view`'s `ContentViewOverlays` rows
(`view_overlays.mbt`, Monaco's `viewOverlays.ts`) — the first registered
content overlay, painted under the selection (`view.ts:218-219`). The margin
half lives in `viewer/browser/view_parts/margin`; the DOM-free predicates
and class strings live in `viewer/common/view_layout`.

## Responsibilities

- `CurrentLineHighlightOverlay` (the `_renderData` state) and
  `prepare_current_line_render`: the wrapped-line and exact passes.
- `current_line_span`: the view-line span the highlight covers.

## Boundaries

- The `DynamicViewOverlay` impl lives in `viewer/browser/view/view_part.mbt`,
  the trait-owning package — see its README for the orphan-rule/cycle
  reasoning. That is also why the types here are `pub(all)`.
- Pure per-line HTML: no DOM writes (the rows belong to `browser/view`).
