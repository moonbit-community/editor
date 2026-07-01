# viewer/browser/view_parts/editor_scrollbar

The editor scrollbar view part, ported from Monaco's
`editor/browser/viewParts/editorScrollbar/editorScrollbar.ts`. A thin
view-part wrapper: the custom scrollbar geometry/DOM itself lives in
`viewer/ui/scrollbar` (Monaco's `base/browser/ui/scrollbar/`).

## Responsibilities

- `EditorScrollbar`: owns one `ScrollableElementDom` (the lines-content
  scrollable wrapper) and the dirty flag. `pub(all)` for the same reason as
  `viewer/browser/view_parts/view_zones`'s types — its `ViewPart` trait impl
  lives in `viewer/view_part.mbt`, not here.
- `wrapper` / `content` / `scrollable`: accessors the root `viewer` package's
  input-hookup glue (`hook_view_input`) and other view parts (`view.mbt`'s
  `View::build`) need.

## Boundaries

- Does not implement the `ViewPart` trait here — see this refactor's
  cycle-backlog note in `docs/exec-plans/viewer-directory-mirror.md` and
  `viewer/browser/view_parts/view_zones/README.md`.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/core`, `viewer/ui/scrollbar`, and `rabbita/dom`.
