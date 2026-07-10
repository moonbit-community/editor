# Viewer ViewZones Parity

Status: proposed — Phase 0 drafted; inventory pending

Date: 2026-07-10

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Finding: P1-10

Depends on: viewer-model-lifecycle-ownership-parity.md,
viewer-render-invalidation-parity.md, and viewer-browser-geometry-parity.md

No product code may be changed until the complete ViewZones inventory and
equal-size ledger are committed and reviewed.

## Goal

Port the complete readonly-applicable ViewZones source unit: API ownership,
model lifetime, layout ordering, DOM ownership, width/visibility, callback
timing, and exception containment. A host-supplied zone node must keep its
class/style/content, and one bad host callback must not abort the editor frame.

Because the P1 defects sit inside one tightly coupled source unit, this child
must inventory the adjacent ordinal, model-swap, height-callback, overflow, and
API-shape branches even where their initial audit severity was P2. They may not
be silently left outside a symptom-only fix.

## Scope (Phase 0)

### Pinned Monaco source

- vscode/src/vs/editor/browser/viewParts/viewZones/viewZones.ts
  - complete source unit, including ViewZones class, zone records, safe
    callbacks, add/remove/layout, render, width, visibility, and DOM ownership.
- vscode/src/vs/editor/common/viewLayout/linesLayout.ts
  - complete ViewZone insertion/removal/ordinal/height and viewport-data
    clusters.
- vscode/src/vs/editor/browser/editorBrowser.ts
  - complete IViewZone and IViewZoneChangeAccessor contracts.
- vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts
  - complete changeViewZones method and accessor transaction only. Model
    attach/detach methods belong to the lifecycle plan and are referenced here
    as a landed dependency contract, not duplicated ledger rows.
- vscode/src/vs/editor/common/viewModel/viewModelImpl.ts
  - complete changeWhitespace/ViewZonesChanged plus hidden-area/model-position
    visibility clusters consumed by ViewZones.
- vscode/src/vs/editor/common/viewModelEventDispatcher.ts
  - complete ViewZonesChanged outgoing-event contract and dispatch cluster;
    cursor/configuration/decorations sibling events are excluded.

### Local ownership

- viewer/view_zones_host.mbt
- viewer/viewer.mbt
- viewer/attach_model.mbt
- viewer/browser/view_parts/view_zones/view_zones.mbt
- viewer/browser/view/view.mbt
- viewer/browser/view_parts/view_zones/view_zones.css
- viewer/browser/view_parts/view_zones/README.md
- viewer/common/view_layout/view_zone.mbt
- viewer/common/view_layout/view_layout.mbt
- viewer/common/view_layout/lines_layout.mbt
- viewer/common/view_model/viewport_data.mbt
- viewer/browser/view/view_part.mbt
- tests/browser/component/viewer_api.spec.js
- tests/browser/component/model_swap.spec.js
- tests/browser/moonbit/model_swap/model_swap_scenario.mbt

Inventory every zone field, default, generated ID, ordering key, mutable
property reread, layout/height conversion, DOM/margin node, callback, try/catch,
width, hidden-area rule, render/offscreen state, and model/dispose transition.

### Explicitly out of scope

- content widgets and overlay widgets;
- variable line height outside zone-owned heightInLines/heightInPx semantics;
- minimap, overview ruler, and glyph-margin lanes;
- edit operations and hidden-area producers such as folding, except the
  visibility query consumed by ViewZones;
- general scrollbar behavior, while retaining the source zone-width dependency
  on scroll/content width.

## Initial Decision Register

| Behavior | Decision |
|---|---|
| mount replaces the entire host class attribute | REQUIRED PARITY: preserve host class |
| render replaces the entire host style attribute | REQUIRED PARITY: write only source-owned properties |
| onComputedHeight/onDomNodeTop exceptions abort render | REQUIRED PARITY: contain and report |
| onComputedHeight fires on every visible render | REQUIRED PARITY: use source timing |
| zone CSS forces overflow hidden | REQUIRED PARITY unless the exact source-owned wrapper proves otherwise |
| zone width ignores scroll/content maximum | REQUIRED PARITY |
| zones survive Some(A) to Some(B) model replacement | REQUIRED PARITY: resolve against source model lifetime |
| same-anchor ordering uses height/ID instead of ordinal/afterColumn | REQUIRED PARITY |
| local caller supplies ID and update replaces the whole record | inventory-required decision for complete API parity |
| missing afterColumn, heightInLines, minWidth, marginDomNode, hidden-area, and ordinal fields | inventory-required PORTED/DEFERRED/N-A decisions |

This register is not the parity ledger and does not count toward the
source-member denominator.

## Inventory and Parity Ledger (Phases 1–2)

This child requires a full source-unit denominator, not a P1-only checklist.
The inventory must enumerate:

- public interfaces and every optional field/default;
- ID generation and change-accessor transaction lifetime;
- all DOM nodes and which attributes/properties Monaco owns;
- insertion and same-anchor ordering;
- height calculation, minWidth, scrollWidth/contentWidth, hidden-area, and
  offscreen branches;
- callback call sites, argument arithmetic, exception handling, and error
  reporting;
- model attach/detach and editor disposal behavior.

Record member and ledger totals, then stop for review.

Review gate: stop after the inventory/ledger documentation commit.

## Test-Authority Corrections

- tests/browser/component/model_swap.spec.js currently states that registered
  ViewZones re-mount across model replacement. That expectation must be checked
  against codeEditorWidget before it can remain.
- Existing viewer_api zone tests assert text/top/height but do not verify host
  class/style preservation, width, callback counts, errors, ordinal, or
  hidden-area behavior.
- Local layout tests with only anchor_line and height_px do not establish the
  complete source contract.
- viewer/common/view_layout/lines_layout_reference_test.mbt is pinned to the
  old 294fb350 oracle and covers only the uniform-height subset. Its scoped
  cases must be reconciled against b18492a, and omitted custom-line-height
  cases require explicit DEFERRED/N-A rows.

## Required Test Matrix (Phase 4)

Package/white-box tests:

- add/remove/layout transaction semantics and generated IDs;
- heightInPx, heightInLines, minimum height, and line-height changes;
- same anchor with ordinal/afterColumn/default ordering;
- top, middle, bottom, empty-document, and hidden-area anchors;

Use reference filenames only for exact upstream linesLayout/viewZones tests
ported with original labels/path/current pin. Source-derived local cases use
ordinary test filenames.

Headless Viewer integration:

- layout/model state for Some(A) to Some(B), detach to None, model disposal,
  and Viewer disposal;
- zone registry and line-layout state without claiming DOM or callback-frame
  behavior.

Browser/component:

- caller class names, inline styles, content, event handlers, and descendant
  state survive mount/render;
- source-owned top/height/display/width properties update correctly;
- marginDomNode and main domNode placement where in scope;
- zone covers the required content/scroll width;
- overflow behavior matches source;
- throwing callbacks are reported but do not abort the frame;
- callback counts for add, explicit layout, height change, static
  scroll/render, parked/visible transition, and removal;
- callback throws before/after another zone and later ViewParts plus the frame
  reporter still commit;
- DOM order equals layout/ordinal order.

## Milestones

1. Complete source-unit inventory and ledger; commit and stop.
2. Reconcile and port exact upstream line-layout/API tests; use ordinary local
   tests for source-derived cases with no upstream suite.
3. Correct zone model lifetime and change-accessor semantics.
4. Port DOM ownership, safe callbacks, visibility, width, and render timing.
5. Add browser DOM ownership/error/ordering/width conformance matrix.
6. Update view-zones and view-layout package contracts.
7. Run focused and full quality gates.
8. Independent source/ledger/diff/test review.

## Deviations (Phase 3)

No product reduction is pre-approved. Editable-editor dependencies may receive
DEFERRED/N-A rows only after the complete source member is inventoried and the
readonly seam is concrete.

## Exit Gate

- [ ] complete source-unit inventory rows equal ledger rows
- [ ] host DOM ownership is preserved
- [ ] callbacks have source timing and exception containment
- [ ] model lifecycle matches codeEditorWidget
- [ ] same-anchor ordering matches ordinal/afterColumn semantics
- [ ] every public API field has PORTED/TESTED/DEFERRED/N-A status
- [ ] browser width/visibility/overflow behavior is measured and green
- [ ] all repository quality gates pass
- [ ] independent closing reread finds no unaccounted scoped member

## Execution Record

Not started. Append dated inventory, approval, implementation commits,
validation results, and final ledger totals here. Freeze after implementation.
