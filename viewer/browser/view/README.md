# viewer/browser/view

The `View` role, ported from Monaco's `editor/browser/view/`: the root editor
DOM node, the coordinated render loop, and the typed view-event dispatch that
drives every `browser/view_parts/*` package.

## Responsibilities

- `View` (`view.mbt`): the root `<section>`, its overflow guard/probe/message
  nodes, one instance of each of the 8 view parts, and `View::render`'s
  Monaco-shaped coordinated render (dispatch view events → collect dirty
  parts → render lines first → prepare/write the rest). `pub(all)`: `Viewer`
  (root `viewer` package) holds `view : View?` and reads several fields
  directly from `view_host.mbt`, `input.mbt`, `hit_test_dom.mbt`,
  `controller_host.mbt`, and `reveal.mbt` — the foreign-method rule keeps
  those `Viewer::` methods out of this package.
- `ViewContext` (`view_context.mbt`): the capability struct `Viewer::build_view_context`
  (root `viewer` package's `view_host.mbt`) builds and `View::render` reads,
  the local analog of `View` reading its owning `CodeEditorWidget`.
- `ViewPart` (`view_part.mbt`): the private `ViewEventHandler`/render-lifecycle
  trait, plus every `impl ViewPart for X with ...` block for the 8 concrete
  view-part types. Kept here rather than in each view-part's own package —
  see "Boundaries" below.
- `RenderingContext`/`RestrictedRenderingContext` (`rendering_context.mbt`):
  read/write render contexts built once per frame and handed to every part.
- `ViewEvent` (`view_events.mbt`): the typed view-event set, sourced by
  diffing one frame's render snapshot against the previous.
- `selection_measure.mbt`: `View::measure_line_selection` and its
  `offset_for_column`/`line_width`/`is_line_rendered` callers — DOM
  caret-range measurement off the live line DOM, Monaco's
  `RangeUtil.readHorizontalRanges` role.

## Boundaries

- Implements the `ViewPart` trait for all 8 concrete view-part types
  (`ViewZones`, `ViewLines`, `MarginViewOverlays`, `OverlayWidgets`,
  `EditorScrollbar`, `ContentViewOverlays`, `ContentWidgets`, `ViewCursors`)
  here, not in each part's own package. MoonBit's orphan rule only lets the
  *trait-owning* package implement a trait for a foreign type, and this
  package needs every concrete type anyway (`View`'s fields, the
  `ViewPartHandle` enum) — see `docs/exec-plans/viewer-directory-mirror.md`'s
  cycle backlog. This makes the dependency one-directional
  (`browser/view` → `browser/view_parts/*`); no view-part package imports
  this one back.
- Holds no `Viewer::` method: MoonBit forbids defining a method on a foreign
  type, so all `Viewer`-facing glue (`build_view_context`, `flush_render`,
  `hook_view_input`, `measure`, the hit-test/reveal/controller hosts) lives
  in the root `viewer` package instead.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*`, every `viewer/browser/view_parts/*`,
  `viewer/contrib/hover`, `viewer/ui/scrollbar`, and `rabbita/{dom,js}`.
