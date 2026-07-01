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
  input for one frame. `pub(all)` for the same reason as `BrowserViewZone` —
  its `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, not here.
- `ViewZones::render_view_zones`: places each visible zone's node at its
  computed top/height.

## Boundaries

- Does **not** implement the `ViewPart` trait for `ViewZones` here. MoonBit's
  orphan rule only lets the *trait-owning* package's `impl Trait for
  ForeignType` participate in dot-call method resolution — writing the impl
  here would need the trait's package's `RenderingContext`/`ViewEvent` types
  imported back in, creating a cycle with `viewer/browser/view/` (which needs
  the concrete `ViewZones` type for its `View` struct and `ViewPartHandle`
  enum). So the impl block lives in `view_part.mbt`, called via explicit
  `ViewPart::method(value, ...)` syntax where the type is foreign to that impl
  site — see `docs/exec-plans/viewer-directory-mirror.md`'s cycle backlog.
- Does not hold any `Viewer::` method: MoonBit forbids defining a method on a
  foreign type, so all `Viewer`-facing glue (`ViewZoneChangeAccessor`,
  `Viewer::change_view_zones`, `Viewer::upsert_view_zone`, etc.) lives in the
  root `viewer` package's `view_zones_host.mbt` instead.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/view_layout` and `rabbita/dom`, nothing else.
