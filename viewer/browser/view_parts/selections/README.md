# viewer/browser/view_parts/selections

The pure overlay computation for Monaco's `SelectionsOverlay`.
Production uses `prepare_selections_render_from_visible_ranges`: browser/view
queries `RenderingContext.linesVisibleRangesForRange(selection, true)` and
passes its ordered, rounded per-line rectangles here for Monaco's rounded and
reverse-corner styling. `prepare_selections_render` remains the pure
measurement-driven compatibility oracle used by focused overlay tests.

Selection is second in `browser/view`'s content-overlay order: current-line
highlight, selection, decorations. This package writes no DOM; the overlay rows,
measurement implementation, and `DynamicViewOverlay` implementation live in
`viewer/browser/view`. CSS for the shared rows and selection pieces remains
owner-adjacent here.
