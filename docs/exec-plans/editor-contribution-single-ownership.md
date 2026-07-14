# Editor Contribution Single Ownership

Status: inventory ready — STOP FOR REVIEW; no implementation has started
Date: 2026-07-13
Oracle commit: `vscode` submodule at
`b18492a288de038fbc7643aae6de8247029d11bd`

Gate A is recorded as a four-document, documentation-only artifact set:

- `editor-contribution-single-ownership-gate-a.md`;
- `editor-contribution-single-ownership-gate-a-upstream.md`;
- `editor-contribution-single-ownership-gate-a-local.md`;
- `editor-contribution-single-ownership-gate-a-lifetime.md`.

Product implementation remains blocked until the entrypoint and all three
companions are explicitly approved.

## Goal

Make the per-viewer contribution registry the sole owner and lookup table for
actual contribution controller instances. Delete the feature-local process
global maps keyed by `Viewer::get_id()`.

`Viewer` already owns `Map[String, EditorContribution]`, constructs it through
`EditorContributionRegistry::instantiate_all`, and disposes it with the
viewer. Hover, folding, and both agent-feedback controllers then duplicate
that ownership in four global maps. Monaco has one
`CodeEditorContributions._instances` map; feature `get(editor)` methods are
typed views over that map, not second stores.

This plan supersedes, as a current architectural direction, Track C of the
implemented `monaco-ownership-divergence-closeout.md`, which introduced
feature-local instance tables as a MoonBit downcast workaround. That plan
remains immutable historical evidence and is not edited.

## Current Denominator

Registered contribution rows at the current checkout:

- content hover;
- folding;
- agent-feedback input;
- agent-feedback widgets;
- quick-diff decorator.

Duplicate stores to remove:

- `viewer/contrib/hover/browser/content_hover_controller.mbt::instances`;
- `viewer/contrib/folding/browser/folding.mbt::folding_instances`;
- `viewer/contrib/agent_feedback/browser/
  agent_feedback_editor_input_contribution.mbt::input_instances`;
- `viewer/contrib/agent_feedback/browser/
  agent_feedback_editor_widget_contribution.mbt::widget_instances`.

The local scope also includes:

- `viewer/editor_extensions.mbt` and its white-box tests;
- the `Viewer.contributions` field, initialization, lookup, and disposal;
- every contribution registration constructor;
- every `attach`, `get`, and `detach` call;
- root `Viewer::` feature glue that currently looks up a controller by editor
  id;
- model-swap and dispose behavior for all five registered contributions.

## Phase 0: Pinned Source Scope

Read and inventory these complete source units/clusters:

- `vscode/src/vs/editor/browser/widget/codeEditor/codeEditorContributions.ts`;
- the contribution initialization, `getContribution`, model-attach hook,
  save/restore, and disposal clusters in `codeEditorWidget.ts`;
- `IEditorContribution` and contribution registration contracts in
  `editorCommon.ts` and `editorExtensions.ts`;
- `ContentHoverController.get` and its construction/disposal lifecycle;
- `FoldingController.get` and its construction/disposal lifecycle.

Gate A corrected this proposal's agent-feedback premise: both local classes
exist upstream at the pinned oracle and register as `Eventually`. Their exact
ownership/lifecycle clusters receive upstream rows; unrelated feedback
behavior remains outside this storage refactor. Quick diff receives both its
Monaco source mapping and local lifecycle rows, with the explicit distinction
that local `quickDiff.decorator` reduces the workbench decorator/controller and
is not upstream `QuickDiffEditorController`.

Explicitly out of scope:

- implementing Monaco's lazy/idle instantiation modes;
- adding contribution save/restore behavior not already present;
- changing feature behavior, commands, keybindings, or model algorithms;
- redesigning the global contribution description registry;
- final public-facade decisions for `get_contribution`; the public API plan
  owns that decision.

## Gate A: Inventory and Review Stop

Before editing the registry, deliver:

1. A complete upstream member/branch/lifetime ledger for the scoped clusters.
2. A five-row local contribution table containing id, instantiation mode,
   constructor, actual state object, listeners, model-scoped state, disposal,
   and every typed lookup caller.
3. A four-map lifecycle audit proving insertion/removal behavior and identifying
   leak/collision behavior if two viewers reuse or outlive ids.
4. A representation spike proving a heterogeneous central map can retain each
   concrete controller without global state.
5. An exact event/disposal-order trace for viewer construction, model attach,
   model swap, and viewer disposal.

The reviewed representation is a closed private enum owned by the root viewer
package:

```moonbit nocheck
priv enum EditorContributionInstance {
  ContentHover(@hover_browser.ContentHoverController)
  Folding(@folding_browser.FoldingController)
  AgentFeedbackInput(@agent_feedback_browser.AgentFeedbackEditorInputContribution)
  AgentFeedbackWidget(@agent_feedback_browser.AgentFeedbackEditorWidgetContribution)
  QuickDiff(QuickDiffContributionState)
}

priv struct EditorContributionEntry {
  id : String
  instance : EditorContributionInstance
  listeners : Array[@base_common.Disposable]
}
```

`QuickDiffContributionState` is a private root-package struct containing the
existing `EditorDecorationsCollection` and listener array currently captured
by the registration closure. The inventory must record why a closed enum is
appropriate for the current statically registered MoonBit product. If a
language limitation prevents this exact representation, the alternative must
still store the concrete instance only once in the central registry; a second
map or id-keyed singleton is rejected.

The actual `Viewer.contributions` map uses private
`EditorContributionEntry`. The current public `EditorContribution` remains a
temporary presence/lifecycle facade adapted from a found entry, so this plan
does not pre-empt the later public-API decision or expose the private enum.
Executable exact-type probes proved the private entry/map and the optional
opaque-public-carrier representation compile without a package cycle.

Construction is obligatorily two-phase per row: reject duplicate id before
side effects; construct bare state; insert it into the Viewer's actual map;
then install listeners and run initial sync/model work. Input, widget, and
folding initializers synchronously use their typed accessor, so assigning a
locally built map only after `instantiate_all` returns is a correctness bug.

**Review gate: stop here. Do not change contribution storage until the
inventory, representation spike, and lifetime trace have been reviewed.**

## Target Architecture

- `Viewer.contributions` is the only instance map.
- Each private `EditorContributionEntry` contains its id and one typed
  `EditorContributionInstance`.
- Disposal dispatches through the typed instance and its owned disposable
  store; it does not find state by id.
- Root feature accessors match the central map entry and enum variant, giving
  the MoonBit equivalent of Monaco's typed `getContribution<T>` cast.
- Feature controller constructors return their concrete controller directly.
- `attach/get/detach` and all four module-level maps disappear.
- Model-scoped reset remains on the controller that owns the state; viewer
  model-change glue invokes that controller through the central entry.

The process-wide registry of contribution *descriptions* remains. It contains
constructors, not per-editor state.

## Milestone B: Add Typed Central Storage

1. Introduce the private contribution-instance enum and private central entry;
   keep the current `EditorContribution` only as the temporary public facade.
2. Add private typed accessors on `Viewer`, one per contribution variant.
3. Make registry construction reject duplicates before construction, insert
   each bare entry before typed initialization, and move lifecycle dispatch
   (`dispose`, and any existing model hooks) onto the instance/entry.
4. Preserve the existing `Viewer::get_contribution(id)` presence behavior
   temporarily so this plan does not decide the public facade.
5. Add registry tests for duplicate ids, known/unknown lookup, construction
   order, and exactly-once disposal.

Use quick diff first to prove the central representation before moving a
controller with extensive state.

Gate:

- `moon check --target all`
- `viewer/editor_extensions_wbtest.mbt`
- quick-diff unit/browser tests
- `just check`

Commit the central storage plus first migrated contribution as one milestone.

## Milestone C: Migrate Hover

1. Replace `ContentHoverController::attach` with a normal primary constructor.
2. Store the returned controller in the central contribution entry.
3. Rewrite all root hover glue to use the typed central accessor.
4. Move timers, request cancellation, decoration cleanup, and widget disposal
   into controller disposal/reset methods where they are not already owned.
5. Delete `instances`, `get`, and `detach` from the hover package.

Preserve request-generation, timer-cancellation, model-swap, and dispose order.
Run all hover reference, white-box, async freshness, and browser behavior tests
before committing.

## Milestone D: Migrate Folding

1. Construct `FoldingController` directly into the central entry.
2. Make its listener store and model-scoped objects dispose/reset from that
   instance.
3. Rewrite commands and root host glue to use the central typed accessor.
4. Delete `folding_instances`, `attach`, `get`, and `detach`.

Preserve hidden-area clearing, decoration cleanup, provider cancellation, and
listener order. Run folding model/controller and browser gutter tests.

## Milestone E: Migrate Agent Feedback

Migrate input and widget contributions as separate green commits because they
share significant root host files:

1. return each concrete controller from its primary constructor;
2. store it in the central entry;
3. rewrite root host accessors and model-swap resets;
4. delete `input_instances`/`widget_instances` and their attach/get/detach
   methods;
5. verify decoration ownership, widget teardown, drafts, selection suppression,
   and service subscriptions.

No process-global mutable contribution state remains after this milestone.

## Milestone F: API, Docs, and Historical Supersession

1. Run `moon ide analyze` and make the central enum/registry internals private.
2. Change touched primary constructors to `Type::Type`.
3. Update `docs/architecture.md` so controller access points to the central
   contribution map rather than feature-local instance tables.
4. Add a dated superseding note in current architecture documentation linking
   to this plan; do not edit the implemented ownership plan.
5. Update contribution package READMEs and generated interfaces.
6. Hand the public status of `EditorContribution`,
   `EditorContributionInstantiation`, and `Viewer::get_contribution` to
   `viewer-public-editor-api-boundary.md`.

## Lifetime and Behavior Matrix

Required cases:

- two viewers alive concurrently with independent controller state;
- known and unknown contribution ids;
- construction order and exactly-once construction;
- model attach, model swap, model removal, reattach, viewer dispose;
- dispose during pending hover/token/provider work;
- hover timers/requests/decorations;
- folding listeners/hidden ranges/decorations;
- feedback input selection/decorations and widget drafts/highlights;
- quick-diff decorations/listeners;
- contribution callback triggered during viewer disposal.

Required validation:

- `moon check --target all`
- targeted contribution white-box/reference tests after each migration
- `just check`
- `just test`
- `just build`
- `just test-browser`

## Exit Criteria

- [ ] inventory rows equal scoped source members; final totals are recorded
- [ ] `Viewer.contributions` is the only per-editor contribution instance map
- [ ] all five registered contributions store their actual typed instance in
      the central entry
- [ ] no feature-local `Map[String, Controller]` remains
- [ ] no attach/get/detach lookup by editor id remains
- [ ] construction, model-swap, and disposal order match the reviewed trace
- [ ] two-viewer isolation and exactly-once disposal tests pass
- [ ] architecture/current READMEs describe the new owner; historical plans
      remain unchanged
- [ ] all deviations are recorded and seam-based
- [ ] closing complete-source reread finds no unaccounted member
- [ ] required validation is green

## Cross-Plan Coordination

Execute this plan before `viewer-public-editor-api-boundary.md`, which removes
or reshapes the public contribution facade. Do not run contribution milestones
in parallel: they share `viewer/editor_extensions.mbt`, `viewer/viewer.mbt`,
model lifecycle paths, root host files, and registry tests.
