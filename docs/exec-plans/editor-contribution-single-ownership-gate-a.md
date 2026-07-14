# Editor Contribution Single Ownership — Gate A

Status: inventory ready — STOP FOR REVIEW; no implementation has started

Date: 2026-07-14

Parent plan: `editor-contribution-single-ownership.md`

Oracle commit: `b18492a288de038fbc7643aae6de8247029d11bd`

Local baseline: `b26a95f61ebf8a0d640b61dc33bffe9b3c7a5c21`

This is a documentation-only pre-implementation snapshot. No contribution,
Viewer, manifest, generated interface, README, test, browser scenario, or
generated web source changed while producing it. Product storage remains at
the local baseline above.

## Artifact Set and Closed Denominators

This entrypoint records the reviewed ownership and ordering decisions. Three
companions carry the mechanical evidence:

- `editor-contribution-single-ownership-gate-a-upstream.md`: 567 terminal
  source atoms across the complete `codeEditorContributions.ts` unit and the
  explicitly bounded integration/controller lifecycle clusters;
- `editor-contribution-single-ownership-gate-a-local.md`: 226 local rows,
  every registered contribution, feature map/API, typed accessor caller,
  relevant package artifact, and current lifecycle carrier;
- `editor-contribution-single-ownership-gate-a-lifetime.md`: executable
  representation probes, exact construction/model/disposal traces, 47 current
  test/browser labels, and the required behavior matrix.

The companions are part of this review gate. A summary here never replaces
their exact rows.

| Denominator | Closed total |
|---|---:|
| pinned upstream source files | 11 files / 9,788 lines |
| upstream ledger | 567 rows: 136 `PORTED`, 161 `TESTED`, 143 `DEFERRED`, 127 `N-A` |
| complete local production files | 14 files / 3,621 lines / 161 declarations |
| bounded local production carriers | 13 |
| directly relevant local tests | 6 files / 1,094 lines / 34 tests + 18 helpers |
| local structural rows | 226 = 174 production + 52 test declarations |
| registered contribution descriptions | 5 |
| process-global concrete-instance maps | 4 |
| public feature-map APIs | 12 = four `attach/get/detach` triples |
| root typed-accessor call sites | 84 |
| static contribution listener handles | 22 |
| scoped package directories/artifacts | 8 packages / 18 present artifacts |

Every upstream row ends in `PORTED`, `TESTED`, `DEFERRED (reason)`, or
`N-A (reason)`. There are no bare `PASS`, placeholder, duplicate row id, or
unterminated statuses.

## Pinned Source Evidence and Corrections

The canonical SHA-256 of the ordered upstream path/line/file-hash manifest is
`c4479c52556cea78880fd292ec196314c9940fb887379880879498bdc7cb0339`.
The local complete-file manifest hash is
`53c2651a75ebfe83a85bd494e46c6d808bd53437588b3758f96a9d9202b5d0f6`;
the 18 package-artifact manifest hash is
`658f95d3372281df554968a0c0f947e2b37cfa19d9deb928e028cd323c20a9e4`.
The companion manifests retain every individual path, line count, and hash.

Gate A corrects two source-mapping premises before implementation:

1. The original proposal's statement that agent feedback was local with no
   upstream class is false at the pinned oracle. Both
   `AgentFeedbackEditorInputContribution` and
   `AgentFeedbackEditorWidgetContribution` exist and register as
   `Eventually`. Their complete ownership/lifecycle clusters are U10/U11.
2. Local `quickDiff.decorator` is not upstream
   `QuickDiffEditorController` (`editor.contrib.quickdiff`,
   `AfterFirstRender`). It is the per-Viewer reduction of
   `QuickDiffWorkbenchController` plus `QuickDiffDecorator`; its local id and
   eager timing remain deliberate topology adaptations.

The large upstream files are not falsely presented as whole-file inventories.
The upstream companion gives exact cluster boundaries and names every excluded
behavior sibling. `codeEditorContributions.ts` is the one complete upstream
unit in this Gate.

## Current Ownership Failure

`Viewer.contributions` currently owns five `{id, dispose-closure}` wrappers.
The actual hover, folding, feedback-input, and feedback-widget controllers live
in four process-global maps keyed by `Viewer::get_id`; quick diff's actual
collection/listeners live only in closure captures.

All four maps have the same unsafe topology:

| Map | Current write/remove | Consequence |
|---|---|---|
| hover `instances` | attach overwrites; detach cancels/removes the value currently under the string key | an old attach can strand live timers; stale detach cancels and removes the replacement |
| folding `folding_instances` | attach overwrites; cleanup re-looks up by key before remove | an old Viewer can clear the replacement's folding state while stranding its own model/provider graph |
| feedback `input_instances` | attach overwrites; detach removes by key only | callbacks from the old Viewer resolve the replacement; widget/host closures can keep a Viewer reachable globally |
| feedback `widget_instances` | attach overwrites; cleanup and remove use the shared key | one Viewer can clear another's widgets/drafts/highlight; global DOM/host reachability survives skipped disposal |

The monotonic current editor-id counter reduces ordinary collision frequency;
it does not repair overwrite semantics, stale detach, skipped-dispose leaks, or
split ownership. The public `attach(String)` APIs accept arbitrary duplicate
keys today.

## Reviewed Central Representation

The actual map value becomes a private root entry. The existing public
`EditorContribution` remains a temporary presence/lifecycle facade for this
plan so the later public-API plan retains its decision boundary.

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

priv struct EditorContributionEntry {
  id : String
  instance : EditorContributionInstance
  listeners : Array[@base_common.Disposable]
}
```

`Viewer.contributions` becomes the sole
`Map[String, EditorContributionEntry]`. `QuickDiffContributionState` is a
private root struct containing the existing `EditorDecorationsCollection` and
its three listeners. The common entry listener store owns the five folding,
nine input-feedback, and five widget-feedback Viewer/service subscriptions.
Hover keeps its four timers and cancellation source on its concrete controller;
folding keeps `local_to_dispose` on its concrete controller.

This allocation follows the dependency owner: root `Viewer` glue registers the
Viewer/service callbacks, so feature packages do not gain public
listener-install APIs. There is no listener side map.

The representation has three executable proofs:

- a native `/tmp` program retained five mutable concrete values in one closed
  enum map, recovered each by matching, and observed insertion order
  `input, widget, folding, hover, quick-diff`;
- an exact root-package transient compiled all four imported controller types,
  the quick-diff state, private enum, entry, listener array, and map with zero
  errors;
- a second exact probe compiled an opaque public getter carrier containing the
  private enum with zero errors. That proves the option but does not authorize
  narrowing today's public fields in this plan.

Both transient files were deleted. No probe or product file remains.

## Dependency Proof

Root `viewer/moon.pkg` already imports the hover-browser, folding-browser,
agent-feedback-browser, quick-diff-common, and quick-diff-browser packages.
None of those feature manifests imports root `viewer`. The private enum adds no
dependency edge and no package cycle.

The set is legitimately closed: the registry, descriptions, registrations,
and initializer are private, and `editor_registry()` statically installs
exactly five rows. A sixth contribution must produce exhaustive compiler edits
to initialization, typed lookup, reset, and disposal. A trait object, identity
downcast, feature singleton, or second map is rejected.

## Five Reviewed Rows

Construction order is input feedback, widget feedback, folding, hover, then
quick diff. Declared timing remains source-shaped, while the local product
continues to construct every mode eagerly.

| ID | Mode | Actual state | Static listeners | Model-state owner/reset | Typed access/disposal target |
|---|---|---|---:|---|---|
| `agentFeedback.editorInputContribution` | `Eventually` | concrete input controller | 9 | controller fields survive; decoration ids/line reset on detach; later model event hides/re-derives lane/input state | central `AgentFeedbackInput` match; dispose entry listeners in current order |
| `agentFeedback.editorWidgetContribution` | `Eventually` | concrete widget controller | 5 | draft/id pool survive; highlight ids/widgets rebuild or clear by model | central `AgentFeedbackWidget` match; clear widgets, then listeners |
| `editor.contrib.folding` | `Eager` | concrete folding controller | 5 | controller owns folding/hidden/provider/model-local store; `clear_local` preserves model-hidden-listener-provider order | central `Folding` match; clear local state, then entry listeners |
| `editor.contrib.contentHover` | `BeforeFirstInteraction` | concrete hover controller | 0 | controller owns timers/request/debouncers/decorations; detach resets model state without replacing controller | central `ContentHover` match; cancel timers/request directly |
| `quickDiff.decorator` | `Eager` | root quick-diff state | 3 | state owns collection; model/content/original callbacks refill it | central `QuickDiff` match; clear collection, then state listeners |

The local companion enumerates all 84 existing calls to the four root accessors.
Their names and caller control flow remain; only their body changes from a
feature `get(editor_id)` to an id-and-enum match. A private quick-diff accessor
completes the five-variant set.

## Mandatory Two-Phase Construction

An assign-after-`instantiate_all` rewrite would be incorrect. Three current
initializers synchronously call their typed accessor:

- input initialization starts with `sync_agent_feedback_lane`;
- widget initialization starts with `rebuild_agent_feedback_widgets`;
- folding initialization ends with `folding_on_model_changed`.

Today each succeeds only because `attach` writes the feature-global map first.
The central protocol is therefore fixed per description:

1. reject a duplicate contribution id before construction or side effects;
2. construct one bare concrete instance/enum variant;
3. insert its private entry into the Viewer's actual map immediately;
4. initialize the installed entry by registering listeners and running its
   existing initial sync/rebuild/model action;
5. continue to the next description in registration order.

`instantiate_all` mutates the Viewer's already-empty map. It must not build an
invisible local map and assign it after all constructors return. The source's
duplicate behavior is first-wins: the later description constructor never
runs. MoonBit constructors/initializers are non-raising; if that changes, the
installed entry must be disposed and removed on initialization failure.

## Exact Model and Disposal Order

The target changes lookup/ownership only. These observable orders remain:

- construction: marker lifetime listener, then five contribution rows in the
  reviewed order; all exist before `Viewer::Viewer` returns;
- initial attach: publish complete `ModelData`, then model listeners deliver
  input -> widgets -> folding -> quick diff; hover is already clean;
- content flush: root hover cancellation/reset precedes the public content
  event, then input -> widgets -> folding -> quick diff callbacks;
- model swap: detach resets hover -> input -> widget/overlays, disposes old
  `ModelData`, attaches the new model, fires the contribution callbacks, then
  sweeps outgoing owner decorations;
- model removal/reattach: the same entries survive; only model-owned state is
  cleared/rebuilt;
- Viewer disposal: mark disposed, clear overlay registry, silently detach and
  sweep, remove placeholder, fire `did_dispose` while contributions remain
  reachable, dispose input -> widget -> folding -> hover -> quick diff, clear
  the map, then dispose Viewer lifetime/emitter/service owners;
- repeated disposal: the existing guard performs no second teardown.

Typed disposal dispatches from the entry payload while the map remains
installed. It never re-looks up a concrete controller by editor id. Listener
handles are drained before the entry is removed, so callbacks triggered during
teardown cannot fall through to a replacement or missing singleton. The
observable `did_dispose` window remains unchanged.

## Public-Facade Boundary

The actual central owner is private `EditorContributionEntry`. For this plan,
`Viewer::get_contribution(id) -> EditorContribution?` is adapted from a found
entry and preserves known/unknown/after-dispose behavior. It does not expose
the private enum or introduce a second state map.

The compiler also proved that an opaque public entry with private enum fields
is legal. Changing today's `pub(all)` field exposure, removing the facade, or
making `EditorContributionInstantiation` private belongs to
`viewer-public-editor-api-boundary.md`, not this storage refactor.

## Branch-Derived Test Obligations

Current evidence includes 47 exact relevant unit/browser labels. During Gate A
the root Viewer suite passed 186/186 on JavaScript; hover passed 67/67; folding
passed 53/53; quick-diff common passed 2/2 and browser passed 4/4. The browser
scenarios were inventoried but not rerun for this documentation-only gate.

Milestone B must add failing-before evidence for:

- all five known ids, one unknown id, and wrong enum-variant access;
- duplicate-id first-wins behavior with zero later constructor/listener/dispose
  side effects;
- exact five-row construction and disposal order, once each;
- two simultaneous Viewers with independent concrete state;
- same-model identity, model removal/reattach, and direct-instance disposal;
- quick-diff A-to-B collection ownership and post-dispose listener silence;
- a contribution callback triggered synchronously inside `did_dispose`.

Feature migrations retain/add their own branch matrix:

- hover timers, requests, decoration reset, stale completions, and repeated
  teardown;
- folding model/hidden/listener/provider order and A-to-B rebuild;
- feedback input selection/glyph/lane and widget draft/highlight/teardown across
  content, swap, removal, and disposal;
- all existing browser scenarios after the last global map disappears.

Repository-green checks do not substitute for these assertions. The lifetime
companion marks every current matrix row `TESTED` or `DEFERRED (milestone)`.

## Milestone Protocol After Approval

1. Milestone B introduces the private entry/enum, two-phase construction,
   duplicate guard, typed accessors, public-facade adaptation, and explicit
   quick-diff state. During transition the other four central enum payloads may
   still be the same object referenced by their old maps; no new object or map
   is introduced.
2. Milestone C renames hover's `attach` to its primary constructor, rewrites
   all access through the central match, and deletes hover `instances/get/detach`.
3. Milestone D does the same for folding while preserving `clear_local` order.
4. Milestone E migrates feedback input and widgets as separate green commits,
   then proves no process-global contribution state remains.
5. Milestone F shrinks generated feature interfaces, updates current
   architecture/README text, performs the closing source reread, and freezes
   this plan. Historical implemented plans remain unchanged.

Each milestone runs the focused tests named by its ledger plus
`moon check --target all` and `just check`; final validation adds `just test`,
`just build`, and `just test-browser`.

## Gate A Reconciliation

- [x] all 567 scoped upstream atoms have terminal dispositions;
- [x] all 226 scoped local production/test rows reconcile;
- [x] all five registered rows include id, mode, state, listeners, model state,
      disposal, and typed callers;
- [x] all four maps, twelve feature-map APIs, and 84 typed calls are accounted;
- [x] overwrite, stale-detach, retained-reference, and skipped-dispose hazards
      are recorded;
- [x] exact closed-enum, package-cycle, map-order, and opaque-carrier probes
      compile/run successfully and leave no product file;
- [x] duplicate check -> construct -> insert -> initialize is fixed;
- [x] construction, attach, content, swap, removal, reattach, `did_dispose`,
      final disposal, and repeated-dispose order are fixed;
- [x] current tests and missing branch-derived tests are separated;
- [x] source corrections and seam-based deviations are explicit;
- [ ] product implementation — **STOP FOR REVIEW**.

No contribution storage, constructor, listener, lifecycle, map, or public
interface code may change until this entrypoint and all three companions have
been explicitly approved.
