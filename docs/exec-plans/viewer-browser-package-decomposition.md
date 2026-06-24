# Viewer Browser Package Decomposition Plan

## Goal

The flat `viewer/` root package is too large: 38 `.mbt` files, ~7,400 non-test
lines, all sharing one MoonBit package namespace. It is meant to be the local
analog of Monaco's `vs/editor/browser/`, but Monaco does not keep that as a flat
directory — it sub-structures it heavily and pushes several features out of
`editor/browser` entirely. This plan records the diagnosis and a phased path to
re-align the browser layer with Monaco's module seams without forcing the
genuinely-cyclic core apart prematurely.

This is a structural plan. It changes package boundaries and imports, not
runtime behavior.

## Implementation status (2026-06-24)

Landed and validated (`just check` green, wbtests pass, moves are
logic-identical, and the full browser suite — 41 tests across
conformance/component/smoke, incl. mouse-selection, selection geometry,
scrollbar drag/track, wheel, and hover scrollbar — passes):

- **`viewer/folding`** — pure folded-range set operations + fallback
  folding-range computation moved out; `Viewer::toggle_fold` /
  `set_folding_ranges` stay in core as the browser-side controls.
- **`viewer/markers`** — `Marker` / `MarkerService` /
  `MarkerDecorationsService` moved out (with their wbtests); core consumers and
  the marker hover participant import `@markers`.
- **`viewer/ui/scrollbar`** — the scrollable-element widget (DOM + CSS) moved
  out. Because it owns `@rdom`, `scripts/check-architecture.mbtx` gained a
  *browser-UI subpackage* category (`is_viewer_browser_subpackage`, matching
  `viewer/ui/*` and `viewer/controller/*`): such packages may import
  `rabbita/dom` and declare JS FFI, but not the shell, the rabbita
  TEA/vdom/command layers, or the `viewer` core (the edge stays
  `viewer -> viewer/ui/scrollbar`).

Re-ordering note: the plan listed hover first as a "misfiled leaf", but hover
turned out to be the *most* coupled phase, so the clean DOM-free leaves
(folding, markers) and the genuine UI leaf (scrollbar) went first instead,
honoring the plan's "minimal risk first" principle.

Deferred — each needs an interface boundary / cycle-break, the plan's
explicitly "hard, optional" work:

- **`viewer/hover`** — blocked by the `hover ↔ ViewerServices ↔ Languages`
  cycle. The three `hover_*.mbt` files are DOM-free, but extraction needs
  `Languages` pulled into its own package, `ViewerHoverResolvedEvent` /
  `span_anchor_for_target` / `EditorEvent`/`EditorContext` relocated, and
  `ViewerServices::new`'s default-participant registration moved out to break
  the services→participant edge.
- **`viewer/controller`** — *landed* (full pointer-input layer).
  `input.mbt`'s handlers were `Viewer::`/`View::` methods over private state, so
  this was not a leaf move: it follows Monaco's `mouseHandler.ts` shape. A
  `MouseHandler` struct owns the scrollbar-thumb drag *and* the
  `MouseDownState`-equivalent (multi-click, selection-drag, autoscroll), and
  calls back through a `PointerHandlerHelper` — the analog of Monaco's
  `IPointerHandlerHelper`, built as a **struct of nodes + closures** (the same
  idiom as `ViewContext`, mirroring `View._createPointerHandlerHelper`) by
  `Viewer::hook_view_input` where the view is in scope. The viewer core keeps
  the measurement read-phase (`measure`/`view_metrics`/`gutter_width`, exposed
  via the helper) and the dispatch side (`Viewer::dispatch_mouse` = Monaco's
  `ViewController`, fed a controller-side `MouseDispatch` intent), as Monaco
  keeps `viewController.ts` under `view/`.

## Background: why the package went flat

The root cause is a module-scope mismatch between the source and target
languages, compounded by a MoonBit constraint Monaco's source does not have.

- **TypeScript module = file. MoonBit module = package (directory).**
  Monaco's `vs/editor/browser/` is a *directory* holding ~30 independently
  imported file-modules plus ~24 `viewParts/<part>/` folder-modules, each with
  its own encapsulation boundary. In MoonBit every `.mbt` file in `viewer/`
  shares one namespace with no inter-file boundary. A naive
  "Monaco *directory* → MoonBit *package*" mapping therefore fuses every
  file-module Monaco kept apart. The flat package is exactly the sum of those
  fused file-modules.

- **The correct mapping is "Monaco *module* → MoonBit *package*."**
  Monaco already drew the cut lines: every `viewParts/<part>/` and
  `contrib/<feature>/` folder is a natural sub-package. The common layer port
  followed this and split cleanly (`view_model`, `view_layout`,
  `view_line_renderer`, `cursor`, `model` ↔ `vs/editor/common/*`). The browser
  layer did not.

- **MoonBit forbids package cycles; TypeScript allows file cycles.**
  Monaco's `View ⇄ viewParts ⇄ viewContext` is a cyclic object graph: parts call
  back into the view/context and vice versa. TS tolerates that across files. In
  MoonBit you cannot put each view part in its own package without first breaking
  the cycle (a shared context package plus callback interfaces, mirroring
  Monaco's `viewPart.ts` base and event bus). The common layer split cleanly
  precisely because it is an acyclic pipeline
  (`model -> view_model -> view_layout -> view_line_renderer -> View`).

So the package is large for two compounding reasons: the scope mismatch fuses
per-file modules, and content Monaco places *outside* `editor/browser` was
imported into it.

## Current Shape (evidence)

`viewer/` root, non-test, ~7,400 lines across 38 files. Largest clusters:

| Cluster | Files / lines | Monaco home |
| --- | --- | --- |
| hover | `hover_controller.mbt` (328), `hover_participants.mbt` (327), `hover_render.mbt` (170) ≈ 825 | `contrib/hover/` (not in `editor/browser`) |
| input controller | `input.mbt` (687) | `browser/controller/` mouseHandler + editContext input, fused |
| scrollable element | `scrollable_element.mbt` (571) | `base/browser/ui/scrollbar/` (a base UI widget) |
| content widgets | `content_widgets.mbt` (531) | `browser/viewParts/contentWidgets/` (own folder) |
| view zones / margin / selections / editor scrollbar | flat `view_zones.mbt`, `margin.mbt`, `selection*.mbt`, `editor_scrollbar.mbt` | `browser/viewParts/<part>/` (each own folder) |
| folding | `folding.mbt` (116) | `contrib/folding/` |
| markers | `markers.mbt` (200) | `contrib/message` + marker hover participant |
| hit testing | `hit_test_dom.mbt` (132) | `browser/controller/mouseTarget.ts` |

What is already faithful: the common-layer sub-packages
(`view_model`, `view_layout`, `view_line_renderer`, `cursor`, `model`,
`common`).

## Diagnosis

Two distinct problems, with different difficulty:

1. **Misfiled leaves (no architectural obstacle).** Hover, folding, inlay
   hints, and markers are `contrib/*` features — they depend *on* the editor,
   not the other way round. `scrollable_element` is a `base/browser/ui` leaf
   widget. None of these participate in the view's dependency cycle. They are
   simply in the wrong package. ~1,400+ lines are extractable with only import
   bookkeeping.

2. **Genuinely-cyclic core (real obstacle).** `view`, the view parts
   (`content_widgets`, `overlay_widgets`, `view_zones`, `margin`,
   `view_overlays`, selections), `view_part`, `view_context`, `view_layer`,
   `rendering_context`, and `view_controller` form a bidirectional object
   graph. Splitting these into Monaco-shaped per-part packages requires first
   introducing a cycle-breaking boundary. This is the hard, optional part.

## Target Shape

Promote along Monaco's own seams. Proposed packages under `viewer/`:

- `viewer/hover` — content + glyph hover controller, participants, rendering
  (← `contrib/hover/`). Depends on the viewer core, not vice versa.
- `viewer/folding` — folding controls (← `contrib/folding/`).
- `base/browser/ui/scrollbar` (or `viewer/ui/scrollbar`) — `scrollable_element`
  as a base UI widget, not editor code (← `base/browser/ui/scrollbar/`).
- `viewer/controller` — `input` + `hit_test_dom` (← `browser/controller/`,
  mouseHandler + mouseTarget + editContext input). Splitting input from mouse
  handling internally can follow.
- (Later, optional) `viewer/view_parts/<part>` packages for content widgets,
  overlay widgets, view zones, margin, selections — gated on breaking the view
  cycle via a shared `view_context` package + callback interfaces.

The cyclic core (`view`, `view_part`, `view_layer`, `view_overlays`,
`rendering_context`, `view_controller`, `view_context`) stays in one package
until a cycle-breaking boundary is designed.

## Phased Plan

Order chosen to land value with minimal risk first.

1. **Extract `viewer/hover`.** Move the three `hover_*.mbt` files and their
   wbtests plus `hover.css` into a new sub-package. Add the import edge
   `viewer -> viewer/hover` (or have the viewer construct hover via a service
   interface). Confirm no reverse dependency is needed.
2. **Extract `scrollable_element`** into a `base/browser/ui/scrollbar`-shaped
   package. It is a leaf widget; expect only outbound imports.
3. **Extract `viewer/folding`** (and inlay-hint projection if cohesive).
4. **Extract `viewer/controller`** (`input`, `hit_test_dom`). Watch for
   callbacks back into the view; if present, route them through an interface so
   the package edge stays one-directional.
5. **Re-evaluate the core.** With leaves gone, measure the remaining package.
   Only then decide whether to invest in cycle-breaking for per-part packages,
   and design the shared-context + interface boundary if so.

After each phase: run `just check`, the wbtests, and the browser smoke tests;
keep `pkg.generated.mbti` regenerated.

**Update docs as part of each phase, not after the whole plan.** A package move
is not done until the living docs match the new boundaries. Per phase:

- Update `viewer/README.md` — its "Boundaries" dependency list and the
  `editor/browser`-role description must name the new sub-package and drop any
  responsibility that moved out.
- Add a `README.md` for each new package (e.g. `viewer/hover/README.md`)
  stating its Monaco origin (`contrib/hover/`, `base/browser/ui/scrollbar/`,
  …), responsibilities, and allowed dependency edges.
- Update `docs/architecture.md` so the package map and dependency direction
  reflect the new layout.
- When the plan is fully implemented, follow the `exec-plans/README.md`
  convention: treat this file as historical evidence (do not rewrite its
  goals/steps), record completion, and move living detail into the docs above.

## Validation

- `just check` repository guardrail passes after each phase.
- Hover scheduling/staleness (`hover_controller_wbtest.mbt`) and services
  (`services_wbtest.mbt`) tests move with their code and still pass.
- Browser component tests (public API, selection/copy, wrapping, hover overlap,
  folding, view zones, inlay-hint copy) stay green.
- No new package cycle is introduced (MoonBit will reject it; treat a rejection
  as a signal that an interface boundary is missing, not as a reason to merge
  packages back).

## Non-Goals / Risks

- Not changing runtime behavior, the public `Viewer` facade, or CSS output.
- Not forcing the cyclic view/view-parts core into per-part packages in this
  plan; that is explicitly deferred to phase 5 and may stay as one package if
  the cycle-breaking cost outweighs the benefit.
- Risk: extracting a "leaf" that turns out to have a hidden back-edge into the
  view. Mitigation: introduce a narrow interface in the core package and have
  the extracted package depend on that, never the concrete view.

## Related

- `monaco-one-to-one-port.md`
- `monaco-view-part-ownership-architecture.md`
- `monaco-role-aligned-viewer-architecture.md`
- `viewer-package-namespace-rename.md`
- `viewer/README.md` (states the `editor/browser` role and boundaries)
