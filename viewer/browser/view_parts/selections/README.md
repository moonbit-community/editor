# viewer/browser/view_parts/selections

The selection-highlight view part, ported from Monaco's
`editor/browser/viewParts/selections/selections.ts` (`SelectionsOverlay`),
merged with the DOM-shell base class `editor/browser/view/viewOverlays.ts`
(`ContentViewOverlays`) since selection highlighting is the only dynamic
overlay this viewer registers.

**Phase-0 naming note** (`docs/exec-plans/viewer-directory-mirror.md`): the
file is named `selections.mbt`, not `view_overlays.mbt` — the original
directory-mirror mapping guessed `selection.mbt`/`selection_measure.mbt` were
this view part by filename pattern-matching; they are not (that's cursor
dispatch + clipboard copy glue, and `View::` DOM measurement, respectively —
both stay elsewhere). This package's actual source is `view_overlays.mbt`,
identified by its `.view-overlays` DOM class and `selections.css` styling.

## Responsibilities

- `ContentViewOverlays`: the `.view-overlays` container, its dirty flag, and
  the prepared render input for one frame. `pub(all)` for the same reason as
  `viewer/browser/view_parts/view_zones`'s types — its `ViewPart` trait impl
  lives in `viewer/browser/view/view_part.mbt`, not here.
- `render_selection_overlays`: paints the selection highlight as DOM-measured
  rectangles with rounded/reverse corners, reading pixel rects through the
  `measure` closure (`ViewContext.measure_line_selection`, off the live line
  DOM `viewer/browser/view/selection_measure.mbt` writes).

## Boundaries

- Does not implement the `ViewPart` trait here — see this refactor's
  cycle-backlog note in `docs/exec-plans/viewer-directory-mirror.md` and
  `viewer/browser/view_parts/view_zones/README.md`.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*` and `rabbita/dom`.
