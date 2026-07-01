# viewer/browser/view_parts/overlay_widgets

The overlay-widget view part, ported from Monaco's
`editor/browser/viewParts/overlayWidgets/overlayWidgets.ts`. The viewer has
no overlay-widget content yet (no minimap, no find widget), so this package
is just the DOM shell — its `ViewPart` render/`prepare_render` are no-ops.

## Responsibilities

- `OverlayWidgets`: the `.overlayWidgets` / `.overflowingOverlayWidgets`
  container pair and their dirty flag. `pub(all)` for the same reason as
  `viewer/browser/view_parts/view_zones`'s types — its `ViewPart` trait impl
  lives in `viewer/browser/view/view_part.mbt`, not here.

## Boundaries

- Does not implement the `ViewPart` trait here — see this refactor's
  cycle-backlog note in `docs/exec-plans/viewer-directory-mirror.md` and
  `viewer/browser/view_parts/view_zones/README.md`.
- A browser-tier package (`supported_targets = "js"`); may import
  `rabbita/dom`, nothing else.
