# viewer/browser/view_parts/selections

The pure overlay computation for Monaco's `SelectionsOverlay`.
`prepare_selections_render` converts the current view selection into per-line
HTML rectangles, using a supplied closure that reads client rects from live
ViewLines DOM. It merges the measured pieces and applies Monaco's rounded and
reverse-corner classes.

Selection is second in `browser/view`'s content-overlay order: current-line
highlight, selection, decorations. This package writes no DOM; the overlay rows,
measurement implementation, and `DynamicViewOverlay` implementation live in
`viewer/browser/view`. CSS for the shared rows and selection pieces remains
owner-adjacent here.
