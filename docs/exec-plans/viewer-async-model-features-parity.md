# Viewer Async Model Features Parity

Status: inventory ready — STOP FOR REVIEW

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
- viewer/contrib/hover/hover_registry.mbt
- viewer/browser_host.mbt
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

### Closed source boundaries and seams

The source denominator is closed at the pinned commit. Line ranges below are
inclusive. A sibling cluster outside these boundaries is not silently omitted:
it is named here with its seam reason.

- `inlayHintsController.ts`: include `InlayHintsCache` (43–66), decoration
  apply metadata (87–91), `CancellationStore` (103–123), and the controller
  request-lifetime members in 129–312 except the exact sibling declarations
  below. The gesture-install calls at 309–311 are already inside that range;
  include the complete double-click method (380–396) because its successful
  edit branch invokes the update schedule. Also include cache/anchor-range
  helpers (434–474), the complete decoration construction/replacement/scroll
  member (476–728), and cleanup (764–770). Exclude rendered
  label/active-label/render-mode and render-only dependency declarations
  (70–85, 93–96, 133–134, 144, 147–148, 155–157, 159),
  link/context-menu/command members (314–379, 399–432),
  color/layout styling (730–762),
  accessibility lookup (775–789), `fixSpace` (793–797), and the standalone
  execute-provider command (799–815). Visual mode arithmetic at 193–207 remains
  inventoried sibling behavior; the modifier session listener at 209–221 is
  scoped because it owns an update schedule.
- `inlayHints.ts`: include `InlayHintAnchor`, the `InlayHintItem` construction
  and `with` copy support, and the complete `InlayHintsFragments` request,
  result, anchor, and disposal cluster. Exclude `InlayHintItem.resolve` and
  `_doResolve` (34–65) and `asCommandLink` (169–171): those are resolve/command
  API siblings, not controller request ownership.
- `contentHoverController.ts`: include settings, owned state/subscriptions,
  construction, `get`, hook/unhook, cancel/hide/react, mouse/keyboard/scroll,
  widget creation/show, resize observation, and `dispose` (28–336, 410–415).
  Exclude action/focus/scroll/content/accessibility/visibility forwarding
  methods (338–408); they neither create nor retire model-scoped work.
- `contentHoverWidgetWrapper.ts`: include owned state/resources and construction
  (27–51), participant/listener setup (53–94), operation start/cancel/result
  reconciliation/loading (99–217), anchor selection and pointer exit
  (249–319), and `hide` (398–401). Exclude DOM rendering/context construction
  (219–246), content/verbosity/focus/scroll forwarding (321–397), and DOM/state
  query getters (403–429). Calls into those clusters remain explicit boundary
  rows; their rendering and widget-state implementation is owned by the hover
  layout/render plans.
- `hoverOperation.ts`, `contentHoverComputer.ts`, and `getHover.ts`: include the
  complete files. `getHover.ts` scoring/order/aggregation facts remain rows in
  this denominator even though their eventual disposition belongs to the P2
  provider-surface plan.
- `hoverTypes.ts`: include `IHoverPart`, hover anchors and their constants,
  cancellation-bearing participant members/constructor/registry, and
  `IHoverWidget` (17–83, 161–167 excluding `hideCopyButton`, 176–203). Exclude
  status-bar, action, color-picker, render-context/rendered-part structures and
  rendering/accessibility/resize/hide/contents/scroll participant methods
  (85–159, 163, 168–174).
- `textModel.ts`: include only the model/resource/version identity cluster:
  `MODEL_ID`, `id`, `_associatedResource`, `_versionId`,
  `_alternativeVersionId`, their construction, `uri`,
  `getVersionId`, `_increaseVersionId`, and only the version transition or
  observation facts at setValue/EOL/edit/overwrite boundaries. Editing/EOL/buffer
  arithmetic, alternative-version public APIs, undo paths, and tokenization are
  named siblings owned by other plans. Decoration-only `_instanceId`
  declaration/init/use (284, 377, 2030) is explicitly excluded.
- `cancellation.ts`: include the token contract, shortcut event, `None`,
  `Cancelled`, `MutableToken`, and `CancellationTokenSource` (9–30, 49–142).
  Exclude type-recognition utility `isCancellationToken` (32–46),
  `cancelOnDispose` (144–148), and `CancellationTokenPool` (150–206): no scoped
  controller consumes those sibling utilities.

Async/runtime seam: MoonBit `async_run` tasks and the raw browser `set_timeout`
binding have no implicit disposable owner. The ledger therefore preserves the
source cancellation transitions, while the later implementation review must
choose the minimum explicit source/token/handle ownership compatible with the
MoonBit runtime. This is a seam, not permission to weaken stale-result guards.

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

The authoritative strict whole-unit reread produced **759 source inventory
members**:

`IHC 156 + IHF 41 + CHC 152 + CHW 140 + HOP 78 + CHCMP 31 + GHR 25 + HTY 63 + TMV 24 + CTS 49 = 759`.

Every declared member, behavior-changing branch/early return, and scoped
constant/CSS fact below is a first-class parity-ledger row; excluded sibling
members are atomic rows too. `MoonBit symbol` stays `TBD at review` and every
status stays `TODO` at this stop gate. Review must approve targets and planned
dispositions without pretending implementation evidence already exists.

Abbreviations: `IHC` = `inlayHintsController.ts`; `IHF` = `inlayHints.ts`;
`CHC` = `contentHoverController.ts`; `CHW` =
`contentHoverWidgetWrapper.ts`; `HOP` = `hoverOperation.ts`; `CHCMP` =
`contentHoverComputer.ts`; `GHR` = `getHover.ts`; `HTY` = `hoverTypes.ts`;
`TMV` = `textModel.ts`; `CTS` = `cancellation.ts`.

| ID | Source member (file:line) | Arithmetic/transition | MoonBit symbol | Status |
|---|---|---|---|---|
| IHC-001 | IHC:45 | `_serviceBrand` DI brand field. | TBD at review | TODO |
| IHC-002 | IHC:47 | `_entries` owns the inlay-item LRU cache. | TBD at review | TODO |
| IHC-003 | IHC:47 | LRU capacity magic value is exactly `50`. | TBD at review | TODO |
| IHC-004 | IHC:49-52 | `get(model)` derives one cache key, then returns that lookup. | TBD at review | TODO |
| IHC-005 | IHC:54-57 | `set(model,value)` derives one cache key, then inserts/replaces. | TBD at review | TODO |
| IHC-006 | IHC:59-61 | `_key(model)` concatenates URI text, the separator, and `getVersionId()` in that order. | TBD at review | TODO |
| IHC-007 | IHC:60 | Cache-key separator magic value is exactly `/`. | TBD at review | TODO |
| IHC-008 | IHC:64 | `IInlayHintsCache` is the service interface extending `InlayHintsCache`. | TBD at review | TODO |
| IHC-009 | IHC:65 | Cache decorator ID is exactly `IInlayHintsCache`. | TBD at review | TODO |
| IHC-010 | IHC:66 | The cache is registered as a delayed singleton. | TBD at review | TODO |
| IHC-011 | IHC:71 | Rendered label-part `item` parameter-property. | TBD at review | TODO |
| IHC-012 | IHC:71 | Rendered label-part `index` parameter-property. | TBD at review | TODO |
| IHC-013 | IHC:71 | `RenderedInlayHintLabelPart` constructor retains item and index. | TBD at review | TODO |
| IHC-014 | IHC:73-80 | `part` getter reads the hint label and returns one label part. | TBD at review | TODO |
| IHC-015 | IHC:75-79 | String labels become `{ label }`; structured labels select the exact indexed part. | TBD at review | TODO |
| IHC-016 | IHC:84 | Active-label `part` parameter-property. | TBD at review | TODO |
| IHC-017 | IHC:84 | Active-label `hasTriggerModifier` parameter-property. | TBD at review | TODO |
| IHC-018 | IHC:84 | `ActiveInlayHintInfo` constructor retains part and modifier state. | TBD at review | TODO |
| IHC-019 | IHC:88 | Decoration metadata retains the originating item. | TBD at review | TODO |
| IHC-020 | IHC:89 | Decoration metadata retains the model delta decoration. | TBD at review | TODO |
| IHC-021 | IHC:90 | Decoration metadata owns the disposable CSS class reference. | TBD at review | TODO |
| IHC-022 | IHC:94 | `RenderMode.Normal` enum value. | TBD at review | TODO |
| IHC-023 | IHC:95 | `RenderMode.Invisible` enum value. | TBD at review | TODO |
| IHC-024 | IHC:105 | `CancellationStore._store` owns replaceable operation disposables. | TBD at review | TODO |
| IHC-025 | IHC:106 | `_tokenSource` starts as a fresh source. | TBD at review | TODO |
| IHC-026 | IHC:108-111 | `dispose` retires the operation store first, then disposes the token source with `cancel=true`. | TBD at review | TODO |
| IHC-027 | IHC:113-121 | `reset` cancels/disposes the old source, creates the new source, replaces and thereby disposes the old operation store, then returns the matching new store/token pair. | TBD at review | TODO |
| IHC-028 | IHC:131 | Contribution ID is exactly `editor.contrib.InlayHints`. | TBD at review | TODO |
| IHC-029 | IHC:133 | Maximum-decoration constant is exactly `1500`. | TBD at review | TODO |
| IHC-030 | IHC:134 | `_whitespaceData` is one shared empty-object sentinel. | TBD at review | TODO |
| IHC-031 | IHC:136-138 | Static `get` reads this contribution from the editor. | TBD at review | TODO |
| IHC-032 | IHC:137 | A nullish contribution is normalized to `undefined`. | TBD at review | TODO |
| IHC-033 | IHC:140 | `_disposables` owns controller-lifetime resources. | TBD at review | TODO |
| IHC-034 | IHC:141 | `_sessionDisposables` owns the current-model session. | TBD at review | TODO |
| IHC-035 | IHC:142 | `_decorationsMetadata` owns active decoration metadata. | TBD at review | TODO |
| IHC-036 | IHC:143 | `_debounceInfo` owns provider/model debounce state. | TBD at review | TODO |
| IHC-037 | IHC:144 | `_ruleFactory` owns dynamic CSS rules. | TBD at review | TODO |
| IHC-038 | IHC:146 | `_cursorInfo` stores cursor position plus absolute freshness deadline. | TBD at review | TODO |
| IHC-039 | IHC:147 | `_activeRenderMode` starts `Normal`. | TBD at review | TODO |
| IHC-040 | IHC:148 | `_activeInlayHintPart` starts absent. | TBD at review | TODO |
| IHC-041 | IHC:151 | `_editor` parameter-property owns the captured editor reference. | TBD at review | TODO |
| IHC-042 | IHC:152 | Language-features service parameter-property owns the consulted registry. | TBD at review | TODO |
| IHC-043 | IHC:154 | Inlay-cache parameter-property owns the fast-restore cache. | TBD at review | TODO |
| IHC-044 | IHC:155 | Command-service parameter-property. | TBD at review | TODO |
| IHC-045 | IHC:156 | Notification-service parameter-property. | TBD at review | TODO |
| IHC-046 | IHC:157 | Instantiation-service parameter-property. | TBD at review | TODO |
| IHC-047 | IHC:150-171 | Constructor creates the owned rule factory, debounce state, provider/model/language/configuration subscriptions in source order, then performs one immediate `_update`. | TBD at review | TODO |
| IHC-048 | IHC:160 | Debounce key is `InlayHint` and minimum delay is exactly `25` ms. | TBD at review | TODO |
| IHC-049 | IHC:164-168 | Constructor configuration callback invokes `_update` only when `EditorOption.inlayHints` changed. | TBD at review | TODO |
| IHC-050 | IHC:173-177 | `dispose` retires the current session, removes every decoration, then retires controller-lifetime resources. | TBD at review | TODO |
| IHC-051 | IHC:179-312 | `_update` clears session then decorations; establishes mode/cache/session; each run timestamps, resets cancellation, awaits fragments for the captured model and current-editor ranges, updates debounce before the cancel guard, retains provider listeners/fragments, applies then caches; finally it owns scroll/content/configuration/gesture subscriptions in source order. | TBD at review | TODO |
| IHC-052 | IHC:183-186 | Enabled mode `off` returns after cleanup. | TBD at review | TODO |
| IHC-053 | IHC:188-191 | Missing model or no matching provider returns after cleanup. | TBD at review | TODO |
| IHC-054 | IHC:193-196 | Enabled mode `on` selects normal rendering and skips modifier subscription. | TBD at review | TODO |
| IHC-055 | IHC:196-222 | Every non-`on` mode enters default/alternate selection and installs the modifier subscription. | TBD at review | TODO |
| IHC-056 | IHC:200-202 | `onUnlessPressed` selects normal default and invisible alternate. | TBD at review | TODO |
| IHC-057 | IHC:203-205 | The other non-`on` mode selects invisible default and normal alternate. | TBD at review | TODO |
| IHC-058 | IHC:209-212 | Modifier callback returns when the editor no longer has a model. | TBD at review | TODO |
| IHC-059 | IHC:213 | Alt+Ctrl without Shift/Meta selects alternate mode; every other combination selects default. | TBD at review | TODO |
| IHC-060 | IHC:214-220 | A changed render mode updates state, copies current anchors, replaces full-model decorations, then schedules refresh. | TBD at review | TODO |
| IHC-061 | IHC:219 | Modifier-triggered refresh uses exact delay `0`. | TBD at review | TODO |
| IHC-062 | IHC:224-228 | A truthy cache hit applies over the full captured-model range. | TBD at review | TODO |
| IHC-063 | IHC:229-234 | Session teardown caches anchors only while the captured model is not disposed. | TBD at review | TODO |
| IHC-064 | IHC:236-239 | Model disposal invokes optional `cts?.cancel()`; `cts` is never assigned in this source, so the call is a no-op. | TBD at review | TODO |
| IHC-065 | IHC:243-276 | Scheduler request passes the captured `model`, while `_getHintsRanges()` independently reads `editor.getModel()!` at execution time. | TBD at review | TODO |
| IHC-066 | IHC:250-254 | Debounce delay updates before the post-await cancellation guard; cancellation disposes fragments and returns before mutation. | TBD at review | TODO |
| IHC-067 | IHC:258-264 | Only providers with a change function and absent from `watchedProviders` are subscribed. | TBD at review | TODO |
| IHC-068 | IHC:260-264 | Provider change schedules only while no run is already scheduled. | TBD at review | TODO |
| IHC-069 | IHC:273-275 | Every thrown request error, including cancellation reaching this catch, is passed to `onUnexpectedError`. | TBD at review | TODO |
| IHC-070 | IHC:279 | First session request uses exact delay `0`. | TBD at review | TODO |
| IHC-071 | IHC:281-288 | Scroll schedules when top changed or the scheduler is idle; otherwise it is a no-op. | TBD at review | TODO |
| IHC-072 | IHC:291-292 | Content change invokes the same unassigned optional `cts?.cancel()` no-op. | TBD at review | TODO |
| IHC-073 | IHC:294-296 | Content stabilization floor is exactly `800` ms via `max(scheduler.delay, 800)`. | TBD at review | TODO |
| IHC-074 | IHC:296-299 | Replacing the cursor timeout cancels its predecessor; the new timeout waits `delay`, then its callback calls `scheduler.schedule(0)` before normal debounced scheduling. | TBD at review | TODO |
| IHC-075 | IHC:302-305 | Session configuration schedules only when `EditorOption.inlayHints` changed. | TBD at review | TODO |
| IHC-076 | IHC:314-368 | `_installLinkGesture` creates one owning store, nested session store, link gesture, move/cancel/execute subscriptions, and returns the owner. | TBD at review | TODO |
| IHC-077 | IHC:329-332 | Missing label part or model clears the nested session and returns. | TBD at review | TODO |
| IHC-078 | IHC:340-342 | Command or location creates active-label state; neither clears it. | TBD at review | TODO |
| IHC-079 | IHC:354-366 | Execute callback does work only when a label part exists. | TBD at review | TODO |
| IHC-080 | IHC:358-360 | A location invokes go-to-definition. | TBD at review | TODO |
| IHC-081 | IHC:361-364 | Otherwise a valid command is awaited through `_invokeCommand`. | TBD at review | TODO |
| IHC-082 | IHC:370-378 | `_getInlineHintsForRange` deduplicates matching items in metadata iteration order. | TBD at review | TODO |
| IHC-083 | IHC:373-375 | An item is added only when the requested range contains its anchor range. | TBD at review | TODO |
| IHC-084 | IHC:309,380-396 | `_installDblClickGesture` owns the complete double-click resolve/edit/update member; the session supplies a callback whose refresh delay is exactly `0`. | TBD at review | TODO |
| IHC-085 | IHC:382-384 | Mouse-up detail other than exactly `2` returns before lookup. | TBD at review | TODO |
| IHC-086 | IHC:385-388 | Missing label part returns before prevent-default and resolve. | TBD at review | TODO |
| IHC-087 | IHC:391-395 | Nonempty text edits map to replace operations, execute with source `inlayHint.default`, then invoke the supplied refresh callback. | TBD at review | TODO |
| IHC-088 | IHC:399-409 | `_installContextMenu` returns the editor context-menu subscription. | TBD at review | TODO |
| IHC-089 | IHC:401-403 | A non-HTMLElement event target returns before label lookup. | TBD at review | TODO |
| IHC-090 | IHC:404-407 | A present label part invokes the context menu; absence is a no-op. | TBD at review | TODO |
| IHC-091 | IHC:411-420 | `_getInlayHintLabelPart` reads content-text injected options and otherwise returns `undefined`. | TBD at review | TODO |
| IHC-092 | IHC:412-414 | Non-content-text target returns `undefined` immediately. | TBD at review | TODO |
| IHC-093 | IHC:415-418 | Exact options and attached-data instance checks return the rendered part. | TBD at review | TODO |
| IHC-094 | IHC:422-432 | `_invokeCommand` awaits the command and reports failures through notification. | TBD at review | TODO |
| IHC-095 | IHC:424 | Missing command arguments fall back to an empty array before spreading. | TBD at review | TODO |
| IHC-096 | IHC:425-430 | Command failure notifies Error severity with provider display name and the error message. | TBD at review | TODO |
| IHC-097 | IHC:434-437 | `_cacheHintsForFastRestore` copies current anchors, then sets the model-keyed cache. | TBD at review | TODO |
| IHC-098 | IHC:441-457 | `_copyInlayHintsWithCurrentAnchor` scans metadata, preserves first-seen item order, and returns copied anchors. | TBD at review | TODO |
| IHC-099 | IHC:444-448 | A repeated item continues before another decoration-range read. | TBD at review | TODO |
| IHC-100 | IHC:449-455 | A present decoration range creates same-direction anchor/copy; a missing range omits that item. | TBD at review | TODO |
| IHC-101 | IHC:460-473 | `_getHintsRanges` reads current model/visible ranges, sorts by start, extends, validates, merges, and returns sorted output. | TBD at review | TODO |
| IHC-102 | IHC:461,466 | Viewport extension magic value is exactly `30` lines above and below. | TBD at review | TODO |
| IHC-103 | IHC:467-469 | Empty output or an extended range that neither intersects nor touches appends. | TBD at review | TODO |
| IHC-104 | IHC:469-471 | The explicit else arm merges touching/intersecting range with the last result via `plusRange`. | TBD at review | TODO |
| IHC-105 | IHC:476-728 | `_updateHintsDecorators` computes fixed lengths and complete injected-decoration data before collecting affected IDs; it then captures scroll, deltas once, pairs returned IDs by index, and restores scroll. | TBD at review | TODO |
| IHC-106 | IHC:480-483 | Cursor stabilization runs only with live cursor info, an unexpired deadline, and a request range containing its position. | TBD at review | TODO |
| IHC-107 | IHC:491 | Missing line decorations fall back to an empty array. | TBD at review | TODO |
| IHC-108 | IHC:493-496 | Decoration starting after the cursor continues before option accounting. | TBD at review | TODO |
| IHC-109 | IHC:497-501 | Existing directed options count only when attached data is not the whitespace sentinel. | TBD at review | TODO |
| IHC-110 | IHC:499 | Missing prior item length falls back to `0` before accumulation. | TBD at review | TODO |
| IHC-111 | IHC:506 | New fixed-length candidates require the cursor line and anchor end at/before cursor column. | TBD at review | TODO |
| IHC-112 | IHC:515-517 | Missing both fixed length and target item breaks the matching loop. | TBD at review | TODO |
| IHC-113 | IHC:519-522 | Present target item records its fixed length and becomes the last item. | TBD at review | TODO |
| IHC-114 | IHC:520 | Missing matched fixed length falls back to `0`. | TBD at review | TODO |
| IHC-115 | IHC:523-530 | Remaining positive lengths with a last item are summed, the pending array is cleared, then the loop breaks. | TBD at review | TODO |
| IHC-116 | IHC:555 | Directed injected options exist only in `RenderMode.Normal`; invisible mode stores `undefined`. | TBD at review | TODO |
| IHC-117 | IHC:561-575,653-668 | Layout magic values preserve `fontSize / 3` width, hair-space content, exact font-family custom property, `1px` padding, minimum horizontal padding `1`, and `fontSize / 4` radii. | TBD at review | TODO |
| IHC-118 | IHC:566 | Injected whitespace stops right only when it is last; otherwise it has no cursor stop. | TBD at review | TODO |
| IHC-119 | IHC:583-585 | A new source line resets line-total accounting before length checks. | TBD at review | TODO |
| IHC-120 | IHC:587-589 | Truthy maximum with total already strictly greater than maximum continues before rendering the item. | TBD at review | TODO |
| IHC-121 | IHC:592-594 | Left padding emits leading injected whitespace only when requested. | TBD at review | TODO |
| IHC-122 | IHC:597-599 | String label becomes one synthetic part; structured label preserves its part array. | TBD at review | TODO |
| IHC-123 | IHC:613 | Uniform layout uses `baseline`; nonuniform uses `middle`. | TBD at review | TODO |
| IHC-124 | IHC:617-619 | Nonempty text edits set cursor style to `default`. | TBD at review | TODO |
| IHC-125 | IHC:623-630 | Matching active command/location part underlines the label. | TBD at review | TODO |
| IHC-126 | IHC:626-629 | Trigger modifier additionally selects active-link color and pointer cursor. | TBD at review | TODO |
| IHC-127 | IHC:635 | Maximum length `0` forces overage `0`; nonzero uses total minus maximum. | TBD at review | TODO |
| IHC-128 | IHC:636-639 | Positive overage truncates by exact overage and appends ellipsis. | TBD at review | TODO |
| IHC-129 | IHC:643-651 | Defined fixed length enables fixed-length comparison and trimming. | TBD at review | TODO |
| IHC-130 | IHC:645-650 | Nonnegative fixed-length overage trims by `1 + overage` and appends ellipsis. | TBD at review | TODO |
| IHC-131 | IHC:653-669 | Padding-shape decisions run only when padding is enabled. | TBD at review | TODO |
| IHC-132 | IHC:654-657 | First part that is also last or truncated gets symmetric padding and radius. | TBD at review | TODO |
| IHC-133 | IHC:658-661 | Other first part gets left-only padding/radius. | TBD at review | TODO |
| IHC-134 | IHC:662-665 | Last or truncated nonfirst part gets right-only padding/radius. | TBD at review | TODO |
| IHC-135 | IHC:666-668 | Interior part gets vertical-only padding. | TBD at review | TODO |
| IHC-136 | IHC:675 | Final label part without requested right padding stops right; every other part has no cursor stop. | TBD at review | TODO |
| IHC-137 | IHC:679-681 | Truncation breaks the part loop immediately. | TBD at review | TODO |
| IHC-138 | IHC:684-693 | Short fixed-length item emits the exact hair-space deficit with no cursor stops. | TBD at review | TODO |
| IHC-139 | IHC:696-698 | Requested right padding emits trailing injected whitespace. | TBD at review | TODO |
| IHC-140 | IHC:700-702 | Decoration count strictly greater than `1500` breaks the item loop. | TBD at review | TODO |
| IHC-141 | IHC:709 | Missing current editor model or decoration range yields no affected old decoration. | TBD at review | TODO |
| IHC-142 | IHC:710-714 | Only an existing range contained by a request range queues the old ID, disposes its class ref, and deletes metadata in that order. | TBD at review | TODO |
| IHC-143 | IHC:730-741 | `_fillInColors` selects one background/foreground pair. | TBD at review | TODO |
| IHC-144 | IHC:731-733 | Parameter kind selects parameter colors. | TBD at review | TODO |
| IHC-145 | IHC:734-736 | Type kind selects type colors. | TBD at review | TODO |
| IHC-146 | IHC:737-740 | Every other kind selects generic inlay colors. | TBD at review | TODO |
| IHC-147 | IHC:743-762 | `_getLayoutInfo` reads options/editor font, resolves size/family, computes uniformity, and returns all four values. | TBD at review | TODO |
| IHC-148 | IHC:750-753 | Falsy font size, size below exactly `5`, or size above editor size falls back to editor size. | TBD at review | TODO |
| IHC-149 | IHC:755 | Falsy configured font family falls back to editor font family. | TBD at review | TODO |
| IHC-150 | IHC:764-770 | `_removeAllDecorations` removes all IDs at once, disposes every class ref, then clears metadata. | TBD at review | TODO |
| IHC-151 | IHC:775-789 | `getInlayHintsForLine` deduplicates hints in line-decoration order. | TBD at review | TODO |
| IHC-152 | IHC:776-778 | Missing editor model returns an empty result. | TBD at review | TODO |
| IHC-153 | IHC:782-786 | Present metadata with an unseen hint adds the hint and item; every other decoration is skipped. | TBD at review | TODO |
| IHC-154 | IHC:793-797 | `fixSpace` globally replaces space/tab with nonbreaking whitespace. | TBD at review | TODO |
| IHC-155 | IHC:799-815 | Execute-provider command validates URI/range, acquires a model reference, awaits fragments for lifted range with `CancellationToken.None`, maps hints, returns them, and always disposes the reference in `finally`. | TBD at review | TODO |
| IHC-156 | IHC:810 | Fragment disposal is deferred with exact timeout `0` after result mapping. | TBD at review | TODO |
| IHF-001 | IHF:17 | Anchor `range` parameter-property. | TBD at review | TODO |
| IHF-002 | IHF:17 | Anchor `direction` parameter-property accepts exactly `before` or `after`. | TBD at review | TODO |
| IHF-003 | IHF:16-18 | `InlayHintAnchor` constructor retains range and direction. | TBD at review | TODO |
| IHF-004 | IHF:22 | Item resolved-state field starts `false`. | TBD at review | TODO |
| IHF-005 | IHF:23 | Current resolve-promise field starts `undefined`. | TBD at review | TODO |
| IHF-006 | IHF:25 | Item `hint` parameter-property. | TBD at review | TODO |
| IHF-007 | IHF:25 | Item `anchor` parameter-property. | TBD at review | TODO |
| IHF-008 | IHF:25 | Item `provider` parameter-property. | TBD at review | TODO |
| IHF-009 | IHF:25 | `InlayHintItem` constructor retains hint, anchor, and provider. | TBD at review | TODO |
| IHF-010 | IHF:27-32 | `with` creates same hint/provider with replacement anchor, copies both resolve fields, then returns. | TBD at review | TODO |
| IHF-011 | IHF:34-52 | Explicit excluded sibling `resolve` serializes provider resolution; an active resolve is awaited before recursive retry, unresolved work installs one promise whose `finally` clears the field, and the final promise is awaited. | TBD at review | TODO |
| IHF-012 | IHF:35-37 | Provider without `resolveInlayHint` returns immediately. | TBD at review | TODO |
| IHF-013 | IHF:38-46 | Existing resolve promise is awaited before cancellation/retry decisions. | TBD at review | TODO |
| IHF-014 | IHF:42-44 | Cancellation after waiting for an active resolve returns before recursive retry. | TBD at review | TODO |
| IHF-015 | IHF:47-50 | Only unresolved items install a new `_doResolve` promise; resolved items skip it. | TBD at review | TODO |
| IHF-016 | IHF:54-65 | Explicit excluded sibling `_doResolve` awaits the provider, applies tooltip/label/text-edit fallbacks in order, then marks resolved. | TBD at review | TODO |
| IHF-017 | IHF:57 | Nullish resolved tooltip preserves the old tooltip. | TBD at review | TODO |
| IHF-018 | IHF:58 | Nullish resolved label preserves the old label. | TBD at review | TODO |
| IHF-019 | IHF:59 | Nullish resolved text edits preserve the old text edits. | TBD at review | TODO |
| IHF-020 | IHF:61-64 | Resolve failure passes the error to `onUnexpectedExternalError`, then resets resolved state to `false`. | TBD at review | TODO |
| IHF-021 | IHF:70 | Frozen empty list has empty hints and a no-op disposer. | TBD at review | TODO |
| IHF-022 | IHF:72-94 | `create` launches `ordered(model).reverse()` provider/range calls with one captured model/token, awaits all, then constructs fragments; `data.push` occurs after each await, so retained-pair order is completion order rather than launch order. | TBD at review | TODO |
| IHF-023 | IHF:79-81 | A result is retained only with nonempty hints or a provider change event; a non-null empty unretained list is neither retained nor disposed. | TBD at review | TODO |
| IHF-024 | IHF:80 | Retained nullish result falls back to the frozen empty list. | TBD at review | TODO |
| IHF-025 | IHF:82-84 | Each provider/range failure is independently passed to `onUnexpectedExternalError` and contained. | TBD at review | TODO |
| IHF-026 | IHF:89-91 | After all calls settle, cancellation or disposed model throws `CancellationError`. | TBD at review | TODO |
| IHF-027 | IHF:96 | `_disposables` owns every retained provider list. | TBD at review | TODO |
| IHF-028 | IHF:98 | Readonly `items` result field. | TBD at review | TODO |
| IHF-029 | IHF:99 | Readonly `ranges` result field. | TBD at review | TODO |
| IHF-030 | IHF:100 | Readonly deduplicated `provider` result field. | TBD at review | TODO |
| IHF-031 | IHF:102-130 | Constructor retains ranges, processes retained pairs in completion order, owns lists, deduplicates providers, validates positions, derives anchors, creates items, then sorts by hint position. | TBD at review | TODO |
| IHF-032 | IHF:118-120 | Word start before hint builds start-to-hint anchor and changes direction to `after`. | TBD at review | TODO |
| IHF-033 | IHF:121-124 | Otherwise hint-to-word-end anchor keeps direction `before`. | TBD at review | TODO |
| IHF-034 | IHF:132-134 | `dispose` retires every retained provider list. | TBD at review | TODO |
| IHF-035 | IHF:136-165 | `_getRangeAtPosition` reads word/token data; no-word flow tokenizes cheaply, fetches line tokens, converts column to zero-based offset, selects/adjusts token bounds, then returns one-based columns. | TBD at review | TODO |
| IHF-036 | IHF:139-142 | Existing word range returns immediately before tokenization. | TBD at review | TODO |
| IHF-037 | IHF:152-163 | Neighbor adjustment is considered only for token length exactly `1`. | TBD at review | TODO |
| IHF-038 | IHF:154-157 | Leading adjustment requires start=offset and index strictly greater than `1`. | TBD at review | TODO |
| IHF-039 | IHF:158-162 | Only after the leading condition fails, trailing adjustment requires end=offset and index below count minus `1`. | TBD at review | TODO |
| IHF-040 | IHF:169-171 | Explicit excluded sibling `asCommandLink` creates the command URI with ID/arguments, then returns `toString()`. | TBD at review | TODO |
| IHF-041 | IHF:170 | Nullish command arguments fall back to an empty array before spreading. | TBD at review | TODO |
| CHC-001 | CHC:28-31 | Module `_sticky` constant is `false`. | TBD at review | TODO |
| CHC-002 | CHC:33-34 | Hover settings `enabled` member. | TBD at review | TODO |
| CHC-003 | CHC:35 | Hover settings `sticky` member. | TBD at review | TODO |
| CHC-004 | CHC:36 | Hover settings `hidingDelay` member. | TBD at review | TODO |
| CHC-005 | CHC:41 | Owned contents-changed emitter. | TBD at review | TODO |
| CHC-006 | CHC:42 | Public contents-changed event alias. | TBD at review | TODO |
| CHC-007 | CHC:44 | Contribution ID is exactly `editor.contrib.contentHover`. | TBD at review | TODO |
| CHC-008 | CHC:46 | Public keep-open override starts false. | TBD at review | TODO |
| CHC-009 | CHC:48 | Listener store owns hook generation. | TBD at review | TODO |
| CHC-010 | CHC:50 | Lazily created content widget field. | TBD at review | TODO |
| CHC-011 | CHC:52 | Latest editor mouse-move event field. | TBD at review | TODO |
| CHC-012 | CHC:53 | Deferred mouse-react scheduler field. | TBD at review | TODO |
| CHC-013 | CHC:55 | Captured hover settings field. | TBD at review | TODO |
| CHC-014 | CHC:56 | Mouse-down state starts false. | TBD at review | TODO |
| CHC-015 | CHC:58 | Ignore-mouse-events state starts false. | TBD at review | TODO |
| CHC-016 | CHC:61 | Editor dependency member. | TBD at review | TODO |
| CHC-017 | CHC:62 | Context-menu service dependency. | TBD at review | TODO |
| CHC-018 | CHC:63 | Instantiation service dependency. | TBD at review | TODO |
| CHC-019 | CHC:64 | Keybinding service dependency. | TBD at review | TODO |
| CHC-020 | CHC:66 | Constructor establishes disposable base. | TBD at review | TODO |
| CHC-021 | CHC:67-73 | Registered mouse-react runner uses delay `0`. | TBD at review | TODO |
| CHC-022 | CHC:69-71 | Runner reacts only when a latest mouse event exists. | TBD at review | TODO |
| CHC-023 | CHC:74-77 | Context-menu show hides hover then ignores mouse events. | TBD at review | TODO |
| CHC-024 | CHC:78-80 | Context-menu hide reenables mouse events. | TBD at review | TODO |
| CHC-025 | CHC:81 | Constructor installs hover listeners. | TBD at review | TODO |
| CHC-026 | CHC:82 | Configuration listener is controller-owned. | TBD at review | TODO |
| CHC-027 | CHC:83-86 | Only hover-option change rehooks listeners. | TBD at review | TODO |
| CHC-028 | CHC:90-92 | Static `get` resolves contribution by ID. | TBD at review | TODO |
| CHC-029 | CHC:94-100 | `_hookListeners` snapshots enabled/sticky/hiding delay. | TBD at review | TODO |
| CHC-030 | CHC:101-103 | Disabled hover cancels scheduler and hides. | TBD at review | TODO |
| CHC-031 | CHC:104 | Hook owns mouse-down subscription. | TBD at review | TODO |
| CHC-032 | CHC:105 | Hook owns mouse-up subscription. | TBD at review | TODO |
| CHC-033 | CHC:106 | Hook owns mouse-move subscription. | TBD at review | TODO |
| CHC-034 | CHC:107 | Hook owns key-down subscription. | TBD at review | TODO |
| CHC-035 | CHC:108 | Hook owns mouse-leave subscription. | TBD at review | TODO |
| CHC-036 | CHC:109 | Model change cancels scheduler and hides. | TBD at review | TODO |
| CHC-037 | CHC:110 | Model-content change cancels pending scheduler only. | TBD at review | TODO |
| CHC-038 | CHC:111 | Hook owns scroll-change subscription. | TBD at review | TODO |
| CHC-039 | CHC:114-116 | `_unhookListeners` clears the generation store. | TBD at review | TODO |
| CHC-040 | CHC:118-121 | `_cancelSchedulerAndHide` orders cancellation before hide. | TBD at review | TODO |
| CHC-041 | CHC:123-126 | `_cancelScheduler` clears captured event then cancels runner. | TBD at review | TODO |
| CHC-042 | CHC:128 | Scroll-change handler member. | TBD at review | TODO |
| CHC-043 | CHC:129-131 | Ignored mouse events return before scroll reaction. | TBD at review | TODO |
| CHC-044 | CHC:132-134 | Top or left scroll change hides hover. | TBD at review | TODO |
| CHC-045 | CHC:137 | Mouse-down handler member. | TBD at review | TODO |
| CHC-046 | CHC:138-140 | Ignored mouse events return before down state. | TBD at review | TODO |
| CHC-047 | CHC:141 | Accepted down sets `_isMouseDown=true`. | TBD at review | TODO |
| CHC-048 | CHC:142-145 | Keep-visible predicate returns before hide. | TBD at review | TODO |
| CHC-049 | CHC:146 | Otherwise mouse-down hides. | TBD at review | TODO |
| CHC-050 | CHC:149-151 | Keep-visible is widget hit, resize, or color decorator. | TBD at review | TODO |
| CHC-051 | CHC:153 | Content-widget hit-test member. | TBD at review | TODO |
| CHC-052 | CHC:154-156 | Missing/disconnected widget returns false. | TBD at review | TODO |
| CHC-053 | CHC:157 | Connected widget uses DOM position containment. | TBD at review | TODO |
| CHC-054 | CHC:160 | Mouse-up handler member. | TBD at review | TODO |
| CHC-055 | CHC:161-163 | Ignored mouse-up returns. | TBD at review | TODO |
| CHC-056 | CHC:164 | Accepted mouse-up clears down state. | TBD at review | TODO |
| CHC-057 | CHC:167 | Mouse-leave handler member. | TBD at review | TODO |
| CHC-058 | CHC:168-170 | Ignored mouse leave returns. | TBD at review | TODO |
| CHC-059 | CHC:171-173 | Explicit keep-open returns. | TBD at review | TODO |
| CHC-060 | CHC:174 | Leave cancels pending scheduler before visibility checks. | TBD at review | TODO |
| CHC-061 | CHC:175-178 | Keep-visible predicate returns. | TBD at review | TODO |
| CHC-062 | CHC:179-181 | Module sticky constant returns. | TBD at review | TODO |
| CHC-063 | CHC:182 | Otherwise leave hides. | TBD at review | TODO |
| CHC-064 | CHC:185 | Current-hover retention member. | TBD at review | TODO |
| CHC-065 | CHC:187-189 | Missing widget returns false. | TBD at review | TODO |
| CHC-066 | CHC:190 | Sticky option captured for retention. | TBD at review | TODO |
| CHC-067 | CHC:191-194 | Sticky widget-hit helper requires sticky and containment. | TBD at review | TODO |
| CHC-068 | CHC:195-201 | Color-picker helper retains visible hit or mouse-down choice. | TBD at review | TODO |
| CHC-069 | CHC:203-207 | Selection helper returns false without browser view. | TBD at review | TODO |
| CHC-070 | CHC:208 | Selection retention requires sticky and contained active element; absent selection or noncollapsed selection makes the final negated optional predicate true. | TBD at review | TODO |
| CHC-071 | CHC:210-212 | Focus, resize, and sticky-keyboard state are captured. | TBD at review | TODO |
| CHC-072 | CHC:214-220 | Retention ORs explicit keep, focus, resize, keyboard, sticky hit, color, selection. | TBD at review | TODO |
| CHC-073 | CHC:223 | Mouse-move handler member. | TBD at review | TODO |
| CHC-074 | CHC:224-226 | Ignored mouse move returns. | TBD at review | TODO |
| CHC-075 | CHC:227 | Accepted move replaces captured event. | TBD at review | TODO |
| CHC-076 | CHC:228-232 | Current-hover retention cancels runner and returns. | TBD at review | TODO |
| CHC-077 | CHC:233 | Move computes whether hover should be rescheduled. | TBD at review | TODO |
| CHC-078 | CHC:234-239 | Reschedule path returns without immediate reaction. | TBD at review | TODO |
| CHC-079 | CHC:235-237 | Reschedule only when runner is not already scheduled. | TBD at review | TODO |
| CHC-080 | CHC:236 | Reschedule uses configured hiding delay. | TBD at review | TODO |
| CHC-081 | CHC:240 | Non-rescheduled move reacts immediately. | TBD at review | TODO |
| CHC-082 | CHC:243 | Reschedule predicate member. | TBD at review | TODO |
| CHC-083 | CHC:245 | Absent widget visibility defaults false. | TBD at review | TODO |
| CHC-084 | CHC:248 | Reschedule requires visible, sticky, and delay greater than `0`. | TBD at review | TODO |
| CHC-085 | CHC:251 | Mouse reaction member. | TBD at review | TODO |
| CHC-086 | CHC:252-256 | `shouldShowHover` gates computation. | TBD at review | TODO |
| CHC-087 | CHC:257 | Show path lazily gets/creates widget. | TBD at review | TODO |
| CHC-088 | CHC:258-260 | Widget showing or pending returns early. | TBD at review | TODO |
| CHC-089 | CHC:262-264 | Module sticky constant suppresses fallback hide. | TBD at review | TODO |
| CHC-090 | CHC:265 | Otherwise reaction hides. | TBD at review | TODO |
| CHC-091 | CHC:268 | Key-down handler member. | TBD at review | TODO |
| CHC-092 | CHC:269-271 | Ignored keys or missing widget return. | TBD at review | TODO |
| CHC-093 | CHC:273-275 | Modifier-only mode requires trigger modifier and captured mouse event. | TBD at review | TODO |
| CHC-094 | CHC:276-278 | Invisible widget restarts from captured mouse event. | TBD at review | TODO |
| CHC-095 | CHC:279 | Modifier-mode branch always returns. | TBD at review | TODO |
| CHC-096 | CHC:282-286 | Potential shortcut or any modifier key preserves hover. | TBD at review | TODO |
| CHC-097 | CHC:287-289 | Focused widget preserves Tab. | TBD at review | TODO |
| CHC-098 | CHC:290 | All other keys hide. | TBD at review | TODO |
| CHC-099 | CHC:293 | Potential-shortcut classifier member. | TBD at review | TODO |
| CHC-100 | CHC:294-296 | Missing model or widget returns false. | TBD at review | TODO |
| CHC-101 | CHC:297 | Key event is soft-dispatched against editor DOM. | TBD at review | TODO |
| CHC-102 | CHC:298 | More-chords-needed is retention state. | TBD at review | TODO |
| CHC-103 | CHC:299-303 | Three hover action IDs count only when widget is visible. | TBD at review | TODO |
| CHC-104 | CHC:304 | Classifier returns more-chords OR matching hover action. | TBD at review | TODO |
| CHC-105 | CHC:307 | Public hide member. | TBD at review | TODO |
| CHC-106 | CHC:308-310 | Module sticky constant prevents hide. | TBD at review | TODO |
| CHC-107 | CHC:311-313 | Visible inline-suggestion dropdown prevents hide. | TBD at review | TODO |
| CHC-108 | CHC:314 | Otherwise delegates widget hide. | TBD at review | TODO |
| CHC-109 | CHC:317 | Lazy widget getter/creator member. | TBD at review | TODO |
| CHC-110 | CHC:318 | Creation occurs only when field is absent. | TBD at review | TODO |
| CHC-111 | CHC:319-320 | Creation subscribes contents changed into controller emitter. | TBD at review | TODO |
| CHC-112 | CHC:322 | Getter returns persistent widget. | TBD at review | TODO |
| CHC-113 | CHC:325-332 | Public show delegates range/mode/source/focus. | TBD at review | TODO |
| CHC-114 | CHC:334-336 | Resize query uses widget value or false. | TBD at review | TODO |
| CHC-115 | CHC:410 | Override dispose member. | TBD at review | TODO |
| CHC-116 | CHC:411 | Disposal calls base first. | TBD at review | TODO |
| CHC-117 | CHC:412 | Disposal unhooks listeners. | TBD at review | TODO |
| CHC-118 | CHC:413 | Disposal retires listener store. | TBD at review | TODO |
| CHC-119 | CHC:414 | Disposal retires optional content widget. | TBD at review | TODO |
| CHC-120 | CHC:338-340 | Excluded sibling member `focusedHoverPartIndex` creates/gets the widget and forwards the query. | TBD at review | TODO |
| CHC-121 | CHC:342-344 | Excluded sibling member `doesHoverAtIndexSupportVerbosityAction` creates/gets the widget and forwards index/action. | TBD at review | TODO |
| CHC-122 | CHC:346-348 | Excluded sibling member `updateHoverVerbosityLevel` creates/gets the widget and forwards action/index/focus. | TBD at review | TODO |
| CHC-123 | CHC:350 | Excluded sibling member `focus`. | TBD at review | TODO |
| CHC-124 | CHC:351 | `focus` forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-125 | CHC:354 | Excluded sibling member `focusHoverPartWithIndex`. | TBD at review | TODO |
| CHC-126 | CHC:355 | Indexed focus forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-127 | CHC:358 | Excluded sibling member `scrollUp`. | TBD at review | TODO |
| CHC-128 | CHC:359 | Up-scroll forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-129 | CHC:362 | Excluded sibling member `scrollDown`. | TBD at review | TODO |
| CHC-130 | CHC:363 | Down-scroll forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-131 | CHC:366 | Excluded sibling member `scrollLeft`. | TBD at review | TODO |
| CHC-132 | CHC:367 | Left-scroll forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-133 | CHC:370 | Excluded sibling member `scrollRight`. | TBD at review | TODO |
| CHC-134 | CHC:371 | Right-scroll forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-135 | CHC:374 | Excluded sibling member `pageUp`. | TBD at review | TODO |
| CHC-136 | CHC:375 | Page-up forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-137 | CHC:378 | Excluded sibling member `pageDown`. | TBD at review | TODO |
| CHC-138 | CHC:379 | Page-down forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-139 | CHC:382 | Excluded sibling member `goToTop`. | TBD at review | TODO |
| CHC-140 | CHC:383 | Top navigation forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-141 | CHC:386 | Excluded sibling member `goToBottom`. | TBD at review | TODO |
| CHC-142 | CHC:387 | Bottom navigation forwards only when the optional content widget exists; absence is a no-op. | TBD at review | TODO |
| CHC-143 | CHC:390 | Excluded sibling member `getWidgetContent`. | TBD at review | TODO |
| CHC-144 | CHC:391 | Widget-content query forwards for an existing widget and returns `undefined` when absent. | TBD at review | TODO |
| CHC-145 | CHC:394 | Excluded sibling member `getAccessibleWidgetContent`. | TBD at review | TODO |
| CHC-146 | CHC:395 | Accessible-content query forwards for an existing widget and returns `undefined` when absent. | TBD at review | TODO |
| CHC-147 | CHC:398 | Excluded sibling member `getAccessibleWidgetContentAtIndex`. | TBD at review | TODO |
| CHC-148 | CHC:399 | Indexed accessible-content query forwards for an existing widget and returns `undefined` when absent. | TBD at review | TODO |
| CHC-149 | CHC:402 | Excluded sibling getter `isColorPickerVisible`. | TBD at review | TODO |
| CHC-150 | CHC:403 | Color-picker visibility forwards for an existing widget and returns `undefined` when absent. | TBD at review | TODO |
| CHC-151 | CHC:406 | Excluded sibling getter `isHoverVisible`. | TBD at review | TODO |
| CHC-152 | CHC:407 | Hover visibility forwards for an existing widget and returns `undefined` when absent. | TBD at review | TODO |
| CHW-001 | CHW:29 | Current reconciled hover result field starts null. | TBD at review | TODO |
| CHW-002 | CHW:30 | Mutable rendered-hover disposable is wrapper-owned. | TBD at review | TODO |
| CHW-003 | CHW:32 | Content-hover widget is wrapper-owned. | TBD at review | TODO |
| CHW-004 | CHW:33 | Participant array is wrapper-owned. | TBD at review | TODO |
| CHW-005 | CHW:34 | Hover operation is wrapper-owned. | TBD at review | TODO |
| CHW-006 | CHW:36 | Contents-changed emitter is owned. | TBD at review | TODO |
| CHW-007 | CHW:37 | Public event aliases emitter. | TBD at review | TODO |
| CHW-008 | CHW:40 | Editor dependency member. | TBD at review | TODO |
| CHW-009 | CHW:41 | Instantiation service member. | TBD at review | TODO |
| CHW-010 | CHW:42 | Keybinding service member. | TBD at review | TODO |
| CHW-011 | CHW:43 | Hover service member. | TBD at review | TODO |
| CHW-012 | CHW:44 | Clipboard service member. | TBD at review | TODO |
| CHW-013 | CHW:46 | Constructor establishes disposable base. | TBD at review | TODO |
| CHW-014 | CHW:47 | Content widget is created and registered. | TBD at review | TODO |
| CHW-015 | CHW:48 | Participants initialize before operation. | TBD at review | TODO |
| CHW-016 | CHW:49 | Operation/computer is created and registered. | TBD at review | TODO |
| CHW-017 | CHW:50 | Listeners register after owned state exists. | TBD at review | TODO |
| CHW-018 | CHW:53 | Participant initialization member. | TBD at review | TODO |
| CHW-019 | CHW:55 | Every registered participant constructor is visited. | TBD at review | TODO |
| CHW-020 | CHW:56-58 | Each participant is instantiated for editor then pushed. | TBD at review | TODO |
| CHW-021 | CHW:59 | Participants sort ascending by exact comparator arithmetic `p1.hoverOrdinal - p2.hoverOrdinal`. | TBD at review | TODO |
| CHW-022 | CHW:60-62 | Widget resize forwards to optional participant handlers. | TBD at review | TODO |
| CHW-023 | CHW:63-65 | Widget scroll forwards to optional participant handlers. | TBD at review | TODO |
| CHW-024 | CHW:66-68 | Widget content change forwards to optional handlers. | TBD at review | TODO |
| CHW-025 | CHW:69 | Initialization returns ordered participants. | TBD at review | TODO |
| CHW-026 | CHW:72 | Listener-registration member. | TBD at review | TODO |
| CHW-027 | CHW:73-76 | Operation result subscription owns reconciliation entry. | TBD at review | TODO |
| CHW-028 | CHW:74 | Loading flag chooses augmented messages vs raw values. | TBD at review | TODO |
| CHW-029 | CHW:75 | Result wraps messages/completeness/options before reconciliation. | TBD at review | TODO |
| CHW-030 | CHW:78-82 | Widget keydown DOM listener is disposable-owned. | TBD at review | TODO |
| CHW-031 | CHW:79-81 | Escape hides. | TBD at review | TODO |
| CHW-032 | CHW:83-85 | Widget mouseleave listener delegates. | TBD at review | TODO |
| CHW-033 | CHW:86-90 | Tokenization registry listener is owned. | TBD at review | TODO |
| CHW-034 | CHW:87-89 | Existing position and result rerender same result. | TBD at review | TODO |
| CHW-035 | CHW:91-93 | Widget content event fires wrapper event. | TBD at review | TODO |
| CHW-036 | CHW:99-105 | Start-or-update member consumes anchor/mode/source/focus/mouse. | TBD at review | TODO |
| CHW-037 | CHW:106 | Visibility requires widget position and current result. | TBD at review | TODO |
| CHW-038 | CHW:107-113 | Invisible hover enters the nested anchor/no-anchor decision; visible hover continues to sticky reconciliation. | TBD at review | TODO |
| CHW-039 | CHW:108-111 | Invisible with anchor starts operation and returns true. | TBD at review | TODO |
| CHW-040 | CHW:112 | Invisible without anchor returns false. | TBD at review | TODO |
| CHW-041 | CHW:114-116 | Sticky and mouse-getting-closer facts combine. | TBD at review | TODO |
| CHW-042 | CHW:119-124 | Closer branch preserves visible result. | TBD at review | TODO |
| CHW-043 | CHW:120-122 | Closer with anchor starts update with insist=true. | TBD at review | TODO |
| CHW-044 | CHW:123 | Closer branch returns true even without anchor. | TBD at review | TODO |
| CHW-045 | CHW:126-129 | No anchor clears result and returns false. | TBD at review | TODO |
| CHW-046 | CHW:131-134 | Equal current anchor returns true without restart. | TBD at review | TODO |
| CHW-047 | CHW:136 | Compatibility asks new anchor to adopt prior visible hover. | TBD at review | TODO |
| CHW-048 | CHW:137-141 | Incompatible anchor clears result then starts fresh. | TBD at review | TODO |
| CHW-049 | CHW:144-146 | Compatible-anchor filtering applies only while `_currentResult` remains non-null; the null branch is a no-op. | TBD at review | TODO |
| CHW-050 | CHW:147-148 | Compatible path starts new operation and returns true. | TBD at review | TODO |
| CHW-051 | CHW:151 | Operation-start-if-necessary member. | TBD at review | TODO |
| CHW-052 | CHW:152-155 | Same operation anchor returns early. | TBD at review | TODO |
| CHW-053 | CHW:156 | Different anchor cancels previous operation first. | TBD at review | TODO |
| CHW-054 | CHW:157-162 | Options capture anchor/source/focus/insist. | TBD at review | TODO |
| CHW-055 | CHW:163 | Operation starts with supplied mode/options. | TBD at review | TODO |
| CHW-056 | CHW:166 | Current-result setter member. | TBD at review | TODO |
| CHW-057 | CHW:168-171 | Identical result object returns early. | TBD at review | TODO |
| CHW-058 | CHW:172-175 | Non-null empty result normalizes to null. | TBD at review | TODO |
| CHW-059 | CHW:176 | Normalized result replaces current field. | TBD at review | TODO |
| CHW-060 | CHW:177-181 | Non-null calls show boundary; null calls hide boundary. | TBD at review | TODO |
| CHW-061 | CHW:184 | Loading-message augmentation member. | TBD at review | TODO |
| CHW-062 | CHW:185 | Participants are checked in order. | TBD at review | TODO |
| CHW-063 | CHW:186-188 | Missing loading-message factory continues. | TBD at review | TODO |
| CHW-064 | CHW:189-192 | Null loading message continues. | TBD at review | TODO |
| CHW-065 | CHW:193 | First message appends to copied result and returns. | TBD at review | TODO |
| CHW-066 | CHW:195 | No participant message returns original value. | TBD at review | TODO |
| CHW-067 | CHW:198 | Result reconciliation member. | TBD at review | TODO |
| CHW-068 | CHW:199 | Previous visible complete result is detected. | TBD at review | TODO |
| CHW-069 | CHW:200-202 | Without a previous visible complete result, the incoming result is applied immediately and control still falls through. | TBD at review | TODO |
| CHW-070 | CHW:204-208 | An incomplete result returns after that possible apply; it preserves an old complete hover only when one existed. | TBD at review | TODO |
| CHW-071 | CHW:209-215 | Empty complete plus insist returns; it preserves an old hover only when the previous-visible-complete precondition held, otherwise the earlier apply already normalized the empty result to null. | TBD at review | TODO |
| CHW-072 | CHW:216 | Every remaining complete result calls `_setCurrentResult`; after the earlier fall-through that call can be an identity no-op. | TBD at review | TODO |
| CHW-073 | CHW:249 | `showsOrWillShow` member. | TBD at review | TODO |
| CHW-074 | CHW:250-253 | Resizing returns true without recomputation. | TBD at review | TODO |
| CHW-075 | CHW:254-256 | Code-action widget hit returns true. | TBD at review | TODO |
| CHW-076 | CHW:257 | Anchor candidates are computed. | TBD at review | TODO |
| CHW-077 | CHW:258-261 | No candidate delegates null delayed mouse update. | TBD at review | TODO |
| CHW-078 | CHW:262-263 | First highest-priority candidate delegates delayed mouse update. | TBD at review | TODO |
| CHW-079 | CHW:266 | Anchor-candidate finder member. | TBD at review | TODO |
| CHW-080 | CHW:268-271 | Participant without suggester continues. | TBD at review | TODO |
| CHW-081 | CHW:272-275 | Null participant suggestion continues. | TBD at review | TODO |
| CHW-082 | CHW:276 | Valid participant suggestion is pushed. | TBD at review | TODO |
| CHW-083 | CHW:280-283 | Content-text target adds priority `0` range anchor. | TBD at review | TODO |
| CHW-084 | CHW:284-285 | Content-empty threshold is halfwidth character width divided by `2`. | TBD at review | TODO |
| CHW-085 | CHW:287-289 | Empty target qualifies only within lines, numeric distance, distance below epsilon. | TBD at review | TODO |
| CHW-086 | CHW:290-292 | Failed empty-target qualification breaks that switch arm. | TBD at review | TODO |
| CHW-087 | CHW:293-294 | Qualified empty target adds priority `0` range anchor. | TBD at review | TODO |
| CHW-088 | CHW:297 | Candidates sort descending by priority. | TBD at review | TODO |
| CHW-089 | CHW:298 | Finder returns sorted candidates. | TBD at review | TODO |
| CHW-090 | CHW:301 | Code-action hit-test member. | TBD at review | TODO |
| CHW-091 | CHW:302-306 | Element with closest `.action-widget` returns true; otherwise false. | TBD at review | TODO |
| CHW-092 | CHW:309 | Mouse-leave member. | TBD at review | TODO |
| CHW-093 | CHW:310-314 | Missing editor DOM or outside position hides; a mouseleave point still inside the editor is a no-op. | TBD at review | TODO |
| CHW-094 | CHW:317-319 | Range start builds priority `0` anchor with undefined mouse coordinates. | TBD at review | TODO |
| CHW-095 | CHW:398 | Public hide member. | TBD at review | TODO |
| CHW-096 | CHW:399-400 | Hide cancels operation before clearing result. | TBD at review | TODO |
| CHW-097 | CHW:279-296 | Implicit switch default: every other mouse target type adds no built-in range anchor. | TBD at review | TODO |
| CHW-098 | CHW:219-227 | Excluded sibling member `_showHover` creates context, replaces the rendered-hover disposable, then decides whether to show it. | TBD at review | TODO |
| CHW-099 | CHW:222-226 | Rendered DOM with children is shown; an empty rendered DOM clears the rendered-hover disposable. | TBD at review | TODO |
| CHW-100 | CHW:229-232 | Excluded sibling member `_hideHover` hides the widget before visiting participants in order. | TBD at review | TODO |
| CHW-101 | CHW:231 | Each participant's optional `handleHide` is called when present and skipped when absent. | TBD at review | TODO |
| CHW-102 | CHW:234-246 | Excluded sibling member `_getHoverContext` returns exact hide, contents-change, minimum-dimensions, and focus delegates. | TBD at review | TODO |
| CHW-103 | CHW:321-327 | Excluded sibling member `getWidgetContent` reads the content-widget DOM node and returns its text on the surviving path. | TBD at review | TODO |
| CHW-104 | CHW:323-325 | Falsy `textContent` returns `undefined` before the final text return. | TBD at review | TODO |
| CHW-105 | CHW:329-331 | Excluded sibling async member `updateHoverVerbosityLevel`. | TBD at review | TODO |
| CHW-106 | CHW:330 | Verbosity update forwards only when a rendered hover exists; absence is a no-op. | TBD at review | TODO |
| CHW-107 | CHW:333-335 | Excluded sibling member `doesHoverAtIndexSupportVerbosityAction`. | TBD at review | TODO |
| CHW-108 | CHW:334 | Optional rendered-hover support is forwarded; a nullish result falls back to `false`. | TBD at review | TODO |
| CHW-109 | CHW:337-339 | Excluded sibling member `getAccessibleWidgetContent`. | TBD at review | TODO |
| CHW-110 | CHW:338 | Accessible-content lookup forwards only when a rendered hover exists and otherwise returns `undefined`. | TBD at review | TODO |
| CHW-111 | CHW:341-343 | Excluded sibling member `getAccessibleWidgetContentAtIndex`. | TBD at review | TODO |
| CHW-112 | CHW:342 | Indexed accessible-content lookup forwards only when a rendered hover exists and otherwise returns `undefined`. | TBD at review | TODO |
| CHW-113 | CHW:345-347 | Excluded sibling member `focusedHoverPartIndex`. | TBD at review | TODO |
| CHW-114 | CHW:346 | Optional rendered-hover focused index is returned when present; a nullish result takes the fallback. | TBD at review | TODO |
| CHW-115 | CHW:346 | Focused-index fallback magic value is `-1`. | TBD at review | TODO |
| CHW-116 | CHW:349-351 | Excluded sibling member `containsNode`. | TBD at review | TODO |
| CHW-117 | CHW:350 | A present node is tested against the widget DOM; a nullish node returns `false`. | TBD at review | TODO |
| CHW-118 | CHW:353-360 | Excluded sibling member `focus`. | TBD at review | TODO |
| CHW-119 | CHW:354 | Hover-part count is read only when a rendered hover exists; absence yields `undefined`. | TBD at review | TODO |
| CHW-120 | CHW:355-359 | A singleton rendered hover focuses its part and returns early; every other count focuses the widget. | TBD at review | TODO |
| CHW-121 | CHW:355 | Singleton hover-part count magic value is `1`. | TBD at review | TODO |
| CHW-122 | CHW:356 | Singleton focus uses part-index magic value `0`. | TBD at review | TODO |
| CHW-123 | CHW:362-364 | Excluded sibling member `focusHoverPartWithIndex`. | TBD at review | TODO |
| CHW-124 | CHW:363 | Indexed part focus forwards only when a rendered hover exists; absence is a no-op. | TBD at review | TODO |
| CHW-125 | CHW:366-368 | Excluded sibling member `scrollUp` forwards to the content widget. | TBD at review | TODO |
| CHW-126 | CHW:370-372 | Excluded sibling member `scrollDown` forwards to the content widget. | TBD at review | TODO |
| CHW-127 | CHW:374-376 | Excluded sibling member `scrollLeft` forwards to the content widget. | TBD at review | TODO |
| CHW-128 | CHW:378-380 | Excluded sibling member `scrollRight` forwards to the content widget. | TBD at review | TODO |
| CHW-129 | CHW:382-384 | Excluded sibling member `pageUp` forwards to the content widget. | TBD at review | TODO |
| CHW-130 | CHW:386-388 | Excluded sibling member `pageDown` forwards to the content widget. | TBD at review | TODO |
| CHW-131 | CHW:390-392 | Excluded sibling member `goToTop` forwards to the content widget. | TBD at review | TODO |
| CHW-132 | CHW:394-396 | Excluded sibling member `goToBottom` forwards to the content widget. | TBD at review | TODO |
| CHW-133 | CHW:403-405 | Excluded sibling member `getDomNode` forwards to the content widget. | TBD at review | TODO |
| CHW-134 | CHW:407-409 | Excluded sibling getter `isColorPickerVisible`. | TBD at review | TODO |
| CHW-135 | CHW:408 | Optional rendered-hover color-picker visibility is forwarded; a nullish result falls back to `false`. | TBD at review | TODO |
| CHW-136 | CHW:411-413 | Excluded sibling getter `isVisibleFromKeyboard` forwards to the content widget. | TBD at review | TODO |
| CHW-137 | CHW:415-417 | Excluded sibling getter `isVisible` forwards to the content widget. | TBD at review | TODO |
| CHW-138 | CHW:419-421 | Excluded sibling getter `isFocused` forwards to the content widget. | TBD at review | TODO |
| CHW-139 | CHW:423-425 | Excluded sibling getter `isResizing` forwards to the content widget. | TBD at review | TODO |
| CHW-140 | CHW:427-429 | Excluded sibling getter `widget` returns the content widget. | TBD at review | TODO |
| HOP-001 | HOP:18 | Optional `IHoverComputer.computeAsync(args, token)` receives the cancellation token when invoked after half delay. | TBD at review | TODO |
| HOP-002 | HOP:22 | Optional `IHoverComputer.computeSync(args)` is invoked after the full delay. | TBD at review | TODO |
| HOP-003 | HOP:25-26 | Operation state `Idle` has implicit value `0`. | TBD at review | TODO |
| HOP-004 | HOP:27 | Operation state `FirstWait` has implicit value `1`. | TBD at review | TODO |
| HOP-005 | HOP:28 | Operation state `SecondWait` has implicit value `2`. | TBD at review | TODO |
| HOP-006 | HOP:29 | Operation state `WaitingForAsync = 3`. | TBD at review | TODO |
| HOP-007 | HOP:30 | Operation state `WaitingForAsyncShowingLoading = 4`. | TBD at review | TODO |
| HOP-008 | HOP:33-34 | Start mode `Delayed = 0`. | TBD at review | TODO |
| HOP-009 | HOP:35 | Start mode `Immediate = 1`. | TBD at review | TODO |
| HOP-010 | HOP:38-39 | Start source `Mouse = 0`. | TBD at review | TODO |
| HOP-011 | HOP:40 | Start source `Click = 1`. | TBD at review | TODO |
| HOP-012 | HOP:41 | Start source `Keyboard = 2`. | TBD at review | TODO |
| HOP-013 | HOP:46 | `HoverResult.value` member. | TBD at review | TODO |
| HOP-014 | HOP:47 | `HoverResult.isComplete` member. | TBD at review | TODO |
| HOP-015 | HOP:48 | `HoverResult.hasLoadingMessage` member. | TBD at review | TODO |
| HOP-016 | HOP:49 | `HoverResult.options` member. | TBD at review | TODO |
| HOP-017 | HOP:44-50 | `HoverResult` constructor retains all four facts. | TBD at review | TODO |
| HOP-018 | HOP:65 | Owned result emitter. | TBD at review | TODO |
| HOP-019 | HOP:66 | Public result event alias. | TBD at review | TODO |
| HOP-020 | HOP:68 | Owned async-computation debouncer starts at `0`. | TBD at review | TODO |
| HOP-021 | HOP:69 | Owned sync-computation debouncer starts at `0`. | TBD at review | TODO |
| HOP-022 | HOP:70 | Owned loading-message debouncer starts at `0`. | TBD at review | TODO |
| HOP-023 | HOP:72 | State starts `Idle`. | TBD at review | TODO |
| HOP-024 | HOP:73 | Cancelable async iterable starts null. | TBD at review | TODO |
| HOP-025 | HOP:74 | Async-done flag starts false. | TBD at review | TODO |
| HOP-026 | HOP:75 | Accumulated result starts empty. | TBD at review | TODO |
| HOP-027 | HOP:76 | Current options start undefined. | TBD at review | TODO |
| HOP-028 | HOP:79 | Editor dependency member. | TBD at review | TODO |
| HOP-029 | HOP:80 | Computer dependency member. | TBD at review | TODO |
| HOP-030 | HOP:78-83 | Constructor establishes disposable ownership. | TBD at review | TODO |
| HOP-031 | HOP:85 | Override dispose member. | TBD at review | TODO |
| HOP-032 | HOP:86-89 | Dispose cancels/nulls an existing iterable; an absent iterable skips both operations. | TBD at review | TODO |
| HOP-033 | HOP:90-91 | Dispose clears options before base disposal. | TBD at review | TODO |
| HOP-034 | HOP:94-96 | Hover time reads configured delay. | TBD at review | TODO |
| HOP-035 | HOP:98-100 | First wait is delay divided by `2`. | TBD at review | TODO |
| HOP-036 | HOP:102-104 | Second wait is delay minus first wait. | TBD at review | TODO |
| HOP-037 | HOP:106-108 | Loading time is `3 * hoverTime`. | TBD at review | TODO |
| HOP-038 | HOP:110-114 | `_setState` assigns options first, state second, then fires the result. | TBD at review | TODO |
| HOP-039 | HOP:116-119 | Async trigger enters `SecondWait` and schedules sync remainder. | TBD at review | TODO |
| HOP-040 | HOP:120 | Async computer presence gates iterable creation. | TBD at review | TODO |
| HOP-041 | HOP:121-123 | Present async computer resets `_asyncIterableDone=false`, then creates a fresh cancelable iterable that propagates its token to the computer. | TBD at review | TODO |
| HOP-042 | HOP:124-141 | Detached async IIFE consumes the producer with `for await` through its catch boundary. | TBD at review | TODO |
| HOP-043 | HOP:127-130 | Truthy item mutates shared result and fires; falsy item is ignored, with no token/options/operation-identity guard before mutation. | TBD at review | TODO |
| HOP-044 | HOP:132 | Iteration completion sets async-done true with no token/options/operation-identity guard. | TBD at review | TODO |
| HOP-045 | HOP:134-136 | Waiting states transition to `Idle` using captured options; non-waiting states do not transition. | TBD at review | TODO |
| HOP-046 | HOP:138-140 | Async failure is contained by `onUnexpectedError`. | TBD at review | TODO |
| HOP-047 | HOP:143-145 | Missing async computer marks async done immediately. | TBD at review | TODO |
| HOP-048 | HOP:148 | Sync trigger member. | TBD at review | TODO |
| HOP-049 | HOP:149-151 | Present sync computer concatenates results; missing sync computer preserves accumulated result. | TBD at review | TODO |
| HOP-050 | HOP:152 | Post-sync state is `Idle` if async done, otherwise `WaitingForAsync`. | TBD at review | TODO |
| HOP-051 | HOP:155 | Loading trigger member. | TBD at review | TODO |
| HOP-052 | HOP:156-158 | Only `WaitingForAsync` enters loading state. | TBD at review | TODO |
| HOP-053 | HOP:161 | Result-fire member. | TBD at review | TODO |
| HOP-054 | HOP:162-165 | First/second wait returns without emission. | TBD at review | TODO |
| HOP-055 | HOP:166 | Completeness means state `Idle`. | TBD at review | TODO |
| HOP-056 | HOP:167 | Loading flag means loading-wait state. | TBD at review | TODO |
| HOP-057 | HOP:168 | Emission snapshots accumulated results with `slice(0)`, constructs `HoverResult` with completeness/loading/options, then fires `_onResult`. | TBD at review | TODO |
| HOP-058 | HOP:171 | Public start member. | TBD at review | TODO |
| HOP-059 | HOP:172 | Delayed mode branch. | TBD at review | TODO |
| HOP-060 | HOP:173-177 | Delayed start acts only from `Idle`; other states no-op. | TBD at review | TODO |
| HOP-061 | HOP:174-176 | Delayed start enters first wait and schedules async/loading timers. | TBD at review | TODO |
| HOP-062 | HOP:178-184 | Bare non-`Delayed` branch with operation state `Idle`. | TBD at review | TODO |
| HOP-063 | HOP:181-183 | Immediate order: trigger async, cancel sync timer, trigger sync. | TBD at review | TODO |
| HOP-064 | HOP:185-188 | Bare non-`Delayed` branch with operation state `SecondWait`. | TBD at review | TODO |
| HOP-065 | HOP:186-187 | Second-wait immediate start cancels sync timer then triggers sync. | TBD at review | TODO |
| HOP-066 | HOP:179-189 | Every other state in the bare non-`Delayed` branch has no switch arm and no-ops; runtime values other than enum `Immediate` enter the same branch. | TBD at review | TODO |
| HOP-067 | HOP:193 | Public cancel member. | TBD at review | TODO |
| HOP-068 | HOP:194-196 | Cancel retires async, sync, and loading schedulers. | TBD at review | TODO |
| HOP-069 | HOP:197-200 | Cancel retires/nulls an active iterable; absent iterable skips both operations. | TBD at review | TODO |
| HOP-070 | HOP:201 | Cancel clears accumulated result. | TBD at review | TODO |
| HOP-071 | HOP:202 | Cancel clears options. | TBD at review | TODO |
| HOP-072 | HOP:203 | Cancel returns state to `Idle`. | TBD at review | TODO |
| HOP-073 | HOP:206-208 | Options getter returns current optional options. | TBD at review | TODO |
| HOP-074 | HOP:213 | Debouncer owns one run-once scheduler. | TBD at review | TODO |
| HOP-075 | HOP:215 | Debouncer retains latest options. | TBD at review | TODO |
| HOP-076 | HOP:217-220 | Constructor calls `super()` before registering a scheduler whose closure reads the latest mutable `_options` at execution, with the supplied default delay. | TBD at review | TODO |
| HOP-077 | HOP:222-225 | Schedule stores options then schedules requested delay. | TBD at review | TODO |
| HOP-078 | HOP:227-229 | Cancel delegates scheduler cancellation. | TBD at review | TODO |
| CHCMP-001 | CHCMP:15 | Options `shouldFocus` member. | TBD at review | TODO |
| CHCMP-002 | CHCMP:16 | Options `anchor` member. | TBD at review | TODO |
| CHCMP-003 | CHCMP:17 | Options `source` member. | TBD at review | TODO |
| CHCMP-004 | CHCMP:18 | Options `insistOnKeepingHoverVisible` member. | TBD at review | TODO |
| CHCMP-005 | CHCMP:24 | Editor dependency member. | TBD at review | TODO |
| CHCMP-006 | CHCMP:25 | Ordered participant dependency member. | TBD at review | TODO |
| CHCMP-007 | CHCMP:23-27 | Constructor retains editor and participants. | TBD at review | TODO |
| CHCMP-008 | CHCMP:29 | Static line-decoration selector member. | TBD at review | TODO |
| CHCMP-009 | CHCMP:30-32 | Non-range anchor without marker support returns empty. | TBD at review | TODO |
| CHCMP-010 | CHCMP:34-35 | Selector captures model and anchor start line. | TBD at review | TODO |
| CHCMP-011 | CHCMP:37-40 | Line beyond model line count returns empty. | TBD at review | TODO |
| CHCMP-012 | CHCMP:42 | Maximum column is captured for cross-line ranges. | TBD at review | TODO |
| CHCMP-013 | CHCMP:44 | Line decorations are filtered. | TBD at review | TODO |
| CHCMP-014 | CHCMP:45-47 | Whole-line decoration returns true immediately. | TBD at review | TODO |
| CHCMP-015 | CHCMP:49 | Start column is same-line start or `1`. | TBD at review | TODO |
| CHCMP-016 | CHCMP:50 | End column is same-line end or max column. | TBD at review | TODO |
| CHCMP-017 | CHCMP:52 | `showIfCollapsed` selects relaxed containment. | TBD at review | TODO |
| CHCMP-018 | CHCMP:54-56 | Relaxed check rejects beyond anchor plus/minus `1`. | TBD at review | TODO |
| CHCMP-019 | CHCMP:57-60 | Ordinary check rejects strict noncontainment. | TBD at review | TODO |
| CHCMP-020 | CHCMP:63 | Surviving decoration returns true. | TBD at review | TODO |
| CHCMP-021 | CHCMP:67 | Async computation member receives options/token. | TBD at review | TODO |
| CHCMP-022 | CHCMP:70-72 | Missing editor model or anchor returns empty producer. | TBD at review | TODO |
| CHCMP-023 | CHCMP:74 | Async path computes line decorations once. | TBD at review | TODO |
| CHCMP-024 | CHCMP:76-77,82-83 | Participants are mapped in array order, then all producers merge concurrently and emitted items interleave by arrival. | TBD at review | TODO |
| CHCMP-025 | CHCMP:78-80 | Participant without async member contributes empty producer. | TBD at review | TODO |
| CHCMP-026 | CHCMP:81 | Participant async call receives anchor, decorations, source, token. | TBD at review | TODO |
| CHCMP-027 | CHCMP:86 | Synchronous computation member. | TBD at review | TODO |
| CHCMP-028 | CHCMP:87-89 | Missing editor model returns empty. | TBD at review | TODO |
| CHCMP-029 | CHCMP:91-92 | Sync path captures anchor and decorations. | TBD at review | TODO |
| CHCMP-030 | CHCMP:94-97 | Sync accumulation starts at `[]` and concatenates participant results in participant order. | TBD at review | TODO |
| CHCMP-031 | CHCMP:99 | Final sync result coalesces nullish entries. | TBD at review | TODO |
| GHR-001 | GHR:18 | Provider-result `provider` member. | TBD at review | TODO |
| GHR-002 | GHR:19 | Provider-result `hover` member. | TBD at review | TODO |
| GHR-003 | GHR:20 | Provider-result `ordinal` member. | TBD at review | TODO |
| GHR-004 | GHR:16-21 | Constructor retains provider, hover, ordinal. | TBD at review | TODO |
| GHR-005 | GHR:27 | `executeProvider` member. | TBD at review | TODO |
| GHR-006 | GHR:28-30 | Provider invocation receives model, position, token; neither a pre-invocation nor post-await cancellation check exists. | TBD at review | TODO |
| GHR-007 | GHR:30 | Returned-promise rejection is contained as undefined; a synchronous provider throw rejects `executeProvider` itself. | TBD at review | TODO |
| GHR-008 | GHR:31-33 | Missing or invalid result returns undefined. | TBD at review | TODO |
| GHR-009 | GHR:34 | Valid result constructs provider result with ordinal. | TBD at review | TODO |
| GHR-010 | GHR:37 | Async-iterable member defaults `recursive=false`. | TBD at review | TODO |
| GHR-011 | GHR:38 | Registry providers are ordered for model/recursive flag. | TBD at review | TODO |
| GHR-012 | GHR:39 | `map` eagerly invokes all ordered providers before iterable consumption, in registry order, and each provider index becomes its stable ordinal. | TBD at review | TODO |
| GHR-013 | GHR:40 | Promise producer yields in resolution order. | TBD at review | TODO |
| GHR-014 | GHR:40 | Undefined failures are coalesced out. | TBD at review | TODO |
| GHR-015 | GHR:43 | `getHoversPromise` member defaults `recursive=false`. | TBD at review | TODO |
| GHR-016 | GHR:44 | Output array starts empty. | TBD at review | TODO |
| GHR-017 | GHR:45 | Async iterable is consumed to completion. | TBD at review | TODO |
| GHR-018 | GHR:46 | Each valid item contributes its hover. | TBD at review | TODO |
| GHR-019 | GHR:48 | Collected hovers return in resolution order. | TBD at review | TODO |
| GHR-020 | GHR:51-54 | Command `_executeHoverProvider` looks up the language-features service, then delegates registry/model/position with `CancellationToken.None`. | TBD at review | TODO |
| GHR-021 | GHR:56-59 | Command `_executeHoverProvider_recursive` performs the same service lookup/delegation with `None` and recursive `true`. | TBD at review | TODO |
| GHR-022 | GHR:61 | Hover validity member. | TBD at review | TODO |
| GHR-023 | GHR:62 | Only `undefined` range is rejected by this predicate; a runtime `null` range passes. | TBD at review | TODO |
| GHR-024 | GHR:63 | Contents must be defined, truthy, and nonempty. | TBD at review | TODO |
| GHR-025 | GHR:64 | Validity is range AND content predicates. | TBD at review | TODO |
| HTY-001 | HTY:21 | Hover part retains owner participant. | TBD at review | TODO |
| HTY-002 | HTY:25 | Hover part retains applicable range. | TBD at review | TODO |
| HTY-003 | HTY:30 | Optional force-show-at-range member. | TBD at review | TODO |
| HTY-004 | HTY:35 | Optional before-content ordering member. | TBD at review | TODO |
| HTY-005 | HTY:39 | Part validity member consumes new anchor. | TBD at review | TODO |
| HTY-006 | HTY:42-43 | Anchor type `Range = 1`. | TBD at review | TODO |
| HTY-007 | HTY:44 | Anchor type `ForeignElement = 2`. | TBD at review | TODO |
| HTY-008 | HTY:48 | Range anchor constant type. | TBD at review | TODO |
| HTY-009 | HTY:50 | Range anchor priority member. | TBD at review | TODO |
| HTY-010 | HTY:51 | Range anchor range member. | TBD at review | TODO |
| HTY-011 | HTY:52 | Range anchor initial mouse X member. | TBD at review | TODO |
| HTY-012 | HTY:53 | Range anchor initial mouse Y member. | TBD at review | TODO |
| HTY-013 | HTY:49-55 | Range anchor constructor retains fields. | TBD at review | TODO |
| HTY-014 | HTY:56-58 | Range equality requires range type and equal range. | TBD at review | TODO |
| HTY-015 | HTY:59-61 | Range adoption requires a prior range anchor and compares `showAtPosition.lineNumber` with the new anchor's start line; it does not compare the two anchor ranges. | TBD at review | TODO |
| HTY-016 | HTY:65 | Foreign anchor constant type. | TBD at review | TODO |
| HTY-017 | HTY:67 | Foreign anchor priority member. | TBD at review | TODO |
| HTY-018 | HTY:68 | Foreign anchor owner member. | TBD at review | TODO |
| HTY-019 | HTY:69 | Foreign anchor range member. | TBD at review | TODO |
| HTY-020 | HTY:70 | Foreign anchor initial mouse X member. | TBD at review | TODO |
| HTY-021 | HTY:71 | Foreign anchor initial mouse Y member. | TBD at review | TODO |
| HTY-022 | HTY:72 | Foreign anchor marker-hover support member. | TBD at review | TODO |
| HTY-023 | HTY:66-74 | Foreign anchor constructor retains fields. | TBD at review | TODO |
| HTY-024 | HTY:75-77 | Foreign equality requires foreign type and same owner identity. | TBD at review | TODO |
| HTY-025 | HTY:78-80 | Foreign adoption requires prior foreign anchor and same owner. | TBD at review | TODO |
| HTY-026 | HTY:83 | Hover anchor union is range or foreign. | TBD at review | TODO |
| HTY-027 | HTY:162 | Participant hover ordinal member. | TBD at review | TODO |
| HTY-028 | HTY:164 | Optional anchor-suggestion member. | TBD at review | TODO |
| HTY-029 | HTY:165 | Synchronous computation member. | TBD at review | TODO |
| HTY-030 | HTY:166 | Optional async computation receives anchor, line decorations, source, then cancellation token. | TBD at review | TODO |
| HTY-031 | HTY:167 | Optional loading-message member. | TBD at review | TODO |
| HTY-032 | HTY:176 | Participant constructor signature consumes editor. | TBD at review | TODO |
| HTY-033 | HTY:180 | Registry owns a participant-constructor array initialized to empty. | TBD at review | TODO |
| HTY-034 | HTY:182-184 | Register appends constructor. | TBD at review | TODO |
| HTY-035 | HTY:186-188 | `getAll` returns the mutable backing constructor array itself, not a copy. | TBD at review | TODO |
| HTY-036 | HTY:198 | Widget `showsOrWillShow` member. | TBD at review | TODO |
| HTY-037 | HTY:203 | Widget `hide` member. | TBD at review | TODO |
| HTY-038 | HTY:86 | Excluded `IEditorHoverStatusBar.addAction` member. | TBD at review | TODO |
| HTY-039 | HTY:87 | Excluded `IEditorHoverStatusBar.append` member. | TBD at review | TODO |
| HTY-040 | HTY:91 | Excluded `IEditorHoverAction.setEnabled` member. | TBD at review | TODO |
| HTY-041 | HTY:95 | Excluded `IEditorHoverColorPickerWidget.layout` member. | TBD at review | TODO |
| HTY-042 | HTY:102 | Excluded `IEditorHoverContext.onContentsChanged` member. | TBD at review | TODO |
| HTY-043 | HTY:106 | Excluded `IEditorHoverContext.setMinimumDimensions` member. | TBD at review | TODO |
| HTY-044 | HTY:110 | Excluded `IEditorHoverContext.hide` member. | TBD at review | TODO |
| HTY-045 | HTY:114 | Excluded `IEditorHoverContext.focus` member. | TBD at review | TODO |
| HTY-046 | HTY:121 | Excluded `IEditorHoverRenderContext.fragment` member. | TBD at review | TODO |
| HTY-047 | HTY:125 | Excluded `IEditorHoverRenderContext.statusBar` member. | TBD at review | TODO |
| HTY-048 | HTY:132 | Excluded `IRenderedHoverPart.hoverPart` member. | TBD at review | TODO |
| HTY-049 | HTY:136 | Excluded `IRenderedHoverPart.hoverElement` member. | TBD at review | TODO |
| HTY-050 | HTY:143 | Excluded `IRenderedHoverParts.renderedHoverParts` member. | TBD at review | TODO |
| HTY-051 | HTY:151 | Excluded `RenderedHoverParts.renderedHoverParts` parameter-property. | TBD at review | TODO |
| HTY-052 | HTY:151 | Excluded optional `RenderedHoverParts.disposables` parameter-property. | TBD at review | TODO |
| HTY-053 | HTY:151 | Excluded `RenderedHoverParts` constructor retains both parameter-properties. | TBD at review | TODO |
| HTY-054 | HTY:153-158 | Excluded `RenderedHoverParts.dispose` visits and disposes parts in array order before the aggregate-disposable check. | TBD at review | TODO |
| HTY-055 | HTY:157 | Present aggregate disposable is retired after all parts; absence is a no-op. | TBD at review | TODO |
| HTY-056 | HTY:163 | Excluded optional participant `hideCopyButton` member. | TBD at review | TODO |
| HTY-057 | HTY:168 | Excluded participant `renderHoverParts` member. | TBD at review | TODO |
| HTY-058 | HTY:169 | Excluded participant `getAccessibleContent` member. | TBD at review | TODO |
| HTY-059 | HTY:170 | Excluded optional participant `handleResize` member. | TBD at review | TODO |
| HTY-060 | HTY:171 | Excluded optional participant `handleHide` member. | TBD at review | TODO |
| HTY-061 | HTY:172 | Excluded optional participant `handleContentsChanged` member. | TBD at review | TODO |
| HTY-062 | HTY:173 | Excluded optional participant `handleScroll` member. | TBD at review | TODO |
| HTY-063 | HTY:178-190 | Exported `HoverParticipantRegistry` singleton constant constructs the anonymous registry class instance. | TBD at review | TODO |
| TMV-001 | TMV:123 | Module model-identity counter `MODEL_ID` starts `0`. | TBD at review | TODO |
| TMV-002 | TMV:250 | Public `id` field retains physical model-instance ID text. | TBD at review | TODO |
| TMV-003 | TMV:252 | Private `_associatedResource` field retains the model URI. | TBD at review | TODO |
| TMV-004 | TMV:262 | Private monotonic `_versionId` field. | TBD at review | TODO |
| TMV-005 | TMV:263-266 | Private `_alternativeVersionId` may decrease or repeat through undo/redo. | TBD at review | TODO |
| TMV-006 | TMV:318-325,370-371 | Constructor identity slice executes `MODEL_ID++`, assigns `$model` plus the new counter (first ID `$model1`), chooses the resource, then later initializes both version fields to exactly `1`. | TBD at review | TODO |
| TMV-007 | TMV:309,321-323 | Null or undefined resource creates exactly `inmemory://model/` plus current `MODEL_ID`. | TBD at review | TODO |
| TMV-008 | TMV:323-325 | Supplied resource is retained exactly. | TBD at review | TODO |
| TMV-009 | TMV:671-673 | Public `uri` getter returns the associated resource without a disposed guard. | TBD at review | TODO |
| TMV-010 | TMV:737-740 | `getVersionId` asserts not disposed, then returns internal version. | TBD at review | TODO |
| TMV-011 | TMV:782-785 | `_increaseVersionId` adds exactly `1`, then mirrors the new value to alternative version. | TBD at review | TODO |
| TMV-012 | TMV:484-493 | Public `setValue` asserts live model, rejects null/undefined, creates a text buffer for every other input without an equality no-op, then delegates. | TBD at review | TODO |
| TMV-013 | TMV:487-489 | Null or undefined `setValue` input throws before buffer creation or version mutation. | TBD at review | TODO |
| TMV-014 | TMV:514-545 | `_setValueFromTextBuffer` captures old extent, swaps buffer/disposable, increments exactly once, clears decorations/history/settings, then calls the raw/public flush-emission path. | TBD at review | TODO |
| TMV-015 | TMV:495-511 | `_createContentChanged2` observes current post-transition version through `getVersionId()` in the public event payload. | TBD at review | TODO |
| TMV-016 | TMV:547-575 | `setEOL` asserts live model; changed flow runs before-EOL hook, mutates buffer, increments once, runs after-EOL hook, then emits raw/public events with post-increment version. | TBD at review | TODO |
| TMV-017 | TMV:550-552 | Equal EOL returns before mutation, increment, hooks, or events. | TBD at review | TODO |
| TMV-018 | TMV:1503-1601 | `_doApplyEdits` applies buffer edits and trim state first; its content-change branch controls decoration transforms, one version increment, raw/public events, and final reverse-edit return. | TBD at review | TODO |
| TMV-019 | TMV:1512-1599 | Nonempty changes transform every decoration first, increment exactly once, build raw changes, then emit both events carrying post-increment version. | TBD at review | TODO |
| TMV-020 | TMV:1506,1509-1512,1599-1601 | After buffer apply and trim-state assignment, empty `contentChanges` skips decoration transforms, version increment, and event emission, then returns `undefined` or `reverseEdits`. | TBD at review | TODO |
| TMV-021 | TMV:787-789 | `_overwriteVersionId` directly assigns a supplied version that may decrease/repeat and leaves alternative version unchanged. | TBD at review | TODO |
| TMV-022 | TMV:760-763 | Explicit excluded sibling `getAlternativeVersionId` asserts live model, then returns alternative version. | TBD at review | TODO |
| TMV-023 | TMV:791-793 | Explicit excluded sibling `_overwriteAlternativeVersionId` directly assigns its supplied value. | TBD at review | TODO |
| TMV-024 | TMV:284,377,2030 | Explicit excluded decoration member `_instanceId` is initialized from `singleLetterHash(MODEL_ID)` and prefixes generated decoration IDs. | TBD at review | TODO |
| CTS-001 | CTS:14 | Token contract readonly `isCancellationRequested` property. | TBD at review | TODO |
| CTS-002 | CTS:16-24 | Token contract readonly cancellation event property covers listener, context, optional disposable bucket, once-only fire, and next-turn late listeners. | TBD at review | TODO |
| CTS-003 | CTS:27-30 | Frozen `shortcutEvent` schedules callback/context with exact timeout `0` and returns disposal that clears the handle. | TBD at review | TODO |
| CTS-004 | CTS:49-52 | Frozen `None` token is false and uses `Event.None`. | TBD at review | TODO |
| CTS-005 | CTS:54-57 | Frozen `Cancelled` token is true and uses `shortcutEvent`. | TBD at review | TODO |
| CTS-006 | CTS:62 | Mutable canceled-state field starts `false`. | TBD at review | TODO |
| CTS-007 | CTS:63 | Mutable emitter field starts `null`. | TBD at review | TODO |
| CTS-008 | CTS:65-73 | `MutableToken.cancel` performs the one-way state/notification transition. | TBD at review | TODO |
| CTS-009 | CTS:66-72 | Only the first cancel flips the flag before notification; repeated cancel is a no-op. | TBD at review | TODO |
| CTS-010 | CTS:68-71 | Existing emitter fires once and is disposed/reset; missing emitter skips notification. | TBD at review | TODO |
| CTS-011 | CTS:75-77 | `isCancellationRequested` getter returns the flag. | TBD at review | TODO |
| CTS-012 | CTS:79-87 | `onCancellationRequested` getter returns shortcut or one lazy emitter event. | TBD at review | TODO |
| CTS-013 | CTS:80-82 | Already-canceled getter returns `shortcutEvent` immediately. | TBD at review | TODO |
| CTS-014 | CTS:83-85 | Before cancellation, missing emitter is allocated; existing emitter is reused. | TBD at review | TODO |
| CTS-015 | CTS:89-94 | `MutableToken.dispose` retires only listener state and leaves cancellation flag unchanged. | TBD at review | TODO |
| CTS-016 | CTS:90-93 | Existing emitter disposes and resets to `null`; missing emitter is a no-op. | TBD at review | TODO |
| CTS-017 | CTS:99 | Source token field starts `undefined`. | TBD at review | TODO |
| CTS-018 | CTS:100 | Parent-listener field starts `undefined` and is source-owned. | TBD at review | TODO |
| CTS-019 | CTS:102-104 | Source constructor derives its optional parent listener. | TBD at review | TODO |
| CTS-020 | CTS:103 | Present parent subscribes `this.cancel` with source context; absent parent installs nothing. | TBD at review | TODO |
| CTS-021 | CTS:106-113 | `token` getter returns the current singleton/mutable token. | TBD at review | TODO |
| CTS-022 | CTS:107-111 | Missing token lazily allocates one `MutableToken` before return. | TBD at review | TODO |
| CTS-023 | CTS:115-126 | Source `cancel` chooses allocation-free canceled singleton, mutable cancellation, or singleton no-op. | TBD at review | TODO |
| CTS-024 | CTS:116-121 | Cancel before token read stores shared `Cancelled` without allocation. | TBD at review | TODO |
| CTS-025 | CTS:122-125 | Existing `MutableToken` delegates to its cancel transition. | TBD at review | TODO |
| CTS-026 | CTS:122-126 | Existing `None` or `Cancelled` singleton takes the nonmutable no-op path. | TBD at review | TODO |
| CTS-027 | CTS:128-141 | Source `dispose` optionally cancels, disposes parent listener, then chooses no-token initialization, mutable-listener disposal, or singleton no-op. | TBD at review | TODO |
| CTS-028 | CTS:129-131 | `cancel=true` performs cancel first; default `false` skips it. | TBD at review | TODO |
| CTS-029 | CTS:132 | Present parent listener disposes; absence is a no-op, and the field is not cleared so repeated dispose repeats the call. | TBD at review | TODO |
| CTS-030 | CTS:133-136 | Dispose before token read stores shared `None`; later cancel is a no-op. | TBD at review | TODO |
| CTS-031 | CTS:137-140 | Existing mutable token disposes listeners but retains the same token and flag. | TBD at review | TODO |
| CTS-032 | CTS:137-141 | Existing singleton token takes the nonmutable no-op path. | TBD at review | TODO |
| CTS-033 | CTS:34-46 | Explicit excluded `isCancellationToken` member accepts exact singleton/mutable identities, rejects nonobjects, and otherwise performs structural boolean/event checks. | TBD at review | TODO |
| CTS-034 | CTS:35-37 | `None` or `Cancelled` identity returns `true` immediately. | TBD at review | TODO |
| CTS-035 | CTS:38-40 | `MutableToken` instance returns `true` immediately. | TBD at review | TODO |
| CTS-036 | CTS:41-43 | Falsy or nonobject input returns `false` before structural checks. | TBD at review | TODO |
| CTS-037 | CTS:144-148 | Explicit excluded `cancelOnDispose` creates a source, adds one store-owned disposer that cancels it, then returns its token. | TBD at review | TODO |
| CTS-038 | CTS:158 | Excluded pool `_source` field starts a fresh cancellation source. | TBD at review | TODO |
| CTS-039 | CTS:159 | Excluded pool `_listeners` owns token subscriptions. | TBD at review | TODO |
| CTS-040 | CTS:161 | Excluded pool `_total` starts `0`. | TBD at review | TODO |
| CTS-041 | CTS:162 | Excluded pool `_cancelled` starts `0`. | TBD at review | TODO |
| CTS-042 | CTS:163 | Excluded pool `_isDone` starts `false`. | TBD at review | TODO |
| CTS-043 | CTS:165-167 | Excluded pool `token` getter returns source token. | TBD at review | TODO |
| CTS-044 | CTS:173-192 | Excluded pool `add` increments total or retains one self-disposing cancellation listener that increments canceled count and rechecks. | TBD at review | TODO |
| CTS-045 | CTS:174-176 | Adding after pool completion returns before counters/listeners. | TBD at review | TODO |
| CTS-046 | CTS:180-184 | Already-canceled input increments canceled count, checks completion, and returns before subscription. | TBD at review | TODO |
| CTS-047 | CTS:194-200 | Excluded pool `_check` evaluates completion and performs its ordered transition. | TBD at review | TODO |
| CTS-048 | CTS:195-199 | Only not-done, positive-total, exact total=canceled state marks done, disposes listeners, then cancels pool source. | TBD at review | TODO |
| CTS-049 | CTS:202-205 | Excluded pool `dispose` retires listeners before disposing source. | TBD at review | TODO |
<!-- SOURCE_LEDGER_END -->

Mechanical review gate: stop after this inventory/ledger documentation
milestone. No product or test code is authorized by this status.

### Separate local ownership audit

The local audit has **87 rows** and is deliberately outside the 759-row
pinned-source denominator. It records current implementation and test authority;
it does not pre-approve any target mapping or deviation.

| ID | Area | Local owner | Current behavior / audit finding |
|---|---|---|---|
| LA-001 | Identity | `viewer/common/model/text_model.mbt:5-14` | Model retains URI, caller-host `version`, `revision`, and snapshot as separate facts. |
| LA-002 | Identity | `viewer/common/model/text_model.mbt:23-26` | Internal mutable `version_id` already exists and is distinct from host `version`. |
| LA-003 | Identity | `viewer/common/model/text_model.mbt:91` | Construction initializes internal version to exactly `1`. |
| LA-004 | Identity | `viewer/common/model/text_model.mbt:449-455` | `get_version_id` returns internal version without a dispose assertion. |
| LA-005 | Identity | `viewer/common/model/text_model.mbt:458-462` | `increase_version_id` adds exactly `1`; alternative-version mirroring is absent. |
| LA-006 | Identity | `viewer/common/model/text_model.mbt:558-593,601-608` | Whole-value replacement orders snapshot swap, one version increment, and decoration clear, then calls the raw/public flush-emission path; delivery is suppressed while the model is disposing. |
| LA-007 | Identity | `viewer/common/model/text_model.mbt:31,94; viewer/common/model/text_model_decorations.mbt:59-68` | `instance_id` is a non-globally-unique decoration prefix from a counter/hash, not physical identity or a safe freshness key. |
| LA-008 | Identity | `viewer/common/model/text_model.mbt:155-163` | Distinct models with equal URI/host version pass; revision, internal version, instance ID, and physical equality are ignored. |
| LA-009 | Identity | `viewer/viewer.mbt:341-346; viewer/registry.mbt:15; viewer/editor_events.mbt:500,515,578-582` | Marker refresh plus inlay and hover completions all delegate freshness to that helper. |
| LA-010 | Identity | `viewer/common/model/text_model_test.mbt:61-79` | Test accepts a distinct same-URI/same-host-version model; this is an async-ownership test bug. |
| LA-011 | Identity | `viewer/common/model/text_model.mbt:103-121` | Model disposal fires will-dispose, retires tokenization/emitters, and marks disposed. |
| LA-012 | Identity | `viewer/attach_model.mbt:71-73` | Attached model disposal calls `set_model(None)` through a swap-scoped listener. |
| LA-013 | Cancellation | `language/cancellation.mbt:3-5` | Token is only a shared `Ref[Bool]`. |
| LA-014 | Cancellation | `language/cancellation.mbt:8-11` | `new` allocates one false Boolean cell. |
| LA-015 | Cancellation | `language/cancellation.mbt:14-17` | Documentation calls `none` shared/never-cancelled, but it returns a fresh publicly cancellable token. |
| LA-016 | Cancellation | `language/cancellation.mbt:20-23` | `cancel` only sets the Boolean; scoped production code has zero callers. |
| LA-017 | Cancellation | `language/cancellation.mbt:26-30` | Polling is the only observation API; scoped production code has zero polling callers. |
| LA-018 | Cancellation | `language/cancellation.mbt:1-31` | No event, source/token split, parent listener, lazy singleton, or dispose lifecycle exists. |
| LA-019 | Cancellation | `language/inlay_hints.mbt:35-41` | Inlay provider contract accepts a cancellation token. |
| LA-020 | Cancellation | `viewer/contrib/hover/hover_participants.mbt:44-55` | Hover participant `compute_async` has no cancellation-token parameter. |
| LA-021 | Inlay | `viewer/inlay_hints_host.mbt:15-21` | Controller owns only last hints and decoration IDs; no request source/generation/store/cache. |
| LA-022 | Inlay | `viewer/inlay_hints_host.mbt:23-35` | Per-editor map attach initializes both arrays empty. |
| LA-023 | Inlay | `viewer/inlay_hints_host.mbt:38-45` | `get` reads the map and `detach` only removes the entry. |
| LA-024 | Inlay | `viewer/inlay_hints_host.mbt:47-55` | Model reset clears arrays only; it does not cancel work. |
| LA-025 | Inlay | `viewer/inlay_hints_host.mbt:67-80` | Contribution disposal only detaches the map entry. |
| LA-026 | Inlay | `viewer/registry.mbt:6-29` | `request_model_features` launches one unretained `async_run` per call. |
| LA-027 | Inlay | `viewer/registry.mbt:10-28` | No task handle, source, request generation, or disposable owner surrounds launch. |
| LA-028 | Inlay | `viewer/common/languages/languages.mbt:176-189` | Callee creates an owner-inaccessible token and captures full-range length once, while passing the live model object to providers. |
| LA-029 | Inlay | `viewer/common/languages/languages.mbt:182-195` | Each active matching entry encountered by the live index loop receives the same token/captured range sequentially in then-current registry order; the entries array is not snapshotted. |
| LA-030 | Inlay | `viewer/common/languages/languages.mbt:185-189` | Active/selector checks occur only before await; there is no post-await registration check. |
| LA-031 | Inlay | `viewer/common/languages/languages.mbt:189-194` | Exact live model/captured range/token are passed; every error, including cancellation-shaped errors, is logged and becomes `[]`. |
| LA-032 | Inlay | `viewer/common/languages/languages.mbt:195-197` | Post-await append has no token/disposed/version/generation/active recheck and retains no disposer or provider set. |
| LA-033 | Inlay | `viewer/registry.mbt:10-15` | Freshness is checked only after the whole provider aggregate finishes. |
| LA-034 | Inlay | `viewer/registry.mbt:20-26` | Absent controller makes completion a no-op after freshness guard. |
| LA-035 | Inlay | `viewer/registry.mbt:21-24` | Accepted completion overwrites hints then synchronizes decorations. |
| LA-036 | Inlay | `viewer/inlay_hints_host.mbt:87-93` | Sync returns for missing controller/model or both hints and old IDs empty. |
| LA-037 | Inlay | `viewer/registry.mbt:20-24; viewer/inlay_hints_host.mbt:87-98` | Accepted result reacquires the current controller/model and applies there, not to the captured request model. |
| LA-038 | Inlay | `viewer/attach_model.mbt:112-115` | Fresh attach schedules rendering and launches model features. |
| LA-039 | Inlay | `viewer/attach_model.mbt:58-69` | Every content event launches another request without retiring the preceding one. |
| LA-040 | Inlay | `viewer/attach_model.mbt:64-68` | Launch precedes public content event and render scheduling. |
| LA-041 | Inlay | `viewer/attach_model.mbt:11-116` | No provider-change, viewport-scroll, inlay-option, or debounce request lane exists. |
| LA-042 | Inlay | `viewer/viewer.mbt:660-691; viewer/registry.mbt:10-28` | Detach clears state/listeners but cannot stop provider work or failure logging; only the eventual completion guard may fail. |
| LA-043 | Inlay | `viewer/viewer.mbt:855-887; viewer/registry.mbt:10-28` | Viewer disposal likewise leaves provider work/logging alive until completion despite later guard failure. |
| LA-044 | Inlay | `viewer/inlay_hints_host_wbtest.mbt:15-57` | Tests install resolved arrays directly; request races are untested. |
| LA-045 | Inlay | `viewer/registry.mbt:10-24; viewer/inlay_hints_host.mbt:87-98` | With no version/identity/generation/token ordering, last finisher wins; an old empty result can clear newer decoration IDs. |
| LA-046 | Inlay | `viewer/common/languages/languages.mbt:19-32,109-116,184-197` | Registry exposes no observed change event; disposing an in-flight provider removes it from the live entries array but its post-await result is still accepted, and the index shift can skip a later provider. |
| LA-047 | Hover | `viewer/contrib/hover/browser/content_hover_controller.mbt:8-45` | Controller owns operation state, react generation, target, notification token, decorations. |
| LA-048 | Hover | `viewer/editor_events.mbt:60-80` | Sticky mouse grace uses raw `set_timeout` and discards handle. |
| LA-049 | Hover | `viewer/editor_events.mbt:65-76` | Callback mutates only when pending and captured react token still match. |
| LA-050 | Hover | `viewer/contrib/hover/browser/content_hover_controller.mbt:97-107` | `cancel_react` increments generation and clears state, but cannot clear browser handle. |
| LA-051 | Hover | `viewer/browser_host.mbt:28-32` | Timer binding returns `Double`; no clear/disposable wrapper exists. |
| LA-052 | Hover | `viewer/editor_events.mbt:367-405` | Async/loading timers allocate immediately; the sync timer allocates later only when async trigger returns `proceed=true`; every handle is ignored. |
| LA-053 | Hover | `viewer/contrib/hover/hover_controller.mbt:149-167,235-261` | Clear and new-anchor start rotate operation token and reset accumulation. |
| LA-054 | Hover | `viewer/contrib/hover/hover_controller.mbt:270-357` | Transitions reject mismatched integer tokens only; an equal reused token is accepted and token equality alone is not freshness. |
| LA-055 | Hover | `viewer/editor_events.mbt:60-80,367-405,475-490` | Every timer/task callback retains Viewer; mouse grace also retains controller; async retains model/anchor/token/computer/hints, and no handle/source releases those captures before completion. |
| LA-056 | Hover | `viewer/contrib/hover/hover_participants.mbt:352-387` | Public `compute_async` aggregates sequentially (test-used) and production `compute_async_each` streams sequentially; neither path is cancelable. |
| LA-057 | Hover | `viewer/contrib/hover/hover_participants.mbt:218-240` | Markdown async participant accepts no token and calls `hover_at`. |
| LA-058 | Hover | `viewer/common/languages/languages.mbt:120-128` | Hover provider path creates `CancellationToken::none()`. |
| LA-059 | Hover | `viewer/common/languages/languages.mbt:128-144` | Providers run sequentially and return the first `Some`, even when its `contents` is empty; that stops later providers before the markdown participant drops empty contents. |
| LA-060 | Hover | `viewer/common/languages/languages.mbt:133-142` | Provider failures are contained/logged; scan continues on `None`. |
| LA-061 | Hover | `viewer/editor_events.mbt:493-506` | Async item compares only current-model helper plus integer token; no anchor, physical identity, internal version, generation, or cancellation state. |
| LA-062 | Hover | `viewer/editor_events.mbt:509-522` | Async done has the same helper/token-only guard before completion/notification. |
| LA-063 | Hover | `viewer/common/model/text_model.mbt:155-163` | Physical same-URI/version replacement can pass both hover guards. |
| LA-064 | Hover | `viewer/editor_events.mbt:410-419` | Sync timer rejects a mismatched token only; a reused equal token passes compute/apply. |
| LA-065 | Hover | `viewer/editor_events.mbt:424-432` | Loading timer rejects a mismatched token only; a reused equal token passes the freshness guard, then changes state only if the current operation is `WaitingForAsync`. |
| LA-066 | Hover | `viewer/editor_events.mbt:524-541` | Notification requires matching token, completion, and not-yet-notified token. |
| LA-067 | Hover | `viewer/attach_model.mbt:58-69; viewer/hover_contribution.mbt:14-92` | Content event fires, but hover contribution has no content-cancel subscription. |
| LA-068 | Hover | `viewer/viewer.mbt:660-691` | Detach empties hover, cancels react generation, resets inlay, disposes model bundle. |
| LA-069 | Hover | `viewer/contrib/hover/browser/content_hover_controller.mbt:125-133` | Controller model reset clears only hover decoration IDs/range. |
| LA-070 | Hover | `viewer/hover_contribution.mbt:14-27` | Contribution disposal removes instance but owns no task/timer handles. |
| LA-071 | Hover | `viewer/viewer.mbt:855-900` | Viewer disposal detaches, disposes contributions, then retires hover widget state. |
| LA-072 | Hover | `viewer/viewer.mbt:140-167` | `ModelData.dispose` retires swap listeners/view/view model, not async features. |
| LA-073 | Hover | `viewer/editor_events.mbt:60-80,367-405,475-490` | After cancel/detach, timers/tasks run; guards suppress some effects but do not cancel resources. |
| LA-074 | Hover | `viewer/contrib/hover/hover_controller_wbtest.mbt:31-130; viewer/contrib/hover/hover_reconciliation_wbtest.mbt:1-175; viewer/contrib/hover/content_hover_computer_wbtest.mbt:18-64; viewer/common/languages/languages_registry_wbtest.mbt:18-37; viewer/contrib/hover/browser/hover_events_wbtest.mbt:1-102; viewer/contrib/hover/hover_interaction_wbtest.mbt:1-114; viewer/contrib/hover/hover_anchor_wbtest.mbt:1-198; viewer/contrib/hover/hover_widget_geometry_wbtest.mbt:1-134; viewer/contrib/hover/browser/content_hover_widget_wbtest.mbt:1-72; viewer/contrib/hover/hover_render_wbtest.mbt:1-211; tests/browser/smoke/hover_stability.spec.js:1-71` | Existing authority also covers pure interaction predicates, anchor candidates/semantics, widget geometry/rendering, and browser hover stability; none is a deterministic deferred Viewer-path race across `set_value`, replacement/reuse, detach/dispose, or cancellation. |
| LA-075 | Hover | `viewer/contrib/hover/hover_registry.mbt:7-64; viewer/contrib/hover/hover_participants.mbt:373-387` | Registry preserves factory order and async computation serializes it. |
| LA-076 | Hover | `viewer/editor_events.mbt:477-485,568-574` | Launch snapshots inlay-hint array; later replacement is not tied to task lifetime. |
| LA-077 | Hover | `viewer/editor_events.mbt:544-565` | Highlight apply has guards, range dedupe, and owner-scoped delta. |
| LA-078 | Hover | `viewer/editor_events.mbt:340-361` | Real state change reconciles widget/schedules render; identical state returns. |
| LA-079 | Hover | `viewer/common/model/text_model.mbt:558-580; viewer/attach_model.mbt:58-69; viewer/editor_events.mbt:475-522` | `set_value` bumps internal version, but hover captures no version and content change rotates neither operation nor react token; pre-change results can apply post-change. |
| LA-080 | Hover | `viewer/viewer.mbt:667-674; viewer/contrib/hover/hover_controller.mbt:95-97,235-261; viewer/editor_events.mbt:393-522` | Detach installs token `0` and fresh start reuses token `1`: old trigger/sync/loading timers need only that equality across any swap, while item/done also pass on same-URI/same-host-version replacement via the weak model helper. |
| LA-081 | Hover | `viewer/contrib/hover/browser/content_hover_controller.mbt:38-40; viewer/viewer.mbt:667-674; viewer/editor_events.mbt:528-541` | Detach resets operation token but not `hover_notified_token`; a fresh model's reused token can be suppressed as already notified. |
| LA-082 | Inlay | `viewer/viewer.mbt:585-626` | `set_value` no-ops when disposed/no model, otherwise mutates the same model; `set_model` no-ops for same physical object, while a distinct same-URI/version model detaches, attaches, and starts a request. |
| LA-083 | Inlay | `viewer/registry.mbt:10-24; viewer/common/model/text_model.mbt:9,23-26,155-163,558-593; viewer/inlay_hints_host.mbt:87-98` | `set_value` changes only internal version, so both same-object completions pass; distinct same-URI/host-version completion also passes and applies to the new current model. |
| LA-084 | Inlay | `viewer/common/model/set_value_wbtest.mbt:8-39,84-97; viewer/set_value_api_wbtest.mbt:10-31` | Tests cover version increments, same-instance retention, and stale decoration clearing, but never hold a provider request across `set_value`. |
| LA-085 | Inlay | `viewer/common/languages/languages_registry_wbtest.mbt:18-72; language/cancellation.mbt:1-31` | Async language-provider tests cover hover failure/order, and a separate test covers token-provider registration disposal; there is no inlay aggregation or cancellation-token test. |
| LA-086 | Inlay | `tests/browser/moonbit/component/viewer_api_scenario.mbt:62-73,98-116; tests/browser/component/viewer_api.spec.js:56-71` | Browser authority is an immediate token-ignoring happy path only: no delay, cancel, dispose, failure, or multi-provider case. |
| LA-087 | Inlay | `viewer/lifecycle_ownership_wbtest.mbt:69-108,168-188; tests/browser/moonbit/model_swap/model_swap_scenario.mbt:99-228` | Detach/dispose are tested without a pending inlay request, so they prove neither cancellation nor stale-result rejection. |

## Proposed Gate B Target Contract

These are review proposals, not implemented behavior or terminal ledger
statuses.

| Contract | Required implementation shape |
|---|---|
| Request stamp | Every inlay/hover operation captures the physical `TextModel`, its `get_version_id()`, a controller-lifetime monotonic generation, and a caller-owned cancellation token. URI, host `version`, `revision`, and decoration `instance_id` are not freshness keys. |
| Freshness predicate | A continuation may mutate only while the Viewer/controller is live, the captured model is physically current, its internal version is unchanged, the generation is current, and the token is not canceled. |
| Cancellation owner | The current inlay session or hover operation owns one source/store and cancels it before replacement, content/model invalidation, detach, model disposal, Viewer disposal, or operation disposal. Generations never reset on model swaps. |
| Timers | Mouse-react and hover async/sync/loading timers have clearable owned handles. Cancellation clears the handle and invalidates its generation; callbacks retain guards for a dispatch race. |
| Provider chain | The caller creates the token and forwards that same value through computer/participant/registry/provider boundaries. Ordinary failures remain contained/logged; cancellation never commits data. |
| Apply boundary | Only the newest request may replace controller data, delta decorations, change hover state, schedule rendering, or fire hover resolution. A stale empty result cannot clear a newer nonempty result. |

`same_identity_and_version` is not approved as async authority. Review must
decide whether a non-async URI/host-version consumer still needs the helper or
whether implementation removes it.

### Inventory review checklist — stop gate

- [ ] Reviewer confirms the strict denominator is 759 atomic source rows with
  exact per-prefix counts and no derived/local row counted as source.
- [ ] Reviewer confirms complete source methods are not split across scope
  boundaries and every excluded sibling member has its own row.
- [ ] Reviewer confirms the 87-row local audit and test-authority corrections
  against the current checkout.
- [ ] Reviewer approves or amends physical model/internal-version/generation/
  token freshness and monotonic generations across swaps.
- [ ] Reviewer approves controller-owned cancellation sources and clearable
  timer handles, including detach/dispose ordering.
- [ ] Reviewer assigns every row a MoonBit target and planned terminal
  disposition while leaving its working status `TODO` until evidence lands.
- [ ] Reviewer approves the branch/configuration matrix below.
- [ ] Corrected inventory is committed separately; only then may product/test
  implementation begin.

**Review gate:** stopped. Commit and independently approve this corrected
denominator before changing product or test code.


## Test-Authority Corrections

- viewer/common/model/text_model_test.mbt currently expects a different model
  revision/instance with the same URI and host version to pass the freshness
  guard. That expectation must be treated as a test bug for async ownership.
- Existing hover reconciliation tests cover operation sequencing inside one
  active model but do not prove model/content cancellation.
- Existing inlay tests mostly install resolved hints directly and do not cover
  request races.

## Required Test Matrix (Phase 4)

All deferred work uses controlled completion, never a sleep as the result
oracle. A test-only inlay provider and hover provider expose `started`,
per-call `release`, and consumer-side `settled` signals. Outcomes include
nonempty, empty/`None`, ordinary error, and a result/error returned after the
provider observes cancellation. White-box tests await the internal request
body; production alone wraps it in `async_run`.

| Group | Behavior variables and mandatory combinations | Harness / assertions |
|---|---|---|
| Cancellation lifecycle | Token read before/after cancel; listener count 0/1/3; early/late/disposed listener; cancel once/twice; dispose false/true before/after token read; parent absent/present; repeated dispose | Port pinned `cancellation.test.ts` labels `None`, `cancel before token`, `cancel happens only once`, `cancel calls all listeners`, `token stays the same`, both `dispose calls no listeners` cases, `dispose does not cancel`, and `parent cancels child`. Assert flag-before-notify, identity, exact-once, late-next-turn, and order on every target. Pool tests remain row-level DEFERRED evidence. |
| Model/version stamp | Same/different physical model × same/different URI × same host version; internal version unchanged/changed; current/stale generation; live/canceled token; Viewer live/disposed | Model/root white-box tests. Include same object after equal and unequal `set_value`, distinct same-URI/same-host-version objects, detach, model dispose, Viewer dispose. Only the all-current combination applies. Port pinned `setValue eventing`; EOL and incremental-edit rows take their owning-plan/N-A dispositions. |
| IHC session/update | Enabled off/on/onUnlessPressed/other mode; model/provider absent/present; cache miss/empty/nonempty; modifier unchanged/changed; provider event scheduled/idle; request success/canceled/error; scroll top changed/unchanged; content timeout replacement; option match/nonmatch | Controller/model tests or explicit DEFERRED/N-A row evidence. Assert cleanup-before-return, reset cancellation order, four zero-delay schedules, debounce floor 800, watched-provider ownership, and cancel-before-apply. |
| IHC ranges/anchors/apply | View ranges empty/one/many, disjoint/touching/overlap, ±30 clamp; duplicate item, missing/current decoration range; affected/unaffected old decoration; missing current model; cap at 1500; cursor/fixed-length branches and padding shapes | DOM-free range/copy tests plus JS decoration integration where planned. Assert sorted merge, no duplicate copy, transaction pairing, class-ref disposal, scroll capture/restore, and exact render/style DEFERRED mapping for every excluded row. |
| IHF provider/anchor | Providers 0/1/2 × ranges 0/1/2; completion orders A→B/B→A; empty/change-event/error; canceled/disposed after settle; word/no-word; one-character token; token indices 0/1/2/count−2/count−1; leading/trailing `else if` | Language/fragment tests. Assert same token/model/range, completion-order accumulation, independent error containment, post-settle guard, before/after anchor direction, exact +1 columns, sort/dedupe/disposal seams, and resolve/command rows' explicit deferred disposition. |
| Hover timing/state | Delayed and every non-Delayed value × each operation state; delay 0/1/2/300/301; before/at half, full, 3×; async/sync computer absent/present; falsy/truthy item; error; async completes before sync, after sync, after loading; cancel/dispose iterable absent/present | Hover controller tests with a manual scheduler/clearable handles. Assert no pre-delay emission, exact state/order, result snapshot, latest options, loading only while waiting, scheduler replacement/cancel/dispose, and late callback rejection. |
| Hover controller/wrapper | Enabled/sticky/hidingDelay; context-menu ignore; model versus content change; scroll neither/top/left/both; mouse down/up/leave/move retention; runner scheduled/idle; key modifier/chord/Tab/default; invisible anchor absent/present; null/equal/compatible/incompatible anchor; loading factory absent/null/present | Existing interaction/browser white-box suites plus focused cases. Assert cancel-before-hide, content cancels pending react, model change cancels+hides, and every input early return. |
| Hover reconciliation | Previous visible complete × incoming complete × empty × insist; sticky-closer with/without anchor; participant suggester absent/null/present; action target element/non-element; mouseleave missing/outside/inside editor | Wrapper/controller tests. Pin the no-previous-complete fall-through: incomplete or empty+insist may already have applied before the later return. Assert cancel-before-clear and identity no-ops. |
| Hover computer/provider | Range/foreign anchor × marker support; invalid/valid line; whole/cross-line decoration; ordinary/collapsed containment at ±1 and just outside; async participant absent/present; provider `Some` empty/nonempty/`None`/throw; cancellation before/after completion; eager invocation and resolution order | Hover/languages tests. Assert identical token propagation, source-exact selection/order, first-`Some` local policy, contained logs, and canceled data never reaching reconciliation. Provider scoring/recursive/command rows receive P2 DEFERRED/N-A evidence rather than implicit omission. |
| Lifecycle races | Outstanding inlay/hover during `set_value`, same-URI/same-host-version replacement, new target, model dispose, detach, Viewer dispose; provider honors/ignores cancellation; newest request succeeds afterward | JS headless Viewer tests. Assert controller data, decoration IDs/ranges, hover view, resolution count/revision, render generation, token observation, and logs. Run both old-last and new-last completion permutations; stale nonempty is ignored and stale empty cannot clear new data. |
| Browser-visible result | Pending old inlay/hover, then content change or same-URI replacement; release newest then oldest; detach/dispose pending | One direct-Viewer component scenario plus Playwright. Assert newest inlay/hover text appears once, stale text never appears, stale empty cannot remove it, teardown leaves no widget/decoration, and no stale resolution report fires. |

Meaningful boundaries also include missing distance, `isAfterLines`, epsilon
`0`, `epsilon−δ`, and `epsilon`, range touching versus one-column gap, and
generation immediately before/current/after. Existing hover interaction,
anchor, widget, geometry, render, and browser-stability tests remain evidence
only after their rows are reconciled; they do not substitute for a deferred
Viewer-provider race.

There are no pinned direct tests for `InlayHintsFragments`,
`InlayHintsController`, `HoverOperation`, `ContentHoverComputer`, or
`getHover`; new tests for those units are branch-derived ordinary MoonBit
tests, not mislabeled reference ports. Pinned `contentHover.test.ts` cases are
render-position tests outside this async implementation scope.

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

- [x] inventory rows equal ledger rows: 759/759; TODO 759, done/deferred/N-A 0/0/0
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

### 2026-07-10 — rejected first inventory milestone

- Commit `5721b8e` recorded 581 mechanically contiguous rows, but fresh Gate B
  review rejected it: several excluded-sibling rows bundled many declared
  members/branches/CSS facts, two derived lifecycle notes were counted as
  source, and the matrix covered P1 races rather than the full denominator.
- No product or test file changed in that rejected documentation milestone.
  History is preserved; the correction below supersedes its denominator.

### 2026-07-10 — corrected Phase 1–2 inventory stop gate

- Verified the read-only VS Code oracle at
  `b18492a288de038fbc7643aae6de8247029d11bd`.
- Re-read every closed source unit/cluster under the strict declared-member,
  behavior-branch/early-return, constant, and CSS-fact rule. Excluded siblings
  remain atomic rows rather than prose-only or umbrella exclusions.
- Corrected source inventory/ledger: **759/759** rows, all `TODO`:
  `IHC 156, IHF 41, CHC 152, CHW 140, HOP 78, CHCMP 31, GHR 25, HTY 63,
  TMV 24, CTS 49`.
- Separate current-MoonBit ownership audit: **87** rows (`LA-001`–`LA-087`).
  It records two unretained `async_run` launches, four raw hover timer sites,
  model/content subscriptions, operation/react tokens, result guards,
  decoration applies, reset paths, and detach/dispose ordering.
- Mechanical verification passed: per-prefix counts, 759 source IDs and 87
  local IDs are contiguous, all 759 source rows end `TODO`, and
  `git diff --check` is clean. This correction changes the child and parent
  plan only.
- No product or test file changed and no runtime tests were run for this
  documentation-only correction. The corrected inventory commit and
  independent approval remain.

**STOP FOR REVIEW.** No implementation is authorized until the corrected
denominator is committed and approved, and every TODO row has a reviewed
target/planned disposition. Working statuses remain `TODO` until implementation
evidence supports a terminal status.
