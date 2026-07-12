# Viewer ViewZones Parity

Status: approved for implementation

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
- vscode/src/vs/editor/browser/view.ts
  - complete ViewZones DOM-attachment cluster only: margin-zone container
    placement/order, content-zone container placement/order, and the
    `shouldSuppressMouseDownOnViewZone` view-helper delegation; complete
    `View.change` ViewZones transaction/render-scheduling handoff. Other
    ViewPart construction and DOM siblings retain their owning frozen plans.
- vscode/src/vs/editor/browser/controller/mouseHandler.ts
  - complete view-zone mouse-down suppression branch and the corresponding
    helper contract only; all other pointer targeting/selection siblings retain
    frozen cursor/input ownership.
- vscode/src/vs/editor/common/viewLayout/linesLayout.ts
  - complete ViewZone insertion/removal/ordinal/height and viewport-data
    clusters.
- vscode/src/vs/editor/common/viewLayout/viewLayout.ts
  - complete whitespace-facing ViewLayout cluster: `saveState`'s zone
    correction, `changeWhitespace`, zone-aware vertical-offset delegates,
    whitespace hit/viewport/all-data accessors, and the LinesLayout viewport
    handoff. General scroll/content dimension formulas remain frozen browser-
    geometry ownership; this child consumes only the whitespace-minimum-width
    handoff without duplicating those rows.
- vscode/src/vs/editor/common/viewModel.ts
  - complete `IEditorWhitespace`, `IWhitespaceChangeAccessor`,
    `IPartialViewLinesViewportData`, and `IViewWhitespaceViewportData`
    contracts consumed by the scoped layout and ViewZones units.
- vscode/src/vs/editor/browser/editorBrowser.ts
  - complete IViewZone and IViewZoneChangeAccessor contracts plus the
    `ICodeEditor.onDidChangeViewZones` and `changeViewZones`/model-loss public
    contracts.
- vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts
  - complete `changeViewZones` method plus the `onDidChangeViewZones` emitter,
    public event alias, and outgoing-event dispatch arm. Model attach/detach
    methods belong to the lifecycle plan and are referenced here as a landed
    dependency contract, not duplicated ledger rows.
- vscode/src/vs/editor/common/viewModel/viewModelImpl.ts
  - complete changeWhitespace/ViewZonesChanged plus hidden-area/model-position
    visibility clusters consumed by ViewZones.
- vscode/src/vs/editor/common/coordinatesConverter.ts and
  vscode/src/vs/editor/common/viewModel/viewModelLines.ts
  - complete `modelPositionIsVisible` interface/identity/projected/delegation
    chain consumed by ViewZones, including projected hidden-decoration
    disposal and the identity collection's no-op disposal. Other converter
    position/range methods remain frozen cursor/input ownership and are
    explicit excluded siblings.
- vscode/src/vs/editor/common/viewModelEventDispatcher.ts
  - complete ViewZonesChanged outgoing-event contract and dispatch cluster;
    cursor/configuration/decorations sibling events are excluded.
  - the local implementation may widen the existing cursor-owned
    outgoing-only pending queue with the ViewZones arm. The frozen mixed
    view/outgoing collector, consumption-postponement, and cross-queue
    reentrancy rows remain RVC-owned and are not claimed here.

### Local ownership

- viewer/view_zones_host.mbt
- viewer/viewer.mbt
- viewer/attach_model.mbt
- viewer/browser/view_parts/view_zones/view_zones.mbt
- viewer/browser/view/view.mbt
- viewer/browser/controller/mouse_handler.mbt
- viewer/browser/view_parts/view_zones/view_zones.css
- viewer/browser/view_parts/view_zones/README.md
- viewer/common/view_layout/view_zone.mbt
- viewer/common/view_layout/view_layout.mbt
- viewer/common/view_layout/lines_layout.mbt
- viewer/common/view_layout/lines_layout_reference_test.mbt
- viewer/common/view_model/viewport_data.mbt
- viewer/common/view_model/visible_ranges.mbt
- viewer/common/view_model/view_model_lines_projected.mbt
- viewer/common/view_model/hidden_areas.mbt
- viewer/common/view_model/view_model.mbt
- viewer/common/view_model/cursor_transitions.mbt
- viewer/common/view_model/cursor_event_dispatcher.mbt
- viewer/common/view_model/cursor_event_dispatcher_wbtest.mbt
- viewer/browser/view/view_overlays.mbt
- viewer/browser/view/view_lifecycle_wbtest.mbt
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

Gate A resolves the inventory-required decisions as follows:

- the public MoonBit API keeps MoonBit-owned names but adopts the complete
  source shape: one mutable zone delegate, source-generated IDs,
  `add_zone`/`remove_zone`/`layout_zone`, accessor invalidation, and no
  whole-record update operation;
- every model replacement or detach destroys the current model-scoped zone
  registry; zones are not persistent editor widgets;
- `after_column`, affinity, hidden-area visibility, ordinal, both height
  forms, minimum width, margin DOM, and mouse suppression are REQUIRED PARITY;
- `height_in_px`, `height_in_lines`, and `min_width_in_px` use `Double`, as do
  the computed-height callback values. The callback observes the raw source
  number; LinesLayout independently applies portable JavaScript `ToInt32`
  before retaining height/minimum width. This includes fractional, non-finite,
  and signed-32-bit wrap boundaries rather than reducing the public API to
  `Int`;
- Monaco's separate `Margin` part stays structurally merged into the existing
  `MarginViewOverlays` ViewPart. The `.margin` DOM owner, first overflow-child
  placement, zone-before-overlay child order, and existing event/render owner
  remain observable and required; the separate object boundary is a reviewed
  structure-only seam;
- hidden-area contribution keys remain caller-chosen `String` values instead
  of source `unknown` object identity. Distinct strings and same-string
  replacement are required; object-identity keys are an explicit DEFERRED
  public-contract reduction;
- the ViewZones public emitter does not acquire CodeEditorWidget's shared
  cross-event delivery queue. That queue remains lifecycle CEW-001 DEFERRED;
  this child claims only its dedicated emitter/listener behavior;
- callback failures are swallowed and reported through the Viewer log-service
  seam; swallowing without a report is not sufficient;
- custom per-line heights remain DEFERRED because this readonly product has no
  custom-line-height producer. The ordinary current line-height and
  `height_in_lines` recomputation paths are REQUIRED PARITY;
- the projected line collection is the only product line collection, so
  identity-line-only source branches are N-A. Line/column/ordinal inputs remain
  typed MoonBit `Int`; height/minimum-width `|0` coercions remain live because
  those inputs are `Double`;
- `View.change` schedules one render after every completed zone callback,
  including an empty transaction, a missing ID, or a contained callback
  failure. Internal `ViewZonesChanged` delivery precedes the outgoing public
  event only when the whitespace transaction actually changed.

## Inventory and Parity Ledger (Phases 1–2)

One row represents one declared member/field/property, behavior-changing
branch or early return, independently reused magic constant, callback, or
owned DOM/CSS fact. Straight-line allocation and ordinary intermediate
assignments remain on the owning member row. Every row is `TODO` until Gate B
approval and implementation evidence; `Proposed terminal` is a review target,
not current proof.

```text
Browser/API:  VZ 126 + VZA 18 + VAT 7 + VMH 5                   = 156
Layout/model: VC 28 + LL 72 + VL 11 + CC 2 + VML 29 + VI 34    = 176
Outgoing:     CEW 6 + VED 8                                     =  14
                                                                  ---
Total                                                             346

Working:  346 TODO; 0 PASS
Proposed: 287 TESTED + 41 PORTED + 8 DEFERRED + 10 N-A = 346
```

### Source evidence

All hashes are from oracle commit
`b18492a288de038fbc7643aae6de8247029d11bd`.

| Prefix | Pinned source | Scoped lines | File lines | SHA-256 |
|---|---|---:|---:|---|
| VZ | `browser/viewParts/viewZones/viewZones.ts` | complete `1-423` | 423 | `9cb62bb235e89f9432515ff1739987a776f2bbcf4f7819087f01373a7f0e2c77` |
| VZA | `browser/editorBrowser.ts` | `36-121`, `856`, `1215-1218` | 1538 | `27375b22639d3db492cf0dacc3e34a061601171de9692d64e554d3fbfd902429` |
| VAT | `browser/view.ts` | `238-242`, `273-281`, `401-403`, `720-723` | 992 | `22edb04795705b7fc8675ba40d89c448a62141201f1a16b1f20d8b26e82771e2` |
| VMH | `browser/controller/mouseHandler.ts` | `47`, `317`, `337-343` | 749 | `3a07ac0185272ffd9f6b557d18fec24e2b441e2da23ff15c958607fdb809386a` |
| VC | `common/viewModel.ts` | scoped contracts | 447 | `5d7d8cbb89d5ee636263367ed944d2f2754559f7b556f3603c5e974fae329be5` |
| LL | `common/viewLayout/linesLayout.ts` | complete zone/layout clusters | 912 | `2265a18001e0158ec5b0dca17da6385e6101a46f47cbc2830f6a8028a7fdcd71` |
| VL | `common/viewLayout/viewLayout.ts` | whitespace-facing clusters | 490 | `628be8f63ced174d6325773b20cb8bf263ebc073fc19632bd7657300d60c70a3` |
| CC | `common/coordinatesConverter.ts` | visibility contract/identity method | 105 | `7b1d1e7b10a4538a6a8ec25727b3c36aa41cf5f2c75518cf33da2973c7cbf0da` |
| VML | `common/viewModel/viewModelLines.ts` | hidden/visibility/lifetime chain | 1272 | `788d3145d0cea65c1d0ebfe1b2041dbc1e4f4eb4ddb495608c0f5a54748a3262` |
| VI | `common/viewModel/viewModelImpl.ts` | consumed hidden/whitespace clusters | 1472 | `b8b9f80ed51fa64c7baa4589aa99c2e2bab4eb365b025586e78d9b0db8f8e28a` |
| CEW | `browser/widget/codeEditor/codeEditorWidget.ts` | `203-204`, `1654-1659`, `1803-1805` | 2559 | `18dd294ed185a29c590df75656f18f27d0cefc8d4d778559db946d447130e5d8` |
| VED | `common/viewModelEventDispatcher.ts` | `181`, `200`, `349-366` | 591 | `64c5aee53d0bd580e8bb13d6f6ca563fcd02b8f78cf764ed0be87747f7d58448` |

`linesLayout.ts`, its 1244-line upstream test
(`a49ccb881aad985965894ce8b6088d227baad1f03ed2cbb7e9c436b62eafedac`),
and the other layout/model files above are byte-identical between the stale
local reference-test pin `294fb350...` and the current oracle. The local test
header therefore needs a metadata correction, not a behavioral rebase.

### Browser/API ledger

#### `editorBrowser.ts` public contracts — VZA

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VZA-001 | `IViewZone.afterLineNumber` (`:36-41`) | Replace positional `anchor_line`; retain `0` = before first line. | TODO | PORTED |
| VZA-002 | optional `afterColumn` and absent=max-column contract (`:43-47`) | Missing from public/local zone record. | TODO | PORTED |
| VZA-003 | optional `afterColumnAffinity`, default `PositionAffinity.None` (`:49-51`) | Missing field; exact local affinity enum exists. | TODO | PORTED |
| VZA-004 | optional `showInHiddenAreas`, default false (`:53-55`) | Missing field. | TODO | PORTED |
| VZA-005 | optional `ordinal`, default `afterColumn ?? 10000` (`:57-60`) | Missing field; layout already supports whitespace ordinal. | TODO | PORTED |
| VZA-006 | optional `suppressMouseDown`, default false (`:62-66`) | Missing public field; controller helper is hard-coded false. | TODO | PORTED |
| VZA-007 | optional `Double heightInLines`, default 1 when both heights are absent (`:68-72`) | Missing; local accepts only integer pixels. | TODO | PORTED |
| VZA-008 | optional `Double heightInPx`, preferred over `heightInLines` (`:74-78`) | Positional integer `height_px` cannot express absence/precedence/raw number semantics. | TODO | PORTED |
| VZA-009 | optional `Double minWidthInPx` (`:80-83`) | Missing; LinesLayout retains only the post-ToInt32 minimum width. | TODO | PORTED |
| VZA-010 | required caller-owned `domNode` (`:85-87`) | Node exists, but mount overwrites caller class/style. | TODO | PORTED |
| VZA-011 | optional/null `marginDomNode` (`:89-91`) | Missing from local record and View DOM. | TODO | PORTED |
| VZA-012 | optional `onDomNodeTop(top)` callback (`:93-95`) | Callback exists but is not safely invoked. | TODO | PORTED |
| VZA-013 | optional `onComputedHeight(Double rawHeight)` callback (`:97-99`) | Callback is integer-typed and fires at the wrong render-time cadence. | TODO | PORTED |
| VZA-014 | `IViewZoneChangeAccessor.addZone(zone): string` (`:104-110`) | Local requires caller ID and returns Unit. | TODO | PORTED |
| VZA-015 | `removeZone(id)` (`:112-115`) | Local method exists. | TODO | PORTED |
| VZA-016 | `layoutZone(id)` rereads mutable fields (`:117-120`) | Local exposes whole-record `update_zone`. | TODO | PORTED |
| VZA-017 | `ICodeEditor.onDidChangeViewZones` event contract (`:856`) | Missing public event surface. | TODO | PORTED |
| VZA-018 | `ICodeEditor.changeViewZones` and zones-lost-on-new-model contract (`:1215-1218`) | Method exists, but local zones incorrectly survive Some(A)→Some(B). | TODO | TESTED |

#### `view.ts` attachment/helper/transaction clusters — VAT

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VAT-001 | construct the Margin owner and register it in `_viewParts` (`view.ts:238,242`) | Local `MarginViewOverlays` is already the merged `.margin` DOM/ViewPart owner; preserve that reviewed structural seam and its event/render registration. | TODO | TESTED |
| VAT-002 | append `viewZones.marginDomNode` before margin overlays/glyph widgets (`:239-241`) | Add the zone container as the first child of the merged `.margin` owner; absent glyph siblings stay frozen. | TODO | TESTED |
| VAT-003 | append `viewZones.domNode` after overlays/rulers and before ViewLines/widgets/cursors (`:273-280`) | Existing content-zone relative order matches; sibling mounts remain frozen. | TODO | TESTED |
| VAT-004 | append Margin owner to overflow guard first (`:281`) | The merged `.margin` owner is already the first overflow child; retain that placement while adding its zone child. | TODO | TESTED |
| VAT-005 | helper delegates `shouldSuppressMouseDownOnViewZone(id)` (`:401-403`) | Local root helper always returns false. | TODO | TESTED |
| VAT-006 | `View.change(callback)` delegates transaction (`:720-721`) | Local root has an extra changed gate and retainable accessor. | TODO | TESTED |
| VAT-007 | unconditional `_scheduleRender()` after callback (`:722`) | Local skips empty/missing-id batches. | TODO | TESTED |

#### `mouseHandler.ts` view-zone suppression cluster — VMH

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VMH-001 | helper `shouldSuppressMouseDownOnViewZone(id)` (`:47`) | Closure field exists. | TODO | PORTED |
| VMH-002 | target predicate is content or gutter ViewZone (`:317`) | Local predicate matches both variants. | TODO | TESTED |
| VMH-003 | ViewZone arm extracts typed detail (`:337-339`) | Local match provides `view_zone_id`. | TODO | TESTED |
| VMH-004 | short-circuit `shouldHandle && helper(id)` (`:339`) | Control flow matches, helper is hard-coded false. | TODO | TESTED |
| VMH-005 | true-arm focus/start/prevent order (`:340-342`) | Local order matches once live delegation is installed. | TODO | TESTED |

#### `viewZones.ts` complete source unit — VZ

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VZ-001 | `IMyViewZone.whitespaceId` (`:17-18`) | Local caller-supplied `id` bypasses LinesLayout generation. | TODO | PORTED |
| VZ-002 | retained mutable `delegate` (`:19`) | Local flattens a copied record and cannot reread caller mutations. | TODO | PORTED |
| VZ-003 | retained `isInHiddenArea` (`:20,95,241,298,366`) | Missing. | TODO | TESTED |
| VZ-004 | retained `isVisible` (`:21,242,386-395`) | Missing source-shaped transition state. | TODO | TESTED |
| VZ-005 | retained main `domNode` (`:22`) | Local main node exists. | TODO | PORTED |
| VZ-006 | nullable retained `marginDomNode` (`:23`) | Missing. | TODO | PORTED |
| VZ-007 | computed `isInHiddenArea` (`:26-27`) | Missing carrier field. | TODO | PORTED |
| VZ-008 | computed `afterViewLineNumber` (`:28`) | Caller anchor is incorrectly treated as normalized view line. | TODO | PORTED |
| VZ-009 | computed raw-`Double` `heightInPx` (`:29`) | Reduced integer pixel field exists, complete carrier does not. | TODO | PORTED |
| VZ-010 | computed raw-`Double` `minWidthInPx` (`:30`) | Missing bridge. | TODO | PORTED |
| VZ-011 | reusable `invalidFunc` throws `Invalid change accessor` (`:33`) | Accessor remains usable after callback. | TODO | TESTED |
| VZ-012 | private `_zones` id map (`:42`) | Local splits registration array and DOM/style maps. | TODO | PORTED |
| VZ-013 | private `_lineHeight` (`:43,56,111,324,326`) | Not retained by local part. | TODO | PORTED |
| VZ-014 | private `_contentWidth` (`:44,57,112,410`) | Not retained; container width is never set. | TODO | PORTED |
| VZ-015 | private `_contentLeft` (`:45,58,113,411`) | Not retained; margin width is absent. | TODO | PORTED |
| VZ-016 | public content `domNode` (`:47`) | Existing container. | TODO | PORTED |
| VZ-017 | public `marginDomNode` (`:49`) | Missing. | TODO | PORTED |
| VZ-018 | constructor option snapshot/DOM initialization order (`:51-73`) | Local initializes one reduced container. | TODO | TESTED |
| VZ-019 | content class `view-zones` (`:61`) | Local matches. | TODO | TESTED |
| VZ-020 | content `position:absolute` (`:62`) | Local relies on CSS rather than owned property. | TODO | TESTED |
| VZ-021 | content `role=presentation` (`:63`) | Missing. | TODO | TESTED |
| VZ-022 | content `aria-hidden=true` (`:64`) | Missing. | TODO | TESTED |
| VZ-023 | margin class `margin-view-zones` (`:67`) | Missing. | TODO | TESTED |
| VZ-024 | margin `position:absolute` (`:68`) | Missing. | TODO | TESTED |
| VZ-025 | margin `role=presentation` (`:69`) | Missing. | TODO | TESTED |
| VZ-026 | margin `aria-hidden=true` (`:70`) | Missing. | TODO | TESTED |
| VZ-027 | dispose superclass-first then clear zones (`:75-78`) | No explicit part dispose/registry clear. | TODO | TESTED |
| VZ-028 | `_recomputeWhitespacesProps` member (`:82-105`) | Missing. | TODO | TESTED |
| VZ-029 | recompute transaction freezes keys but looks up each zone live (`:89-103`) | Missing exact snapshot/reentrant semantics. | TODO | TESTED |
| VZ-030 | existing whitespace and line-or-height changed gate; `changeOneWhitespace` → computed-height callback → `hadAChange` (`:97-101`) | Missing exact callback gate/order. | TODO | TESTED |
| VZ-031 | configuration option refresh and always-true result (`:107-120`) | Handler only marks dirty. | TODO | TESTED |
| VZ-032 | line-height-changed recomputation (`:115-117`) | Missing. | TODO | TESTED |
| VZ-033 | line-mapping handler delegates recomputation (`:122-124`) | Local returns true without recomputing. | TODO | TESTED |
| VZ-034 | lines-deleted handler always true (`:126-128`) | Local matches. | TODO | TESTED |
| VZ-035 | scrollTop-or-scrollWidth handler (`:130-132`) | Local truth table matches. | TODO | TESTED |
| VZ-036 | zones-changed handler always true (`:134-136`) | Local matches. | TODO | TESTED |
| VZ-037 | lines-inserted handler always true (`:138-140`) | Local matches. | TODO | TESTED |
| VZ-038 | `_getZoneOrdinal` member (`:144-146`) | Missing; local sorts by height/id. | TODO | TESTED |
| VZ-039 | explicit ordinal wins (`:145`) | Missing. | TODO | TESTED |
| VZ-040 | absent ordinal falls back to afterColumn (`:145`) | Missing. | TODO | TESTED |
| VZ-041 | absent ordinal/column uses exact `10000` (`:145`) | Missing constant/default. | TODO | TESTED |
| VZ-042 | `_computeWhitespaceProps` member (`:148-197`) | Missing source model/view/hidden computation. | TODO | TESTED |
| VZ-043 | `afterLineNumber===0` early return (`:149-156`) | Local clamp lacks no-conversion/not-hidden special path. | TODO | TESTED |
| VZ-044 | afterColumn-present versus max-column branch (`:158-174`) | Missing. | TODO | TESTED |
| VZ-045 | before-position next-line/same-line branch (`:176-187`) | Missing. | TODO | TESTED |
| VZ-046 | conversion forwards affinity and `allowZero=true` (`:189`) | Converter exists; ViewZones does not call it. | TODO | TESTED |
| VZ-047 | `showInHiddenAreas \|\| modelPositionIsVisible(before)` (`:190`) | Missing. | TODO | TESTED |
| VZ-048 | hidden flag and visible-height-or-zero result (`:191-196`) | Current zones always displace layout. | TODO | TESTED |
| VZ-049 | `changeViewZones` complete transaction (`:199-232`) | API shape and lifetime diverge. | TODO | TESTED |
| VZ-050 | source-owned whitespace transaction callback (`:202-229`) | Missing direct LinesLayout accessor bridge. | TODO | TESTED |
| VZ-051 | accessor add sets changed then delegates (`:204-208`) | Local add takes caller ID and returns Unit. | TODO | TESTED |
| VZ-052 | accessor remove callback (`:209-214`) | Local transaction/scheduling differs. | TODO | TESTED |
| VZ-053 | remove empty-id early return (`:210-212`) | Missing explicit branch. | TODO | TESTED |
| VZ-054 | remove result aggregation/order (`:213`) | Missing exact contract. | TODO | TESTED |
| VZ-055 | accessor layout callback (`:215-220`) | Missing; update replaces whole record. | TODO | TESTED |
| VZ-056 | layout empty-id early return (`:216-218`) | Missing. | TODO | TESTED |
| VZ-057 | layout result aggregation/order (`:219`) | Missing. | TODO | TESTED |
| VZ-058 | invoke caller through `safeInvoke1Arg` (`:223`) | Direct invocation lets failure escape. | TODO | TESTED |
| VZ-059 | invalidate `addZone` after callback (`:225-226`) | Missing. | TODO | TESTED |
| VZ-060 | invalidate `removeZone` after callback (`:227`) | Missing. | TODO | TESTED |
| VZ-061 | invalidate `layoutZone` after callback (`:228`) | Missing. | TODO | TESTED |
| VZ-062 | `_addZone` complete member (`:234-269`) | Local upsert uses caller identity/replacement semantics. | TODO | TESTED |
| VZ-063 | insert whitespace with ordinal/height/minWidth and generated ID (`:235-236`) | LinesLayout supports it; host rebuild bypasses it. | TODO | TESTED |
| VZ-064 | retained record, `isVisible=false`, exact node wrappers (`:238-245`) | Local omits delegate/hidden/margin/visibility. | TODO | TESTED |
| VZ-065 | nullable margin wrapper ternary (`:244`) | Missing. | TODO | TESTED |
| VZ-066 | after whitespace insertion/node wrapping, add-time safe computed-height callback runs before host style/attributes, mount, zone-map insertion, and dirtying (`:235-266`) | Local fires during each visible render. | TODO | TESTED |
| VZ-067 | main host `position:absolute` (`:249`) | CSS class supplies position but overwrites caller class. | TODO | TESTED |
| VZ-068 | raw main-host `style.width=100%` property write preserves every unrelated inline style (`:250`) | Local rewrites the entire style attribute and omits width. | TODO | TESTED |
| VZ-069 | main display lifecycle none/block (`:251,380-400`) | Local rewrites full style. | TODO | TESTED |
| VZ-070 | main `monaco-view-zone=<id>` lifecycle (`:252,278`) | Local invents `data-view-zone-id`. | TODO | TESTED |
| VZ-071 | main node mount/remove lifecycle (`:253,279`) | Preserve identity/order/attributes. | TODO | TESTED |
| VZ-072 | margin-present setup branch (`:255-261`) | Missing. | TODO | TESTED |
| VZ-073 | margin host `position:absolute` (`:256`) | Missing. | TODO | TESTED |
| VZ-074 | raw margin-host `style.width=100%` property write preserves every unrelated inline style (`:257`) | Missing. | TODO | TESTED |
| VZ-075 | margin display lifecycle (`:258,405`) | Missing. | TODO | TESTED |
| VZ-076 | margin `monaco-view-zone=<id>` lifecycle (`:259,283`) | Missing. | TODO | TESTED |
| VZ-077 | margin mount/remove lifecycle (`:260,284`) | Missing. | TODO | TESTED |
| VZ-078 | add marks dirty after map insertion (`:263-266`) | Root schedules without source-local order. | TODO | TESTED |
| VZ-079 | `_removeZone` complete member (`:271-292`) | Whitespace/DOM cleanup is missing. | TODO | TESTED |
| VZ-080 | owned ID true; missing ID false (`:272-291`) | Found/missing distinction exists, scheduling differs. | TODO | TESTED |
| VZ-081 | main visible attribute transition/cleanup (`:277,386-395`) | Missing. | TODO | TESTED |
| VZ-082 | defensive margin visible-attribute removal (`:282`) | Missing. | TODO | TESTED |
| VZ-083 | margin-present removal branch (`:281-285`) | Missing. | TODO | TESTED |
| VZ-084 | successful remove marks dirty (`:287`) | Root changed gate differs. | TODO | TESTED |
| VZ-085 | `_layoutZone` complete member (`:294-309`) | Whole-record update is not source layout semantics. | TODO | TESTED |
| VZ-086 | owned ID true; missing ID false (`:295-308`) | Missing exact result contract. | TODO | TESTED |
| VZ-087 | recompute hidden/line/height; retain ordinal/minWidth (`:297-301`) | Local replaces record and re-sorts. | TODO | TESTED |
| VZ-088 | layout does `changeOneWhitespace` → computed-height callback → `setShouldRender`, even if unchanged (`:300,303-304`) | Missing cadence/containment/order. | TODO | TESTED |
| VZ-089 | successful layout marks dirty (`:304`) | Missing source-local transition. | TODO | TESTED |
| VZ-090 | suppression lookup member (`:311-317`) | Part has no method. | TODO | TESTED |
| VZ-091 | owned ID reads live boolean; missing/absent false (`:312-316`) | Missing. | TODO | TESTED |
| VZ-092 | `_heightInPixels` member (`:319-327`) | Missing API normalization. | TODO | TESTED |
| VZ-093 | numeric heightInPx wins (`:320-322`) | Required pixels cannot test precedence. | TODO | TESTED |
| VZ-094 | else heightInLines × current lineHeight (`:323-325`) | Missing. | TODO | TESTED |
| VZ-095 | neither height defaults to one line (`:326`) | Missing. | TODO | TESTED |
| VZ-096 | `_minWidthInPixels` member (`:329-334`) | Missing API bridge. | TODO | TESTED |
| VZ-097 | numeric minWidth wins (`:330-332`) | Missing. | TODO | TESTED |
| VZ-098 | absent min width exact `0` (`:333`) | Layout hard-codes 0 but API cannot override. | TODO | TESTED |
| VZ-099 | safe computed-height member (`:336-344`) | Local calls directly. | TODO | TESTED |
| VZ-100 | computed-height callback presence branch (`:337-343`) | Option branch exists only at wrong call site. | TODO | TESTED |
| VZ-101 | computed-height exception reported and swallowed (`:338-342`) | Missing. | TODO | TESTED |
| VZ-102 | safe DOM-top member (`:346-354`) | Local calls directly. | TODO | TESTED |
| VZ-103 | DOM-top callback presence branch (`:347-353`) | Option branch exists. | TODO | TESTED |
| VZ-104 | DOM-top exception reported and swallowed (`:348-352`) | Missing. | TODO | TESTED |
| VZ-105 | `prepareRender` declared no-op (`:356-358`) | Local matches. | TODO | TESTED |
| VZ-106 | `render` complete member (`:360-413`) | Hidden/margin/width/transition/safe callbacks missing. | TODO | TESTED |
| VZ-107 | hidden-area visible-whitespace continue (`:365-368`) | Missing. | TODO | TESTED |
| VZ-108 | callback-before-render frozen key array, live map lookup, and per-zone top/height/display defaults (`:373-380`) | Local iterates a mutable array/index identity and overwrites full style. | TODO | TESTED |
| VZ-109 | visible-zone branch (`:381-390`) | Index path lacks source identity/hidden state. | TODO | TESTED |
| VZ-110 | visible height and `display=block` (`:382-384`) | Values match through synthesized style. | TODO | TESTED |
| VZ-111 | visible DOM top = verticalOffset - bigNumbersDelta (`:382`) | Verify local relative-offset equivalence. | TODO | TESTED |
| VZ-112 | false→true visible attribute then state (`:386-389`) | Missing. | TODO | TESTED |
| VZ-113 | after visible-attribute/state transition, scrolled-top callback runs before main/margin top/height/display writes (`:386-390,398-405`) | Safe wrapper/context semantics and phase order missing. | TODO | TESTED |
| VZ-114 | absent-visible-data/offscreen branch (`:391-397`) | Reduced branch exists. | TODO | TESTED |
| VZ-115 | true→false remove attribute then state (`:392-395`) | Missing. | TODO | TESTED |
| VZ-116 | after hidden visible-attribute/state transition, converted offscreen sentinel `-1000000` callback runs before main/margin writes (`:392-405`) | Local passes a raw sentinel and lacks phase order. | TODO | TESTED |
| VZ-117 | main top property write (`:398`) | Full-style rewrite must become property-owned. | TODO | TESTED |
| VZ-118 | main height property write (`:399`) | Same gap. | TODO | TESTED |
| VZ-119 | margin-present render branch (`:402-406`) | Missing. | TODO | TESTED |
| VZ-120 | margin top mirrors main (`:403`) | Missing. | TODO | TESTED |
| VZ-121 | margin height mirrors main (`:404`) | Missing. | TODO | TESTED |
| VZ-122 | any-visible width-write gate (`:364,369-370,409-412`) | Missing; source retains prior widths when none visible. | TODO | TESTED |
| VZ-123 | content width `max(scrollWidth,contentWidth)` (`:410`) | Never written. | TODO | TESTED |
| VZ-124 | margin width `_contentLeft` (`:411`) | Missing. | TODO | TESTED |
| VZ-125 | `safeInvoke1Arg` invokes with exact accessor/result (`:416-418`) | Direct call constrains result to Unit. | TODO | TESTED |
| VZ-126 | `safeInvoke1Arg` reports catch and returns undefined (`:419-422`) | Missing. | TODO | TESTED |

### Layout/model ledger

#### `viewModel.ts` contracts — VC

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VC-001 | `IViewModel.getHiddenAreas` (`:66`) | Existing hidden-area model and tests. | TODO | TESTED |
| VC-002 | `IViewModel.changeWhitespace` (`:111-113`) | Missing ViewModel bridge. | TODO | TESTED |
| VC-003 | lines viewport contract (`:139`) | Existing ViewLayout viewport path. | TODO | TESTED |
| VC-004 | viewport-at-scrollTop contract (`:140`) | Missing from local ViewLayout. | TODO | TESTED |
| VC-005 | `getWhitespaces` contract (`:141`) | Exists only on LinesLayout. | TODO | TESTED |
| VC-006 | line-top/includeViewZones (`:147`) | Existing delegate/read API. | TODO | TESTED |
| VC-007 | line-bottom/includeViewZones (`:148`) | Existing delegate. | TODO | TESTED |
| VC-008 | line-height contract (`:149`) | Existing uniform delegate. | TODO | TESTED |
| VC-009 | whitespace-hit contract (`:150`) | Existing delegate lacks focused evidence. | TODO | TESTED |
| VC-010 | whitespace viewport contract (`:152-155`) | Missing from ViewLayout. | TODO | TESTED |
| VC-011 | whitespace `id` (`:158-159`) | Existing EditorWhitespace. | TODO | TESTED |
| VC-012 | whitespace `afterLineNumber` (`:160`) | Existing field. | TODO | TESTED |
| VC-013 | whitespace `height` (`:161`) | Existing field. | TODO | TESTED |
| VC-014 | insert signature with raw-`Double` height/minWidth, ordinal, and returned id (`:164-168`) | Existing accessor is integer-only. | TODO | TESTED |
| VC-015 | change signature (`:169`) | Existing accessor. | TODO | TESTED |
| VC-016 | remove signature (`:170`) | Existing accessor. | TODO | TESTED |
| VC-017 | `bigNumbersDelta` field (`:178-182`) | Existing branch needs boundary evidence. | TODO | TESTED |
| VC-018 | viewport start line (`:183-186`) | Reference suite. | TODO | TESTED |
| VC-019 | viewport end line (`:187-190`) | Reference suite. | TODO | TESTED |
| VC-020 | relative offsets (`:191-194`) | Reference suite. | TODO | TESTED |
| VC-021 | centered line (`:195-198`) | Reference suite. | TODO | TESTED |
| VC-022 | completely-visible start (`:199-202`) | Reference suite. | TODO | TESTED |
| VC-023 | completely-visible end (`:203-206`) | Reference suite. | TODO | TESTED |
| VC-024 | returned line height (`:208-211`) | Existing field needs direct evidence. | TODO | TESTED |
| VC-025 | viewport whitespace id (`:214-215`) | Reference suite. | TODO | TESTED |
| VC-026 | viewport whitespace anchor (`:216`) | Reference suite. | TODO | TESTED |
| VC-027 | viewport whitespace top (`:217`) | Reference suite. | TODO | TESTED |
| VC-028 | viewport whitespace height (`:218`) | Reference suite. | TODO | TESTED |

#### `linesLayout.ts` complete scoped clusters — LL

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| LL-001 | pending-change shape (`:10`) | Existing `PendingChange`. | TODO | TESTED |
| LL-002 | pending-remove shape (`:11`) | Existing `PendingRemove`. | TODO | TESTED |
| LL-003 | pending queues/defaults (`:13-24`) | Existing `PendingChanges`; pure retained shape. | TODO | PORTED |
| LL-004 | enqueue methods set pending before push (`:26-39`) | Existing. | TODO | TESTED |
| LL-005 | no-pending commit early return (`:41-44`) | Existing, untested. | TODO | TESTED |
| LL-006 | snapshot, clear, delegate order (`:46-55`) | Existing; reentrancy untested. | TODO | TESTED |
| LL-007 | whitespace id/anchor/ordinal/height fields and constructor assignments (`:59-63,67-71`) | Existing. | TODO | TESTED |
| LL-008 | post-ToInt32 `minWidth` field (`:64,72`) | Existing retained integer field. | TODO | PORTED |
| LL-009 | prefix sum starts at zero (`:65,73`) | Reference suite. | TODO | TESTED |
| LL-010 | instance counter/hash-generated id (`:85,87,99`) | Exact ID shape unasserted. | TODO | TESTED |
| LL-011 | layout state and sentinel defaults (`:88-95,100-107`) | Existing retained shape. | TODO | PORTED |
| LL-012 | `LineHeightsManager` ownership (`:96,108`) | No custom-line-height producer. | TODO | DEFERRED (custom per-line heights absent) |
| LL-013 | anchor/ordinal binary insertion (`:111-136`) | Exact reference test. | TODO | TESTED |
| LL-014 | default line-height setter (`:138-143`) | Existing, needs focused test. | TODO | TESTED |
| LL-015 | padding setter (`:145-151`) | Existing, setter untested. | TODO | TESTED |
| LL-016 | flush replaces line count (`:158-159`) | Existing flush paths. | TODO | TESTED |
| LL-017 | flush rebuilds custom line heights (`:160`) | No custom-line-height producer. | TODO | DEFERRED (custom per-line heights absent) |
| LL-018 | custom line-height transaction (`:163-177`) | No custom-line-height producer. | TODO | DEFERRED (custom per-line heights absent) |
| LL-019 | whitespace had-change result (`:179-180,208`) | Existing; empty callback untested. | TODO | TESTED |
| LL-020 | insert/id/queue/return (`:183-184,189-192`) | Reference suite. | TODO | TESTED |
| LL-021 | insert `\|0` coercions (`:185-188`) | Line/ordinal are typed `Int`; `Double` height/min-width require exact portable JavaScript `ToInt32`. | TODO | TESTED |
| LL-022 | change/queue behavior (`:193-194,197-198`) | Reference suite. | TODO | TESTED |
| LL-023 | change `\|0` coercions (`:195-196`) | Line is typed `Int`; `Double` height requires exact portable JavaScript `ToInt32`. | TODO | TESTED |
| LL-024 | remove queue (`:199-202`) | Reference suite. | TODO | TESTED |
| LL-025 | callback commits in `finally` (`:181,204-207`) | Local commits only after normal return. | TODO | TESTED |
| LL-026 | min-width cache invalidation (`:211-214`) | Existing, untested. | TODO | TESTED |
| LL-027 | delicate single-operation ordering (`:216-224,229-231`) | Reference suite. | TODO | TESTED |
| LL-028 | missing remove ID continues (`:225-228`) | Existing branch lacks direct test. | TODO | TESTED |
| LL-029 | bulk remove/change conflict rules (`:234-260`) | Existing; mixed transaction untested. | TODO | TESTED |
| LL-030 | old array before inserts concatenation (`:262`) | Existing, untested. | TODO | TESTED |
| LL-031 | bulk anchor/ordinal sort (`:263-268`) | Existing; exact matrix missing. | TODO | TESTED |
| LL-032 | bulk array replacement/prefix reset (`:270-271`) | Existing; invalidation untested. | TODO | TESTED |
| LL-033 | delicate insertion/prefix invalidation (`:274-278`) | Reference suite. | TODO | TESTED |
| LL-034 | id lookup and miss (`:280-288`) | Existing; valid path tested. | TODO | TESTED |
| LL-035 | change missing-id return (`:290-294`) | Existing branch lacks direct test. | TODO | TESTED |
| LL-036 | height mutation/prefix invalidation (`:295-298`) | Reference suite. | TODO | TESTED |
| LL-037 | anchor move removes and reinserts (`:299-312`) | Reference suite. | TODO | TESTED |
| LL-038 | remove/prefix invalidation (`:315-318`) | Reference suite. | TODO | TESTED |
| LL-039 | line deletion reanchors zones (`:326,330-343`) | Reference suite. | TODO | TESTED |
| LL-040 | deletion `\|0` coercions (`:327-328`) | MoonBit inputs are statically `Int`. | TODO | N-A (typed Int boundary) |
| LL-041 | deletion custom-height hook (`:344`) | No custom-line-height producer. | TODO | DEFERRED (custom per-line heights absent) |
| LL-042 | line insertion shifts anchors (`:353,357-364`) | Reference suite. | TODO | TESTED |
| LL-043 | insertion `\|0` coercions (`:354-355`) | MoonBit inputs are statically `Int`. | TODO | N-A (typed Int boundary) |
| LL-044 | insertion custom-height hook (`:365`) | No custom-line-height producer. | TODO | DEFERRED (custom per-line heights absent) |
| LL-045 | total whitespace height (`:371-376`) | Reference suite. | TODO | TESTED |
| LL-046 | lazy prefix-sum rebuild (`:385-399`) | Reference suite. | TODO | TESTED |
| LL-047 | line+zone+padding total height (`:406-411`) | Reference suite under uniform height. | TODO | TESTED |
| LL-048 | whitespace accumulated before line (`:418-428`) | Reference suite. | TODO | TESTED |
| LL-049 | last-whitespace binary search (`:430-455`) | Covered through public callers. | TODO | TESTED |
| LL-050 | first-whitespace derivation (`:457-468`) | Reference suite. | TODO | TESTED |
| LL-051 | public first-whitespace lookup (`:474-478`) | Existing. | TODO | TESTED |
| LL-052 | line top/include-zone rule (`:486-499`) | Reference/read-API tests. | TODO | TESTED |
| LL-053 | per-line height delegate (`:501-503`) | Uniform implementation needs direct evidence. | TODO | TESTED |
| LL-054 | line bottom/include-zone rule (`:511-516`) | Existing tests. | TODO | TESTED |
| LL-055 | has-whitespace predicate (`:521-523`) | Existing, untested directly. | TODO | TESTED |
| LL-056 | min-width cache/maximum (`:528-537`) | Existing, untested. | TODO | TESTED |
| LL-057 | line-at-offset binary search (`:570-604`) | Exact reference tests. | TODO | TESTED |
| LL-058 | viewport initialization/zone sentinel (`:613-637`) | Exact reference tests. | TODO | TESTED |
| LL-059 | exact `STEP_SIZE=500000` alignment (`:642-651`) | Existing branch needs boundary tests. | TODO | TESTED |
| LL-060 | centered-line selection (`:653-667`) | Exact reference tests. | TODO | TESTED |
| LL-061 | line/zone accumulation and stop (`:658-696`) | Exact reference tests. | TODO | TESTED |
| LL-062 | centered fallback (`:698-700`) | Exact reference tests. | TODO | TESTED |
| LL-063 | complete-visible edge corrections (`:702-717`) | Exact reference tests. | TODO | TESTED |
| LL-064 | viewport result fields (`:719,721-726,728`) | Exact reference tests. | TODO | TESTED |
| LL-065 | returned big delta/default line height (`:720,727`) | Needs direct field evidence. | TODO | TESTED |
| LL-066 | whitespace vertical offset (`:731-750`) | Top/middle zones covered. | TODO | TESTED |
| LL-067 | whitespace-index binary search (`:752-787`) | Exact reference tests. | TODO | TESTED |
| LL-068 | single-whitespace hit/null branches (`:795-824`) | Exact boundary tests. | TODO | TESTED |
| LL-069 | whitespace viewport/half-open end (`:833-861`) | Exact reference tests. | TODO | TESTED |
| LL-070 | shallow whitespace snapshot (`:866-868`) | Existing; copy independence untested. | TODO | TESTED |
| LL-071 | whitespace count (`:873-875`) | Reference suite. | TODO | TESTED |
| LL-072 | id/anchor/height indexed accessors (`:883-910`) | Reference suite. | TODO | TESTED |

#### `viewLayout.ts` whitespace handoff — VL

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VL-001 | save-state zone subtraction (`:361-370`) | Existing, no focused test. | TODO | TESTED |
| VL-002 | incremental whitespace delegate (`:374-375`) | Local rebuilds via `set_view_zones`. | TODO | TESTED |
| VL-003 | conditional height update/result (`:376-380`) | Missing with incremental bridge. | TODO | TESTED |
| VL-004 | line-top delegate (`:390-392`) | Existing. | TODO | TESTED |
| VL-005 | line-bottom delegate (`:393-395`) | Existing. | TODO | TESTED |
| VL-006 | line-height delegate (`:396-398`) | Existing. | TODO | TESTED |
| VL-007 | whitespace-hit delegate (`:413-415`) | Existing, not focused-tested. | TODO | TESTED |
| VL-008 | current viewport `[top,top+height]` (`:416-419`) | Existing window/zone tests. | TODO | TESTED |
| VL-009 | explicit-scrollTop clamp/delegate (`:420-430`) | Missing locally. | TODO | TESTED |
| VL-010 | whitespace viewport delegate (`:431-434`) | Missing locally. | TODO | TESTED |
| VL-011 | whitespace snapshot delegate (`:435-437`) | Missing locally. | TODO | TESTED |

#### Visibility chain — CC/VML

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| CC-001 | coordinates-converter visibility contract (`coordinatesConverter.ts:27`) | Local converter trait omits the method. | TODO | TESTED |
| CC-002 | identity visibility bounds (`:76-83`) | Viewer never constructs identity lines. | TODO | N-A (projected line collection is universal) |
| VML-001 | `IViewModelLines extends IDisposable`; projected dispose removes hidden decoration IDs with default owner 0 (`viewModelLines.ts:22,114-116`) | Local ViewModel disposal never disposes projected lines; editor-owner sweep cannot remove owner-0 decorations. | TODO | TESTED |
| VML-002 | create-converter contract (`:23`) | Existing projected converter. | TODO | TESTED |
| VML-003 | hidden-area contracts (`:27-28`) | Existing. | TODO | TESTED |
| VML-004 | hidden decoration IDs (`:83`) | Existing. | TODO | TESTED |
| VML-005 | projected converter construction (`:118-120`) | Existing. | TODO | TESTED |
| VML-006 | reset projections/hidden decorations (`:122-127`) | Existing wrapping-survival evidence. | TODO | TESTED |
| VML-007 | hidden-range sentinel traversal (`:140-155`) | Hidden-area tests. | TODO | TESTED |
| VML-008 | projection visibility/counts/ensure (`:156-160,163-165`) | Hidden-area tests; version-state sibling `:161` remains excluded. | TODO | TESTED |
| VML-009 | resolve hidden decorations (`:168-172`) | Existing. | TODO | TESTED |
| VML-010 | validate/normalize hidden ranges (`:174-176`) | Existing. | TODO | TESTED |
| VML-011 | unchanged-range return (`:180-193`) | Idempotence test. | TODO | TESTED |
| VML-012 | replace tracking decorations (`:195-204`) | Existing tests. | TODO | TESTED |
| VML-013 | hidden sentinel walk (`:205-220`) | Existing tests. | TODO | TESTED |
| VML-014 | toggle visibility/update prefix (`:221-240`) | Existing tests. | TODO | TESTED |
| VML-015 | all-hidden recursive clear (`:242-245`) | Explicit test. | TODO | TESTED |
| VML-016 | changed return (`:247`) | Existing tests. | TODO | TESTED |
| VML-017 | invalid position bounds (`:250-254`) | Implemented; 0/count+1 untested. | TODO | TESTED |
| VML-018 | projection visibility result (`:255`) | Hidden/visible assertions. | TODO | TESTED |
| VML-019 | ensure first visible line (`:435-440`) | All-hidden test. | TODO | TESTED |
| VML-020 | normalize empty (`:1024-1027`) | Hidden tests. | TODO | TESTED |
| VML-021 | copy/sort/seed (`:1029-1034`) | Hidden tests. | TODO | TESTED |
| VML-022 | separated vs touching/overlap (`:1036-1046`) | Explicit normalization tests. | TODO | TESTED |
| VML-023 | emit final interval (`:1047-1048`) | Hidden tests. | TODO | TESTED |
| VML-024 | projected converter ownership (`:1073-1078`) | Existing. | TODO | TESTED |
| VML-025 | projected visibility delegator (`:1108-1110`) | Concrete converter omits it; Viewer bypasses directly. | TODO | TESTED |
| VML-026 | identity dispose is an empty no-op (`:1134-1135`) | No identity-lines path. | TODO | N-A (projected line collection is universal) |
| VML-027 | identity converter creation (`:1137-1139`) | No identity-lines path. | TODO | N-A (projected line collection is universal) |
| VML-028 | identity hidden areas empty (`:1141-1143`) | No identity-lines path. | TODO | N-A (projected line collection is universal) |
| VML-029 | identity set-hidden false (`:1145-1147`) | No identity-lines path. | TODO | N-A (projected line collection is universal) |

#### `viewModelImpl.ts` consumed clusters — VI

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VI-001 | lines/converter/layout ownership (`viewModelImpl.ts:62-64`) | Existing ViewModel member order. | TODO | TESTED |
| VI-002 | `USE_IDENTITY_LINES_COLLECTION=true` and identity-lines constructor branch (`:49,94-97`) | Viewer always uses projected lines. | TODO | N-A (projected line collection is universal) |
| VI-003 | projected-lines constructor branch (`:98-120`) | Existing `with_options`. | TODO | TESTED |
| VI-004 | converter then layout wiring (`:122,126`) | Existing; cursor-owned `:124` remains excluded. | TODO | TESTED |
| VI-005 | stable viewport capture (`:263-272`) | Existing; needs focused scroll test. | TODO | TESTED |
| VI-006 | hidden model/cache fields (`:568-569`) | Existing. | TODO | TESTED |
| VI-007 | source contribution + merged ranges (`:592-594`) | Existing. | TODO | TESTED |
| VI-008 | unchanged/force-update gate (`:595-597`) | Structural equality equivalent. | TODO | TESTED |
| VI-009 | cache then capture order (`:599-601`) | Existing; ordering untested. | TODO | TESTED |
| VI-010 | begin event transaction before mutation (`:603-605`) | Local batch currently begins later in host. | TODO | TESTED |
| VI-011 | apply hidden ranges (`:606`) | Existing. | TODO | TESTED |
| VI-012 | ordered flush/mapping/decor events (`:607-610`) | Equivalent fan-out needs exact evidence. | TODO | TESTED |
| VI-013 | cursor/decor/layout/height effects (`:611-615`) | Existing uniform-height path. | TODO | TESTED |
| VI-014 | viewport-line-hidden recovery gate (`:617-621`) | Existing, no focused test. | TODO | TESTED |
| VI-015 | end transaction in `finally` (`:622-624`) | Owner/order currently differs. | TODO | TESTED |
| VI-016 | async view-line-count refresh (`:625`) | Viewer derives count immediately; no async config cache. | TODO | N-A (immediate line-count ownership) |
| VI-017 | outgoing HiddenAreasChanged (`:627-629`) | The complete HiddenAreas outgoing class/emitter/dispatch surface remains lifecycle CEW-044/128 and generic-outgoing dependent. | TODO | DEFERRED (no complete public HiddenAreas event surface) |
| VI-018 | hidden-area getter delegate (`:651-653`) | Existing. | TODO | TESTED |
| VI-019 | ViewModel whitespace delegate/result (`:1253-1255`) | Missing; host rebuilds ViewLayout. | TODO | TESTED |
| VI-020 | changed internal event before outgoing (`:1255-1257`) | Only internal event exists. | TODO | TESTED |
| VI-021 | outgoing ViewZonesChanged (`:1257`) | Missing kind/class/merge/emitter. | TODO | TESTED |
| VI-022 | identity-keyed hidden-model map/defaults (`:1383-1386`) | Local uses caller-chosen `String` keys and cannot preserve arbitrary object identity. | TODO | DEFERRED (arbitrary identity-keyed hidden sources absent) |
| VI-023 | unchanged contribution/recompute flag (`:1388-1395`) | Existing. | TODO | TESTED |
| VI-024 | cached merged-array return (`:1400-1404`) | Existing. | TODO | TESTED |
| VI-025 | reduce source arrays through merge (`:1405`) | Multi-source tests. | TODO | TESTED |
| VI-026 | preserve identity or replace cache (`:1406-1410`) | Existing tests. | TODO | TESTED |
| VI-027 | two-cursor merge setup (`:1414-1418`) | Existing merge helper. | TODO | TESTED |
| VI-028 | separated-range branches (`:1422-1425`) | Hidden tests. | TODO | TESTED |
| VI-029 | touching/overlap union (`:1426-1432`) | Explicit tests. | TODO | TESTED |
| VI-030 | append tails (`:1434-1440`) | Multi-source tests. | TODO | TESTED |
| VI-031 | range-array equality (`:1443-1453`) | Structural equivalent. | TODO | TESTED |
| VI-032 | stable viewport fields (`:1458-1462`) | Existing pure carrier. | TODO | PORTED |
| VI-033 | no-position recovery return (`:1464-1467`) | Existing, needs focused test. | TODO | TESTED |
| VI-034 | convert/top/immediate recovery (`:1468-1470`) | Existing, needs focused scroll test. | TODO | TESTED |

### Outgoing-event ledger

#### `codeEditorWidget.ts` event/API handoff — CEW

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| CEW-001 | registered `_onDidChangeViewZones` emitter field plus shared delivery-queue option (`:203`) | Add the dedicated Viewer emitter, but lifecycle CEW-001's cross-event delivery queue remains absent. | TODO | DEFERRED (shared CodeEditorWidget delivery queue absent) |
| CEW-002 | public `onDidChangeViewZones` event alias (`:204`) | Missing public listener. | TODO | PORTED |
| CEW-003 | `changeViewZones` member/signature (`:1654`) | Shape-divergent root method exists. | TODO | PORTED |
| CEW-004 | no-model/no-real-view early return (`:1655-1657`) | Local headless path currently mutates zones. | TODO | TESTED |
| CEW-005 | success delegates to `View.change` (`:1658`) | Transaction currently stays in root. | TODO | TESTED |
| CEW-006 | outgoing ViewZones arm fires public emitter (`:1803-1805`) | Missing bridge. | TODO | TESTED |

#### `viewModelEventDispatcher.ts` ViewZones outgoing contract — VED

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VED-001 | `OutgoingViewModelEvent` union arm (`:181`) | No local outgoing zone-event type. | TODO | PORTED |
| VED-002 | `OutgoingViewModelEventKind.ViewZonesChanged` exact numeric ordinal 4 (`:200`) | Local semantic enum has no numeric ABI; distinct kind equality remains live. | TODO | N-A (semantic enum exposes no numeric ABI) |
| VED-003 | class `kind` field (`:349-351`) | Missing. | TODO | PORTED |
| VED-004 | empty constructor (`:353-354`) | Missing source-shaped constructor. | TODO | PORTED |
| VED-005 | `isNoOp` member returns false (`:356-358`) | Missing. | TODO | TESTED |
| VED-006 | `attemptToMerge` member (`:360`) | Missing. | TODO | TESTED |
| VED-007 | other-kind mismatch returns null (`:361-363`) | Missing. | TODO | TESTED |
| VED-008 | same-kind merge returns existing `this` (`:364`) | Missing. | TODO | TESTED |

### Ownership, exclusions, and local drift

- The frozen render-invalidation plan owns the internal
  `ViewEvent::ViewZonesChanged` declaration and generic nested/reentrant View
  event queue. This child owns the source producer/order, the distinct outgoing
  ViewZones event class/public bridge, and a heterogeneous widening of the
  existing cursor-owned outgoing-only pending queue. The direct whitespace
  path must finish internal ViewEvent delivery before enqueueing the public
  outgoing event. `VED-006–008` are proven by event-class/private-pending-queue
  white-box tests; ordinary direct calls drain immediately and do not claim
  end-to-end same-kind coalescing. The frozen RVC mixed collector,
  view-consumption postponement, and cross-queue reentrancy rows remain
  DEFERRED and are not duplicated.
- The frozen cursor plan owns the existing outgoing-only mechanics at
  VMI-001/002/004 and VED-001/002/008/010–018. This child edits
  `cursor_event_dispatcher.mbt` only to replace its deferred sibling witness
  with the new ViewZones arm/listener and does not recount those mechanics;
  every cursor dispatcher white-box regression remains mandatory.
- Browser geometry owns ViewLayout's general content/scroll formulas. This
  child owns the nonzero whitespace-minimum producers at `VZA-009`,
  `VZ-010/063/087/096–098`, and `LL-008/026/056`; frozen geometry consumes them
  at `GVLay-023` and `GVLay-046`.
- Cursor/input owns PositionAffinity, all non-visibility converter methods,
  mouse-target production, and pointer paths outside VMH. The scoped rows count
  only ViewZones' arguments, visibility handoff, and suppression consumer.
- Lifecycle owns general attach/detach/dispose mechanics. This child owns the
  observable rule that the per-model zone registry is lost on every model
  replacement/detach and verifies it without recounting lifecycle members.
  Parent ownership also transfers lifecycle's historical DEFERRED CEW-043/127
  ViewZones emitter/dispatch rows to this child; the lifecycle ledger remains
  immutable history. Its CEW-001 shared cross-event delivery queue is not
  transferred and remains the explicit CEW-001 child-row deferral.
- Parent ownership transfers only the zone-specific attachment subsegments of
  lifecycle VIEW-029/053/060–062. VAT proves the margin/content zone placement
  and merged `.margin` owner; rulers, glyphs, widgets, scrollbars, and every
  other constructor/order sibling remain frozen lifecycle/geometry ownership.
- `linesLayout.ts:542-560` padding/after-lines hit helpers and ViewLayout's
  general padding/scroll siblings remain geometry-owned. Custom-line-height
  hooks are the five explicit DEFERRED LL rows; identity-line paths are the
  explicit N-A CC/VML/VI rows.
- `viewModelImpl.ts:632-720` visible-range splitting, cursor/edit/copy/render
  siblings, generic collectors at `:1262-1279`, and overview-ruler aggregation
  are excluded. `viewModelLines.ts` wrapping/text/decorations/general-converter
  siblings are excluded. Projected owner-0 hidden-decoration disposal and the
  identity no-op are now VML-001/026; the editor-owner CEW-075 sweep is not an
  equivalent handoff.
- Local-only drift adds no source rows but must disappear or be justified in
  Phase 3: caller IDs, whole-record `update_zone`, `(anchor,height,id)` sorting,
  retained post-callback accessors, the no-op scheduling gate, raw offscreen
  top, render-time computed-height calls, `data-view-zone-id`, class/style
  replacement, `.view-zone { overflow:hidden }`, the invented `.view-zone`
  class, and the absent margin container. Some(A)→Some(B) persistence, eager
  anchor/height clamping, `measure_requested`, whole-list DOM reconciliation
  and `zone_index` identity also need removal. The container's invented
  `data-view-part`, `top/left/z-index`, and host `left/right/box-sizing`
  stylesheet facts require removal or a source-backed deviation.

### Historical inventory stop gate

- [x] 346 source atoms have 346 unique, contiguous ledger IDs.
- [x] Every row is TODO and has a proposed terminal; there are zero PASS rows.
- [x] Proposed totals are 287 TESTED / 41 PORTED / 8 DEFERRED / 10 N-A.
- [x] Shared-file ownership and frozen sibling clusters are explicit.
- [x] No product or test file changed while building the inventory.
- [x] Independent Gate B approves source completeness, boundaries, matrices,
  and proposed terminals.

Review gate: commit this corrected 346-row inventory and stop for fresh
independent Gate B review before any product or test edit.

## Test-Authority Corrections

- tests/browser/component/model_swap.spec.js currently states that registered
  ViewZones re-mount across model replacement. The `ICodeEditor.changeViewZones`
  contract and per-model View construction prove the opposite: the test is a
  stale oracle and must assert loss on Some(A)→Some(B), detach, and disposal.
- Existing viewer_api zone tests assert text/top/height but do not verify host
  class/style preservation, width, callback counts, errors, ordinal, or
  hidden-area behavior.
- Local layout tests with only anchor_line and height_px do not establish the
  complete source contract.
- viewer/common/view_layout/lines_layout_reference_test.mbt names the old
  294fb350 oracle, but both source and upstream test are byte-identical at
  b18492a. Correct the header pin, retain the exact labels, add ordinary local
  tests for unported source branches, and keep custom-line-height cases on the
  five explicit DEFERRED rows.

## Required Test Matrix (Phase 4)

Use reference filenames only for exact upstream tests with original labels,
paths, and current pin. Source-derived cases use ordinary local filenames.

| Cluster | Required axes and boundaries | Lowest useful evidence |
|---|---|---|
| transaction | callback normal/throw; 0/1/many operations; add/remove/layout mixtures; empty/missing IDs; retained accessor after normal return/throw; exact invalid error for all three methods | root/ViewZones white-box + reporter |
| root guard | no model; model with no real View; live model/View: first two do not invoke callback and produce no mutation, event, or schedule; live path invokes once | root white-box |
| scheduling/events | change/no-change/callback throw; unconditional one render schedule after every invoked transaction; internal ViewEvent completes before public outgoing enqueue only on change | root/view scheduler ordered spy |
| outgoing-only queue | ViewZones event is never no-op; same-kind merge keeps first instance; different kind keeps two queue slots and FIFO order; reentrant listener order means only the outgoing Emitter's own delivery; direct calls drain immediately; mixed view/outgoing collector postponement, CodeEditorWidget shared delivery-queue ordering, and cross-queue reentrancy are not claimed | event-class/private-pending-queue white-box + full cursor-dispatcher regression |
| identity/lifetime | repeated adds; remove then add; generated IDs unique and used by layout/DOM; Some(A)→Some(B), detach, model dispose, Viewer dispose all lose registry | LinesLayout + root/headless + browser |
| projected-lines lifetime | 0/1/many owner-0 hidden decorations; ViewModel dispose clears all and leaves unrelated/editor-owned decorations; repeated dispose is harmless; identity dispose is the explicit N-A no-op path | ViewModel/model white-box |
| bulk layout | 0/1/>1 queued operations; insert/change/remove conflicts; same ID repeated; missing IDs; delicate versus rebuild path | LinesLayout white-box/reference |
| line edits / flush | delete interval before/containing/after anchor; insert before/equal/after anchor; preserve same-anchor ordinal; same-model flush shrinks/grows and retains zones | LinesLayout + ViewModel integration |
| layout state / accessors | IDs across two LinesLayout instances and per-instance counters; padding top/bottom 0/nonzero; `hasWhitespace` false/true; `getWhitespaces` returns an independent array with aliased whitespace objects; `saveState` uses future scroll with 0/1/many zones above and zones below the first visible line | LinesLayout/ViewLayout white-box |
| anchor/column | line 0, first/middle/last/out-of-range; afterColumn absent/1/middle/max/beyond; EOL uses next-line column 1, otherwise same-line column+1 | ViewModel/ViewZones white-box |
| affinity | omitted/None/Left/Right/LeftOfInjectedText/RightOfInjectedText at wrapped and injected multi-view-column boundaries | projected ViewModel white-box |
| hidden | showInHiddenAreas omitted/false/true × before-position visible/hidden; hidden↔visible mapping changes; line-zero never hidden; hidden height exactly 0 | hidden-area + ViewZones integration |
| hidden producer / stable viewport | unchanged/force-update; caller `String` sources distinct/repeated/same-string replacement (arbitrary object identity stays VI-022 DEFERRED); disjoint/touch/overlap/all-hidden; invalid visibility positions 0 and lineCount+1; scrollTop 0/nonzero; no captured position; viewport first model line hidden skips recovery; hidden ranges only above it preserve model line+delta and restore immediately; begin/order/finally and changed-only internal events; public HiddenAreas outgoing stays excluded by VI-017 | ViewModel/ViewLayout ordered white-box |
| ordinal | explicit 0/negative/equal; fallback afterColumn; neither→10000; lower/equal/higher anchor; equal-key stable insertion | LinesLayout/ViewZones white-box |
| mutable delegate | mutate anchor/column/height/minWidth/ordinal/node/callback then layout; reread only source fields and retain inserted ordinal/minWidth/node | transaction white-box |
| height / ToInt32 | px present with/without lines; lines only; neither; raw +0/-0/positive/fractional/negative/NaN/±Infinity and signed-32-bit/2^32 overflow; callback distinguishes raw -0 while LinesLayout canonicalizes it to 0 and otherwise retains exact JavaScript-ToInt32 height/minWidth; line-height change; changed/unchanged recompute compares retained integer to raw computed value | pure normalization + LinesLayout/config integration |
| computed height | absent/normal/throw; add once after whitespace insertion/node wrapping but before any host DOM mutation/mount/map insertion/dirtying; layout existing even unchanged after whitespace change but before dirtying; recompute `changeOneWhitespace`→callback→changed; hidden raw +0; never on static render/scroll; throw is reported and all later phases still complete | callback/DOM/dirty ordered spies + error reporter |
| min width | absent/0/nonzero; cache hit; insert/remove invalidation; multiple-zone maximum; below/equal/above content/scroll width; layout retains original minimum | LinesLayout/ViewLayout + Chromium reach |
| viewport | no/one/many/same-anchor zones; top/middle/bottom; starts in line/zone/gap; half-open end; explicit scrollTop negative/bottom overflow | layout reference/white-box |
| ViewPart handlers | configuration changed fields independently and lineHeight recompute only on its bit; mapping recomputes; delete/zones/insert always true; scroll top/width truth table across neither/each/both | ViewZones white-box |
| large geometry | 499999/500000/500001; line-height alignment; visible DOM top with zero/nonzero bigNumbersDelta | layout + rendering-context white-box |
| host DOM | caller class, unrelated styles, content, listener, descendant identity/state survive; only position/width/display/top/height and Monaco attributes change | real Chromium DOM assertions |
| margin/attachment | absent/null/present margin node; both mount/remove; mirrored top/height/display; exact container attrs; merged `MarginViewOverlays` remains the `.margin` DOM/ViewPart owner and first overflow child; zone precedes overlay children; content zone retains relative sibling order | browser component + ViewPart event regression |
| visibility/top | visible/offscreen/hidden; mixed zones; repeated frame; transitions; visible attribute/state changes before callback; callback before main/margin top/height/display; scrolled visible top and converted `-1000000` | ViewZones ordered white-box + browser scroll |
| callback containment / key snapshots | each callback absent/normal/throw; throwing first/middle/last; later zone, later ViewPart, public event and frame reporter still commit; render and recompute freeze only key arrays and look up values live: new keys mount immediately but skip the current iteration, current removal detaches before saved-wrapper writes finish, future removal leaves a stale key that can fail on this iteration, and layout mutates whitespace/dirty state immediately while current visible data stays frozen | browser ordered spies + memory logger |
| width gate | no visible zone; one/many; scrollWidth <,=,> contentWidth; contentLeft 0/nonzero; all zone callbacks/style writes finish before width writes; some→none retains prior widths | browser geometry |
| mouse suppression | existing omitted/false/true/missing × content/gutter zone × shouldHandle false/true; true-arm focus/start/prevent order; normal public mouse event still emits | controller white-box + pointer fixture |

DOM insertion order remains source add order; ordinal controls layout position,
not node reordering. The browser matrix asserts both facts independently.

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

The reviewed implementation seams are:

- the common ViewModel package cannot import browser `ViewEvent`. The root
  transaction therefore completes the internal browser ViewEvent delivery and
  then submits `ViewZonesChangedEvent` to the common heterogeneous
  outgoing-only queue. Ordered evidence is required; this does not claim the
  frozen RVC mixed-collector postponement semantics;
- `Double` zone heights/minimum widths preserve source raw-number callbacks,
  while LinesLayout stores portable JavaScript-ToInt32 values;
- Monaco's separate `Margin` object stays merged into `MarginViewOverlays`;
  exact DOM ownership/order and existing ViewPart delivery remain tested;
- hidden-area sources use caller-chosen `String` keys. Arbitrary source object
  identity is the explicit VI-022 DEFERRED reduction;
- the dedicated ViewZones emitter is added without CodeEditorWidget's shared
  cross-event delivery queue, which remains the explicit CEW-001/lifecycle
  CEW-001 DEFERRED reduction;
- MoonBit's semantic outgoing enum exposes no numeric ABI, so source ordinal 4
  is VED-002 N-A while distinct kind equality remains tested;
- the complete public HiddenAreas event class/emitter/dispatch chain remains
  outside the ViewZones consumer and is the explicit VI-017 DEFERRED handoff;
- custom per-line-height producers remain absent and are the five explicit LL
  DEFERRED rows. The projected-only/typed-line/immediate-count reductions are
  the remaining N-A rows.

No other product reduction is pre-approved. Any new DEFERRED/N-A outcome must
update the ledger and stop for classification review.

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

- 2026-07-12: Phase 0 was corrected before inventory freeze to include the
  previously omitted `View.change` unconditional-schedule handoff, content and
  margin attachment clusters, mouse suppression consumer, ViewLayout
  whitespace facade, whitespace/viewport contracts, and the real projected
  visibility chain. These are complete consumed clusters; frozen siblings are
  named above.
- 2026-07-12: Phase 1–2 inventory is ready with 351/351 TODO rows: 163
  browser/API, 174 layout/model, and 14 outgoing-event atoms. The proposed map
  is 293 TESTED, 43 PORTED, 5 DEFERRED, and 10 N-A. Three independent source
  passes produced the source-ordered fragments and challenged stale local
  tests and missing source owners. No product or test file changed. Commit this
  documentation-only gate and stop for independent Gate B review.
- 2026-07-12: Gate B rejected documentation-only inventory commit `50d3905`
  (this file's inventory SHA-256
  `3f93dcb568ece6a8857c4dbd28f22c2fd0c0e85c3a5ff7e844cf334706563991`).
  The reviews found seven frozen sibling mount rows, conflicting historical
  ownership, integer-versus-raw-number ambiguity, one partial HiddenAreas
  outgoing claim, imprecise shared-file ranges, and missing callback/reentrant,
  line-edit/layout-state, and stable-viewport matrices.
- 2026-07-12: the corrected candidate has 344/344 TODO rows: 156 browser/API,
  174 layout/model, and 14 outgoing-event atoms. The proposed map is 287
  TESTED, 43 PORTED, 6 DEFERRED, and 8 N-A. Public height/minimum-width carriers
  are raw `Double` values while LinesLayout owns exact JavaScript-ToInt32
  retention; VI-017 is the concrete HiddenAreas public-event deferral. Parent
  ownership now transfers lifecycle's historical ViewZones emitter/dispatch
  rows, StableViewport helpers, LinesLayout custom-height siblings, and the
  cursor outgoing-only queue widening without reopening the mixed RVC
  collector. No product/test file changed. Commit this documentation-only
  correction and stop for fresh independent Gate B review.
- 2026-07-12: fresh Gate B reviews rejected correction commit `be2a127`
  (this file's SHA-256
  `5d8864ecc77f889b246bad1c6b3cf8a95d9d2bf9450acdb3f0c212b3422f2449`).
  Owner-id evidence invalidated the projected-lines disposal handoff; reviews
  also found untransferred View attachment history, the merged-Margin premise,
  incomplete cursor-queue local ownership, and three unclassified reductions
  (shared editor delivery queue, numeric enum ABI, identity-key hidden sources).
- 2026-07-12: the second corrected candidate has 346/346 TODO rows: 156
  browser/API, 176 layout/model, and 14 outgoing atoms. The proposed map is 287
  TESTED, 41 PORTED, 8 DEFERRED, and 10 N-A. VML-001/026 now own projected and
  identity disposal; parent transfers the zone-only VIEW attachment subsegments
  and cursor-queue widening; merged Margin, shared delivery, semantic enum, and
  String-key seams are explicit. The matrix now covers `-0`, owner-0 cleanup,
  and exact frozen-key/live-map callback mutation. No product/test file changed;
  commit and stop for another fresh Gate B review.
- 2026-07-12: Gate B passed at documentation-only inventory commit `1c83995`.
  The approved fixed denominator is 346/346 TODO rows with 287 proposed TESTED,
  41 PORTED, 8 DEFERRED, and 10 N-A; this file's SHA-256 is
  `a556095eee067bee7d32ffb31406c1e9de5407b2f66a7aa1dff45bcbe97b1790`.
  Three fresh independent reviews approved the 156 browser/API, 176
  layout/model, and 14 outgoing atoms, including ownership transfers, reduced
  seams, exact matrices, hashes, and combined mechanics. No product/test edit
  preceded approval; implementation is authorized.
