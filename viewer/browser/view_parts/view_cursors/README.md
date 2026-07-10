# viewer/browser/view_parts/view_cursors

The readonly single-cursor subset of Monaco's `ViewCursors`/`ViewCursor`.
`ViewCursors` owns the `.cursors-layer` and one cursor node;
`prepare_cursor_render_data` and `compute_screen_aware_size` compute placement
and device-pixel-ratio-aware caret width. `get_last_render_data` exposes the
last cursor box to browser hit testing.

The painted caret is visible only while the editor is focused; selection state
changes the cursor-layer class. Multi-cursor rendering and Monaco's
blink-interval/style machinery are not implemented. The
`ViewPart` implementation lives in `viewer/browser/view`; this package is
JS-only and contains no root `Viewer::` methods.
