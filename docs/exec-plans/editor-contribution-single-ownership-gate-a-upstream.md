# Editor Contribution Single Ownership Gate A — Upstream Ledger

Status: inventory ready — STOP FOR REVIEW
Date: 2026-07-14
Oracle: checked-in reference tree
Parent plan: `docs/exec-plans/editor-contribution-single-ownership.md`

This is the upstream half of Gate A only. It changes no product code and does
not authorize the storage refactor.

## Scope closure and source corrections

`codeEditorContributions.ts` is the only complete source unit in this
companion. The larger files are closed to the exact contribution-ownership
clusters below; their named behavior siblings are excluded. Line-numbered
complete-file reads were still used to find the cluster boundaries.

- **U01 — complete unit:** all of
  `src/vs/editor/browser/widget/codeEditor/codeEditorContributions.ts`.
- **U02 — widget integration:** `_contributions` at line 79; the 21 private
  `InteractionEmitter` owners at lines 123 and 137-194; the attach-scoped
  `_contributionsDisposable` at line 239; constructor selection/initialization
  at 338-344; complete `dispose` at 426-439; complete `setModel` at 506-548;
  complete `saveViewState`, `restoreViewState`, and `getContribution` at
  1038-1088; complete `_detachModel` at 2012-2032; and complete
  `InteractionEmitter` at 2184-2200. Public event aliases are not independent
  contribution owners. All other editor operations, model/view construction,
  widgets, actions, decorations, and helper classes are excluded siblings.
- **U03 — common contract:** complete `IEditorContribution` at 580-596 of
  `editorCommon.ts`. `IDiffEditorContribution` and every unrelated editor
  contract are excluded.
- **U04 — registration contract:** `EditorContributionCtor`,
  `EditorContributionInstantiation`, and `IEditorContributionDescription` at
  31-71; public registration/getter facade rows at 548-554 and 564-580; the
  complete contribution half of `EditorContributionRegistry` at 592-610; and
  its global registration at 639. Diff-editor, action, command, menu, and
  keybinding siblings are excluded.
- **U05 — hover ownership:** `ContentHoverController` fields, constructor,
  `get`, listener hook/unhook, and scheduler-cancellation cluster at 39-126;
  lazy widget ownership at 317-323; and disposal at 410-415. Mouse/keyboard
  hover policy and forwarding methods at 128-316 and 325-409 are excluded
  behavior siblings.
- **U06 — folding ownership:** `CONTEXT_FOLDING_ENABLED` and the `RangeProvider`
  disposal contract at 46-52; `FoldingController` ID/get/fields/constructor at
  68-182; model-scoped owner replacement and provider lifecycle at 227-293;
  pending-computation ownership in `triggerFoldingModelChanged` at 305-350;
  and registration at 1246. Save/restore, folding algorithms, cursor/mouse
  behavior, actions, provider selection, and reporter behavior are excluded
  siblings.
- **U07-U09 — quick-diff mapping:** the two registration calls at 30-34 of
  `quickDiff.contribution.ts`; complete `QuickDiffDecorator` at 32-211 plus
  `QuickDiffWorkbenchController` fields/constructor, enable/disable,
  editor-tracking, and disposal at 218-262, 310-338, and 408-458 of
  `quickDiffDecorator.ts`; and only `QuickDiffEditorController` ID/get/dispose
  at 481-487 and 763-766 of `quickDiffWidget.ts`. Peek behavior, actions,
  provider menus, active-editor counters, and dynamic stylesheet policy are
  excluded.
- **U10 — feedback input ownership:**
  `AgentFeedbackEditorInputContribution` ID/constant/fields/constructor at
  244-340, lazy widget owner at 350-366, visible-listener release at 502-517,
  gutter-owner reset at 606-616, complete widget-listener registration at
  630-745, typed action lookup at 902-907, disposal at 876-884, and registration
  at 911. Feedback submission, positioning, selection, and hover-glyph behavior
  are excluded siblings.
- **U11 — feedback widget ownership:**
  `AgentFeedbackEditorWidgetContribution` ID/fields/constructor at 1034-1091,
  widget construction/listener ownership at 1102-1150, widget teardown and
  focus-draft capture at 1271-1308, and registration at 1311. Session mapping,
  navigation, grouping policy, and comment behavior are excluded siblings.

The original parent-plan premise that agent feedback was a local feature with
no upstream class is false at the pinned oracle. Both upstream classes exist
and are registered `Eventually`; U10 and U11 replace that premise for this
gate.

The quick-diff mapping is also intentionally non-identity-based:

- upstream `QuickDiffEditorController` has id `editor.contrib.quickdiff` and is
  registered `AfterFirstRender`; it owns the peek/gutter-action controller and
  is not the local contribution;
- local `quickDiff.decorator` is an eager per-viewer reduction of upstream
  `QuickDiffWorkbenchController` plus `QuickDiffDecorator`;
- the two locally cited quick-diff files are byte-identical between the
  previously cited source state and the current oracle
  (`git diff --quiet` returned 0), so the mapping can be safely repinned without
  source drift.

## Manifest and counting rule

The manifest is ordered as shown. Its canonical SHA-256 over tab-separated
`source path`, `wc -l`, and file SHA-256 rows is
`c4479c52556cea78880fd292ec196314c9940fb887379880879498bdc7cb0339`.
The eleven physical files contain **9,788 lines**; only the closed clusters
above contribute ledger atoms.

| Unit | Pinned source | wc -l | SHA-256 |
|---|---|---:|---|
| U01 | `src/vs/editor/browser/widget/codeEditor/codeEditorContributions.ts` | 165 | `3cd98c20ffa0e0f691c38ecd30723240ee91536e2a542bde83e65c2d412ebb99` |
| U02 | `src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts` | 2559 | `18dd294ed185a29c590df75656f18f27d0cefc8d4d778559db946d447130e5d8` |
| U03 | `src/vs/editor/common/editorCommon.ts` | 783 | `86e64d099b9add7e762ad30623a21d859498b23cce4cd03ce20451e76de342ee` |
| U04 | `src/vs/editor/browser/editorExtensions.ts` | 726 | `16dd965e131283e37f0fbe6a431825c8f6d8f0de8f9e182ff2dfd02c16af9136` |
| U05 | `src/vs/editor/contrib/hover/browser/contentHoverController.ts` | 416 | `2e811bcc9ca11606040a9cc127ab178eb29d7be58e6655e4a619e25534f77592` |
| U06 | `src/vs/editor/contrib/folding/browser/folding.ts` | 1331 | `e5969d3047ef640f9b942ed5022686c1b2ad3b62174ff799422256b6a8757b77` |
| U07 | `src/vs/workbench/contrib/scm/browser/quickDiff.contribution.ts` | 116 | `5b9008986e9ce334d012a4f7db304f662adae0a0006d17722c75919051fb92e8` |
| U08 | `src/vs/workbench/contrib/scm/browser/quickDiffDecorator.ts` | 459 | `7cf7189753da7916e4e33f7fa7d27d7349e7ec231b63f2d5c7416082bc85b829` |
| U09 | `src/vs/workbench/contrib/scm/browser/quickDiffWidget.ts` | 1011 | `32e4152a885768bc543f263439f27ce2ffebc6754de12eaaaf7dec7e21906c86` |
| U10 | `src/vs/sessions/contrib/agentFeedback/browser/agentFeedbackEditorInputContribution.ts` | 911 | `66ca2ed32c65f1377f96b0e6ccda11ee1b7897268bb0ed90520c3b8139e05e28` |
| U11 | `src/vs/sessions/contrib/agentFeedback/browser/agentFeedbackEditorWidgetContribution.ts` | 1311 | `183bc5f0bd81821efc4e009be00190c421db2e24ab7a6cca0abc71edaab537b0` |

One row represents one scoped member/field, semantic constant, behavior-changing
branch, early exit, or independently owned acquisition/release atom. A member
row does not subsume its branches or owned disposables. Ordinary immutable
locals, loop mechanics, final returns, TypeScript casts, and public aliases of
an already-counted owned emitter are not separate atoms. Every row ends in
`PORTED`, `TESTED`, `PASS`, `DEFERRED (reason)`, or `N-A (reason)`.

## Exact audit totals

The final ledger has **567 rows**: **136 `PORTED`**, **161 `TESTED`**,
**143 `DEFERRED (reason)`**, and **127 `N-A (reason)`**. No row is left at
`PASS` or an unterminated status.

By atom kind, the inventory contains **202 members**, **27 constants**,
**191 lifetime atoms**, **125 branches**, and **22 early exits**. By source
unit it contains U01 **55**, U02 **83**, U03 **4**, U04 **28**, U05 **52**,
U06 **92**, U07 **2**, U08 **102**, U09 **6**, U10 **92**, and U11 **51**
rows. These independent partitions both sum to 567.

## Parity ledger

### U01 — complete `codeEditorContributions.ts`

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U01-001 | class `CodeEditorContributions extends Disposable` (`:14-165`) | MEMBER | One editor-lifetime owner for descriptions, live instances, and scheduled handles. | `Viewer.contributions`; `EditorContributionRegistry::instantiate_all` | DEFERRED (the local map owns disposer wrappers while four concrete controllers still live in feature-global maps) |
| U01-002 | `_editor` (`:16`) | MEMBER | Null until `initialize`; borrowed editor identity. | ctor closures receive the concrete `Viewer` directly | PORTED |
| U01-003 | `_instantiationService` (`:17`) | MEMBER | Null until `initialize`; borrowed DI service. | direct typed MoonBit constructors | N-A (the viewer has no DI/instantiation-service seam) |
| U01-004 | `_instances` registered `DisposableMap` (`:22`) | MEMBER | Sole live-instance map; registered so values dispose with the editor. | `Viewer.contributions` | DEFERRED (central entries do not yet contain the actual hover/folding/feedback controller instances) |
| U01-005 | `_pending` (`:26`) | MEMBER | Descriptions not yet instantiated, keyed by id. | all local modes instantiate eagerly | DEFERRED (there is no pending-description map) |
| U01-006 | `_finishedInstantiation` (`:30`) | MEMBER | One completion bit per timing mode. | declared modes are retained but ignored | DEFERRED (all local modes instantiate eagerly) |
| U01-007 | constructor (`:32-41`) | MEMBER | Initializes the timing-state owner after `Disposable`. | `editor_registry` singleton plus per-viewer `instantiate_all` | PORTED |
| U01-008 | `Eager=false` initialization (`:37`) | LIFETIME | Eager pass has not run. | eager pass is immediate and has no stored bit | N-A (the local eager-only path cannot be observed before it runs) |
| U01-009 | `AfterFirstRender=false` initialization (`:38`) | LIFETIME | Deferred pass remains pending. | enum value retained only | DEFERRED (no first-render scheduler) |
| U01-010 | `BeforeFirstInteraction=false` initialization (`:39`) | LIFETIME | Deferred pass remains pending. | enum value retained only | DEFERRED (no interaction-triggered scheduler) |
| U01-011 | `Eventually=false` initialization (`:40`) | LIFETIME | Deferred pass remains pending. | enum value retained only | DEFERRED (no idle/eventual scheduler) |
| U01-012 | `initialize` (`:43-77`) | MEMBER | Captures editor/service, seeds descriptions, eagerly constructs, then owns three idle handles. | `EditorContributionRegistry::instantiate_all` called by `Viewer::Viewer` | PORTED |
| U01-013 | store editor (`:44`) | LIFETIME | Editor becomes available before any construction. | `viewer` argument is passed to each ctor | PORTED |
| U01-014 | store instantiation service (`:45`) | LIFETIME | DI becomes available before any construction. | direct construction | N-A (no DI service) |
| U01-015 | duplicate pending-id branch (`:48-51`) | BRANCH | Preserve first description; report and continue. | registry appends and instance-map assignment can overwrite | DEFERRED (no duplicate contribution-id guard) |
| U01-016 | duplicate `continue` (`:50`) | EXIT | Skips replacement of the first description. | no equivalent | DEFERRED (duplicate ids are not rejected) |
| U01-017 | seed pending description (`:52`) | LIFETIME | Description enters the pending owner exactly once. | description stays in process registry; ctor runs eagerly | DEFERRED (no per-editor pending state) |
| U01-018 | eager instantiation call (`:55`) | LIFETIME | Eager entries construct before idle handles are registered. | registration-order loop in `instantiate_all` | TESTED |
| U01-019 | AfterFirstRender idle handle (`:60-62`) | LIFETIME | Registered in the base store; may instantiate early at idle. | none | DEFERRED (all modes are eager) |
| U01-020 | BeforeFirstInteraction idle handle (`:67-69`) | LIFETIME | Registered in the base store; interaction can also force it. | none | DEFERRED (all modes are eager) |
| U01-021 | Eventually idle handle (`:74-76`) | LIFETIME | Registered in the base store with a maximum delay. | none | DEFERRED (all modes are eager) |
| U01-022 | eventual timeout `5000` ms (`:76`) | CONST | Bounds eventual construction even with no idle time. | none | DEFERRED (no idle/eventual timing seam) |
| U01-023 | `saveViewState` (`:79-87`) | MEMBER | Snapshot every already-instantiated contribution that implements the optional method. | `Viewer::save_view_state` saves cursor/view state only | DEFERRED (local contribution entries expose no save callback) |
| U01-024 | iterate `_instances` for save (`:81`) | LIFETIME | Pending contributions are deliberately absent from saved state. | all local entries are eager | N-A (there is no pending/live split) |
| U01-025 | save-method presence branch (`:82-84`) | BRANCH | Store state only for contributions with `saveViewState`. | `EditorContribution` has only `dispose` | DEFERRED (no contribution view-state contract) |
| U01-026 | state keyed by contribution id (`:83`) | LIFETIME | One serializable slot per live id. | no local contribution state map in `ViewerViewState` | DEFERRED (no contribution view-state contract) |
| U01-027 | `restoreViewState` (`:89-95`) | MEMBER | Restore every live contribution from its id slot. | no local contribution restore dispatch | DEFERRED (no contribution view-state contract) |
| U01-028 | restore-method presence branch (`:91-93`) | BRANCH | Call only contributions implementing the optional method. | `EditorContribution` has no restore callback | DEFERRED (no contribution view-state contract) |
| U01-029 | restore state by id (`:92`) | LIFETIME | Missing id passes `undefined` to the contribution. | no local equivalent | DEFERRED (no contribution view-state contract) |
| U01-030 | `get` (`:97-100`) | MEMBER | Explicit lookup first forces pending construction, then returns instance/null. | `Viewer::get_contribution` | TESTED |
| U01-031 | lookup forces `_instantiateById` (`:98`) | LIFETIME | A lazy/deferred contribution can construct earlier on demand. | all local entries already exist | N-A (the local registry is eager-only) |
| U01-032 | missing-instance null fallback (`:99`) | BRANCH | Unknown or failed ids return null. | `Map::get` returns `None` | TESTED |
| U01-033 | test-only `set` (`:105-107`) | MEMBER | Injects an already-live instance into the disposable map. | tests construct real viewers/registries | N-A (no test-only instance injection seam is required) |
| U01-034 | `onBeforeInteractionEvent` (`:109-112`) | MEMBER | Forces the interaction timing class before delivering the event. | no interaction timing pass | DEFERRED (all contributions instantiate eagerly) |
| U01-035 | `onAfterModelAttached` (`:114-118`) | MEMBER | Returns a caller-owned idle handle for the new model attachment. | no attach-scoped contribution handle | DEFERRED (all contributions instantiate eagerly) |
| U01-036 | optional editor DOM lookup (`:115`) | BRANCH | Tolerates an uninitialized/null editor while choosing a window. | viewer registry finishes synchronously in its constructor | N-A (lookup cannot precede initialization) |
| U01-037 | attach delay `50` ms (`:117`) | CONST | Latest AfterFirstRender construction after model attach. | no timing seam | DEFERRED (no first-render scheduler) |
| U01-038 | `_instantiateSome` (`:120-131`) | MEMBER | Idempotently completes one timing class in pending-order. | registration-order eager loop | DEFERRED (no timing-class state) |
| U01-039 | already-finished branch (`:121-124`) | BRANCH | Prevents a second scan/construction pass. | no repeated timing trigger seam | N-A (single synchronous construction has no finished-state branch) |
| U01-040 | already-finished return (`:123`) | EXIT | Leaves pending map untouched on repeated triggers. | no repeated trigger seam | N-A (single synchronous construction pass) |
| U01-041 | mark timing class finished (`:125`) | LIFETIME | Bit changes before any constructors run, preventing reentrancy. | no timing bit | DEFERRED (eager-only construction has no reentrant timing pass) |
| U01-042 | instantiate matching snapshot (`:127-130`) | LIFETIME | Finds then constructs each matching pending id in map order. | `instantiate_all` loops process registration order | PORTED |
| U01-043 | `_findPendingContributionsByInstantiation` (`:133-141`) | MEMBER | Produces an ordered snapshot of matching pending descriptions. | no pending map | DEFERRED (all descriptions are constructed eagerly) |
| U01-044 | instantiation-mode equality branch (`:136-138`) | BRANCH | Includes only the requested mode. | mode is carried but ignored | DEFERRED (mode does not switch construction timing) |
| U01-045 | `_instantiateById` (`:143-164`) | MEMBER | Remove-before-create, construct once, retain or report failure. | `(description.ctor)(viewer)` then `instances.set` | PORTED |
| U01-046 | missing-description branch (`:145-147`) | BRANCH | Already-live/unknown id is a no-op. | all registered ids already materialized | N-A (no pending lookup path) |
| U01-047 | missing-description return (`:146`) | EXIT | Prevents duplicate construction. | one `instantiate_all` call per viewer | TESTED |
| U01-048 | delete pending before create (`:149`) | LIFETIME | Reentrant lookup cannot construct the same id twice. | no pending state; synchronous loop | DEFERRED (no explicit reentrancy guard) |
| U01-049 | uninitialized editor/service branch (`:151-153`) | BRANCH | Reject construction before `initialize`. | construction is inside `Viewer::Viewer` after field setup | N-A (the ctor cannot be invoked before initialization) |
| U01-050 | uninitialized throw (`:152`) | EXIT | Stops construction with a diagnostic. | MoonBit ctor closure is not independently callable | N-A (no uninitialized API seam) |
| U01-051 | DI `createInstance` (`:156`) | LIFETIME | Creates the concrete contribution with editor plus injected services. | direct typed ctor closure | N-A (MoonBit dependencies are closed over or passed directly) |
| U01-052 | store actual instance (`:157`) | LIFETIME | The one central map now owns the concrete object. | central map currently stores only `{id, dispose}` | DEFERRED (Milestones B-E must store the concrete enum variant here) |
| U01-053 | non-eager restore-method warning branch (`:158-160`) | BRANCH | Warns when stateful contribution timing violates the eager-only state contract. | no save/restore methods | N-A (local contributions cannot expose view-state callbacks) |
| U01-054 | constructor catch (`:161-163`) | BRANCH | Reports one failed contribution without aborting later construction. | ctor closures are non-raising | N-A (MoonBit type signature excludes constructor errors) |
| U01-055 | inherited/base disposal (`:14,22,60-76`) | LIFETIME | Dispose live instances and registered idle handles through the base store exactly once. | `Viewer::dispose` fires `did_dispose`, invokes every entry, then clears the map | TESTED |

### U02 — bounded `codeEditorWidget.ts` integration clusters

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U02-001 | `_contributions` (`:79`) | MEMBER | Register one `CodeEditorContributions` in the widget lifetime store before interaction emitters. | `Viewer.contributions` | DEFERRED (the local entries are not yet the sole concrete-instance owners) |
| U02-002 | `_onDidAttemptReadOnlyEdit` (`:123`) | MEMBER | Registered `InteractionEmitter` forces BeforeFirstInteraction before delivery. | readonly edit event is absent | N-A (readonly Viewer has no attempted-edit event) |
| U02-003 | `_onWillType` (`:137`) | MEMBER | Interaction-triggered emitter. | no typing path | N-A (readonly Viewer has no type event) |
| U02-004 | `_onDidType` (`:140`) | MEMBER | Interaction-triggered emitter. | no typing path | N-A (readonly Viewer has no type event) |
| U02-005 | `_onDidCompositionStart` (`:143`) | MEMBER | Interaction-triggered emitter. | no composition edit path | N-A (readonly Viewer has no composition event) |
| U02-006 | `_onDidCompositionEnd` (`:146`) | MEMBER | Interaction-triggered emitter. | no composition edit path | N-A (readonly Viewer has no composition event) |
| U02-007 | `_onDidPaste` (`:149`) | MEMBER | Interaction-triggered emitter. | no paste path | N-A (readonly Viewer has no paste event) |
| U02-008 | `_onWillCopy` (`:152`) | MEMBER | Interaction-triggered emitter before copy. | root copy callback only | DEFERRED (copy is not routed through contribution timing) |
| U02-009 | `_onWillCut` (`:155`) | MEMBER | Interaction-triggered emitter. | no cut path | N-A (readonly Viewer has no cut event) |
| U02-010 | `_onWillPaste` (`:158`) | MEMBER | Interaction-triggered emitter. | no paste path | N-A (readonly Viewer has no paste event) |
| U02-011 | `_onMouseUp` (`:161`) | MEMBER | Interaction-triggered emitter. | `Viewer.did_mouse_up` | N-A (all local contributions exist before any mouse event) |
| U02-012 | `_onMouseDown` (`:164`) | MEMBER | Interaction-triggered emitter. | `Viewer.did_mouse_down` | N-A (all local contributions exist before any mouse event) |
| U02-013 | `_onMouseDrag` (`:167`) | MEMBER | Interaction-triggered emitter. | root drag path | N-A (all local contributions are eager) |
| U02-014 | `_onMouseDrop` (`:170`) | MEMBER | Interaction-triggered emitter. | no contribution timing | N-A (all local contributions are eager) |
| U02-015 | `_onMouseDropCanceled` (`:173`) | MEMBER | Interaction-triggered emitter. | no contribution timing | N-A (all local contributions are eager) |
| U02-016 | `_onDropIntoEditor` (`:176`) | MEMBER | Interaction-triggered emitter. | no editable drop path | N-A (readonly Viewer has no drop-into-editor edit) |
| U02-017 | `_onContextMenu` (`:179`) | MEMBER | Interaction-triggered emitter. | no context-menu service event | DEFERRED (context-menu interaction is not exposed) |
| U02-018 | `_onMouseMove` (`:182`) | MEMBER | Interaction-triggered emitter. | `Viewer.did_mouse_move` | N-A (all local contributions are eager) |
| U02-019 | `_onMouseLeave` (`:185`) | MEMBER | Interaction-triggered emitter. | `Viewer.did_mouse_leave` | N-A (all local contributions are eager) |
| U02-020 | `_onMouseWheel` (`:188`) | MEMBER | Interaction-triggered emitter. | scroll events | N-A (all local contributions are eager) |
| U02-021 | `_onKeyUp` (`:191`) | MEMBER | Interaction-triggered emitter. | root key path | N-A (all local contributions are eager) |
| U02-022 | `_onKeyDown` (`:194`) | MEMBER | Interaction-triggered emitter. | registry key dispatch | N-A (all local contributions are eager) |
| U02-023 | `_contributionsDisposable` (`:239`) | MEMBER | Owns only the current model attachment's AfterFirstRender idle handle. | no attach-scoped contribution handle | DEFERRED (all local modes are eager) |
| U02-024 | constructor contribution selection branch (`:338-343`) | BRANCH | Use caller-supplied descriptions when the option is an array; otherwise copy the global registry. | one closed process registry | N-A (Viewer construction exposes no custom contribution-list option) |
| U02-025 | supplied contribution array (`:339-340`) | LIFETIME | Preserve caller array order and contents. | no injection seam | N-A (closed statically registered product) |
| U02-026 | global registry contribution list (`:341-343`) | LIFETIME | Snapshot process descriptions for this editor. | lazy `editor_registry()` singleton | PORTED |
| U02-027 | initialize contribution owner (`:344`) | LIFETIME | Run after editor services/model field/widget maps exist and before actions/DOM observers. | `viewer.contributions = editor_registry().instantiate_all(viewer)` after Viewer field setup | TESTED |
| U02-028 | `dispose` (`:426-439`) | MEMBER | Editor unregister/registry cleanup/model teardown/event/base-store disposal in fixed order. | `Viewer::dispose` | TESTED |
| U02-029 | unregister code editor (`:427`) | LIFETIME | External editor service stops exposing the widget first. | no global code-editor service | N-A (no external editor-service registry) |
| U02-030 | clear actions (`:429`) | LIFETIME | Drop action wrappers before contribution/base disposal. | process command registry is not per viewer | N-A (commands are immutable process descriptions) |
| U02-031 | clear content widgets (`:430`) | LIFETIME | Drop widget registration map before model/contributions. | Viewer widget teardown | PORTED |
| U02-032 | clear overlay widgets (`:431`) | LIFETIME | Drop widget registration map before model/contributions. | `Viewer.overlay_widgets.clear()` | PORTED |
| U02-033 | remove decoration types (`:433`) | LIFETIME | Clean widget-owned decoration registrations before model detach. | owner-id decoration sweep | PORTED |
| U02-034 | detach model then post-clean (`:434`) | LIFETIME | Per-model owners release before dispose event; owner decorations clean after detach. | `Viewer::detach_model` then owner-id sweep | TESTED |
| U02-035 | fire `onDidDispose` (`:436`) | LIFETIME | Observers run after model teardown but while contributions/base store are alive. | `Viewer.did_dispose.fire(())` | TESTED |
| U02-036 | `super.dispose()` (`:438`) | LIFETIME | Disposes registered `_contributions` after the dispose event. | explicit contribution loop after `did_dispose` | TESTED |
| U02-037 | `setModel` (`:506-548`) | MEMBER | Atomic update scope around same-model guards, detach/attach, events, cleanup, and new attach handle. | `Viewer::set_model` / `detach_model` | TESTED |
| U02-038 | `_beginUpdate` / finally `_endUpdate` (`:508,545-547`) | LIFETIME | Always closes update batching, including early returns. | `Viewer` event batching | TESTED |
| U02-039 | `(null,null)` same-model branch (`:510-513`) | BRANCH | No detach, attach, events, or new contribution handle. | no-model no-op guard | TESTED |
| U02-040 | `(null,null)` return (`:512`) | EXIT | Leaves current contribution lifetime unchanged. | same | TESTED |
| U02-041 | identical model branch (`:514-517`) | BRANCH | Physical identity suppresses the whole swap. | same-model identity guard | TESTED |
| U02-042 | identical model return (`:516`) | EXIT | Contributions and model-scoped state remain untouched. | same | TESTED |
| U02-043 | old/new URI optional projections (`:519-522`) | BRANCH | Event uses null for either absent side. | `ModelChangedEvent` old/new option projections | TESTED |
| U02-044 | fire will-change before detach (`:523`) | LIFETIME | Observers still see the outgoing model. | Viewer will-change/model detach ordering | PORTED |
| U02-045 | capture text focus (`:525`) | LIFETIME | Focus is restored only if the new editor has a model. | Viewer focus snapshot | PORTED |
| U02-046 | detach then attach (`:526-527`) | LIFETIME | Old attach handle/model data release before new model owners construct. | `detach_model`; attach pipeline | TESTED |
| U02-047 | new-model presence branch (`:528-538`) | BRANCH | Restore text focus with a new model; otherwise clear text/widget focus. | local model-present branch | TESTED |
| U02-048 | prior-focus branch (`:530-532`) | BRANCH | Focus new view only when old view had text focus. | local focus restoration | TESTED |
| U02-049 | no-model focus clearing (`:533-538`) | LIFETIME | Both focus emitters become false after removal. | local focus reset | PORTED |
| U02-050 | decoration cleanup then did-change (`:540-541`) | LIFETIME | Owner-type cleanup precedes observers of the new model. | local swap cleanup/event order | PORTED |
| U02-051 | post-detach cleanup (`:542`) | LIFETIME | Outgoing owner decorations are removed after did-change. | owner-id sweep | TESTED |
| U02-052 | replace attach-scoped contribution handle (`:544`) | LIFETIME | `_detachModel` cleared the old handle; store the new 50-ms handle last. | no handle | DEFERRED (no AfterFirstRender timing pass) |
| U02-053 | `saveViewState` (`:1038-1050`) | MEMBER | Reject no-model, then snapshot contributions, cursor, and view in source order. | `Viewer::save_view_state` | PORTED |
| U02-054 | save no-model branch (`:1039-1041`) | BRANCH | Null result; no contribution callback. | local `None` result | TESTED |
| U02-055 | save no-model return (`:1040`) | EXIT | Skips all state reads. | same | TESTED |
| U02-056 | contribution snapshot first (`:1042`) | LIFETIME | Contribution state is captured before cursor/view state. | absent | DEFERRED (no contribution save callbacks) |
| U02-057 | cursor then view snapshot (`:1043-1044`) | LIFETIME | Preserve cursor-before-layout order. | local cursor/view state | TESTED |
| U02-058 | contribution slot in returned state (`:1048`) | LIFETIME | Serialized state carries the id-keyed contribution object. | `ViewerViewState` has no contribution slot | DEFERRED (no contribution view-state contract) |
| U02-059 | `restoreViewState` (`:1052-1072`) | MEMBER | Restore only a real view and a structurally complete state. | `Viewer::restore_view_state` | PORTED |
| U02-060 | missing model or unreal view branch (`:1053-1055`) | BRANCH | Skip all cursor/contribution/view restore. | local missing-view guard | TESTED |
| U02-061 | missing model/unreal view return (`:1054`) | EXIT | No partial restore. | same | TESTED |
| U02-062 | complete-state branch (`:1057-1071`) | BRANCH | Requires state plus cursor and view components. | local optional state branch | TESTED |
| U02-063 | cursor-array branch (`:1059-1066`) | BRANCH | Current array form vs legacy single cursor form. | local `ViewerViewState` is statically shaped | N-A (MoonBit state cannot carry the legacy structural shape) |
| U02-064 | nonempty cursor-array branch (`:1060-1062`) | BRANCH | Empty selection array does not restore cursors. | local state validation | PORTED |
| U02-065 | legacy cursor compatibility (`:1063-1066`) | LIFETIME | Wrap one old cursor in an array. | no dynamic legacy input | N-A (statically typed state) |
| U02-066 | restore contributions (`:1068`) | LIFETIME | Runs after cursor restore but before reduced view state. | absent | DEFERRED (no contribution restore callbacks) |
| U02-067 | reduce then restore view (`:1069-1070`) | LIFETIME | View layout restores after contribution state. | local view-state restore | TESTED |
| U02-068 | `getContribution` (`:1086-1088`) | MEMBER | Public typed view over central id lookup. | `Viewer::get_contribution` | DEFERRED (the current return type is an untyped `{id,dispose}` wrapper, not a concrete controller view) |
| U02-069 | central lookup delegation (`:1087`) | LIFETIME | No second store; cast only narrows the central object. | current feature accessors consult four second stores | DEFERRED (typed accessors must match the central enum entry) |
| U02-070 | `_detachModel` (`:2012-2032`) | MEMBER | Release contribution handle before any model guard, then dispose/remove per-model owners. | `Viewer::detach_model` | PORTED |
| U02-071 | optional contribution-handle disposal (`:2013`) | BRANCH | Dispose the current attach handle if present. | no handle | DEFERRED (no AfterFirstRender timing pass) |
| U02-072 | clear contribution handle (`:2014`) | LIFETIME | Field becomes undefined even when no model is attached. | no field | N-A (no attach-scoped handle) |
| U02-073 | missing-model branch (`:2015-2017`) | BRANCH | Handle is already released; return null before model/DOM work. | local missing-model guard | TESTED |
| U02-074 | missing-model return (`:2016`) | EXIT | No per-model disposal. | same | TESTED |
| U02-075 | retain model and optional real-view DOM (`:2018-2019`) | LIFETIME | Capture return model/root before disposing ModelData. | local `ModelData` detach | TESTED |
| U02-076 | dispose and clear ModelData (`:2021-2022`) | LIFETIME | Per-model listeners/view/view-model release before DOM removal. | `ModelData::dispose`; clear field | TESTED |
| U02-077 | remove mode attribute (`:2024`) | LIFETIME | Clear model-specific DOM metadata. | local root/model cleanup | PORTED |
| U02-078 | contained view-root branch (`:2025-2027`) | BRANCH | Remove only the captured real-view node still owned by the editor root. | `remove_element_if_contained` | TESTED |
| U02-079 | contained banner branch (`:2028-2030`) | BRANCH | Remove optional banner only when still under the root. | no banner | N-A (Viewer has no banner owner) |
| U02-080 | `InteractionEmitter` class (`:2187-2200`) | MEMBER | Retains the central contribution manager and delivery queue. | ordinary emitters plus eager registry | N-A (no lazy BeforeFirstInteraction mode) |
| U02-081 | `InteractionEmitter` constructor (`:2189-2194`) | MEMBER | Borrow contribution manager; initialize base emitter. | no wrapper class | N-A (all modes are eager) |
| U02-082 | `InteractionEmitter.fire` (`:2196-2199`) | MEMBER | Instantiate BeforeFirstInteraction contributions before observer delivery. | events deliver directly | N-A (all local entries already exist) |
| U02-083 | force-before-super ordering (`:2197-2198`) | LIFETIME | Constructor side effects complete before any event listener runs. | eager construction precedes all external event registration/use | TESTED |

### U03 — `IEditorContribution` contract in `editorCommon.ts`

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U03-001 | `IEditorContribution` (`:583-596`) | MEMBER | Per-editor object created and disposed with its editor. | `EditorContribution` plus target closed `EditorContributionInstance` enum | DEFERRED (the current wrapper does not hold the concrete controller) |
| U03-002 | `dispose()` (`:587`) | MEMBER | Required lifetime release. | `EditorContribution.dispose` closure | TESTED |
| U03-003 | optional `saveViewState()` (`:591`) | MEMBER | Contribution-owned serializable state. | no callback | DEFERRED (local contribution view-state is intentionally absent) |
| U03-004 | optional `restoreViewState(state)` (`:595`) | MEMBER | Restore the contribution's id-keyed state. | no callback | DEFERRED (local contribution view-state is intentionally absent) |

### U04 — contribution contracts in `editorExtensions.ts`

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U04-001 | `EditorContributionCtor` (`:31`) | MEMBER | Constructor signature receives editor and injected services. | `(Viewer) -> EditorContribution` closure | PORTED |
| U04-002 | `EditorContributionInstantiation` (`:34-65`) | MEMBER | Closed timing mode contract. | same five-case enum | PORTED |
| U04-003 | `Eager` (`:39`) | CONST | Construct during editor initialization; stateful contributions must use it. | `Eager` | TESTED |
| U04-004 | `AfterFirstRender` (`:46`) | CONST | By first-render+50ms, explicit get, or earlier idle. | enum value retained | DEFERRED (instantiated eagerly, no first-render timing) |
| U04-005 | AfterFirstRender `50ms` contract (`:42`) | CONST | Maximum post-attach delay. | none | DEFERRED (no timing seam) |
| U04-006 | `BeforeFirstInteraction` (`:53`) | CONST | Before interaction event, explicit get, or earlier idle. | enum value retained | DEFERRED (instantiated eagerly, no interaction timing) |
| U04-007 | `Eventually` (`:59`) | CONST | Idle or at latest 5000ms; explicit get may force. | enum value retained | DEFERRED (instantiated eagerly, no eventual timing) |
| U04-008 | Eventually `5000ms` contract (`:56`) | CONST | Upper time bound without idle. | none | DEFERRED (no idle scheduler) |
| U04-009 | `Lazy` (`:64`) | CONST | Construct only on explicit get. | enum value retained | DEFERRED (instantiated eagerly) |
| U04-010 | `IEditorContributionDescription` (`:67-71`) | MEMBER | Process description, not per-editor live state. | `EditorContributionDescription` | PORTED |
| U04-011 | description `id` (`:68`) | MEMBER | Registry/instance lookup key. | `id : String` | PORTED |
| U04-012 | description `ctor` (`:69`) | MEMBER | Factory for one editor's actual instance. | `ctor : (Viewer) -> EditorContribution` | DEFERRED (factory returns a disposer wrapper while concrete controllers enter feature-global maps) |
| U04-013 | description `instantiation` (`:70`) | MEMBER | Declared timing mode. | same field | PORTED |
| U04-014 | public `registerEditorContribution` (`:552-554`) | MEMBER | Adds a process description; lifetime is bound to one code editor. | `register_editor_contribution` | PORTED |
| U04-015 | public facade delegates to singleton (`:553`) | LIFETIME | Exactly one global description registry receives every call. | lazy `editor_registry_holder` singleton | TESTED |
| U04-016 | `EditorExtensionsRegistry.getEditorContributions` (`:574-576`) | MEMBER | Public snapshot of registered editor descriptions. | `editor_registry().contributions` consumed internally | PORTED |
| U04-017 | getter delegates to singleton (`:575`) | LIFETIME | Does not create per-editor state. | same | PORTED |
| U04-018 | `getSomeEditorContributions` (`:578-580`) | MEMBER | Filter global descriptions by requested ids. | no selective construction surface | N-A (closed Viewer always constructs the full static set) |
| U04-019 | requested-id membership branch (`:579`) | BRANCH | Keep descriptions whose id occurs at index >=0. | no selective list | N-A (no partial contribution option) |
| U04-020 | `EditorContributionRegistry` (`:592-610`) | MEMBER | Process owner of descriptions; distinct from per-editor instances. | `EditorContributionRegistry` | TESTED |
| U04-021 | static `INSTANCE` (`:594`) | MEMBER | One eagerly allocated process registry. | one lazily initialized holder | PORTED |
| U04-022 | `editorContributions` (`:596`) | MEMBER | Registration-order description array. | `contributions` array | TESTED |
| U04-023 | empty constructor (`:601-602`) | MEMBER | Field initializers establish empty registry. | struct literal in `editor_registry()` | PORTED |
| U04-024 | registry `registerEditorContribution` (`:604-606`) | MEMBER | Append id/ctor/mode without constructing editor state. | `register_editor_contribution` | PORTED |
| U04-025 | append description (`:605`) | LIFETIME | Registration order is preserved; duplicate ids are not rejected here. | `self.contributions.push` | PORTED |
| U04-026 | registry `getEditorContributions` (`:608-610`) | MEMBER | Return a shallow copy so callers cannot mutate registry order. | array is private and consumed only by `instantiate_all` | N-A (no external getter or mutable alias crosses the package) |
| U04-027 | `slice(0)` snapshot (`:609`) | LIFETIME | Copy begins at index zero. | direct private iteration | N-A (MoonBit array never leaves registry package) |
| U04-028 | platform registry registration (`:639`) | LIFETIME | Publish the singleton under `editor.contributions`. | explicit `build_editor_registry` equivalent | N-A (MoonBit has no platform extension registry/import side effects) |

### U05 — bounded `ContentHoverController` ownership cluster

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U05-001 | `ContentHoverController extends Disposable` (`:39`) | MEMBER | One editor-lifetime hover controller. | `@hover_browser.ContentHoverController` | DEFERRED (the concrete controller is stored in process-global `instances`, not the central entry) |
| U05-002 | `_onHoverContentsChanged` (`:41`) | MEMBER | Registered emitter released by `super.dispose`. | Viewer hover-resolution/status emitter | DEFERRED (no exact content-change event owner) |
| U05-003 | static `ID` (`:44`) | CONST | Central lookup key `editor.contrib.contentHover`. | identical registration id | TESTED |
| U05-004 | `shouldKeepOpenOnEditorMouseMoveOrLeave` (`:46`) | MEMBER | Mutable editor-lifetime interaction state, initially false. | `hover_keep_open` | TESTED |
| U05-005 | `_listenersStore` (`:48`) | MEMBER | Clearable hover-option/model/input listeners; manually disposed. | root event dispatch plus contribution/viewer listener owners | DEFERRED (listeners are not owned by the concrete controller) |
| U05-006 | `_contentWidget` (`:50`) | MEMBER | Lazily created controller-owned widget, disposed with controller. | `Viewer.content_hover_widget` | DEFERRED (widget is owned separately by Viewer) |
| U05-007 | `_mouseMoveEvent` (`:52`) | MEMBER | Latest deferred mouse input; cleared on cancel. | `hover_pending_target` plus recorded pointer/modifiers | TESTED |
| U05-008 | `_reactToEditorMouseMoveRunner` (`:53`) | MEMBER | Registered zero-delay scheduler; cancelable and editor-lifetime. | `hover_react_timer`/token | TESTED |
| U05-009 | `_hoverSettings` (`:55`) | MEMBER | Snapshot of hover enabled/sticky/hidingDelay. | `hover_settings` | TESTED |
| U05-010 | `_isMouseDown=false` (`:56`) | MEMBER | Tracks accepted down/up pair. | `hover_is_mouse_down` | TESTED |
| U05-011 | `_ignoreMouseEvents=false` (`:58`) | MEMBER | Context-menu suppression state. | `hover_ignore_mouse_events` | TESTED |
| U05-012 | borrowed `_editor` (`:61`) | MEMBER | Event source, option source, and widget host; never disposed. | root `Viewer::` glue | PORTED |
| U05-013 | borrowed `_instantiationService` (`:63`) | MEMBER | Creates lazy widget. | direct `ContentHoverWidget` construction | N-A (no DI service) |
| U05-014 | borrowed `_keybindingService` (`:64`) | MEMBER | Resolves hover-preserving keybindings. | root contribution command/keybinding registry | PORTED |
| U05-015 | constructor (`:60-88`) | MEMBER | Register scheduler/context/config owners, hook editor listeners, leave widget lazy. | `ContentHoverController::attach` plus root registration/wiring | DEFERRED (construction also inserts the controller into a second global map) |
| U05-016 | register `RunOnceScheduler` (`:67-73`) | LIFETIME | Base store owns the deferred reaction scheduler. | clearable `hover_react_timer` owned by controller | TESTED |
| U05-017 | scheduler delay `0` (`:72`) | CONST | Callback runs on next turn unless canceled/rescheduled. | host timeout scheduler | PORTED |
| U05-018 | scheduler pending-event branch (`:69-71`) | BRANCH | React only when a latest mouse event still exists. | pending flag/target plus generation guard | TESTED |
| U05-019 | context-menu-show subscription (`:74-77`) | LIFETIME | Hide hover then suppress mouse input. | suppression field exists | DEFERRED (no context-menu service event is wired) |
| U05-020 | context-menu-show state order (`:75-76`) | LIFETIME | Hide before setting ignore=true. | tests can set suppression, but no source event | DEFERRED (missing context-menu event seam) |
| U05-021 | context-menu-hide subscription (`:78-80`) | LIFETIME | Resume mouse handling. | field exists | DEFERRED (missing context-menu event seam) |
| U05-022 | initial `_hookListeners` (`:81`) | LIFETIME | Snapshot settings before config subscription is installed. | root event handlers plus option initialization | PORTED |
| U05-023 | configuration subscription (`:82-87`) | LIFETIME | Rebuild clearable input/model listeners only when hover option changes. | `Viewer::update_options` updates hover settings/behavior | PORTED |
| U05-024 | hover-option-changed branch (`:83-86`) | BRANCH | Ignore unrelated configuration events. | option-diff branch | TESTED |
| U05-025 | unhook-before-rehook ordering (`:84-85`) | LIFETIME | No duplicate listeners survive option changes. | root event sources remain singular for Viewer lifetime | N-A (listeners are global Viewer event dispatch, not option-scoped registrations) |
| U05-026 | static `get` (`:90-92`) | MEMBER | Typed view over the editor's central map. | `ContentHoverController::get(editor_id)` | DEFERRED (lookup consults feature-global `instances`) |
| U05-027 | get delegates by `ID` (`:91`) | LIFETIME | No feature-owned instance store in source. | global map lookup by `Viewer::get_id()` | DEFERRED (must become a root typed central-map accessor) |
| U05-028 | `_hookListeners` (`:94-112`) | MEMBER | Refresh settings, cancel disabled hover, then own eight editor listeners. | root hover event/model glue | PORTED |
| U05-029 | hover-setting snapshot (`:95-100`) | LIFETIME | Copy enabled/sticky/hidingDelay together. | `HoverSettings` | TESTED |
| U05-030 | hover-disabled branch (`:101-103`) | BRANCH | Cancel pending scheduler and hide before registering listeners. | local option change cancellation | TESTED |
| U05-031 | mouse-down listener (`:104`) | LIFETIME | Clearable listener retained by `_listenersStore`. | root `on_mouse_down` dispatch | PORTED |
| U05-032 | mouse-up listener (`:105`) | LIFETIME | Clearable listener retained by `_listenersStore`. | root `on_mouse_up` dispatch | PORTED |
| U05-033 | mouse-move listener (`:106`) | LIFETIME | Clearable listener retained by `_listenersStore`. | root `on_mouse_move` dispatch | PORTED |
| U05-034 | key-down listener (`:107`) | LIFETIME | Clearable listener retained by `_listenersStore`. | root keybinding dispatch | PORTED |
| U05-035 | mouse-leave listener (`:108`) | LIFETIME | Clearable listener retained by `_listenersStore`. | root `on_mouse_leave` dispatch | PORTED |
| U05-036 | model-change listener (`:109`) | LIFETIME | Cancel scheduler and hide on every model swap. | `Viewer::set_model` hover reset | TESTED |
| U05-037 | model-content listener (`:110`) | LIFETIME | Cancel scheduler without hiding current content. | content invalidation cancellation | TESTED |
| U05-038 | scroll listener (`:111`) | LIFETIME | Hide only for axis changes, respecting ignore state. | scroll handler | TESTED |
| U05-039 | `_unhookListeners` (`:114-116`) | MEMBER | Clear every option-scoped editor listener. | no controller-owned equivalent | DEFERRED (listener ownership remains outside the concrete controller) |
| U05-040 | listener-store clear (`:115`) | LIFETIME | Dispose listeners but retain reusable store. | no reusable store | DEFERRED (event dispatch uses Viewer-lifetime owners) |
| U05-041 | `_cancelSchedulerAndHide` (`:118-121`) | MEMBER | Cancel scheduler before hiding widget. | `cancel_hover_react` then hide | TESTED |
| U05-042 | `_cancelScheduler` (`:123-126`) | MEMBER | Drop latest event then cancel scheduled callback. | `cancel_react` | TESTED |
| U05-043 | clear `_mouseMoveEvent` (`:124`) | LIFETIME | A racing callback observes no work. | clear pending target/flag | TESTED |
| U05-044 | cancel runner (`:125`) | LIFETIME | Release pending host timer. | dispose `hover_react_timer` and rotate token | TESTED |
| U05-045 | `_getOrCreateContentWidget` (`:317-323`) | MEMBER | Lazily create one widget and one content-change listener. | Viewer-owned lazy content widget | DEFERRED (widget must be reached/disposed through the controller instance) |
| U05-046 | missing-widget branch (`:318-321`) | BRANCH | Construction/listener registration happens once. | optional Viewer field | TESTED |
| U05-047 | create concrete widget (`:319`) | LIFETIME | Controller retains the created widget. | Viewer retains widget | DEFERRED (wrong owner) |
| U05-048 | widget content-change subscription (`:320`) | LIFETIME | Listener is retained in the same clearable store as editor listeners. | no exact content-change event | DEFERRED (missing event and controller listener owner) |
| U05-049 | `dispose` (`:410-415`) | MEMBER | Base store, option listeners, store object, then optional widget. | contribution detach cancels timers/request and removes global entry; Viewer later tears down widget | DEFERRED (actual owners are split and order differs) |
| U05-050 | `super.dispose()` first (`:411`) | LIFETIME | Release registered scheduler/context/config listeners before manual listener store. | controller timer/request cancellation is explicit in `detach` | PORTED |
| U05-051 | unhook then dispose listener store (`:412-413`) | LIFETIME | Clear contents before permanently disposing the store. | root listener array is disposed by contribution wrapper | DEFERRED (listeners are not controller fields) |
| U05-052 | optional widget disposal (`:414`) | BRANCH | Dispose only if lazy widget was created. | Viewer optional widget cleanup | DEFERRED (widget is not owned by the contribution controller) |

### U06 — bounded `FoldingController` ownership cluster

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U06-001 | `CONTEXT_FOLDING_ENABLED` (`:46`) | CONST | Per-editor context key defaults false. | live `Viewer::folding_enabled` predicate | PORTED |
| U06-002 | `RangeProvider` (`:48-52`) | MEMBER | Computation owner has stable id and mandatory disposal. | `IndentRangeProvider` | PORTED |
| U06-003 | `RangeProvider.id` (`:49`) | MEMBER | Identifies provider in state and replacement. | indent-only provider has no public id | DEFERRED (view-state/provider selection is absent) |
| U06-004 | `RangeProvider.compute` (`:50`) | MEMBER | Asynchronous cancellable range computation. | synchronous `compute()` | DEFERRED (no async folding-provider seam) |
| U06-005 | `RangeProvider.dispose` (`:51`) | MEMBER | Mandatory release on strategy/model/controller replacement. | `IndentRangeProvider::dispose` | TESTED |
| U06-006 | `FoldingController extends Disposable` (`:68`) | MEMBER | One editor-lifetime folding controller with model-scoped sub-store. | `@folding_browser.FoldingController` | DEFERRED (the concrete controller lives in process-global `folding_instances`) |
| U06-007 | static `ID` (`:70`) | CONST | Central lookup key `editor.contrib.folding`. | `FOLDING_CONTROLLER_ID` | TESTED |
| U06-008 | static `get` (`:72-74`) | MEMBER | Typed view over editor central instance map. | `FoldingController::get(editor_id)` | DEFERRED (lookup uses the feature-global map) |
| U06-009 | get delegates by `ID` (`:73`) | LIFETIME | Source owns no second lookup table. | global `folding_instances` lookup | DEFERRED (must become a root central-enum accessor) |
| U06-010 | borrowed `editor` (`:88`) | MEMBER | Event/model/widget host; never disposed. | root `Viewer::` folding glue | PORTED |
| U06-011 | `_isEnabled` (`:89`) | MEMBER | Snapshot of folding option. | `Viewer.options.folding` | TESTED |
| U06-012 | `_useFoldingProviders` (`:90`) | MEMBER | Strategy switch between syntax providers and indentation. | indent-only implementation | DEFERRED (no folding language-provider registry) |
| U06-013 | `_unfoldOnClickAfterEndOfLine` (`:91`) | MEMBER | Click behavior option snapshot. | `ViewerOptions.unfold_on_click_after_end_of_line` | TESTED |
| U06-014 | `_restoringViewState` (`:92`) | MEMBER | Suppresses selection adjustment while applying memento. | no folding view-state restore | DEFERRED (folding memento is absent) |
| U06-015 | `_foldingImportsByDefault` (`:93`) | MEMBER | Option controlling initial import collapse. | no provider kinds/import folding | DEFERRED (indent-only provider has no import kind) |
| U06-016 | `_currentModelHasFoldedImports` (`:94`) | MEMBER | Per-model one-shot import-collapse state. | absent | DEFERRED (no import folding) |
| U06-017 | `foldingDecorationProvider` (`:96`) | MEMBER | Editor-lifetime provider reused across model-scoped folding models. | optional per-model `FoldingDecorationProvider` | PORTED |
| U06-018 | `foldingModel` (`:98`) | MEMBER | Model-scoped owner, null when disabled/detached. | `folding_model` | TESTED |
| U06-019 | `hiddenRangeModel` (`:99`) | MEMBER | Model-scoped hidden-area owner. | `hidden_range_model` | TESTED |
| U06-020 | `rangeProvider` (`:101`) | MEMBER | Lazily chosen model-scoped provider; replaced/disposed on strategy change. | `range_provider` | TESTED |
| U06-021 | `foldingRegionPromise` (`:102`) | MEMBER | Current cancelable provider computation. | none | DEFERRED (folding computation is synchronous) |
| U06-022 | `foldingModelPromise` (`:104`) | MEMBER | Published eventual model result. | immediate folding model option | N-A (synchronous computation returns no promise) |
| U06-023 | `updateScheduler` (`:105`) | MEMBER | Model-scoped debouncing owner. | none | DEFERRED (no folding Delayer) |
| U06-024 | `updateDebounceInfo` (`:106`) | MEMBER | Editor-lifetime adaptive delay state. | none | DEFERRED (no debounce service) |
| U06-025 | `foldingEnabled` (`:108`) | MEMBER | Bound per-editor context key. | live predicate, no stored context key | N-A (no context-key service) |
| U06-026 | `cursorChangedScheduler` (`:109`) | MEMBER | Model-scoped delayed cursor reveal. | synchronous cursor reveal | DEFERRED (no 200-ms scheduler) |
| U06-027 | registered `localToDispose` (`:111`) | MEMBER | Clearable model-scoped store itself owned by controller base store. | `local_to_dispose` plus `clear_local` | DEFERRED (array exists, but its concrete controller is not the central owner) |
| U06-028 | `mouseDownInfo` (`:112`) | MEMBER | Model interaction state cleared with local owners. | `mouse_down_info` | TESTED |
| U06-029 | `_foldingLimitReporter` (`:114`) | MEMBER | Registered editor-lifetime limit reporter. | callback-shaped `FoldingLimitReporter` | PORTED |
| U06-030 | borrowed `contextKeyService` (`:118`) | MEMBER | Owns bound `foldingEnabled`, not disposed by controller. | none | N-A (no context-key service) |
| U06-031 | borrowed `languageConfigurationService` (`:119`) | MEMBER | Used by indentation provider. | language registry passed directly | PORTED |
| U06-032 | borrowed `languageFeaturesService` (`:122`) | MEMBER | Provider registry and provider-change event source. | no folding range providers | DEFERRED (language feature registry has no folding provider contract) |
| U06-033 | constructor (`:116-182`) | MEMBER | Initialize editor state, register editor-lifetime listeners, then build model-scoped owners. | `FoldingController::attach` plus `register_folding_contribution` | DEFERRED (constructor inserts concrete state in a second global map and listeners live in wrapper closure) |
| U06-034 | register limit reporter (`:127`) | LIFETIME | Base store releases reporter with controller. | reporter is value/callback state | N-A (local reporter has no resources) |
| U06-035 | option snapshot (`:129-135`) | LIFETIME | Read folding/strategy/click/import settings before creating any model state. | supported options snapshot; strategy/import omitted | PORTED |
| U06-036 | debounce minimum `200` ms (`:136`) | CONST | Lower bound for adaptive folding recomputation delay. | no debounce | DEFERRED (synchronous computation) |
| U06-037 | initialize model-scoped nullable owners (`:138-145`) | LIFETIME | Model/promise/scheduler/provider/mouse fields all start empty. | local controller option fields start `None` | PORTED |
| U06-038 | create decoration provider (`:147-149`) | LIFETIME | Configure controls/highlights before any folding model uses it. | create/update provider on model attach | PORTED |
| U06-039 | bind/set folding context key (`:150-151`) | LIFETIME | Publish initial enabled state. | live predicate | N-A (no context-key owner) |
| U06-040 | editor model-change subscription (`:153`) | LIFETIME | Controller base store owns model-change callback. | listener array in contribution ctor | DEFERRED (listener is not owned by concrete controller) |
| U06-041 | configuration subscription (`:155-180`) | LIFETIME | Controller base store owns one option-dispatch callback. | root `folding_on_configuration_changed` dispatch | DEFERRED (listener ownership is outside concrete controller) |
| U06-042 | folding-enabled branch (`:156-160`) | BRANCH | Refresh flag/context and rebuild model state. | option branch rebuilds | TESTED |
| U06-043 | maximum-regions branch (`:161-163`) | BRANCH | Rebuild model state when limit changes. | option branch rebuilds | TESTED |
| U06-044 | controls/highlight branch (`:164-169`) | BRANCH | Refresh provider options and rerender without rebuilding. | local provider update | TESTED |
| U06-045 | controls-or-highlight short circuit (`:164`) | BRANCH | Either option triggers the shared update. | equivalent option disjunction | TESTED |
| U06-046 | strategy branch (`:170-173`) | BRANCH | Refresh provider strategy and dispose/recompute current provider. | no strategy switch | DEFERRED (indent-only provider) |
| U06-047 | unfold-after-EOL branch (`:174-176`) | BRANCH | Refresh click behavior without rebuild. | local option read at event time | PORTED |
| U06-048 | fold-imports-default branch (`:177-179`) | BRANCH | Refresh future one-shot import behavior. | absent | DEFERRED (no import folding) |
| U06-049 | initial `onModelChanged` (`:181`) | LIFETIME | Build model-scoped owners only after all editor fields/listeners exist. | trailing `viewer.folding_on_model_changed()` | TESTED |
| U06-050 | `onModelChanged` (`:227-272`) | MEMBER | Clear old model store, validate new model, construct/own all new model resources, then compute. | `Viewer::folding_on_model_changed`; `clear_local` | TESTED |
| U06-051 | clear `localToDispose` first (`:228`) | LIFETIME | Releases prior models/listeners/disposer before inspecting new model. | `controller.clear_local()` | TESTED |
| U06-052 | disabled/missing/too-large branch (`:231-234`) | BRANCH | Leave all model-scoped owners empty. | local guards cover disabled/missing models but not the too-large-tokenization case | DEFERRED (the too-large model axis is absent) |
| U06-053 | invalid-model return (`:233`) | EXIT | No hidden-area/model/listener creation. | local guard return | TESTED |
| U06-054 | reset folded-imports state (`:236`) | LIFETIME | New model has not received default import collapse. | absent | DEFERRED (no import folding) |
| U06-055 | create/own `FoldingModel` (`:237-238`) | LIFETIME | Add model before every dependent owner. | `folding_model`, disposed first by `clear_local` | TESTED |
| U06-056 | create/own `HiddenRangeModel` (`:240-241`) | LIFETIME | Add after FoldingModel so store teardown preserves source insertion order. | `hidden_range_model`, disposed second | TESTED |
| U06-057 | hidden-range listener (`:242`) | LIFETIME | Store callback after both models. | `local_to_dispose` listener | TESTED |
| U06-058 | create/own update `Delayer` (`:244-245`) | LIFETIME | Model-specific adaptive scheduler. | none | DEFERRED (synchronous recomputation) |
| U06-059 | cursor scheduler `200` ms (`:247-248`) | CONST | Model-specific delayed reveal owner. | immediate reveal | DEFERRED (no cursor scheduler) |
| U06-060 | provider-registry change listener (`:249`) | LIFETIME | Reset range provider when registry changes. | none | DEFERRED (no folding provider registry) |
| U06-061 | language-configuration listener (`:250`) | LIFETIME | Reset provider on language/config changes. | option/model glue | PORTED |
| U06-062 | model-content listener (`:251`) | LIFETIME | Notify hidden model then schedule recomputation. | contribution listener recomputes | TESTED |
| U06-063 | cursor listener (`:252`) | LIFETIME | Schedule reveal when cursor enters hidden area. | contribution listener, immediate reveal | PORTED |
| U06-064 | mouse-down listener (`:253`) | LIFETIME | Retain folding gutter interaction callback. | contribution listener | PORTED |
| U06-065 | mouse-up listener (`:254`) | LIFETIME | Retain matching folding gutter callback. | contribution listener | PORTED |
| U06-066 | inline model-store disposer (`:255-270`) | LIFETIME | Last-added cleanup cancels work, nulls fields, and disposes provider. | `clear_local` plus contribution wrapper | PORTED |
| U06-067 | pending-region branch (`:257-260`) | BRANCH | Cancel current computation and null it before other owners. | none | DEFERRED (no async provider promise) |
| U06-068 | scheduler cancel/null (`:261-262`) | LIFETIME | Stop queued recomputation before clearing models. | no scheduler | DEFERRED (synchronous computation) |
| U06-069 | clear model/promise/hidden/cursor fields (`:263-266`) | LIFETIME | Published state becomes empty during teardown. | `clear_local` clears model/hidden state | TESTED |
| U06-070 | optional range-provider disposal (`:267-268`) | BRANCH | Dispose lazily created provider then null it. | `clear_local` | TESTED |
| U06-071 | initial trigger after ownership complete (`:271`) | LIFETIME | First compute sees all listeners/disposer installed. | `trigger_folding_model_changed` | TESTED |
| U06-072 | `onFoldingStrategyChanged` (`:274-278`) | MEMBER | Dispose old provider, clear field, then recompute. | indent provider reset on relevant option/model changes | DEFERRED (no strategy/provider-change event axis) |
| U06-073 | optional provider disposal before trigger (`:275-277`) | LIFETIME | New computation cannot reuse old strategy owner. | `range_provider.dispose` in `clear_local` | PORTED |
| U06-074 | `getRangeProvider` (`:280-293`) | MEMBER | Reuse current provider; otherwise install indentation fallback, optionally replace with syntax provider. | `Viewer::folding_range_provider` | PORTED |
| U06-075 | cached-provider branch/return (`:281-283`) | BRANCH | Do not allocate a second provider for one model. | `Some(provider)` return | TESTED |
| U06-076 | install indentation fallback (`:284-285`) | LIFETIME | Field owns fallback before optional syntax wrapper construction. | indent provider set once | TESTED |
| U06-077 | syntax-strategy/model branch (`:286-291`) | BRANCH | Consider syntax providers only when strategy enables them and folding model exists. | none | DEFERRED (no syntax folding providers) |
| U06-078 | selected-provider nonempty branch (`:288-290`) | BRANCH | Replace field with syntax provider only when at least one provider exists. | none | DEFERRED (no syntax folding providers) |
| U06-079 | `triggerFoldingModelChanged` (`:305-350`) | MEMBER | Cancel stale work, debounce, publish promise, apply only current results, and adapt delay. | synchronous `trigger_folding_model_changed` | DEFERRED (async cancellation/debounce is absent) |
| U06-080 | scheduler-present branch (`:306-349`) | BRANCH | No scheduler means disabled/disposed and no work. | folding-model guard | PORTED |
| U06-081 | stale-region-promise branch (`:307-310`) | BRANCH | Cancel and null previous provider computation before queuing new work. | none | DEFERRED (no async computation) |
| U06-082 | publish triggered model promise (`:311`) | LIFETIME | `getFoldingModel` observes the newest scheduled computation. | immediate model option | N-A (synchronous result needs no promise owner) |
| U06-083 | disposed/disabled folding-model branch (`:312-315`) | BRANCH | Trigger callback returns null if model vanished while waiting. | guard before synchronous compute | PORTED |
| U06-084 | missing-model return (`:314`) | EXIT | Provider is never constructed after disposal. | local guard return | TESTED |
| U06-085 | create current cancelable provider promise (`:316-319`) | LIFETIME | Retain identity for stale-result rejection. | synchronous provider call | DEFERRED (no async promise) |
| U06-086 | result/current-promise branch (`:320-342`) | BRANCH | Apply only non-null result belonging to current computation. | synchronous result is current by construction | N-A (no concurrent result race) |
| U06-087 | default-import branch (`:323-329`) | BRANCH | Apply imports once per model when configured. | absent | DEFERRED (no import kinds) |
| U06-088 | import-collapse changed branch (`:325-328`) | BRANCH | Capture scroll and mark state only when collapse changed. | absent | DEFERRED (no import folding) |
| U06-089 | update folding model then restore scroll (`:331-335`) | LIFETIME | Selection-safe update precedes optional scroll restore. | local folding-model update has no stable-scroll capture/restore for folded imports | DEFERRED (the post-update scroll restoration is absent) |
| U06-090 | scheduler-still-live branch (`:338-341`) | BRANCH | Apply adaptive delay only if scheduler survived async work. | none | DEFERRED (no debounce scheduler) |
| U06-091 | rejected-trigger handler (`:345-348`) | BRANCH | Report error and resolve public promise to null. | synchronous non-raising provider | N-A (current provider signature does not raise asynchronously) |
| U06-092 | editor contribution registration (`:1246`) | LIFETIME | Register id/class as `Eager` because it implements state save/restore. | identical id, `Eager` | TESTED |

### U07 — quick-diff registrations in `quickDiff.contribution.ts`

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U07-001 | register `QuickDiffWorkbenchController` (`:30-31`) | LIFETIME | One workbench-lifetime owner starts at `Restored` and tracks all visible editors. | each Viewer eagerly registers `quickDiff.decorator` | PORTED |
| U07-002 | register `QuickDiffEditorController` (`:33-34`) | LIFETIME | Separate editor contribution `editor.contrib.quickdiff`, `AfterFirstRender`, for peek/gutter actions. | none; local id is `quickDiff.decorator` | N-A (peek widget and gutter-action controller are explicitly unported) |

### U08 — bounded quick-diff decorator/workbench ownership clusters

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U08-001 | `QuickDiffDecorator extends Disposable` (`:32-211`) | MEMBER | One live `(resource, editor)` decoration owner. | per-viewer quick-diff contribution state | DEFERRED (collection/listeners are captured by a disposer wrapper, not stored as a concrete central variant) |
| U08-002 | static `createDecoration` (`:34-60`) | MEMBER | Build one dynamic option object from gutter/overview/minimap axes. | `create_decoration` gutter reduction | PORTED |
| U08-003 | gutter branch (`:40-43`) | BRANCH | Add class and tooltip only when gutter channel is active. | gutter class always active | PORTED |
| U08-004 | overview branch (`:45-50`) | BRANCH | Add left-lane themed overview option only when active. | none | DEFERRED (no overview ruler view part) |
| U08-005 | minimap branch (`:52-57`) | BRANCH | Add themed minimap gutter option only when active. | none | DEFERRED (no minimap view part) |
| U08-006 | `addedOptions` (`:62`) | MEMBER | Primary non-pattern add decoration. | `added_options` | TESTED |
| U08-007 | `addedSecondaryOptions` (`:63`) | MEMBER | Secondary-provider add decoration. | none | N-A (service has one implicit primary provider) |
| U08-008 | `addedPatternOptions` (`:64`) | MEMBER | Primary patterned add decoration. | none | N-A (no diff-pattern configuration) |
| U08-009 | `addedSecondaryPatternOptions` (`:65`) | MEMBER | Secondary patterned add decoration. | none | N-A (one provider and no pattern configuration) |
| U08-010 | `modifiedOptions` (`:66`) | MEMBER | Primary non-pattern modify decoration. | `modified_options` | TESTED |
| U08-011 | `modifiedSecondaryOptions` (`:67`) | MEMBER | Secondary modify decoration. | none | N-A (single provider) |
| U08-012 | `modifiedPatternOptions` (`:68`) | MEMBER | Primary patterned modify decoration. | none | N-A (no pattern configuration) |
| U08-013 | `modifiedSecondaryPatternOptions` (`:69`) | MEMBER | Secondary patterned modify decoration. | none | N-A (single provider and no pattern) |
| U08-014 | `deletedOptions` (`:70`) | MEMBER | Primary deletion marker. | `deleted_options` | TESTED |
| U08-015 | `deletedSecondaryOptions` (`:71`) | MEMBER | Secondary deletion marker. | none | N-A (single provider) |
| U08-016 | `decorationsCollection` (`:72`) | MEMBER | Lazy per-editor collection, cleared and forgotten on disposal. | eagerly created `EditorDecorationsCollection` in contribution ctor | TESTED |
| U08-017 | borrowed `codeEditor` (`:75`) | MEMBER | Model/collection host. | `Viewer` | PORTED |
| U08-018 | owned `quickDiffModelRef` (`:76`) | MEMBER | Reference-counted resource model; decorator disposes it. | quick-diff service stores plain original content | N-A (no reference-counted quick-diff model service) |
| U08-019 | borrowed `configurationService` (`:77`) | MEMBER | Supplies display/pattern axes and event. | defaults baked into CSS/options | N-A (no configuration service) |
| U08-020 | borrowed `quickDiffService` (`:78`) | MEMBER | Provider visibility filtering. | one-provider `QuickDiffService` | PORTED |
| U08-021 | constructor (`:74-128`) | MEMBER | Build all option variants, own config/model listeners, initial-render via run-and-subscribe. | quick-diff contribution ctor/listeners/update | PORTED |
| U08-022 | channel option booleans (`:82-85`) | BRANCH | `all` participates independently in gutter/overview/minimap channels. | gutter fixed on; other channels absent | DEFERRED (configuration and overview/minimap axes are absent) |
| U08-023 | build four added variants (`:87-97`) | LIFETIME | Initialize every add option before subscriptions can render. | one primary non-pattern option | PORTED |
| U08-024 | added whole-line `true` (`:92`) | CONST | Add decorations cover modified line spans. | identical | TESTED |
| U08-025 | build four modified variants (`:99-109`) | LIFETIME | Initialize every modify option before subscriptions can render. | one primary non-pattern option | PORTED |
| U08-026 | modified whole-line `true` (`:104`) | CONST | Modify decorations cover line spans. | identical | TESTED |
| U08-027 | build two deleted variants (`:111-119`) | LIFETIME | Initialize deletion options before subscriptions. | one primary deletion option | PORTED |
| U08-028 | deleted whole-line `false` (`:116`) | CONST | Deleted block is a boundary marker, not whole-line. | identical | TESTED |
| U08-029 | gutter-pattern config subscription (`:121-125`) | LIFETIME | Registered in base store; rerender only on relevant setting. | none | N-A (pattern setting absent) |
| U08-030 | pattern-setting branch (`:122-124`) | BRANCH | Ignore unrelated configuration changes. | none | N-A (no config service) |
| U08-031 | run-and-subscribe model listener (`:127`) | LIFETIME | Invoke once immediately, then on every quick-diff model change; base store owns listener. | initial `quick_diff_update` plus model/content/original listeners | TESTED |
| U08-032 | `onDidChange` (`:130-201`) | MEMBER | Derive visible decorations and create/update the collection. | `Viewer::quick_diff_update`; `changes_to_decorations` | TESTED |
| U08-033 | no-model branch (`:131-133`) | BRANCH | Return without touching collection. | local no-model path clears collection | DEFERRED (local reduction clears stale decorations instead of no-op) |
| U08-034 | no-model return (`:132`) | EXIT | Skip service/model reads. | local path returns after clear | PORTED |
| U08-035 | modified-end fallback (`:157`) | BRANCH | Zero end line uses start line. | identical mapping | TESTED |
| U08-036 | missing/invisible provider branch (`:146-148`) | BRANCH | Skip change when provider is unknown or hidden. | one implicit visible provider | N-A (no provider visibility axis) |
| U08-037 | invisible-provider `continue` (`:147`) | EXIT | No decoration for that change. | none | N-A (single provider) |
| U08-038 | secondary-primary overlap branch (`:150-153`) | BRANCH | Primary decoration suppresses touching secondary changes. | one provider | N-A (no secondary provider) |
| U08-039 | overlap `continue` (`:152`) | EXIT | Skip secondary decoration. | none | N-A (no secondary provider) |
| U08-040 | `ChangeType.Add` case (`:160-170`) | BRANCH | Lines 1..end use add option. | `Add` arm | TESTED |
| U08-041 | add primary/contributed branch (`:166-168`) | BRANCH | Primary/contributed vs secondary option. | always primary | N-A (single provider) |
| U08-042 | add pattern branch (`:167-168`) | BRANCH | Patterned vs plain add option. | always plain | N-A (no pattern setting) |
| U08-043 | `ChangeType.Delete` case (`:171-181`) | BRANCH | Pin zero-width marker at `Number.MAX_VALUE` on start line. | `Delete` arm with max-column sentinel | TESTED |
| U08-044 | deletion `Number.MAX_VALUE` sentinel (`:174-175`) | CONST | Column after any line content. | `MAX_COLUMN` | TESTED |
| U08-045 | delete primary/contributed branch (`:177-179`) | BRANCH | Primary/contributed vs secondary option. | always primary | N-A (single provider) |
| U08-046 | `ChangeType.Modify` case (`:182-192`) | BRANCH | Lines 1..end use modify option. | `Modify` arm | TESTED |
| U08-047 | modify primary/contributed branch (`:188-190`) | BRANCH | Primary/contributed vs secondary option. | always primary | N-A (single provider) |
| U08-048 | modify pattern branch (`:189-190`) | BRANCH | Patterned vs plain modify option. | always plain | N-A (no pattern setting) |
| U08-049 | missing collection branch (`:196-200`) | BRANCH | First update creates collection; later updates replace contents. | collection exists before initial update, then `set` | PORTED |
| U08-050 | create collection (`:197`) | LIFETIME | Editor owns ids; decorator retains collection. | contribution creates collection | TESTED |
| U08-051 | update existing collection (`:199`) | LIFETIME | Replace decorations without changing owner. | `collection.set` | TESTED |
| U08-052 | `QuickDiffDecorator.dispose` (`:203-210`) | MEMBER | Clear collection, forget it, release model ref, then base listeners. | central state target will own collection/listeners | PORTED |
| U08-053 | collection-present branch (`:204-206`) | BRANCH | Clear only if first update created the collection. | collection is always created | N-A (local collection is nonoptional) |
| U08-054 | forget collection (`:207`) | LIFETIME | Prevent reuse after disposal. | captured state becomes unreachable with contribution entry | PORTED |
| U08-055 | dispose model reference (`:208`) | LIFETIME | Release resource-level quick-diff model. | no reference owner | N-A (plain original-content service) |
| U08-056 | base listener disposal last (`:209`) | LIFETIME | Configuration/model subscriptions release after decoration/model ref. | listener loop in contribution disposer | PORTED |
| U08-057 | `QuickDiffWorkbenchController` (`:218-458`) | MEMBER | Workbench owner maps visible `(URI, editor id)` pairs to decorators. | Viewer registry is already per editor | N-A (per-viewer central ownership removes the workbench fanout layer) |
| U08-058 | `enabled=false` (`:220`) | MEMBER | Guards enable/disable transitions. | quick diff always enabled when registered | N-A (no `scm.diffDecorations=none` setting) |
| U08-059 | `quickDiffDecorationCount` (`:221`) | MEMBER | Active-editor context count. | no context key | N-A (peek/menu surface absent) |
| U08-060 | `activeEditor` observable (`:223`) | MEMBER | Workbench-lifetime active-editor owner. | each Viewer is direct owner | N-A (no workbench editor service) |
| U08-061 | `quickDiffProviders` observable (`:224`) | MEMBER | Workbench-lifetime provider list owner. | one implicit provider | N-A (no provider registry) |
| U08-062 | `decorators` ResourceMap/DisposableMaps (`:226-227`) | MEMBER | Sole upstream owner of every live `QuickDiffDecorator`, nested URI then editor id. | one contribution entry per Viewer | N-A (central per-viewer map replaces this global fanout) |
| U08-063 | initial view state `width=3, visibility=always` (`:228`) | CONST | CSS defaults before configuration reads. | baked into `quick_diff.css` | PORTED |
| U08-064 | registered `transientDisposables` (`:229`) | MEMBER | Clearable enable-session listener/autorun owner. | contribution listener array | PORTED |
| U08-065 | `stylesheet` (`:230`) | MEMBER | Workbench-owned dynamic stylesheet disposed by base store. | static CSS asset | N-A (no runtime stylesheet owner) |
| U08-066 | borrowed editor/config/model/quick-diff/URI services (`:233-237`) | MEMBER | Workbench inputs are borrowed; only produced refs/decorators are owned. | direct Viewer and quick-diff service | N-A (no workbench service layer) |
| U08-067 | constructor (`:232-262`) | MEMBER | Create stylesheet/context/observables; own three filtered config listeners and apply initial values. | static registration/CSS defaults | N-A (per-viewer contribution needs no workbench controller) |
| U08-068 | stylesheet creation in base store (`:241`) | LIFETIME | Style element is disposed with controller. | static CSS | N-A (asset lifetime belongs to page stylesheet) |
| U08-069 | bind decoration-count context (`:243`) | LIFETIME | Publish zero until active-editor autorun. | none | N-A (no context key) |
| U08-070 | active-editor observable (`:245-246`) | LIFETIME | Controller owns event-to-observable subscription. | no editor service | N-A (each Viewer is explicit) |
| U08-071 | provider observable (`:248-249`) | LIFETIME | Controller owns provider-list subscription. | one provider service event for original content only | N-A (no provider registry) |
| U08-072 | decorations config listener + initial call (`:251-253`) | LIFETIME | Register before applying enable/disable state. | quick diff always registered | N-A (no configuration axis) |
| U08-073 | width config listener + initial call (`:255-257`) | LIFETIME | Register before applying width. | width 3 static CSS | N-A (fixed default) |
| U08-074 | visibility config listener + initial call (`:259-261`) | LIFETIME | Register before applying visibility. | always static CSS | N-A (fixed default) |
| U08-075 | `enable` (`:310-322`) | MEMBER | Reset existing enabled session, own visible-editor event, build decorators/autoruns, then set enabled. | contribution construction per Viewer | PORTED |
| U08-076 | already-enabled branch (`:311-313`) | BRANCH | Fully disable before re-enabling to avoid duplicate resources. | Viewer contribution constructs once | N-A (no runtime enable transition) |
| U08-077 | visible-editor listener (`:315`) | LIFETIME | Transient store owns close/visible-set callback. | model-change listener in per-viewer contribution | PORTED |
| U08-078 | initial editor reconciliation (`:316`) | LIFETIME | Create missing decorators before enabled flag flips. | ctor creates collection/listeners and runs update | TESTED |
| U08-079 | active-editor/provider autorun setup (`:318-319`) | LIFETIME | Add transient counter/menu owners. | none | N-A (peek/menu/provider surface absent) |
| U08-080 | set `enabled=true` last (`:321`) | LIFETIME | Reconciliation completes before state reports enabled. | contribution entry becomes visible after ctor returns | PORTED |
| U08-081 | `disable` (`:324-338`) | MEMBER | Idempotently clear transient owners/count/decorators, then mark disabled. | Viewer contribution disposal | PORTED |
| U08-082 | already-disabled branch (`:325-327`) | BRANCH | Repeated disable is a no-op. | Viewer dispose is idempotent | TESTED |
| U08-083 | already-disabled return (`:326`) | EXIT | No second disposal. | same | TESTED |
| U08-084 | clear transient store/count (`:329-330`) | LIFETIME | Stop callbacks before decorator disposal. | listener loop before entry disappears | PORTED |
| U08-085 | dispose/delete every decorator map (`:332-335`) | LIFETIME | Dispose values before removing URI key. | per-viewer contribution disposer | PORTED |
| U08-086 | set `enabled=false` last (`:337`) | LIFETIME | All owned state is gone before disabled publication. | entry removed/cleared after disposer | PORTED |
| U08-087 | `onEditorsChanged` (`:408-453`) | MEMBER | Create missing visible-editor decorators, then dispose stale ones. | static per-viewer construction plus model-change update | PORTED |
| U08-088 | non-code-editor branch (`:410-412`) | BRANCH | Ignore non-code visible controls. | every instance is a Viewer | N-A (closed editor type) |
| U08-089 | non-code-editor `continue` (`:411`) | EXIT | No URI/model lookup. | none | N-A (closed editor type) |
| U08-090 | missing-model branch (`:415-417`) | BRANCH | Do not create decorator without a resource. | contribution exists but update clears collection | PORTED |
| U08-091 | missing-model `continue` (`:416`) | EXIT | Skip model reference creation. | local update return | PORTED |
| U08-092 | existing `(URI,id)` branch (`:420-422`) | BRANCH | Prevent duplicate decorator construction. | one contribution construction per Viewer | TESTED |
| U08-093 | existing decorator `continue` (`:421`) | EXIT | Preserve current decorator/listeners. | same | TESTED |
| U08-094 | unavailable model-ref branch (`:424-427`) | BRANCH | Skip editor when quick-diff model service has no resource model. | local missing original clears the per-viewer decoration collection | DEFERRED (the local reduction clears rather than skipping the editor) |
| U08-095 | unavailable model-ref `continue` (`:426`) | EXIT | No decorator owns an invalid reference. | local has no reference owner | N-A (plain original content option) |
| U08-096 | missing URI-map branch (`:429-431`) | BRANCH | Create inner disposable map before first editor entry. | central Viewer map already exists | N-A (different ownership topology) |
| U08-097 | store new decorator (`:433`) | LIFETIME | Inner disposable map becomes sole owner of concrete decorator. | target `QuickDiffContributionState` enum payload | DEFERRED (current central entry stores only its disposer closure) |
| U08-098 | visible-editor identity/resource match (`:439-441`) | BRANCH | A decorator remains only while same id and same URI are visible. | Viewer survives model swaps and updates its one collection | N-A (per-viewer contribution lifetime intentionally differs) |
| U08-099 | missing-visible-editor branch (`:443-445`) | BRANCH | Delete-and-dispose stale editor decorator. | only Viewer disposal removes contribution | N-A (model swaps reuse the per-viewer contribution) |
| U08-100 | empty URI-map branch (`:448-451`) | BRANCH | Dispose empty inner map then delete URI key. | no nested URI owner | N-A (central map is keyed only by contribution id) |
| U08-101 | workbench controller `dispose` (`:455-458`) | MEMBER | `disable` all decorators/transients before base stylesheet/config owners. | Viewer contribution disposal | PORTED |
| U08-102 | disable-before-super order (`:456-457`) | LIFETIME | Concrete decorators release before controller base store. | contribution state disposer before map clear | PORTED |

### U09 — identity distinction for `QuickDiffEditorController`

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U09-001 | `QuickDiffEditorController` (`quickDiffWidget.ts:481`) | MEMBER | Separate per-editor peek/gutter-action contribution. | none | N-A (peek widget/action controller is unported) |
| U09-002 | static `ID='editor.contrib.quickdiff'` (`:483`) | CONST | Registration/lookup key differs from local `quickDiff.decorator`. | none | N-A (local id names the decorator reduction, not this class) |
| U09-003 | static `get` (`:485-487`) | MEMBER | Typed central-map view for the peek controller. | none | N-A (class is unported) |
| U09-004 | get delegates by ID (`:486`) | LIFETIME | No second class-owned store. | none | N-A (class is unported) |
| U09-005 | `dispose` (`:763-766`) | MEMBER | Dispose gutter-action transient store before base-owned resources. | none | N-A (gutter-action controller is unported) |
| U09-006 | gutter store before super (`:764-765`) | LIFETIME | Stop gutter callbacks before remaining resources. | none | N-A (gutter-action controller is unported) |

### U10 — bounded agent-feedback input ownership cluster

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U10-001 | `AgentFeedbackEditorInputContribution` (`:244-885`) | MEMBER | One editor-lifetime input controller. | local concrete controller | DEFERRED (controller lives in process-global `input_instances`) |
| U10-002 | static `ID` (`:246`) | CONST | `agentFeedback.editorInputContribution`. | identical id | TESTED |
| U10-003 | reserved gutter width `18` (`:252`) | CONST | Add/remove 18px while current file has a feedback session. | `agent_feedback_reserved_gutter_px` | TESTED |
| U10-004 | `_widget` (`:254`) | MEMBER | Lazy controller-owned overlay widget. | `widget` | TESTED |
| U10-005 | `_visible=false` (`:255`) | MEMBER | Input visibility state. | `visible` | TESTED |
| U10-006 | `_mouseDown=false` (`:256`) | MEMBER | Suppresses selection reaction during editor drag/click. | `mouse_down` | TESTED |
| U10-007 | `_suppressSelectionChangeOnce=false` (`:257`) | MEMBER | One-shot guard after hide/refocus. | `suppress_selection_change_once` | TESTED |
| U10-008 | `_reservedGutterSpace=false` (`:258`) | MEMBER | Whether 18px has been added. | `lane_base_width : Int?` | PORTED |
| U10-009 | `_session` (`:259`) | MEMBER | Current model's session retained while input is active. | service lookup on demand | PORTED |
| U10-010 | `_pinnedRange` (`:260`) | MEMBER | Selection/range captured for draft submission. | `pinned_range` | TESTED |
| U10-011 | `_anchorPosition` (`:261`) | MEMBER | Widget anchor captured independently of range. | `anchor_position` | TESTED |
| U10-012 | `_preferBelow=true` (`:262`) | MEMBER | Placement preference derived from selection direction. | `prefer_below` | TESTED |
| U10-013 | `_hoverLineNumber` (`:263`) | MEMBER | Optional line owning hover glyph. | `hover_line_number=-1` sentinel | PORTED |
| U10-014 | `_hoverDecorations` (`:264`) | MEMBER | Controller-owned collection, cleared by base-store disposer. | owner-scoped `hover_decoration_ids` | TESTED |
| U10-015 | `_hasAgentFeedbackSessionContext` (`:265`) | MEMBER | Per-editor context key for actions/menu. | live `agent_feedback_enabled` predicate | N-A (no context-key service) |
| U10-016 | registered `_widgetListeners` store (`:266`) | MEMBER | Visible-session DOM listeners; reusable across show/hide and disposed by base store. | widget listeners/keybindings split across widget and root registry | DEFERRED (no single controller-owned listener store) |
| U10-017 | borrowed `_editor` (`:269`) | MEMBER | Model/event/widget host. | `Viewer` glue | PORTED |
| U10-018 | borrowed feedback service (`:270`) | MEMBER | Session/feedback source. | `ViewerServices.agent_feedback` | PORTED |
| U10-019 | borrowed code-editor service (`:271`) | MEMBER | Builds feedback context and action lookup. | direct Viewer context | N-A (no global code-editor service) |
| U10-020 | borrowed context-key service (`:272`) | MEMBER | Binds session context and checks chat enablement. | service enable predicate | N-A (no context-key service) |
| U10-021 | constructor (`:268-340`) | MEMBER | Create collection/context, retain ten editor listeners, then resolve initial session. | `attach` plus `Viewer::hook_agent_feedback` | DEFERRED (state and listener owners are split across global map and disposer closure) |
| U10-022 | create hover collection (`:276`) | LIFETIME | Collection exists before events. | decoration id array starts empty | PORTED |
| U10-023 | register collection clear disposer (`:277`) | LIFETIME | Clear decorations during base disposal. | model-swap reset and owner sweep | PORTED |
| U10-024 | bind session context (`:278`) | LIFETIME | Context key exists before listeners/session resolution. | live predicate | N-A (no context key) |
| U10-025 | cursor-selection listener (`:280`) | LIFETIME | Base store owns input selection reaction. | root subscription array | DEFERRED (listener not owned by concrete controller) |
| U10-026 | model-change listener (`:281`) | LIFETIME | Base store owns model reset. | root subscription array | DEFERRED (listener not owned by concrete controller) |
| U10-027 | scroll listener (`:282-286`) | LIFETIME | Reposition only while visible. | root scroll listener | PORTED |
| U10-028 | visible-on-scroll branch (`:283-285`) | BRANCH | Hidden input incurs no layout work. | equivalent | TESTED |
| U10-029 | layout-change listener (`:287-294`) | LIFETIME | Autosize then reposition a visible, created widget. | reposition rides scroll/options path | DEFERRED (no dedicated layout event) |
| U10-030 | visible-and-widget layout branch (`:288-293`) | BRANCH | Avoid creating widget during layout. | optional widget/visible guards | PORTED |
| U10-031 | mouse-move listener (`:295`) | LIFETIME | Base store owns glyph following. | root subscription array | DEFERRED (listener not owned by concrete controller) |
| U10-032 | mouse-leave listener (`:296`) | LIFETIME | Clear hover glyph. | root subscription array | DEFERRED (listener not owned by concrete controller) |
| U10-033 | mouse-down listener (`:297-312`) | LIFETIME | Widget/glyph targets return; ordinary target marks down and autohides. | root subscription and handler | PORTED |
| U10-034 | widget-target mouse-down branch/return (`:298-300`) | BRANCH | Do not mutate editor selection/input state. | equivalent target guard | TESTED |
| U10-035 | glyph-target mouse-down branch (`:301-309`) | BRANCH | Prevent/stop event, optionally select line, then return. | glyph target handler | TESTED |
| U10-036 | glyph line-defined branch (`:304-307`) | BRANCH | Select only when target carries a line. | target position option | TESTED |
| U10-037 | glyph mouse-down return (`:308`) | EXIT | Never set ordinary `_mouseDown`. | same | TESTED |
| U10-038 | ordinary mouse-down state/autohide (`:310-311`) | LIFETIME | Mark down before attempting hide. | same | PORTED |
| U10-039 | mouse-up listener (`:313-322`) | LIFETIME | Clear down before target guards; then reevaluate selection. | root subscription and handler | PORTED |
| U10-040 | widget-target mouse-up branch/return (`:315-317`) | BRANCH | Skip selection reaction. | equivalent | TESTED |
| U10-041 | glyph-target mouse-up branch/return (`:318-320`) | BRANCH | Glyph down path already selected line. | equivalent | TESTED |
| U10-042 | editor-blur listener (`:323-337`) | LIFETIME | Deferred focus-settle callback autohides outside editor/widget. | only a synchronous empty-textarea blur callback exists | DEFERRED (the local viewer has no editor-blur focus-settle listener) |
| U10-043 | hidden-at-blur branch/return (`:324-326`) | BRANCH | Do not schedule when already hidden. | widget blur only exists while shown | PORTED |
| U10-044 | blur timeout `0` (`:328-336`) | CONST | Defer until new active element is settled. | local textarea blur invokes its host synchronously | DEFERRED (zero-delay focus settling is absent) |
| U10-045 | hidden-after-timeout branch/return (`:329-331`) | BRANCH | Racing hide makes callback no-op. | no deferred callback can race a hide | DEFERRED (zero-delay focus settling is absent) |
| U10-046 | focus-moved-to-widget branch/return (`:332-334`) | BRANCH | Preserve visible input when focus enters it. | local blur checks only whether the textarea is empty | DEFERRED (there is no editor/widget focus containment guard) |
| U10-047 | text-focus listener (`:338`) | LIFETIME | Reevaluate selection when editor text gains focus. | local focus handling emits view focus and renders without invoking feedback selection logic | DEFERRED (the generic text-focus reevaluation listener is absent) |
| U10-048 | initial session resolution (`:339`) | LIFETIME | Publish context/gutter state after all listeners exist. | `sync_agent_feedback_lane` before returning listener array | PORTED |
| U10-049 | `_ensureWidget` (`:350-358`) | MEMBER | Lazily create one widget, own its two action listeners, register overlay. | local lazy widget construction | TESTED |
| U10-050 | missing-widget branch (`:351-356`) | BRANCH | No duplicate widget/listener/overlay registration. | optional widget guard | TESTED |
| U10-051 | create/retain widget (`:352`) | LIFETIME | Concrete widget becomes controller field. | `widget` | TESTED |
| U10-052 | add and add-submit listeners (`:353-354`) | LIFETIME | Base store owns both widget events for controller lifetime. | widget host callbacks | PORTED |
| U10-053 | add overlay widget (`:355`) | LIFETIME | Editor owns mounted widget registration until controller dispose. | Viewer overlay widget map | PORTED |
| U10-054 | `_onModelChanged` (`:360-366`) | MEMBER | Hide, clear glyph/suppression/session, then resolve new session. | `on_agent_feedback_model_changed`; `reset_model_state` | TESTED |
| U10-055 | model-reset order (`:361-365`) | LIFETIME | Old widget/glyph/session state gone before new session/lane lookup. | local hide, clear glyph, reset, sync lane | TESTED |
| U10-056 | `_hide` (`:502-517`) | MEMBER | Idempotently clear visible anchors/listeners and reset widget. | `hide_agent_feedback_input` | TESTED |
| U10-057 | already-hidden branch/return (`:503-505`) | BRANCH | Preserve draft/widget without duplicate clears. | local visibility guard | TESTED |
| U10-058 | clear visibility/anchors/listener store (`:507-510`) | LIFETIME | DOM listeners stop before widget reset. | local hide clears visibility/anchors but leaves constructor-lifetime widget listeners installed | DEFERRED (the visible-session listener release is absent) |
| U10-059 | widget-present hide branch (`:512-516`) | BRANCH | Hide/unposition/clear only if widget was created. | optional widget branch | TESTED |
| U10-060 | `_updateReservedGutterSpace` (`:606-616`) | MEMBER | Idempotently add/subtract 18px and update editor option. | `sync_agent_feedback_lane` stores/restores base width | PORTED |
| U10-061 | unchanged-reservation branch/return (`:607-609`) | BRANCH | Avoid cumulative width changes. | `(needed,lane_base_width)` state machine | TESTED |
| U10-062 | add-vs-subtract branch (`:612-614`) | BRANCH | Add 18 when enabling; subtract/clamp at zero when disabling. | add 18 and restore recorded base | PORTED |
| U10-063 | `_registerWidgetListeners` (`:630-745`) | MEMBER | Clear old visible-session listeners, then own editor/input DOM listeners. | widget DOM listeners install once in its constructor; editor chords use the process registry | N-A (there is no visible-session registration method) |
| U10-064 | clear old widget listeners first (`:631`) | LIFETIME | Re-show cannot duplicate callbacks. | persistent widget listeners are never reinstalled on show | N-A (constructor-lifetime listeners cannot duplicate across re-show) |
| U10-065 | editor DOM present branch (`:634-693`) | BRANCH | Editor-level keydown exists only with a DOM node. | attached Viewer root | PORTED |
| U10-066 | hidden editor-keydown branch/return (`:637-639`) | BRANCH | Racing hide ignores event. | visibility command precondition | PORTED |
| U10-067 | missing text-focus branch/return (`:643-645`) | BRANCH | Overlay/widget focus must not be stolen. | root command preconditions/widget focus | PORTED |
| U10-068 | modifier-key-alone branch/return (`:648-650`) | BRANCH | Ctrl/Shift/Alt/Meta alone never focus input. | keybinding resolver | N-A (only explicit registered chords reach the action) |
| U10-069 | Escape branch/return (`:653-657`) | BRANCH | Hide, refocus editor, consume no typing. | `agentFeedback.cancelInput` plus widget Escape | TESTED |
| U10-070 | Ctrl/Cmd+I branch/return (`:660-665`) | BRANCH | Prevent/stop and focus input. | `agentFeedback.focusInput` keybinding | TESTED |
| U10-071 | other-modifier branch/return (`:668-670`) | BRANCH | Do not steal keyboard shortcuts. | exact keybinding matching | TESTED |
| U10-072 | arrow-key branch/return (`:673-680`) | BRANCH | Navigation remains in editor. | only explicit keybindings route | N-A (no typing-steal listener) |
| U10-073 | editable-editor branch/return (`:684-686`) | BRANCH | Automatic typing focus only in readonly editors. | Viewer is readonly but typing is unsupported | N-A (no editor typing path) |
| U10-074 | inactive-input branch (`:689-691`) | BRANCH | Focus once when actual typing begins. | none | N-A (no typing path) |
| U10-075 | input keydown listener (`:696-718`) | LIFETIME | Visible-session store owns Escape/Alt+Enter/Enter handling. | widget handlers | PORTED |
| U10-076 | input Escape branch/return (`:697-703`) | BRANCH | Consume, hide, refocus editor. | widget Escape | TESTED |
| U10-077 | input Alt+Enter branch/return (`:705-710`) | BRANCH | Consume and add+submit. | widget submit action | TESTED |
| U10-078 | input Enter branch/return (`:712-717`) | BRANCH | Consume and add. | widget add action | TESTED |
| U10-079 | input keypress listener (`:720-723`) | LIFETIME | Stop propagation to editor. | local input stops keydown/keyup propagation and has no `keypress` path | N-A (the local viewer has no keypress handler) |
| U10-080 | input change listener (`:725-730`) | LIFETIME | Autosize, update action, reposition. | widget input event | TESTED |
| U10-081 | input blur listener (`:732-744`) | LIFETIME | Defer and autohide only outside editor/widget. | local textarea blur synchronously autohides only when empty | DEFERRED (focus-settle timing and editor/widget containment are absent) |
| U10-082 | blur timeout `0` (`:735-743`) | CONST | Defer autohide until the newly focused element has settled. | local textarea blur invokes its host synchronously | DEFERRED (zero-delay focus settling is absent) |
| U10-083 | blur hidden branch/return (`:736-738`) | BRANCH | Racing hide no-ops. | visibility guard | PORTED |
| U10-084 | editor-widget-focus branch/return (`:739-741`) | BRANCH | Preserve when focus remains in editor/widget. | local blur checks only whether the textarea is empty | DEFERRED (there is no editor/widget focus containment guard) |
| U10-085 | typed action contribution lookup (`:902-907`) | LIFETIME | Focused/active editor central lookup returns concrete input controller, then calls it. | root accessor via global `input_instances` | DEFERRED (must match central enum instead of second map) |
| U10-086 | focused-vs-active fallback (`:904`) | BRANCH | Prefer focused editor. | single explicit Viewer | N-A (no code-editor service) |
| U10-087 | optional editor/contribution calls (`:905-906`) | BRANCH | Missing editor or missing contribution is a no-op. | root optional accessor | PORTED |
| U10-088 | `dispose` (`:876-884`) | MEMBER | Release reserved gutter, unmount/dispose optional widget, then base listeners/collection. | contribution wrapper subscriptions + widget/controller teardown | DEFERRED (central entry does not own controller/listeners/widget together) |
| U10-089 | release gutter before widget (`:877`) | LIFETIME | Restore layout option first. | explicit lane sync on model/dispose paths | PORTED |
| U10-090 | widget-present disposal branch (`:878-882`) | BRANCH | Remove overlay, dispose widget, then clear field. | Viewer widget removal/disposal | PORTED |
| U10-091 | `super.dispose` last (`:883`) | LIFETIME | Base store then releases listeners/collection/context. | wrapper listener loop and map removal | DEFERRED (owners are split and central dispatch cannot reproduce this order yet) |
| U10-092 | editor contribution registration (`:911`) | LIFETIME | Register exact class/id as `Eventually`. | identical id/mode declaration, though constructed eagerly | DEFERRED (declared Eventually is not scheduled; concrete instance enters a global map) |

### U11 — bounded agent-feedback widget ownership cluster

| Row | Source atom | Kind | Transition / ownership | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U11-001 | `AgentFeedbackEditorWidgetContribution` (`:1034-1309`) | MEMBER | One editor-lifetime owner for feedback bubble widgets. | local concrete widget controller | DEFERRED (controller lives in process-global `widget_instances`) |
| U11-002 | static `ID` (`:1036`) | CONST | `agentFeedback.editorWidgetContribution`. | identical id | TESTED |
| U11-003 | `_widgets=[]` (`:1038`) | MEMBER | Live widget owners in render/stack order. | `widgets` array | TESTED |
| U11-004 | registered `_widgetListeners` (`:1039`) | MEMBER | Rebuild-scoped expand listeners; reusable and controller-owned. | widget host callbacks, no controller store | DEFERRED (listeners are not owned by the concrete controller) |
| U11-005 | `_sessionResource` (`:1040`) | MEMBER | Current model's feedback session identity. | current model/service lookup | PORTED |
| U11-006 | `_replyDraftState` (`:1047-1050`) | MEMBER | Controller-lifetime drafts/focus state survives widget rebuilds. | `reply_drafts` plus transient focused-reply snapshot | PORTED |
| U11-007 | reply `drafts` map (`:1048`) | MEMBER | Comment-id keyed mutable drafts. | `reply_drafts` | TESTED |
| U11-008 | `focusedCommentId=undefined` (`:1049`) | MEMBER | Carries focused reply across teardown/rebuild. | `clear_agent_feedback_widgets` returns focused id into rebuild | PORTED |
| U11-009 | borrowed `_editor` (`:1053`) | MEMBER | Event/model/widget host. | root Viewer glue | PORTED |
| U11-010 | borrowed feedback service (`:1054`) | MEMBER | Feedback/navigation/session source. | `ViewerServices.agent_feedback` | PORTED |
| U11-011 | borrowed sessions-management service (`:1055`) | MEMBER | Maps current/original/modified resources. | single-resource feedback store | DEFERRED (no session change-resource service) |
| U11-012 | borrowed code-review service (`:1056`) | MEMBER | Observable PR review state for rebuilds. | none | DEFERRED (PR review state is not ported) |
| U11-013 | borrowed instantiation service (`:1057`) | MEMBER | Creates concrete widgets with injected services. | direct widget constructor/host closure | N-A (no DI service) |
| U11-014 | constructor (`:1052-1091`) | MEMBER | Own navigation/rebuild/layout subscriptions and initial autorun rebuild. | `attach` plus `hook_agent_feedback_widgets` | DEFERRED (controller and subscriptions are split between global map and disposer wrapper) |
| U11-015 | navigation subscription (`:1061-1065`) | LIFETIME | Base store owns session-filtered navigation callback. | root service subscription | DEFERRED (listener is not owned by concrete controller) |
| U11-016 | matching-session navigation branch (`:1062-1064`) | BRANCH | Handle only when both current session exists and URI strings match. | current-resource filter | TESTED |
| U11-017 | rebuild signal from feedback/model events (`:1067-1070`) | LIFETIME | Observable owner combines both invalidation sources. | two root subscriptions plus model-content adaptation | PORTED |
| U11-018 | scroll/layout subscription (`:1072-1076`) | LIFETIME | One base-store listener relayouts all live widgets. | local listener covers scroll but has no dedicated layout event | DEFERRED (layout-triggered relayout is absent) |
| U11-019 | relayout every widget (`:1073-1075`) | LIFETIME | Preserve array order while updating geometry. | `relayout_agent_feedback_widgets` | PORTED |
| U11-020 | rebuild autorun (`:1078-1090`) | LIFETIME | Base store owns reactive rebuild, session resolve, PR read, navigation. | root feedback/model subscriptions invoke rebuild/handle | PORTED |
| U11-021 | missing-session branch (`:1081-1084`) | BRANCH | Clear widgets and stop before PR state read. | no model/comments branch clears widgets | TESTED |
| U11-022 | missing-session return (`:1083`) | EXIT | No rebuild/navigation. | same | TESTED |
| U11-023 | rebuild before navigation (`:1086-1089`) | LIFETIME | New widget set exists before navigation expands/focuses. | same ordering in root hooks | TESTED |
| U11-024 | `_rebuildWidgets` (`:1102-1150`) | MEMBER | Clear old owners, validate session/model/comments, create widgets in reverse order, own expand listeners, then prune drafts. | `Viewer::rebuild_agent_feedback_widgets` | TESTED |
| U11-025 | `_clearWidgets` first (`:1105`) | LIFETIME | Capture focus and dispose all old widgets/listeners before reading inputs. | `clear_agent_feedback_widgets` | TESTED |
| U11-026 | missing-session branch/return (`:1107-1109`) | BRANCH | Leave empty widget set. | current-model/service guard | TESTED |
| U11-027 | missing-model branch/return (`:1111-1114`) | BRANCH | Leave empty widget set. | model/view guard | TESTED |
| U11-028 | no-file-comments branch/return (`:1122-1124`) | BRANCH | Leave empty widget set. | empty comments guard | TESTED |
| U11-029 | grouping distance `5` (`:1126`) | CONST | Nearby comments within five lines share a widget. | default grouping helper | TESTED |
| U11-030 | reverse group order (`:1128-1132`) | LIFETIME | Add lower-file widgets first so upper widgets render on top. | reverse loop | TESTED |
| U11-031 | create concrete widget (`:1133`) | LIFETIME | Pass editor/group/session/shared draft state. | direct `AgentFeedbackEditorWidget::new` | PORTED |
| U11-032 | retain widget before listener/layout (`:1134`) | LIFETIME | Widget enters owner array before callbacks can inspect siblings. | push before overlay/layout | PORTED |
| U11-033 | expand listener (`:1138-1144`) | LIFETIME | Rebuild-scoped store owns one listener per widget. | widget host `on_did_expand` callback | PORTED |
| U11-034 | other-and-expanded branch (`:1140-1142`) | BRANCH | Collapse only different expanded siblings. | equivalent id/expanded check | TESTED |
| U11-035 | initial widget layout (`:1146`) | LIFETIME | Layout only after owner/listener installation. | add overlay then layout | PORTED |
| U11-036 | prune drafts last (`:1149`) | LIFETIME | Draft retention is reconciled against the complete new widget set. | `prune_agent_feedback_reply_drafts` | TESTED |
| U11-037 | `_clearWidgets` (`:1271-1283`) | MEMBER | Capture focus, clear listeners, dispose every widget, then empty array. | `clear_agent_feedback_widgets` | TESTED |
| U11-038 | capture focused reply first (`:1276`) | LIFETIME | Snapshot before widget blur/disposal can clear it. | return focused reply snapshot | TESTED |
| U11-039 | clear rebuild listeners (`:1278`) | LIFETIME | Stop expand callbacks before widget destruction. | local callbacks die with their widgets and have no independent pre-widget store clear | DEFERRED (the source release ordering is absent) |
| U11-040 | dispose every widget (`:1279-1281`) | LIFETIME | Widget removes overlay/listeners/decorations. | mark disposed and remove overlay for every widget | PORTED |
| U11-041 | truncate widgets to zero (`:1282`) | LIFETIME | No disposed widget remains reachable. | `wc.widgets.clear()` | TESTED |
| U11-042 | `_captureFocusedReplyCommentId` (`:1285-1303`) | MEMBER | Recompute focus from DOM from scratch before rebuild. | widget query loop returns focused id | PORTED |
| U11-043 | clear stale focused id first (`:1288`) | LIFETIME | Old snapshot cannot survive if no active textarea exists. | local snapshot variable starts `None` | PORTED |
| U11-044 | no-widgets branch/return (`:1289-1291`) | BRANCH | Avoid active-element reads. | empty loop | PORTED |
| U11-045 | optional editor DOM/active element (`:1292`) | BRANCH | Missing editor DOM yields undefined active element. | attached-view guard | PORTED |
| U11-046 | non-HTML active-element branch/return (`:1293-1295`) | BRANCH | Only HTML elements can belong to a reply field. | widget query returns `None` | PORTED |
| U11-047 | matching-comment branch (`:1298-1301`) | BRANCH | Store first matching comment id and return. | first focused reply wins | TESTED |
| U11-048 | matching-comment return (`:1300`) | EXIT | Later widgets cannot replace the snapshot. | local loop preserves first found | TESTED |
| U11-049 | `dispose` (`:1305-1308`) | MEMBER | Clear widgets/rebuild listeners before base subscriptions. | contribution disposer clears widgets then subscription loop | PORTED |
| U11-050 | clear-before-super order (`:1306-1307`) | LIFETIME | No widget callback survives into base event teardown. | same high-level order | PORTED |
| U11-051 | editor contribution registration (`:1311`) | LIFETIME | Register exact class/id as `Eventually`. | identical id/mode declaration, constructed eagerly | DEFERRED (timing is not Eventually and concrete controller enters a global map) |

## Deviations and target implications

- TypeScript DI, context keys, workbench editor services, dynamic configuration,
  observable plumbing, and reference-counted quick-diff models have no local
  runtime owner. Their rows are `N-A` only where the local closed/static seam
  erases the behavior; missing supported behavior is `DEFERRED`.
- Lazy/idle contribution timing remains deliberately deferred. This ownership
  refactor must not accidentally claim `AfterFirstRender`,
  `BeforeFirstInteraction`, `Eventually`, or `Lazy` timing parity.
- Contribution save/restore callbacks remain deferred by parent-plan scope.
  Folding is registered eager upstream because it has such callbacks; keeping
  its local eager construction does not port those callbacks.
- Hover, folding, and both feedback classes currently violate the source's
  lookup topology: their typed accessors read feature-global maps. The target
  closed enum must hold each concrete controller exactly once in
  `Viewer.contributions`; typed accessors are matches over that map entry.
- Quick diff is a deliberate topology adaptation. The local product has no
  workbench visible-editor fanout, so a per-viewer `QuickDiffContributionState`
  replaces `QuickDiffWorkbenchController.decorators`. It is not the upstream
  `QuickDiffEditorController` and must keep the local id distinction explicit.
- Source disposal order must remain observable in the central dispatch:
  controller-owned timers/promises/listeners/widgets/decorations release before
  the central entry disappears, while `Viewer.on_did_dispose` still fires while
  all contribution entries are reachable.

## Branch-derived validation obligations

The implementation/test companion must link exact tests for these ownership
axes; repository-green checks alone are insufficient:

- known/unknown id and wrong enum-variant lookup;
- one construction and one disposal for each of five entries;
- duplicate description ids without silent last-writer ownership;
- two simultaneous Viewers, including deliberately colliding/reused public
  editor-id strings, with independent controller state;
- no model, attach, same-model no-op, model swap, model removal, reattach, and
  Viewer disposal;
- dispose-event callback can still reach every central entry, followed by an
  empty map after disposal;
- hover pending timer/request, optional widget, model/content invalidation,
  and repeated disposal;
- folding model/hidden model/listener/provider order and pending-work
  cancellation seam;
- feedback input lazy widget, visible-only listeners, gutter reservation,
  draft/selection suppression, and model reset;
- feedback widgets rebuild/clear/focus-draft capture, expand listener release,
  and reverse construction order;
- quick-diff initial update, model/content/original changes, collection clear,
  and listener release.

## Closing audit

- [x] The oracle source is the checked-in submodule state.
- [x] The complete 165-line `codeEditorContributions.ts` unit was reread and
      every scoped member, branch, early exit, timing constant, and lifetime
      owner has a row.
- [x] Every large-file cluster is explicitly bounded and its behavior siblings
      are named as excluded.
- [x] The stale quick-diff header pin was diffed against the current pin; both
      mapped files are byte-identical.
- [x] The two real pinned agent-feedback contribution classes replace the
      parent's incorrect missing-upstream premise.
- [x] Mechanical row/status totals above reconcile after the final static
      audit.

**STOP FOR REVIEW. No contribution storage or product source may change from
this ledger until Gate A is explicitly approved.**
