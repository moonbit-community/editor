# viewer/browser/view_parts/decorations

The pure HTML half of Monaco's `DecorationsOverlay`. It turns viewport model
decorations into per-line `<div class="cdr ...">` pieces after the
current-line and selection overlays.

`compute_decoration_overlay_pieces` filters/sorts decorations, emits whole-line
pieces, merges touching same-class ranges, handles `showIfCollapsed`, and
expands `shouldFillLineOnLineBreak`. Inline geometry comes from the supplied
live-line measurement closure. `prepare_decorations_render` serializes those
pieces into one string per visible line.

This package writes no DOM. `browser/view` owns the overlay rows, closed overlay
dispatch, and rendering-context adapter; exact helper types are in
`pkg.generated.mbti`.
