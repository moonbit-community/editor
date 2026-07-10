# Viewer Model Lifecycle and Service Ownership Parity

Status: approved for implementation

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
  - complete no-op instantiation contribution that forces the service to exist.
- vscode/src/vs/base/browser/globalPointerMoveMonitor.ts
  - complete monitor lifecycle.
- vscode/src/vs/base/browser/ui/scrollbar/abstractScrollbar.ts
  - complete slider-drag monitor ownership and cleanup cluster only.
- vscode/src/vs/editor/browser/config/editorConfiguration.ts
  - configuration/font subscription ownership and disposal cluster only.

The inventory must explicitly name excluded sibling methods when a file is
scoped to a method cluster.

### Closed method-cluster boundaries and excluded siblings

The following exclusions close the Phase 0 denominator. They are named here so
that an omitted sibling cannot be mistaken for an unread source member.

- `codeEditorWidget.ts`: the denominator includes the private registered
  emitter/disposable fields that participate in editor lifetime, the
  constructor's registration/subscription work, `dispose`, `setModel`,
  `_attachModel`, `_createView`, `_postDetachModelCleanup`, `_detachModel`, and
  `ModelData`. Excluded sibling clusters are the public editor operation/query
  API (`writeScreenReaderContent` and the members between `dispose`/`setModel`
  and `_attachModel`), edit/action execution, decoration-type implementation
  (`_removeDecorationTypes` and its callees; only call order from scoped methods
  is counted), widget mutation APIs, render/layout APIs, drag/drop semantics
  beyond ownership of the constructor-installed observer, and helper classes
  after `ModelData` (`BooleanEventEmitter`, `InteractionEmitter`,
  `InternalEditorAction`, and edit-source helpers). Public `onDid*` aliases are
  not separate rows: the owned private emitter on the same source line is the
  lifecycle member; the alias has no independent lifetime.
- `codeEditorContributions.ts`: included are storage initialization,
  `initialize`, the attach-scoped disposable returned by
  `onAfterModelAttached`, and inherited `Disposable` cleanup. Excluded siblings
  are `saveViewState`, `restoreViewState`, `get`, test-only `set`,
  `onBeforeInteractionEvent`, `_instantiateSome`,
  `_findPendingContributionsByInstantiation`, and `_instantiateById`. The
  eager/idle instantiation policy and 5-second eventual timer are excluded;
  cancellation ownership of registered idle handles and the attach-scoped
  50-ms handle remains included.
- `view.ts`: included are `View` construction, edit-context replacement only
  where it changes owned resources, clipboard-listener wiring, `_applyLayout`,
  root class ownership, configuration/focus/theme class transitions,
  `dispose`, and the complete `CodeEditorWidgetFocusTracker` owned by the
  constructor. Excluded siblings are glyph-lane computation, pointer-helper
  geometry, all public view/widget/query APIs, scheduling/rendering and
  coordinated rendering (`_scheduleRender` through
  `CoordinatedRendering`), and their geometry helpers. `View` render behavior
  remains the sibling plan's concern.
- `abstractScrollbar.ts`: included are the registered
  `GlobalPointerMoveMonitor`, slider pointer-down entry listeners, the complete
  `_sliderPointerDown` drag/stop cluster, its `active` class, and inherited
  `Widget` cleanup. Excluded siblings are arrow creation, slider geometry,
  element-size/scroll state updates, render/reveal/hide, trough/page-click
  behavior (`_domNodePointerDown`, `delegatePointerDown`, `_onPointerDown`),
  scroll-position application, resize/needed queries, and abstract geometry
  projections.
- `editorConfiguration.ts`: included are registered emitters,
  `ElementSizeObserver`, automatic-observation ownership, the seven external
  change subscriptions, `_recomputeOptions`, `_readFontInfo`, and inherited
  disposal. Excluded siblings are option validation/computation internals,
  raw-option mutation, model/view-line/reserved-height/glyph-lane setters,
  digit/class helpers, `ValidatedEditorOptions`, `ComputedEditorOptions`,
  `EditorOptionsUtil`, and migration cloning.
- The other four pinned files are complete-source-unit scopes. Nothing in
  `markerDecorations.ts`, browser `markerDecorations.ts`,
  `markerDecorationsService.ts`, or `globalPointerMoveMonitor.ts` is excluded.

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

The listener trace expands that minimum to these actual owners reached from the
listed files:

- base/browser/global_pointer_move_monitor.mbt
- viewer/browser/editor_dom.mbt (`GlobalEditorPointerMoveMonitor` and
  `EditorMouseEventFactory` clusters)
- viewer/view_host.mbt (`schedule_render`/`flush_render` rAF cluster)
- viewer/browser/controller/drag_scrolling.mbt (rAF ownership cluster)
- viewer/browser_host.mbt (`schedule_at_next_animation_frame` cancellation
  wrapper)
- viewer/ui/scrollbar/scrollable_element.mbt (`schedule_hide_scrollbars`
  timeout ownership cluster)

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
| Editor detach calls MarkerDecorationsService.on_model_removed unconditionally | PROPOSED PARITY CONTRACT: ModelData owns one identity-keyed acquisition disposable; detach uses `LeaseReleased`, and only the last lease disposes the per-model owner without deleting host-owned diagnostics |
| Replacing a same-URI per-model decoration owner disposes the old owner first | PROPOSED PARITY CONTRACT: do not replace by URI; distinct model identities coexist and same-identity acquisitions refcount |
| MarkerDecorationsService.dispose disposes all per-model owners | REQUIRED PARITY |
| Viewer-owned listeners/subscriptions are retained and disposed exactly once | REQUIRED PARITY |
| Caller-injected services are disposed by Viewer.dispose | REQUIRED PARITY: do not dispose them |
| Services created because the caller omitted ViewerServices | PROPOSED PARITY CONTRACT: Viewer owns and releases only this internally created aggregate |
| Per-model View DOM is removed at detach and Viewer-owned attach DOM is removed at Viewer disposal | REQUIRED PARITY |
| Two Viewers share one model through shared ViewerServices | PROPOSED PARITY CONTRACT: N acquisitions require N idempotent releases; final release alone disposes the identity owner |
| Distinct live models share one URI through shared ViewerServices | PROPOSED PARITY CONTRACT: acquisition-ordered `URI -> Array[instance_id]` fans marker changes to every live identity and defines union order; source lookup signatures remain compatible, with a model-specific helper added for hover |
| Releasing the last ordinary lease for a transient URI removes MarkerService diagnostics | PROPOSED PARITY CONTRACT: never; ordinary detach does not establish model destruction and `A -> None -> A` must preserve diagnostics |
| A registered model emits `on_will_dispose` | PROPOSED PARITY CONTRACT: handle as `ModelDisposed`; transient cleanup is allowed only after removing that active identity leaves its URI bucket empty |

These rows seed the later member ledger; they do not replace the complete
source-unit inventory.

### Shared marker registration review proposal

Approve this contract at the stop gate before implementation:

| Proposed transition | Source/local ledger mapping |
|---|---|
| `acquire_model(model.instance_id, model) -> Disposable` constructs the per-model decoration owner plus exactly one model-content watch and one model-dispose watch only on the first acquisition; the returned disposable is stored in `ModelData.listeners_to_remove` | MDS-005, MDS-014, CEW-085, LOCAL-081–084, LOCAL-094–095 |
| Reacquiring the same identity increments a refcount; each returned release is independently idempotent | MDS-005, LOCAL-083–084, LOCAL-088 |
| A secondary acquisition-ordered `URI -> Array[instance_id]` index permits distinct live models with the same URI, fans marker changes to every identity, and defines stable union lookup order; first acquisition appends, reacquisition does not reorder, and final identity removal deletes its entry | MDS-013, MDS-039, MDS-075, LOCAL-085–087 |
| `set_value` refreshes the already acquired identity's decorations but never acquires or increments the refcount | CEW-004, MDS-016, MDS-043, MDS-074, LOCAL-022 |
| The one service-owned `model.on_did_change_content` watch per active identity refreshes/reseeds its existing owner on flush and never calls `acquire_model`; two Viewers sharing a model therefore trigger one service refresh | CEW-004, MDS-014, MDS-016, LOCAL-022, LOCAL-078, LOCAL-084, LOCAL-094 |
| Attach ordering is fixed: retain the Viewer decoration-event listener first; acquire the identity (install service content and `on_will_dispose` watches, then seed); only afterward retain the Viewer content, `on_will_dispose`, and token listeners. The service's ModelDisposed watcher therefore runs before Viewer detach can ordinary-release it, while seed/flush decoration events remain observable without duplicate per-Viewer refresh | CEW-008, CEW-011, CEW-085, CEW-092, MDS-002–003, LOCAL-021–025, LOCAL-094–095 |
| Identity removal has an explicit reason: `LeaseReleased`, `ModelDisposed`, or `ServiceDisposed`; every path may finalize and dispose its `MarkerDecorations` exactly once, but the reason controls MarkerService side effects | MDS-009, MDS-015, MDS-017, MDS-040, MDS-069, LOCAL-083, LOCAL-088 |
| Final `LeaseReleased` disposal removes the identity from both indexes, disposes its owner and both model watches, and never removes MarkerService diagnostics; refcount zero retains no historical-model watch | MDS-015, MDS-040, MDS-069, LOCAL-034, LOCAL-036, LOCAL-083, LOCAL-088, LOCAL-094–095 |
| Only a real `ModelDisposed` delivered to a currently active identity may remove transient MarkerService diagnostics, and only when deleting that identity leaves the URI bucket empty; a later model disposal after refcount zero is host-owned and unseen | MDS-015, MDS-017, MDS-040–041, MDS-069, LOCAL-080, LOCAL-088 |
| Preserve `get_marker(uri, decoration_id)`: scan the URI bucket, using instance-prefixed decoration ids for uniqueness. Preserve `get_live_markers(uri)`: concatenate every identity's live markers in acquisition order and document that union. Add `get_live_markers_for_model(model)` for hover so ranges cannot cross same-URI model identities | MDC-004–005, MDS-010–011, MDS-033–035, MDS-068, LOCAL-074, LOCAL-087 |
| `ServiceDisposed` first marks the service disposed and blocks marker-service subscription plus outward-emitter ingress; it then releases every identity content/dispose watch and owner once before finally clearing both indexes. It never disposes the injected MarkerService or removes its diagnostics | MDS-008–009, MDS-032, MDS-066–067, LOCAL-047, LOCAL-071, LOCAL-094–095 |

Recommended Phase 3 disposition: global ModelService seed/add/remove
subscriptions (MDS-006–008, MDS-066) and the complete global transient trigger
(MDS-017, MDS-041) are `DEFERRED (needs global ModelService)`. Identity-owner
present/absent removal and exact-once finalization (MDS-015, MDS-040, MDS-069)
remain implementable/testable through the reviewed reasoned-removal seam;
MDS-063 is N-A because the local MarkerService is non-optional. Ledger statuses
remain `TODO` at this inventory stop gate; approval is required before recording
those dispositions.

### ViewerServices ownership review proposal

Approve one explicit provenance rule before implementation:

| Construction/disposal path | Contract |
|---|---|
| `Viewer()` / `Viewer::create(host)` with services omitted | Resolve the optional parameter inside the constructor to `ViewerServices::new()` and store `owns_services=true`; do not use a default expression that erases whether the caller supplied a value |
| Any explicit `services=...` argument | Store the exact aggregate with `owns_services=false`; it is borrowed even when the caller created it with `ViewerServices::new()` |
| Borrowed aggregate on Viewer disposal | Release only Viewer-owned subscriptions/leases; do not dispose any service field |
| Default-owned aggregate on Viewer disposal | After contributions, Viewer subscriptions, ModelData, and DOM are gone, dispose `marker_decorations`, then `markers`, then `agent_feedback`; `languages` and `log_service` remain borrowed/global and `quick_diff` has no external subscription owner |

Viewer stores a disposed/idempotency flag, the provenance bit, retained
lifetime disposables, and a cancellable root render-frame handle. Tests must
cover both omitted/default-owned and explicit/borrowed construction; an
explicitly passed aggregate must remain usable after that Viewer is disposed.

## Inventory and Parity Ledger (Phases 1–2)

### Counting rule and exact denominator

The source ledger below is the authoritative atomic inventory. A row is one
scoped source member, constant/magic-value cluster, owned subscription, owned
DOM/CSS transition, or behavior-changing branch/early return. Every branch has
its own stable source ID; the prose branch checklist is only a second reading,
not a substitute for rows. Private owned emitters in `CodeEditorWidget` each
receive their own row. Public event aliases inside scoped complete units also
receive separate contract rows even though they share emitter lifetime.
Local-only audit rows use `LOCAL-*` IDs
and are explicitly outside the source denominator.

Exact source denominator:

```text
CEW 158 + CEC 15 + VIEW 115 + MDC 6 + MDCON 3 + MDS 76
+ GPMM 20 + SB 14 + CFG 20 = 427 source rows
```

All 427 source rows start `TODO`. No implementation status has been inferred
from similar-looking local code; review must first decide identity and shared-
service ownership seams.

### `codeEditorWidget.ts` source ledger — 158 rows

| ID | Source member (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| CEW-001 | `_deliveryQueue` (`codeEditorWidget.ts:78`) | Shared ordered delivery queue for editor events | no explicit queue; emitters are synchronous | TODO |
| CEW-002 | `_contributions` (`codeEditorWidget.ts:79`) | Registered once in the widget disposable store | `Viewer.contributions` | TODO |
| CEW-003 | `_onDidDispose` (`codeEditorWidget.ts:81`) | Registered emitter, disposed by `super.dispose()` | `Viewer.did_dispose` | TODO |
| CEW-004 | `_onDidChangeModelContent` (`codeEditorWidget.ts:84`) | Registered delivery-queue emitter | `Viewer.did_change_model_content` | TODO |
| CEW-005 | `_onDidChangeModelLanguage` (`codeEditorWidget.ts:87`) | Registered delivery-queue emitter | no local public event | TODO |
| CEW-006 | `_onDidChangeModelLanguageConfiguration` (`codeEditorWidget.ts:90`) | Registered delivery-queue emitter | no local public event | TODO |
| CEW-007 | `_onDidChangeModelOptions` (`codeEditorWidget.ts:93`) | Registered delivery-queue emitter | no local public event | TODO |
| CEW-008 | `_onDidChangeModelDecorations` (`codeEditorWidget.ts:96`) | Registered delivery-queue emitter | model decoration listener/render generation | TODO |
| CEW-009 | `_onDidChangeLineHeight` (`codeEditorWidget.ts:99`) | Registered delivery-queue emitter | no local public event | TODO |
| CEW-010 | `_onDidChangeFont` (`codeEditorWidget.ts:102`) | Registered delivery-queue emitter | `FontMeasurements.did_change` is separate | TODO |
| CEW-011 | `_onDidChangeModelTokens` (`codeEditorWidget.ts:105`) | Registered delivery-queue emitter | model token listener | TODO |
| CEW-012 | `_onDidChangeConfiguration` (`codeEditorWidget.ts:108`) | Registered delivery-queue emitter | configuration routing is direct | TODO |
| CEW-013 | `_onWillChangeModel` (`codeEditorWidget.ts:111`) | Fires before detach/attach | no local `onWillChangeModel` | TODO |
| CEW-014 | `_onDidChangeModel` (`codeEditorWidget.ts:114`) | Fires before post-detach decoration cleanup | `Viewer.did_change_model` | TODO |
| CEW-015 | `_onDidChangeCursorPosition` (`codeEditorWidget.ts:117`) | Registered delivery-queue emitter | `Viewer.did_change_cursor_position` | TODO |
| CEW-016 | `_onDidChangeCursorSelection` (`codeEditorWidget.ts:120`) | Registered delivery-queue emitter | `Viewer.did_change_cursor_selection` | TODO |
| CEW-017 | `_onDidAttemptReadOnlyEdit` (`codeEditorWidget.ts:123`) | Contribution-aware interaction emitter | no local event | TODO |
| CEW-018 | `_onDidLayoutChange` (`codeEditorWidget.ts:126`) | Registered delivery-queue emitter | no local public event | TODO |
| CEW-019 | `_editorTextFocus` (`codeEditorWidget.ts:129`) | Registered boolean emitter with true/false edges | `Viewer.editor_has_focus` | TODO |
| CEW-020 | `_editorWidgetFocus` (`codeEditorWidget.ts:133`) | Registered boolean emitter with true/false edges | `Viewer.has_widget_focus` query only | TODO |
| CEW-021 | `_onWillType` (`codeEditorWidget.ts:137`) | Registered contribution-aware emitter | N-A candidate: readonly edit path | TODO |
| CEW-022 | `_onDidType` (`codeEditorWidget.ts:140`) | Registered contribution-aware emitter | N-A candidate: readonly edit path | TODO |
| CEW-023 | `_onDidCompositionStart` (`codeEditorWidget.ts:143`) | Registered contribution-aware emitter | N-A candidate: no edit context | TODO |
| CEW-024 | `_onDidCompositionEnd` (`codeEditorWidget.ts:146`) | Registered contribution-aware emitter | N-A candidate: no edit context | TODO |
| CEW-025 | `_onDidPaste` (`codeEditorWidget.ts:149`) | Registered contribution-aware emitter | N-A candidate: readonly edit path | TODO |
| CEW-026 | `_onWillCopy` (`codeEditorWidget.ts:152`) | Registered contribution-aware emitter | root copy callback, not retained | TODO |
| CEW-027 | `_onWillCut` (`codeEditorWidget.ts:155`) | Registered contribution-aware emitter | N-A candidate: readonly edit path | TODO |
| CEW-028 | `_onWillPaste` (`codeEditorWidget.ts:158`) | Registered contribution-aware emitter | N-A candidate: readonly edit path | TODO |
| CEW-029 | `_onMouseUp` (`codeEditorWidget.ts:161`) | Registered contribution-aware emitter | `Viewer.did_mouse_up` | TODO |
| CEW-030 | `_onMouseDown` (`codeEditorWidget.ts:164`) | Registered contribution-aware emitter | `Viewer.did_mouse_down` | TODO |
| CEW-031 | `_onMouseDrag` (`codeEditorWidget.ts:167`) | Registered contribution-aware emitter | controller dispatch seam | TODO |
| CEW-032 | `_onMouseDrop` (`codeEditorWidget.ts:170`) | Registered contribution-aware emitter | N-A candidate: readonly DnD | TODO |
| CEW-033 | `_onMouseDropCanceled` (`codeEditorWidget.ts:173`) | Registered contribution-aware emitter | N-A candidate: readonly DnD | TODO |
| CEW-034 | `_onDropIntoEditor` (`codeEditorWidget.ts:176`) | Registered contribution-aware emitter | N-A candidate: readonly DnD | TODO |
| CEW-035 | `_onContextMenu` (`codeEditorWidget.ts:179`) | Registered contribution-aware emitter | no local public event | TODO |
| CEW-036 | `_onMouseMove` (`codeEditorWidget.ts:182`) | Registered contribution-aware emitter | `Viewer.did_mouse_move` | TODO |
| CEW-037 | `_onMouseLeave` (`codeEditorWidget.ts:185`) | Registered contribution-aware emitter | `Viewer.did_mouse_leave` | TODO |
| CEW-038 | `_onMouseWheel` (`codeEditorWidget.ts:188`) | Registered contribution-aware emitter | no local public event | TODO |
| CEW-039 | `_onKeyUp` (`codeEditorWidget.ts:191`) | Registered contribution-aware emitter | no local public event | TODO |
| CEW-040 | `_onKeyDown` (`codeEditorWidget.ts:194`) | Registered contribution-aware emitter | root keydown callback, not retained | TODO |
| CEW-041 | `_onDidContentSizeChange` (`codeEditorWidget.ts:197`) | Registered delivery-queue emitter | no local public event | TODO |
| CEW-042 | `_onDidScrollChange` (`codeEditorWidget.ts:200`) | Registered delivery-queue emitter | `Viewer.did_scroll` | TODO |
| CEW-043 | `_onDidChangeViewZones` (`codeEditorWidget.ts:203`) | Registered delivery-queue emitter | no local public event | TODO |
| CEW-044 | `_onDidChangeHiddenAreas` (`codeEditorWidget.ts:206`) | Registered delivery-queue emitter | no local public event | TODO |
| CEW-045 | `_onWillTriggerEditorOperationEvent` (`codeEditorWidget.ts:211`) | Registered emitter | N-A candidate: readonly operations | TODO |
| CEW-046 | `_onBeginUpdate` (`codeEditorWidget.ts:214`) | Registered update-bracket emitter | no local begin/end bracket | TODO |
| CEW-047 | `_onEndUpdate` (`codeEditorWidget.ts:217`) | Registered update-bracket emitter | no local begin/end bracket | TODO |
| CEW-048 | `_onBeforeExecuteEdit` (`codeEditorWidget.ts:220`) | Registered emitter | N-A candidate: readonly edit path | TODO |
| CEW-049 | `_domElement` (`codeEditorWidget.ts:235`) | Host-owned container retained for widget lifetime | `Viewer.container` | TODO |
| CEW-050 | `_overflowWidgetsDomNode` (`codeEditorWidget.ts:236`) | Optional external host for overflowing widgets; children remain View-owned | no external overflow host option | TODO |
| CEW-051 | `_id` (`codeEditorWidget.ts:237,295`) | Pre-incremented editor id; decoration owner id | `Viewer.editor_id` / `next_editor_id` | TODO |
| CEW-052 | `_configuration` (`codeEditorWidget.ts:238,300-315`) | Registered configuration plus owned change subscription | `Viewer.options` + measured/font state | TODO |
| CEW-053 | `_contributionsDisposable` (`codeEditorWidget.ts:239,544,2013-2014`) | One attach-scoped idle handle; dispose/reset before any no-model return | no local equivalent | TODO |
| CEW-054 | `_modelData` (`codeEditorWidget.ts:244`) | Nullable legal-state bundle | `Viewer.model_data` | TODO |
| CEW-055 | `_instantiationService` (`codeEditorWidget.ts:246,330`) | Registered child service scope | no DI child scope | TODO |
| CEW-056 | `_contextKeyService` (`codeEditorWidget.ts:247-248,317`) | Registered scoped context service | contribution registry context is local | TODO |
| CEW-057 | `_actions` (`codeEditorWidget.ts:241,429`) | Widget-owned map cleared on dispose | registry actions are global; instances not stored here | TODO |
| CEW-058 | `_contentWidgets` (`codeEditorWidget.ts:255,334,430`) | Widget registrations survive model swaps; map cleared on dispose | hover content widget field | TODO |
| CEW-059 | `_overlayWidgets` (`codeEditorWidget.ts:256,335,431`) | Widget registrations survive model swaps; map cleared on dispose | `Viewer.overlay_widgets` | TODO |
| CEW-060 | `_glyphMarginWidgets` (`codeEditorWidget.ts:257,336`) | Widget registrations survive model swaps | no glyph-margin widget API | TODO |
| CEW-061 | `_decorationTypeKeysToIds` (`codeEditorWidget.ts:262,296`) | Per-editor decoration-type ownership cleared/swept | editor owner-id decorations | TODO |
| CEW-062 | `_decorationTypeSubtypes` (`codeEditorWidget.ts:263,297`) | Per-editor subtype registry cleared/swept | no decoration-type registry | TODO |
| CEW-063 | `_bannerDomNode` (`codeEditorWidget.ts:265,2028-2030`) | Optional widget-owned DOM removed at detach | no banner API | TODO |
| CEW-064 | constructor (`codeEditorWidget.ts:271-408`) | Registers every widget-lifetime resource, initializes contributions, installs DnD observer, then registers editor service | `Viewer::Viewer` + `Viewer::attach` | TODO |
| CEW-065 | configuration listener (`codeEditorWidget.ts:303-315`) | Fires configuration first; layout branch next; font custom property branch last | `update_options` / `refresh_font_info` | TODO |
| CEW-066 | `EditorContextKeysManager` (`codeEditorWidget.ts:327`) | First context manager is independently registered in the widget store | no direct equivalent | TODO |
| CEW-067 | contribution initialization (`codeEditorWidget.ts:338-344`) | Explicit contribution list or global registry, then initialize once | `editor_registry().instantiate_all` | TODO |
| CEW-068 | `DragAndDropObserver` (`codeEditorWidget.ts:372-405`) | Registered DOM observer; every callback dies with widget store | no retained DnD observer | TODO |
| CEW-069 | code-editor service registration (`codeEditorWidget.ts:287,407,427`) | will-create → add; dispose removes before other teardown | no global editor service | TODO |
| CEW-070 | `--editor-font-size` (`codeEditorWidget.ts:303,313`) | Container custom property set initially and on font-size changes | root custom property in `apply_font_info_to_view` | TODO |
| CEW-071 | `dispose` (`codeEditorWidget.ts:426-439`) | remove service → clear registries → detach/post-cleanup → fire dispose → `super.dispose` | `Viewer::dispose` | TODO |
| CEW-072 | `setModel` (`codeEditorWidget.ts:506-548`) | begin/end update; no-op guards; will-change; detach/attach; focus; did-change; cleanup; attach contribution handle | `Viewer::set_model` | TODO |
| CEW-073 | `_attachModel` (`codeEditorWidget.ts:1750-1921`) | Null arm or complete ModelData construction with swap-scoped listeners and View DOM | `Viewer::attach_model` | TODO |
| CEW-074 | `_createView` (`codeEditorWidget.ts:1923-2006`) | Select command delegate; wire user-input relays; construct View | `Viewer::create_view` + controller helper | TODO |
| CEW-075 | `_postDetachModelCleanup` (`codeEditorWidget.ts:2008-2010`) | Remove all decorations for this editor owner id | outgoing-model owner-id sweep | TODO |
| CEW-076 | `_detachModel` (`codeEditorWidget.ts:2012-2032`) | Dispose attach contribution first; dispose bundle; clear DOM attributes/nodes; return model | `Viewer::detach_model` | TODO |
| CEW-077 | container `data-mode-id` (`codeEditorWidget.ts:1758,1865,2024`) | Set on attach/language change; remove on detach | local host attribute | TODO |
| CEW-078 | per-model root DOM (`codeEditorWidget.ts:1891,2019,2025-2027`) | Append after View creation; retain before disposal; remove only if still contained | local host append/remove | TODO |
| CEW-079 | view-root `data-uri` (`codeEditorWidget.ts:1912`) | Stamp attached model URI after initial render | local View root attribute | TODO |
| CEW-080 | View `onWillCopy` subscription (`codeEditorWidget.ts:1915`) | Independently pushed into ModelData listener array | local root copy callback is not retained | TODO |
| CEW-081 | `ModelData.model` (`codeEditorWidget.ts:2125`) | Caller-owned model identity; not disposed | `ModelData.model` | TODO |
| CEW-082 | `ModelData.viewModel` (`codeEditorWidget.ts:2126`) | Per-model owner; disposed last | `ModelData.view_model` | TODO |
| CEW-083 | `ModelData.view` (`codeEditorWidget.ts:2127`) | Per-model View; disposal gated by `hasRealView` | `ModelData.view?` | TODO |
| CEW-084 | `ModelData.hasRealView` (`codeEditorWidget.ts:2128`) | Controls View disposal and DOM capture | `view is Some` is implicit flag | TODO |
| CEW-085 | `ModelData.listenersToRemove` (`codeEditorWidget.ts:2129`) | Every swap-scoped subscription disposed first | `ModelData.listeners_to_remove` | TODO |
| CEW-086 | `ModelData.attachedView` (`codeEditorWidget.ts:2130`) | Token returned by model attach protocol and passed back on detach | no local attached-view protocol | TODO |
| CEW-087 | `ModelData` constructor (`codeEditorWidget.ts:2124-2132`) | Bundles all six fields without side effects | local struct literal | TODO |
| CEW-088 | `ModelData.dispose` (`codeEditorWidget.ts:2134-2141`) | listeners → model `onBeforeDetached` → real View → ViewModel | local `ModelData::dispose` | TODO |

### `codeEditorContributions.ts` source ledger — 15 rows

| ID | Source member (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| CEC-001 | `_editor` (`codeEditorContributions.ts:16`) | Nullable until one initialization | registry closures capture Viewer | TODO |
| CEC-002 | `_instantiationService` (`codeEditorContributions.ts:17`) | Nullable until initialization; caller-owned service | no DI service | TODO |
| CEC-003 | `_instances` (`codeEditorContributions.ts:22`) | Registered `DisposableMap`; owns every instantiated contribution | `Viewer.contributions` | TODO |
| CEC-004 | `_pending` (`codeEditorContributions.ts:26`) | Descriptions not yet instantiated | no pending map; all eager | TODO |
| CEC-005 | `_finishedInstantiation` (`codeEditorContributions.ts:30`) | Boolean slots for all four timing modes | modes recorded but all eager | TODO |
| CEC-006 | constructor (`codeEditorContributions.ts:32-41`) | Initializes Eager/AfterFirstRender/BeforeFirstInteraction/Eventually to false | registry construction | TODO |
| CEC-007 | `initialize` (`codeEditorContributions.ts:43-77`) | Store editor/service; reject duplicate ids; seed pending; eager instantiate; register three idle handles | `instantiate_all` | TODO |
| CEC-008 | AfterFirstRender idle handle (`codeEditorContributions.ts:60-62`) | Independently registered in the base disposable store | no lazy handles | TODO |
| CEC-009 | `onAfterModelAttached` (`codeEditorContributions.ts:114-118`) | Return caller-owned/cancelable 50-ms idle handle | no local attach contribution handle | TODO |
| CEC-010 | attach delay constant (`codeEditorContributions.ts:117`) | `50` ms latest AfterFirstRender instantiation | no local timing | TODO |
| CEC-011 | inherited `Disposable.dispose` (`codeEditorContributions.ts:14,22,60-76`) | Disposes instances and registered idle handles exactly once | explicit contribution loop only | TODO |

### `view.ts` source ledger — 115 rows

| ID | Source member (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| VIEW-001 | `_widgetFocusTracker` (`view.ts:88,149-151`) | Registered focus-tracker field owned by View | anonymous root focus/blur callbacks | TODO |
| VIEW-002 | `_scrollbar` (`view.ts:90,195-196`) | Per-View part retained and disposed through `_viewParts` | `View.editor_scrollbar` | TODO |
| VIEW-003 | `_context` (`view.ts:91,166-169`) | Per-View context; View registers itself first as event handler | no `ViewContext` event registry | TODO |
| VIEW-004 | `_viewGpuContext` (`view.ts:92,191-193`) | Optional GPU owner, disposed explicitly | N-A candidate: no GPU renderer | TODO |
| VIEW-005 | `_selections` (`view.ts:93,156`) | Initial selection is `(1,1,1,1)` | selection lives in ViewModel | TODO |
| VIEW-006 | `_viewLines` (`view.ts:96,199`) | Per-View special part, explicitly disposed outside `_viewParts` | `View.view_lines` | TODO |
| VIEW-007 | `_viewLinesGpu` (`view.ts:97,200-202`) | Optional GPU lines, explicitly disposed | N-A candidate | TODO |
| VIEW-008 | `_viewZones` (`view.ts:100,205-206`) | Per-View part retained and in `_viewParts` | `View.view_zones` | TODO |
| VIEW-009 | `_contentWidgets` (`view.ts:101,245-246`) | Per-View part plus overflowing node | `View.content_widgets` | TODO |
| VIEW-010 | `_overlayWidgets` (`view.ts:102,252-253`) | Per-View part plus overflowing node | `View.overlay_widgets` | TODO |
| VIEW-011 | `_glyphMarginWidgets` (`view.ts:103,235-236`) | Per-View part retained and in `_viewParts` | no glyph-margin widgets | TODO |
| VIEW-012 | `_viewCursors` (`view.ts:104,248-249`) | Per-View part retained and in `_viewParts` | `View.view_cursors` | TODO |
| VIEW-013 | `_viewParts` (`view.ts:105,171`) | Ordered disposal owner for constructed parts | `View.view_parts` | TODO |
| VIEW-014 | `_viewController` (`view.ts:106,163`) | Per-View controller, not a disposable | root controller closures | TODO |
| VIEW-015 | `_editContextEnabled` (`view.ts:108,174`) | Captures ownership-switching option | N-A candidate: no edit context | TODO |
| VIEW-016 | `_accessibilitySupport` (`view.ts:109,175`) | Participates in edit-context replacement equality guard | no edit context | TODO |
| VIEW-017 | `_editContext` (`view.ts:110,176-179`) | Per-View part; can be disposed/replaced at runtime | no edit context | TODO |
| VIEW-018 | `_editContextClipboardListeners` (`view.ts:111`) | Dedicated `DisposableStore`, cleared on reconnect and disposed on View disposal | no retained clipboard store | TODO |
| VIEW-019 | `_pointerHandler` (`view.ts:112,303`) | Registered View-lifetime pointer handler | `Viewer.mouse_handler` is not View-owned | TODO |
| VIEW-020 | `_onWillCopy` (`view.ts:115`) | Registered View-lifetime emitter | root copy callback | TODO |
| VIEW-021 | `_onWillCut` (`view.ts:118`) | Registered View-lifetime emitter | N-A candidate: readonly | TODO |
| VIEW-022 | `_onWillPaste` (`view.ts:121`) | Registered View-lifetime emitter | N-A candidate: readonly | TODO |
| VIEW-023 | `_linesContent` (`view.ts:125,182-184`) | Sole 2^24-pixel scrolling rail shared with scrollbar and lines | `View.lines_content` | TODO |
| VIEW-024 | `domNode` (`view.ts:126,186-189`) | Per-model root; parent widget removes it | `View.root` | TODO |
| VIEW-025 | `_overflowGuardContainer` (`view.ts:127,159-161`) | Root-owned overflow guard | `View.overflow_guard` | TODO |
| VIEW-026 | `_shouldRecomputeGlyphMarginLanes` (`view.ts:130`) | View mutable state only; no external lifetime | no glyph margin | TODO |
| VIEW-027 | `_renderAnimationFrame` (`view.ts:131,157`) | Nullable scheduled frame disposed/reset first | Viewer render scheduler state | TODO |
| VIEW-028 | `_ownerID` (`view.ts:132,147`) | Editor owner id passed to edit context | `Viewer.editor_id` | TODO |
| VIEW-029 | constructor (`view.ts:134-304`) | Constructs all owned parts/DOM in source order, applies layout, then registers pointer handler | `View::new` + `hook_view_input` | TODO |
| VIEW-030 | `_instantiateEditContext` (`view.ts:306-313`) | `effectiveEditContext` chooses Native vs TextArea owner | N-A candidate | TODO |
| VIEW-031 | `_updateEditContext` (`view.ts:315-334`) | Equal options early return; preserve focus/index; dispose old; rebuild/listen; restore/replace conditionally | N-A candidate | TODO |
| VIEW-032 | `_connectEditContextClipboardEvents` (`view.ts:336-344`) | Method clears the old listener store before reconnecting | root copy callback only | TODO |
| VIEW-033 | `_applyLayout` (`view.ts:444-457`) | Root and overflow use layout width/height; rail is fixed at 2^24 each axis | fixed rail plus CSS sizing | TODO |
| VIEW-034 | `_getEditorClassName` (`view.ts:459-462`) | configured editor class + theme selector + optional ` focused` | local `get_editor_class_name` | TODO |
| VIEW-035 | `onConfigurationChanged` (`view.ts:469-474`) | Reclass, update edit-context owner, apply layout | local render/options path | TODO |
| VIEW-036 | `onFocusChanged` (`view.ts:485-488`) | Recompute root class | local render snapshot focus | TODO |
| VIEW-037 | `onThemeChanged` (`view.ts:489-493`) | Update context theme then recompute root class | `Viewer::apply_theme` | TODO |
| VIEW-038 | `dispose` (`view.ts:497-521`) | Frame → clipboard store → external overflow nodes → context/GPU/lines → every ViewPart → base store | no local `View::dispose` | TODO |
| VIEW-039 | `DecorationsOverviewRuler` (`view.ts:208-210`) | Constructor-local owned ViewPart in `_viewParts` | N-A candidate: no overview ruler | TODO |
| VIEW-040 | `ScrollDecorationViewPart` (`view.ts:213-214`) | Constructor-local owned ViewPart in `_viewParts` | no scroll-decoration part | TODO |
| VIEW-041 | `ContentViewOverlays` (`view.ts:216-217`) | Constructor-local owned ViewPart in `_viewParts` | `View.content_view_overlays` | TODO |
| VIEW-042 | `CurrentLineHighlightOverlay` (`view.ts:218`) | Owned by content overlay in first position | local content overlay current line | TODO |
| VIEW-043 | `SelectionsOverlay` (`view.ts:219`) | Owned by content overlay in second position | local selections overlay | TODO |
| VIEW-044 | `IndentGuidesOverlay` (`view.ts:220`) | Owned by content overlay in third position | N-A candidate: no indent guides | TODO |
| VIEW-045 | `DecorationsOverlay` (`view.ts:221`) | Owned by content overlay in fourth position | local decorations overlay | TODO |
| VIEW-046 | `WhitespaceOverlay` (`view.ts:222`) | Owned by content overlay in fifth position | local whitespace rendering is in lines | TODO |
| VIEW-047 | `MarginViewOverlays` (`view.ts:224-225`) | Constructor-local owned ViewPart in `_viewParts` | `View.margin_view_overlays` | TODO |
| VIEW-048 | `CurrentLineMarginHighlightOverlay` (`view.ts:226`) | Owned by margin overlay first | local margin current line | TODO |
| VIEW-049 | `MarginViewLineDecorationsOverlay` (`view.ts:227`) | Owned by margin overlay second | local line decorations | TODO |
| VIEW-050 | `LinesDecorationsOverlay` (`view.ts:228`) | Owned by margin overlay third | local line decorations role | TODO |
| VIEW-051 | `LineNumbersOverlay` (`view.ts:229`) | Owned by margin overlay fourth | local line numbers | TODO |
| VIEW-052 | `GpuMarkOverlay` (`view.ts:230-232`) | Optional GPU-only dynamic overlay | N-A candidate | TODO |
| VIEW-053 | `Margin` (`view.ts:238-242`) | Owns margin child-node order and is a ViewPart | local margin overlays have no separate wrapper owner | TODO |
| VIEW-054 | `RulersGpu` / `Rulers` (`view.ts:255-258`) | GPU branch chooses exactly one owned ViewPart | N-A candidate: no rulers | TODO |
| VIEW-055 | `BlockDecorations` (`view.ts:260-261`) | Constructor-local owned ViewPart | no block-outline part | TODO |
| VIEW-056 | `Minimap` (`view.ts:263-264`) | Constructor-local owned ViewPart | N-A candidate: no minimap | TODO |
| VIEW-057 | overflow-guard fingerprint/class (`view.ts:159-161`) | `div`, fingerprint OverflowGuard, class `overflow-guard` | local same class/fingerprint | TODO |
| VIEW-058 | lines-content class/position (`view.ts:182-184`) | `lines-content monaco-editor-background`; absolute | local `lines-content moonbit-viewer-background`; absolute | TODO |
| VIEW-059 | root class/role (`view.ts:186-189`) | computed editor class and `role=code` | local section class, aria-label, tabindex; no role | TODO |
| VIEW-060 | margin DOM child order (`view.ts:238-241`) | zones margin → margin overlays → glyph widgets | local margin tree differs | TODO |
| VIEW-061 | lines-content child order (`view.ts:273-280`) | content overlays → optional rulers → zones → lines → content widgets → cursors | local order omits rulers | TODO |
| VIEW-062 | overflow-guard child order (`view.ts:281-289`) | margin → scrollbar → optional GPU canvas → scroll decoration → overlay widgets → minimap → block outline | local margin → scrollbar → overlay widgets | TODO |
| VIEW-063 | root overflow-guard append (`view.ts:290`) | Root owns overflow guard | local root append | TODO |
| VIEW-064 | overflowing-widget parent branch (`view.ts:292-298`) | External host when supplied; otherwise root; both nodes remain View-owned | local always root | TODO |
| VIEW-065 | rail-size constant (`view.ts:454-456`) | width = height = `16777216` (`2^24`) | local exact constant | TODO |
| VIEW-066 | pointer-handler registration (`view.ts:302-303`) | Created only after all DOM/layout and registered in base store | `MouseHandler::new` stored outside View | TODO |
| VIEW-067 | focus tracker `_hasDomElementFocus` (`view.ts:935,949`) | Starts false; set by root focus/blur | `Viewer.editor_has_focus` | TODO |
| VIEW-068 | focus tracker `_domFocusTracker` (`view.ts:936,950`) | Registered user-interaction focus tracker | anonymous root listeners | TODO |
| VIEW-069 | focus tracker `_overflowWidgetsDomNode` (`view.ts:937,963-972`) | Optional registered external-node focus tracker and two subscriptions | no external overflow host | TODO |
| VIEW-070 | focus tracker `_onChange` (`view.ts:939-940`) | Registered emitter | no retained focus emitter | TODO |
| VIEW-071 | `_overflowWidgetsDomNodeHasFocus` (`view.ts:942,952`) | Starts false; updated by optional tracker | no equivalent | TODO |
| VIEW-072 | `_hadFocus` (`view.ts:944`) | `undefined` sentinel makes first update observable | local bool starts false | TODO |
| VIEW-073 | focus tracker constructor (`view.ts:946-974`) | Initializes focus state and conditionally creates the overflow tracker | root focus/blur callbacks | TODO |
| VIEW-074 | focus tracker `_update` (`view.ts:976-982`) | OR both focus sources; emit only when aggregate changed | no aggregate tracker | TODO |
| VIEW-075 | focus tracker `hasFocus` (`view.ts:984-986`) | Undefined falls back to false | `has_widget_focus` DOM containment | TODO |
| VIEW-076 | focus tracker `refreshState` (`view.ts:988-991`) | Refresh root then optional overflow tracker | no equivalent | TODO |
| VIEW-077 | overflowing content node removal (`view.ts:506`) | Remove even when parent is external | local removed only with entire root | TODO |
| VIEW-078 | overflowing overlay node removal (`view.ts:507`) | Remove even when parent is external | local removed only with entire root | TODO |
| VIEW-079 | root-node disposal boundary (`view.ts:497-521`; `codeEditorWidget.ts:2019-2027`) | `View.dispose` releases internals; parent widget separately removes root | local parent removes root without `View::dispose` | TODO |

### Marker-decoration contract ledgers — 9 rows

| ID | Source member (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| MDC-001 | `IMarkerDecorationsService` decorator (`common/services/markerDecorations.ts:14`) | Singleton service identity | concrete `ViewerServices.marker_decorations` | TODO |
| MDC-002 | `_serviceBrand` (`common/services/markerDecorations.ts:17`) | Type-only service brand | N-A candidate | TODO |
| MDC-003 | `onDidChangeMarker` (`common/services/markerDecorations.ts:19`) | Changed-model event | `on_did_change_marker_decorations` | TODO |
| MDC-004 | `getMarker` (`common/services/markerDecorations.ts:21`) | URI plus decoration identity → marker/null | `get_marker(uri, decoration_id)` | TODO |
| MDC-005 | `getLiveMarkers` (`common/services/markerDecorations.ts:23`) | URI → live `(range, marker)` pairs | `get_live_markers` | TODO |
| MDC-006 | `addMarkerSuppression` (`common/services/markerDecorations.ts:25`) | URI/range suppression returns removal disposable | `add_marker_suppression` | TODO |
| MDCON-001 | `MarkerDecorationsContribution.ID` (`browser/services/markerDecorations.ts:12`) | Constant `editor.contrib.markerDecorations` | no dedicated contribution | TODO |
| MDCON-002 | constructor (`browser/services/markerDecorations.ts:14-19`) | Instantiation dependency only; owns nothing | service currently constructed by `ViewerServices::new` | TODO |
| MDCON-003 | `dispose` (`browser/services/markerDecorations.ts:21-22`) | Deliberate no-op | no dedicated contribution | TODO |

### `markerDecorationsService.ts` source ledger — 76 rows

| ID | Source member (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| MDS-001 | `_serviceBrand` (`markerDecorationsService.ts:26`) | Type-only service brand | N-A candidate | TODO |
| MDS-002 | `_onDidChangeMarker` (`markerDecorationsService.ts:28`) | Registered emitter owned by service base store | `did_change_marker_decorations` | TODO |
| MDS-003 | `onDidChangeMarker` (`markerDecorationsService.ts:29`) | Public event alias | `on_did_change_marker_decorations` | TODO |
| MDS-004 | `_suppressedRanges` (`markerDecorationsService.ts:31`) | URI-keyed suppression sets | local URI-string map of arrays | TODO |
| MDS-005 | `_markerDecorations` (`markerDecorationsService.ts:33`) | URI-keyed per-model owners; lifetime fed by global `IModelService` | local URI-string map fed by Viewer calls | TODO |
| MDS-006 | constructor (`markerDecorationsService.ts:35-44`) | Seed every existing ModelService model, then retain three subscriptions | `MarkerDecorationsService::new` only subscribes to markers | TODO |
| MDS-007 | existing-model seed (`markerDecorationsService.ts:40`) | Call `_onModelAdded` for every already-live model before subscribing | no shared model registry | TODO |
| MDS-008 | model-added subscription (`markerDecorationsService.ts:41`) | Independently registered in the service store | no shared model registry | TODO |
| MDS-009 | `dispose` (`markerDecorationsService.ts:46-50`) | Base subscriptions/emitter first; dispose every per-model owner; clear map | local clears map without owner disposal | TODO |
| MDS-010 | `getMarker` (`markerDecorationsService.ts:52-55`) | Missing URI owner → null; otherwise id lookup/null | local URI-only lookup | TODO |
| MDS-011 | `getLiveMarkers` (`markerDecorationsService.ts:57-60`) | Missing URI owner → empty; otherwise live ranges | local URI-only lookup | TODO |
| MDS-012 | `addMarkerSuppression` (`markerDecorationsService.ts:62-82`) | Create/find set, add+refresh; disposable removes, drops empty set, refreshes | local suppression disposable | TODO |
| MDS-013 | `_handleMarkerChange` (`markerDecorationsService.ts:84-91`) | For each changed URI, update only when a registered owner exists | `handle_marker_change` | TODO |
| MDS-014 | `_onModelAdded` (`markerDecorationsService.ts:93-97`) | Construct owner, URI-keyed `set`, then seed; source relies on ModelService URI uniqueness and does not dispose an overwritten entry | `on_model_added` needs identity-aware storage | TODO |
| MDS-015 | `_onModelRemoved` (`markerDecorationsService.ts:99-112`) | If registered: dispose then delete; then transient-marker cleanup | `on_model_removed` | TODO |
| MDS-016 | `_updateDecorations` (`markerDecorationsService.ts:114-129`) | Read, suppress-filter, update, and fire only on changed set | `update_decorations` | TODO |
| MDS-017 | transient schemes (`markerDecorationsService.ts:107-110`) | `inMemory || internal || vscode`; remove every owner for removed model URI | local exact literal strings | TODO |
| MDS-018 | marker cap (`markerDecorationsService.ts:115-116`) | Read only first `500` markers | local `take=500` | TODO |
| MDS-019 | `MarkerDecorations._map` (`markerDecorationsService.ts:134`) | Bidirectional marker-identity ↔ decoration-id owner state | local entry array uses structural equality | TODO |
| MDS-020 | `MarkerDecorations.model` (`markerDecorationsService.ts:136-138`) | Exact model identity owned by registration | local field | TODO |
| MDS-021 | `MarkerDecorations` constructor (`markerDecorationsService.ts:136-144`) | Registers a dispose hook tied to model+map | local plain constructor, explicit dispose only | TODO |
| MDS-022 | constructor dispose hook (`markerDecorationsService.ts:140-143`) | Delta every current id to empty, then clear map | `MarkerDecorations::dispose` | TODO |
| MDS-023 | `MarkerDecorations.update` (`markerDecorationsService.ts:146-173`) | Identity diff; no-op false; delta removed/added; maintain map; true | local structural diff/update | TODO |
| MDS-024 | `MarkerDecorations.getMarker` (`markerDecorationsService.ts:175-177`) | Reverse lookup by decoration id | local `get_marker` | TODO |
| MDS-025 | `MarkerDecorations.getMarkers` (`markerDecorationsService.ts:179-188`) | Resolve each current decoration range; skip missing ranges | local `get_markers` | TODO |
| MDS-026 | `_createDecorationRange` (`markerDecorationsService.ts:190-224`) | Hint truncation → validation → empty/full-line branches → final range | local `create_decoration_range`; arithmetic out of implementation scope | TODO |
| MDS-027 | range constants (`markerDecorationsService.ts:194-220`) | Hint `+2`; empty-line sentinel `1`; full-line `Number.MAX_VALUE`; mutate start column | local `+2`, `1`, `max_value_column` | TODO |
| MDS-028 | `_createDecorationOption` (`markerDecorationsService.ts:226-297`) | Severity matrix, tag overrides, and returned option record | local `create_decoration_option`; rendering style out of scope | TODO |
| MDS-029 | severity z-indices (`markerDecorationsService.ts:243,248,257,267`) | Hint `0`, Info `10`, Warning `20`, Error/default `30` | local exact values | TODO |
| MDS-030 | option constants (`markerDecorationsService.ts:249-296`) | minimap Inline; description `marker-decoration`; NeverGrows; collapsed true; overview Right | local exact carrier values | TODO |
| MDS-031 | `_hasMarkerTag` (`markerDecorationsService.ts:299-304`) | Tags present → membership; absent → false | `Marker::has_tag` | TODO |

### `globalPointerMoveMonitor.ts` source ledger — 20 rows

| ID | Source member (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| GPMM-001 | `IPointerMoveCallback` (`globalPointerMoveMonitor.ts:9-11`) | Pointer event callback contract | local MouseEvent callback (pointer FFI gap) | TODO |
| GPMM-002 | `IOnStopCallback` (`globalPointerMoveMonitor.ts:13-15`) | Optional pointer/keyboard stop-event contract | local optional generic Event | TODO |
| GPMM-003 | `_hooks` (`globalPointerMoveMonitor.ts:19`) | `DisposableStore` owns capture release and active listeners | local disposable array | TODO |
| GPMM-004 | `_pointerMoveCallback` (`globalPointerMoveMonitor.ts:20`) | Null means not monitoring | local optional callback | TODO |
| GPMM-005 | `_onStopCallback` (`globalPointerMoveMonitor.ts:21`) | Cleared before optional invocation | local optional callback | TODO |
| GPMM-006 | `dispose` (`globalPointerMoveMonitor.ts:23-26`) | `stopMonitoring(false)` then permanently dispose hook store | local only stops; array remains reusable | TODO |
| GPMM-007 | `stopMonitoring` (`globalPointerMoveMonitor.ts:28-43`) | Inactive early return; clear hooks/callbacks; optionally invoke captured callback | local `stop_monitoring` | TODO |
| GPMM-008 | `isMonitoring` (`globalPointerMoveMonitor.ts:45-47`) | Boolean coercion of move callback | local option test | TODO |
| GPMM-009 | `startMonitoring` (`globalPointerMoveMonitor.ts:49-111`) | Stop prior monitor without callback; set callbacks; capture/fallback; install move/up | local window-fallback implementation | TODO |
| GPMM-010 | pointer-capture hook (`globalPointerMoveMonitor.ts:62-89`) | Try capture; retain release disposable; ignore release failure; capture failure switches source to window | FFI gap always selects window | TODO |
| GPMM-011 | pointer-move listener (`globalPointerMoveMonitor.ts:91-104`) | Buttons mismatch calls `stopMonitoring(true)` without forwarding the pointer event, then returns; otherwise prevent default then callback | local retained removal disposable | TODO |
| GPMM-012 | pointer-up listener (`globalPointerMoveMonitor.ts:106-110`) | Any pointerup calls `stopMonitoring(true)` without forwarding the pointer event; listener is in hook store | local retained removal disposable | TODO |

### `abstractScrollbar.ts` source ledger — 14 rows

| ID | Source member (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| SB-001 | `POINTER_DRAG_RESET_DISTANCE` (`abstractScrollbar.ts:17-20`) | Orthogonal Windows reset threshold = `140` px | local scrollbar drag has no reset | TODO |
| SB-002 | `_pointerMoveMonitor` (`abstractScrollbar.ts:52`) | One monitor owned by scrollbar Widget | current scrollbar path has no monitor field | TODO |
| SB-003 | constructor listener ownership (`abstractScrollbar.ts:68,77`) | Register the pointer monitor and the scrollbar-root pointerdown listener in the Widget store; trough behavior remains excluded | listeners split between per-view and document | TODO |
| SB-004 | `_createSlider` (`abstractScrollbar.ts:94-127`) | Method constructs the slider and installs two independently owned listeners; geometry remains excluded | local slider constructed elsewhere | TODO |
| SB-005 | slider `active` class (`abstractScrollbar.ts:247,268`) | True before monitor start; false only in stop callback | local `set_slider_active` | TODO |
| SB-006 | `_sliderPointerDown` (`abstractScrollbar.ts:240-274`) | Invalid target early return; snapshot start positions/state; start monitor; notify drag start | `start_scrollable_drag` plus permanent document callbacks | TODO |
| SB-007 | drag-move reset/delta (`abstractScrollbar.ts:253-266`) | `abs(orthogonal-start)`; Windows `>140` resets to initial and returns; else apply along-axis delta | local only along-axis delta | TODO |
| SB-008 | inherited `Widget`/`DisposableStore` cleanup (`widget.ts:12-19`; `lifecycle.ts:416-440,542-555`) | `_register` routes monitor/listeners into an idempotent store; its first dispose clears each entry and later dispose returns | `MouseHandler::dispose` exists but is not called by View teardown | TODO |

### `editorConfiguration.ts` source ledger — 20 rows

| ID | Source member (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| CFG-001 | `_onDidChange` (`editorConfiguration.ts:42-43`) | Registered ordinary configuration emitter | direct option routing | TODO |
| CFG-002 | `_onDidChangeFast` (`editorConfiguration.ts:45-46`) | Registered fast configuration emitter | direct option routing | TODO |
| CFG-003 | `_containerObserver` (`editorConfiguration.ts:50,83`) | Registered observer owns container measurement hooks | explicit `layout`/measure; no observer object | TODO |
| CFG-004 | constructor (`editorConfiguration.ts:73-101`) | Build observer/options; optional observe; retain seven external subscriptions | `Viewer::attach` + `update_options` | TODO |
| CFG-005 | automatic-layout branch (`editorConfiguration.ts:90-92`) | Start observer only when computed option is true | no automatic observer | TODO |
| CFG-006 | EditorZoom subscription (`editorConfiguration.ts:94`) | Registered external callback → recompute | no zoom service | TODO |
| CFG-007 | TabFocus subscription (`editorConfiguration.ts:95`) | Registered external callback → recompute | no tab-focus service | TODO |
| CFG-008 | container-size subscription (`editorConfiguration.ts:96`) | Registered observer callback → recompute | explicit layout only | TODO |
| CFG-009 | FontMeasurements subscription (`editorConfiguration.ts:97`) | Registered external callback → recompute | `Viewer::attach` subscribes but drops disposable | TODO |
| CFG-010 | PixelRatio subscription (`editorConfiguration.ts:98`) | Registered per-window callback → recompute | device ratio read only | TODO |
| CFG-011 | accessibility subscription (`editorConfiguration.ts:99`) | Registered service callback → recompute | no accessibility service | TODO |
| CFG-012 | InputMode subscription (`editorConfiguration.ts:100`) | Registered global callback → recompute | no input-mode service | TODO |
| CFG-013 | `_recomputeOptions` (`editorConfiguration.ts:103-114`) | Compute/check; null early return; assign; fire fast then ordinary | `on_configuration_changed` | TODO |
| CFG-014 | `_readFontInfo` (`editorConfiguration.ts:157-159`) | Read singleton font cache for target window id | `font_measurements().read_font_info` | TODO |
| CFG-015 | inherited `Disposable.dispose` (`editorConfiguration.ts:40,42-50,83-100`) | Disposes emitters, observer, and all seven subscriptions | no retained configuration owner | TODO |

### Source-member and branch rows completing the denominator

The following rows turn every branch/early return and the independently found
ownership fields into first-class ledger items. Their IDs continue the source-
unit sequences above.

| ID | Source member/branch (pinned file:line) | Arithmetic / transition / ownership | MoonBit symbol or seam | Status |
|---|---|---|---|---|
| CEW-089 | `_updateCounter` (`codeEditorWidget.ts:209`) | Nesting counter for begin/end update events | no local update counter | TODO |
| CEW-090 | `_beginUpdate` (`codeEditorWidget.ts:2072-2077`) | Increment, then fire begin only at depth 1 | no local bracket | TODO |
| CEW-091 | `_endUpdate` (`codeEditorWidget.ts:2079-2084`) | Decrement, then fire end only at depth 0 | no local bracket | TODO |
| CEW-092 | model will-dispose subscription (`codeEditorWidget.ts:1786-1787`) | Swap-scoped disposable calls `setModel(null)` | local ModelData listener | TODO |
| CEW-093 | ViewModel event subscription (`codeEditorWidget.ts:1789-1887`) | One swap-scoped disposable owns the complete outgoing-event relay | no single local relay subscription | TODO |
| CEW-094 | `ViewUserInputEvents` callback owner (`codeEditorWidget.ts:1979-1990`) | Eleven callbacks close over widget emitters and live exactly as long as View | controller helper/root callbacks | TODO |
| CEW-095 | `_telemetryData` (`codeEditorWidget.ts:233,298`) | Borrowed immutable construction data; never disposed | no telemetry field | TODO |
| CEW-096 | `_notificationService` (`codeEditorWidget.ts:249,323`) | Injected borrowed service; never disposed by widget | no notification service | TODO |
| CEW-097 | `_codeEditorService` (`codeEditorWidget.ts:250,324`) | Injected borrowed registry; widget only add/removes itself | no editor registry service | TODO |
| CEW-098 | `_commandService` (`codeEditorWidget.ts:251,325`) | Injected borrowed service; never disposed | registry command closures | TODO |
| CEW-099 | `_themeService` (`codeEditorWidget.ts:252,326`) | Injected borrowed service; never disposed | theme is option/CSS data | TODO |
| CEW-100 | `_userInteractionService` (`codeEditorWidget.ts:253,292`) | Injected borrowed service passed into View/focus owner; never disposed | no service object | TODO |
| CEW-101 | `languageConfigurationService` (`codeEditorWidget.ts:282`) | Constructor parameter-property, borrowed and passed into ViewModel | languages registry is borrowed service | TODO |
| CEW-102 | `accessibilityService` (`codeEditorWidget.ts:281,300-302`) | Borrowed constructor argument passed into registered configuration | no accessibility service | TODO |
| CEW-103 | `languageFeaturesService` (`codeEditorWidget.ts:283,328`) | Borrowed constructor argument passed into registered context owner | `ViewerServices.languages` is borrowed | TODO |
| CEW-104 | `_dropIntoEditorDecorations` (`codeEditorWidget.ts:267`) | Widget-owned decorations collection used by registered DnD observer | N-A candidate: readonly DnD | TODO |
| CEW-105 | `EDITOR_ID` (`codeEditorWidget.ts:2087`) | Process counter, preincremented into `_id` | `editor_id_counter` | TODO |
| CEW-106 | constructor overflow-node option branch (`codeEditorWidget.ts:291-295`) | Optional external node is retained and deleted from options before configuration | no external overflow host | TODO |
| CEW-107 | constructor simple-widget default branch (`codeEditorWidget.ts:300-301`) | Missing/false `isSimpleWidget` resolves false | viewer is one readonly kind | TODO |
| CEW-108 | explicit context-menu-id branch (`codeEditorWidget.ts:301`) | Explicit id wins over derived default | no context menu id | TODO |
| CEW-109 | derived context-menu-id branch (`codeEditorWidget.ts:301`) | Missing id selects SimpleEditorContext vs EditorContext by widget kind | no context menu id | TODO |
| CEW-110 | optional style branch (`codeEditorWidget.ts:303`) | Initial font custom property is skipped only when style is absent | local root always Element | TODO |
| CEW-111 | configuration layout-info branch (`codeEditorWidget.ts:308-311`) | Fires layout event only when that option changed | direct layout path | TODO |
| CEW-112 | configuration font-size branch (`codeEditorWidget.ts:312-314`) | Rewrites font custom property only when font size changed | `apply_font_info_to_view` | TODO |
| CEW-113 | context-key-values branch (`codeEditorWidget.ts:318-322`) | Missing map is no-op; present map creates every key | no context key map | TODO |
| CEW-114 | explicit contributions branch (`codeEditorWidget.ts:338-341`) | Array supplied by caller is authoritative | registry always global | TODO |
| CEW-115 | registry contributions branch (`codeEditorWidget.ts:341-343`) | Non-array option loads global registry | `editor_registry` | TODO |
| CEW-116 | `setModel` both-null early return (`codeEditorWidget.ts:510-513`) | No detach, events, cleanup, or contribution rearm | local same | TODO |
| CEW-117 | `setModel` same-identity early return (`codeEditorWidget.ts:514-517`) | Physical model identity is the no-op key | local `physical_equal` | TODO |
| CEW-118 | `setModel` attached-model branch (`codeEditorWidget.ts:528-532`) | New real model may restore text focus | local `has_model` arm | TODO |
| CEW-119 | `setModel` retained-focus branch (`codeEditorWidget.ts:530-532`) | Focus only when pre-swap text focus was true | local same | TODO |
| CEW-120 | `setModel` no-model branch (`codeEditorWidget.ts:533-538`) | Clears both text and widget focus emitters | local clears one bool | TODO |
| CEW-121 | `setModel` finally branch (`codeEditorWidget.ts:545-547`) | `_endUpdate` runs for both early returns and failures | no local bracket | TODO |
| CEW-122 | `_attachModel` null early return (`codeEditorWidget.ts:1751-1754`) | Set bundle null and return before listeners/DOM | local None arm lives in caller | TODO |
| CEW-123 | ViewModel ContentSize arm (`codeEditorWidget.ts:1791-1793`) | Relay event | no local public event | TODO |
| CEW-124 | ViewModel Focus arm (`codeEditorWidget.ts:1794-1796`) | Update text-focus emitter | local focus DOM flag | TODO |
| CEW-125 | ViewModel WidgetFocus arm (`codeEditorWidget.ts:1797-1799`) | Update widget-focus emitter | DOM containment query | TODO |
| CEW-126 | ViewModel Scroll arm (`codeEditorWidget.ts:1800-1802`) | Relay scroll event | local layout subscription | TODO |
| CEW-127 | ViewModel ViewZones arm (`codeEditorWidget.ts:1803-1805`) | Fire zone-change event | no local public event | TODO |
| CEW-128 | ViewModel HiddenAreas arm (`codeEditorWidget.ts:1806-1808`) | Fire hidden-area event | no local public event | TODO |
| CEW-129 | ViewModel ReadOnlyEdit arm (`codeEditorWidget.ts:1809-1811`) | Fire readonly-attempt interaction | no local event | TODO |
| CEW-130 | CursorState max-count branch (`codeEditorWidget.ts:1812-1833`) | Optional warning plus two command actions | N-A candidate: single cursor | TODO |
| CEW-131 | CursorState relay arm (`codeEditorWidget.ts:1835-1860`) | Build positions, fire position, then selection | local cursor events | TODO |
| CEW-132 | ModelDecorations arm (`codeEditorWidget.ts:1861-1863`) | Relay decoration event | local generation scheduling | TODO |
| CEW-133 | ModelLanguage arm (`codeEditorWidget.ts:1864-1867`) | Restamp mode id before event | no language-change event | TODO |
| CEW-134 | LanguageConfiguration arm (`codeEditorWidget.ts:1868-1870`) | Relay event | no local event | TODO |
| CEW-135 | ModelContent arm (`codeEditorWidget.ts:1871-1873`) | Relay event | local model listener | TODO |
| CEW-136 | ModelOptions arm (`codeEditorWidget.ts:1874-1876`) | Relay event | no local event | TODO |
| CEW-137 | ModelTokens arm (`codeEditorWidget.ts:1877-1879`) | Relay event | local token listener | TODO |
| CEW-138 | ModelLineHeight arm (`codeEditorWidget.ts:1880-1882`) | Relay event | no local event | TODO |
| CEW-139 | ModelFont arm (`codeEditorWidget.ts:1883-1885`) | Relay event | font singleton callback | TODO |
| CEW-140 | `_attachModel` real-view branch (`codeEditorWidget.ts:1889-1918`) | Append/re-add/render/stamp/subscribe only when real | local View Some branch | TODO |
| CEW-141 | `_createView` simple-widget branch (`codeEditorWidget.ts:1925-1945`) | Delegates editing directly to widget methods | N-A candidate | TODO |
| CEW-142 | `_createView` ordinary-widget branch (`codeEditorWidget.ts:1946-1977`) | Delegates through command service | N-A candidate | TODO |
| CEW-143 | composition new-command branch (`codeEditorWidget.ts:1957-1962`) | `replaceNextCharCnt || positionDelta` selects CompositionType | N-A candidate | TODO |
| CEW-144 | composition replace-previous branch (`codeEditorWidget.ts:1962-1965`) | Otherwise selects ReplacePreviousChar | N-A candidate | TODO |
| CEW-145 | `_detachModel` no-model early return (`codeEditorWidget.ts:2015-2017`) | Contribution handle is already disposed/reset | local returns before any handler cleanup | TODO |
| CEW-146 | root-contained branch (`codeEditorWidget.ts:2025-2027`) | Remove captured root only when still under container | local unconditional `remove_child` in Some arm | TODO |
| CEW-147 | banner-contained branch (`codeEditorWidget.ts:2028-2030`) | Remove banner only when still under container | no banner | TODO |
| CEW-148 | ModelData real-view branch (`codeEditorWidget.ts:2137-2139`) | View disposed only for real View | local option is implicit but no View dispose | TODO |
| CEW-149 | `_beginUpdate` outermost branch (`codeEditorWidget.ts:2073-2076`) | Fire begin iff incremented depth equals 1 | no local bracket | TODO |
| CEW-150 | `_endUpdate` outermost branch (`codeEditorWidget.ts:2080-2083`) | Fire end iff decremented depth equals 0 | no local bracket | TODO |
| CEC-012 | duplicate contribution-id branch (`codeEditorContributions.ts:47-51`) | Report unexpected error and continue without replacing first pending description | local registry rejects duplicates at registration seam | TODO |
| VIEW-080 | `_instantiationService` (`view.ts:143`) | Injected borrowed service used to create View-owned parts; View never disposes service itself | no DI service | TODO |
| VIEW-081 | `_userInteractionService` (`view.ts:144`) | Injected borrowed service used to create registered focus trackers; never disposed itself | no service object | TODO |
| VIEW-082 | native edit-context branch (`view.ts:307-310`) | Effective option true creates NativeEditContext | N-A candidate | TODO |
| VIEW-083 | textarea edit-context branch (`view.ts:310-312`) | Effective option false creates TextAreaEditContext | N-A candidate | TODO |
| VIEW-084 | edit-context equality early return (`view.ts:318-320`) | No disposal/replacement when both controlling values are unchanged | N-A candidate | TODO |
| VIEW-085 | edit-context focus restore branch (`view.ts:328-330`) | Newly constructed context is focused only when old one was focused | N-A candidate | TODO |
| VIEW-086 | edit-context index branch (`view.ts:331-333`) | Replace ViewPart slot only when old context was found | N-A candidate | TODO |
| VIEW-087 | constructor GPU-context branch (`view.ts:191-193`) | Create GPU context only when acceleration option is exactly `on` | N-A candidate | TODO |
| VIEW-088 | constructor GPU-lines branch (`view.ts:200-202`) | Create GPU lines only when GPU context exists | N-A candidate | TODO |
| VIEW-089 | constructor GPU-mark branch (`view.ts:230-232`) | Add GpuMarkOverlay only when GPU context exists | N-A candidate | TODO |
| VIEW-090 | constructor rulers alternative (`view.ts:255-258`) | GPU context chooses RulersGpu; absence chooses DOM Rulers | N-A candidate | TODO |
| VIEW-091 | overview-ruler insertion branch (`view.ts:268-271`) | Truthy ruler inserts at scrollbar-provided position | N-A candidate | TODO |
| VIEW-092 | rulers DOM-node branch (`view.ts:274-276`) | Append only the rulers variant exposing `domNode` | N-A candidate | TODO |
| VIEW-093 | GPU-canvas append branch (`view.ts:283-285`) | Canvas is appended only when GPU context exists | N-A candidate | TODO |
| VIEW-094 | external overflow-parent branch (`view.ts:292-295`) | Both overflowing nodes append into caller-supplied host | no external host option | TODO |
| VIEW-095 | internal overflow-parent branch (`view.ts:295-298`) | Without external host both nodes append to View root | local fixed path | TODO |
| VIEW-096 | focus-tracker overflow-host branch (`view.ts:963-973`) | Create tracker and two subscriptions only when external node exists | no external host option | TODO |
| VIEW-097 | focus aggregate changed branch (`view.ts:977-981`) | Fire `_onChange` only when OR aggregate differs from prior/undefined | local separate callbacks | TODO |
| VIEW-098 | dispose animation-frame branch (`view.ts:498-501`) | Non-null frame is disposed and field reset before any other teardown | Viewer render-pending path | TODO |
| VIEW-099 | dispose GPU-context branch (`view.ts:510`) | Optional context disposed when present | N-A candidate | TODO |
| VIEW-100 | dispose GPU-lines branch (`view.ts:513`) | Optional GPU lines disposed when present | N-A candidate | TODO |
| VIEW-101 | focused-class branch (`view.ts:459-462`) | Edit-context focus appends exact ` focused`, absence appends empty string | local focused class | TODO |
| MDS-032 | `_markerService` parameter-property (`markerDecorationsService.ts:37`) | Injected borrowed service; service subscribes/reads/removes but never disposes it | local `markers` field; may be shared | TODO |
| MDS-033 | `getMarker` present-owner branch (`markerDecorationsService.ts:53-54`) | Delegate and normalize undefined to null | local Some delegate | TODO |
| MDS-034 | `getMarker` missing-owner branch (`markerDecorationsService.ts:53-54`) | Return null | local None | TODO |
| MDS-035 | `getLiveMarkers` present-owner branch (`markerDecorationsService.ts:58-59`) | Present owner delegates to its live ranges | local Some arm | TODO |
| MDS-036 | suppression missing-set branch (`markerDecorationsService.ts:64-68`) | Allocate/store a new Set before adding range | local array creation | TODO |
| MDS-037 | suppression disposal present-set branch (`markerDecorationsService.ts:73-80`) | Delete range and refresh only while set still exists | local Some arm | TODO |
| MDS-038 | suppression empty-set branch (`markerDecorationsService.ts:76-78`) | Drop URI key when last range removed | local length zero | TODO |
| MDS-039 | marker-change registered-owner branch (`markerDecorationsService.ts:86-89`) | Update only present URI owner | local Some arm | TODO |
| MDS-040 | model-remove present-owner branch (`markerDecorationsService.ts:100-104`) | Dispose before deleting URI entry | local Some arm | TODO |
| MDS-041 | transient-scheme branch (`markerDecorationsService.ts:107-111`) | Only three schemes trigger marker-owner removal | local exact strings | TODO |
| MDS-042 | suppression-filter present-set branch (`markerDecorationsService.ts:119-124`) | Present set filters every marker whose range intersects or touches a candidate | local Some arm | TODO |
| MDS-043 | changed-decoration branch (`markerDecorationsService.ts:126-128`) | Fire model event only when update returns true | local same | TODO |
| MDS-044 | update no-change early return (`markerDecorationsService.ts:153-155`) | No delta/map mutation and false | local same | TODO |
| MDS-045 | live-range present branch (`markerDecorationsService.ts:182-185`) | Push pair when decoration id still resolves | local Some branch | TODO |
| MDS-046 | ordinary-Hint range branch (`markerDecorationsService.ts:194-198`) | Hint and neither tag forces one line/end=start+2 | local same | TODO |
| MDS-047 | empty-range branch (`markerDecorationsService.ts:202-216`) | Run empty-range max-column/word logic | local same | TODO |
| MDS-048 | empty-line/behind-EOL early return (`markerDecorationsService.ts:206-210`) | Return validated range before word lookup | local same | TODO |
| MDS-049 | word-found branch (`markerDecorationsService.ts:212-215`) | Replace columns when word exists | local Some arm | TODO |
| MDS-050 | full-line marker branch (`markerDecorationsService.ts:216-222`) | Non-empty MAX_VALUE/start-1/single-line enters whitespace snap | local same | TODO |
| MDS-051 | full-line min-column branch (`markerDecorationsService.ts:218-221`) | Rewrite range and raw marker only when min < end | local same | TODO |
| MDS-052 | Hint severity arm (`markerDecorationsService.ts:235-244`) | Runs tag submatrix and z=0 | local Hint arm | TODO |
| MDS-053 | Hint Deprecated arm (`markerDecorationsService.ts:236-238`) | Class undefined | local empty class | TODO |
| MDS-054 | Hint Unnecessary arm (`markerDecorationsService.ts:238-240`) | Unnecessary class | local same | TODO |
| MDS-055 | Info severity arm (`markerDecorationsService.ts:245-253`) | Info class/color/z=10/minimap Inline | local same | TODO |
| MDS-056 | Warning severity arm (`markerDecorationsService.ts:254-262`) | Warning class/color/z=20/minimap Inline | local same | TODO |
| MDS-057 | Error/default severity arm (`markerDecorationsService.ts:263-273`) | Error class/color/z=30/minimap Inline | local Error enum has no default catch-all | TODO |
| MDS-058 | tags-present branch (`markerDecorationsService.ts:275-282`) | Inline-class overrides run only when tags array exists | local Some arm | TODO |
| MDS-059 | Unnecessary inline-tag branch (`markerDecorationsService.ts:276-278`) | Assign unnecessary inline class | local same | TODO |
| MDS-060 | Deprecated inline-tag branch (`markerDecorationsService.ts:279-281`) | Assign deprecated after unnecessary, so it wins | local same | TODO |
| MDS-061 | `_hasMarkerTag` tags branch (`markerDecorationsService.ts:300-304`) | Present array returns index>=0; absent returns false | local `has_tag` | TODO |
| GPMM-013 | stop inactive early return (`globalPointerMoveMonitor.ts:29-32`) | Leaves hook store/callbacks untouched | local same | TODO |
| GPMM-014 | stop callback branch (`globalPointerMoveMonitor.ts:40-42`) | Invoke only when flag true and captured callback non-null | local same | TODO |
| GPMM-015 | start-already-monitoring branch (`globalPointerMoveMonitor.ts:56-58`) | Stop old monitor without stop callback before replacing callbacks | local same | TODO |
| GPMM-016 | pointer-capture success branch (`globalPointerMoveMonitor.ts:64-78`) | Capture and retain release hook; event source stays element | local always window | TODO |
| GPMM-017 | release-capture exception branch (`globalPointerMoveMonitor.ts:67-77`) | Deliberately ignore DOMException | FFI gap | TODO |
| GPMM-018 | set-capture exception branch (`globalPointerMoveMonitor.ts:79-89`) | Fallback event source to owning window | local fixed path | TODO |
| GPMM-019 | buttons-changed early return (`globalPointerMoveMonitor.ts:95-99`) | Stop(true) and return before prevent-default/callback | local same | TODO |
| SB-009 | slider pointerdown left-button branch (`abstractScrollbar.ts:115-118`) | Prevent default and start only for button 0 | local converts any MouseEvent then starts | TODO |
| SB-010 | slider click left-button branch (`abstractScrollbar.ts:122-125`) | Stop propagation only for normalized left button | local mousedown stops propagation | TODO |
| SB-011 | drag invalid-target early return (`abstractScrollbar.ts:241-243`) | No active class/monitor/host callback | local target is not validated | TODO |
| SB-012 | Windows orthogonal reset branch (`abstractScrollbar.ts:257-261`) | Strict `>140` resets initial scroll and returns | local missing | TODO |
| CFG-016 | `_targetWindowId` (`editorConfiguration.ts:57,84,146,158`) | Pins later environment/font reads to the container window id; the PixelRatio subscription itself uses `getWindow(container)` directly at line 98 | local single global window | TODO |
| CFG-017 | `_accessibilityService` (`editorConfiguration.ts:78`) | Injected borrowed service; subscription retained, service never disposed | no service | TODO |
| CFG-018 | `_recomputeOptions` unchanged early return (`editorConfiguration.ts:106-109`) | Return before assignment and both events | local option equality guard | TODO |
| CEW-151 | post-detach optional-model branch (`codeEditorWidget.ts:2008-2010`) | Owner-id sweep runs only for a non-null detached model | local explicit match | TODO |
| CEW-152 | detach optional contribution-handle branch (`codeEditorWidget.ts:2012-2014`) | Dispose when present, then clear field unconditionally before model guard | no local handle | TODO |
| CEW-153 | model-change old-URI branch (`codeEditorWidget.ts:519-522`) | Missing old ModelData produces null; present uses its model URI | local match | TODO |
| CEW-154 | model-change new-URI branch (`codeEditorWidget.ts:519-522`) | Null new model produces null; present uses URI | local match | TODO |
| CEC-013 | attach-idle editor optional branch (`codeEditorContributions.ts:114-117`) | Optional editor DOM lookup permits an uninitialized/null editor input to `getWindow` | local registry always initialized | TODO |
| VIEW-102 | focus tracker initial fallback branch (`view.ts:984-986`) | Undefined `_hadFocus` returns false; defined value returns itself | local bool starts false | TODO |
| VIEW-103 | focus tracker optional refresh branch (`view.ts:988-991`) | Always refresh root; refresh overflow tracker only when tracker/method exist | no external overflow tracker | TODO |
| MDS-062 | suppression disposal missing-set branch (`markerDecorationsService.ts:73-81`) | Missing set performs no deletion and no marker refresh | local None arm | TODO |
| MDS-063 | transient cleanup optional-service branch (`markerDecorationsService.ts:110`) | Optional-chain read skips cleanup if service were absent | local nonoptional field | TODO |
| MDS-064 | ordinary Hint option branch (`markerDecorationsService.ts:240-242`) | Neither Deprecated nor Unnecessary selects hint class | local else arm | TODO |
| MDS-065 | `_hasMarkerTag` absent-tags branch (`markerDecorationsService.ts:300-304`) | Return false when tags are absent | local None path | TODO |
| GPMM-020 | pointer-move matching-buttons branch (`globalPointerMoveMonitor.ts:100-103`) | Prevent default then invoke current move callback | local else path | TODO |
| CEW-155 | `_detachModel` real-view root selection (`codeEditorWidget.ts:2019`) | `hasRealView` captures the View root for later removal; false captures null | local `view is Some` match | TODO |
| CEW-156 | `EditorModeContext` (`codeEditorWidget.ts:328`) | Second context manager is independently registered in the widget store | no direct equivalent | TODO |
| CEW-157 | View `onWillCut` subscription (`codeEditorWidget.ts:1916`) | Independently pushed into ModelData listener array | N-A candidate: readonly cut | TODO |
| CEW-158 | View `onWillPaste` subscription (`codeEditorWidget.ts:1917`) | Independently pushed into ModelData listener array | N-A candidate: readonly paste | TODO |
| CEC-014 | BeforeFirstInteraction idle handle (`codeEditorContributions.ts:67-69`) | Independently registered in the base disposable store | no lazy handles | TODO |
| CEC-015 | Eventually idle handle (`codeEditorContributions.ts:74-76`) | Independently registered in the base disposable store; lazy-instantiation timing remains an excluded sibling | no lazy handles | TODO |
| VIEW-104 | widget-focus change subscription (`view.ts:152-154`) | Independently registered in View's base disposable store | anonymous focus callbacks | TODO |
| VIEW-105 | edit-context `onWillCopy` subscription (`view.ts:341`) | Independently owned by clipboard listener store | local root copy callback | TODO |
| VIEW-106 | edit-context `onWillCut` subscription (`view.ts:342`) | Independently owned by clipboard listener store | N-A candidate: readonly cut | TODO |
| VIEW-107 | edit-context `onWillPaste` subscription (`view.ts:343`) | Independently owned by clipboard listener store | N-A candidate: readonly paste | TODO |
| VIEW-108 | root focus subscription (`view.ts:954-957`) | Independently registered by focus tracker | local anonymous root focus listener | TODO |
| VIEW-109 | root blur subscription (`view.ts:958-961`) | Independently registered by focus tracker | local anonymous root blur listener | TODO |
| VIEW-110 | overflow-node focus subscription (`view.ts:965-968`) | Independently registered when external overflow host exists | no external overflow host | TODO |
| VIEW-111 | overflow-node blur subscription (`view.ts:969-972`) | Independently registered when external overflow host exists | no external overflow host | TODO |
| VIEW-112 | public `onWillCopy` alias (`view.ts:116`) | Public Event aliases the private owned emitter | no View event alias | TODO |
| VIEW-113 | public `onWillCut` alias (`view.ts:119`) | Public Event aliases the private owned emitter | no local alias | TODO |
| VIEW-114 | public `onWillPaste` alias (`view.ts:122`) | Public Event aliases the private owned emitter | no local alias | TODO |
| VIEW-115 | focus tracker public `onChange` alias (`view.ts:940`) | Public Event aliases `_onChange` | no local alias | TODO |
| MDS-066 | model-removed subscription (`markerDecorationsService.ts:42`) | Independently registered in the service store | no shared model registry | TODO |
| MDS-067 | marker-changed subscription (`markerDecorationsService.ts:43`) | Independently registered in the service store | local retained marker subscription | TODO |
| MDS-068 | `getLiveMarkers` missing-owner branch (`markerDecorationsService.ts:58-60`) | Missing URI owner returns an empty array | local None arm | TODO |
| MDS-069 | model-remove missing-owner branch (`markerDecorationsService.ts:100-104`) | Missing URI owner skips decoration disposal/deletion | local None arm | TODO |
| MDS-070 | word-missing branch (`markerDecorationsService.ts:212-215`) | Missing word leaves the validated empty range unchanged | local None arm | TODO |
| MDS-071 | live-range missing branch (`markerDecorationsService.ts:182-186`) | Missing decoration range skips that marker/id pair | local None arm | TODO |
| MDS-072 | last-non-whitespace outcome (`markerDecorationsService.ts:203-204`) | Nonzero last-non-whitespace column becomes `maxColumn` | local nonzero arm | TODO |
| MDS-073 | line-max fallback outcome (`markerDecorationsService.ts:203-204`) | Zero last-non-whitespace falls back to line max column | local zero arm | TODO |
| MDS-074 | unchanged service-update outcome (`markerDecorationsService.ts:126-129`) | `MarkerDecorations.update=false` fires no service event | local false arm | TODO |
| MDS-075 | marker-change missing-owner branch (`markerDecorationsService.ts:86-90`) | Missing URI owner performs no update | local None arm | TODO |
| SB-013 | slider pointerdown listener (`abstractScrollbar.ts:111-120`) | Independently registered in Widget's disposable store | anonymous local mousedown | TODO |
| SB-014 | slider click listener (`abstractScrollbar.ts:122-126`; `widget.ts:14-15`) | `onclick` independently registers a disposable listener in Widget's store | no separate local click listener | TODO |
| CFG-019 | public `onDidChange` alias (`editorConfiguration.ts:43`) | Public Event aliases `_onDidChange` | no local event alias | TODO |
| CFG-020 | public `onDidChangeFast` alias (`editorConfiguration.ts:46`) | Public Event aliases `_onDidChangeFast` | no local event alias | TODO |
| MDS-076 | suppression-filter absent-set branch (`markerDecorationsService.ts:119-124`) | Missing suppression set preserves the first-500 marker list unchanged | local None arm | TODO |

### Behavior-changing branch and early-return inventory

This prose is a second-read grouping of the first-class branch rows above.
Every item below is therefore already an independent denominator row; none
exists only in prose.

- **CEW-064 constructor:** optional `style?.setProperty`; configuration event
  always fires before the independent `layoutInfo` and `fontSize` branches;
  optional `contextKeyValues` iterates all entries; contributions come from an
  explicit array or the registry. DnD callback semantics and the action-
  duplicate branch remain excluded siblings; only observer ownership is in
  CEW-068.
- **CEW-071 dispose:** no conditional early return; ordering is externally
  meaningful: unregister editor, clear widget registries, decoration cleanup,
  detach/post-cleanup, fire dispose, then base-store disposal.
- **CEW-072 setModel:** `(null,null)` and physical same-model are distinct early
  returns inside the update bracket; `hasModel` splits focus restoration from
  clearing both focus emitters; text focus is restored only when it existed;
  contribution re-arm happens after `onDidChangeModel` and outgoing decoration
  cleanup, including after a `None` attach.
- **CEW-073 _attachModel:** null model sets `_modelData=null` and returns. The
  ViewModel event switch accounts for ContentSize, Focus, WidgetFocus, Scroll,
  ViewZones, HiddenAreas, ReadOnlyEditAttempt, CursorState, Decorations,
  Language, LanguageConfiguration, Content, Options, Tokens, LineHeight, and
  Font. CursorState separately gates the max-cursor warning/actions and always
  emits position before selection. `hasRealView` gates root append, all three
  widget re-add loops, initial render, `data-uri`, and the three clipboard
  subscriptions. No listener is installed after `ModelData` construction.
- **CEW-074 _createView:** simple-widget and ordinary-widget delegates are
  complete alternatives. Both provide paste/type/composition-start/
  composition-end/cut; ordinary `compositionType` chooses the new composition
  command when `replaceNextCharCnt || positionDelta`, otherwise the replace-
  previous-character command. All eleven key/context/mouse/wheel relay slots
  are assigned before View construction.
- **CEW-076 _detachModel:** the attach-scoped contribution handle is disposed
  and cleared before the no-model early return. A real model captures its root
  before bundle disposal; root and banner removal each require both a non-null
  node and `container.contains(node)`; return occurs after attributes/nodes are
  removed.
- **CEW-088 ModelData.dispose:** listener disposal and `onBeforeDetached` are
  unconditional; only View disposal is gated by `hasRealView`; ViewModel is
  always last.
- **CEC-007 initialize:** duplicate pending id reports and continues; each of
  the three idle callbacks is independently registered. The lazy callbacks'
  instantiation policy is excluded, but cancellation ownership is not.
- **VIEW-029 constructor:** experimental GPU acceleration gates both GPU owners
  and GPU-only parts; edit-context choice is binary; overview-ruler insertion
  retains its source truthiness guard; rulers have GPU/DOM alternatives;
  overflow widget nodes choose external host or root. DOM order is exactly the
  order recorded in VIEW-060–064.
- **VIEW-031 _updateEditContext:** equal effective-edit-context and
  accessibility values return early. Replacement records focus and array
  index, disposes old context before constructing the new one, restores focus
  conditionally, and replaces `_viewParts[index]` only when found.
- **VIEW-032 _connectEditContextClipboardEvents:** old copy/cut/paste listeners
  are cleared before the new three are added.
- **VIEW-035/036/037 event handlers:** configuration always updates class,
  edit-context ownership, and layout in that order; focus only reclasses;
  theme updates the context before reclassing.
- **VIEW-038 dispose:** nullable animation frame is disposed/reset first;
  optional GPU owners are independently gated; overflowing nodes are removed
  regardless of internal/external parent; every `_viewParts` entry is disposed
  before the base store. Root removal is intentionally a parent-widget step.
- **VIEW-073/074 focus tracker:** the overflow tracker/listeners exist only for
  an external overflow host; root and overflow focus values are ORed; `_update`
  emits only when the aggregate differs from the `undefined`/prior state;
  `hasFocus` maps the initial `undefined` to false.
- **MDS-006 constructor:** existing models are seeded before model-add,
  model-remove, and marker-change subscriptions are registered.
- **MDS-009 dispose:** base cleanup precedes per-model owner disposal; every map
  value is disposed before the map is cleared.
- **MDS-010/011 lookups:** missing URI owner yields null/empty; a present owner
  delegates. Because the map key is URI, these branches do not resolve two
  simultaneous model identities with the same URI.
- **MDS-012 suppression:** missing URI set is created; returned disposal acts
  only when the set still exists, deletes the range, drops an empty set, then
  refreshes; missing set is a no-op.
- **MDS-013:** every changed resource is visited; only a present per-model
  owner updates.
- **MDS-015:** present owner is disposed before deletion; absent owner skips
  both. Transient marker cleanup is an OR of exactly `inMemory`, `internal`,
  and `vscode`, then removes each owner returned by the marker read.
- **MDS-016:** a present suppression set filters any marker whose range
  intersects or touches any candidate; absent set preserves the first 500.
  The change emitter fires only when `MarkerDecorations.update` returns true.
- **MDS-023 update:** empty added and removed sets return false before any model
  call. Otherwise removed ids and added decorations are built, one delta call
  occurs, removed map entries are deleted, returned ids are paired by index,
  and true is returned.
- **MDS-025 getMarkers:** a missing decoration range is skipped, not emitted.
- **MDS-026 range:** ordinary Hint without Unnecessary/Deprecated is forced to
  one line and `+2`; validation always follows. Empty ranges choose
  last-non-whitespace or line max; empty-line/behind-EOL returns immediately;
  a found word expands the range and missing word leaves it unchanged. Only a
  non-empty `MAX_VALUE`, column-1, single-line marker enters the full-line
  branch; `minColumn < endColumn` gates both range rewrite and raw-marker
  mutation.
- **MDS-028 options:** Hint chooses Deprecated/Unnecessary/ordinary in that
  order and z=0; Info/Warning/Error(default) choose z=10/20/30 plus their
  overview/minimap colors. Tags are optional; Unnecessary writes the inline
  class first and Deprecated overwrites it when both are present.
- **MDS-031 hasMarkerTag:** missing tags returns false; present tags use
  non-negative index membership.
- **GPMM-007 stopMonitoring:** inactive returns without clearing or callback;
  active clears hooks and both callback fields before optional invocation;
  callback requires both `invokeStopCallback` and a captured callback.
- **GPMM-009/010 startMonitoring:** active prior monitor stops with callback
  false; pointer capture success retains a release hook whose failure is
  ignored; capture failure switches both listeners to the owning window.
- **GPMM-011:** changed buttons stops with callback true and returns before
  prevent-default/callback; matching buttons performs both.
- **SB-004:** slider pointerdown only starts for button 0; click propagation is
  stopped only for the normalized left-button event.
- **SB-006/007:** missing/non-Element target returns before active state or
  callbacks; Windows plus orthogonal distance strictly greater than 140 resets
  to the captured initial position and returns; all other moves use along-axis
  delta. Stop clears `active` before host `onDragEnd`; `onDragStart` occurs
  after monitor installation.
- **CFG-004/005:** automatic layout alone starts container observation; all
  seven subscriptions are retained regardless of that option.
- **CFG-013:** unchanged computed options return before assignment/events;
  changed options fire Fast before ordinary.

The complete contract files MDC/MDCON contain no behavior-changing branches;
the MDCON constructor and `dispose` are deliberately empty.

### Local ownership audit — 96 rows, outside the source denominator

These rows describe current ownership facts and gaps. They are evidence for
mapping the 427 source rows, not extra source-parity members.

| ID | Local owner (file:line) | Current lifetime / finding | Source rows affected |
|---|---|---|---|
| LOCAL-001 | `ViewerServices` fields (`viewer/services.mbt:8-20`) | Languages, markers, marker decorations, feedback, quick diff, and logger may be shared caller-injected objects | CEW-071, MDS-005–009 |
| LOCAL-002 | `ViewerServices::new` (`viewer/services.mbt:25-39`) | Creates fresh marker/decoration/feedback/quick-diff services but exposes the same value shape as injected services | CEW-071, MDS-006 |
| LOCAL-003 | Viewer service provenance (`viewer/viewer.mbt:14`; `viewer/services.mbt:25-39`) | Viewer stores no owns/borrows bit, so disposal cannot distinguish default-created from caller-shared services | CEW-071; proposed `owns_services` contract above |
| LOCAL-004 | Viewer emitters (`viewer/viewer.mbt:16-41`) | Thirteen Viewer-owned emitters are constructed per editor | CEW-003–048 mapping |
| LOCAL-005 | `Viewer.model_data` (`viewer/viewer.mbt:45-48`) | Nullable per-attachment bundle | CEW-054, CEW-081–088 |
| LOCAL-006 | `Viewer.container` (`viewer/viewer.mbt:75-76`) | Host-owned element retained after attach | CEW-049 |
| LOCAL-007 | placeholder fields (`viewer/viewer.mbt:77-83`) | Viewer owns placeholder section and text node outside per-model View | CEW-078, VIEW-079 |
| LOCAL-008 | `document_input_hooked` (`viewer/viewer.mbt:87-90`) | Boolean records one-time installation but stores no removal handles | GPMM/SB ownership |
| LOCAL-009 | `mouse_handler` (`viewer/viewer.mbt:107`) | Per-View handler is held by Viewer, not by local View | VIEW-019, VIEW-066, SB-008 |
| LOCAL-010 | `contributions` (`viewer/viewer.mbt:121-124`) | Per-editor contribution instances are Viewer-owned | CEW-002, CEC-003 |
| LOCAL-011 | local `ModelData` fields (`viewer/viewer.mbt:138-143`) | Holds model, ViewModel, optional View, and listener array; no `attached_view` token or explicit real-view flag | CEW-081–087 |
| LOCAL-012 | `ModelData::dispose` listeners (`viewer/viewer.mbt:150-153`) | Iterates/disposes swap listeners first | CEW-085, CEW-088 |
| LOCAL-013 | `ModelData::dispose` owners (`viewer/viewer.mbt:154-156`) | Disposes ViewModel but never calls a View disposal method; local View has none | CEW-082–084, VIEW-038 |
| LOCAL-014 | Viewer marker-decoration callback (`viewer/viewer.mbt:318-328`) | `on_did_change_marker_decorations` disposable is piped to `ignore`; callback can schedule after Viewer disposal | MDS-003, CEW-071 |
| LOCAL-015 | contribution construction (`viewer/viewer.mbt:329-332`) | `instantiate_all` creates all modes eagerly once | CEC-003–010 |
| LOCAL-016 | `Viewer::attach` guard (`viewer/viewer.mbt:492-495`) | Repeated attach returns, but disposed state is not checked | CEW-064; partial-attach audit |
| LOCAL-017 | placeholder DOM (`viewer/viewer.mbt:497-508`) | Owns section class/data-theme, message div, text node, and both append edges | VIEW DOM rows; local-only placeholder |
| LOCAL-018 | font-change callback (`viewer/viewer.mbt:509-517`) | Returned disposable is ignored; callback can schedule after Viewer disposal | CFG-009, CFG-015 |
| LOCAL-019 | document-input installation (`viewer/viewer.mbt:518`) | Once-per-Viewer callback installation is invoked at attach | SB-003–008 |
| LOCAL-020 | marker clearing on attach (`viewer/attach_model.mbt:13-18`) | `clear_resource(model.uri)` deletes host-owned preloaded diagnostics before seeding | MDS-007, MDS-014, MDS-016 |
| LOCAL-021 | model decoration subscription (`viewer/attach_model.mbt:19-45`) | Disposable retained in ModelData; installed before marker seeding | CEW-085, CEW-088 |
| LOCAL-022 | model content subscription (`viewer/attach_model.mbt:46-67`) | Current per-Viewer disposable re-adds the marker owner on every flush; replace this refresh responsibility with one content watch per active service identity, while retaining Viewer content-event delivery after acquisition | CEW-004, CEW-085, MDS-014; proposed ordered acquisition |
| LOCAL-023 | model will-dispose subscription (`viewer/attach_model.mbt:68-70`) | Disposable retained; calls this Viewer `set_model(None)` | CEW-073, CEW-085 |
| LOCAL-024 | token subscription (`viewer/attach_model.mbt:71-77`) | Disposable retained | CEW-011, CEW-085 |
| LOCAL-025 | marker model add (`viewer/attach_model.mbt:78`) | Registration currently occurs after Viewer content/will/token subscriptions and once per Viewer; the proposal moves identity acquisition immediately after the decoration listener, so the service ModelDisposed watcher is installed before the Viewer will-dispose callback can ordinary-release it | MDS-005–008, MDS-014; proposed attach order |
| LOCAL-026 | view-layout scroll subscription (`viewer/attach_model.mbt:86-93`) | Disposable retained in ModelData | CEW-042, CEW-085 |
| LOCAL-027 | local ModelData construction (`viewer/attach_model.mbt:94-95`) | Bundle is assigned only after View construction and all listener installation | CEW-073, CEW-087 |
| LOCAL-028 | `create_view` container guard (`viewer/attach_model.mbt:121-123`) | Headless attach returns `None` before any View DOM | CEW-073, CEW-084 |
| LOCAL-029 | per-model root mount (`viewer/attach_model.mbt:123-129`) | Create View, theme it, append root, apply squiggle/font state | CEW-078, VIEW-029 |
| LOCAL-030 | per-view input owner (`viewer/attach_model.mbt:130-132`) | Fresh MouseHandler is stored on Viewer for each View | VIEW-019, VIEW-066 |
| LOCAL-031 | widget re-add (`viewer/attach_model.mbt:133-140`) | Content hover optional; every overlay registration re-added | CEW-058–060, CEW-073 |
| LOCAL-032 | URI/placeholder transition (`viewer/attach_model.mbt:141-148`) | Stamp `data-uri`; remove placeholder if present; no contains guard | CEW-079, VIEW-079 |
| LOCAL-033 | `set_model` no-op guards (`viewer/viewer.mbt:542-554`) | Both-null and physical same-model return before lifecycle work | CEW-072 |
| LOCAL-034 | pre-detach marker removal (`viewer/viewer.mbt:563-573`) | Calls `on_model_removed` only when both models exist and URI strings differ; `Some→None`, same-URI replacement, and disposal do not unregister here | MDS-015; proposed identity-release contract |
| LOCAL-035 | swap/event order (`viewer/viewer.mbt:574-603`) | Capture focus → detach → attach/None → restore/clear focus → fire did-change → owner-id sweep; no will-change event or contribution handle | CEW-013–014, CEW-053, CEW-072, CEW-075 |
| LOCAL-036 | None attach (`viewer/viewer.mbt:576-585`) | Clears zones and schedules; no marker-registration release is defined | MDS-015; proposed identity-release contract |
| LOCAL-037 | `detach_model` no-model guard (`viewer/viewer.mbt:611-613`) | Returns before any cleanup | CEW-076 |
| LOCAL-038 | mouse teardown start (`viewer/viewer.mbt:614-616`) | Calls `cancel_mouse_selection`, which stops only the selection monitor | VIEW-019, SB-008 |
| LOCAL-039 | contribution feature resets (`viewer/viewer.mbt:617-640`) | Per-model feature state reset precedes ModelData disposal; request freshness is out of this plan | CEW-076 ordering |
| LOCAL-040 | bundle drop (`viewer/viewer.mbt:641-642`) | Dispose listeners/ViewModel then clear `model_data`; View internals remain undisposed | CEW-088, VIEW-038 |
| LOCAL-041 | detach DOM (`viewer/viewer.mbt:643-659`) | Remove host `data-mode-id`; remove View root; reappend placeholder; no banner or external-overflow branch | CEW-077–078, VIEW-064, VIEW-079 |
| LOCAL-042 | handler drop (`viewer/viewer.mbt:660`) | Sets `mouse_handler=None` without calling its public `dispose` | VIEW-019, VIEW-038, SB-008 |
| LOCAL-043 | `Viewer::dispose` reentry (`viewer/viewer.mbt:799-830`) | No disposed flag/early return; repeated disposal reaches contributions, emitters, and services again | CEW-071; required idempotency test |
| LOCAL-044 | dispose detach/sweep (`viewer/viewer.mbt:800-805`) | Silent detach then outgoing owner-id decoration sweep | CEW-071, CEW-075 |
| LOCAL-045 | contribution disposal (`viewer/viewer.mbt:807-812`) | Calls every contribution closure then clears map | CEC-003, CEC-011 |
| LOCAL-046 | emitter disposal (`viewer/viewer.mbt:813-826`) | Fires `did_dispose`, then disposes all thirteen emitters | CEW-003–048 |
| LOCAL-047 | injected-service disposal (`viewer/viewer.mbt:827-829`) | Disposes marker decorations, markers, and feedback even when caller shares ViewerServices; quick diff/log/languages are not disposed | CEW-071, MDS-009; REQUIRED correction |
| LOCAL-048 | per-view root listeners (`viewer/input.mbt:10-68`) | Focus, blur, copy, keydown, and wheel are anonymous and not represented by disposables; DOM removal is the only release mechanism | VIEW-001, VIEW-018–022, VIEW-038 |
| LOCAL-049 | document scrollbar listeners (`viewer/input.mbt:71-96`) | Anonymous document `mousemove` and `mouseup` are installed once and can never be removed | GPMM-003–012, SB-002–008 |
| LOCAL-050 | scrollbar interaction listeners (`viewer/browser/controller/scrollbar_input.mbt:12-74`) | Three hover listeners plus vertical/horizontal thumb and track mousedown listeners are anonymous | SB-003–006 |
| LOCAL-051 | desperate-reveal listeners (`viewer/browser/controller/scrollbar_input.mbt:260-294`) | Four anonymous scroll listeners on root, overflow, content, and wrapper | VIEW-038, SB-008 |
| LOCAL-052 | scrollbar drag slot (`viewer/browser/controller/scrollbar_input.mbt:147-204`; `mouse_handler.mbt:135-136`) | Stores arithmetic state only; global move/up ownership lives in permanent document callbacks | SB-002, SB-006–008 |
| LOCAL-053 | `MouseHandler` owner fields (`viewer/browser/controller/mouse_handler.mbt:128-137`) | Owns listener array, optional document recovery monitor, MouseDownOperation, and scrollbar drag | VIEW-019, SB-008 |
| LOCAL-054 | tracked root mouse listeners (`viewer/browser/controller/mouse_handler.mbt:153-223`) | Move/up/leave/down disposables plus pointerup removal disposable are retained | VIEW-019, VIEW-038 |
| LOCAL-055 | recovery document monitor (`viewer/browser/controller/mouse_handler.mbt:160-192,326-335`) | Lazily installs a named document mousemove and retains a removal disposable; leave disposes it | GPMM ownership pattern |
| LOCAL-056 | pointerup compensation (`viewer/browser/controller/mouse_handler.mbt:205-216`) | Named root listener plus retained removal disposable | VIEW-019, VIEW-038 |
| LOCAL-057 | `MouseHandler::dispose` (`viewer/browser/controller/mouse_handler.mbt:226-237`) | Correctly disposes all tracked listeners/recovery monitor and MouseDownOperation, but no Viewer path invokes it | VIEW-038, SB-008 |
| LOCAL-058 | `cancel_selection` (`viewer/browser/controller/mouse_handler.mbt:240-244`) | Stops only MouseDownOperation monitoring; not a handler disposal | VIEW-038, SB-008 |
| LOCAL-059 | base global monitor (`base/browser/global_pointer_move_monitor.mbt:15-106`) | Retains named window pointermove/up removals; stop clears callbacks before optional stop callback | GPMM-001–012 |
| LOCAL-060 | editor global monitor (`viewer/browser/editor_dom.mbt:300-365`) | Retains capture-keydown removal and releases it from the base monitor's stop callback; repeated `start_monitoring` overwrites `keydown_listener` before the base monitor stops without callback, leaking the prior capture listener | GPMM stop/restart ownership gap |
| LOCAL-061 | local View fields (`viewer/browser/view/view.mbt:13-28`) | Owns root, overflow, rail, squiggle style, eight handles, and snapshot, but exposes no dispose state | VIEW-002–028 |
| LOCAL-062 | local View DOM (`viewer/browser/view/view.mbt:31-124`) | Owns section/attributes, style, overflow, 2^24 rail, part tree, fingerprints, and overflow nodes | VIEW-057–065 |
| LOCAL-063 | missing View disposal (`viewer/browser/view/view.mbt:31-230`) | No `View::dispose`, no ViewPart disposal loop, no external-overflow removal seam | VIEW-038, VIEW-077–079 |
| LOCAL-064 | FontMeasurements singleton (`viewer/browser/config/font_measurements.mbt:7-25`) | Process-wide cache and emitter, intentionally not per Viewer | CFG-009, CFG-014 |
| LOCAL-065 | font event API (`viewer/browser/config/font_measurements.mbt:29-37`) | Returns a real disposable; Viewer drops it | CFG-009, CFG-015 |
| LOCAL-066 | font retry timer (`viewer/browser/config/font_measurements.mbt:50-96,262-263`) | One untrusted-reading 5-second timeout handle is ignored; singleton lifetime makes it process-owned, not Viewer-owned | CFG ownership distinction |
| LOCAL-067 | MarkerStats subscription (`viewer/common/markers/marker_service.mbt:154-175`) | Self-subscription disposable is ignored, but the owning MicrotaskEmitter disposal clears listeners | service-internal lifetime |
| LOCAL-068 | `MarkerService::dispose` (`viewer/common/markers/marker_service.mbt:296-300`) | Disposes only the emitter; marker data remains in the service value | shared-service ownership |
| LOCAL-069 | local MDS fields (`viewer/common/markers/marker_decorations_service.mbt:9-15`) | URI-string owner map, suppression map, emitter, optional marker subscription | MDS-002–005 |
| LOCAL-070 | local MDS constructor (`viewer/common/markers/marker_decorations_service.mbt:20-36`) | Retains marker-change subscription but has no shared model-add/remove source | MDS-006–008 |
| LOCAL-071 | local MDS dispose (`viewer/common/markers/marker_decorations_service.mbt:48-60`) | Disposes marker subscription/emitter then clears owner map without calling each `MarkerDecorations::dispose` | MDS-009, MDS-022 |
| LOCAL-072 | local `on_model_added` (`viewer/common/markers/marker_decorations_service.mbt:62-73`) | URI-keyed `set` can overwrite a prior owner without disposing its model decorations | MDS-005, MDS-014 |
| LOCAL-073 | local `on_model_removed` (`viewer/common/markers/marker_decorations_service.mbt:75-97`) | Looks up by URI, disposes found owner, removes key, then transient cleanup | MDS-015 |
| LOCAL-074 | local marker lookups (`viewer/common/markers/marker_decorations_service.mbt:144-170`) | `get_marker`/`get_live_markers` resolve by URI only, so concurrent same-URI model identity is unknowable | MDC-004–005, MDS-010–011 |
| LOCAL-075 | local suppression disposable (`viewer/common/markers/marker_decorations_service.mbt:172-206`) | Retained only by caller; faithfully removes range/empty map and refreshes | MDC-006, MDS-012 |
| LOCAL-076 | local update path (`viewer/common/markers/marker_decorations_service.mbt:99-142`) | Present URI owner only; take 500; suppression filter; changed-only fire | MDS-013, MDS-016, MDS-018 |
| LOCAL-077 | per-model decoration dispose (`viewer/common/markers/marker_decorations.mbt:14-31`) | Exact model + ids; delta to empty and clear entries | MDS-019–022 |
| LOCAL-078 | shared same-model registration (`viewer/attach_model.mbt:78`; `viewer/services.mbt:8-12`) | Two Viewers sharing services and the same TextModel both call add; there is no identity refcount, so either detach can invalidate the other's registration if remove is added naively | proposed same-identity refcount contract; MDS-005–015 |
| LOCAL-079 | distinct same-URI models (`marker_decorations_service.mbt:11,66-86,147-169`) | Two live model objects with one URI overwrite/share one map slot; decorations and lookup answers can target the wrong model | proposed identity-owner/URI-index contract; MDC-004–005, MDS-005, MDS-010–015 |
| LOCAL-080 | model-lifetime authority (`viewer/attach_model.mbt:68-78`; upstream `markerDecorationsService.ts:35-43`) | Local registration is editor-attach-driven; upstream is global ModelService add/remove-driven. The proposal therefore makes each editor attachment acquire an identity owner and store its release in ModelData | proposed acquisition contract; MDS-006–009, MDS-014–015 |
| LOCAL-081 | `TextModel.instance_id` (`viewer/common/model/text_model.mbt:31,94`; `text_model_decorations.mbt:62-67`) | Every model object already has a stable identity independent of URI; this is the available acquire/release key | MDS-005, MDS-014–015 |
| LOCAL-082 | missing acquire seam (`viewer/attach_model.mbt:78`) | Attach calls URI-keyed `on_model_added` directly; no `acquire_model(instance_id, model)` owner exists | proposed ModelData-stored acquisition |
| LOCAL-083 | missing release/refcount seam (`viewer/viewer.mbt:563-573,611-663`) | Detach has no identity-keyed release count, so it cannot know whether another Viewer still uses the same model | proposed idempotent refcount release |
| LOCAL-084 | same-model multi-Viewer fanout (`viewer/services.mbt:8-12`; `viewer/attach_model.mbt:78`) | Required registry shape is `instance_id -> {model, refcount}`; count reaches zero before the identity owner is disposed once | proposed same-identity refcount contract |
| LOCAL-085 | distinct same-URI fanout (`marker_decorations_service.mbt:11,66-86`) | Identity-keyed owners coexist even when URI matches; an acquisition-ordered `URI -> Array[instance_id]` index fans marker changes and preserves deterministic union order | proposed ordered URI-index contract |
| LOCAL-086 | marker-change URI fanout (`marker_decorations_service.mbt:102-111`) | One URI event must update every live distinct model identity for that URI, not whichever owner last overwrote the map | MDS-013, MDS-016 |
| LOCAL-087 | lookup identity ambiguity (`marker_decorations_service.mbt:147-169`) | Preserve URI APIs: scan instance-prefixed ids for `get_marker`, return acquisition-order union for `get_live_markers`; hover needs a new `get_live_markers_for_model(model)` helper to prevent range cross-talk | MDC-004–005; proposed compatible lookup contract |
| LOCAL-088 | model-dispose authority (`viewer/attach_model.mbt:68-70`) | N successful acquisitions yield N independently idempotent releases; one active identity watch handles real `ModelDisposed`, the owner is disposed exactly once, later lease releases are harmless, and final ordinary release disposes the watch so no historical model remains retained | MDS-015, CEW-092 |
| LOCAL-089 | root render rAF (`viewer/view_host.mbt:182-190`; `viewer/viewer.mbt:91`) | `render_pending` is a Bool; window rAF handle is ignored, so Viewer disposal cannot cancel the pending callback | VIEW-027, VIEW-098 |
| LOCAL-090 | callback after disposal (`viewer/view_host.mbt:66-73,182-190`) | Pending rAF clears the Bool then can render placeholder or touch model/View after `Viewer::dispose`; no disposed guard exists | CEW-071, VIEW-038 |
| LOCAL-091 | drag-scrolling rAF (`viewer/browser/controller/drag_scrolling.mbt:114-169`) | Operation retains frame id and disposed flag; `dispose` cancels and clears it, but this depends on `MouseHandler::dispose` reaching MouseDownOperation | VIEW-038, SB-008 |
| LOCAL-092 | cancellable ViewModel scheduler (`viewer/browser_host.mbt:13-26`; `viewer/attach_model.mbt:163-169`) | The ViewModel scheduler returns a cancellation disposable; ModelData ViewModel disposal is its release path, unlike the root render rAF | CEW-082, CEW-088 |
| LOCAL-093 | Viewer-owned attach DOM after dispose (`viewer/viewer.mbt:643-659,799-830`) | Dispose detaches the View and re-appends the placeholder, but never removes the placeholder subtree or clears `container`/placeholder fields; Viewer-owned DOM therefore remains mounted in the host after disposal | CEW-071, CEW-078, VIEW-079 |
| LOCAL-094 | proposed active-registration content subscription (`viewer/attach_model.mbt:46-67`; `marker_decorations_service.mbt`) | Each identity registration must own exactly one retained `model.on_did_change_content` subscription; flush refreshes/reseeds that identity's existing decoration owner without acquiring or changing refcount, and final identity/service disposal releases it exactly once | CEW-004, MDS-014, MDS-016; proposed acquisition contract |
| LOCAL-095 | proposed active-registration model-dispose subscription (`viewer/attach_model.mbt:68-70`; `marker_decorations_service.mbt`) | Each active identity registration must own exactly one retained `model.on_will_dispose` subscription; it supplies `ModelDisposed`, and final ordinary release or service disposal removes the watch so no historical model remains retained | CEW-092, MDS-015, MDS-017; proposed reasoned-removal contract |
| LOCAL-096 | scrollbar hide timeout (`viewer/ui/scrollbar/scrollable_element.mbt:367-383`) | The 500-ms timeout handle is ignored; generation suppresses older schedules but View detach/disposal neither cancels the latest callback nor marks the DOM owner disposed, so it can mutate a detached scrollbar subtree | VIEW-038; future cancellable timeout or disposed-generation guard |

### Inventory audit evidence

- Pinned oracle verification:
  `git -C vscode rev-parse HEAD` returned
  `b18492a288de038fbc7643aae6de8247029d11bd`, exactly the plan pin.
- The nine pinned files were read in full or across the closed line ranges above.
  Their complete files total 4,848 lines:
  `2559 + 165 + 992 + 305 + 26 + 23 + 112 + 308 + 358`.
  Line-numbered reads, not symbol search alone, were used to close the source
  units; `rg` was used only to find method boundaries and `_register` sites.
- The fourteen required local files plus the two reached pointer/listener
  owners were read completely (5,089 lines). The three reached rAF owners were
  then read completely as well (610 more lines), followed by the reached
  626-line scrollable-element timeout owner, for 6,325 local audit lines.
  `TextModel.instance_id` and its generator were read at their cited ownership
  lines. `moon ide outline` was also run for the MoonBit ownership files to
  reconcile declarations with the line-by-line listener/disposal trace.
- Mechanical row reconciliation:

  ```sh
  rg -c '^\| (CEW|CEC|VIEW|MDC|MDCON|MDS|GPMM|SB|CFG)-[0-9]{3} \|' \
    docs/exec-plans/viewer-model-lifecycle-ownership-parity.md
  # 427

  rg -c '^\| LOCAL-[0-9]{3} \|' \
    docs/exec-plans/viewer-model-lifecycle-ownership-parity.md
  # 96
  ```

- Every source-ledger line ends in `TODO`; no source-ledger status cell makes a
  pre-review `PORTED`/`TESTED`/`PASS`/`DEFERRED`/`N-A` transition. The proposed
  post-review seam dispositions remain review inputs only. Local rows are a
  separate audit and cannot satisfy a source row by their presence alone.
- The repository was clean before this edit. Only this plan is an authorized
  output; no product source or test was changed and no commit was created.

### Inventory review checklist — stop gate

- [x] Reviewer confirms all 427 source IDs are within the closed Phase 0 scope.
- [x] Reviewer confirms the denominator formula and mechanical 427-row count.
- [x] Reviewer confirms every named source member/constant/owned disposable has
  one row and every behavior-changing branch/early return has its own stable
  source-ledger row.
- [x] Reviewer confirms all ViewParts, external overflow nodes, root/placeholder
  nodes, DOM attributes/classes/custom properties, and 2^24 rail constants are
  accounted for.
- [x] Reviewer confirms ModelData disposal order and setModel event/focus/
  post-cleanup order against `codeEditorWidget.ts` side by side.
- [x] Reviewer approves or amends the shared marker registration proposal:
  identity-keyed acquisitions stored in ModelData, same-identity refcounts,
  acquisition-ordered `URI -> Array[instance_id]` fanout, no `set_value`
  acquisition, reasoned removal,
  ordinary-release diagnostic preservation, active-`ModelDisposed`-only
  transient cleanup, zero-refcount watch removal, and model-specific lookup.
- [x] Reviewer confirms the proposed distinct-live-model same-URI behavior for
  owner storage, instance-prefixed decoration ids, acquisition-order
  `get_live_markers(uri)` union, and model-specific hover helper.
- [x] Reviewer confirms caller-injected/shared ViewerServices remain borrowed
  and approves the omitted-services `owns_services=true` contract above.
- [x] Reviewer confirms every Viewer/attach/model/View/font/marker/document/
  window subscription has a retained exactly-once release path in the future
  implementation design.
- [x] Reviewer confirms repeated dispose, partial attach, headless View=None,
  and callback-after-dispose cases are represented in the later test matrix.
- [x] Inventory approved and committed separately; only then may Milestone 2
  product/test work begin.

**Review gate passed:** independent review approved the fixed inventory hash
recorded below. Product/test implementation may now begin from this denominator.

## Test-Authority Corrections

- viewer/set_value_api_wbtest.mbt currently explains that attach clears marker
  data. That comment and any expectation derived from it are not authoritative.
- Existing tests that inject markers only after set_model do not cover preload.
- Existing dispose tests do not establish shared-service ownership or global
  listener cleanup.

Do not rewrite these expectations until the inventory review approves the
source contract.

## Required Test Matrix (Phase 4)

Run every applicable layer across these behavior-switching dimensions; a
single green default configuration does not close a source branch:

- lifecycle state: unattached, fully attached, partial attach, headless
  `View=None`, model `None`/`Some`, first/repeated disposal, and callback before
  versus after disposal;
- marker identity: same Viewer reacquiring the same model, two Viewers sharing
  one identity, distinct identities sharing one URI, and each possible release
  order;
- scheduled work: no pending frame versus pending root/drag frame or 500-ms
  scrollbar-hide timeout when detach or disposal begins;
- pointer monitor: pointer capture succeeds versus throws into the window
  fallback, inactive versus active restart, matching versus changed `buttons`,
  pointer move versus pointer up, and `stopMonitoring(false)` versus
  `stopMonitoring(true)` (neither stop path forwards the triggering pointer
  event to the stop callback);
- scrollbar drag: Windows versus non-Windows, invalid versus Element target,
  normal along-axis movement, and Windows orthogonal distances 139, 140, and
  141 pixels so the strict `> 140` boundary is measured;
- View construction: internal versus external overflow-widget parent,
  TextArea versus native edit context, unchanged versus replaced effective edit
  context, GPU acceleration off/on, and aggregate root/overflow focus states
  `00`, `10`, `01`, and `11`;
- configuration: automatic layout off/on, recompute with no effective option
  change versus a change, and each independent environment/font/container/
  accessibility subscription firing before and after disposal;
- service provenance: omitted/default-owned aggregate versus any explicitly
  supplied borrowed aggregate, including one the caller created with
  `ViewerServices::new()`;
- disposal reentrancy: marker/model callbacks attempt to fire while service
  teardown is in progress and must observe ingress already blocked.

Package/white-box tests:

- MarkerService preload/change/remove behavior;
- MarkerDecorationsService acquire/release/dispose ownership, including same-
  identity refcounts and distinct same-URI identity fanout;
- model.on_will_dispose and per-model decoration-owner disposal;
- same-Viewer same-URI order: set A, repeat physical A as a no-op, switch to a
  distinct B with A's URI, then release B/A in both possible orders;
- `set_value` refcount: refresh destroys/reseeds decorations without calling
  `acquire_model`, incrementing the identity refcount, or requiring an extra
  release;
- one versus two Viewers sharing an identity still install exactly one service
  content watch and one service model-dispose watch; one content flush performs
  exactly one decoration refresh/reseed and no acquisition;
- suppression missing/present/last-range release outcomes, marker-update
  changed/unchanged outcomes, missing/present live decoration ranges, and every
  empty-range word/column fallback outcome;
- final ordinary lease release never deletes MarkerService diagnostics:
  `A -> None -> reattach A` preserves and re-seeds the same diagnostics, for
  transient and non-transient schemes;
- active `ModelDisposed` transient cleanup covers each
  `inMemory`/`internal`/`vscode` scheme and a non-transient control; it runs only
  when deletion leaves the URI identity bucket empty, and does not run while a
  distinct same-URI identity remains active;
- after final lease release, the model-dispose watch is gone; a later host-side
  model disposal neither calls this service nor retains the historical model;
- `ServiceDisposed` disposes decoration owners/watches but preserves all
  host-owned MarkerService diagnostics; marker-service and outward-emitter
  ingress is blocked before any per-identity watch/owner teardown, including a
  reentrant callback attempt during disposal;
- exact upstream tests use reference naming; source-derived cases use ordinary
  local test filenames.

Headless Viewer integration:

- markers preloaded before set_model survive attach and seed decorations;
- instrumented attach order is Viewer decoration listener, service acquisition
  (content watch, model-dispose watch, seed), then Viewer content,
  model-will-dispose, and token listeners; seed/flush decoration events are
  observed, and service `ModelDisposed` handling precedes Viewer detach;
- set_value destroys model decorations and correctly re-seeds them from the
  unchanged MarkerService store;
- Some(A) to None releases A and disposes its decoration owner only when the
  approved model-lifetime authority says A has no remaining owners;
- Some(A) to Some(B) releases A and acquires/seeds B in the approved identity
  registry;
- two Viewers sharing the same model identity keep decorations live until the
  last release; disposing the model wakes both Viewers, consumes exactly their
  two idempotent releases in either callback order, and disposes the identity
  owner once;
- distinct same-URI model instances coexist and marker-change fanout plus
  lookup obeys the compatibility contract: instance-prefixed ids make
  `get_marker(uri,id)` unambiguous, `get_live_markers(uri)` concatenates in
  acquisition order, and `get_live_markers_for_model(model)` isolates hover
  ranges to the requested model;
- partial attach and headless `View=None` still release every owner already
  acquired before the missing/failing View seam;
- callbacks retained by marker, model, and font subscriptions become inert
  after Viewer disposal even if their source emits afterward;
- an omitted services argument creates a default-owned aggregate that is
  released in marker-decorations/markers/agent-feedback order, while any
  explicitly supplied aggregate remains usable after Viewer disposal;
- Viewer.dispose is idempotent and each of N acquisition disposables is
  independently idempotent.

Browser/component tests:

- model View DOM and placeholder/container nodes have the expected lifetime;
- document-level drag listeners and font/marker callbacks cannot schedule work
  after Viewer disposal;
- a pending root render frame is cancelled and cannot touch placeholder,
  model, or View state after disposal; drag-scrolling frames have the same
  callback-after-dispose assertion;
- the 500-ms scrollbar-hide callback cannot mutate a detached View subtree;
  cover cancellation when the timeout API exposes a handle and a disposed-
  generation guard as the fallback seam;
- global pointer monitoring covers capture and exception fallback, active
  restart, matching/changed buttons, pointerup, and both stop-callback flags;
- scrollbar drag covers invalid targets and the Windows 139/140/141 orthogonal
  boundary in addition to ordinary along-axis movement;
- View teardown covers internal/external overflow parents, TextArea/native edit
  context replacement, GPU owners off/on, and all four root/overflow aggregate
  focus states;
- EditorConfiguration covers automatic layout off/on, effective no-change/
  change recomputation, Fast-before-ordinary event order, and independent
  subscription disposal;
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

No deviation is approved yet. The stop-gate recommendation is:

| Source rows | Proposed post-review status | Concrete seam and bounded substitute |
|---|---|---|
| MDS-006–008, MDS-066 | `DEFERRED (needs global ModelService)` | ViewerServices has no authoritative process-wide model inventory/add/remove stream. ModelData acquisitions cover only identities actively leased by Viewers; they do not pretend to seed or observe unleased host models. |
| MDS-017, MDS-041 | `DEFERRED (needs global ModelService)` | Exact global transient-cleanup triggering cannot follow upstream model lifetime. The bounded substitute handles only a real `ModelDisposed` event from an active identity watch, cleans transient diagnostics only after that identity leaves its URI bucket empty, and never treats `LeaseReleased` or `ServiceDisposed` as model destruction. |
| MDS-015, MDS-040, MDS-069 | `PORTED` / `TESTED` after implementation | Identity-keyed reasoned removal ports the present/absent owner disposal branches and exact-once finalization. Record the local identity/refcount seam under Deviations; these rows are not blocked by the absent global ModelService. |
| MDS-063 (planned) | `N-A (local MarkerService is non-optional)` | The source optional-chain branch has no local state: every MarkerDecorationsService is constructed with a concrete MarkerService. |

Review approved these seam-based planned dispositions. Source-ledger statuses
remain `TODO` until implementation and the required tests supply row evidence.

## Execution Record

2026-07-10 inventory milestone committed as `3dbc1e7` and independently
approved at SHA-256
`4d1e57457a08528d88e2e3e86fa5dde14b6d0caf617f0170635a2d3173ccc52e`:

- oracle verified at `b18492a288de038fbc7643aae6de8247029d11bd`;
- Phase 0 closed with every excluded sibling cluster named;
- Phase 1 source inventory = 427 first-class rows, including independent rows
  for every behavior-changing branch and early return;
- Phase 2 ledger = the same 427 rows, all `TODO`;
- separate local ownership audit = 96 rows, including five ModelData
  subscriptions, Viewer/font callbacks, DOM/document/window listeners, View and
  rAF/timeout teardown, borrowed ViewerServices, `TextModel.instance_id`,
  same-model refcount, distinct same-URI fanout, registration watches, and
  lookup ambiguity;
- no product code/test change or implementation status transition occurred in
  the inventory commit;
- independent review approved the denominator, shared-marker lifecycle,
  compatible lookup surface, reasoned removal, service disposal ordering,
  ViewerServices provenance, and the required test matrices.

Append implementation commits, validation results, and final ledger totals
below. Freeze after implementation.
