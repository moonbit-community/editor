# viewer/browser/view_parts/current_line_highlight

Pure per-line HTML for Monaco's content-side
`CurrentLineHighlightOverlay`. `prepare_current_line_render` applies the
focus, selection, wrapping, and `RenderLineHighlight` predicates and returns
one overlay string per visible view line; `current_line_span` expands a wrapped
model line to its view-line span.

The overlay is first in `browser/view`'s content-overlay order, below selection
and decoration pieces. Shared predicates/classes live in
`viewer/common/view_layout`; the margin half lives in
`browser/view_parts/margin`. This package writes no DOM. Its
`DynamicViewOverlay` implementation lives in the trait-owning
`viewer/browser/view` package.
