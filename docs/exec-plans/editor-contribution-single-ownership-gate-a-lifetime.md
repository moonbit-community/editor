# Editor Contribution Single Ownership — Gate A Lifetime Companion

Status: inventory ready — STOP FOR REVIEW; no implementation has started
Date: 2026-07-14
Parent plan: `docs/exec-plans/editor-contribution-single-ownership.md`
Local snapshot: `b26a95f61ebf8a0d640b61dc33bffe9b3c7a5c21`

## Scope and Evidence Rule

This companion freezes the local representation, construction, lookup,
model-transition, callback, and disposal evidence for the five registered
contributions:

1. `agentFeedback.editorInputContribution`;
2. `agentFeedback.editorWidgetContribution`;
3. `editor.contrib.folding`;
4. `editor.contrib.contentHover`;
5. `quickDiff.decorator`.

It also audits the four feature-global instance maps. It does not inventory the
upstream TypeScript denominator, change product code, or decide the final public
contribution API. Source locations below are from the local snapshot above.

The relevant test inventory is deliberately limited to tests that traverse the
registry, `Viewer` model/disposal lifecycle, or root/browser glue for one of the
five contributions. Pure folding/hover/quick-diff algorithms and widget geometry
tests are useful feature evidence but do not prove instance ownership or
lifetime, so they are not counted here.

## Representation Decision

### Why a closed enum is the right local representation

The contribution-description registry is process-wide, but it is not an
extension API. `EditorContributionRegistry`, registration, and
`editor_registry()` are private, and `editor_registry()` calls the five
registrations explicitly (`viewer/editor_extensions.mbt:325-360`). The runtime
set is therefore statically closed even though descriptions are held in an
array. A private enum makes every typed lookup and disposal branch exhaustive;
adding a sixth contribution becomes a compile-time edit rather than a runtime
downcast convention.

The approved shape remains:

```moonbit nocheck
priv enum EditorContributionInstance {
  ContentHover(@hover_browser.ContentHoverController)
  Folding(@folding_browser.FoldingController)
  AgentFeedbackInput(
    @agent_feedback_browser.AgentFeedbackEditorInputContribution,
  )
  AgentFeedbackWidget(
    @agent_feedback_browser.AgentFeedbackEditorWidgetContribution,
  )
  QuickDiff(QuickDiffContributionState)
}
```

The private central entry should own at least
`{ id, instance: EditorContributionInstance, listeners }`. The entry-level
listener store owns Viewer/service subscriptions for input, widgets, and
folding. Hover keeps timers and its cancellation source on the concrete hover
controller; folding keeps its model-scoped `local_to_dispose` on the concrete
controller. Per the parent plan, `QuickDiffContributionState` retains its
`EditorDecorationsCollection` and its three feature listeners; the common
entry listener store can be empty for that variant.

The current `EditorContribution` is `pub(all)` and exposes only `id` and a
dispose closure (`viewer/editor_extensions.mbt:35-41`). The first exact-type
probe below proves the private enum/private entry map. A second probe proves
that MoonBit also accepts a `pub struct EditorContribution` with private `id`,
private-enum `instance`, and private listeners behind a public Viewer-like
getter. There is therefore no language blocker to an opaque public entry.

This plan still must not decide the public facade. Milestone B will keep a
private `EditorContributionEntry` as the actual map value and adapt it to the
temporary public `EditorContribution` presence/lifecycle view. That preserves
today's `get_contribution(id) -> EditorContribution?` contract without exposing
the enum or making the actual instance live in two stores. The compiler-proven
opaque-public-entry option remains available to the later public-API plan,
which can assess the API narrowing from today's `pub(all)` fields. The private
enum must never be made public merely to preserve the getter signature.

### Reproducible runtime spike

This exact command ran from `/tmp`, so it created no repository file:

```sh
moon run --target native -e '
struct Hover { mut value : Int }
struct Folding { mut value : Int }
struct FeedbackInput { mut value : Int }
struct FeedbackWidget { mut value : Int }
struct QuickDiff { mut value : Int }
enum Instance {
  ContentHover(Hover)
  Folding(Folding)
  AgentFeedbackInput(FeedbackInput)
  AgentFeedbackWidget(FeedbackWidget)
  QuickDiff(QuickDiff)
}
fn main {
  let hover : Hover = { value: 1 }
  let folding : Folding = { value: 2 }
  let input : FeedbackInput = { value: 3 }
  let widget : FeedbackWidget = { value: 4 }
  let quick_diff : QuickDiff = { value: 5 }
  let instances : Map[String, Instance] = Map([])
  instances["input"] = AgentFeedbackInput(input)
  instances["widget"] = AgentFeedbackWidget(widget)
  instances["folding"] = Folding(folding)
  instances["hover"] = ContentHover(hover)
  instances["quick-diff"] = QuickDiff(quick_diff)
  hover.value = 11
  folding.value = 12
  input.value = 13
  widget.value = 14
  quick_diff.value = 15
  guard instances["hover"] is ContentHover(h) && h.value == 11 else { abort("hover") }
  guard instances["folding"] is Folding(f) && f.value == 12 else { abort("folding") }
  guard instances["input"] is AgentFeedbackInput(i) && i.value == 13 else { abort("input") }
  guard instances["widget"] is AgentFeedbackWidget(w) && w.value == 14 else { abort("widget") }
  guard instances["quick-diff"] is QuickDiff(q) && q.value == 15 else { abort("quick-diff") }
  let order : Array[String] = []
  for id, _ in instances { order.push(id) }
  guard order == ["input", "widget", "folding", "hover", "quick-diff"] else { abort("order") }
  println("closed enum retained 5 concrete instances; map order=input,widget,folding,hover,quick-diff")
}
'
```

Exact output:

```text
closed enum retained 5 concrete instances; map order=input,widget,folding,hover,quick-diff
```

This proves that one heterogeneous insertion-ordered map can retain the five
original mutable struct references, recover each concrete type by exhaustive
matching, and preserve the reviewed construction/disposal order. No identity
copy, trait object, process global, or second lookup table is needed.

### Exact repository-type compilation probe

A transient `viewer/__gate_a_contribution_enum_spike.mbt` declared the exact
four imported controller payloads, the root-owned quick-diff state, the five
enum variants, a private `{ id, instance, listeners }` entry, and
`Map[String, GateAEditorContributionEntry]`. The decisive command was:

```sh
moon check viewer --target js --warn-list +73
```

It finished with `0 errors`. The only probe diagnostics were expected
unused-private-type/constructor warnings; the other three warnings were the
pre-existing unused fields in
`viewer/browser/view/rendering_context.mbt`. The transient file was then
deleted. The worktree was clean before the probes; after their removal, the
only untracked paths were the three Gate A companion documents. No transient
or product file remained.

### Public opaque-facade compilation probe

A second transient root-package file used the same exact private enum payloads
and declared:

```moonbit nocheck
pub struct GateAPublicEditorContribution {
  priv id : String
  priv instance : GateAPublicEditorContributionInstance
  priv listeners : Array[@base_common.Disposable]
}

pub struct GateAPublicViewer {
  priv contributions : Map[String, GateAPublicEditorContribution]
}

pub fn GateAPublicViewer::get_contribution(
  self : GateAPublicViewer,
  id : String,
) -> GateAPublicEditorContribution? {
  self.contributions.get(id)
}
```

The exact command was again:

```sh
moon check viewer --target js --warn-list +73
```

Result: `Finished`, `0 errors`, 16 warnings. Thirteen were expected unused
probe types/fields/constructors, and three were the same pre-existing
rendering-context fields. This proves the public getter may return an opaque
public struct whose private layout contains the private enum; it does not by
itself authorize narrowing today's `pub(all)` field access. The transient file
was deleted and did not change a generated interface.

### Actual package graph

The root package already imports every package needed by the five variants:

| Contribution variant | Concrete owner available to root | Manifest evidence |
|---|---|---|
| content hover | `viewer/contrib/hover/browser.ContentHoverController` | `viewer/moon.pkg:20-21` |
| folding | `viewer/contrib/folding/browser.FoldingController` | `viewer/moon.pkg:19` |
| feedback input | `viewer/contrib/agent_feedback/browser.AgentFeedbackEditorInputContribution` | `viewer/moon.pkg:17-18` |
| feedback widgets | `viewer/contrib/agent_feedback/browser.AgentFeedbackEditorWidgetContribution` | `viewer/moon.pkg:17-18` |
| quick diff | root-private state using quick-diff common/browser algorithms | `viewer/moon.pkg:22-23` |

There are five variants but only three foreign controller-owner packages;
input and widget share the agent-feedback browser package, and quick-diff's
instance state is deliberately root-owned because it contains a
Viewer-bound decorations collection. None of these manifests imports the root
`moonbit-community/editor/viewer` package:

```sh
rg -n '"moonbit-community/editor/viewer"([[:space:]]|,|$)' \
  viewer/contrib/hover/browser/moon.pkg \
  viewer/contrib/folding/browser/moon.pkg \
  viewer/contrib/agent_feedback/browser/moon.pkg \
  viewer/contrib/quick_diff/browser/moon.pkg
```

The command produced no match. `moon check viewer --target js` then completed
with `0 errors` and only the three pre-existing rendering-context warnings.
The root can therefore own all five concrete variants without introducing a
package cycle. A contribution package must not import root merely to own
Viewer subscriptions; those handles belong on the private root entry or, for
quick diff, its root-private state.

## Current Five-Contribution Lifetime Table

Construction order is input, widget, folding, hover, quick diff. That is the
description order produced by `editor_registry()`:
`register_agent_feedback_contribution` appends input and calls the widget
registration, followed by folding, hover, and quick diff
(`viewer/editor_extensions.mbt:344-357`). `instantiate_all` iterates that array
and inserts into the central map in the same order
(`viewer/editor_extensions.mbt:282-293`).

| ID / declared mode | Current concrete state and construction | Viewer/service listeners | Model-scoped state/reset | Typed lookup and final disposal |
|---|---|---|---|---|
| `agentFeedback.editorInputContribution` / `Eventually` | `attach(id)` builds widget/visibility/range/anchor/lane/mouse/suppression/decorations state, then inserts `input_instances` (`agent_feedback_editor_input_contribution.mbt:43-59`). Root immediately calls `hook_agent_feedback` (`agent_feedback_host.mbt:41-60`). | Nine handles: feedback, model, content, selection, scroll, mouse move/leave/down/up (`agent_feedback_host.mbt:85-120`). | Detach resets only hover decoration ids and line (`agent_feedback_editor_input_contribution.mbt:74-82`); the later model event hides input, clears glyph/suppression, and restores/re-reserves the lane (`agent_feedback_host.mbt:169-180`). The widget object and lane base are Viewer-lifetime. | All production calls go through `Viewer::agent_feedback_input_contribution` -> global `get(id)` (`agent_feedback_host.mbt:137-147`): 17 root calls in that file plus the detach reset in `viewer.mbt:782-784`. Final closure disposes subscriptions, then removes the map row (`agent_feedback_host.mbt:51-59`). |
| `agentFeedback.editorWidgetContribution` / `Eventually` | `attach(id)` builds mounted widgets, reply drafts, id pool, and highlight ids, then inserts `widget_instances` (`agent_feedback_editor_widget_contribution.mbt:27-37`). Root immediately rebuilds and subscribes (`agent_feedback_widgets_host.mbt:27-44,65-88`). | Five handles: feedback, navigation, model, content, scroll. | Detach first resets highlight ids, then clears mounted widgets. Widget clearing records focused reply, marks each widget disposed, removes overlays, and clears highlight (`agent_feedback_widgets_host.mbt:90-109`). Drafts and id pool survive a model swap; the new rebuild prunes drafts not represented by the new model's widgets (`:111-145,338-359`). | All production calls go through `Viewer::agent_feedback_widget_contribution` -> global `get(id)` (`:49-59`): nine calls in that file plus the detach reset in `viewer.mbt:786-788`. Final closure clears widgets again, disposes subscriptions, then removes the map row (`:33-43`). |
| `editor.contrib.folding` / `Eager` | `attach(id)` builds the empty controller and inserts `folding_instances`; root installs five listeners and synchronously calls `folding_on_model_changed` (`folding.mbt:88-98`; `folding_contribution.mbt:12-60`). | Five Viewer handles: model, content, cursor, mouse down, mouse up. | `folding_on_model_changed` calls `clear_local`, then, with a model and folding enabled, constructs decoration/folding/hidden-range/provider state (`folding_host.mbt:23-50`). `clear_local` disposes folding model, hidden-range model while its listener is live, model-scoped listeners, then range provider (`folding.mbt:113-140`). | All production calls go through `Viewer::folding_controller` -> global `get(id)` (`folding_host.mbt:14-20`): seven calls there and four in `folding_contribution.mbt`. Final closure calls `clear_local`, disposes the five Viewer listeners, then removes the map row (`folding_contribution.mbt:48-59`). |
| `editor.contrib.contentHover` / `BeforeFirstInteraction` | `attach(id)` builds the hover machine, four timer slots, three debouncers, request generation/source, mouse state, and decoration ids, then inserts `instances` (`content_hover_controller.mbt:79-109`). It has no contribution-level Viewer listener array. | Timers and one async cancellation source are concrete-controller fields; editor/model events enter through root Viewer glue. | Detach calls `cancel_all_timers` (`cancel_react` then operation timers), cancels the request, resets decoration ids/range, clears hover view/flags, and syncs the persistent widget (`viewer.mbt:769-781`; controller `:123-131,228-265,283-291`). Request generation never resets while the Viewer lives. | `Viewer::content_hover_controller` is the only production call to global `get(id)` (`editor_events.mbt:30-36`), with 28 uses in that file plus `attach_model.mbt`, `content_hover_widget_host.mbt`, and `viewer.mbt`. Final closure's `detach` repeats idempotent timer/request cancellation before removing the map row (`hover_contribution.mbt:18-25`). |
| `quickDiff.decorator` / `Eager` | No feature-global map. The registration closure creates one `EditorDecorationsCollection`, three listeners, runs an initial update, then captures them in the central dispose closure (`quick_diff_contribution.mbt:13-56`). | Model, content, and quick-diff-original service handles. | The collection holds decoration ids. Model/content/service events synchronously refill or clear it (`quick_diff_host.mbt:9-34`). | No typed lookup exists. Actual state is closure-captured and the central entry exposes only its lifecycle closure. Final disposal clears the collection, then listeners (`quick_diff_contribution.mbt:47-54`). Target `QuickDiffContributionState` makes that captured state explicit. |

Only four concrete `get` functions are called in production, and each has one
root accessor. Repository-wide `rg` found no other attach/get/detach callers.
Quick diff is the control case proving that a feature-global map was never
necessary.

## Four-Map Collision and Leak Audit

All four `attach` methods assign with `map[editor_id] = controller`; none checks
for a duplicate. Normal `Viewer` construction masks the bug with a monotonic
process counter (`viewer/viewer.mbt:449-461`), and
`"editor ids are process-unique and preincrement in construction order"`
tests adjacent ids. The public attach methods and the map operations themselves
still have overwrite semantics.

| Global map | Insert / remove contract | If an id is reused or two live Viewers collide |
|---|---|---|
| hover `instances` (`content_hover_controller.mbt:69-73`) | Attach overwrites. Detach cancels only the controller currently found at that key, then removes it. | The old controller's timers/cancellation source can remain live and unreachable. Every first-Viewer lookup starts mutating the second controller. Disposing the first cancels/removes the second controller; the second then has no lookup. |
| folding `folding_instances` (`folding.mbt:81-84`) | Attach overwrites. Root disposal clears whichever controller lookup returns; `detach` only removes. | Old folding/hidden models, provider, and model-scoped handles can be stranded. A first-Viewer model event mutates the second Viewer controller. Disposing either Viewer can clear/remove the other's state. |
| input `input_instances` (`agent_feedback_editor_input_contribution.mbt:36-40`) | Attach overwrites. Root disposal first disposes its own listener array, then `detach` removes whichever value owns the key. | The first widget/lane/decoration state becomes unreachable, while its still-live callbacks resolve and mutate the second state. First disposal removes the second row; an already-mounted first widget can survive until root DOM/overlay teardown rather than controller teardown. |
| widget `widget_instances` (`agent_feedback_editor_widget_contribution.mbt:21-24`) | Attach overwrites. Root disposal clears whichever lookup returns, disposes its own subscriptions, then removes. | The first Viewer's bubbles/drafts/highlight become unreachable through its accessor. Clearing from the first can mark/remove the second controller's widget objects while using the first Viewer overlay host; disposal order determines which row disappears. |

A caller can also retain a concrete struct returned by public `attach`/`get`.
Removing a map row does not invalidate that reference; it merely makes the root
accessor unable to find it. This is why target disposal must dispatch directly
through the concrete instance stored in the central entry, never perform a
fresh id lookup.

Target duplicate rejection must occur **before any concrete construction**.
Rejecting after `attach`/construction would already have allocated timers,
widgets, decorations, or subscriptions and would reproduce the overwrite leak.

## Required Two-Phase Central Construction

The current global maps are inserted before synchronous initialization:

- input `attach` precedes `hook_agent_feedback`, whose first call is
  `sync_agent_feedback_lane` and therefore a typed lookup;
- widget `attach` precedes `hook_agent_feedback_widgets`, whose first call is
  `rebuild_agent_feedback_widgets` and therefore a typed lookup;
- folding `attach` precedes listener installation and the trailing
  `folding_on_model_changed`, which immediately performs a typed lookup.

At the same time, today's central map insertion happens only **after** each
description constructor returns (`instantiate_all`,
`viewer/editor_extensions.mbt:286-292`). Simply replacing the feature maps
with an enum while retaining that call shape would make all three initializers
see `None`.

Milestone B therefore has this mandatory construction protocol:

1. Validate/reject duplicate description ids before invoking any constructor.
2. Construct one bare concrete instance/enum variant with no listener or
   initial-model side effects.
3. Insert the private entry into `viewer.contributions` immediately.
4. Initialize that already-indexed entry: install its listener handles and run
   the existing initial `sync`/`rebuild`/`on_model_changed` action.
5. Continue to the next description in registration order.

`instantiate_all` must mutate the Viewer's actual map; it cannot build a hidden
local map and assign it only at the end. The split may be represented as
description-level `construct`/`initialize` callbacks or an equivalent closed
enum dispatch, but a constructor that reaches a typed accessor before central
insertion is rejected. If initialization ever becomes raising, the inserted
entry must be removed and disposed on failure; current initializers are
non-raising.

## Exact Transition and Disposal Trace

### Viewer construction

1. `Viewer::Viewer` allocates the Viewer with an empty central map
   (`viewer/viewer.mbt:315-377`).
2. It installs the marker-decorations lifetime subscription (`:378-389`).
3. `instantiate_all` runs the five constructors in the order above and only
   then assigns the completed map to `viewer.contributions` (`:390-394`).
4. Each of the first four constructors inserts its actual controller into a
   feature map before installing any root hooks. Quick diff keeps actual state
   only in its closure.

Target order is the two-phase protocol above; the observable contribution
order remains input -> widget -> folding -> hover -> quick diff.

### Initial model attach

1. `set_model(Some(model))` no-ops for the same model, otherwise calls
   `detach_model` (empty on first attach), then `attach_model`
   (`viewer/viewer.mbt:702-735`).
2. `attach_model` registers decoration/marker/content/will-dispose and
   ViewModel listeners, creates the attached view handle, ViewModel, and View,
   and publishes `self.model_data` (`viewer/attach_model.mbt:10-184`).
3. It emits the initial View events/layout/build facts and schedules rendering
   (`:185-204`).
4. Only after the new `ModelData` is live does `set_model` fire
   `did_change_model` (`viewer/viewer.mbt:736-745`). `Emitter::fire` delivers a
   snapshot in registration order (`base/common/lifecycle.mbt:89-103`):
   input hides/resets lane state; widgets rebuild; folding clears/constructs its
   model-scoped state; quick diff fills its collection. Hover has no public
   model listener and is already empty on the first attach.

### Content flush (`set_value`)

1. The model/ViewModel flush completes before the public model content emitter.
2. The root content callback cancels hover react/operation timers and request,
   rotates the hover operation while preserving only a settled view, resets
   decoration bookkeeping, and syncs the widget
   (`viewer/attach_model.mbt:68-109`).
3. `did_change_model_content.fire` then delivers input -> widgets -> folding ->
   quick diff in contribution-registration order (`:110` plus the four hook
   files). Input treats the flush as a model reset, widgets rebuild, folding
   recomputes against the existing controller/model (preserving matching
   collapsed regions), and quick diff recomputes its collection.
4. Cursor-content barrier completion runs after those callbacks (`:111`).

### Model swap A -> B

1. `set_model` records URLs/focus and calls `detach_model`.
2. Detach increments the generation, cancels render/cursor/mouse work, then
   resets in this exact feature order: hover timers/request/state/decoration
   ids; input decoration ids; widget highlight ids; mounted feedback widgets
   (`viewer/viewer.mbt:760-790`). Folding and quick-diff controller state remain
   until the later model event.
3. `ModelData::dispose` releases swap listeners in insertion order, calls
   `model.on_before_detached`, disposes View, then ViewModel
   (`viewer/viewer.mbt:175-194,791`). The old DOM leaves and `model_data` becomes
   `None` (`:792-821`).
4. B attaches completely and becomes the live `ModelData`.
5. `did_change_model` delivers input -> widgets -> folding -> quick diff.
   Folding now clears the A folding objects while its hidden-range listener is
   still live, then constructs B state. Quick diff hands its old ids to B's
   delta call (unknown ids are tolerated) and records B ids.
6. Only after every model-change observer returns does the owner-id sweep remove
   remaining A decorations (`viewer/viewer.mbt:745-752`).

### Model removal and reattach

Removal performs the same detach steps, schedules the no-model render, clears
focus, and fires the model event with `new_model_url=None`. Input hides and
restores its lane as needed; widgets clear and do not rebuild without a real
View/model; folding clears and stops at its no-model guard; quick diff clears
its id collection. Hover was already fully reset during detach. The outgoing
owner sweep runs last.

Reattach does not reconstruct any contribution. It creates a new `ModelData`
and fires the same ordered contribution callbacks, so Viewer-lifetime fields
(hover generation, input widget, widget reply drafts/id pool) survive while
model-scoped ids/models/widgets are rebuilt or pruned. Existing tests prove
generic detach/reattach and hover's path, but not this complete five-variant
state boundary.

### Viewer disposal and callback window

`Viewer::dispose` is guarded and executes once (`viewer/viewer.mbt:961-1030`):

1. Set `disposed=true`, cancel the frame, clear the overlay registration map.
2. Call `detach_model` silently (no `did_change_model`) and sweep outgoing owner
   decorations. Hover/input/widget direct reset runs here; folding and quick
   diff are intentionally left for contribution disposal because no model
   event fires.
3. Remove placeholder DOM.
4. Fire `did_dispose` at line 985 **while the central map, all four feature
   maps, contribution subscriptions, and Viewer-lifetime subscriptions are
   still live**. The existing lifecycle test proves that the model is detached
   and `get_contribution(contentHover)` is still `Some` in this callback.
5. Iterate the insertion-ordered central map and dispose input -> widget ->
   folding -> hover -> quick diff (`:986-991`):
   - input disposes nine subscriptions, then removes its feature row;
   - widget clears widgets, disposes five subscriptions, then removes its row;
   - folding clears model-scoped state, disposes five Viewer subscriptions,
     then removes its row;
   - hover cancels all timers/request again, then removes its row;
   - quick diff clears its collection and disposes three listeners.
6. Replace the central map with empty, dispose Viewer-lifetime handles, clear
   root fields/hover scrollbar, dispose emitters, then dispose owned services.

The `did_dispose` window is observable. A user callback can synchronously mutate
the shared feedback or quick-diff services while contribution listeners remain
registered. Those callbacks currently see `disposed=true` and no model; their
resource/model guards should make them no-ops, but no test fires a
contribution callback from inside `on_did_dispose`. The target must retain this
ordering and add the missing regression case rather than disposing entries
before the public event.

### Pending callbacks

- Hover detach disposes all four timer handles before `did_dispose`; generation
  and debouncer checks reject an already-dispatched timer. It cancels the
  request source before model teardown. Async provider emissions carry model
  identity, internal version, operation generation, and token; the Viewer
  `disposed` guard and later missing central entry reject stale completion.
- Folding's Viewer subscriptions live until contribution disposal, while its
  hidden-range listener is model-scoped and deliberately remains live during
  `clear_local` long enough to publish the empty hidden set.
- Input/widget callbacks use a fresh typed lookup on every event. Target entry
  listeners must be disposed before their central entry is removed, preserving
  today's safe order without a global map.
- Quick-diff callbacks capture the collection directly. Target state must keep
  that collection alive until all three listener handles are disposed.
- `Emitter::fire` snapshots listeners but checks each active flag; disposing a
  sibling during a fire prevents the removed listener from running
  (`base/common/lifecycle.mbt:89-103`).

## Exact Existing Test and Browser Scenario Inventory

### Registry and generic lifecycle (13)

- `viewer/editor_extensions_wbtest.mbt:6` —
  `contributions instantiate through the registry and dispose with the viewer`.
- `viewer/test_viewer_wbtest.mbt:276` —
  `decoration queries are scoped by editor id like Monaco`.
- `viewer/test_viewer_wbtest.mbt:297` —
  `editor ids are process-unique and preincrement in construction order`.
- `viewer/test_viewer_wbtest.mbt:306` —
  `model change fires before outgoing owner decorations are swept`.
- `viewer/test_viewer_wbtest.mbt:436` —
  `disposing the installed model detaches it from the viewer`.
- `viewer/test_viewer_wbtest.mbt:452` —
  `disposing a replaced model leaves the current model attached`.
- All seven labels in `viewer/lifecycle_ownership_wbtest.mbt`:
  `preloaded markers survive detach and seed again on reattach` (`:28`),
  `set_value refresh does not acquire another shared-model lease` (`:47`),
  `distinct same-URI models retain independent decoration owners` (`:68`),
  `model disposal detaches two Viewers sharing one registration` (`:92`),
  `explicit services stay borrowed after Viewer disposal` (`:110`),
  `omitted services are owned and Viewer disposal is idempotent` (`:125`), and
  `disposed headless Viewer ignores later model and callback work` (`:167`).

### Hover root lifetime (10)

All ten labels in `viewer/async_model_features_wbtest.mbt`:

- `live hover timers follow 150 300 900ms and cancel stale generations` (`:127`);
- `content and model invalidation clear a pending mouse-react handle` (`:169`);
- `hover widget mouseleave hides when the editor DOM is missing` (`:205`);
- `programmatic hover forwards immediate mode source focus and mouse state` (`:224`);
- `hover scroll handling covers neither top left both and ignored input` (`:303`);
- `invisible hover dismissal cancels work idempotently` (`:353`);
- `visible hover dismissal clears the shown view` (`:386`);
- `content invalidation cancels hover request but preserves shown view` (`:405`);
- `content invalidation removes loading visibility and permits same-anchor restart` (`:429`);
- `hover request stamp rejects version identity generation and token drift` (`:461`).

### Feedback root behavior (5)

All five labels in `viewer/agent_feedback_host_wbtest.mbt`:

- `feedback lane reserves 18px while enabled and restores the base` (`:27`);
- `hover glyph follows non-empty lines of an enabled resource` (`:39`);
- `lines with unresolved feedback refuse the add glyph` (`:66`);
- `feedback landing on the glyph line clears the glyph` (`:81`);
- `selection changes without editor focus never open the input` (`:94`).

### Folding root behavior (4)

All four labels in `viewer/folding_host_wbtest.mbt`:

- `folding: contribution computes indent regions on model attach` (`:6`);
- `folding: toggling a region folds its lines out of the view axis` (`:20`);
- `folding: fold and unfold actions work off the selection` (`:68`);
- `folding: disabling the option clears folds and detaches the model state` (`:86`).

### Quick-diff root behavior (4)

All four labels in `viewer/quick_diff_host_wbtest.mbt`:

- `quick diff: stored original decorates the gutter on model attach` (`:24`);
- `quick diff: original arriving after attach updates, clearing removes` (`:48`);
- `quick diff: an original for another resource does not decorate` (`:74`);
- `quick diff: identical original decorates nothing` (`:89`).

### Browser scenarios (11)

- `tests/browser/component/agent_feedback.spec.js:35` —
  `agent feedback: bubbles, glyph add flow, reply, remove, scroll`.
- `tests/browser/component/async_model_features.spec.js:98` —
  `rejects stale async hover results across model ownership changes`.
- `tests/browser/component/folding.spec.js:19` —
  `folding: chevron click folds and unfolds, keyboard folds at cursor`.
- `tests/browser/component/folding.spec.js:83` —
  `folding: clicking the collapsed ⋯ unfolds; clicks past it and split gestures do not`.
- `tests/browser/component/folding.spec.js:133` —
  `folding: alt-clicking a chevron folds the surrounding regions`.
- `tests/browser/component/folding_nested.spec.js:84` —
  `folding: shift-clicking a chevron folds children first, then the region, and unfolds the subtree`.
- `tests/browser/component/folding_nested.spec.js:102` —
  `folding: middle-clicking a chevron drives the same recursive toggle`.
- `tests/browser/component/model_swap.spec.js:14` —
  `rebuilds the view per model and carries focus across set_model`.
- `tests/browser/component/quick_diff.spec.js:28` —
  `quick diff: gutter shows added, modified, and deleted markers on the right lines`.
- `tests/browser/component/set_value.spec.js:14` —
  `keeps the view and refreshes gutter state across set_value`.
- `tests/browser/smoke/hover_stability.spec.js:11` —
  `hover widget stays mounted and visible while the mouse moves along the span`.

This inventory contains 47 exact labels/scenarios. During this Gate A pass,
`moon test viewer --target js` was green (`186/186`), the hover package was
green (`67/67`), folding browser was green (`53/53`), quick-diff common was
green (`2/2`), and quick-diff browser was green (`4/4`). Browser scenarios were
inventoried from source but not rerun by this docs-only companion.

## Required Behavior Matrix

`TESTED` below means the cited existing test directly proves the row's current
behavior. `DEFERRED` means the behavior must gain a regression test during the
named implementation milestone; nearby generic evidence is not promoted to
proof.

| Required case | Current evidence | Gate status |
|---|---|---|
| Closed enum retains five concrete instances in one map | Runtime spike plus exact repository-type compile probe | TESTED |
| Root can own all payload types without a package cycle | Manifest audit plus `moon check viewer --target js` | TESTED |
| All five known ids and one unknown id | Registry test checks input, widget, hover, and unknown, but omits folding and quick diff | DEFERRED (Milestone B must assert all five variants and unknown) |
| Duplicate id rejected before construction | Current description and all four feature maps overwrite silently | DEFERRED (Milestone B must prove zero constructor/listener/dispose side effects for the rejected row) |
| Exact input -> widget -> folding -> hover -> quick-diff construction order | Source establishes order; no test records it | DEFERRED (Milestone B order trace) |
| Exactly-once construction and Viewer-driven disposal | Presence/empty-map and idempotent Viewer tests are indirect; no per-variant counters | DEFERRED (Milestone B counters for all five) |
| Initial model attach for folding, feedback, quick diff, and hover | Folding/feedback/quick-diff root/browser tests plus hover root tests | TESTED |
| Same-model `set_model` no-op preserves the same five instances | Generic same-model path exists; no variant identity/state assertions | DEFERRED (Milestone B identity matrix) |
| Content flush preserves contribution instances and refreshes state | Hover root tests and browser set-value test prove hover/folding/quick diff; feedback reset/rebuild is not asserted | DEFERRED (Milestone E feedback content-flush assertions) |
| Model swap cancels pending hover and rejects old results | Root timer test, async browser ownership scenario, model-swap browser scenario | TESTED |
| Model swap resets/rebuilds folding state | Only initial attach, option disable, and content flush are tested | DEFERRED (Milestone D A->B state trace) |
| Model swap resets input glyph/selection/widget state and rebuilds bubbles while applying draft policy | Existing feedback tests do not swap models | DEFERRED (Milestone E A->B state/draft trace) |
| Model swap moves quick-diff collection from A to B without leaking A ids/listeners | Initial attach/service/content refresh only | DEFERRED (Milestone B quick-diff A->B test) |
| Model removal and reattach preserve the five Viewer-lifetime instances but rebuild only model state | Generic marker reattach and hover browser path are insufficient for all variants | DEFERRED (cross-variant remove/reattach matrix) |
| Two Viewers keep independent concrete controller state | Unique ids and decoration owners are tested, not contribution state | DEFERRED (Milestone B two-Viewer mutation/isolation test for all variants) |
| Hypothetical id reuse cannot overwrite/leak or detach another Viewer | Current code has the proven collision paths above | DEFERRED (Milestone B duplicate/reuse regression) |
| `did_dispose` fires after model detach but before contribution teardown | `omitted services are owned and Viewer disposal is idempotent` | TESTED |
| Contributions dispose in reviewed order exactly once | Source gives order; current test only proves one public dispose event and later empty central map | DEFERRED (Milestone B five-variant disposal trace) |
| Pending hover timers/request/provider work is canceled on content, swap, model disposal, detach, and Viewer disposal | Hover root lifetime tests plus `rejects stale async hover results across model ownership changes` | TESTED |
| Folding hidden ranges/decorations clear while the hidden-range listener is still live | `folding: disabling the option clears folds and detaches the model state` | TESTED |
| Folding Viewer/model-scoped listeners stop after Viewer disposal | No post-dispose folding event assertion | DEFERRED (Milestone D) |
| Feedback input selection, glyph, and lane state | Five feedback root tests plus browser add flow | TESTED |
| Feedback widget highlight, reply, remove, and scroll behavior | Agent-feedback browser scenario | TESTED |
| Feedback draft/highlight/widget teardown across swap/removal/disposal | Browser scenario does not preserve a draft across rebuild or assert post-dispose silence | DEFERRED (Milestone E) |
| Quick-diff decoration and service-listener behavior while live | Four root tests plus quick-diff/set-value browser scenarios | TESTED |
| Quick-diff listener silence and collection cleanup after disposal | No post-dispose service emission assertion | DEFERRED (Milestone B) |
| Contribution callback triggered synchronously inside `on_did_dispose` | Current lifecycle test observes presence only; it does not fire feature services/callbacks | DEFERRED (Milestone B disposal-window test) |
| A retained old concrete reference cannot act as an id-keyed singleton after detach | Current public attach/get can outlive map membership | DEFERRED (global APIs deleted in Milestones C-E; central direct-instance disposal test) |

## Review Decisions Frozen by This Companion

1. The central representation is a closed private enum with one direct concrete
   instance per entry; no trait object, second map, id-keyed singleton, or
   identity downcast is accepted.
2. A private entry owns common Viewer/service listener handles. Hover keeps
   timers/request ownership on its controller, folding keeps model-scoped
   handles on its controller, and root-private quick-diff state owns its
   collection and listeners.
3. Construction is two-phase: reject duplicates, construct bare state, insert
   centrally, then initialize. Central insertion after initialization is a
   correctness bug because three initializers synchronously use typed accessors.
4. Model swap preserves Viewer-lifetime instances and fields, resets
   model-owned ids/models/widgets before or during the reviewed model event,
   and keeps the existing input -> widget -> folding -> quick-diff event order.
5. `did_dispose` remains before contribution teardown. Typed central lookups
   remain available during the event, but see `disposed=true` and no model.
6. Entry disposal uses the stored concrete instance directly and disposes
   listeners before removing the entry. It never performs a lookup by editor
   id.
7. The temporary public presence facade stays separate from the private central
   entry for this plan. The opaque `pub struct` alternative is compiler-proven,
   but the later public-API plan owns whether to narrow today's `pub(all)`
   fields and merge the facade with the entry.

**STOP FOR REVIEW. Do not edit contribution storage or delete any global map
until this companion and the rest of Gate A are explicitly approved.**
