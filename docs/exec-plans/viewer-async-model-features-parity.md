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
  below, plus the gesture-install/schedule boundary (309–311, 394),
  cache/anchor-range helpers (434–474), decoration replacement
  and scroll preservation (705–728), and cleanup (764–770). Exclude rendered
  label/active-label/render-mode and render-only dependency declarations
  (70–85, 93–96, 133–134, 144, 147–148, 155–157, 159),
  link/double-click/context-menu/command members (314–393, 395–432),
  decoration text/CSS construction (476–703), color/layout styling (730–762),
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

The authoritative whole-unit reread produced **581 source inventory members**:

`IHC 103 + IHF 41 + CHC 120 + CHW 101 + HOP 79 + CHCMP 31 + GHR 25 + HTY 40 + TMV 18 + CTS 23 = 581`.

Every source inventory member below is already a first-class parity-ledger row;
there is no separate summary count that can hide an omission. `MoonBit symbol`
stays `TBD at review` and every status stays `TODO` at this stop gate. Review
must decide whether the local identity helper is removed, strengthened, or
replaced by captured model identity plus internal version ID.

Abbreviations: `IHC` = `inlayHintsController.ts`; `IHF` = `inlayHints.ts`;
`CHC` = `contentHoverController.ts`; `CHW` =
`contentHoverWidgetWrapper.ts`; `HOP` = `hoverOperation.ts`; `CHCMP` =
`contentHoverComputer.ts`; `GHR` = `getHover.ts`; `HTY` = `hoverTypes.ts`;
`TMV` = `textModel.ts`; `CTS` = `cancellation.ts`.

| ID | Source member (file:line) | Arithmetic/transition | MoonBit symbol | Status |
|---|---|---|---|---|
| IHC-001 | IHC:45 | `_serviceBrand` DI brand field. | TBD at review | TODO |
| IHC-002 | IHC:47 | `_entries` owns `LRUCache<string, InlayHintItem[]>` with capacity `50`. | TBD at review | TODO |
| IHC-003 | IHC:49-52 | `get(model)` derives the key then returns the cache lookup. | TBD at review | TODO |
| IHC-004 | IHC:54-57 | `set(model,value)` derives the key then inserts/replaces. | TBD at review | TODO |
| IHC-005 | IHC:59-61 | `_key(model)` is URI string plus `/` plus `getVersionId()`. | TBD at review | TODO |
| IHC-006 | IHC:64-66 | Cache decorator name and delayed singleton registration. | TBD at review | TODO |
| IHC-007 | IHC:87-89 | Decoration metadata retains originating item. | TBD at review | TODO |
| IHC-008 | IHC:89 | Decoration metadata retains model delta decoration. | TBD at review | TODO |
| IHC-009 | IHC:90 | Decoration metadata owns disposable CSS class reference. | TBD at review | TODO |
| IHC-010 | IHC:105 | `CancellationStore._store` owns replaceable operation disposables. | TBD at review | TODO |
| IHC-011 | IHC:106 | `_tokenSource` starts as a fresh source. | TBD at review | TODO |
| IHC-012 | IHC:108-109 | Store disposal runs first. | TBD at review | TODO |
| IHC-013 | IHC:110 | Token source then disposes with `cancel=true`. | TBD at review | TODO |
| IHC-014 | IHC:113-115 | `reset` cancels/disposes old source before replacement. | TBD at review | TODO |
| IHC-015 | IHC:115 | `reset` creates a new token source. | TBD at review | TODO |
| IHC-016 | IHC:116 | `reset` installs a new disposable store. | TBD at review | TODO |
| IHC-017 | IHC:118-121 | `reset` returns the matching new store/token pair. | TBD at review | TODO |
| IHC-018 | IHC:131 | Contribution ID is `editor.contrib.InlayHints`. | TBD at review | TODO |
| IHC-019 | IHC:136-138 | Static `get` reads the contribution and normalizes nullish. | TBD at review | TODO |
| IHC-020 | IHC:140 | `_disposables` owns controller-lifetime resources. | TBD at review | TODO |
| IHC-021 | IHC:141 | `_sessionDisposables` owns current-model/session resources. | TBD at review | TODO |
| IHC-022 | IHC:142 | `_decorationsMetadata` owns decoration apply metadata. | TBD at review | TODO |
| IHC-023 | IHC:143 | `_debounceInfo` stores provider/model debounce state. | TBD at review | TODO |
| IHC-024 | IHC:146 | `_cursorInfo` stores position plus absolute freshness deadline. | TBD at review | TODO |
| IHC-025 | IHC:151 | `_editor` is the captured editor/session owner. | TBD at review | TODO |
| IHC-026 | IHC:152 | Language-features service owns the consulted registry. | TBD at review | TODO |
| IHC-027 | IHC:154 | Injected inlay cache is the fast-restore cache. | TBD at review | TODO |
| IHC-028 | IHC:160 | Debounce uses provider registry, key `InlayHint`, minimum `25` ms. | TBD at review | TODO |
| IHC-029 | IHC:161 | Provider-registry changes invoke `_update`. | TBD at review | TODO |
| IHC-030 | IHC:162 | Editor model changes invoke `_update`. | TBD at review | TODO |
| IHC-031 | IHC:163 | Model-language changes invoke `_update`. | TBD at review | TODO |
| IHC-032 | IHC:164-168 | Only inlay-hint configuration changes invoke `_update`. | TBD at review | TODO |
| IHC-033 | IHC:169 | Construction performs one immediate `_update`. | TBD at review | TODO |
| IHC-034 | IHC:173-174 | Dispose first retires the current session. | TBD at review | TODO |
| IHC-035 | IHC:175 | Dispose next removes all owned decorations. | TBD at review | TODO |
| IHC-036 | IHC:176 | Dispose finally retires controller-lifetime resources. | TBD at review | TODO |
| IHC-037 | IHC:179-181 | `_update` clears prior session before removing decorations. | TBD at review | TODO |
| IHC-038 | IHC:183-186 | Enabled mode `off` returns after cleanup. | TBD at review | TODO |
| IHC-039 | IHC:188-191 | Absent model or no matching provider returns after cleanup. | TBD at review | TODO |
| IHC-040 | IHC:193-196 | Mode `on` uses normal render and no modifier subscription. | TBD at review | TODO |
| IHC-041 | IHC:197-207 | Other modes choose default/alternate modes; `onUnlessPressed` reverses them. | TBD at review | TODO |
| IHC-042 | IHC:209-212 | Session owns modifier event; callback returns if model vanished. | TBD at review | TODO |
| IHC-043 | IHC:213-220 | Alt+Ctrl without Shift/Meta selects alternate; changed mode copies/applies/schedules `0`. | TBD at review | TODO |
| IHC-044 | IHC:224-228 | Truthy cache hit applies over full model range. | TBD at review | TODO |
| IHC-045 | IHC:229-234 | Session teardown caches anchors only while model is live. | TBD at review | TODO |
| IHC-046 | IHC:236 | Local request `cts` is declared undefined and never assigned. | TBD at review | TODO |
| IHC-047 | IHC:237 | `watchedProviders` deduplicates session listeners. | TBD at review | TODO |
| IHC-048 | IHC:239 | Model disposal invokes no-op `cts?.cancel` in pinned source. | TBD at review | TODO |
| IHC-049 | IHC:241 | Session owns one `CancellationStore`. | TBD at review | TODO |
| IHC-050 | IHC:243-276 | One scheduler owns request callback and initial debounce delay. | TBD at review | TODO |
| IHC-051 | IHC:244 | Each run captures `Date.now()` start time. | TBD at review | TODO |
| IHC-052 | IHC:246 | Each run resets store, cancelling the preceding operation. | TBD at review | TODO |
| IHC-053 | IHC:248-249 | Request gets registry, captured model, visible ranges, fresh token. | TBD at review | TODO |
| IHC-054 | IHC:250 | Measured duration updates scheduler delay before cancel guard. | TBD at review | TODO |
| IHC-055 | IHC:251-254 | Canceled post-await result is disposed and returns before mutation. | TBD at review | TODO |
| IHC-056 | IHC:256-257 | Every provider represented by fragments is inspected. | TBD at review | TODO |
| IHC-057 | IHC:258 | Watcher requires change event function and unwatched provider. | TBD at review | TODO |
| IHC-058 | IHC:259 | Provider is marked watched before subscribing. | TBD at review | TODO |
| IHC-059 | IHC:260-264 | Provider event schedules only when no run is already scheduled. | TBD at review | TODO |
| IHC-060 | IHC:260-264 | Provider subscription belongs to current operation store. | TBD at review | TODO |
| IHC-061 | IHC:268 | Returned fragments belong to current operation store. | TBD at review | TODO |
| IHC-062 | IHC:269 | Operation store also clears `watchedProviders`. | TBD at review | TODO |
| IHC-063 | IHC:270 | Successful current result applies ranges/items. | TBD at review | TODO |
| IHC-064 | IHC:271 | Apply is followed by cache refresh. | TBD at review | TODO |
| IHC-065 | IHC:273-275 | Thrown errors, including cancellation, go to `onUnexpectedError`. | TBD at review | TODO |
| IHC-066 | IHC:278 | Session owns scheduler disposal. | TBD at review | TODO |
| IHC-067 | IHC:279 | New session schedules first request with delay `0`. | TBD at review | TODO |
| IHC-068 | IHC:281-288 | Scroll schedules on top change or idle scheduler; otherwise no-op. | TBD at review | TODO |
| IHC-069 | IHC:290 | Session owns mutable delayed-content timeout. | TBD at review | TODO |
| IHC-070 | IHC:291-292 | Content change invokes same unassigned no-op `cts?.cancel`. | TBD at review | TODO |
| IHC-071 | IHC:294-295 | Stabilization delay is `max(scheduler.delay, 800)`. | TBD at review | TODO |
| IHC-072 | IHC:296 | Content captures cursor and `Date.now() + delay`. | TBD at review | TODO |
| IHC-073 | IHC:297 | Replacing timeout cancels prior; new timeout schedules delay `0`. | TBD at review | TODO |
| IHC-074 | IHC:299 | Content change also schedules normal debounced run. | TBD at review | TODO |
| IHC-075 | IHC:302-306 | Session option listener schedules only for inlay-hint changes. | TBD at review | TODO |
| IHC-076 | IHC:434-437 | Fast restore copies current anchors then caches by model key. | TBD at review | TODO |
| IHC-077 | IHC:441-443 | Anchor copy deduplicates by original item while scanning metadata. | TBD at review | TODO |
| IHC-078 | IHC:444-448 | Second decoration for one item takes early `continue`. | TBD at review | TODO |
| IHC-079 | IHC:449-450 | Missing current decoration range omits the item. | TBD at review | TODO |
| IHC-080 | IHC:451-455 | Existing range creates same-direction anchor and `with` copy. | TBD at review | TODO |
| IHC-081 | IHC:457 | Copies return in map insertion order. | TBD at review | TODO |
| IHC-082 | IHC:460-464 | Request ranges extend viewport by `30` lines. | TBD at review | TODO |
| IHC-083 | IHC:465 | Visible ranges sort by start before merge. | TBD at review | TODO |
| IHC-084 | IHC:466 | Each range extends `-30/+30` and is model-validated. | TBD at review | TODO |
| IHC-085 | IHC:467-469 | Empty result or non-touching range appends. | TBD at review | TODO |
| IHC-086 | IHC:469-471 | Touching/intersecting range merges with last via `plusRange`. | TBD at review | TODO |
| IHC-087 | IHC:473 | Merged ranges return in sorted order. | TBD at review | TODO |
| IHC-088 | IHC:705-709 | Apply scans metadata and queries each active decoration range. | TBD at review | TODO |
| IHC-089 | IHC:709-710 | Old decoration is affected only when a request range contains it. | TBD at review | TODO |
| IHC-090 | IHC:711-714 | Affected ID queues, CSS ref disposes, metadata deletes, in order. | TBD at review | TODO |
| IHC-091 | IHC:717 | Stable scroll state captures before mutation. | TBD at review | TODO |
| IHC-092 | IHC:719-720 | One transaction deltas affected old IDs against new decorations. | TBD at review | TODO |
| IHC-093 | IHC:721-724 | Returned IDs pair by index with new metadata. | TBD at review | TODO |
| IHC-094 | IHC:727 | Stable scroll state restores after mutation. | TBD at review | TODO |
| IHC-095 | IHC:764-765 | Cleanup removes every metadata key from editor at once. | TBD at review | TODO |
| IHC-096 | IHC:766-768 | Cleanup disposes every retained CSS class reference. | TBD at review | TODO |
| IHC-097 | IHC:769 | Cleanup clears metadata last. | TBD at review | TODO |
| IHC-098 | IHC:70-85,93-96,133-134,144,147-148,155-157,159 | Required sibling row: rendered/active label, render mode, cap/sentinel, CSS-rule field/init, active state, and command/notification/instantiation dependencies. | TBD at review | TODO |
| IHC-099 | IHC:314-393,395-432 | Required sibling row: link, double-click, context-menu, label-resolve, and command implementation; request scheduling at the install boundary remains scoped. | TBD at review | TODO |
| IHC-100 | IHC:476-703 | Required sibling row: decorator text/CSS/padding/truncation/whitespace/cursor-stop production and `1500` cap. | TBD at review | TODO |
| IHC-101 | IHC:730-762 | Required sibling row: color and layout styling, including font-size bounds and fallback. | TBD at review | TODO |
| IHC-102 | IHC:775-789,793-797,799-815 | Required sibling row: accessibility lookup, `fixSpace`, and execute-provider command/model-reference cluster. | TBD at review | TODO |
| IHC-103 | IHC:309-311,394 | Session owns all gesture installs; the double-click update callback schedules the request with delay `0`. | TBD at review | TODO |
| IHF-001 | IHF:16-18 | `InlayHintAnchor` retains exact range and direction `before`/`after`. | TBD at review | TODO |
| IHF-002 | IHF:22-23 | Item resolve state starts false/undefined. | TBD at review | TODO |
| IHF-003 | IHF:25 | Item retains hint, anchor, and provider. | TBD at review | TODO |
| IHF-004 | IHF:27-28 | `with` creates same hint/provider with replacement anchor. | TBD at review | TODO |
| IHF-005 | IHF:29-31 | `with` preserves resolve flag/promise before return. | TBD at review | TODO |
| IHF-006 | IHF:70 | Frozen empty list has empty hints and no-op disposer. | TBD at review | TODO |
| IHF-007 | IHF:72-74 | `create` accumulates list/provider pairs. | TBD at review | TODO |
| IHF-008 | IHF:76 | Providers come from `ordered(model).reverse()`. | TBD at review | TODO |
| IHF-009 | IHF:76 | Every provider fans out over every requested range. | TBD at review | TODO |
| IHF-010 | IHF:77-78 | Each call receives captured model, one range, same token. | TBD at review | TODO |
| IHF-011 | IHF:79 | Response retained only with hints or provider change event. | TBD at review | TODO |
| IHF-012 | IHF:80 | Missing retained result uses frozen empty list. | TBD at review | TODO |
| IHF-013 | IHF:82-84 | Each provider/range failure is independently contained. | TBD at review | TODO |
| IHF-014 | IHF:87 | Flattened `Promise.all` waits for all calls. | TBD at review | TODO |
| IHF-015 | IHF:89-91 | After all settle, cancel or disposed model throws `CancellationError`. | TBD at review | TODO |
| IHF-016 | IHF:93 | Live result constructs fragments from ranges/data/model. | TBD at review | TODO |
| IHF-017 | IHF:96 | Fragments owns provider lists in a `DisposableStore`. | TBD at review | TODO |
| IHF-018 | IHF:98-100 | Readonly result is items, ranges, deduplicated providers. | TBD at review | TODO |
| IHF-019 | IHF:102-105 | Constructor stores ranges, new provider set, empty items. | TBD at review | TODO |
| IHF-020 | IHF:106 | Pairs process in accumulation order. | TBD at review | TODO |
| IHF-021 | IHF:107 | Every returned list enters disposable store. | TBD at review | TODO |
| IHF-022 | IHF:108 | Every contributing provider enters set. | TBD at review | TODO |
| IHF-023 | IHF:110 | Every list hint converts to an item. | TBD at review | TODO |
| IHF-024 | IHF:112 | Hint position is model-validated. | TBD at review | TODO |
| IHF-025 | IHF:113 | Anchor direction defaults `before`. | TBD at review | TODO |
| IHF-026 | IHF:115-116 | Anchoring consults `_getRangeAtPosition`. | TBD at review | TODO |
| IHF-027 | IHF:118-120 | Word start before hint yields start-to-hint range and `after`. | TBD at review | TODO |
| IHF-028 | IHF:121-124 | Otherwise hint-to-word-end range remains `before`. | TBD at review | TODO |
| IHF-029 | IHF:126 | Item retains original hint, computed anchor, provider. | TBD at review | TODO |
| IHF-030 | IHF:129 | Items sort by hint position. | TBD at review | TODO |
| IHF-031 | IHF:132-134 | Dispose retires every retained provider list. | TBD at review | TODO |
| IHF-032 | IHF:136-142 | Exact word range is preferred and returns early. | TBD at review | TODO |
| IHF-033 | IHF:144 | No word calls `tokenizeIfCheap(line)`. | TBD at review | TODO |
| IHF-034 | IHF:145-147 | Column becomes zero-based offset; token index is found. | TBD at review | TODO |
| IHF-035 | IHF:149-150 | Initial bounds are selected token offsets. | TBD at review | TODO |
| IHF-036 | IHF:152-153 | Neighbor adjustment only for token length `1`. | TBD at review | TODO |
| IHF-037 | IHF:154-157 | Leading adjustment requires start=offset and index greater than `1`. | TBD at review | TODO |
| IHF-038 | IHF:158-162 | Trailing adjustment requires end=offset and index below count minus `1`. | TBD at review | TODO |
| IHF-039 | IHF:165 | Offsets return as one-based columns via `+1`. | TBD at review | TODO |
| IHF-040 | IHF:34-65 | Explicit excluded sibling: inlay-item resolve serialization, cancellation, provider mutation, and error handling; review must record the final seam disposition. | TBD at review | TODO |
| IHF-041 | IHF:169-171 | Explicit excluded sibling: command-link URI construction. | TBD at review | TODO |
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
| CHC-120 | CHC:338-408 | Required excluded sibling: action, focus, scroll, content, accessibility, color-picker, and visibility forwarding cluster. | TBD at review | TODO |
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
| CHW-018 | CHW:27-51 | Inherited disposal retires registered widget/operation/emitter resources. | TBD at review | TODO |
| CHW-019 | CHW:53 | Participant initialization member. | TBD at review | TODO |
| CHW-020 | CHW:55 | Every registered participant constructor is visited. | TBD at review | TODO |
| CHW-021 | CHW:56-58 | Each participant is instantiated for editor then pushed. | TBD at review | TODO |
| CHW-022 | CHW:59 | Participants sort ascending by hover ordinal. | TBD at review | TODO |
| CHW-023 | CHW:60-62 | Widget resize forwards to optional participant handlers. | TBD at review | TODO |
| CHW-024 | CHW:63-65 | Widget scroll forwards to optional participant handlers. | TBD at review | TODO |
| CHW-025 | CHW:66-68 | Widget content change forwards to optional handlers. | TBD at review | TODO |
| CHW-026 | CHW:69 | Initialization returns ordered participants. | TBD at review | TODO |
| CHW-027 | CHW:72 | Listener-registration member. | TBD at review | TODO |
| CHW-028 | CHW:73-76 | Operation result subscription owns reconciliation entry. | TBD at review | TODO |
| CHW-029 | CHW:74 | Loading flag chooses augmented messages vs raw values. | TBD at review | TODO |
| CHW-030 | CHW:75 | Result wraps messages/completeness/options before reconciliation. | TBD at review | TODO |
| CHW-031 | CHW:78-82 | Widget keydown DOM listener is disposable-owned. | TBD at review | TODO |
| CHW-032 | CHW:79-81 | Escape hides. | TBD at review | TODO |
| CHW-033 | CHW:83-85 | Widget mouseleave listener delegates. | TBD at review | TODO |
| CHW-034 | CHW:86-90 | Tokenization registry listener is owned. | TBD at review | TODO |
| CHW-035 | CHW:87-89 | Existing position and result rerender same result. | TBD at review | TODO |
| CHW-036 | CHW:91-93 | Widget content event fires wrapper event. | TBD at review | TODO |
| CHW-037 | CHW:99-105 | Start-or-update member consumes anchor/mode/source/focus/mouse. | TBD at review | TODO |
| CHW-038 | CHW:106 | Visibility requires widget position and current result. | TBD at review | TODO |
| CHW-039 | CHW:107-113 | Invisible branch starts only with anchor. | TBD at review | TODO |
| CHW-040 | CHW:108-111 | Invisible with anchor starts operation and returns true. | TBD at review | TODO |
| CHW-041 | CHW:112 | Invisible without anchor returns false. | TBD at review | TODO |
| CHW-042 | CHW:114-116 | Sticky and mouse-getting-closer facts combine. | TBD at review | TODO |
| CHW-043 | CHW:119-124 | Closer branch preserves visible result. | TBD at review | TODO |
| CHW-044 | CHW:120-122 | Closer with anchor starts update with insist=true. | TBD at review | TODO |
| CHW-045 | CHW:123 | Closer branch returns true even without anchor. | TBD at review | TODO |
| CHW-046 | CHW:126-129 | No anchor clears result and returns false. | TBD at review | TODO |
| CHW-047 | CHW:131-134 | Equal current anchor returns true without restart. | TBD at review | TODO |
| CHW-048 | CHW:136 | Compatibility asks new anchor to adopt prior visible hover. | TBD at review | TODO |
| CHW-049 | CHW:137-141 | Incompatible anchor clears result then starts fresh. | TBD at review | TODO |
| CHW-050 | CHW:144-146 | Compatible anchor filters current result. | TBD at review | TODO |
| CHW-051 | CHW:147-148 | Compatible path starts new operation and returns true. | TBD at review | TODO |
| CHW-052 | CHW:151 | Operation-start-if-necessary member. | TBD at review | TODO |
| CHW-053 | CHW:152-155 | Same operation anchor returns early. | TBD at review | TODO |
| CHW-054 | CHW:156 | Different anchor cancels previous operation first. | TBD at review | TODO |
| CHW-055 | CHW:157-162 | Options capture anchor/source/focus/insist. | TBD at review | TODO |
| CHW-056 | CHW:163 | Operation starts with supplied mode/options. | TBD at review | TODO |
| CHW-057 | CHW:166 | Current-result setter member. | TBD at review | TODO |
| CHW-058 | CHW:168-171 | Identical result object returns early. | TBD at review | TODO |
| CHW-059 | CHW:172-175 | Non-null empty result normalizes to null. | TBD at review | TODO |
| CHW-060 | CHW:176 | Normalized result replaces current field. | TBD at review | TODO |
| CHW-061 | CHW:177-181 | Non-null calls show boundary; null calls hide boundary. | TBD at review | TODO |
| CHW-062 | CHW:184 | Loading-message augmentation member. | TBD at review | TODO |
| CHW-063 | CHW:185 | Participants are checked in order. | TBD at review | TODO |
| CHW-064 | CHW:186-188 | Missing loading-message factory continues. | TBD at review | TODO |
| CHW-065 | CHW:189-192 | Null loading message continues. | TBD at review | TODO |
| CHW-066 | CHW:193 | First message appends to copied result and returns. | TBD at review | TODO |
| CHW-067 | CHW:195 | No participant message returns original value. | TBD at review | TODO |
| CHW-068 | CHW:198 | Result reconciliation member. | TBD at review | TODO |
| CHW-069 | CHW:199 | Previous visible complete result is detected. | TBD at review | TODO |
| CHW-070 | CHW:200-202 | Without previous complete result, incoming result is applied. | TBD at review | TODO |
| CHW-071 | CHW:204-208 | Incomplete replacement returns, preserving previous complete result. | TBD at review | TODO |
| CHW-072 | CHW:209-215 | Empty complete result with insist flag preserves previous hover. | TBD at review | TODO |
| CHW-073 | CHW:216 | All other complete results apply. | TBD at review | TODO |
| CHW-074 | CHW:249 | `showsOrWillShow` member. | TBD at review | TODO |
| CHW-075 | CHW:250-253 | Resizing returns true without recomputation. | TBD at review | TODO |
| CHW-076 | CHW:254-256 | Code-action widget hit returns true. | TBD at review | TODO |
| CHW-077 | CHW:257 | Anchor candidates are computed. | TBD at review | TODO |
| CHW-078 | CHW:258-261 | No candidate delegates null delayed mouse update. | TBD at review | TODO |
| CHW-079 | CHW:262-263 | First highest-priority candidate delegates delayed mouse update. | TBD at review | TODO |
| CHW-080 | CHW:266 | Anchor-candidate finder member. | TBD at review | TODO |
| CHW-081 | CHW:268-271 | Participant without suggester continues. | TBD at review | TODO |
| CHW-082 | CHW:272-275 | Null participant suggestion continues. | TBD at review | TODO |
| CHW-083 | CHW:276 | Valid participant suggestion is pushed. | TBD at review | TODO |
| CHW-084 | CHW:280-283 | Content-text target adds priority `0` range anchor. | TBD at review | TODO |
| CHW-085 | CHW:284-285 | Content-empty threshold is halfwidth character width divided by `2`. | TBD at review | TODO |
| CHW-086 | CHW:287-289 | Empty target qualifies only within lines, numeric distance, distance below epsilon. | TBD at review | TODO |
| CHW-087 | CHW:290-292 | Failed empty-target qualification breaks that switch arm. | TBD at review | TODO |
| CHW-088 | CHW:293-294 | Qualified empty target adds priority `0` range anchor. | TBD at review | TODO |
| CHW-089 | CHW:297 | Candidates sort descending by priority. | TBD at review | TODO |
| CHW-090 | CHW:298 | Finder returns sorted candidates. | TBD at review | TODO |
| CHW-091 | CHW:301 | Code-action hit-test member. | TBD at review | TODO |
| CHW-092 | CHW:302-306 | Element with closest `.action-widget` returns true; otherwise false. | TBD at review | TODO |
| CHW-093 | CHW:309 | Mouse-leave member. | TBD at review | TODO |
| CHW-094 | CHW:310-314 | Missing editor DOM or outside position hides; a mouseleave point still inside the editor is a no-op. | TBD at review | TODO |
| CHW-095 | CHW:317-319 | Range start builds priority `0` anchor with undefined mouse coordinates. | TBD at review | TODO |
| CHW-096 | CHW:398 | Public hide member. | TBD at review | TODO |
| CHW-097 | CHW:399-400 | Hide cancels operation before clearing result. | TBD at review | TODO |
| CHW-098 | CHW:279-296 | Implicit switch default: every other mouse target type adds no built-in range anchor. | TBD at review | TODO |
| CHW-099 | CHW:219-246 | Required excluded sibling: DOM render, hide-render, and hover-context construction cluster. | TBD at review | TODO |
| CHW-100 | CHW:321-397 | Required excluded sibling: content, verbosity, accessibility, focus, and scroll forwarding cluster. | TBD at review | TODO |
| CHW-101 | CHW:403-429 | Required excluded sibling: DOM and widget-state query/getter cluster. | TBD at review | TODO |
| HOP-001 | HOP:18 | `IHoverComputer.computeAsync` receives token after half delay. | TBD at review | TODO |
| HOP-002 | HOP:22 | `computeSync` runs after full delay. | TBD at review | TODO |
| HOP-003 | HOP:25-26 | Operation state `Idle` has implicit value `0`. | TBD at review | TODO |
| HOP-004 | HOP:27 | Operation state `FirstWait` has implicit value `1`. | TBD at review | TODO |
| HOP-005 | HOP:28 | Operation state `SecondWait` has implicit value `2`. | TBD at review | TODO |
| HOP-006 | HOP:29 | Operation state `WaitingForAsync = 3`. | TBD at review | TODO |
| HOP-007 | HOP:30 | Operation state `WaitingForAsyncShowingLoading = 4`. | TBD at review | TODO |
| HOP-008 | HOP:33-35 | Start mode `Delayed = 0`. | TBD at review | TODO |
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
| HOP-038 | HOP:110-114 | `_setState` stores options/state then fires. | TBD at review | TODO |
| HOP-039 | HOP:116-119 | Async trigger enters `SecondWait` and schedules sync remainder. | TBD at review | TODO |
| HOP-040 | HOP:120 | Async computer presence gates iterable creation. | TBD at review | TODO |
| HOP-041 | HOP:121-123 | Fresh cancelable iterable propagates its token to computer. | TBD at review | TODO |
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
| HOP-057 | HOP:168 | Emission copies accumulated result with `slice(0)`. | TBD at review | TODO |
| HOP-058 | HOP:171 | Public start member. | TBD at review | TODO |
| HOP-059 | HOP:172 | Delayed mode branch. | TBD at review | TODO |
| HOP-060 | HOP:173-177 | Delayed start acts only from `Idle`; other states no-op. | TBD at review | TODO |
| HOP-061 | HOP:174-176 | Delayed start enters first wait and schedules async/loading timers. | TBD at review | TODO |
| HOP-062 | HOP:178-184 | Immediate start `Idle` case. | TBD at review | TODO |
| HOP-063 | HOP:181-183 | Immediate order: trigger async, cancel sync timer, trigger sync. | TBD at review | TODO |
| HOP-064 | HOP:185-188 | Immediate `SecondWait` case. | TBD at review | TODO |
| HOP-065 | HOP:186-187 | Second-wait immediate start cancels sync timer then triggers sync. | TBD at review | TODO |
| HOP-066 | HOP:179-189 | All other immediate states have no switch arm and no-op. | TBD at review | TODO |
| HOP-067 | HOP:193 | Public cancel member. | TBD at review | TODO |
| HOP-068 | HOP:194-196 | Cancel retires async, sync, and loading schedulers. | TBD at review | TODO |
| HOP-069 | HOP:197-200 | Cancel retires/nulls an active iterable; absent iterable skips both operations. | TBD at review | TODO |
| HOP-070 | HOP:201 | Cancel clears accumulated result. | TBD at review | TODO |
| HOP-071 | HOP:202 | Cancel clears options. | TBD at review | TODO |
| HOP-072 | HOP:203 | Cancel returns state to `Idle`. | TBD at review | TODO |
| HOP-073 | HOP:206-208 | Options getter returns current optional options. | TBD at review | TODO |
| HOP-074 | HOP:213 | Debouncer owns one run-once scheduler. | TBD at review | TODO |
| HOP-075 | HOP:215 | Debouncer retains latest options. | TBD at review | TODO |
| HOP-076 | HOP:217-220 | Constructor registers scheduler closure and default delay. | TBD at review | TODO |
| HOP-077 | HOP:222-225 | Schedule stores options then schedules requested delay. | TBD at review | TODO |
| HOP-078 | HOP:227-229 | Cancel delegates scheduler cancellation. | TBD at review | TODO |
| HOP-079 | HOP:211-230 | Inherited disposal retires the registered scheduler. | TBD at review | TODO |
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
| CHCMP-024 | CHCMP:76-83 | Participant producers merge. | TBD at review | TODO |
| CHCMP-025 | CHCMP:78-80 | Participant without async member contributes empty producer. | TBD at review | TODO |
| CHCMP-026 | CHCMP:81 | Participant async call receives anchor, decorations, source, token. | TBD at review | TODO |
| CHCMP-027 | CHCMP:86 | Synchronous computation member. | TBD at review | TODO |
| CHCMP-028 | CHCMP:87-89 | Missing editor model returns empty. | TBD at review | TODO |
| CHCMP-029 | CHCMP:91-92 | Sync path captures anchor and decorations. | TBD at review | TODO |
| CHCMP-030 | CHCMP:94-97 | Participant sync results concatenate in participant order. | TBD at review | TODO |
| CHCMP-031 | CHCMP:99 | Final sync result coalesces nullish entries. | TBD at review | TODO |
| GHR-001 | GHR:18 | Provider-result `provider` member. | TBD at review | TODO |
| GHR-002 | GHR:19 | Provider-result `hover` member. | TBD at review | TODO |
| GHR-003 | GHR:20 | Provider-result `ordinal` member. | TBD at review | TODO |
| GHR-004 | GHR:16-21 | Constructor retains provider, hover, ordinal. | TBD at review | TODO |
| GHR-005 | GHR:27 | `executeProvider` member. | TBD at review | TODO |
| GHR-006 | GHR:28-30 | Provider invocation receives model, position, token; no post-await cancellation check follows. | TBD at review | TODO |
| GHR-007 | GHR:30 | Returned-promise rejection is contained as undefined; a synchronous provider throw rejects `executeProvider` itself. | TBD at review | TODO |
| GHR-008 | GHR:31-33 | Missing or invalid result returns undefined. | TBD at review | TODO |
| GHR-009 | GHR:34 | Valid result constructs provider result with ordinal. | TBD at review | TODO |
| GHR-010 | GHR:37 | Async-iterable member defaults `recursive=false`. | TBD at review | TODO |
| GHR-011 | GHR:38 | Registry providers are ordered for model/recursive flag. | TBD at review | TODO |
| GHR-012 | GHR:39 | Provider index becomes stable ordinal. | TBD at review | TODO |
| GHR-013 | GHR:40 | Promise producer yields in resolution order. | TBD at review | TODO |
| GHR-014 | GHR:40 | Undefined failures are coalesced out. | TBD at review | TODO |
| GHR-015 | GHR:43 | `getHoversPromise` member defaults `recursive=false`. | TBD at review | TODO |
| GHR-016 | GHR:44 | Output array starts empty. | TBD at review | TODO |
| GHR-017 | GHR:45 | Async iterable is consumed to completion. | TBD at review | TODO |
| GHR-018 | GHR:46 | Each valid item contributes its hover. | TBD at review | TODO |
| GHR-019 | GHR:48 | Collected hovers return in resolution order. | TBD at review | TODO |
| GHR-020 | GHR:51-54 | Command `_executeHoverProvider` uses `CancellationToken.None`. | TBD at review | TODO |
| GHR-021 | GHR:56-59 | Command `_executeHoverProvider_recursive` uses `None` and recursive `true`. | TBD at review | TODO |
| GHR-022 | GHR:61 | Hover validity member. | TBD at review | TODO |
| GHR-023 | GHR:62 | Range must be defined. | TBD at review | TODO |
| GHR-024 | GHR:63 | Contents must be defined, truthy, and nonempty. | TBD at review | TODO |
| GHR-025 | GHR:64 | Validity is range AND content predicates. | TBD at review | TODO |
| HTY-001 | HTY:21 | Hover part retains owner participant. | TBD at review | TODO |
| HTY-002 | HTY:25 | Hover part retains applicable range. | TBD at review | TODO |
| HTY-003 | HTY:30 | Optional force-show-at-range member. | TBD at review | TODO |
| HTY-004 | HTY:35 | Optional before-content ordering member. | TBD at review | TODO |
| HTY-005 | HTY:39 | Part validity member consumes new anchor. | TBD at review | TODO |
| HTY-006 | HTY:42-44 | Anchor type `Range = 1`. | TBD at review | TODO |
| HTY-007 | HTY:44 | Anchor type `ForeignElement = 2`. | TBD at review | TODO |
| HTY-008 | HTY:48 | Range anchor constant type. | TBD at review | TODO |
| HTY-009 | HTY:50 | Range anchor priority member. | TBD at review | TODO |
| HTY-010 | HTY:51 | Range anchor range member. | TBD at review | TODO |
| HTY-011 | HTY:52 | Range anchor initial mouse X member. | TBD at review | TODO |
| HTY-012 | HTY:53 | Range anchor initial mouse Y member. | TBD at review | TODO |
| HTY-013 | HTY:49-55 | Range anchor constructor retains fields. | TBD at review | TODO |
| HTY-014 | HTY:56-58 | Range equality requires range type and equal range. | TBD at review | TODO |
| HTY-015 | HTY:59-61 | Range adoption requires prior range and same start line. | TBD at review | TODO |
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
| HTY-030 | HTY:166 | Async computation receives cancellation token. | TBD at review | TODO |
| HTY-031 | HTY:167 | Optional loading-message member. | TBD at review | TODO |
| HTY-032 | HTY:176 | Participant constructor signature consumes editor. | TBD at review | TODO |
| HTY-033 | HTY:180 | Registry owns participant constructor array. | TBD at review | TODO |
| HTY-034 | HTY:182-184 | Register appends constructor. | TBD at review | TODO |
| HTY-035 | HTY:186-188 | `getAll` returns registry array. | TBD at review | TODO |
| HTY-036 | HTY:198 | Widget `showsOrWillShow` member. | TBD at review | TODO |
| HTY-037 | HTY:203 | Widget `hide` member. | TBD at review | TODO |
| HTY-038 | HTY:85-159 | Explicit excluded sibling: status/action/color/context/rendered-hover types and implementation. | TBD at review | TODO |
| HTY-039 | HTY:163,168-174 | Explicit excluded sibling: copy-button and render/accessibility/resize/hide/contents/scroll participant affordances. | TBD at review | TODO |
| HTY-040 | HTY:178-190 | Exported `HoverParticipantRegistry` singleton constant constructs the anonymous registry class instance. | TBD at review | TODO |
| TMV-001 | TMV:123 | Module model-identity counter starts `0`. | TBD at review | TODO |
| TMV-002 | TMV:250,252 | Each model retains public `id` and private associated resource fields. | TBD at review | TODO |
| TMV-003 | TMV:318-319 | Construction pre-increments `MODEL_ID`, then assigns `$model` plus the counter; the first ID is `$model1`. | TBD at review | TODO |
| TMV-004 | TMV:309,321-325 | Null/undefined default creates exactly `inmemory://model/` plus `MODEL_ID`; otherwise supplied URI is retained exactly. | TBD at review | TODO |
| TMV-005 | TMV:671-673 | Public URI getter returns associated resource without a disposed guard. | TBD at review | TODO |
| TMV-006 | TMV:262-266 | `_versionId` and `_alternativeVersionId` are distinct; the alternative may decrease or repeat. | TBD at review | TODO |
| TMV-007 | TMV:370-371 | Construction initializes both version fields to `1`. | TBD at review | TODO |
| TMV-008 | TMV:737-738 | `getVersionId` first asserts model is not disposed. | TBD at review | TODO |
| TMV-009 | TMV:739 | `getVersionId` returns internal version. | TBD at review | TODO |
| TMV-010 | TMV:782-783 | Increase increments by exactly `1`. | TBD at review | TODO |
| TMV-011 | TMV:784 | Same increase mirrors new value to alternative version. | TBD at review | TODO |
| TMV-012 | TMV:521-545 | `setValue` has no equality no-op: buffer swaps before exactly one increment, which precedes reset/events. | TBD at review | TODO |
| TMV-013 | TMV:547-552 | Equal EOL returns with no mutation, increment, or event. | TBD at review | TODO |
| TMV-014 | TMV:560-575 | Changed EOL increments after mutation and before post-EOL/event work. | TBD at review | TODO |
| TMV-015 | TMV:1506,1509,1512,1599-1601 | Empty content changes skip mutation/increment/event but still return reverse edits. | TBD at review | TODO |
| TMV-016 | TMV:1513-1524 | Nonempty edit batch transforms decorations then increments exactly once. | TBD at review | TODO |
| TMV-017 | TMV:1579-1595 | Only nonempty edit flow emits raw/public events carrying the post-increment version. | TBD at review | TODO |
| TMV-018 | TMV:787-789 | `_overwriteVersionId` directly assigns supplied version and may decrease or reuse it. | TBD at review | TODO |
| CTS-001 | CTS:9-15 | Token contract exposes readonly cancellation flag. | TBD at review | TODO |
| CTS-002 | CTS:16-24 | Cancellation event contract covers listener, `thisArgs`, optional disposable bucket, once-only fire, and next-turn late listeners. | TBD at review | TODO |
| CTS-003 | CTS:27-30 | Shortcut event schedules timeout `0`; disposal clears it. | TBD at review | TODO |
| CTS-004 | CTS:49-52 | `None` is frozen, false, and uses `Event.None`. | TBD at review | TODO |
| CTS-005 | CTS:54-57 | `Cancelled` is frozen, true, and uses shortcut event. | TBD at review | TODO |
| CTS-006 | CTS:62 | Mutable canceled state starts false. | TBD at review | TODO |
| CTS-007 | CTS:63 | Mutable emitter starts null and lazy. | TBD at review | TODO |
| CTS-008 | CTS:65-67 | Already-canceled call is a no-op; first cancel flips the flag before notification. | TBD at review | TODO |
| CTS-009 | CTS:68-71 | Missing emitter skips notification; existing emitter fires once then disposes. | TBD at review | TODO |
| CTS-010 | CTS:75-77 | State getter returns flag. | TBD at review | TODO |
| CTS-011 | CTS:79-82 | Event getter returns shortcut after cancellation. | TBD at review | TODO |
| CTS-012 | CTS:83-86 | Before cancellation, event getter creates emitter only if absent, reuses it, and returns its event. | TBD at review | TODO |
| CTS-013 | CTS:89-94 | Dispose with no emitter is a no-op; otherwise emitter disposes/resets null while cancellation flag is unchanged. | TBD at review | TODO |
| CTS-014 | CTS:99 | Source token starts undefined. | TBD at review | TODO |
| CTS-015 | CTS:100 | Parent listener starts undefined and is source-owned. | TBD at review | TODO |
| CTS-016 | CTS:102-104 | Absent parent installs no listener; present parent subscribes `this.cancel` with source context. | TBD at review | TODO |
| CTS-017 | CTS:106-113 | Token getter lazily creates a mutable token; existing mutable or shared singleton token is returned unchanged. | TBD at review | TODO |
| CTS-018 | CTS:115-121 | Cancel-before-token assigns shared `Cancelled` without allocation. | TBD at review | TODO |
| CTS-019 | CTS:122-125 | Existing `MutableToken` cancels; existing `None` or `Cancelled` singleton cases are no-ops. | TBD at review | TODO |
| CTS-020 | CTS:128-131 | Default `false` skips cancel; `true` performs cancel first. | TBD at review | TODO |
| CTS-021 | CTS:132 | Optional parent listener disposes, but field is not cleared, so repeated dispose repeats that call. | TBD at review | TODO |
| CTS-022 | CTS:133-136 | `dispose(false)` before token read stores shared `None`; later cancel is a no-op. | TBD at review | TODO |
| CTS-023 | CTS:137-140 | Mutable dispose retires listeners but keeps same token/flag; singleton cases are no-ops. | TBD at review | TODO |
<!-- SOURCE_LEDGER_END -->

Mechanical review gate: stop after this inventory/ledger documentation
milestone. No product or test code is authorized by this status.

### Separate local ownership audit

The local audit has **87 rows** and is deliberately outside the 581-row
pinned-source denominator. It records current implementation and test authority;
it does not pre-approve any target mapping or deviation.

| ID | Area | Local owner | Current behavior / audit finding |
|---|---|---|---|
| LA-001 | Identity | `viewer/common/model/text_model.mbt:5-14` | Model retains URI, caller-host `version`, `revision`, and snapshot as separate facts. |
| LA-002 | Identity | `viewer/common/model/text_model.mbt:23-26` | Internal mutable `version_id` already exists and is distinct from host `version`. |
| LA-003 | Identity | `viewer/common/model/text_model.mbt:91` | Construction initializes internal version to exactly `1`. |
| LA-004 | Identity | `viewer/common/model/text_model.mbt:449-455` | `get_version_id` returns internal version without a dispose assertion. |
| LA-005 | Identity | `viewer/common/model/text_model.mbt:458-462` | `increase_version_id` adds exactly `1`; alternative-version mirroring is absent. |
| LA-006 | Identity | `viewer/common/model/text_model.mbt:558-593` | Whole-value replacement orders snapshot swap, one version increment, decoration clear, then raw/public flush emission. |
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
| LA-029 | Inlay | `viewer/common/languages/languages.mbt:182-195` | Every provider receives the same token and captured range sequentially in registry order. |
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
| LA-046 | Inlay | `viewer/common/languages/languages.mbt:19-32,109-116,184-197` | Registry exposes no observed change event; disposing an in-flight provider removes it from registry but its post-await result is still accepted. |
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
| LA-059 | Hover | `viewer/common/languages/languages.mbt:128-144` | Providers run sequentially and return first nonempty result. |
| LA-060 | Hover | `viewer/common/languages/languages.mbt:133-142` | Provider failures are contained/logged; scan continues on `None`. |
| LA-061 | Hover | `viewer/editor_events.mbt:493-506` | Async item compares only current-model helper plus integer token; no anchor, physical identity, internal version, generation, or cancellation state. |
| LA-062 | Hover | `viewer/editor_events.mbt:509-522` | Async done has the same helper/token-only guard before completion/notification. |
| LA-063 | Hover | `viewer/common/model/text_model.mbt:155-163` | Physical same-URI/version replacement can pass both hover guards. |
| LA-064 | Hover | `viewer/editor_events.mbt:410-419` | Sync timer rejects a mismatched token only; a reused equal token passes compute/apply. |
| LA-065 | Hover | `viewer/editor_events.mbt:424-432` | Loading timer rejects a mismatched token only; a reused equal token passes state change. |
| LA-066 | Hover | `viewer/editor_events.mbt:524-541` | Notification requires matching token, completion, and not-yet-notified token. |
| LA-067 | Hover | `viewer/attach_model.mbt:58-69; viewer/hover_contribution.mbt:14-92` | Content event fires, but hover contribution has no content-cancel subscription. |
| LA-068 | Hover | `viewer/viewer.mbt:660-691` | Detach empties hover, cancels react generation, resets inlay, disposes model bundle. |
| LA-069 | Hover | `viewer/contrib/hover/browser/content_hover_controller.mbt:125-133` | Controller model reset clears only hover decoration IDs/range. |
| LA-070 | Hover | `viewer/hover_contribution.mbt:14-27` | Contribution disposal removes instance but owns no task/timer handles. |
| LA-071 | Hover | `viewer/viewer.mbt:855-900` | Viewer disposal detaches, disposes contributions, then retires hover widget state. |
| LA-072 | Hover | `viewer/viewer.mbt:140-167` | `ModelData.dispose` retires swap listeners/view/view model, not async features. |
| LA-073 | Hover | `viewer/editor_events.mbt:60-80,367-405,475-490` | After cancel/detach, timers/tasks run; guards suppress some effects but do not cancel resources. |
| LA-074 | Hover | `viewer/contrib/hover/hover_controller_wbtest.mbt:31-130; viewer/contrib/hover/hover_reconciliation_wbtest.mbt:1-175; viewer/contrib/hover/content_hover_computer_wbtest.mbt:18-64; viewer/common/languages/languages_registry_wbtest.mbt:18-37` | Existing authority is pure monotonic-controller transitions, within-model reconciliation, immediate computer results, and provider-failure logging; no deterministic deferred Viewer-path race covers set_value, replacement/reuse, detach/dispose, or cancellation. |
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
| LA-085 | Inlay | `viewer/common/languages/languages_registry_wbtest.mbt:18-72; language/cancellation.mbt:1-31` | Language tests cover hover failure/order only; there is no inlay aggregation or cancellation-token test. |
| LA-086 | Inlay | `tests/browser/moonbit/component/viewer_api_scenario.mbt:62-73,98-116; tests/browser/component/viewer_api.spec.js:56-71` | Browser authority is an immediate token-ignoring happy path only: no delay, cancel, dispose, failure, or multi-provider case. |
| LA-087 | Inlay | `viewer/lifecycle_ownership_wbtest.mbt:69-108,168-188; tests/browser/moonbit/model_swap/model_swap_scenario.mbt:99-228` | Detach/dispose are tested without a pending inlay request, so they prove neither cancellation nor stale-result rejection. |


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

- [x] inventory rows equal ledger rows: 581/581; TODO 581, done/deferred/N-A 0/0/0
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

### 2026-07-10 — Phase 1–2 inventory stop gate

- Verified the read-only VS Code oracle at
  `b18492a288de038fbc7643aae6de8247029d11bd`.
- Read every closed source unit/cluster and recorded exact exclusions and
  runtime seams. Excluded-but-required sibling clusters remain first-class TODO
  rows; no prose-only exclusion is being counted as parity.
- Source inventory/ledger: **581/581** rows, all `TODO`:
  `IHC 103, IHF 41, CHC 120, CHW 101, HOP 79, CHCMP 31, GHR 25, HTY 40,
  TMV 18, CTS 23`.
- Separate current-MoonBit ownership audit: **87** rows (`LA-001`–`LA-087`).
  It records two unretained `async_run` launches, four raw hover timer sites,
  model/content subscriptions, operation/react tokens, result guards,
  decoration applies, reset paths, and detach/dispose ordering.
- Mechanical verification passed: per-prefix counts, 581 source IDs and 87
  local IDs are contiguous, all 581 source rows end `TODO`, `git diff --check`
  is clean, and the diff is confined to this plan.
- No product or test file changed and no runtime tests were run for this
  documentation-only stop gate. Commit/approval remains for the parent
  milestone.

**STOP FOR REVIEW.** No implementation is authorized until every TODO row has
a reviewed target/status and the inventory milestone is committed.
