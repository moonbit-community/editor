# viewer/browser/view_parts/editor_scrollbar

The editor scrollbar view part, ported from Monaco's
`editor/browser/viewParts/editorScrollbar/editorScrollbar.ts`. A thin
view-part wrapper: the custom scrollbar geometry/DOM itself lives in
`viewer/ui/scrollbar` (Monaco's `base/browser/ui/scrollbar/`).

## Responsibilities

- `EditorScrollbar`: owns one `ScrollableElementDom` (the lines-content
  scrollable wrapper) and the dirty flag.
- `wrapper` / `content` / `scrollable`: accessors the root `viewer` package's
  input-hookup glue (`hook_view_input`) and `View::build` need.

## Boundaries

- The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, the
  trait-owning package — see its README for the orphan-rule/cycle reasoning.
  That is also why the types here are `pub(all)`.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/core`, `viewer/ui/scrollbar`, and `rabbita/dom`.
