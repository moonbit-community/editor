# viewer/browser/view_parts/selections

The dynamic content-overlay view part: the DOM-shell base class from
`editor/browser/view/viewOverlays.ts` (`ContentViewOverlays`) merged with the
three Monaco overlays this viewer renders into `.view-overlays`:

- `viewParts/selections/selections.ts` (`SelectionsOverlay`): the selection
  highlight as DOM-measured rectangles with rounded/reverse corners, reading
  pixel rects through the `measure` closure
  (`ViewContext.measure_line_selection`, off the live line DOM written by
  `viewer/browser/view/selection_measure.mbt`).
- `viewParts/currentLineHighlight/currentLineHighlight.ts` (content half): the
  current-line highlight; the margin half lives in
  `viewer/browser/view_parts/margin`.
- `viewParts/decorations/decorations.ts` (`DecorationsOverlay`): whole-line
  and inline decoration rectangles, including the marker squiggles.

## Responsibilities

- `ContentViewOverlays`: the `.view-overlays` container, its dirty flag, and
  the prepared render input for one frame.
- The per-overlay render functions listed above, driven from the prepared
  input.

## Boundaries

- The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, the
  trait-owning package — see its README for the orphan-rule/cycle reasoning.
  That is also why the types here are `pub(all)`.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*` and `rabbita/dom`.
