# Viewer Lifecycle-Domain Internal Aggregates

Status: implemented and fully validated 2026-07-15. Gate A was refreshed and
approved before Milestones B–G began.

Date: 2026-07-15

Local baseline: recorded repository state

Gate A evidence: `viewer-lifecycle-domain-aggregates-gate-a.md`.

Monaco oracle: checked-in `vscode` submodule.

## Summary

Refactor the root `Viewer` from one 49-field private record into a small number
of concrete internal owners whose types express real lifecycle and reset
boundaries:

- `EditorConfigurationState` for viewer-lifetime options, measured geometry,
  font facts, and derived layout identity;
- `ViewerModelSlot` for the nullable per-model bundle plus generation guards;
- `ModelBrowserData` for the real-View-only controller/render-window state;
- `ViewerMount` for the private headless-vs-mounted state and the local no-model
  placeholder/render-frame owner;
- `EditorContributions` for the already-central contribution instance map, with
  content-hover widget and scheduler state moved into its concrete contribution;
- `CursorEventDelivery` for the reentrant cursor-pair queue and content-version
  barrier algorithm.

This is selective aggregation, not an attempt to minimize the raw field count.
Emitters, service provenance, `disposed`, editor identity, overlay-widget
registration, and the root render-publication facts stay direct on `Viewer`
unless a later independent audit proves a stronger owner. `Viewer::set_model`
and `Viewer::dispose` remain the explicit cross-domain orchestrators.

The result should be more structurally aligned with Monaco's selected owners
(`_configuration`, `_modelData`, `_contributions`, `_deliveryQueue`, and
`View`) while using MoonBit private structs/enums to make the local headless
harness and browser-only states legal by construction.

## Why This Refactor

The current `Viewer` record mixes six different kinds of state:

1. viewer-lifetime services, public emitters, and disposables;
2. configuration inputs and derived measurement/layout facts;
3. one-model attach state and stale-callback generation guards;
4. real-browser-view state that cannot exist in the headless harness;
5. contribution state, especially content-hover state split between the
   contribution controller and the root viewer;
6. event-delivery algorithms whose correctness depends on reentrancy rather
   than on model or DOM lifetime alone.

Splitting additional `.mbt` files does not change any of those ownership facts:
all files in the root `viewer` directory remain one MoonBit package. Conversely,
putting every field into a generic `ViewerState`/`ViewerLifetime` bag would hide
the same transitions behind another record without creating an owner.

The refactor therefore uses this admission rule:

> A field moves into an aggregate only when the aggregate can name the field's
> construction, model-reset, mount-reset, and disposal behavior and own the
> corresponding methods without receiving a raw `Viewer` back-reference.

Fields that do not yet satisfy that rule remain direct.

## Goals

1. Preserve all public APIs and keep `viewer/pkg.generated.mbti` unchanged.
2. Preserve editor behavior, event ordering, DOM/CSS, model swaps, focus carry,
   render scheduling, hover freshness, cursor reentrancy, and disposal order.
3. Represent no-real-View state explicitly while keeping public production
   construction DOM-backed.
4. Make illegal partial states unrepresentable, especially:
   - a browser `View` without its `MouseHandler` reference;
   - one placeholder element without its paired text node;
   - a model generation without one canonical nullable `ModelData` slot;
   - hover widget/scheduler state detached from the content-hover contribution.
5. Keep the existing central contribution map as the sole instance store.
6. Move pure state transitions and calculations onto the concrete aggregate
   that owns their inputs.
7. Keep package dependencies acyclic and make all new types package-private.
8. Land the work as behavior-preserving, independently validated milestones.

## Non-Goals

- Do not add editor capabilities or close unrelated Monaco parity gaps.
- Do not port Monaco dependency injection, generic contribution casts,
  edit-context input, or a new shared event-delivery framework.
- Do not expose headless construction or any new aggregate publicly.
- Do not remove the existing headless Viewer white-box harness.
- Do not make the no-model placeholder part of `ModelData`; it is a mounted
  Viewer deviation that exists precisely when no model is installed.
- Do not put all emitters into `ViewerEventHub`; Monaco also keeps widget
  emitters as direct fields, and grouping them would not own new behavior.
- Do not create a generic `ViewerLifetimeState` or `ViewerState` bag.
- Do not introduce trait objects, runtime downcasts, id-keyed secondary
  contribution maps, or managers that retain a raw `Viewer` reference.
- Do not force `pending_rendered`, `scroll_dirty`, and `last_scroll_event` into
  one render-state aggregate before their distinct reset rules are audited.
- Do not change packages merely to reduce one record's field count.
- Do not rewrite completed execution plans; they remain historical evidence.

## Relationship to Existing Plans

This plan builds on, but does not reopen or rewrite:

- `viewer-model-lifecycle-ownership-parity.md`, which established `ModelData`,
  model/service provenance, and disposal ordering;
- `headless-viewer-test-harness.md` plus the current `docs/harness.md`, which
  established a real Viewer/ViewModel harness with no browser `View`;
- `moonbit-idiomatic-view-lifecycle-refactor.md`, which made the browser View's
  closed lifecycle dispatch MoonBit-idiomatic;
- `editor-contribution-single-ownership.md`, which made the root contribution
  map the sole owner and typed lookup table for concrete contributions.

This plan may wrap or refine those private representations, but it must preserve
their landed contracts and test evidence. It must not reintroduce feature-local
contribution maps or a second model/view owner.

## Reference Baseline

This is a local structural refactor, not a new claim of complete 1:1 port
parity. The 1:1 port playbook therefore does not require a new whole-file
source denominator. The following pinned Monaco units constrain owner shape
and ordering; existing completed parity ledgers continue to constrain behavior.

| Source unit | Relevant owner facts | SHA-256 |
| --- | --- | --- |
| `vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts` | direct emitters, shared `_deliveryQueue`, `_configuration`, `_contributions`, `_modelData`, `setModel`, attach/detach, `ModelData` | `18dd294ed185a29c590df75656f18f27d0cefc8d4d778559db946d447130e5d8` |
| `vscode/src/vs/editor/test/browser/testCodeEditor.ts` | `TestCodeEditor._createView` returns a no-real-View result while retaining editor/model/view-model state | `339584740ad74f23fbf4aaadbd901f899085c1241082a543d586e1d2a7ea1785` |
| `vscode/src/vs/editor/browser/widget/codeEditor/codeEditorContributions.ts` | one `_instances` owner with typed lookup/disposal | `3cd98c20ffa0e0f691c38ecd30723240ee91536e2a542bde83e65c2d412ebb99` |
| `vscode/src/vs/editor/browser/view.ts` | real View owns pointer-handler and render-frame lifetimes | `22edb04795705b7fc8675ba40d89c448a62141201f1a16b1f20d8b26e82771e2` |
| `vscode/src/vs/editor/contrib/hover/browser/contentHoverController.ts` | content-hover contribution owns its lazily created widget and disposal | `2e811bcc9ca11606040a9cc127ab178eb29d7be58e6655e4a619e25534f77592` |

If the `vscode` submodule changes before implementation, refresh these hashes
and reread the named owner clusters before editing product code.

Primary local baseline:

```text
viewer/viewer.mbt
viewer/attach_model.mbt
viewer/view_host.mbt
viewer/input.mbt
viewer/controller_host.mbt
viewer/cursor_event_delivery.mbt
viewer/editor_extensions.mbt
viewer/hover_contribution.mbt
viewer/content_hover_widget_host.mbt
viewer/editor_events.mbt
viewer/test_viewer_wbtest.mbt
viewer/cursor_transition_wbtest.mbt
viewer/lifecycle_ownership_wbtest.mbt
viewer/async_model_features_wbtest.mbt
viewer/reveal_wbtest.mbt
viewer/cursor_input_wbtest.mbt
tests/browser/component/model_swap.spec.js
```

## Target Architecture

```text
Viewer
├── configuration: EditorConfigurationState
├── model_slot: ViewerModelSlot
│   └── current: ModelData?
│       ├── model + view_model + attached_view + listeners
│       └── browser: ModelBrowserData?
│           ├── view
│           ├── mouse_handler
│           ├── rendered_window
│           └── horizontal_reveal_request
├── mount: ViewerMount
│   ├── Headless
│   └── Mounted(MountedViewer)
│       ├── container
│       ├── placeholder: PlaceholderDom?
│       ├── render_frame
│       └── editor_has_focus
├── contributions: EditorContributions
│   └── ContentHover(ContentHoverContributionState)
│       ├── controller
│       ├── widget + widget_view
│       └── timeout/async host callbacks
└── cursor_delivery: CursorEventDelivery
    ├── FIFO queue
    ├── reentrant drain gate
    ├── content barrier depth
    └── completed content versions

Direct Viewer fields remain:
services/provenance, disposed, test/lifetime registrations, public emitters,
last_scroll_event, overlay_widgets, pending_rendered, scroll_dirty, editor_id
```

All target types remain in the root `viewer` package. Cohesive files may be
created to keep implementations readable, but file placement is not the
encapsulation mechanism and must not be presented as the architectural result.

## Representation Decisions

### `EditorConfigurationState`

Recommended private shape:

```moonbit nocheck
priv struct EditorConfigurationState {
  mut options : ViewerOptions
  mut font_info : @config.FontInfo
  mut measured_content_width : Double
  mut measured_height : Double
  mut model_line_count : Int
  mut view_line_count : Int
  mut soft_wrap_column : Int
  mut measure_requested : Bool
}
```

The aggregate owns pure configuration transitions, not just storage:

- compute and compare layout identity;
- commit measured size and derived soft-wrap column;
- commit font info and report whether the identity changed;
- update model/view line counts;
- reset only model-derived line counts on detach;
- mark and consume a measure request;
- build immutable option snapshots consumed by ViewModel/View readers.

Browser measurement, View event emission, ViewModel reflow, and render
scheduling remain root orchestration because they cross domains. Avoid a wide
set of trivial forwarding getters; move the calculations that use these fields
onto the aggregate and pass narrow immutable facts to callers.

### `ViewerModelSlot`, `ModelData`, and `ModelBrowserData`

Recommended private shape:

```moonbit nocheck
priv struct ViewerModelSlot {
  mut generation : Int
  mut current : ModelData?
}

priv struct ModelData {
  model : @model.TextModel
  view_model : @view_model.ViewModel
  browser : ModelBrowserData?
  attached_view : @model.AttachedViewImpl
  listeners_to_remove : Array[@base_common.Disposable]
}

priv struct ModelBrowserData {
  view : @view.View
  mouse_handler : @controller.MouseHandler
  mut rendered_window : @view_layout.LineWindow?
  mut horizontal_reveal_request : HorizontalRevealRangeRequest?
}
```

`ModelData.browser=None` is the type-safe local equivalent of Monaco's
`hasRealView=false` test-editor result. It does not mean the model or ViewModel
is missing. Public `Viewer::create` still takes a DOM host; only the private
constructor used by white-box tests starts headless.

`ViewerModelSlot` owns generation/current coherence but does not own the entire
attach/detach transaction. Preserve the current ordering exactly:

1. begin attach increments generation while `current` is still absent;
2. swap-scoped listeners capture that generation;
3. build ViewModel and optional browser data;
4. install one complete `ModelData` only after construction succeeds;
5. begin detach increments generation before any callback-producing cleanup;
6. dispose listeners/model attachment/View/ViewModel in the existing order;
7. clear `current` only at the current post-disposal point.

Do not implement detach as an early `take()` that changes `get_model()` during
cleanup. Do not replace the generation guard with model URL equality.

`Viewer::create_view` should become a function returning
`ModelBrowserData?`. `hook_view_input` should return the newly created
`MouseHandler` after registering its disposal in the `View` lifetime store.
`ModelBrowserData` retains the handler for cancellation and scrollbar rebinding,
but `View` remains its sole disposal owner; do not dispose the handler twice.

### `ViewerMount`

Recommended private shape:

```moonbit nocheck
priv enum ViewerMount {
  Headless
  Mounted(MountedViewer)
}

priv struct MountedViewer {
  container : @rdom.Element
  mut placeholder : PlaceholderDom?
  mut render_frame : @base_common.Disposable?
  mut editor_has_focus : Bool
}

priv struct PlaceholderDom {
  root : @rdom.Element
  text : @rdom.Element
}
```

Invariants:

- the private constructor starts `Headless`;
- `Viewer::create` transitions to `Mounted` before any model is installed;
- a mounted Viewer never transitions back to `Headless`;
- disposal removes Viewer-owned DOM but retains the caller's container
  reference for `get_container_dom_node`;
- `PlaceholderDom` pairs both nodes, eliminating partial placeholder state;
- root render scheduling is a mounted concern because it paints either a real
  model View or the no-model placeholder;
- focus is mounted Viewer state: it survives the detach half of a model swap
  long enough to be carried to the new View, then becomes false for no model.

The current private `attach` contract is not expanded. Attaching a model before
calling private `attach` remains unsupported; public construction already
attaches first, and white-box headless tests deliberately never attach.

### `EditorContributions` and content hover

Recommended private shape:

```moonbit nocheck
priv struct EditorContributions {
  instances : Map[String, EditorContributionEntry]
  mut lifecycle : EditorContributionsLifecycle
}

priv struct ContentHoverContributionState {
  controller : @hover_browser.ContentHoverController
  mut widget : @hover_browser.ContentHoverWidget?
  mut widget_view : @hover.HoverWidgetView?
  mut schedule_timeout : (() -> Unit, Int) -> @base_common.Disposable
  mut launch_async_task : (async () -> Unit noraise) -> Unit
}
```

The current closed `EditorContributionInstance` remains closed, but its
`ContentHover` variant stores `ContentHoverContributionState` instead of only
the controller. The central map remains the sole contribution instance store.

Preserve the already-reviewed construction rule:

1. reject duplicate id before side effects;
2. construct the concrete instance;
3. insert the actual entry into `EditorContributions.instances`;
4. only then install listeners and perform synchronous typed initialization.

Content-hover widget/controller/scheduler state is viewer-lifetime contribution
state. It survives model swaps, while `reset_model_state` clears model-derived
hover facts and remount/rebind uses the new `ModelBrowserData.mouse_handler`.
The package-private scheduler test seam updates the installed hover state rather
than root Viewer fields.

Preserve the current observable disposal order with two explicit contribution
phases if needed:

- the contribution-behavior phase cancels timers/requests and disposes current
  contribution listeners at the current contribution slot;
- the retained browser-resource phase disposes the hover widget/scrollable at
  the current root hover-widget cleanup slot.

If the map must remain allocated between those phases, mark it non-lookuppable
and `Disposing`; do not expose disposed entries or create a temporary second
map. Clear it after the retained browser-resource phase. A single earlier
widget disposal is allowed only if a separate reviewed change proves that the
ordering is unobservable and updates the lifecycle tests; it is not part of
this behavior-preserving plan.

### `CursorEventDelivery`

Recommended private shape:

```moonbit nocheck
priv struct CursorEventDelivery {
  queue : Array[@view_model.CursorStateChangedEvent]
  mut is_draining : Bool
  mut content_barrier_depth : Int
  completed_content_versions : Array[Int]
}
```

This aggregate is Viewer-lifetime algorithm state, not `ModelData` state.
Model swaps can occur reentrantly inside a position/selection/content listener,
so it must retain the active drain gate while dropping stale model facts.

Prefer a state-machine API that returns work to the root orchestrator:

```moonbit nocheck
fn CursorEventDelivery::enqueue(...) -> Unit
fn CursorEventDelivery::begin_drain(...) -> Bool
fn CursorEventDelivery::take_next_ready(...) -> CursorStateChangedEvent?
fn CursorEventDelivery::mark_content_complete(...) -> Unit
fn CursorEventDelivery::end_drain(...) -> Unit
fn CursorEventDelivery::reset_model_scope(...) -> Unit
```

The root Viewer fires public emitters and schedules rendering. The aggregate
must not store emitters or a raw Viewer callback. Reentrant public callbacks
append into the same queue while `is_draining=true`; the outer drain continues
after the current position/selection pair finishes.

`reset_model_scope` clears the queue, content barrier, and completed versions,
but must not force `is_draining=false`. The active-model identity check in
`complete_model_content_delivery` remains at the Viewer boundary before a
version is marked complete.

### Direct root state

Keep these direct because they are the public facade or cross-domain
orchestration boundary:

- `services`, `owns_services`, `disposed`, `testing_registration`,
  `lifetime_disposables`, and `editor_id`;
- every public/testing emitter;
- `overlay_widgets`;
- `last_scroll_event`, `pending_rendered`, and `scroll_dirty`.

The direct render-publication fields may receive a future focused refactor only
after their model-swap, no-model, first-scroll, and disposal reset rules are
inventoried together. This plan neither creates nor reserves a generic render
state owner.

## Complete Viewer Field Disposition Ledger

The baseline `Viewer` has 49 private fields. Every field has exactly one target
disposition below; absence from this table is a planning bug.

| ID | Current field | Lifecycle/reset fact | Target disposition |
| --- | --- | --- | --- |
| VFD-001 | `services` | Viewer lifetime; borrowed or owned by provenance | `KEEP Viewer` |
| VFD-002 | `owns_services` | Viewer lifetime; controls final service disposal | `KEEP Viewer` |
| VFD-003 | `disposed` | Global gate for every domain | `KEEP Viewer` |
| VFD-004 | `testing_registration` | Viewer lifetime; disposed after emitters | `KEEP Viewer` |
| VFD-005 | `lifetime_disposables` | Viewer lifetime; ordered after contribution behavior disposal | `KEEP Viewer` |
| VFD-006 | `options` | Viewer lifetime; configuration transition input | `MOVE EditorConfigurationState.options` |
| VFD-007 | `did_change_model` | Public facade event; disposed with Viewer | `KEEP Viewer` |
| VFD-008 | `did_change_model_content` | Public facade event with cursor-content ordering | `KEEP Viewer` |
| VFD-009 | `did_change_cursor_position` | Public facade event fired by root drain | `KEEP Viewer` |
| VFD-010 | `did_change_cursor_selection` | Public facade event fired adjacent to position | `KEEP Viewer` |
| VFD-011 | `cursor_delivery_queue` | Viewer-lifetime reentrant delivery state; model facts reset on detach | `MOVE CursorEventDelivery.queue` |
| VFD-012 | `cursor_delivery_is_draining` | Must survive reentrant model reset until outer drain exits | `MOVE CursorEventDelivery.is_draining` |
| VFD-013 | `cursor_content_barrier_depth` | Derived from queued flush facts and completed versions | `MOVE CursorEventDelivery.content_barrier_depth` |
| VFD-014 | `cursor_completed_content_versions` | Model facts reset on detach; exact versions, not high-water mark | `MOVE CursorEventDelivery.completed_content_versions` |
| VFD-015 | `did_build_view_model` | Testing observation disposed with Viewer | `KEEP Viewer` |
| VFD-016 | `did_scroll` | Public facade event; first-event diff baseline stays direct | `KEEP Viewer` |
| VFD-017 | `did_change_view_zones` | Public facade event; model producer is swap-scoped | `KEEP Viewer` |
| VFD-018 | `did_dispose` | Must fire before contribution/lifetime teardown | `KEEP Viewer` |
| VFD-019 | `did_mouse_down` | Public facade event from browser controller | `KEEP Viewer` |
| VFD-020 | `did_mouse_up` | Public facade event from browser controller | `KEEP Viewer` |
| VFD-021 | `did_mouse_move` | Public facade event from browser controller | `KEEP Viewer` |
| VFD-022 | `did_mouse_leave` | Public facade event from browser controller | `KEEP Viewer` |
| VFD-023 | `last_scroll_event` | Viewer-lifetime fired-event diff baseline; distinct from pending render | `KEEP Viewer` |
| VFD-024 | `model_data` | Canonical nullable per-model bundle | `MOVE ViewerModelSlot.current` |
| VFD-025 | `model_data_generation` | Monotonic stale-callback guard across attach/detach | `MOVE ViewerModelSlot.generation` |
| VFD-026 | `rendered_window` | Exists only for one real browser View; reset every attach/detach | `MOVE ModelBrowserData.rendered_window` |
| VFD-027 | `content_hover_widget` | Viewer-lifetime lazy hover resource; survives model swaps | `MOVE ContentHoverContributionState.widget` |
| VFD-028 | `hover_widget_view` | Logical cache paired with the hover widget/controller | `MOVE ContentHoverContributionState.widget_view` |
| VFD-029 | `font_info` | Viewer-lifetime configuration fact; remeasured when mounted | `MOVE EditorConfigurationState.font_info` |
| VFD-030 | `measured_content_width` | Mounted measurement retained across model swaps and used headlessly by tests | `MOVE EditorConfigurationState.measured_content_width` |
| VFD-031 | `measured_height` | Mounted measurement retained across model swaps and used headlessly by tests | `MOVE EditorConfigurationState.measured_height` |
| VFD-032 | `layout_model_line_count` | Model-derived configuration identity; resets to zero on detach | `MOVE EditorConfigurationState.model_line_count` |
| VFD-033 | `layout_line_count` | ViewModel-derived configuration identity; resets to zero on detach | `MOVE EditorConfigurationState.view_line_count` |
| VFD-034 | `soft_wrap_column` | Derived configuration fact; persists/recomputes across swaps | `MOVE EditorConfigurationState.soft_wrap_column` |
| VFD-035 | `container` | Present only after mount; retained after disposal | `MOVE MountedViewer.container` |
| VFD-036 | `placeholder_element` | Mounted no-model DOM paired with text node | `MOVE PlaceholderDom.root` |
| VFD-037 | `placeholder_text` | Mounted no-model DOM paired with root | `MOVE PlaceholderDom.text` |
| VFD-038 | `overlay_widgets` | Monaco-shaped widget registry, persistent across model swaps | `KEEP Viewer` |
| VFD-039 | `render_frame` | Mounted root rAF paints View or placeholder | `MOVE MountedViewer.render_frame` |
| VFD-040 | `hover_schedule_timeout` | Content-hover host policy, test-injectable | `MOVE ContentHoverContributionState.schedule_timeout` |
| VFD-041 | `hover_launch_async_task` | Content-hover async host policy, test-injectable | `MOVE ContentHoverContributionState.launch_async_task` |
| VFD-042 | `measure_requested` | Configuration/measurement handshake | `MOVE EditorConfigurationState.measure_requested` |
| VFD-043 | `pending_rendered` | Root render-publication observation with model identity/freshness | `KEEP Viewer` |
| VFD-044 | `scroll_dirty` | Root render-flush publication flag | `KEEP Viewer` |
| VFD-045 | `editor_id` | Stable widget identity and decoration owner id | `KEEP Viewer` |
| VFD-046 | `mouse_handler` | Exists exactly with one real browser View; View owns disposal | `MOVE ModelBrowserData.mouse_handler` |
| VFD-047 | `editor_has_focus` | Mounted root focus carried across model replacement | `MOVE MountedViewer.editor_has_focus` |
| VFD-048 | `horizontal_reveal_request` | Deferred measurement for one real ViewLines instance | `MOVE ModelBrowserData.horizontal_reveal_request` |
| VFD-049 | `contributions` | Viewer-lifetime sole concrete contribution map | `MOVE EditorContributions.instances` |

Gate A must recount the actual record at execution time and prove
`field count == ledger row count`. If the baseline changes, update this plan's
local-baseline commit and ledger before implementation; do not silently assign
new fields to a convenient aggregate.

## Required Lifecycle Traces

### Private headless construction

```text
Viewer::Viewer
  -> configuration initialized with estimated font info
  -> model_slot = empty generation 0
  -> mount = Headless
  -> cursor_delivery = empty/not draining
  -> contributions constructed and initialized once
  -> no DOM, no View, no MouseHandler, no rAF
```

`with_test_viewer` then installs a real `TextModel` and `ViewModel` with
`ModelData.browser=None`. Headless tests continue to set configuration facts
through package-private helpers; no public headless API is added.

### Public production construction

```text
Viewer::create(host)
  -> Viewer::Viewer(...)
  -> attach(host)
     -> Headless -> Mounted
     -> construct one PlaceholderDom pair
     -> retain font-measurement listener
     -> request measure and schedule one root render frame
```

The host remains caller-owned. The mounted state retains its container after
Viewer disposal while removing only Viewer-owned descendants.

### Model attach

Preserve this order:

1. increment model generation;
2. install model/decorations/service listeners in current source order;
3. acquire the attached-view handle;
4. build the real ViewModel;
5. update configuration line-count facts;
6. install swap-scoped ViewModel/layout listeners with the captured generation;
7. create `ModelBrowserData` only when `mount` is `Mounted`;
8. rebind persistent hover/overlay widgets to the fresh browser View;
9. install one complete `ModelData` in `ViewerModelSlot`;
10. emit the existing View events/observations, mark pending render, request
    measurement, and schedule rendering.

### Model detach and replacement

Preserve this order:

1. capture `had_text_focus` in the root `set_model` transaction;
2. invalidate model generation before callback-producing cleanup;
3. cancel the mounted root render frame;
4. reset cursor model facts without clearing an active drain gate;
5. cancel mouse selection through `ModelBrowserData.mouse_handler`;
6. reset contribution-owned model state, including hover;
7. dispose `ModelData` in the existing listener -> model-detach -> View ->
   ViewModel order;
8. clear `ViewerModelSlot.current` at the current point;
9. reset model-derived configuration counts;
10. remove the outgoing View DOM and restore the mounted placeholder when not
    disposing;
11. drop browser data by dropping the outgoing `ModelData`;
12. attach the replacement, restore focus if appropriate, fire
    `did_change_model`, then perform the outgoing decoration-owner sweep.

The root transaction remains visible in `Viewer::set_model`; do not replace it
with `model_slot.set_model(viewer, ...)`.

### Render flush

`Viewer::schedule_render` matches on `ViewerMount`:

- `Headless` returns without scheduling;
- `Mounted` coalesces through `MountedViewer.render_frame`.

`flush_render` preserves the current branches:

- no model: paint `MountedViewer.placeholder` only;
- model with `browser=None`: return without DOM work;
- model with browser data: consume configuration measurement request, render
  the browser View, update `browser.rendered_window`, flush browser reveal,
  publish pending-render and scroll facts from the direct root fields.

### Viewer disposal

Keep the root disposal sequence explicit and behaviorally equivalent:

1. idempotency guard, then `disposed=true`;
2. cancel mounted render frame;
3. clear overlay widget registration;
4. silently detach model and sweep outgoing owner-id decorations;
5. remove mounted placeholder while retaining the host;
6. fire `did_dispose` while contributions and lifetime resources are live;
7. begin ordered contribution behavior disposal;
8. dispose Viewer-lifetime subscriptions;
9. clear mounted placeholder/focus state and the direct `last_scroll_event`
   baseline;
10. finish contribution-owned retained browser-resource disposal at the
    current hover-widget cleanup position, clear the widget/view cache, then
    clear the contribution storage that has remained allocated but
    non-lookuppable in `Disposing` since step 7;
11. clear the remaining direct render-publication state and the configuration
    measure request;
12. dispose all emitters;
13. dispose testing registration;
14. dispose only default-owned services.

Any implementation simplification that changes this sequence requires a
separate reviewed behavior change and is not authorized by this plan.

## Execution Plan

### Gate A — Refresh the ownership inventory and stop for review

Before product edits:

1. Verify the local baseline, `vscode` commit, and the five source hashes.
2. Recount every `Viewer` field and reconcile it one-to-one with VFD-001–049.
3. Use `moon ide outline`, `moon ide peek-def`, and
   `moon ide find-references` where supported, plus `rg` for private-field
   direct accesses, to inventory all readers/writers of every moving field.
4. Record current constructor, model attach, model detach, render flush, and
   disposal traces side by side with the required traces above.
5. Run the focused characterization tests before edits and record their counts.
6. Confirm `viewer/pkg.generated.mbti` is clean at the baseline.

Review gate: stop after refreshing this plan's baseline/ledger/evidence. Do not
begin Milestone B until the field assignments, browser/headless representation,
cursor reset semantics, and two-phase hover disposal decision are reviewed.

### Milestone B — Wrap contribution storage and consolidate content hover

1. Introduce `EditorContributions` around the existing map without changing
   any registered rows or lookup semantics.
2. Route duplicate checks, insertion-before-initialization, typed lookup, and
   ordered disposal through the wrapper.
3. Introduce `ContentHoverContributionState` and change only the closed enum's
   `ContentHover` payload.
4. Move the lazy widget, widget-view cache, timeout scheduler, and async launcher
   into that state.
5. Rewrite root hover glue and the package-private scheduler test seam to obtain
   the concrete hover state through the central typed accessor.
6. Preserve model-reset behavior, persistent-widget remounting, scrollbar
   rebinding, request-generation checks, and the two disposal phases.
7. Delete the four corresponding root fields only after all direct accesses
   are gone.

Focused gate:

```sh
moon test viewer/editor_extensions_wbtest.mbt --target js
moon test viewer/async_model_features_wbtest.mbt --target js
moon test viewer --target js --filter '*hover*'
just check
```

Commit this milestone independently.

### Milestone C — Introduce `EditorConfigurationState`

1. Construct the aggregate from `ViewerOptions` and the estimated `FontInfo`.
2. Move the eight configuration fields and their pure transitions.
3. Update options, measure, font-refresh, layout-identity, wrap, ViewModel-build,
   and live View reader paths to consume one configuration owner.
4. Update headless helpers to set measured viewport/wrap facts through narrow
   package-private aggregate methods rather than direct Viewer fields.
5. Preserve exact configuration-event comparison inputs and order relative to
   ViewModel reflow and render scheduling.
6. Delete old root fields only after an `rg` audit finds no access.

Focused gate:

```sh
moon test viewer/test_viewer_wbtest.mbt --target js
moon test viewer/set_value_api_wbtest.mbt --target js
moon test viewer --target js --filter '*configuration*'
moon test viewer --target js --filter '*layout*'
just check
```

Commit this milestone independently.

### Milestone D — Introduce `ViewerModelSlot` and `ModelBrowserData`

1. Wrap `model_data` and `model_data_generation` in `ViewerModelSlot` without
   changing generation timing.
2. Change `ModelData.view` to `ModelData.browser`.
3. Change `hook_view_input` to return the registered `MouseHandler`.
4. Change `create_view` to return `ModelBrowserData?` containing View, handler,
   empty rendered window, and empty horizontal reveal request.
5. Route view lookup, mouse cancellation, rendered-window synchronization,
   reveal requests, persistent hover rebinding, attach, detach, and disposal
   through `ModelData.browser`.
6. Keep View as the handler's actual disposable owner.
7. Update white-box tests to assert through package-private helpers or the new
   aggregate rather than old root fields; do not widen the public API.

Focused gate:

```sh
moon test viewer/test_viewer_wbtest.mbt --target js
moon test viewer/set_value_api_wbtest.mbt --target js
moon test viewer/reveal_wbtest.mbt --target js
moon test viewer/cursor_input_wbtest.mbt --target js
moon test viewer/lifecycle_ownership_wbtest.mbt --target js
just test-browser-component --grep 'model swap'
just check
```

If the repository's `just test-browser-component` wrapper does not accept
`--grep`, run the documented direct Playwright command or the whole component
suite instead; record the exact command used.

Commit this milestone independently.

### Milestone E — Introduce `ViewerMount`

1. Replace `container=None` with `mount=Headless` in the private constructor.
2. Make private `attach` perform the one-way transition to `Mounted` and create
   one complete `PlaceholderDom`.
3. Move root render-frame cancellation/coalescing and focus state into
   `MountedViewer` methods.
4. Rewrite placeholder painting, theme propagation, View mount/unmount,
   focus/blur listeners, scheduling, disposal, and container queries as
   exhaustive `ViewerMount` matches.
5. Preserve the public DOM-required construction path and the private no-rAF
   headless harness path.
6. Preserve caller host ownership and post-dispose container lookup.

Focused gate:

```sh
moon test viewer/test_viewer_wbtest.mbt --target js
moon test viewer/lifecycle_ownership_wbtest.mbt --target js
just test-browser-component
just check
```

Commit this milestone independently.

### Milestone F — Introduce `CursorEventDelivery`

Do this last because it has the strongest reentrancy constraints.

1. Move the four cursor-delivery fields as one algorithmic aggregate.
2. Move barrier recomputation, completed-version membership, enqueue, ready-item
   selection, and model-scope reset onto it.
3. Keep active-model identity checks, render scheduling, View cursor event
   emission, and public position/selection emission in the root Viewer.
4. Preserve remove-before-callback FIFO semantics.
5. Preserve position-before-selection adjacency during position-listener and
   selection-listener reentrancy.
6. Preserve nested content-version completion order.
7. Preserve model-swap behavior where an old-model completion cannot release a
   same-version new-model flush.
8. Ensure model reset never clears an active drain gate.

Focused gate:

```sh
moon test viewer/cursor_transition_wbtest.mbt --target js
moon test viewer/cursor_behavior_wbtest.mbt --target js
moon test viewer/set_value_api_wbtest.mbt --target js
just check
```

Commit this milestone independently.

### Milestone G — Documentation, API audit, and full validation

1. Update `docs/architecture.md` with the landed internal owner shape and
   precise headless meaning.
2. Update `viewer/README.md` with contribution/model/mount lifecycle contracts.
3. Update `docs/harness.md` only if helper names or recommended test routing
   changed; do not expose private aggregate details as public harness API.
4. Run `moon info --target js` and prove no intended public-interface diff.
5. Run formatting and the complete repository gates.
6. Recount the final direct Viewer fields and verify every VFD row reached its
   intended disposition.
7. Record final milestone results, test counts, and any approved deviations in this
   plan, then mark it implemented.

Full gate:

```sh
moon fmt
moon info --target js
git diff -- viewer/pkg.generated.mbti
git diff --check
just check
just test
just build
just test-browser
```

Commit documentation and closeout evidence as the final milestone.

## Test Matrix

| Behavior axis | Headless/MoonBit evidence | Browser evidence |
| --- | --- | --- |
| private headless construction | `test_viewer_wbtest`: real model/ViewModel, no browser data, no rAF | N-A |
| production mounted construction | lifecycle white-box tests where possible | component Viewer construction |
| no model | model clear/reset tests | placeholder render and theme |
| first model attach | model/view-model observations | real View DOM and `data-uri`/`data-mode-id` |
| same-model no-op | lifecycle/model tests | existing component coverage where applicable |
| model A -> B | generation/listener/reset assertions | `model_swap.spec.js` View replacement, focus, zones, widgets |
| model A -> None | headless model slot/config reset | placeholder restoration and View removal |
| model disposal | model listener and exact-once cleanup tests | hostile post-dispose browser callbacks |
| options/font/measure | configuration/layout/headless viewport tests | measured geometry/component suites |
| soft wrap and line counts | headless projection/window tests | existing geometry/render suites |
| hover settled/loading/async | async hover freshness and scheduler injection | hover widget visibility/scroll/input suites |
| hover across model swap | contribution reset and typed-state tests | persistent widget remount/scrollbar rebind |
| cursor ordinary transition | cursor behavior tests | caret rendering remains browser-owned |
| position listener reentrancy | `cursor_transition_wbtest` adjacency test | N-A |
| selection listener reentrancy | `cursor_transition_wbtest` queued-pair test | N-A |
| nested content flush | version-order/barrier-depth tests | N-A |
| model swap during content listener | old/new same-version isolation test | N-A |
| horizontal reveal | reveal/cursor-input white-box tests | measured horizontal reveal scenarios |
| repeated disposal | lifecycle exact-once tests | component disposal with Model Some/None |
| borrowed vs owned services | lifecycle ownership tests | N-A |

Do not replace semantic white-box assertions with browser DOM assertions. DOM,
measurement, pointer input, real focus, and rAF behavior remain browser tests.

## Acceptance Criteria

- [x] Gate A field count equals ledger count and every moving field's readers
      and writers are inventoried.
- [x] `Viewer` has the five selected concrete owners plus direct facade fields;
      there is no generic catch-all state bag.
- [x] `ModelData.browser=None` is the only no-real-View model state.
- [x] A real browser View cannot be installed without its MouseHandler
      reference and browser-scoped render/reveal facts.
- [x] Placeholder root/text cannot become partially initialized.
- [x] The central contribution map remains the sole contribution instance map.
- [x] Content-hover controller/widget/scheduler state has one concrete owner.
- [x] Cursor delivery has one state-machine owner and all reentrant ordering
      tests pass.
- [x] `Viewer::set_model` and `Viewer::dispose` still visibly express global
      ordering instead of delegating to a manager with a Viewer back-reference.
- [x] No public API or generated interface changes.
- [x] No DOM structure, CSS, geometry, public event, focus, model-swap, or
      disposal behavior changes.
- [x] `just check`, `just test`, `just build`, and the complete
      `just test-browser` suite pass.

## Implementation Closeout

The 49-field Gate A denominator reconciled exactly: 22 fields remain direct and
27 moved. The final root `Viewer` has 27 fields—those same 22 direct facade and
cross-domain facts plus the five selected owners:

```text
configuration  model_slot  mount  contributions  cursor_delivery
```

The exact final record is:

```text
services owns_services disposed testing_registration lifetime_disposables
configuration did_change_model did_change_model_content
did_change_cursor_position did_change_cursor_selection cursor_delivery
did_build_view_model did_scroll did_change_view_zones did_dispose
did_mouse_down did_mouse_up did_mouse_move did_mouse_leave last_scroll_event
model_slot mount overlay_widgets pending_rendered scroll_dirty editor_id
contributions
```

The landed owner shapes match the ledger: `EditorConfigurationState` has 8
fields; `ViewerModelSlot` has 2; `ModelBrowserData` has 4; `MountedViewer` has
4 and `PlaceholderDom` has 2; `EditorContributions` has 2 and its
`ContentHoverContributionState` has 5; `CursorEventDelivery` has 4. No generic
state bag, raw Viewer back-reference, second contribution map, compatibility
mirror field, or public headless API was introduced.

| Milestone | Commit | Result |
| --- | --- | --- |
| Gate A | recorded milestone | 49 fields, 49 ledger rows, ownership traces and baseline characterization recorded |
| B | recorded milestone | contribution storage and content-hover ownership |
| C | recorded milestone | configuration transition owner |
| D | recorded milestone | model slot and browser-only model data |
| E | recorded milestone | one-way headless/mounted owner and atomic placeholder |
| F | recorded milestone | reentrant cursor-delivery state machine |
| G | the commit containing this closeout record | current architecture/harness docs, API audit, and full validation |

Focused final evidence includes 217/217 root Viewer JS tests, 19/19 cursor
transition tests, 12/12 cursor behavior tests, 11/11 lifecycle ownership tests,
8/8 `set_value` tests, 4/4 mount-owner tests, and the 3/3 D browser scenarios
for model swap, reveal, and `set_value`. The complete browser gate passed
83/83, including all 57 component scenarios.

Final validation passed:

```text
moon fmt
moon info --target js
git diff -- viewer/pkg.generated.mbti
git diff --check
just check
just test
just build
READONLY_EDITOR_BASE_URL=http://127.0.0.1:5187 just test-browser
```

`viewer/pkg.generated.mbti` remained byte-for-byte unchanged at SHA-256
`6f1aba10c05f08fd1e3f61f829c69226d75e97b2608f6de30db1c5f7b6c46bac`.
The browser command used the repository's documented already-running-server
path after two ordinary invocations spent Playwright's fixed 60-second server
startup window rebuilding bundles; no browser assertion ran or failed in those
startup-only attempts, and the final command executed the unchanged full suite.

There are no product-behavior deviations from the reviewed plan. Milestone D
used the plan-authorized direct Playwright fallback because the `just`
component wrapper accepts no `--grep` arguments; it expanded the focused gate
to `model_swap.spec.js`, `reveal.spec.js`, and `set_value.spec.js`.

## Risks and Guardrails

### Reentrant model swaps

Moving `model_data` and cursor delivery together can accidentally clear the
drain gate or make a new model's same-version flush visible to an old completion.
Mitigation: move them in separate milestones; cursor delivery is last and uses
the existing reentrancy tests as the primary gate.

### Hidden disposal-order changes

Moving hover widget state into the contribution can silently move its browser
resource disposal earlier. Mitigation: retain explicit begin/finish disposal
phases and test hostile timeout/listener behavior. Do not rely on GC.

### Double disposal of `MouseHandler`

`ModelBrowserData` retains the handler, but View already owns its disposable.
Mitigation: document and test that `ModelData.dispose` disposes View only; no
second handler disposal is added.

### Configuration forwarding boilerplate

A state record with dozens of one-line getters would only relocate fields.
Mitigation: move calculations and transitions, return immutable facts, and
leave cross-domain effects in Viewer.

### Headless/placeholder conflation

Headless means no mounted host and no browser View. No-model placeholder means
a mounted host with no model. Mitigation: keep them in distinct types and test
all four meaningful combinations: headless/no-model, headless/model,
mounted/no-model, mounted/model.

### White-box tests coupled to fields

Several tests assign or inspect private root fields directly. Mitigation: add
narrow package-private test helpers where they express a semantic operation;
otherwise update the test to the owning aggregate. Do not add public getters.

## Commit Strategy

Use one validated commit per milestone:

1. Gate A inventory/evidence only;
2. contribution storage and content-hover ownership;
3. configuration owner;
4. model slot and browser data;
5. mount state;
6. cursor delivery state machine;
7. docs, generated-interface audit, and final closeout.

Do not squash, amend, or rewrite these milestones without approval. If a
milestone exposes a behavior regression, fix it within that milestone before
continuing; do not compensate in a later aggregate.
