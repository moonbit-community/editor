# viewer/browser/view_parts/selections

Mirrors `vscode/src/vs/editor/browser/viewParts/selections`
(`SelectionsOverlay`) plus the DOM-shell base class from
`editor/browser/view/viewOverlays.ts` (`ContentViewOverlays`): the selection
highlight as DOM-measured rectangles with rounded/reverse corners, reading
pixel rects through the `measure` closure
(`ViewContext.measure_line_selection`, off the live line DOM written by
`viewer/browser/view/selection_measure.mbt`).

The sibling dynamic overlays render into this package's `.view-overlays`
container from their own Monaco-mirroring packages:
`view_parts/current_line_highlight` (content half) and
`view_parts/decorations` (whole-line/inline decoration rectangles, marker
squiggles). The shared `ViewPart` shell in
`viewer/browser/view/view_part.mbt` sequences them in Monaco's dynamic-
overlay registration order (current-line → selection → decorations,
`view.ts:218-221`).

## Responsibilities

- `ContentViewOverlays`: the `.view-overlays` container, its dirty flag, and
  the prepared render input for one frame.
- `SelectionsOverlay`'s piece computation and DOM writes.

## Boundaries

- The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, the
  trait-owning package — see its README for the orphan-rule/cycle reasoning.
  That is also why the types here are `pub(all)`.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*` and `rabbita/dom`.
