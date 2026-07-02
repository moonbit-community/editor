# viewer/browser/view_parts/view_zones

The view-zones DOM view part, ported from Monaco's
`editor/browser/viewParts/viewZones/viewZones.ts`. Owns the `.view-zones`
container and the DOM nodes of each browser-facing view zone.

## Responsibilities

- `BrowserViewZone`: one browser view zone (id, anchor line, height, node).
  `pub(all)` — `Viewer.view_zones : Array[BrowserViewZone]` and the
  `Viewer::` glue in the root `viewer` package's `view_zones_host.mbt`
  construct/read it directly.
- `ViewZones`: the DOM container, its dirty flag, and the prepared render
  input for one frame.
- `ViewZones::render_view_zones`: places each visible zone's node at its
  computed top/height.

## Boundaries

- The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, the
  trait-owning package — see its README for the orphan-rule/cycle reasoning.
  That is also why the types here are `pub(all)`.
- Holds no `Viewer::` method (MoonBit forbids methods on foreign types); the
  `Viewer`-facing glue (`ViewZoneChangeAccessor`, `Viewer::change_view_zones`,
  etc.) lives in the root `viewer` package's `view_zones_host.mbt`.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/view_layout` and `rabbita/dom`, nothing else.
