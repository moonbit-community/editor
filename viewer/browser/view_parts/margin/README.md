# viewer/browser/view_parts/margin

Pure per-line HTML builders for three Monaco margin overlays, registered in
this order by `viewer/browser/view`:

1. `CurrentLineMarginHighlightOverlay` — focus/config-aware current-line
   margin, including wrapped view lines.
2. `LinesDecorationsOverlay` — deduplicated `.cldr` gutter-lane classes; the
   DOM-free filtering data comes from `viewer/common/view_model`.
3. `LineNumbersOverlay` — the readonly `lineNumbers: 'on'` subset; it renders
   a model line number only on that model line's first view line.

The glyph-margin overlay and relative/interval/custom line-number modes are not
implemented. This package writes no DOM; `browser/view` owns margin rows and
the closed overlay dispatch.
