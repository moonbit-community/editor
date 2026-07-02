# viewer/browser/view_parts/view_cursors

The cursor view part, ported from Monaco's
`editor/browser/viewParts/viewCursors/viewCursors.ts` + `viewCursor.ts`,
reduced to the readonly viewer's single primary cursor (no multi-cursor, no
blink-interval styles beyond the focus-driven visibility class).

## Responsibilities

- `ViewCursors`: the `.cursors-layer` container and the one cursor node, its
  dirty flag, and the prepared render input for one frame
  (`ViewCursorsPrepared`).
- `prepare_cursor_render_data` / `compute_screen_aware_size`: the DOM-free
  cursor placement math, including Monaco's device-pixel-ratio-aware caret
  width.

## Boundaries

- The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, the
  trait-owning package — see its README for the orphan-rule/cycle reasoning.
  That is also why the types here are `pub(all)`.
- A browser-tier package (`supported_targets = "js"`); may import
  `rabbita/dom`, nothing else.
