# MoonBit-Idiomatic View Lifecycle Refactor

Status: proposed; source and local inventory complete; **STOP FOR REVIEW** before
implementation.
Date: 2026-07-13
Monaco oracle: checked-in `vscode` commit
`b18492a288de038fbc7643aae6de8247029d11bd`.

## Summary

Refactor the private browser-view lifecycle so the MoonBit types express the
capabilities that the renderer actually uses:

- all current view concerns receive ordered `ViewEvent` batches;
- only ordinary render parts participate in the shared
  `prepare_render`/`render`/`on_did_render` pipeline;
- `ViewLines` keeps its source-shaped special text-render path instead of
  pretending to support the ordinary render-part API;
- both closed heterogeneous collections use private enums with inherent
  exhaustive dispatch, not traits;
- the already-closed `DynamicViewOverlayHandle` receives the same audit and,
  unless its inventory changes before execution, loses its redundant trait.

This is deliberately not a minimal-diff plan. It may move substantial private
code, split the current handle, rewrite whitebox tests, and adjust package
boundaries where that produces a clearer long-term design. It must not change
observable editor behavior, Monaco parity, public APIs, DOM structure, CSS, or
render ordering.

This plan supersedes only the current private trait representation introduced
while executing:

- `monaco-view-part-render-architecture.md`;
- `monaco-view-part-ownership-architecture.md`;
- `viewer-render-invalidation-parity.md`.

Those implemented plans remain immutable historical records. Their behavior
contracts and completed parity evidence remain authoritative.

## Why This Refactor

The domain term `ViewPart` is useful: it names a visual concern owned and
coordinated by `View`. The current MoonBit `ViewPart` *trait* is not carrying
that architectural meaning cleanly.

The current implementation has:

- six trait methods;
- nine implementations when the eight concrete variants and the forwarding
  `ViewPartHandle` implementation are counted;
- 54 method-level `impl` blocks;
- zero production trait objects;
- zero production functions accepting `&ViewPart`;
- one generic `T : ViewPart` helper, retained only to support a whitebox test;
- an already-closed `ViewPartHandle` enum that performs the real heterogeneous
  dispatch.

The trait therefore does not provide an open extension boundary or runtime
polymorphism. It mainly duplicates the enum dispatch and forces every member to
claim all six capabilities. That produces invalid or misleading states:

- `ViewLines::prepare_render` and `ViewLines::render` abort because the normal
  render path is unsupported;
- `OverlayWidgets::prepare_render` and `OverlayWidgets::render` are no-ops;
- the `CountingViewPart` whitebox fake must implement unrelated empty render
  methods merely to test event-batch accumulation;
- `View::get_view_parts_to_render` must know to exclude `ViewLines` after the
  type system has already admitted it as an ordinary part.

The same shape appears one level down: `DynamicViewOverlayHandle` is a closed
six-variant enum, yet `DynamicViewOverlay` adds two trait methods to the six
concrete overlay implementations and to the handle itself. There is no trait
object or generic consumer there either.

The refactor should retain the useful domain roles while removing abstraction
that does not encode a real extension or substitution point.

## Goals

1. Make unsupported lifecycle operations unrepresentable.
2. Make the event-handler set and ordinary render-part set explicit and
   independently reviewable.
3. Preserve the exact order, batching, dirtiness, render phases, DOM ownership,
   and source-derived constants of the current implementation.
4. Use MoonBit's closed enums and pattern matching for closed product-owned
   sets.
5. Keep behavior next to the owning type when package dependencies allow it;
   use narrow private adapters in `viewer/browser/view` when private context
   types or dependency direction require them.
6. Replace trait-shape tests with tests of observable lifecycle contracts.
7. Leave a smaller, more legible private API with no compatibility shims for
   obsolete internal abstractions.

## Non-Goals

- Do not make the viewer editable.
- Do not add Monaco services, contribution registration, dependency injection,
  minimap, overview ruler, edit context, or textarea input.
- Do not add new rendering behavior or close unrelated Monaco parity gaps.
- Do not change the public `Viewer`, model, layout, widget, or overlay APIs.
- Do not change DOM nodes, class names, attributes, z-order, focus behavior,
  geometry, scheduling, or CSS.
- Do not alter event values, event coalescing, reentrant queue behavior, or
  invalidation semantics.
- Do not mechanically remove traits that represent genuinely open provider
  boundaries elsewhere in the repository.
- Do not rewrite implemented execution plans or their historical ledgers.

## Source Inventory

The refactor is structural, but it touches a 1:1 Monaco-derived lifecycle. The
following files are the pinned source oracle for control flow, membership, and
ordering:

| Source file | Lines | SHA-256 |
| --- | ---: | --- |
| `vscode/src/vs/editor/common/viewEventHandler.ts` | 220 | `1eb8aa7b6af6240b85684838155c8b2ed650e7f3bca26c73f8caf32e25d9b3d5` |
| `vscode/src/vs/editor/browser/view/viewPart.ts` | 82 | `920c845a3ce6016a36f2f4762e962d9fa22c31055d6a60e1639bba9f16cdc280` |
| `vscode/src/vs/editor/browser/view/dynamicViewOverlay.ts` | 15 | `334b8d784b161661c8377773d9fe7f801449a01c657a6a927c695a19e0f5265c` |
| `vscode/src/vs/editor/browser/view/viewOverlays.ts` | 268 | `93dda802411e21e3c23a3db55e416d5f4942fdf2bcfadab79b95d3cedfd4cf5e` |
| `vscode/src/vs/editor/browser/view.ts` | 992 | `22edb04795705b7fc8675ba40d89c448a62141201f1a16b1f20d8b26e82771e2` |

Source facts that constrain the design:

- Monaco `ViewPart` extends `ViewEventHandler`; this TypeScript inheritance is
  a source-language reuse mechanism, not a requirement to reproduce one merged
  MoonBit trait.
- `ViewEventHandler` is also used independently of `ViewPart` in Monaco.
- Monaco's ordered `_viewParts` collection excludes `ViewLines`.
- `ViewLines` receives view events but renders text through the dedicated
  `renderText` path before ordinary parts prepare and write.
- dynamic overlays are registered into an ordered collection and contribute
  per-line HTML in registration order.

Any implementation PR must re-check the pinned files and record a new oracle
commit and hashes if the `vscode` submodule moves first. A changed oracle pauses
execution for inventory review; it is not silently accepted.

## Local Inventory

Primary files:

```text
viewer/browser/view/view_part.mbt
viewer/browser/view/view.mbt
viewer/browser/view/view_event_dispatcher.mbt
viewer/browser/view/view_overlays.mbt
viewer/browser/view/view_events_wbtest.mbt
viewer/browser/view/view_lifecycle_wbtest.mbt
viewer/browser/view/view_part_test.mbt
viewer/browser/view/README.md
viewer/browser/view/pkg.generated.mbti
```

Owning view-part packages and their generated interfaces are in scope only when
a method can move there without reversing the dependency graph or widening a
public contract.

### Current `ViewPart` Members

| Current member | Actual responsibility | Target disposition |
| --- | --- | --- |
| `on_view_event` | inspect one ordered event and report invalidation | inherent dispatch on `ViewEventHandlerHandle`; concrete handler or narrow adapter owns each branch |
| `should_render` | query accumulated dirty state | inherent dispatch on ordinary `ViewPartHandle`; direct query for `ViewLines` where needed |
| `force_should_render` | accumulate dirty state after a batch | private handler operation reached by `ViewEventHandlerHandle` |
| `prepare_render` | read/compute phase for ordinary parts | inherent dispatch on `ViewPartHandle`; no `ViewLines` case |
| `render` | DOM write phase for ordinary parts | inherent dispatch on `ViewPartHandle`; no `ViewLines` case |
| `on_did_render` | clear/commit dirty state after an ordinary render | inherent dispatch on `ViewPartHandle`; dedicated `ViewLines` completion remains on its special path |

### Closed Membership

The construction boundary is closed. Preserve these exact source-shaped orders
unless the pinned source inventory proves otherwise:

| Concern | Receives events | Ordinary part lifecycle | Special handling |
| --- | :---: | :---: | --- |
| `ViewLines` | yes | no | direct `render_text` path and direct disposal |
| `ViewZones` | yes | yes | none |
| `ContentViewOverlays` | yes | yes | owns content overlay composition |
| `MarginViewOverlays` | yes | yes | owns margin overlay composition |
| `ContentWidgets` | yes | yes | owns applicable `on_before_render` behavior |
| `ViewCursors` | yes | yes | ordered after content widgets |
| `OverlayWidgets` | yes | yes | retained so its dirty state completes even when prepare/write are currently empty |
| `EditorScrollbar` | yes | yes | disposal reaches the scrollable timer owner |

`DynamicViewOverlayHandle` is also closed, in this order at its construction
sites:

```text
CurrentLine
Selections
Decorations
CurrentLineMargin
LinesDecorations
LineNumbers
```

The implementation must inventory every construction site because content and
margin overlay owners use different ordered subsets; the enum declaration
order alone is not a rendering-order contract.

## Target Architecture

Recommended final shape:

```text
View
├── view_lines: ViewLines
│   ├── participates in view_event_handlers
│   └── renders through the dedicated text path
├── view_event_handlers: Array[ViewEventHandlerHandle]
│   └── all eight current event consumers, in source order
└── view_parts: Array[ViewPartHandle]
    └── seven ordinary parts, excluding ViewLines, in source order

ViewOverlays / ViewOverlayLine
└── dynamic_overlays: Array[DynamicViewOverlayHandle]
    └── closed enum with inherent prepare/render dispatch
```

The same concrete stateful values are placed into the applicable handles. The
two arrays are capability indexes, not duplicate part ownership. Construction
must make that sharing obvious: create each concrete part exactly once, then
build both ordered arrays from those values.

### `ViewEventHandlerHandle`

Add a private enum containing all eight current event consumers. Its inherent
methods should expose only event-handler capabilities:

```moonbit
priv enum ViewEventHandlerHandle {
  ViewLinesHandler(@view_lines.ViewLines)
  ViewZonesHandler(@view_zones.ViewZones)
  ContentViewOverlaysHandler(ContentViewOverlays)
  MarginViewOverlaysHandler(MarginViewOverlays)
  ContentWidgetsHandler(@content_widgets.ContentWidgets)
  ViewCursorsHandler(@view_cursors.ViewCursors)
  OverlayWidgetsHandler(@overlay_widgets.OverlayWidgets)
  EditorScrollbarHandler(@editor_scrollbar.EditorScrollbar)
}
```

Exact variant names may be shortened during implementation if the resulting
matches remain unambiguous. The membership and order may not change casually.

Its batch method preserves the existing accumulation rule:

1. offer every event in the batch to the handler in FIFO order;
2. OR the returned invalidation decisions locally;
3. call the handler's force-dirty operation once after the full batch if any
   event returned `true`;
4. never clear a dirty flag because a later event returned `false`.

Do not introduce another six-method trait behind this enum.

### `ViewPartHandle`

Retain the useful name for the seven ordinary render parts. Remove
`ViewLinesPart`. Give the enum inherent private methods for:

```text
dispose
on_before_render
should_render
prepare_render
render
on_did_render
```

Each method must use an exhaustive match. A wildcard is permitted only where
the source contract truly defines a default no-op, such as the current scoped
`on_before_render` hook; dispatch methods whose purpose is to cover every
variant must enumerate every variant.

`ViewLines` remains a direct `View` field with direct calls for its dedicated
text lifecycle. No method on `ViewLines` may abort merely because it was forced
to implement the ordinary part surface.

### Event-Batch Test Seam

Remove `fn[T : ViewPart] handle_view_part_events`. A whitebox test is not a
reason to keep a production abstraction.

If direct handle tests do not isolate the accumulation rule clearly enough,
use a capability-minimal private helper such as:

```moonbit
fn handle_view_event_batch(
  events : Array[ViewEvent],
  on_event : (ViewEvent) -> Bool,
  force_dirty : () -> Unit,
) -> Unit
```

The exact callback shape is an implementation detail. It must describe only
the behavior under test and must not grow back into a lifecycle interface.

### Package Placement

Apply this order of preference for each current trait implementation:

1. use an existing inherent method on the concrete owning type;
2. add a private or appropriately scoped inherent method to the owning package
   when the required inputs already belong there and imports stay acyclic;
3. keep a small private adapter function in `viewer/browser/view` when it needs
   package-private `ViewEvent`, `RenderingContext`, or
   `RestrictedRenderingContext` types;
4. do not widen public APIs or create reverse imports solely to eliminate an
   adapter.

The goal is clear ownership, not forcing every branch into a different package.
Large file movement is allowed when it improves ownership and dependency
direction, but only after the dependency change is written into the phase
inventory and reviewed.

### `DynamicViewOverlay`

Assuming the pre-implementation inventory still finds no trait object, generic
consumer, or external construction boundary:

- remove the private `DynamicViewOverlay` trait;
- keep `DynamicViewOverlayHandle` as the closed set;
- convert `prepare_render` and `render` into inherent handle methods;
- replace concrete trait implementations with owning methods or narrow private
  adapters following the package-placement rule above;
- preserve construction-site order, per-line result indexing, focus state,
  HTML concatenation, row recycling, and rendered-content deduplication.

If a real open extension boundary is discovered, stop and amend this plan with
the concrete consumer and substitution requirement. Do not retain the trait on
the vague possibility that the set might become open later.

## Behavior Invariants

The refactor is acceptable only if all of the following remain true.

### Event Delivery

- nested collectors append into one outer batch;
- only the outermost matching `end` dispatches;
- events within a batch remain FIFO;
- every current handler sees the full batch in the current handler order;
- a reentrant emit is queued as a later batch and does not interleave with the
  batch being delivered;
- `after_view_events` callbacks run only after earlier and reentrant view-event
  batches complete;
- each handler is forced dirty at most once per delivered batch;
- `false` never clears previously accumulated dirtiness.

### Render Lifecycle

- applicable `on_before_render` work occurs at the same point as today;
- `ViewLines` renders text before ordinary parts prepare and write;
- the set of dirty ordinary parts is recollected after text rendering, matching
  the source-shaped invalidation opportunity;
- all selected parts finish `prepare_render` before any selected part performs
  its DOM-writing `render`;
- `on_did_render` runs in the current order and only for parts that completed
  the ordinary lifecycle;
- `ViewLines` dirty completion remains attached to its special path;
- stable DOM nodes, cached geometry, rendered HTML deduplication, and dirty-bit
  convergence do not change;
- scroll-only frames do not rewrite unchanged line or overlay HTML.

### Ownership and Teardown

- each stateful part is constructed once;
- both handle arrays reference the same applicable stateful part values;
- each resource owner is disposed exactly once;
- `ViewLines` cancels its delayed width work;
- `EditorScrollbar` cancels its hide timer through its scrollable owner;
- array copies or enum copies must not accidentally fork mutable state.

## Structural Parity Ledger

This ledger accounts for every member of the two abstractions being removed.
Implementation must update each row to `PORTED`, `TESTED`, `PASS`,
`DEFERRED (reason)`, or `N-A (reason)` before the first implementation milestone
is committed. Absence is a bug.

| ID | Current member or branch | Target | Required evidence | Status |
| --- | --- | --- | --- | --- |
| VP-01 | `ViewPart::on_view_event` (`viewEventHandler.ts:89-219`) | event-handle exhaustive dispatch | eight-handler order plus existing branch matrices in `view_events_wbtest.mbt` | TESTED |
| VP-02 | `ViewPart::should_render` (`view.ts:626-638`) | render-handle query plus direct lines query | exact dirty ordinary-part selection and convergence tests | TESTED |
| VP-03 | `ViewPart::force_should_render` (`viewEventHandler.ts:91-218`) | event-handle private operation | full-batch, sticky-OR, force-once test | TESTED |
| VP-04 | `ViewPart::prepare_render` (`view.ts:662-674`) | seven-variant render dispatch | text-complete/all-prepares-before-write lifecycle test | TESTED |
| VP-05 | `ViewPart::render` (`view.ts:675-680`) | seven-variant render dispatch | lifecycle-order test plus final browser checks | TESTED |
| VP-06 | `ViewPart::on_did_render` (`viewEventHandler.ts:31-33`; `view.ts:677-679`) | seven-variant completion plus direct lines completion | dirty convergence in membership and lifecycle tests | TESTED |
| VP-07 | `ViewLines` unsupported ordinary prepare/render branches (`view.ts:641-649`) | absent from ordinary type surface | exact 8/7 membership test and direct text completion | TESTED |
| VP-08 | `OverlayWidgets` empty prepare/render branches (`view.ts:252`) | retained for lifecycle completion | seven-part membership and dirty convergence tests | TESTED |
| VP-09 | `ViewPartHandle` eight-way forwarding impls (`view.ts:195-253`) | split event and render enum inherent methods | exhaustive matches and exact order tests | TESTED |
| VP-10 | generic `T : ViewPart` batch helper (`viewEventHandler.ts:89-219`) | minimal callback helper | callback-only batch-contract test | TESTED |
| DVO-01 | `DynamicViewOverlay::prepare_render` (`viewOverlays.ts:113-121`) | handle inherent dispatch | exhaustive six-variant match and construction inventory | TESTED |
| DVO-02 | `DynamicViewOverlay::render` (`viewOverlays.ts:165-169`) | handle inherent dispatch | per-line concatenation, both bounds, and retained-row dedupe tests | TESTED |
| DVO-03 | content/margin subset registration order (`view.ts:218-231`) | unchanged construction-site arrays | exact content/margin subset order test | TESTED |

`INVENTORIED` is not an exit status. The implementation phase must replace it
with one of the playbook statuses and cite the relevant source and test.

## Execution Phases

Each phase below is a coherent, validated milestone and should be committed
separately. Do not squash or amend the milestones without approval.

### Phase 0: Review Gate

This document completes the initial source and local abstraction inventory.
Before editing production code, review and approve:

- the decision to model two closed capability indexes rather than one trait;
- the exact event-handler and render-part membership and order;
- the direct special lifecycle for `ViewLines`;
- the planned removal of `DynamicViewOverlay`;
- any proposed movement across package boundaries.

**Stop here. Creating this plan does not authorize implementation.**

### Phase 1: Separate Event and Render Capabilities

1. Re-read the pinned source and update the structural ledger with precise
   source citations.
2. Introduce `ViewEventHandlerHandle` with all eight current event consumers.
3. remove `ViewLinesPart` from `ViewPartHandle` and convert its lifecycle
   forwarding to inherent methods;
4. construct each concrete stateful part once, then build the two ordered
   capability arrays;
5. route dispatcher delivery through `view_event_handlers`;
6. route ordinary dirty selection and render phases through `view_parts`;
7. call the `ViewLines` special render and disposal operations directly;
8. remove `ViewPart`, all `impl ViewPart` blocks, and the generic test helper;
9. update whitebox tests to assert capability membership, ordering, batching,
   and phase behavior without implementing a fake render lifecycle;
10. run the focused MoonBit checks and tests listed below.

Milestone result: no `ViewPart` trait remains, unsupported `ViewLines`
operations are absent, and behavior tests are green.

### Phase 2: Remove the Redundant Overlay Trait

1. Re-inventory every `DynamicViewOverlayHandle` construction site and record
   the ordered subset used by each owner.
2. Convert handle forwarding to inherent exhaustive methods.
3. Move concrete logic to owning methods where dependency direction permits;
   otherwise use named private adapters in `viewer/browser/view`.
4. Remove `DynamicViewOverlay` and all of its trait implementations.
5. Preserve overlay preparation, result slicing, registration order, HTML
   concatenation, row recycling, focus class updates, and content dedupe.
6. run focused MoonBit tests and browser component tests.

Milestone result: `viewer/browser/view` contains no closed-set trait used only
as an enum forwarding layer.

### Phase 3: Consolidate Ownership and Documentation

1. Review `view_part.mbt` after trait removal. Split it by responsibility if a
   single adapter file remains a long, mixed collection of unrelated part
   behavior. Prefer names that state the boundary, such as event adapters,
   render adapters, or overlay adapters.
2. Keep code in `viewer/browser/view` when it legitimately bridges private view
   context types; do not create tiny packages or public APIs merely to reduce
   file length.
3. Update `viewer/browser/view/README.md` to document the two capability
   indexes, the special `ViewLines` path, ownership, and ordering invariants.
4. Update `docs/architecture.md` only if the refactor establishes or changes a
   cross-package dependency rule.
5. Regenerate and review `pkg.generated.mbti`; no unintended public API delta is
   allowed.
6. Search current documentation and comments for claims that `ViewPart` or
   `DynamicViewOverlay` is a trait and correct only current contracts. Do not
   edit completed plans.

Milestone result: the final file/package layout explains the architecture
without requiring readers to reconstruct it from enum forwarding code.

### Phase 4: Full Validation and Closeout

1. Finish every structural ledger row with a permitted terminal status.
2. Compare the final event and render traces against the pre-refactor baseline.
3. Run all required repository checks.
4. Inspect the final diff for accidental public API, DOM, CSS, selector,
   geometry, or source-order changes.
5. Mark this plan implemented only after all acceptance criteria pass.

## Test and Validation Plan

### Focused MoonBit Validation

Run after each affected implementation milestone:

```sh
moon check viewer/browser/view --target js
moon test viewer/browser/view --target js
```

Run directly affected owning packages as the implementation moves methods.
Use the package paths reported by `moon info`/the workspace package graph rather
than guessing new package names.

Required whitebox coverage:

- exact eight-handler membership and delivery order;
- exact seven-part ordinary render membership and order;
- `ViewLines` participates in event delivery but not the ordinary part array;
- every event in a batch reaches a handler even after an earlier event returns
  `true`;
- force-dirty runs once per handler per batch;
- a later `false` cannot clear earlier or pre-existing dirtiness;
- reentrant events form a later FIFO batch;
- text rendering precedes ordinary part preparation;
- all prepares precede all DOM writes;
- post-text invalidation is included in the recollected render set;
- dirty flags converge after successful rendering;
- content and margin dynamic overlay subsets preserve registration order;
- per-line overlay result slicing and unchanged-content dedupe remain intact;
- each resource-owning part is disposed exactly once.

Prefer trace arrays and state assertions over tests that depend on private type
names. The tests should survive harmless renaming while failing on lifecycle
order changes.

### Browser Validation

Run after Phases 2 and 3:

```sh
just test-browser-component
```

The relevant browser assertions must cover at least:

- initial render and a second unchanged frame;
- scroll-only rendering;
- selection, cursor, decoration, current-line, and line-number overlays;
- content and overlay widgets;
- view zones;
- scrollbar visibility and teardown;
- focus changes;
- no line or overlay HTML rewrite when the rendered content is unchanged.

Do not accept snapshot churn without tying each changed artifact to an intended
observable change. This refactor expects no visual change.

### Required Final Checks

Per `docs/quality.md`:

```sh
just check
just test
just build
just test-browser
```

Also run:

```sh
git diff --check
rg -n "trait ViewPart|impl ViewPart|trait DynamicViewOverlay|impl DynamicViewOverlay" viewer/browser/view
```

The final search must return no production trait or implementation declarations.
Historical prose in implemented plans is intentionally not part of this check.

## Risks and Controls

| Risk | Control |
| --- | --- |
| Building two arrays accidentally creates two independent part states | construct each concrete value once; add identity/state-sharing tests |
| Event order changes while splitting collections | encode exact ordered membership in tests before moving dispatch |
| `ViewLines` dirty state stops clearing | trace its dedicated text lifecycle and completion separately |
| An empty ordinary hook is removed even though completion is required | distinguish empty prepare/write work from render-set membership and dirty completion |
| Adapter movement creates dependency cycles or public API growth | inspect package graph first; prefer private adapters over reverse imports |
| Overlay enum order is mistaken for registration order | inventory and test each content/margin construction site |
| Large code movement hides behavior changes | land separate validated milestones and compare lifecycle traces |
| Source submodule moves during execution | re-pin hashes and stop for inventory review before continuing |

If a milestone fails, fix it forward or stop for review. Do not reset, revert,
amend, or rewrite history without approval.

## Acceptance Criteria

- [ ] Review explicitly approves the two-capability-index design.
- [ ] The pinned Monaco source has been rechecked at implementation start.
- [ ] Every structural parity-ledger row has a permitted terminal status and
      evidence.
- [ ] No private `ViewPart` trait or `impl ViewPart` remains.
- [ ] `ViewLines` cannot be passed through the ordinary render-part lifecycle.
- [ ] The event-handler array contains exactly the eight inventoried consumers
      in the approved order.
- [ ] The ordinary render-part array contains exactly the seven inventoried
      parts in the approved order.
- [ ] No generic production helper is retained solely for a whitebox fake.
- [ ] No private `DynamicViewOverlay` trait or implementation remains unless a
      newly documented and reviewed open extension boundary proves it necessary.
- [ ] Event batching, reentrancy, dirtiness, render-phase order, overlay order,
      DOM identity, and teardown tests pass.
- [ ] `pkg.generated.mbti` contains no unintended public contract change.
- [ ] Current README/architecture prose describes the final ownership model.
- [ ] `just check`, `just test`, `just build`, and `just test-browser` pass.
- [ ] The final diff contains no unintended DOM, CSS, selector, visual, or
      geometry changes.
- [ ] Coherent milestones are committed without rewriting history.

## Review Decision Requested

Approve or revise these decisions before implementation:

1. keep `ViewPart` as a domain concept and closed enum name, but remove it as a
   trait;
2. represent event receipt and ordinary rendering as two explicit ordered
   capability indexes;
3. keep `ViewLines` on its dedicated text path;
4. use inherent enum dispatch plus narrow adapters rather than closed-set
   traits;
5. remove `DynamicViewOverlay` under the same criterion;
6. allow package/file restructuring where it clarifies ownership without
   widening APIs or reversing dependencies.

**STOP FOR REVIEW. Do not begin Phase 1 until the user explicitly asks to
implement this plan.**
