# viewer/browser/view_parts/selections

Mirrors `vscode/src/vs/editor/browser/viewParts/selections`
(`SelectionsOverlay`): the selection highlight as per-line HTML pieces with
rounded/reverse corners, measured through the `measure` closure
(`ViewContext.measure_line_selection`, off the live line DOM written by
`viewer/browser/view/selection_measure.mbt`).

The overlay renders into `viewer/browser/view`'s `ContentViewOverlays` rows
(`view_overlays.mbt`, Monaco's `viewOverlays.ts`) as the second registered
dynamic overlay — after the current-line highlight, before decorations
(`view.ts:218-221`).

## Responsibilities

- `SelectionsOverlay` (the `_renderResult` state) and
  `prepare_selections_render`: the per-line range collection
  (`linesVisibleRangesForRange`), the corner-style enrichment
  (`_enrichVisibleRangesWithStyle`), and the two-bucket per-line HTML
  (`_actualRenderOneSelection` — inner corners before selection rects).

## Boundaries

- The `DynamicViewOverlay` impl lives in `viewer/browser/view/view_part.mbt`,
  the trait-owning package — see its README for the orphan-rule/cycle
  reasoning. That is also why the types here are `pub(all)`.
- Pure per-line HTML: no DOM writes (the rows belong to `browser/view`).
- Also carries `view_overlays.css` (the `.view-overlays` container + shared
  row rules) and `selections.css`.
