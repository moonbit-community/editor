# Viewer Model Lifecycle and Service Ownership Parity

Status: proposed — Phase 0 drafted; inventory pending

Date: 2026-07-10

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Findings: P1-04, P1-05

No product code may be changed until the inventory and equal-size parity ledger
in this plan are completed, committed, and reviewed.

## Goal

Make model attach/detach, marker-decoration ownership, external subscriptions,
DOM teardown, and injected-service ownership follow one explicit lifecycle.
Attaching a Viewer must not delete host-owned diagnostics. Detaching or
disposing must release every Viewer-owned resource without disposing services
that the caller may share with another Viewer.

## Scope (Phase 0)

### Pinned Monaco source

Read these complete source units or complete named method clusters:

- vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts
  - constructor subscription-registration cluster;
  - setModel, _attachModel, _detachModel, _postDetachModelCleanup,
    _createView, and dispose;
  - ModelData construction and disposal.
- vscode/src/vs/editor/browser/widget/codeEditor/codeEditorContributions.ts
  - contribution collection initialization, lifecycle, and disposal cluster;
    lazy instantiation timing is an excluded sibling.
- vscode/src/vs/editor/browser/view.ts
  - complete construction, owned-DOM registration, ViewPart disposal, and
    root-node disposal cluster; render behavior is an excluded sibling.
- vscode/src/vs/editor/common/services/markerDecorationsService.ts
  - complete source unit.
- vscode/src/vs/editor/common/services/markerDecorations.ts
  - complete service contract.
- vscode/src/vs/editor/browser/services/markerDecorations.ts
  - complete per-model decoration owner.
- vscode/src/vs/base/browser/globalPointerMoveMonitor.ts
  - complete monitor lifecycle.
- vscode/src/vs/base/browser/ui/scrollbar/abstractScrollbar.ts
  - complete slider-drag monitor ownership and cleanup cluster only.
- vscode/src/vs/editor/browser/config/editorConfiguration.ts
  - configuration/font subscription ownership and disposal cluster only.

The inventory must explicitly name excluded sibling methods when a file is
scoped to a method cluster.

### Local ownership

Inventory at least:

- viewer/viewer.mbt
- viewer/services.mbt
- viewer/attach_model.mbt
- viewer/input.mbt
- viewer/browser/controller/scrollbar_input.mbt
- viewer/browser/controller/mouse_handler.mbt
- viewer/browser/config/font_measurements.mbt
- viewer/browser/view/view.mbt
- viewer/browser/view/README.md
- viewer/common/markers/marker_service.mbt
- viewer/common/markers/marker_decorations.mbt
- viewer/common/markers/marker_decorations_service.mbt
- viewer/common/markers/README.md
- viewer/README.md

Also inventory every disposable stored in ModelData, every subscription created
by Viewer::Viewer or Viewer::attach, every global document/window listener, and
every DOM node whose lifetime is owned by attach or by the per-model View.

### Explicitly out of scope

- inlay/hover request cancellation and freshness;
- cursor-event semantics and keyboard commands;
- ViewPart invalidation and measured geometry;
- scrollbar pointer behavior other than monitor ownership/cleanup;
- marker rendering style and range arithmetic;
- changing the external ViewerServices API unless ownership cannot be expressed
  without a minimal contract change.

## Initial Decision Register

| Behavior | Decision |
|---|---|
| Attaching a model clears MarkerService data for that URI | REQUIRED PARITY: remove this behavior |
| Marker decorations seed from existing MarkerService data on model add | REQUIRED PARITY |
| Every detached model is removed from MarkerDecorationsService, including None detach, same-URI replacement, model disposal, and Viewer disposal | REQUIRED PARITY |
| Replacing a same-URI per-model decoration owner disposes the old owner first | REQUIRED PARITY |
| MarkerDecorationsService.dispose disposes all per-model owners | REQUIRED PARITY |
| Viewer-owned listeners/subscriptions are retained and disposed exactly once | REQUIRED PARITY |
| Caller-injected services are disposed by Viewer.dispose | REQUIRED PARITY: do not dispose them |
| Per-model View DOM is removed at detach and Viewer-owned attach DOM is removed at Viewer disposal | REQUIRED PARITY |

These rows seed the later member ledger; they do not replace the complete
source-unit inventory.

## Inventory and Parity Ledger (Phases 1–2)

The inventory agent must add:

- every field and disposable in Monaco ModelData and the local ModelData;
- the complete attach/detach order, including event order and cleanup order;
- marker service add/remove/dispose branches and transient-resource rules;
- subscription ownership for configuration/font, marker changes, document
  pointer movement, model events, View events, and contributions;
- DOM removal and placeholder/container state transitions;
- repeated-dispose and partial-attach early returns.

Record the final member count and create exactly one ledger row per member.
Statuses start as TODO and may end only as PORTED, TESTED, PASS,
DEFERRED (reason), or N-A (reason).

Review gate: stop after the inventory/ledger documentation commit.

## Test-Authority Corrections

- viewer/set_value_api_wbtest.mbt currently explains that attach clears marker
  data. That comment and any expectation derived from it are not authoritative.
- Existing tests that inject markers only after set_model do not cover preload.
- Existing dispose tests do not establish shared-service ownership or global
  listener cleanup.

Do not rewrite these expectations until the inventory review approves the
source contract.

## Required Test Matrix (Phase 4)

Package/white-box tests:

- MarkerService preload/change/remove behavior;
- MarkerDecorationsService add/remove/replace/dispose ownership;
- model.on_will_dispose and per-model decoration-owner disposal;
- exact upstream tests use reference naming; source-derived cases use ordinary
  local test filenames.

Headless Viewer integration:

- markers preloaded before set_model survive attach and seed decorations;
- set_value destroys model decorations and correctly re-seeds them from the
  unchanged MarkerService store;
- Some(A) to None removes A;
- Some(A) to Some(B) removes A and seeds B;
- same URI but distinct model instances dispose A's decoration owner before
  registering B;
- Viewer.dispose is idempotent.

Browser/component tests:

- model View DOM and placeholder/container nodes have the expected lifetime;
- document-level drag listeners and font/marker callbacks cannot schedule work
  after Viewer disposal;
- two Viewers sharing one ViewerServices instance remain independent when one
  Viewer is disposed;
- focus and model-change event ordering remain compatible with the pinned
  codeEditorWidget method cluster.

## Milestones

1. Inventory and ledger only; commit and stop for review.
2. Add corrected source-derived marker/model-lifecycle tests; use reference
   naming only when an exact upstream test is ported, and do not commit a
   failing milestone.
3. Port marker add/remove/dispose ordering and ModelData cleanup.
4. Replace permanent document callbacks with a disposable monitor lifecycle;
   retain and release all Viewer-owned subscriptions.
5. Correct ViewerServices ownership and Viewer DOM teardown.
6. Update viewer/README.md and viewer/common/markers/README.md with the landed
   ownership contract.
7. Run focused tests and all repository quality gates.
8. Independent source/ledger/diff/test review.

## Exit Gate

- [ ] inventory rows equal ledger rows
- [ ] marker preload and all detach paths are tested
- [ ] shared-service disposal is tested
- [ ] every Viewer-owned subscription is named and disposed
- [ ] no caller-owned service is disposed by Viewer
- [ ] DOM cleanup and callback-after-dispose are browser-tested
- [ ] all deviations have reviewed seam-based reasons
- [ ] just check, just test, just build, and just test-browser pass
- [ ] independent closing reread finds no unaccounted scoped member

## Deviations (Phase 3)

No deviation is approved yet. Populate this section only after the inventory
review, with one source-member row and one concrete ownership/runtime seam for
every deviation.

## Execution Record

Not started. Append dated inventory, approval, implementation commits,
validation results, and final ledger totals here. Freeze after implementation.
