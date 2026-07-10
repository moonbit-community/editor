# Viewer Async Model Features Parity

Status: proposed — Phase 0 drafted; inventory pending

Date: 2026-07-10

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Finding: P1-03

Depends on: viewer-model-lifecycle-ownership-parity.md. The later EOL plan must
land before provider-surface/P2 work, but does not block request cancellation.

No product code may be changed until the inventory and equal-size parity ledger
are committed and reviewed.

## Goal

Give every model-scoped inlay and hover request an explicit cancellation and
freshness lifetime. Results from old content, an old model instance, or an old
operation must be unable to overwrite the active model even when URI and host
version values are reused.

## Scope (Phase 0)

### Pinned Monaco source

- vscode/src/vs/editor/contrib/inlayHints/browser/inlayHintsController.ts
  - complete controller model/content/provider-change, scheduling,
    cancellation, request, apply, and disposal clusters;
  - rendering/style command clusters are sibling inventory rows but may be
    excluded with explicit reasons if they do not affect request lifetime.
- vscode/src/vs/editor/contrib/inlayHints/browser/inlayHints.ts
  - complete InlayHintsFragments request, cancellation, result, and disposal
    cluster; rendering commands are excluded siblings.
- vscode/src/vs/editor/contrib/hover/browser/contentHoverController.ts
  - complete model/content/configuration subscription and cancel/hide/react
    cluster.
- vscode/src/vs/editor/contrib/hover/browser/contentHoverWidgetWrapper.ts
  - complete hover-operation start/cancel/dispose and model-change cluster.
- vscode/src/vs/editor/contrib/hover/browser/hoverOperation.ts
  - complete token, scheduling, cancellation, async-item, completion, and
    disposal state machine.
- vscode/src/vs/editor/contrib/hover/browser/contentHoverComputer.ts
  - complete participant computation and cancellation-token propagation
    cluster.
- vscode/src/vs/editor/contrib/hover/browser/getHover.ts
  - complete provider invocation/cancellation cluster; scoring, ordering, and
    aggregation remain inventoried sibling rows deferred to the P2 provider
    plan.
- vscode/src/vs/editor/contrib/hover/browser/hoverTypes.ts
  - cancellation-bearing hover participant/computer contracts consumed by the
    request chain; rendering-only types are excluded siblings.
- vscode/src/vs/editor/common/model/textModel.ts
  - complete getVersionId/version-increment identity facts only. setValue and
    buffer/event arithmetic belong to the EOL plan; tokenization forwarding
    belongs to the tokenization plan.
- vscode/src/vs/base/common/cancellation.ts
  - only the complete token-source lifecycle consumed by the scoped
    controllers; list excluded sibling utilities.

### Local ownership

- viewer/common/model/text_model.mbt
- viewer/registry.mbt
- viewer/editor_events.mbt
- viewer/viewer.mbt
- viewer/attach_model.mbt
- viewer/inlay_hints_host.mbt
- viewer/hover_contribution.mbt
- viewer/contrib/hover/hover_controller.mbt
- viewer/contrib/hover/hover_participants.mbt
- viewer/contrib/hover/browser/content_hover_controller.mbt
- viewer/contrib/hover/hover_reconciliation_wbtest.mbt
- language/inlay_hints.mbt
- language/cancellation.mbt
- viewer/common/languages/languages.mbt

Inventory every async_run launch, model/content subscription, operation token,
deferred mouse-react task, request result guard, controller reset, decoration
apply, and dispose path.

### Explicitly out of scope

- provider selector scoring, registry ordering, and multi-provider hover
  aggregation;
- inlay label-part, command, resolve, and public API expansion;
- hover DOM/CSS, copy affordance, resize layout, and status bar;
- marker lifecycle;
- semantic token requests;
- introducing a general async framework beyond the minimum cancellation
  primitive required by the scoped state machines.

## Initial Decision Register

| Behavior | Decision |
|---|---|
| URI plus host version alone identifies a live model request | REQUIRED PARITY: insufficient |
| set_value invalidates all older inlay requests | REQUIRED PARITY |
| model replacement invalidates hover and inlay work even for the same URI/version | REQUIRED PARITY |
| old async completion can update controller data or injected decorations | REQUIRED PARITY: forbidden |
| content change cancels the pending hover mouse-react runner | REQUIRED PARITY |
| request/provider failures remain contained and logged | REQUIRED PARITY |
| provider scoring and full public provider API | DEFERRED to the P2 provider plan |

This register is not the parity ledger and does not count toward the
source-member denominator.

## Inventory and Parity Ledger (Phases 1–2)

The inventory must enumerate:

- every freshness fact Monaco relies on: model object, version ID, request
  generation, cancellation token, and operation token;
- cancellation/disposal ordering for model change, content change, new
  request, provider change, contribution dispose, and Viewer dispose;
- every async callback and the exact guards before it mutates controller,
  model decorations, hover state, or DOM scheduling;
- hover synchronous versus asynchronous item ordering;
- error, empty-result, canceled-result, and completion branches.

Each member receives one ledger row. The review must decide whether the local
model identity helper is removed, strengthened, or replaced by explicit
captured model identity plus internal version ID. Convenience is not a reason
to diverge from source request lifetime.

Review gate: stop after the inventory/ledger documentation commit.

## Test-Authority Corrections

- viewer/common/model/text_model_test.mbt currently expects a different model
  revision/instance with the same URI and host version to pass the freshness
  guard. That expectation must be treated as a test bug for async ownership.
- Existing hover reconciliation tests cover operation sequencing inside one
  active model but do not prove model/content cancellation.
- Existing inlay tests mostly install resolved hints directly and do not cover
  request races.

## Required Test Matrix (Phase 4)

Package/white-box tests cover HoverOperation, cancellation tokens,
InlayHintsFragments, and controller state machines with controlled deferred
results.

Headless Viewer integration must control request completion order:

- request A starts, set_value occurs, request B starts, then A completes last;
- model A request starts, same-URI model B attaches, then A completes;
- model A and B reuse the same host version and first operation token;
- canceled provider returns Some, None, or throws after cancellation;
- new hover target cancels the previous operation;
- content change occurs before a delayed mouse-react callback;
- detach to None and Viewer.dispose occur while work is outstanding;
- a valid newest request still applies hints and decoration changes once.

Assert both positive and negative effects: controller state, injected
decorations, hover notification, render scheduling, and log containment.
Prefer deterministic deferred promises/test providers over timing sleeps.

Browser/component tests cover same-URI model replacement while hover/inlay work
is pending and assert that no stale visible widget or decoration is committed.
They do not use sleeps as the completion oracle.

## Milestones

1. Inventory and ledger only; commit and stop.
2. Add deterministic cancellation/race fixtures and corrected freshness tests.
3. Port model/content/request cancellation for inlay hints.
4. Port hover operation and pending-react cancellation across model/content
   changes.
5. Unify result guards around model identity, internal content version, request
   generation, and cancellation state.
6. Update viewer and relevant hover/inlay package contracts.
7. Run focused tests and all repository quality gates.
8. Independent source/ledger/diff/test review.

## Deviations (Phase 3)

None approved yet. Populate only after the inventory review.

## Exit Gate

- [ ] inventory rows equal ledger rows
- [ ] all completion-order permutations are deterministic and tested
- [ ] same-URI/same-host-version replacement cannot accept old results
- [ ] set_value cannot accept an older inlay result
- [ ] pending hover reaction is canceled on content/model changes
- [ ] detach and dispose cancel all scoped work
- [ ] provider errors remain contained
- [ ] all deviations have reviewed reasons
- [ ] all repository quality gates pass
- [ ] independent closing reread finds no unaccounted scoped member

## Execution Record

Not started. Append dated inventory, approval, implementation commits,
validation results, and final ledger totals here. Freeze this file after it is
marked implemented.
