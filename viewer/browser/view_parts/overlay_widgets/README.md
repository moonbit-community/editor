# viewer/browser/view_parts/overlay_widgets

The overlay-widget view part, ported from Monaco's
`editor/browser/viewParts/overlayWidgets/overlayWidgets.ts`. The viewer has
no overlay-widget content yet (no minimap, no find widget), so this package
is just the DOM shell — its `ViewPart` render/`prepare_render` are no-ops.

## Responsibilities

- `OverlayWidgets`: the `.overlayWidgets` / `.overflowingOverlayWidgets`
  container pair and their dirty flag.

## Boundaries

- The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, the
  trait-owning package — see its README for the orphan-rule/cycle reasoning.
  That is also why the types here are `pub(all)`.
- A browser-tier package (`supported_targets = "js"`); may import
  `rabbita/dom`, nothing else.
