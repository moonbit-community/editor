# Viewer Async Model Features Parity

Status: implemented

Date: 2026-07-10

Oracle: checked-in reference tree

Parent: viewer-monaco-parity-remediation.md

Finding: P1-03

Depends on: viewer-model-lifecycle-ownership-parity.md. The later EOL plan must
land before provider-surface/P2 work, but does not block request cancellation.

Product work followed the reviewed target/disposition map and test matrix
below. The source ledger now records the closing evidence dispositions.

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

The source denominator is closed at the checked-in source. Line ranges below are
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

The authoritative normalized whole-unit reread produced **810 source inventory
members**:

`IHC 232 + IHF 49 + CHC 132 + CHW 132 + HOP 75 + CHCMP 26 + GHR 16 + HTY 67 + TMV 26 + CTS 55 = 810`.

The uniform counting rule is one row per declared member, behavior-changing
branch/early return, independently reused/control-flow magic constant, owned
DOM/CSS/custom property, and source-owned nested/object callback. A property
row carries its exact literal/arithmetic without double-counting that value;
straight-line non-callback order stays on its member row, and a plain
constructor parameter is not a field. Excluded sibling members use the same
rule. Every `MoonBit symbol` cell references the approved grouped target map
below. Every working status stayed `TODO` through Gate B; the terminal values
now reflect landed implementation and closing-review evidence.

Abbreviations: `IHC` = `inlayHintsController.ts`; `IHF` = `inlayHints.ts`;
`CHC` = `contentHoverController.ts`; `CHW` =
`contentHoverWidgetWrapper.ts`; `HOP` = `hoverOperation.ts`; `CHCMP` =
`contentHoverComputer.ts`; `GHR` = `getHover.ts`; `HTY` = `hoverTypes.ts`;
`TMV` = `textModel.ts`; `CTS` = `cancellation.ts`.

| ID | Source member (file:line) | Arithmetic/transition | MoonBit symbol | Status |
|---|---|---|---|---|
| IHC-001 | IHC:45 | `_serviceBrand` DI brand field. | See Gate B target map | N-A (TypeScript DI brand) |
| IHC-002 | IHC:47 | `_entries` owns the inlay-item LRU cache with exact capacity `50`. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-003 | IHC:49-52 | `get(model)` derives one cache key, then returns that lookup. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-004 | IHC:54-57 | `set(model,value)` derives one cache key, then inserts/replaces. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-005 | IHC:59-61 | `_key(model)` concatenates URI text, exact separator `/`, and `getVersionId()` in that order. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-006 | IHC:64 | `IInlayHintsCache` is the service interface extending `InlayHintsCache`. | See Gate B target map | N-A (TypeScript service interface/decorator/singleton registration) |
| IHC-007 | IHC:65-66 | `IInlayHintsCache` decorator constant uses exact ID `IInlayHintsCache` and is registered as a delayed singleton. | See Gate B target map | N-A (TypeScript service interface/decorator/singleton registration) |
| IHC-008 | IHC:71 | Rendered label-part `item` parameter-property. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-009 | IHC:71 | Rendered label-part `index` parameter-property. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-010 | IHC:71 | `RenderedInlayHintLabelPart` constructor retains item and index. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-011 | IHC:73-80 | `part` getter reads the hint label and returns one label part. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-012 | IHC:75-79 | String labels become `{ label }`; structured labels select the exact indexed part. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-013 | IHC:84 | Active-label `part` parameter-property. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-014 | IHC:84 | Active-label `hasTriggerModifier` parameter-property. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-015 | IHC:84 | `ActiveInlayHintInfo` constructor retains part and modifier state. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-016 | IHC:88 | Decoration metadata retains the originating item. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-017 | IHC:89 | Decoration metadata retains the model delta decoration. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-018 | IHC:90 | Decoration metadata owns the disposable CSS class reference. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-019 | IHC:94 | `RenderMode.Normal` enum value. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-020 | IHC:95 | `RenderMode.Invisible` enum value. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-021 | IHC:105 | `CancellationStore._store` owns replaceable operation disposables. | See Gate B target map | DEFERRED (operation-store lifecycle absent) |
| IHC-022 | IHC:106 | `_tokenSource` starts as a fresh source. | See Gate B target map | DEFERRED (operation-store lifecycle absent) |
| IHC-023 | IHC:108-111 | `dispose` retires the operation store first, then disposes the token source with `cancel=true`. | See Gate B target map | DEFERRED (operation-store lifecycle absent) |
| IHC-024 | IHC:113-121 | `reset` cancels/disposes the old source, creates the new source, replaces and thereby disposes the old operation store, then returns the matching new store/token pair. | See Gate B target map | DEFERRED (operation-store lifecycle absent) |
| IHC-025 | IHC:131 | Static contribution-ID member is exactly `editor.contrib.InlayHints`. | See Gate B target map | PORTED |
| IHC-026 | IHC:133 | Static maximum-decoration member is exactly `1500`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-027 | IHC:134 | `_whitespaceData` is one shared empty-object sentinel. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-028 | IHC:136-138 | Static `get` reads this contribution from the editor. | See Gate B target map | PORTED |
| IHC-029 | IHC:137 | A nullish contribution is normalized to `undefined`. | See Gate B target map | PORTED |
| IHC-030 | IHC:140 | `_disposables` owns controller-lifetime resources. | See Gate B target map | TESTED |
| IHC-031 | IHC:141 | `_sessionDisposables` owns the current-model session. | See Gate B target map | TESTED |
| IHC-032 | IHC:142 | `_decorationsMetadata` owns active decoration metadata. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-033 | IHC:143 | `_debounceInfo` owns provider/model debounce state. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-034 | IHC:144 | `_ruleFactory` owns dynamic CSS rules. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-035 | IHC:146 | `_cursorInfo` stores cursor position plus absolute freshness deadline. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-036 | IHC:147 | `_activeRenderMode` starts `Normal`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-037 | IHC:148 | `_activeInlayHintPart` starts absent. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-038 | IHC:151 | `_editor` parameter-property owns the captured editor reference. | See Gate B target map | N-A (no separate service parameter-property seam) |
| IHC-039 | IHC:152 | Language-features service parameter-property owns the consulted registry. | See Gate B target map | N-A (no separate service parameter-property seam) |
| IHC-040 | IHC:154 | Inlay-cache parameter-property owns the fast-restore cache. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-041 | IHC:155 | Command-service parameter-property. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-042 | IHC:156 | Notification-service parameter-property. | See Gate B target map | N-A (no separate service parameter-property seam) |
| IHC-043 | IHC:157 | Instantiation-service parameter-property. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-044 | IHC:150-171 | Constructor creates the owned rule factory and debounce state, registers subscriptions in source order, then performs one immediate `_update`. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-045 | IHC:161 | Provider-registry change callback invokes `_update`. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-046 | IHC:162 | Editor-model change callback invokes `_update`. | See Gate B target map | TESTED |
| IHC-047 | IHC:163 | Model-language change callback invokes `_update`. | See Gate B target map | N-A (language ID is immutable per local model; replacement is IHC-046) |
| IHC-048 | IHC:164-168 | Constructor configuration callback owns the configuration-change dispatch. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-049 | IHC:160 | Debounce key is exactly `InlayHint`. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-050 | IHC:160 | Debounce minimum delay is exactly `25` ms. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-051 | IHC:165-167 | Constructor configuration branch invokes `_update` only when `EditorOption.inlayHints` changed. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-052 | IHC:173-177 | `dispose` retires the current session, removes every decoration, then retires controller-lifetime resources. | See Gate B target map | TESTED |
| IHC-053 | IHC:179-312 | `_update` clears session then decorations; establishes mode/cache/session; requests, applies, and caches in source order; then installs session subscriptions. | See Gate B target map | DEFERRED (complete update and cache lane absent) |
| IHC-054 | IHC:183-186 | The disabled-mode branch returns after cleanup. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-055 | IHC:184 | Disabled-mode protocol value is exactly `off`. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-056 | IHC:188-191 | Missing model or no matching provider returns after cleanup. | See Gate B target map | TESTED |
| IHC-057 | IHC:193-196 | The always-enabled branch selects normal rendering and skips modifier subscription. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-058 | IHC:193 | Always-enabled protocol value is exactly `on`. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-059 | IHC:196-222 | Every non-`on` mode enters default/alternate selection and installs the modifier subscription. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-060 | IHC:200-202 | The normal-unless-pressed branch selects normal default and invisible alternate. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-061 | IHC:200 | Normal-unless-pressed protocol value is exactly `onUnlessPressed`. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-062 | IHC:203-205 | The other non-`on` mode selects invisible default and normal alternate. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-063 | IHC:209-221 | Modifier callback owns render-mode recomputation. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-064 | IHC:210-212 | Modifier callback returns when the editor no longer has a model. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-065 | IHC:213 | Alt+Ctrl without Shift/Meta selects alternate mode; every other combination selects default. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-066 | IHC:214-220 | A changed render mode updates state, copies current anchors, replaces full-model decorations, then schedules refresh. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-067 | IHC:219 | Modifier-triggered refresh uses exact delay `0`. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-068 | IHC:224-228 | A truthy cache hit applies over the full captured-model range. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-069 | IHC:229-234 | Session-teardown callback owns fast-restore caching. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-070 | IHC:231-233 | Session teardown caches anchors only while the captured model is not disposed. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-071 | IHC:239 | Model-disposal callback invokes optional cancellation. | See Gate B target map | TESTED |
| IHC-072 | IHC:236-239 | Model disposal invokes cancellation when optional `cts` is present; absence is a no-op. | See Gate B target map | N-A (pinned dead optional-`cts` seam; real cancellation ownership is `H`) |
| IHC-073 | IHC:243-276 | Scheduler request passes the captured `model`, while `_getHintsRanges()` independently reads `editor.getModel()!` at execution time. | See Gate B target map | DEFERRED (viewport debounce scheduler absent) |
| IHC-074 | IHC:250-254 | Debounce delay updates before the post-await cancellation guard; cancellation disposes fragments and returns before mutation. | See Gate B target map | DEFERRED (viewport debounce scheduler absent) |
| IHC-075 | IHC:258-264 | Only providers with a change function and absent from `watchedProviders` are subscribed. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-076 | IHC:260-264 | Provider-change callback consults the session scheduler. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-077 | IHC:261-263 | Provider change schedules only while no run is already scheduled. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-078 | IHC:269 | Operation-store cleanup callback clears `watchedProviders`. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-079 | IHC:273-275 | Every thrown request error, including cancellation reaching this catch, is passed to `onUnexpectedError`. | See Gate B target map | N-A (cancellation is typed and silently contained) |
| IHC-080 | IHC:279 | First session request uses exact delay `0`. | See Gate B target map | TESTED |
| IHC-081 | IHC:281-288 | Scroll-change callback owns viewport-triggered scheduling. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-082 | IHC:285-287 | Scroll schedules when top changed or the scheduler is idle; otherwise it is a no-op. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-083 | IHC:291-300 | Content-change callback owns cancellation, cursor stabilization, timeout replacement, and debounced scheduling. | See Gate B target map | DEFERRED (cursor-stabilized content scheduler absent) |
| IHC-084 | IHC:292 | Content change invokes cancellation when optional `cts` is present; absence is a no-op. | See Gate B target map | N-A (pinned dead optional-`cts` seam; real cancellation ownership is `H`) |
| IHC-085 | IHC:294-296 | Content stabilization floor is exactly `800` ms via `max(scheduler.delay, 800)`. | See Gate B target map | N-A (typing cursor-delay runner) |
| IHC-086 | IHC:297 | Cursor-timeout callback schedules the immediate refresh. | See Gate B target map | N-A (typing cursor-delay runner) |
| IHC-087 | IHC:297 | Cursor-timeout refresh delay is exactly `0`. | See Gate B target map | N-A (typing cursor-delay runner) |
| IHC-088 | IHC:302-306 | Session-configuration callback owns option-triggered scheduling. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-089 | IHC:303-305 | Session configuration schedules only when `EditorOption.inlayHints` changed. | See Gate B target map | DEFERRED (inlay option/render-mode surface) |
| IHC-090 | IHC:314-368 | `_installLinkGesture` creates the owning stores and gesture, installs subscriptions, and returns the owner. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-091 | IHC:336 | Link-session disposal callback cancels and disposes its token source. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-092 | IHC:348-351 | Link-session cleanup callback clears active state and reapplies line decorations. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-093 | IHC:353 | Gesture-cancel callback clears the nested session store. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-094 | IHC:324-352 | Link mouse-move callback owns label/model lookup and link-session refresh. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-095 | IHC:329-332 | Missing label part or model clears the nested session and returns. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-096 | IHC:340-342 | Command or location creates active-label state; neither clears it. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-097 | IHC:354-366 | Gesture-execute callback owns location/command dispatch. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-098 | IHC:356-365 | Execute callback does work only when a label part exists. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-099 | IHC:358-360 | A location invokes go-to-definition. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-100 | IHC:361-364 | Otherwise a valid command is awaited through `_invokeCommand`. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-101 | IHC:370-378 | `_getInlineHintsForRange` deduplicates matching items in metadata iteration order. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-102 | IHC:373-375 | An item is added only when the requested range contains its anchor range. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-103 | IHC:380-396 | `_installDblClickGesture` installs the double-click resolve/edit/update listener. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-104 | IHC:309 | Session-owned double-click refresh callback schedules an immediate request. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-105 | IHC:309 | Double-click refresh delay is exactly `0`. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-106 | IHC:381-396 | Mouse-up callback owns double-click resolution and edit application. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-107 | IHC:382-384 | Non-double-click mouse-up returns before lookup. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-108 | IHC:382 | Double-click mouse-detail magic value is exactly `2`. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-109 | IHC:385-388 | Missing label part returns before prevent-default and resolve. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-110 | IHC:391-395 | Nonempty text edits execute replacement operations and then invoke the supplied refresh callback. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-111 | IHC:392 | Text-edit mapping callback lifts each edit range and creates its replacement operation. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-112 | IHC:393 | Inlay-hint edit source is exactly `inlayHint.default`. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-113 | IHC:399-409 | `_installContextMenu` returns the editor context-menu subscription. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-114 | IHC:400-408 | Context-menu callback owns target validation and label-part dispatch. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-115 | IHC:401-403 | A non-HTMLElement event target returns before label lookup. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-116 | IHC:404-407 | A present label part invokes the context menu; absence is a no-op. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-117 | IHC:411-420 | `_getInlayHintLabelPart` reads content-text injected options and otherwise returns `undefined`. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-118 | IHC:412-414 | Non-content-text target returns `undefined` immediately. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-119 | IHC:415-418 | Exact options and attached-data instance checks return the rendered part. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-120 | IHC:422-432 | `_invokeCommand` awaits the command and reports failures through notification. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-121 | IHC:424 | Missing command arguments fall back to an empty array before spreading. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-122 | IHC:425-430 | Command failure notifies Error severity with provider display name and the error message. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-123 | IHC:434-437 | `_cacheHintsForFastRestore` copies current anchors, then sets the model-keyed cache. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-124 | IHC:441-457 | `_copyInlayHintsWithCurrentAnchor` scans metadata, preserves first-seen item order, and returns copied anchors. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-125 | IHC:444-448 | A repeated item continues before another decoration-range read. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-126 | IHC:449-455 | A present decoration range creates same-direction anchor/copy; a missing range omits that item. | See Gate B target map | DEFERRED (fast-restore/cache child) |
| IHC-127 | IHC:460-473 | `_getHintsRanges` reads current model/visible ranges, sorts by start, extends, validates, merges, and returns sorted output. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-128 | IHC:461,466 | Viewport extension magic value is exactly `30` lines above and below. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-129 | IHC:467-469 | Empty output or an extended range that neither intersects nor touches appends. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-130 | IHC:469-471 | The explicit else arm merges touching/intersecting range with the last result via `plusRange`. | See Gate B target map | DEFERRED (debounce/provider-change/viewport request lane) |
| IHC-131 | IHC:476-728 | `_updateHintsDecorators` computes fixed lengths and injected decorations, collects affected IDs, captures scroll, deltas once, pairs returned IDs, and restores scroll in source order. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-132 | IHC:480-483 | Cursor stabilization runs only with live cursor info, an unexpired deadline, and a matching request range. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-133 | IHC:482 | Cursor-range predicate callback tests whether a request range contains the captured cursor position. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-134 | IHC:491 | Missing line decorations fall back to an empty array. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-135 | IHC:493-496 | Decoration starting after the cursor continues before option accounting. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-136 | IHC:497-501 | Existing directed options count only when attached data is not the whitespace sentinel. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-137 | IHC:499 | Missing prior item length takes the fallback branch before accumulation. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-138 | IHC:499 | Prior-item-length fallback is exactly `0`. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-139 | IHC:506 | Fixed-length filter callback keeps items on the cursor line whose anchor ends at or before the cursor column. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-140 | IHC:515-517 | Missing both fixed length and target item breaks the matching loop. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-141 | IHC:519-522 | Present target item records its fixed length and becomes the last item. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-142 | IHC:520 | Missing matched fixed length takes the fallback branch. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-143 | IHC:520 | Matched-fixed-length fallback is exactly `0`. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-144 | IHC:523-530 | Remaining positive lengths with a last item are summed, the pending array is cleared, then the loop breaks. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-145 | IHC:527 | Remaining-fixed-length reduction callback sums pending lengths. | See Gate B target map | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| IHC-146 | IHC:536-559 | `addInjectedText` nested callback constructs and records one injected decoration. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-147 | IHC:538 | Injected-text `content` property retains the supplied content. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-148 | IHC:539 | Injected-text `inlineClassNameAffectsLetterSpacing` property is exactly `true`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-149 | IHC:540 | Injected-text `inlineClassName` property retains the generated class. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-150 | IHC:541 | Injected-text `cursorStops` property retains the supplied stop mode. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-151 | IHC:542 | Injected-text `attachedData` property retains the supplied metadata. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-152 | IHC:548 | Injected-decoration `range` property uses the item's anchor range. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-153 | IHC:551 | Injected-decoration description property is exactly `InlayHint`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-154 | IHC:552 | Injected-decoration `showIfCollapsed` property follows anchor emptiness. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-155 | IHC:553 | Injected-decoration `collapseOnReplaceEdit` property follows anchor nonemptiness. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-156 | IHC:554 | Injected-decoration stickiness property is `AlwaysGrowsWhenTypingAtEdges`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-157 | IHC:555 | Injected-decoration anchor-direction property owns the directed text options. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-158 | IHC:555 | Directed options use `opts` only in `RenderMode.Normal`; invisible mode stores `undefined`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-159 | IHC:561-567 | `addInjectedWhitespace` nested callback creates the whitespace class and decoration. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-160 | IHC:563 | Whitespace CSS `width` is exactly truncated `fontSize / 3` pixels. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-161 | IHC:564 | Whitespace CSS `display` is exactly `inline-block`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-162 | IHC:566,690 | Shared injected-whitespace content is exact hair space `U+200A`, reused for fixed-length deficit. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-163 | IHC:573-574 | Custom property `--code-editorInlayHintsFontFamily` is set to the resolved font family. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-164 | IHC:566 | Injected whitespace stops right only when it is last; otherwise it has no cursor stop. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-165 | IHC:583-585 | A new source line resets line-total accounting before length checks. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-166 | IHC:587-589 | Truthy maximum with total already strictly greater than maximum continues before rendering the item. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-167 | IHC:592-594 | Left padding emits leading injected whitespace only when requested. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-168 | IHC:597-599 | String label becomes one synthetic part; structured label preserves its part array. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-169 | IHC:611 | Label CSS `fontSize` is the resolved size in pixels. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-170 | IHC:612 | Label CSS `fontFamily` uses the custom property before the editor fallback. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-171 | IHC:613 | Label CSS `verticalAlign` owns baseline/middle alignment. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-172 | IHC:613 | Uniform layout selects `baseline`; nonuniform layout selects `middle`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-173 | IHC:614 | Label CSS `unicodeBidi` is exactly `isolate`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-174 | IHC:617-619 | Nonempty text edits take the cursor-style branch. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-175 | IHC:618 | Text-edit label CSS `cursor` is exactly `default`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-176 | IHC:623-630 | Matching active command/location part takes the link-highlighting branch. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-177 | IHC:625 | Active-label CSS `textDecoration` is exactly `underline`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-178 | IHC:626-629 | Trigger modifier takes the active-link styling branch. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-179 | IHC:627 | Trigger-modifier CSS `color` uses `editorActiveLinkForeground`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-180 | IHC:628 | Trigger-modifier CSS `cursor` is exactly `pointer`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-181 | IHC:635 | Maximum-length ternary selects bounded overage or zero. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-182 | IHC:635 | Disabled maximum length and fallback overage use exact value `0`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-183 | IHC:636-639 | Positive overage truncates by the exact overage. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-184 | IHC:637,648 | Shared truncation suffix is exact ellipsis `…`, reused by maximum- and fixed-length trimming. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-185 | IHC:643-651 | Defined fixed length enables fixed-length comparison and trimming. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-186 | IHC:645-650 | Nonnegative fixed-length overage trims exactly `1 + overage` code units and appends the shared ellipsis. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-187 | IHC:653-669 | Padding-shape decisions run only when padding is enabled. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-188 | IHC:654-657 | First part that is also last or truncated selects the symmetric shape. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-189 | IHC:656 | Symmetric-shape CSS `padding` uses exact vertical `1px` and equal horizontal sides clamped to at least `1px`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-190 | IHC:657 | Symmetric-shape CSS `borderRadius` has equal corners of truncated `fontSize / 4` pixels. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-191 | IHC:658-661 | Other first parts select the left-edge shape. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-192 | IHC:660 | Left-edge CSS `padding` uses exact vertical `1px` and only the left horizontal inset clamped to at least `1px`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-193 | IHC:661 | Left-edge CSS `borderRadius` rounds only the left corners by truncated `fontSize / 4` pixels. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-194 | IHC:662-665 | Last or truncated nonfirst parts select the right-edge shape. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-195 | IHC:664 | Right-edge CSS `padding` uses exact vertical `1px` and only the right horizontal inset clamped to at least `1px`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-196 | IHC:665 | Right-edge CSS `borderRadius` rounds only the right corners by truncated `fontSize / 4` pixels. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-197 | IHC:666-668 | Interior parts select the interior shape. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-198 | IHC:667 | Interior CSS `padding` is vertical-only at exact `1px`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-199 | IHC:675 | Final label part without requested right padding stops right; every other part has no cursor stop. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-200 | IHC:679-681 | Truncation breaks the part loop immediately. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-201 | IHC:684-693 | Short fixed-length item emits its deficit with no cursor stops. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-202 | IHC:696-698 | Requested right padding emits trailing injected whitespace. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-203 | IHC:700-702 | Decoration count strictly greater than `1500` breaks the item loop. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-204 | IHC:709 | Missing current editor model or decoration range yields no affected old decoration. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-205 | IHC:710-714 | Only an existing range contained by a request range queues the old ID, disposes its class ref, and deletes metadata in that order. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-206 | IHC:710 | Affected-range predicate callback checks containment for each request range. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-207 | IHC:719-725 | Decoration-transaction callback deltas decorations and pairs returned IDs with metadata. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-208 | IHC:720 | New-decoration mapping callback extracts each model delta decoration. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-209 | IHC:730-741 | `_fillInColors` selects one background/foreground pair. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-210 | IHC:731-733 | Parameter kind selects the parameter-color branch. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-211 | IHC:732 | Parameter-kind CSS `backgroundColor` uses `editorInlayHintParameterBackground`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-212 | IHC:733 | Parameter-kind CSS `color` uses `editorInlayHintParameterForeground`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-213 | IHC:734-736 | Type kind selects the type-color branch. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-214 | IHC:735 | Type-kind CSS `backgroundColor` uses `editorInlayHintTypeBackground`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-215 | IHC:736 | Type-kind CSS `color` uses `editorInlayHintTypeForeground`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-216 | IHC:737-740 | Every other kind selects the generic-color branch. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-217 | IHC:738 | Generic-kind CSS `backgroundColor` uses `editorInlayHintBackground`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-218 | IHC:739 | Generic-kind CSS `color` uses `editorInlayHintForeground`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-219 | IHC:743-762 | `_getLayoutInfo` reads options/editor font, resolves size/family, computes uniformity, and returns all four values. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-220 | IHC:750-753 | Falsy, too-small, or too-large font size falls back to editor size. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-221 | IHC:751 | Minimum configured inlay-hint font size is exactly `5`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-222 | IHC:755 | Falsy configured font family falls back to editor font family. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-223 | IHC:764-770 | `_removeAllDecorations` removes all IDs at once, disposes every class ref, then clears metadata. | See Gate B target map | TESTED |
| IHC-224 | IHC:775-789 | `getInlayHintsForLine` deduplicates hints in line-decoration order. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-225 | IHC:776-778 | Missing editor model returns an empty result. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-226 | IHC:782-786 | Present metadata with an unseen hint adds the hint and item; every other decoration is skipped. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-227 | IHC:793-797 | `fixSpace` globally replaces exact space-or-tab matches with nonbreaking space `U+00A0`. | See Gate B target map | DEFERRED (complete render/CSS/partial-decoration parity) |
| IHC-228 | IHC:799-815 | Execute-provider command callback validates input, acquires a model, awaits fragments, maps/returns hints, and disposes the reference. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-229 | IHC:799 | Registered execute-provider command ID is exactly `_executeInlayHintProvider`. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-230 | IHC:809 | Result-mapping callback extracts each item hint. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-231 | IHC:810 | Deferred-disposal callback disposes the fragments. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHC-232 | IHC:810 | Fragment-disposal timeout is exactly `0`. | See Gate B target map | DEFERRED (label resolve/command/public interaction surface) |
| IHF-001 | IHF:17 | Anchor `range` parameter-property. | See Gate B target map | TESTED |
| IHF-002 | IHF:17 | Anchor `direction` parameter-property is the exact `before`/`after` protocol union. | See Gate B target map | TESTED |
| IHF-003 | IHF:16-18 | `InlayHintAnchor` constructor retains range and direction. | See Gate B target map | TESTED |
| IHF-004 | IHF:22 | Item resolved-state field starts `false`. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-005 | IHF:23 | Current resolve-promise field starts `undefined`. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-006 | IHF:25 | Item `hint` parameter-property. | See Gate B target map | TESTED |
| IHF-007 | IHF:25 | Item `anchor` parameter-property. | See Gate B target map | TESTED |
| IHF-008 | IHF:25 | Item `provider` parameter-property. | See Gate B target map | TESTED |
| IHF-009 | IHF:25 | `InlayHintItem` constructor retains hint, anchor, and provider. | See Gate B target map | TESTED |
| IHF-010 | IHF:27-32 | `with` creates same hint/provider with replacement anchor, copies both resolve fields, then returns. | See Gate B target map | DEFERRED (fast restore) |
| IHF-011 | IHF:34-52 | Explicit excluded sibling `resolve` serializes provider resolution, awaits active work before retry, installs unresolved work, and awaits the final promise. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-012 | IHF:49 | Resolve-finally callback clears the current resolve promise. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-013 | IHF:35-37 | Provider without `resolveInlayHint` returns immediately. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-014 | IHF:38-46 | Existing resolve promise is awaited before cancellation/retry decisions. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-015 | IHF:42-44 | Cancellation after waiting for an active resolve returns before recursive retry. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-016 | IHF:47-50 | Only unresolved items install a new `_doResolve` promise; resolved items skip it. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-017 | IHF:54-65 | Explicit excluded sibling `_doResolve` awaits the provider, applies tooltip/label/text-edit fallbacks in order, then marks resolved. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-018 | IHF:57 | Nullish resolved tooltip preserves the old tooltip. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-019 | IHF:58 | Nullish resolved label preserves the old label. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-020 | IHF:59 | Nullish resolved text edits preserve the old text edits. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-021 | IHF:61-64 | Resolve failure passes the error to `onUnexpectedExternalError`, then resets resolved state to `false`. | See Gate B target map | DEFERRED (resolve API/state outside P1) |
| IHF-022 | IHF:70 | Frozen empty-list member has empty hints. | See Gate B target map | N-A (MoonBit providers return non-null GC-owned arrays, not optional disposable lists) |
| IHF-023 | IHF:70 | Frozen empty-list object disposer callback is a no-op. | See Gate B target map | N-A (MoonBit providers return non-null GC-owned arrays, not optional disposable lists) |
| IHF-024 | IHF:72-94 | `create` launches reversed ordered-provider/range work with one model/token, awaits all, then constructs fragments in completion order. | See Gate B target map | TESTED |
| IHF-025 | IHF:76 | Provider-mapping callback fans one provider out across all requested ranges. | See Gate B target map | TESTED |
| IHF-026 | IHF:76-85 | Async range-mapping callback requests, retains, or contains one provider/range result. | See Gate B target map | TESTED |
| IHF-027 | IHF:79-81 | A result is retained only with nonempty hints or a provider change event; a non-null empty unretained list is neither retained nor disposed. | See Gate B target map | DEFERRED (provider observation/P2 registry surface) |
| IHF-028 | IHF:80 | Retained nullish result falls back to the frozen empty list. | See Gate B target map | N-A (MoonBit providers return non-null GC-owned arrays, not optional disposable lists) |
| IHF-029 | IHF:82-84 | Each provider/range failure is independently passed to `onUnexpectedExternalError` and contained. | See Gate B target map | TESTED |
| IHF-030 | IHF:89-91 | After all calls settle, cancellation or disposed model throws `CancellationError`. | See Gate B target map | TESTED |
| IHF-031 | IHF:96 | `_disposables` owns every retained provider list. | See Gate B target map | N-A (MoonBit providers return non-null GC-owned arrays, not optional disposable lists) |
| IHF-032 | IHF:98 | Readonly `items` result field. | See Gate B target map | TESTED |
| IHF-033 | IHF:99 | Readonly `ranges` result field. | See Gate B target map | TESTED |
| IHF-034 | IHF:100 | Readonly deduplicated `provider` result field. | See Gate B target map | DEFERRED (provider observation/P2 registry surface) |
| IHF-035 | IHF:102-130 | Constructor retains ranges, processes retained pairs, owns lists, deduplicates providers, validates positions, derives anchors initially as `before`, creates items, and sorts them. | See Gate B target map | TESTED |
| IHF-036 | IHF:129 | Item-sort comparator orders items by hint position. | See Gate B target map | TESTED |
| IHF-037 | IHF:118-120 | Word start before hint takes the start-to-hint anchor branch with exact direction `after`. | See Gate B target map | TESTED |
| IHF-038 | IHF:121-124 | The other branch builds a hint-to-word-end anchor with exact direction `before`. | See Gate B target map | TESTED |
| IHF-039 | IHF:132-134 | `dispose` retires every retained provider list. | See Gate B target map | N-A (MoonBit providers return non-null GC-owned arrays, not optional disposable lists) |
| IHF-040 | IHF:136-165 | `_getRangeAtPosition` converts column to zero-based offset with exact `-1`, reads/selects/adjusts token bounds, then converts returned columns with exact `+1`. | See Gate B target map | TESTED |
| IHF-041 | IHF:139-142 | Existing word range returns immediately before tokenization. | See Gate B target map | TESTED |
| IHF-042 | IHF:152-163 | Neighbor adjustment is considered only for the single-character-token branch. | See Gate B target map | TESTED |
| IHF-043 | IHF:152 | Single-character token length is exactly `1`. | See Gate B target map | TESTED |
| IHF-044 | IHF:154-157 | Leading adjustment requires start=offset and an eligible preceding index, then selects index minus exactly `1`. | See Gate B target map | TESTED |
| IHF-045 | IHF:154 | Leading-adjustment index must be strictly greater than `1`. | See Gate B target map | TESTED |
| IHF-046 | IHF:158-162 | Only after the leading condition fails, trailing adjustment requires end=offset and an eligible following index, then selects index plus exactly `1`. | See Gate B target map | TESTED |
| IHF-047 | IHF:158 | Trailing-adjustment upper bound is token count minus exactly `1`. | See Gate B target map | TESTED |
| IHF-048 | IHF:169-171 | Explicit excluded sibling `asCommandLink` creates the command URI with ID/arguments, then returns `toString()`. | See Gate B target map | DEFERRED (command-link API) |
| IHF-049 | IHF:170 | Nullish command arguments fall back to an empty array before spreading. | See Gate B target map | DEFERRED (command-link API) |
| CHC-001 | CHC:28-31 | Module `_sticky` constant is `false`. | See Gate B target map | TESTED |
| CHC-002 | CHC:33-34 | Hover settings `enabled` member. | See Gate B target map | TESTED |
| CHC-003 | CHC:34 | Enabled-mode protocol value is exactly `on`. | See Gate B target map | TESTED |
| CHC-004 | CHC:34 | Enabled-mode protocol value is exactly `off`. | See Gate B target map | TESTED |
| CHC-005 | CHC:34 | Enabled-mode protocol value is exactly `onKeyboardModifier`. | See Gate B target map | TESTED |
| CHC-006 | CHC:35 | Hover settings `sticky` member. | See Gate B target map | TESTED |
| CHC-007 | CHC:36 | Hover settings `hidingDelay` member. | See Gate B target map | TESTED |
| CHC-008 | CHC:41 | Owned contents-changed emitter. | See Gate B target map | DEFERRED (hover render/participant lifecycle) |
| CHC-009 | CHC:42 | Public contents-changed event alias. | See Gate B target map | DEFERRED (hover render/participant lifecycle) |
| CHC-010 | CHC:44 | Contribution ID is exactly `editor.contrib.contentHover`. | See Gate B target map | PORTED |
| CHC-011 | CHC:46 | Public keep-open override starts false. | See Gate B target map | TESTED |
| CHC-012 | CHC:48 | Listener store owns hook generation. | See Gate B target map | TESTED |
| CHC-013 | CHC:50 | Lazily created content widget field. | See Gate B target map | TESTED |
| CHC-014 | CHC:52 | Latest editor mouse-move event field. | See Gate B target map | TESTED |
| CHC-015 | CHC:53 | Deferred mouse-react scheduler field. | See Gate B target map | TESTED |
| CHC-016 | CHC:55 | Captured hover settings field. | See Gate B target map | TESTED |
| CHC-017 | CHC:56 | Mouse-down state starts false. | See Gate B target map | TESTED |
| CHC-018 | CHC:58 | Ignore-mouse-events state starts false. | See Gate B target map | TESTED |
| CHC-019 | CHC:61 | Editor dependency member. | See Gate B target map | N-A (no retained TypeScript DI parameter-properties) |
| CHC-020 | CHC:63 | Instantiation service dependency. | See Gate B target map | N-A (no retained TypeScript DI parameter-properties) |
| CHC-021 | CHC:64 | Keybinding service dependency. | See Gate B target map | N-A (no retained TypeScript DI parameter-properties) |
| CHC-022 | CHC:60-66,81 | Constructor accepts the context-menu service parameter, establishes the disposable base, then installs hover listeners. | See Gate B target map | DEFERRED (context-menu service wiring absent) |
| CHC-023 | CHC:67-72 | Registered mouse-react callback reads the latest mouse event and delegates reaction with that event. | See Gate B target map | TESTED |
| CHC-024 | CHC:69-71 | Runner reacts only when a latest mouse event exists. | See Gate B target map | TESTED |
| CHC-025 | CHC:72 | Mouse-react scheduler delay is exactly `0`. | See Gate B target map | TESTED |
| CHC-026 | CHC:74-77 | Context-menu show hides hover then ignores mouse events. | See Gate B target map | DEFERRED (context-menu lifecycle wiring absent) |
| CHC-027 | CHC:78-80 | Context-menu hide reenables mouse events. | See Gate B target map | DEFERRED (context-menu lifecycle wiring absent) |
| CHC-028 | CHC:82 | Configuration listener is controller-owned. | See Gate B target map | DEFERRED (live hover-configuration owner absent) |
| CHC-029 | CHC:83-86 | Only hover-option change rehooks listeners. | See Gate B target map | DEFERRED (live hover-configuration owner absent) |
| CHC-030 | CHC:90-92 | Static `get` resolves contribution by ID. | See Gate B target map | TESTED |
| CHC-031 | CHC:94-100 | `_hookListeners` snapshots enabled/sticky/hiding delay. | See Gate B target map | DEFERRED (live hover-configuration owner absent) |
| CHC-032 | CHC:101 | Disabled-mode comparison uses the exact protocol value `off`. | See Gate B target map | DEFERRED (live hover-configuration owner absent) |
| CHC-033 | CHC:101-103 | Disabled hover cancels scheduler and hides. | See Gate B target map | DEFERRED (live hover-configuration owner absent) |
| CHC-034 | CHC:104 | Hook owns mouse-down subscription. | See Gate B target map | TESTED |
| CHC-035 | CHC:105 | Hook owns mouse-up subscription. | See Gate B target map | TESTED |
| CHC-036 | CHC:106 | Hook owns mouse-move subscription. | See Gate B target map | TESTED |
| CHC-037 | CHC:107 | Hook owns key-down subscription. | See Gate B target map | TESTED |
| CHC-038 | CHC:108 | Hook owns mouse-leave subscription. | See Gate B target map | TESTED |
| CHC-039 | CHC:109 | Model change cancels scheduler and hides. | See Gate B target map | TESTED |
| CHC-040 | CHC:110 | Model-content change cancels pending scheduler only. | See Gate B target map | TESTED |
| CHC-041 | CHC:111 | Hook owns scroll-change subscription. | See Gate B target map | TESTED |
| CHC-042 | CHC:114-116 | `_unhookListeners` clears the generation store. | See Gate B target map | TESTED |
| CHC-043 | CHC:118-121 | `_cancelSchedulerAndHide` orders cancellation before hide. | See Gate B target map | TESTED |
| CHC-044 | CHC:123-126 | `_cancelScheduler` clears captured event then cancels runner. | See Gate B target map | TESTED |
| CHC-045 | CHC:128 | Scroll-change handler member. | See Gate B target map | TESTED |
| CHC-046 | CHC:129-131 | Ignored mouse events return before scroll reaction. | See Gate B target map | TESTED |
| CHC-047 | CHC:132-134 | Top or left scroll change hides hover. | See Gate B target map | TESTED |
| CHC-048 | CHC:137-146 | Mouse-down handling sets the accepted down state before the keep-visible check and otherwise hides. | See Gate B target map | TESTED |
| CHC-049 | CHC:138-140 | Ignored mouse events return before down state. | See Gate B target map | TESTED |
| CHC-050 | CHC:142-145 | Keep-visible predicate returns before hide. | See Gate B target map | TESTED |
| CHC-051 | CHC:149-151 | Keep-visible is widget hit, resize, or color decorator. | See Gate B target map | DEFERRED (resize waits hover-resize child; color-decorator arm is N-A; widget arm is CHC-052–053) |
| CHC-052 | CHC:153-157 | Content-widget hit testing uses DOM position containment on the surviving connected-widget path. | See Gate B target map | TESTED |
| CHC-053 | CHC:154-156 | Missing/disconnected widget returns false. | See Gate B target map | TESTED |
| CHC-054 | CHC:160-164 | Accepted mouse-up clears the down state. | See Gate B target map | TESTED |
| CHC-055 | CHC:161-163 | Ignored mouse-up returns. | See Gate B target map | TESTED |
| CHC-056 | CHC:167-182 | Mouse leave cancels the pending scheduler before retention checks and hides on the surviving path. | See Gate B target map | TESTED |
| CHC-057 | CHC:168-170 | Ignored mouse leave returns. | See Gate B target map | TESTED |
| CHC-058 | CHC:171-173 | Explicit keep-open returns. | See Gate B target map | TESTED |
| CHC-059 | CHC:175-178 | Keep-visible predicate returns. | See Gate B target map | TESTED |
| CHC-060 | CHC:179-181 | Module sticky constant returns. | See Gate B target map | TESTED |
| CHC-061 | CHC:185-220 | Current-hover retention captures sticky/focus/resize/keyboard state and returns the OR of every retention predicate. | See Gate B target map | DEFERRED (focus/resize/keyboard-visible arms wait widget-state child; color/selection arms are N-A) |
| CHC-062 | CHC:187-189 | Missing widget returns false. | See Gate B target map | TESTED |
| CHC-063 | CHC:191-194 | Sticky widget-hit helper requires sticky and containment. | See Gate B target map | TESTED |
| CHC-064 | CHC:195-201 | Color-picker helper retains visible hit or mouse-down choice. | See Gate B target map | N-A (no hover color-picker widget) |
| CHC-065 | CHC:203-209 | Selection-retention callback requires sticky and a contained active element; absent selection or noncollapsed selection makes its final negated optional predicate true. | See Gate B target map | N-A (no browser-selection retention surface) |
| CHC-066 | CHC:204-207 | Selection-retention callback returns false when the browser view is absent. | See Gate B target map | N-A (no browser-selection retention surface) |
| CHC-067 | CHC:223-240 | Mouse move captures the event, computes retention/rescheduling, and reacts immediately on the surviving path. | See Gate B target map | TESTED |
| CHC-068 | CHC:224-226 | Ignored mouse move returns. | See Gate B target map | TESTED |
| CHC-069 | CHC:228-232 | Current-hover retention cancels runner and returns. | See Gate B target map | TESTED |
| CHC-070 | CHC:234-239 | Reschedule path returns without immediate reaction. | See Gate B target map | TESTED |
| CHC-071 | CHC:235-237 | Reschedule uses the configured hiding delay only when the runner is not already scheduled. | See Gate B target map | TESTED |
| CHC-072 | CHC:243 | Reschedule predicate member. | See Gate B target map | TESTED |
| CHC-073 | CHC:245 | Absent widget visibility defaults false. | See Gate B target map | TESTED |
| CHC-074 | CHC:248 | Reschedule requires visible, sticky, and delay greater than `0`. | See Gate B target map | TESTED |
| CHC-075 | CHC:251-265 | Mouse reaction gates the show path and otherwise hides on the surviving nonsticky path. | See Gate B target map | TESTED |
| CHC-076 | CHC:252-257 | `shouldShowHover` gates computation and lazily gets or creates the widget. | See Gate B target map | TESTED |
| CHC-077 | CHC:258-260 | Widget showing or pending returns early. | See Gate B target map | TESTED |
| CHC-078 | CHC:262-264 | Module sticky constant suppresses fallback hide. | See Gate B target map | TESTED |
| CHC-079 | CHC:268-290 | Key-down handling preserves its guarded cases and hides on the surviving default path. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-080 | CHC:269-271 | Ignored keys or missing widget return. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-081 | CHC:273 | Modifier-only comparison uses the exact protocol value `onKeyboardModifier`. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-082 | CHC:273-279 | Modifier-only mode requires trigger modifier and a captured mouse event, then always returns after its optional restart. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-083 | CHC:276-278 | Invisible widget restarts from captured mouse event. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-084 | CHC:282-286 | Potential shortcut or any modifier key preserves hover. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-085 | CHC:287-289 | Focused widget preserves Tab. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-086 | CHC:293-304 | Potential-shortcut classification soft-dispatches the key, derives chord/action state, and returns their OR. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-087 | CHC:294-296 | Missing model or widget returns false. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHC-088 | CHC:307 | Public hide member. | See Gate B target map | TESTED |
| CHC-089 | CHC:308-310 | Module sticky constant prevents hide. | See Gate B target map | TESTED |
| CHC-090 | CHC:311-313 | Visible inline-suggestion dropdown prevents hide. | See Gate B target map | N-A (no inline-suggestion hints dropdown) |
| CHC-091 | CHC:314 | Otherwise delegates widget hide. | See Gate B target map | TESTED |
| CHC-092 | CHC:317-322 | Lazy widget access creates only when needed and returns the persistent widget. | See Gate B target map | TESTED |
| CHC-093 | CHC:318 | Creation occurs only when field is absent. | See Gate B target map | TESTED |
| CHC-094 | CHC:320 | Contents-changed callback forwards into the controller emitter. | See Gate B target map | DEFERRED (hover render/participant lifecycle) |
| CHC-095 | CHC:325-332 | Public show delegates range/mode/source/focus. | See Gate B target map | TESTED |
| CHC-096 | CHC:334 | Content-widget resize query member. | See Gate B target map | DEFERRED (hover resize/layout child) |
| CHC-097 | CHC:335 | Present widget returns its resize state; an absent widget falls back to `false`. | See Gate B target map | DEFERRED (hover resize/layout child) |
| CHC-098 | CHC:410-414 | Override disposal calls the base first, unhooks listeners, retires the store, then retires the optional widget. | See Gate B target map | TESTED |
| CHC-099 | CHC:414 | Disposal retires optional content widget. | See Gate B target map | TESTED |
| CHC-100 | CHC:338-340 | Excluded sibling member `focusedHoverPartIndex` creates/gets the widget and forwards the query. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHC-101 | CHC:342-344 | Excluded sibling member `doesHoverAtIndexSupportVerbosityAction` creates/gets the widget and forwards index/action. | See Gate B target map | DEFERRED (hover verbosity child) |
| CHC-102 | CHC:346-348 | Excluded sibling member `updateHoverVerbosityLevel` creates/gets the widget and forwards action/index/focus. | See Gate B target map | DEFERRED (hover verbosity child) |
| CHC-103 | CHC:350 | Excluded sibling member `focus`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHC-104 | CHC:351 | `focus` forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHC-105 | CHC:354 | Excluded sibling member `focusHoverPartWithIndex`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHC-106 | CHC:355 | Indexed focus forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHC-107 | CHC:358 | Excluded sibling member `scrollUp`. | See Gate B target map | TESTED |
| CHC-108 | CHC:359 | Up-scroll forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | TESTED |
| CHC-109 | CHC:362 | Excluded sibling member `scrollDown`. | See Gate B target map | TESTED |
| CHC-110 | CHC:363 | Down-scroll forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | TESTED |
| CHC-111 | CHC:366 | Excluded sibling member `scrollLeft`. | See Gate B target map | TESTED |
| CHC-112 | CHC:367 | Left-scroll forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | TESTED |
| CHC-113 | CHC:370 | Excluded sibling member `scrollRight`. | See Gate B target map | TESTED |
| CHC-114 | CHC:371 | Right-scroll forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | TESTED |
| CHC-115 | CHC:374 | Excluded sibling member `pageUp`. | See Gate B target map | TESTED |
| CHC-116 | CHC:375 | Page-up forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | TESTED |
| CHC-117 | CHC:378 | Excluded sibling member `pageDown`. | See Gate B target map | TESTED |
| CHC-118 | CHC:379 | Page-down forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | TESTED |
| CHC-119 | CHC:382 | Excluded sibling member `goToTop`. | See Gate B target map | TESTED |
| CHC-120 | CHC:383 | Top navigation forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | TESTED |
| CHC-121 | CHC:386 | Excluded sibling member `goToBottom`. | See Gate B target map | TESTED |
| CHC-122 | CHC:387 | Bottom navigation forwards only when the optional content widget exists; absence is a no-op. | See Gate B target map | TESTED |
| CHC-123 | CHC:390 | Excluded sibling member `getWidgetContent`. | See Gate B target map | DEFERRED (hover render/content API) |
| CHC-124 | CHC:391 | Widget-content query forwards for an existing widget and returns `undefined` when absent. | See Gate B target map | DEFERRED (hover render/content API) |
| CHC-125 | CHC:394 | Excluded sibling member `getAccessibleWidgetContent`. | See Gate B target map | DEFERRED (hover accessibility child) |
| CHC-126 | CHC:395 | Accessible-content query forwards for an existing widget and returns `undefined` when absent. | See Gate B target map | DEFERRED (hover accessibility child) |
| CHC-127 | CHC:398 | Excluded sibling member `getAccessibleWidgetContentAtIndex`. | See Gate B target map | DEFERRED (hover accessibility child) |
| CHC-128 | CHC:399 | Indexed accessible-content query forwards for an existing widget and returns `undefined` when absent. | See Gate B target map | DEFERRED (hover accessibility child) |
| CHC-129 | CHC:402 | Excluded sibling getter `isColorPickerVisible`. | See Gate B target map | N-A (no hover color-picker widget) |
| CHC-130 | CHC:403 | Color-picker visibility forwards for an existing widget and returns `undefined` when absent. | See Gate B target map | N-A (no hover color-picker widget) |
| CHC-131 | CHC:406 | Excluded sibling getter `isHoverVisible`. | See Gate B target map | TESTED |
| CHC-132 | CHC:407 | Hover visibility forwards for an existing widget and returns `undefined` when absent. | See Gate B target map | TESTED |
| CHW-001 | CHW:29 | Current reconciled hover result field starts null. | See Gate B target map | TESTED |
| CHW-002 | CHW:30 | Mutable rendered-hover disposable is wrapper-owned. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| CHW-003 | CHW:32 | Content-hover widget is wrapper-owned. | See Gate B target map | TESTED |
| CHW-004 | CHW:33 | Participant array is wrapper-owned. | See Gate B target map | TESTED |
| CHW-005 | CHW:34 | Hover operation is wrapper-owned. | See Gate B target map | TESTED |
| CHW-006 | CHW:36 | Contents-changed emitter is owned. | See Gate B target map | DEFERRED (render/participant lifecycle) |
| CHW-007 | CHW:37 | Public event aliases emitter. | See Gate B target map | DEFERRED (render/participant lifecycle) |
| CHW-008 | CHW:40 | Editor dependency member. | See Gate B target map | N-A (no separate TypeScript DI parameter-properties) |
| CHW-009 | CHW:41 | Instantiation service member. | See Gate B target map | N-A (no separate TypeScript DI parameter-properties) |
| CHW-010 | CHW:42 | Keybinding service member. | See Gate B target map | N-A (no separate TypeScript DI parameter-properties) |
| CHW-011 | CHW:43 | Hover service member. | See Gate B target map | N-A (no separate TypeScript DI parameter-properties) |
| CHW-012 | CHW:44 | Clipboard service member. | See Gate B target map | N-A (no separate TypeScript DI parameter-properties) |
| CHW-013 | CHW:39-50 | Constructor establishes the disposable base, creates owned widget/participants/operation in order, then registers listeners. | See Gate B target map | PORTED |
| CHW-014 | CHW:53-69 | Participant initialization builds the ordered list, installs participant listeners, and returns that list. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-015 | CHW:55-58 | Every registered constructor is visited, instantiated for the editor, and pushed in registry order. | See Gate B target map | TESTED |
| CHW-016 | CHW:59 | Participants sort ascending by exact comparator arithmetic `p1.hoverOrdinal - p2.hoverOrdinal`. | See Gate B target map | TESTED |
| CHW-017 | CHW:60-62 | Widget-resize event callback visits the ordered participant collection. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-018 | CHW:61 | Resize `forEach` callback receives one participant. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-019 | CHW:61 | Present optional `handleResize` runs; absence is a no-op. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-020 | CHW:63-65 | Widget-scroll event callback visits the ordered participant collection with the source event. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-021 | CHW:64 | Scroll `forEach` callback receives one participant and the captured event. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-022 | CHW:64 | Present optional `handleScroll` receives the event; absence is a no-op. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-023 | CHW:66-68 | Widget-content-change event callback visits the ordered participant collection. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-024 | CHW:67 | Contents-change `forEach` callback receives one participant. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-025 | CHW:67 | Present optional `handleContentsChanged` runs; absence is a no-op. | See Gate B target map | DEFERRED (participant render-lifecycle handlers) |
| CHW-026 | CHW:72 | Listener-registration member. | See Gate B target map | TESTED |
| CHW-027 | CHW:73-76 | Operation-result callback chooses messages, wraps completeness/options, and enters reconciliation. | See Gate B target map | TESTED |
| CHW-028 | CHW:74 | Loading flag chooses augmented messages vs raw values. | See Gate B target map | TESTED |
| CHW-029 | CHW:78 | DOM event protocol value is exactly `keydown`. | See Gate B target map | TESTED |
| CHW-030 | CHW:78-82 | Widget keydown callback is disposable-owned. | See Gate B target map | TESTED |
| CHW-031 | CHW:79-81 | Escape hides. | See Gate B target map | TESTED |
| CHW-032 | CHW:83 | DOM event protocol value is exactly `mouseleave`. | See Gate B target map | TESTED |
| CHW-033 | CHW:83-85 | Widget mouseleave callback delegates the event. | See Gate B target map | TESTED |
| CHW-034 | CHW:86-90 | Tokenization registry listener is owned. | See Gate B target map | DEFERRED (hover render/tokenization child) |
| CHW-035 | CHW:87-89 | Existing position and result rerender same result. | See Gate B target map | DEFERRED (hover render/tokenization child) |
| CHW-036 | CHW:91-93 | Widget content event fires wrapper event. | See Gate B target map | DEFERRED (render/participant lifecycle) |
| CHW-037 | CHW:99-148 | Start-or-update consumes anchor/mode/source/focus/mouse, derives visibility/sticky/compatibility, and restarts on the surviving compatible path. | See Gate B target map | TESTED |
| CHW-038 | CHW:107-113 | Invisible hover enters the nested anchor/no-anchor decision; visible hover continues to sticky reconciliation. | See Gate B target map | TESTED |
| CHW-039 | CHW:108-111 | Invisible with anchor starts operation and returns true. | See Gate B target map | TESTED |
| CHW-040 | CHW:112 | Invisible without anchor returns false. | See Gate B target map | TESTED |
| CHW-041 | CHW:119-124 | Closer branch optionally starts an insisting update and always returns true while preserving the visible result. | See Gate B target map | TESTED |
| CHW-042 | CHW:120-122 | Closer with anchor starts update with insist=true. | See Gate B target map | TESTED |
| CHW-043 | CHW:126-129 | No anchor clears result and returns false. | See Gate B target map | TESTED |
| CHW-044 | CHW:131-134 | Equal current anchor returns true without restart. | See Gate B target map | TESTED |
| CHW-045 | CHW:137-141 | Incompatible anchor clears result then starts fresh. | See Gate B target map | TESTED |
| CHW-046 | CHW:144-146 | Compatible-anchor filtering applies only while `_currentResult` remains non-null; the null branch is a no-op. | See Gate B target map | TESTED |
| CHW-047 | CHW:151-164 | Operation-start-if-necessary cancels the previous operation, captures all four options, then starts with the supplied mode. | See Gate B target map | TESTED |
| CHW-048 | CHW:152-155 | Same operation anchor returns early. | See Gate B target map | TESTED |
| CHW-049 | CHW:166-181 | Current-result setter normalizes and stores the result before selecting the show/hide boundary. | See Gate B target map | TESTED |
| CHW-050 | CHW:168-171 | Identical result object returns early. | See Gate B target map | N-A (hover results are immutable values, not identity objects) |
| CHW-051 | CHW:172-175 | Non-null empty result normalizes to null. | See Gate B target map | TESTED |
| CHW-052 | CHW:177-181 | Non-null calls show boundary; null calls hide boundary. | See Gate B target map | TESTED |
| CHW-053 | CHW:184-195 | Loading-message augmentation scans participants and returns the original value when none contributes. | See Gate B target map | TESTED |
| CHW-054 | CHW:185 | Participants are checked in order. | See Gate B target map | TESTED |
| CHW-055 | CHW:186-188 | Missing loading-message factory continues. | See Gate B target map | N-A (loading factory is a required option-returning trait member) |
| CHW-056 | CHW:189-192 | Null loading message continues. | See Gate B target map | TESTED |
| CHW-057 | CHW:193 | First message appends to copied result and returns. | See Gate B target map | TESTED |
| CHW-058 | CHW:198-216 | Result reconciliation derives the prior-visible-complete predicate and applies every surviving complete result. | See Gate B target map | TESTED |
| CHW-059 | CHW:200-202 | Without a previous visible complete result, the incoming result is applied immediately and control still falls through. | See Gate B target map | TESTED |
| CHW-060 | CHW:204-208 | An incomplete result returns after that possible apply; it preserves an old complete hover only when one existed. | See Gate B target map | TESTED |
| CHW-061 | CHW:209-215 | Empty complete plus insist returns; it preserves an old hover only when the previous-visible-complete precondition held, otherwise the earlier apply already normalized the empty result to null. | See Gate B target map | TESTED |
| CHW-062 | CHW:249-264 | `showsOrWillShow` computes candidates and delegates the first highest-priority candidate on the surviving path. | See Gate B target map | DEFERRED (resize waits resize child; code-action arm is N-A; candidate path is CHW-065–075) |
| CHW-063 | CHW:250-253 | Resizing returns true without recomputation. | See Gate B target map | DEFERRED (hover resize/layout child) |
| CHW-064 | CHW:254-256 | Code-action widget hit returns true. | See Gate B target map | N-A (no code-action widget contribution) |
| CHW-065 | CHW:258-261 | No candidate delegates null delayed mouse update. | See Gate B target map | TESTED |
| CHW-066 | CHW:266-299 | Anchor-candidate finding collects valid suggestions and built-ins, sorts them, and returns the resulting array. | See Gate B target map | TESTED |
| CHW-067 | CHW:268-271 | Participant without suggester continues. | See Gate B target map | N-A (anchor suggester is a required option-returning trait member) |
| CHW-068 | CHW:272-275 | Null participant suggestion continues. | See Gate B target map | TESTED |
| CHW-069 | CHW:280-283 | Content-text target adds a built-in range anchor. | See Gate B target map | TESTED |
| CHW-070 | CHW:281 | Content-text built-in range-anchor priority is exactly `0`. | See Gate B target map | TESTED |
| CHW-071 | CHW:284-295 | Content-empty target computes epsilon and adds a built-in anchor only on the qualifying path. | See Gate B target map | TESTED |
| CHW-072 | CHW:285 | Content-empty epsilon divisor is exactly `2`. | See Gate B target map | TESTED |
| CHW-073 | CHW:287-294 | Empty-target qualification requires within-lines, numeric distance below epsilon; failure breaks and success continues to the built-in anchor. | See Gate B target map | TESTED |
| CHW-074 | CHW:293 | Qualified-empty built-in range-anchor priority is exactly `0`. | See Gate B target map | TESTED |
| CHW-075 | CHW:297 | Candidates sort descending by priority. | See Gate B target map | TESTED |
| CHW-076 | CHW:301 | Code-action hit-test member. | See Gate B target map | N-A (no `.action-widget` contribution/selector) |
| CHW-077 | CHW:302-306 | Element with a matching closest action widget returns true; otherwise false. | See Gate B target map | N-A (no `.action-widget` contribution/selector) |
| CHW-078 | CHW:303 | Code-action DOM class selector is exactly `.action-widget`. | See Gate B target map | N-A (no `.action-widget` contribution/selector) |
| CHW-079 | CHW:309 | Mouse-leave member. | See Gate B target map | TESTED |
| CHW-080 | CHW:310-314 | Missing editor DOM or outside position hides; a mouseleave point still inside the editor is a no-op. | See Gate B target map | TESTED |
| CHW-081 | CHW:317-319 | `startShowingAtRange` builds a range anchor with undefined mouse coordinates and delegates the requested mode/source/focus. | See Gate B target map | TESTED |
| CHW-082 | CHW:318 | Programmatic range-anchor priority is exactly `0`. | See Gate B target map | TESTED |
| CHW-083 | CHW:398-400 | Public hide cancels the operation before clearing the current result. | See Gate B target map | TESTED |
| CHW-084 | CHW:279-296 | Implicit switch default: every other mouse target type adds no built-in range anchor. | See Gate B target map | TESTED |
| CHW-085 | CHW:219-227 | Excluded sibling member `_showHover` creates context, replaces the rendered-hover disposable, then decides whether to show it. | See Gate B target map | DEFERRED (hover DOM/render child) |
| CHW-086 | CHW:222-226 | Rendered DOM with children is shown; an empty rendered DOM clears the rendered-hover disposable. | See Gate B target map | DEFERRED (hover DOM/render child) |
| CHW-087 | CHW:229-232 | Excluded sibling member `_hideHover` hides the widget before visiting participants in order. | See Gate B target map | DEFERRED (participant render-lifecycle child) |
| CHW-088 | CHW:231 | Hide `forEach` callback receives one participant. | See Gate B target map | DEFERRED (participant render-lifecycle child) |
| CHW-089 | CHW:231 | Present optional `handleHide` runs; absence is a no-op. | See Gate B target map | DEFERRED (participant render-lifecycle child) |
| CHW-090 | CHW:234-246 | Excluded sibling member `_getHoverContext` returns the four named context callbacks. | See Gate B target map | DEFERRED (hover render-context child) |
| CHW-091 | CHW:235-237 | Context `hide` callback delegates to wrapper `hide`. | See Gate B target map | DEFERRED (hover render-context child) |
| CHW-092 | CHW:238-240 | Context `onContentsChanged` callback delegates to the content widget. | See Gate B target map | DEFERRED (hover render-context child) |
| CHW-093 | CHW:241-243 | Context `setMinimumDimensions` callback forwards the exact dimensions. | See Gate B target map | DEFERRED (hover resize/layout child) |
| CHW-094 | CHW:244 | Context `focus` callback delegates to wrapper focus. | See Gate B target map | DEFERRED (hover focus child) |
| CHW-095 | CHW:321-327 | Excluded sibling member `getWidgetContent` reads the content-widget DOM node and returns its text on the surviving path. | See Gate B target map | DEFERRED (hover render/content API) |
| CHW-096 | CHW:323-325 | Falsy `textContent` returns `undefined` before the final text return. | See Gate B target map | DEFERRED (hover render/content API) |
| CHW-097 | CHW:329-331 | Excluded sibling async member `updateHoverVerbosityLevel`. | See Gate B target map | DEFERRED (hover verbosity child) |
| CHW-098 | CHW:330 | Verbosity update forwards only when a rendered hover exists; absence is a no-op. | See Gate B target map | DEFERRED (hover verbosity child) |
| CHW-099 | CHW:333-335 | Excluded sibling member `doesHoverAtIndexSupportVerbosityAction`. | See Gate B target map | DEFERRED (hover verbosity child) |
| CHW-100 | CHW:334 | Optional rendered-hover support is forwarded; a nullish result falls back to `false`. | See Gate B target map | DEFERRED (hover verbosity child) |
| CHW-101 | CHW:337-339 | Excluded sibling member `getAccessibleWidgetContent`. | See Gate B target map | DEFERRED (hover accessibility child) |
| CHW-102 | CHW:338 | Accessible-content lookup forwards only when a rendered hover exists and otherwise returns `undefined`. | See Gate B target map | DEFERRED (hover accessibility child) |
| CHW-103 | CHW:341-343 | Excluded sibling member `getAccessibleWidgetContentAtIndex`. | See Gate B target map | DEFERRED (hover accessibility child) |
| CHW-104 | CHW:342 | Indexed accessible-content lookup forwards only when a rendered hover exists and otherwise returns `undefined`. | See Gate B target map | DEFERRED (hover accessibility child) |
| CHW-105 | CHW:345-347 | Excluded sibling member `focusedHoverPartIndex`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-106 | CHW:346 | Optional rendered-hover focused index is returned when present; a nullish result takes the fallback. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-107 | CHW:346 | Focused-index fallback magic value is `-1`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-108 | CHW:349-351 | Excluded sibling member `containsNode`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-109 | CHW:350 | A present node is tested against the widget DOM; a nullish node returns `false`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-110 | CHW:353-360 | Excluded sibling member `focus`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-111 | CHW:354 | Hover-part count is read only when a rendered hover exists; absence yields `undefined`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-112 | CHW:355-359 | A singleton rendered hover focuses its part and returns early; every other count focuses the widget. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-113 | CHW:355 | Singleton hover-part count magic value is `1`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-114 | CHW:356 | Singleton focus uses part-index magic value `0`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-115 | CHW:362-364 | Excluded sibling member `focusHoverPartWithIndex`. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-116 | CHW:363 | Indexed part focus forwards only when a rendered hover exists; absence is a no-op. | See Gate B target map | DEFERRED (hover rendered-part focus child) |
| CHW-117 | CHW:366-368 | Excluded sibling member `scrollUp` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-118 | CHW:370-372 | Excluded sibling member `scrollDown` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-119 | CHW:374-376 | Excluded sibling member `scrollLeft` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-120 | CHW:378-380 | Excluded sibling member `scrollRight` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-121 | CHW:382-384 | Excluded sibling member `pageUp` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-122 | CHW:386-388 | Excluded sibling member `pageDown` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-123 | CHW:390-392 | Excluded sibling member `goToTop` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-124 | CHW:394-396 | Excluded sibling member `goToBottom` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-125 | CHW:403-405 | Excluded sibling member `getDomNode` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-126 | CHW:407-409 | Excluded sibling getter `isColorPickerVisible`. | See Gate B target map | N-A (no hover color-picker widget) |
| CHW-127 | CHW:408 | Optional rendered-hover color-picker visibility is forwarded; a nullish result falls back to `false`. | See Gate B target map | N-A (no hover color-picker widget) |
| CHW-128 | CHW:411-413 | Excluded sibling getter `isVisibleFromKeyboard` forwards to the content widget. | See Gate B target map | DEFERRED (hover keyboard/widget-state child) |
| CHW-129 | CHW:415-417 | Excluded sibling getter `isVisible` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-130 | CHW:419-421 | Excluded sibling getter `isFocused` forwards to the content widget. | See Gate B target map | TESTED |
| CHW-131 | CHW:423-425 | Excluded sibling getter `isResizing` forwards to the content widget. | See Gate B target map | DEFERRED (hover resize/layout child) |
| CHW-132 | CHW:427-429 | Excluded sibling getter `widget` returns the content widget. | See Gate B target map | TESTED |
| HOP-001 | HOP:18 | Optional `IHoverComputer.computeAsync(args, token)` receives the cancellation token when invoked after half delay. | See Gate B target map | TESTED |
| HOP-002 | HOP:22 | Optional `IHoverComputer.computeSync(args)` is invoked after the full delay. | See Gate B target map | TESTED |
| HOP-003 | HOP:25-26 | Operation state `Idle` has implicit value `0`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-004 | HOP:27 | Operation state `FirstWait` has implicit value `1`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-005 | HOP:28 | Operation state `SecondWait` has implicit value `2`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-006 | HOP:29 | Operation state `WaitingForAsync = 3`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-007 | HOP:30 | Operation state `WaitingForAsyncShowingLoading = 4`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-008 | HOP:33-34 | Start mode `Delayed = 0`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-009 | HOP:35 | Start mode `Immediate = 1`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-010 | HOP:38-39 | Start source `Mouse = 0`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-011 | HOP:40 | Start source `Click = 1`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-012 | HOP:41 | Start source `Keyboard = 2`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HOP-013 | HOP:46 | `HoverResult.value` member. | See Gate B target map | TESTED |
| HOP-014 | HOP:47 | `HoverResult.isComplete` member. | See Gate B target map | TESTED |
| HOP-015 | HOP:48 | `HoverResult.hasLoadingMessage` member. | See Gate B target map | TESTED |
| HOP-016 | HOP:49 | `HoverResult.options` member. | See Gate B target map | TESTED |
| HOP-017 | HOP:44-50 | `HoverResult` constructor retains all four facts. | See Gate B target map | TESTED |
| HOP-018 | HOP:65 | Owned result emitter. | See Gate B target map | TESTED |
| HOP-019 | HOP:66 | Public result event alias. | See Gate B target map | TESTED |
| HOP-020 | HOP:68 | Async-computation scheduler field owns one registered debouncer. | See Gate B target map | TESTED |
| HOP-021 | HOP:68 | Async scheduler callback forwards its latest options to `_triggerAsyncComputation`. | See Gate B target map | TESTED |
| HOP-022 | HOP:68 | Async-computation debouncer default delay is exactly `0`. | See Gate B target map | TESTED |
| HOP-023 | HOP:69 | Sync-computation scheduler field owns one registered debouncer. | See Gate B target map | TESTED |
| HOP-024 | HOP:69 | Sync scheduler callback forwards its latest options to `_triggerSyncComputation`. | See Gate B target map | TESTED |
| HOP-025 | HOP:69 | Sync-computation debouncer default delay is exactly `0`. | See Gate B target map | TESTED |
| HOP-026 | HOP:70 | Loading-message scheduler field owns one registered debouncer. | See Gate B target map | TESTED |
| HOP-027 | HOP:70 | Loading scheduler callback forwards its latest options to `_triggerLoadingMessage`. | See Gate B target map | TESTED |
| HOP-028 | HOP:70 | Loading-message debouncer default delay is exactly `0`. | See Gate B target map | TESTED |
| HOP-029 | HOP:72 | State starts `Idle`. | See Gate B target map | TESTED |
| HOP-030 | HOP:73 | Cancelable async iterable starts null. | See Gate B target map | TESTED |
| HOP-031 | HOP:74 | Async-done flag starts false. | See Gate B target map | TESTED |
| HOP-032 | HOP:75 | Accumulated result starts empty. | See Gate B target map | TESTED |
| HOP-033 | HOP:76 | Current options start undefined. | See Gate B target map | TESTED |
| HOP-034 | HOP:79 | Editor dependency member. | See Gate B target map | TESTED |
| HOP-035 | HOP:80 | Computer dependency member. | See Gate B target map | TESTED |
| HOP-036 | HOP:78-83 | Constructor establishes disposable ownership. | See Gate B target map | TESTED |
| HOP-037 | HOP:85-91 | Override disposal clears options before base disposal after the optional iterable branch. | See Gate B target map | TESTED |
| HOP-038 | HOP:86-89 | Dispose cancels/nulls an existing iterable; an absent iterable skips both operations. | See Gate B target map | TESTED |
| HOP-039 | HOP:94-96 | Hover time reads configured delay. | See Gate B target map | DEFERRED (live configured-delay owner absent) |
| HOP-040 | HOP:98-100 | First-wait getter derives its duration from hover time. | See Gate B target map | TESTED |
| HOP-041 | HOP:99 | First-wait divisor is exactly `2`. | See Gate B target map | TESTED |
| HOP-042 | HOP:102-104 | Second wait is delay minus first wait. | See Gate B target map | TESTED |
| HOP-043 | HOP:106-108 | Loading-time getter derives its duration from hover time. | See Gate B target map | TESTED |
| HOP-044 | HOP:107 | Loading-time multiplier is exactly `3`. | See Gate B target map | TESTED |
| HOP-045 | HOP:110-114 | `_setState` assigns options first, state second, then fires the result. | See Gate B target map | TESTED |
| HOP-046 | HOP:116-119 | Async trigger enters `SecondWait` and schedules sync remainder. | See Gate B target map | TESTED |
| HOP-047 | HOP:120-123 | Async-computer presence resets completion and creates the fresh cancelable iterable. | See Gate B target map | TESTED |
| HOP-048 | HOP:122 | Cancelable-producer callback propagates its cancellation token to the async computer. | See Gate B target map | TESTED |
| HOP-049 | HOP:124-141 | Detached async-IIFE callback consumes the producer and marks iteration complete before its waiting-state branch. | See Gate B target map | TESTED |
| HOP-050 | HOP:127-130 | Truthy item mutates shared result and fires; falsy item is ignored, with no token/options/operation-identity guard before mutation. | See Gate B target map | N-A (typed arrays remove falsy items and guards are stronger) |
| HOP-051 | HOP:134-136 | Waiting states transition to `Idle` using captured options; non-waiting states do not transition. | See Gate B target map | TESTED |
| HOP-052 | HOP:138-140 | Async failure is contained by `onUnexpectedError`. | See Gate B target map | TESTED |
| HOP-053 | HOP:143-145 | Missing async computer marks async done immediately. | See Gate B target map | N-A (async computation is a required trait member) |
| HOP-054 | HOP:148 | Sync trigger member. | See Gate B target map | TESTED |
| HOP-055 | HOP:149-151 | Present sync computer concatenates results; missing sync computer preserves accumulated result. | See Gate B target map | TESTED |
| HOP-056 | HOP:152 | Post-sync state is `Idle` if async done, otherwise `WaitingForAsync`. | See Gate B target map | TESTED |
| HOP-057 | HOP:155 | Loading trigger member. | See Gate B target map | TESTED |
| HOP-058 | HOP:156-158 | Only `WaitingForAsync` enters loading state. | See Gate B target map | TESTED |
| HOP-059 | HOP:161-168 | Result firing derives completeness/loading flags, snapshots accumulated results, constructs `HoverResult`, then fires the emitter. | See Gate B target map | TESTED |
| HOP-060 | HOP:162-165 | First/second wait returns without emission. | See Gate B target map | TESTED |
| HOP-061 | HOP:171 | Public start member. | See Gate B target map | TESTED |
| HOP-062 | HOP:172 | Delayed mode branch. | See Gate B target map | TESTED |
| HOP-063 | HOP:173-177 | Delayed start acts only from `Idle`, entering first wait and scheduling async/loading timers; other states no-op. | See Gate B target map | TESTED |
| HOP-064 | HOP:178-184 | Bare non-`Delayed` `Idle` arm triggers async, cancels the sync timer, then triggers sync. | See Gate B target map | TESTED |
| HOP-065 | HOP:185-188 | Bare non-`Delayed` `SecondWait` arm cancels the sync timer then triggers sync. | See Gate B target map | TESTED |
| HOP-066 | HOP:179-189 | Every other state in the bare non-`Delayed` branch has no switch arm and no-ops; runtime values other than enum `Immediate` enter the same branch. | See Gate B target map | TESTED |
| HOP-067 | HOP:193-203 | Public cancel retires all schedulers, clears result/options, and returns state to `Idle` around the optional-iterable branch. | See Gate B target map | TESTED |
| HOP-068 | HOP:197-200 | Cancel retires/nulls an active iterable; absent iterable skips both operations. | See Gate B target map | TESTED |
| HOP-069 | HOP:206-208 | Options getter returns current optional options. | See Gate B target map | TESTED |
| HOP-070 | HOP:213 | Debouncer owns one run-once scheduler. | See Gate B target map | TESTED |
| HOP-071 | HOP:215 | Debouncer retains latest options. | See Gate B target map | TESTED |
| HOP-072 | HOP:217-220 | Debouncer constructor calls `super()` before registering its scheduler with the supplied default delay. | See Gate B target map | TESTED |
| HOP-073 | HOP:219 | Scheduler callback reads the latest mutable `_options` at execution and passes it to the runner. | See Gate B target map | TESTED |
| HOP-074 | HOP:222-225 | Schedule stores options then schedules requested delay. | See Gate B target map | TESTED |
| HOP-075 | HOP:227-229 | Cancel delegates scheduler cancellation. | See Gate B target map | TESTED |
| CHCMP-001 | CHCMP:15 | Options `shouldFocus` member. | See Gate B target map | TESTED |
| CHCMP-002 | CHCMP:16 | Options `anchor` member. | See Gate B target map | TESTED |
| CHCMP-003 | CHCMP:17 | Options `source` member. | See Gate B target map | TESTED |
| CHCMP-004 | CHCMP:18 | Options `insistOnKeepingHoverVisible` member. | See Gate B target map | TESTED |
| CHCMP-005 | CHCMP:24 | Editor dependency member. | See Gate B target map | N-A (computer retains no TypeScript editor dependency) |
| CHCMP-006 | CHCMP:25 | Ordered participant dependency member. | See Gate B target map | TESTED |
| CHCMP-007 | CHCMP:23-27 | Constructor retains editor and participants. | See Gate B target map | PORTED |
| CHCMP-008 | CHCMP:29-64 | Static line-decoration selection captures model/line/max-column and returns the filtered decorations. | See Gate B target map | TESTED |
| CHCMP-009 | CHCMP:30-32 | Non-range anchor without marker support returns empty. | See Gate B target map | TESTED |
| CHCMP-010 | CHCMP:37-40 | Line beyond model line count returns empty. | See Gate B target map | TESTED |
| CHCMP-011 | CHCMP:44-64 | Line-decoration filter callback accepts every decoration surviving its whole-line and containment branches. | See Gate B target map | TESTED |
| CHCMP-012 | CHCMP:45-47 | Whole-line decoration returns true immediately. | See Gate B target map | TESTED |
| CHCMP-013 | CHCMP:49 | Start-column ternary selects the decoration start on the anchor line and the fallback on a crossing range. | See Gate B target map | TESTED |
| CHCMP-014 | CHCMP:49 | Cross-line start-column fallback is exactly `1`. | See Gate B target map | TESTED |
| CHCMP-015 | CHCMP:50 | End column is same-line end or max column. | See Gate B target map | TESTED |
| CHCMP-016 | CHCMP:52 | `showIfCollapsed` selects relaxed containment. | See Gate B target map | TESTED |
| CHCMP-017 | CHCMP:54-56 | Relaxed containment branch rejects decorations outside its expanded boundary. | See Gate B target map | TESTED |
| CHCMP-018 | CHCMP:54 | Collapsed-decoration relaxation is exactly anchor `+1` at the start and `-1` at the end. | See Gate B target map | TESTED |
| CHCMP-019 | CHCMP:57-60 | Ordinary check rejects strict noncontainment. | See Gate B target map | TESTED |
| CHCMP-020 | CHCMP:67-83 | Async computation captures anchor/decorations and merges the mapped participant producers. | See Gate B target map | TESTED |
| CHCMP-021 | CHCMP:70-72 | Missing editor model or anchor returns empty producer. | See Gate B target map | N-A (computer receives a required explicit model and anchor) |
| CHCMP-022 | CHCMP:77-82 | Participant-mapping callback preserves array order and calls each present async member with anchor, decorations, source, and token. | See Gate B target map | TESTED |
| CHCMP-023 | CHCMP:78-80 | Participant without async member contributes empty producer. | See Gate B target map | N-A (async computation is a required trait member) |
| CHCMP-024 | CHCMP:86-99 | Synchronous computation captures anchor/decorations, accumulates in participant order, and coalesces the final result. | See Gate B target map | TESTED |
| CHCMP-025 | CHCMP:87-89 | Missing editor model returns empty. | See Gate B target map | N-A (computer receives a required explicit model) |
| CHCMP-026 | CHCMP:94-97 | Sync accumulation starts at `[]` and concatenates participant results in participant order. | See Gate B target map | TESTED |
| GHR-001 | GHR:18 | Provider-result `provider` member. | See Gate B target map | DEFERRED (P2 provider scoring/order surface) |
| GHR-002 | GHR:19 | Provider-result `hover` member. | See Gate B target map | DEFERRED (P2 provider scoring/order surface) |
| GHR-003 | GHR:20 | Provider-result `ordinal` member. | See Gate B target map | DEFERRED (P2 provider scoring/order surface) |
| GHR-004 | GHR:16-21 | Constructor retains provider, hover, ordinal. | See Gate B target map | DEFERRED (P2 provider scoring/order surface) |
| GHR-005 | GHR:27-35 | `executeProvider` invokes with model/position/token, has no pre/post cancellation check, and constructs the valid provider result. | See Gate B target map | N-A (central provider path adds pre and post freshness guards) |
| GHR-006 | GHR:30 | Returned-promise rejection is contained as undefined; a synchronous provider throw rejects `executeProvider` itself. | See Gate B target map | N-A (no synchronous-throw versus Promise-rejection distinction) |
| GHR-007 | GHR:31-33 | Missing or invalid result returns undefined. | See Gate B target map | TESTED |
| GHR-008 | GHR:37-40 | Async-iterable member defaults `recursive=false`, orders providers, builds promises, then yields resolution order with undefined results coalesced. | See Gate B target map | DEFERRED (P2 multi-provider ordering/aggregation) |
| GHR-009 | GHR:39 | `map` eagerly invokes all ordered providers before iterable consumption, in registry order, and each provider index becomes its stable ordinal. | See Gate B target map | DEFERRED (P2 multi-provider ordering/aggregation) |
| GHR-010 | GHR:43-48 | `getHoversPromise` defaults `recursive=false`, accumulates the iterable, and returns hovers in resolution order. | See Gate B target map | DEFERRED (P2 multi-provider ordering/aggregation) |
| GHR-011 | GHR:45-46 | Async iteration consumes to completion and appends each valid hover. | See Gate B target map | DEFERRED (P2 multi-provider ordering/aggregation) |
| GHR-012 | GHR:51 | Registered hover-provider command ID is exactly `_executeHoverProvider`. | See Gate B target map | DEFERRED (P2 public provider command surface) |
| GHR-013 | GHR:51-54 | Hover-provider command callback looks up the language-features service, then delegates registry/model/position with `CancellationToken.None`. | See Gate B target map | DEFERRED (P2 public provider command surface) |
| GHR-014 | GHR:56 | Registered recursive hover-provider command ID is exactly `_executeHoverProvider_recursive`. | See Gate B target map | DEFERRED (P2 public provider command surface) |
| GHR-015 | GHR:56-59 | Recursive command callback performs the same service lookup/delegation with `None` and recursive `true`. | See Gate B target map | DEFERRED (P2 public provider command surface) |
| GHR-016 | GHR:61-64 | Hover validity requires range not `undefined` (runtime `null` passes) and defined/truthy/nonempty contents. | See Gate B target map | TESTED |
| HTY-001 | HTY:21 | Hover part retains owner participant. | See Gate B target map | DEFERRED (rendered-part/participant ownership child) |
| HTY-002 | HTY:25 | Hover part retains applicable range. | See Gate B target map | TESTED |
| HTY-003 | HTY:30 | Optional force-show-at-range member. | See Gate B target map | DEFERRED (hover layout child) |
| HTY-004 | HTY:35 | Optional before-content ordering member. | See Gate B target map | DEFERRED (hover render-order child) |
| HTY-005 | HTY:39 | Part validity member consumes new anchor. | See Gate B target map | TESTED |
| HTY-006 | HTY:42-43 | Anchor type `Range = 1`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HTY-007 | HTY:44 | Anchor type `ForeignElement = 2`. | See Gate B target map | N-A (typed enum has no observable numeric encoding) |
| HTY-008 | HTY:48 | Range anchor constant type. | See Gate B target map | TESTED |
| HTY-009 | HTY:50 | Range anchor priority member. | See Gate B target map | TESTED |
| HTY-010 | HTY:51 | Range anchor range member. | See Gate B target map | TESTED |
| HTY-011 | HTY:52 | Range anchor initial mouse X member. | See Gate B target map | TESTED |
| HTY-012 | HTY:53 | Range anchor initial mouse Y member. | See Gate B target map | TESTED |
| HTY-013 | HTY:49-55 | Range anchor constructor retains fields. | See Gate B target map | TESTED |
| HTY-014 | HTY:56-58 | Range equality requires range type and equal range. | See Gate B target map | TESTED |
| HTY-015 | HTY:59-61 | Range adoption requires a prior range anchor and compares `showAtPosition.lineNumber` with the new anchor's start line; it does not compare the two anchor ranges. | See Gate B target map | TESTED |
| HTY-016 | HTY:65 | Foreign anchor constant type. | See Gate B target map | TESTED |
| HTY-017 | HTY:67 | Foreign anchor priority member. | See Gate B target map | TESTED |
| HTY-018 | HTY:68 | Foreign anchor owner member. | See Gate B target map | TESTED |
| HTY-019 | HTY:69 | Foreign anchor range member. | See Gate B target map | TESTED |
| HTY-020 | HTY:70 | Foreign anchor initial mouse X member. | See Gate B target map | TESTED |
| HTY-021 | HTY:71 | Foreign anchor initial mouse Y member. | See Gate B target map | TESTED |
| HTY-022 | HTY:72 | Foreign anchor marker-hover support member. | See Gate B target map | TESTED |
| HTY-023 | HTY:66-74 | Foreign anchor constructor retains fields. | See Gate B target map | TESTED |
| HTY-024 | HTY:75-77 | Foreign equality requires foreign type and same owner identity. | See Gate B target map | TESTED |
| HTY-025 | HTY:78-80 | Foreign adoption requires prior foreign anchor and same owner. | See Gate B target map | TESTED |
| HTY-026 | HTY:83 | Hover anchor union is range or foreign. | See Gate B target map | TESTED |
| HTY-027 | HTY:162 | Participant hover ordinal member. | See Gate B target map | TESTED |
| HTY-028 | HTY:164 | Optional anchor-suggestion member. | See Gate B target map | N-A (anchor suggester is a required option-returning member) |
| HTY-029 | HTY:165 | Synchronous computation member. | See Gate B target map | TESTED |
| HTY-030 | HTY:166 | Optional async computation receives anchor, line decorations, source, then cancellation token. | See Gate B target map | N-A (async computation is a required token-aware member) |
| HTY-031 | HTY:167 | Optional loading-message member. | See Gate B target map | N-A (loading factory is a required option-returning member) |
| HTY-032 | HTY:176 | Participant constructor signature consumes editor. | See Gate B target map | N-A (service-capturing factory replaces editor/DI constructor signature) |
| HTY-033 | HTY:180 | Registry owns a participant-constructor array initialized to empty. | See Gate B target map | TESTED |
| HTY-034 | HTY:182-184 | Register appends constructor. | See Gate B target map | TESTED |
| HTY-035 | HTY:186-188 | `getAll` returns the mutable backing constructor array itself, not a copy. | See Gate B target map | TESTED |
| HTY-036 | HTY:198 | Widget `showsOrWillShow` member. | See Gate B target map | TESTED |
| HTY-037 | HTY:203 | Widget `hide` member. | See Gate B target map | TESTED |
| HTY-038 | HTY:86 | Excluded `IEditorHoverStatusBar.addAction` member. | See Gate B target map | DEFERRED (hover status/action child) |
| HTY-039 | HTY:86 | Inline action-options type declares required `label`. | See Gate B target map | DEFERRED (hover status/action child) |
| HTY-040 | HTY:86 | Inline action-options type declares optional `iconClass`. | See Gate B target map | DEFERRED (hover status/action child) |
| HTY-041 | HTY:86 | Inline action-options type declares `run(target)` callback member. | See Gate B target map | DEFERRED (hover status/action child) |
| HTY-042 | HTY:86 | Inline action-options type declares required `commandId`. | See Gate B target map | DEFERRED (hover status/action child) |
| HTY-043 | HTY:87 | Excluded `IEditorHoverStatusBar.append` member. | See Gate B target map | DEFERRED (hover status/action child) |
| HTY-044 | HTY:91 | Excluded `IEditorHoverAction.setEnabled` member. | See Gate B target map | DEFERRED (hover status/action child) |
| HTY-045 | HTY:95 | Excluded `IEditorHoverColorPickerWidget.layout` member. | See Gate B target map | N-A (no hover color-picker widget) |
| HTY-046 | HTY:102 | Excluded `IEditorHoverContext.onContentsChanged` member. | See Gate B target map | DEFERRED (hover render-context child) |
| HTY-047 | HTY:106 | Excluded `IEditorHoverContext.setMinimumDimensions` member. | See Gate B target map | DEFERRED (hover resize/layout child) |
| HTY-048 | HTY:110 | Excluded `IEditorHoverContext.hide` member. | See Gate B target map | DEFERRED (hover render/focus child) |
| HTY-049 | HTY:114 | Excluded `IEditorHoverContext.focus` member. | See Gate B target map | DEFERRED (hover render/focus child) |
| HTY-050 | HTY:121 | Excluded `IEditorHoverRenderContext.fragment` member. | See Gate B target map | DEFERRED (hover DOM/render child) |
| HTY-051 | HTY:125 | Excluded `IEditorHoverRenderContext.statusBar` member. | See Gate B target map | DEFERRED (hover DOM/render child) |
| HTY-052 | HTY:132 | Excluded `IRenderedHoverPart.hoverPart` member. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| HTY-053 | HTY:136 | Excluded `IRenderedHoverPart.hoverElement` member. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| HTY-054 | HTY:143 | Excluded `IRenderedHoverParts.renderedHoverParts` member. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| HTY-055 | HTY:151 | Excluded `RenderedHoverParts.renderedHoverParts` parameter-property. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| HTY-056 | HTY:151 | Excluded optional `RenderedHoverParts.disposables` parameter-property. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| HTY-057 | HTY:151 | Excluded `RenderedHoverParts` constructor retains both parameter-properties. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| HTY-058 | HTY:153-158 | Excluded `RenderedHoverParts.dispose` visits and disposes parts in array order before the aggregate-disposable check. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| HTY-059 | HTY:157 | Present aggregate disposable is retired after all parts; absence is a no-op. | See Gate B target map | DEFERRED (rendered-part lifecycle child) |
| HTY-060 | HTY:163 | Excluded optional participant `hideCopyButton` member. | See Gate B target map | DEFERRED (hover copy-affordance child) |
| HTY-061 | HTY:168 | Excluded participant `renderHoverParts` member. | See Gate B target map | N-A (central renderer replaces participant render member) |
| HTY-062 | HTY:169 | Excluded participant `getAccessibleContent` member. | See Gate B target map | DEFERRED (hover accessibility child) |
| HTY-063 | HTY:170 | Excluded optional participant `handleResize` member. | See Gate B target map | DEFERRED (hover resize/layout child) |
| HTY-064 | HTY:171 | Excluded optional participant `handleHide` member. | See Gate B target map | DEFERRED (participant render-lifecycle child) |
| HTY-065 | HTY:172 | Excluded optional participant `handleContentsChanged` member. | See Gate B target map | DEFERRED (participant render-lifecycle child) |
| HTY-066 | HTY:173 | Excluded optional participant `handleScroll` member. | See Gate B target map | DEFERRED (participant render-lifecycle child) |
| HTY-067 | HTY:178-190 | Exported `HoverParticipantRegistry` singleton constant constructs the anonymous registry class instance. | See Gate B target map | PORTED |
| TMV-001 | TMV:123 | Module model-identity counter `MODEL_ID` starts `0`. | See Gate B target map | N-A (generated model ID is not an async identity key) |
| TMV-002 | TMV:250,319 | Public `id` field retains physical model-instance ID text with exact `$model` prefix. | See Gate B target map | N-A (generated model ID is not an async identity key) |
| TMV-003 | TMV:252 | Private `_associatedResource` field retains the model URI. | See Gate B target map | TESTED |
| TMV-004 | TMV:262,370 | Private monotonic `_versionId` field initializes to exactly `1`. | See Gate B target map | TESTED |
| TMV-005 | TMV:263-266,371 | Private `_alternativeVersionId` initializes to exactly `1` and may later decrease or repeat through undo/redo. | See Gate B target map | N-A (no alternative-version/undo-redo model) |
| TMV-006 | TMV:318-325,370-371 | Constructor identity slice increments `MODEL_ID`, assigns the `$model`-prefixed physical ID, chooses the resource, then initializes both version fields to `1`. | See Gate B target map | N-A (physical object identity replaces generated model IDs) |
| TMV-007 | TMV:309,321-323 | Null or undefined resource takes the generated-resource branch with exact prefix `inmemory://model/`. | See Gate B target map | N-A (MoonBit construction requires an explicit URI) |
| TMV-008 | TMV:323-325 | Supplied resource is retained exactly. | See Gate B target map | TESTED |
| TMV-009 | TMV:671-673 | Public `uri` getter returns the associated resource without a disposed guard. | See Gate B target map | TESTED |
| TMV-010 | TMV:737-740 | `getVersionId` asserts not disposed, then returns internal version. | See Gate B target map | N-A (local version reads have no disposed assertion) |
| TMV-011 | TMV:782-785 | `_increaseVersionId` increments the monotonic version by exactly `1`, then mirrors it to alternative version. | See Gate B target map | DEFERRED (alternative-version and undo model absent) |
| TMV-012 | TMV:484-493 | Public `setValue` asserts live model, rejects null/undefined, creates a text buffer for every other input without an equality no-op, then delegates. | See Gate B target map | TESTED |
| TMV-013 | TMV:487-489 | Null or undefined `setValue` input throws before buffer creation or version mutation. | See Gate B target map | N-A (MoonBit `String` input is non-nullable) |
| TMV-014 | TMV:514-545 | `_setValueFromTextBuffer` captures old extent, swaps buffer/disposable, increments exactly once, clears decorations/history/settings, then calls the raw/public flush-emission path. | See Gate B target map | TESTED |
| TMV-015 | TMV:495-511 | `_createContentChanged2` observes current post-transition version through `getVersionId()` in the public event payload. | See Gate B target map | TESTED |
| TMV-016 | TMV:547-575 | `setEOL` asserts live model; changed flow runs hooks around mutation/increment, then emits events with post-increment version. | See Gate B target map | DEFERRED (EOL child ownership) |
| TMV-017 | TMV:549 | Explicit excluded EOL-selection branch maps CRLF to exact `\r\n` and every other sequence to exact `\n`. | See Gate B target map | DEFERRED (EOL child ownership) |
| TMV-018 | TMV:550-552 | Equal EOL returns before mutation, increment, hooks, or events. | See Gate B target map | DEFERRED (EOL child ownership) |
| TMV-019 | TMV:1503-1601 | `_doApplyEdits` applies buffer edits and trim state first; its content-change branch controls decoration transforms, one version increment, raw/public events, and final reverse-edit return. | See Gate B target map | N-A (incremental editing/reverse-edit lane absent from readonly Viewer) |
| TMV-020 | TMV:1512-1599 | Nonempty changes transform every decoration first, increment exactly once, build raw changes, then emit both events carrying post-increment version. | See Gate B target map | N-A (incremental editing/reverse-edit lane absent from readonly Viewer) |
| TMV-021 | TMV:1506,1509-1512,1599 | After buffer apply and trim-state assignment, empty `contentChanges` skips decoration transforms, version increment, and event emission. | See Gate B target map | N-A (incremental editing/reverse-edit lane absent from readonly Viewer) |
| TMV-022 | TMV:1601 | Final reverse-edit branch maps `null` to `undefined` and otherwise returns `reverseEdits`. | See Gate B target map | N-A (incremental editing/reverse-edit lane absent from readonly Viewer) |
| TMV-023 | TMV:787-789 | `_overwriteVersionId` directly assigns a supplied version that may decrease/repeat and leaves alternative version unchanged. | See Gate B target map | N-A (undo/alternative-version overwrite APIs absent) |
| TMV-024 | TMV:760-763 | Explicit excluded sibling `getAlternativeVersionId` asserts live model, then returns alternative version. | See Gate B target map | N-A (undo/alternative-version overwrite APIs absent) |
| TMV-025 | TMV:791-793 | Explicit excluded sibling `_overwriteAlternativeVersionId` directly assigns its supplied value. | See Gate B target map | N-A (undo/alternative-version overwrite APIs absent) |
| TMV-026 | TMV:284,377,2030 | Explicit excluded decoration member `_instanceId` is initialized from `singleLetterHash(MODEL_ID)` and prefixes generated decoration IDs with exact separator `;`. | See Gate B target map | N-A (decoration instance prefix is not physical request identity) |
| CTS-001 | CTS:14 | Token contract readonly `isCancellationRequested` property. | See Gate B target map | TESTED |
| CTS-002 | CTS:16-24 | Token contract readonly cancellation event property covers listener, context, optional disposable bucket, once-only fire, and next-turn late listeners. | See Gate B target map | DEFERRED (context and disposable-bucket event surface absent) |
| CTS-003 | CTS:27-30 | Frozen `shortcutEvent` callback binds the supplied context, schedules delivery, and returns handle disposal. | See Gate B target map | DEFERRED (context and disposable-bucket event surface absent) |
| CTS-004 | CTS:28 | Shortcut-event timeout is exactly `0`. | See Gate B target map | DEFERRED (context and disposable-bucket event surface absent) |
| CTS-005 | CTS:29 | Shortcut-event returned object callback clears the timeout handle on disposal. | See Gate B target map | DEFERRED (context and disposable-bucket event surface absent) |
| CTS-006 | CTS:49-52 | Frozen `None` token is false and uses `Event.None`. | See Gate B target map | TESTED |
| CTS-007 | CTS:54-57 | Frozen `Cancelled` token is true and uses `shortcutEvent`. | See Gate B target map | DEFERRED (shared scheduled Cancelled singleton not used) |
| CTS-008 | CTS:62 | Mutable canceled-state field starts `false`. | See Gate B target map | TESTED |
| CTS-009 | CTS:63 | Mutable emitter field starts `null`. | See Gate B target map | TESTED |
| CTS-010 | CTS:65-73 | `MutableToken.cancel` performs the one-way state/notification transition. | See Gate B target map | TESTED |
| CTS-011 | CTS:66-72 | Only the first cancel flips the flag before notification; repeated cancel is a no-op. | See Gate B target map | TESTED |
| CTS-012 | CTS:68-71 | Existing emitter fires once and is disposed/reset; missing emitter skips notification. | See Gate B target map | TESTED |
| CTS-013 | CTS:75-77 | `isCancellationRequested` getter returns the flag. | See Gate B target map | TESTED |
| CTS-014 | CTS:79-87 | `onCancellationRequested` getter returns shortcut or one lazy emitter event. | See Gate B target map | TESTED |
| CTS-015 | CTS:80-82 | Already-canceled getter returns `shortcutEvent` immediately. | See Gate B target map | TESTED |
| CTS-016 | CTS:83-85 | Before cancellation, missing emitter is allocated; existing emitter is reused. | See Gate B target map | TESTED |
| CTS-017 | CTS:89-94 | `MutableToken.dispose` retires only listener state and leaves cancellation flag unchanged. | See Gate B target map | TESTED |
| CTS-018 | CTS:90-93 | Existing emitter disposes and resets to `null`; missing emitter is a no-op. | See Gate B target map | TESTED |
| CTS-019 | CTS:99 | Source token field starts `undefined`. | See Gate B target map | TESTED |
| CTS-020 | CTS:100 | Parent-listener field starts `undefined` and is source-owned. | See Gate B target map | TESTED |
| CTS-021 | CTS:102-104 | Source constructor derives its optional parent listener. | See Gate B target map | TESTED |
| CTS-022 | CTS:103 | Present parent subscribes `this.cancel` with source context; absent parent installs nothing. | See Gate B target map | TESTED |
| CTS-023 | CTS:106-113 | `token` getter returns the current singleton/mutable token. | See Gate B target map | DEFERRED (singleton token identity shortcut not used) |
| CTS-024 | CTS:107-111 | Missing token lazily allocates one `MutableToken` before return. | See Gate B target map | TESTED |
| CTS-025 | CTS:115-126 | Source `cancel` chooses allocation-free canceled singleton, mutable cancellation, or singleton no-op. | See Gate B target map | DEFERRED (cancel-before-read singleton shortcut not used) |
| CTS-026 | CTS:116-121 | Cancel before token read stores shared `Cancelled` without allocation. | See Gate B target map | DEFERRED (cancel-before-read singleton shortcut not used) |
| CTS-027 | CTS:122-125 | Existing `MutableToken` delegates to its cancel transition. | See Gate B target map | TESTED |
| CTS-028 | CTS:122-126 | Existing `None` or `Cancelled` singleton takes the nonmutable no-op path. | See Gate B target map | TESTED |
| CTS-029 | CTS:128-141 | Source `dispose` optionally cancels, disposes parent listener, then chooses no-token initialization, mutable-listener disposal, or singleton no-op. | See Gate B target map | TESTED |
| CTS-030 | CTS:129-131 | Explicit `cancel=true` performs cancellation before disposal; false skips it. | See Gate B target map | TESTED |
| CTS-031 | CTS:128 | Source-dispose `cancel` parameter defaults exactly to `false`. | See Gate B target map | TESTED |
| CTS-032 | CTS:132 | Present parent listener disposes; absence is a no-op, and the field is not cleared so repeated dispose repeats the call. | See Gate B target map | TESTED |
| CTS-033 | CTS:133-136 | Dispose before token read stores shared `None`; later cancel is a no-op. | See Gate B target map | TESTED |
| CTS-034 | CTS:137-140 | Existing mutable token disposes listeners but retains the same token and flag. | See Gate B target map | TESTED |
| CTS-035 | CTS:137-141 | Existing singleton token takes the nonmutable no-op path. | See Gate B target map | TESTED |
| CTS-036 | CTS:34-46 | Explicit excluded `isCancellationToken` member accepts exact singleton/mutable identities, rejects nonobjects, and otherwise performs structural boolean/event checks. | See Gate B target map | N-A (MoonBit static typing replaces structural token recognition) |
| CTS-037 | CTS:35-37 | `None` or `Cancelled` identity returns `true` immediately. | See Gate B target map | N-A (MoonBit static typing replaces structural token recognition) |
| CTS-038 | CTS:38-40 | `MutableToken` instance returns `true` immediately. | See Gate B target map | N-A (MoonBit static typing replaces structural token recognition) |
| CTS-039 | CTS:41-43 | Falsy or nonobject input returns `false` before structural checks. | See Gate B target map | N-A (MoonBit static typing replaces structural token recognition) |
| CTS-040 | CTS:144-148 | Explicit excluded `cancelOnDispose` creates a source, registers cancellation disposal, then returns its token. | See Gate B target map | DEFERRED (no scoped consumer) |
| CTS-041 | CTS:146 | `cancelOnDispose` store-owned object callback cancels its source. | See Gate B target map | DEFERRED (no scoped consumer) |
| CTS-042 | CTS:158 | Excluded pool `_source` field starts a fresh cancellation source. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-043 | CTS:159 | Excluded pool `_listeners` owns token subscriptions. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-044 | CTS:161 | Excluded pool `_total` starts `0`. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-045 | CTS:162 | Excluded pool `_cancelled` starts `0`. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-046 | CTS:163 | Excluded pool `_isDone` starts `false`. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-047 | CTS:165-167 | Excluded pool `token` getter returns source token. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-048 | CTS:173-192 | Excluded pool `add` increments total, handles already-canceled input, or retains one cancellation listener. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-049 | CTS:186-190 | Pool cancellation-listener callback self-disposes, increments canceled count, and rechecks completion. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-050 | CTS:174-176 | Adding after pool completion returns before counters/listeners. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-051 | CTS:180-184 | Already-canceled input increments canceled count, checks completion, and returns before subscription. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-052 | CTS:194-200 | Excluded pool `_check` evaluates completion and performs its ordered transition. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-053 | CTS:195-199 | Only not-done, positive-total, exact total=canceled state marks done, disposes listeners, then cancels pool source. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-054 | CTS:195 | Pool positive-total threshold is exactly `0`. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
| CTS-055 | CTS:202-205 | Excluded pool `dispose` retires listeners before disposing source. | See Gate B target map | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |
<!-- SOURCE_LEDGER_END -->

Historical Gate B stop: implementation did not begin until this inventory and
ledger milestone was committed and independently approved.

### Separate local ownership audit (Gate B baseline)

The local audit has **87 rows** and is deliberately outside the 810-row
pinned-source denominator. It records implementation and test authority as they
stood at Gate B; it did not pre-approve any target mapping or deviation.

| ID | Area | Local owner | Gate B behavior / audit finding |
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
| LA-046 | Inlay | `viewer/common/languages/languages.mbt:19-32,109-116,184-197` | Registry exposes no observed change event; disposing an in-flight provider removes it from the live entries array but its post-await result is still accepted. Because the MoonBit range bound is fixed while the indexed array stays live, the shift can skip a later provider and a later iteration can index beyond the shortened array. |
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

## Gate B Target Contract (historical)

At Gate B these were review proposals rather than implemented behavior or
terminal ledger statuses. The implementation and closing ledger above now
record the adopted contract and evidence.

| Contract | Required implementation shape |
|---|---|
| Request stamp | Every inlay/hover operation captures the physical `TextModel`, its `get_version_id()`, a controller-lifetime monotonic generation, and a caller-owned cancellation token. URI, host `version`, `revision`, and decoration `instance_id` are not freshness keys. |
| Freshness predicate | A continuation may mutate only while the Viewer/controller is live, the captured model is physically current, its internal version is unchanged, the generation is current, and the token is not canceled. |
| Cancellation owner | The current inlay session or hover operation owns one source/store and cancels it before replacement, content/model invalidation, detach, model disposal, Viewer disposal, or operation disposal. Generations never reset on model swaps. |
| Timers | Mouse-react and hover async/sync/loading timers have clearable owned handles. Cancellation clears the handle and invalidates its generation; callbacks retain guards for a dispatch race. |
| Provider chain | The caller creates the token and forwards that same value through computer/participant/registry/provider boundaries. Ordinary failures remain contained/logged; cancellation never commits data. |
| Apply boundary | Only the newest request may replace controller data, delta decorations, change hover state, schedule rendering, or fire hover resolution. A stale empty result cannot clear a newer nonempty result. |

`same_identity_and_version` was not approved as async authority. Closing review
found no remaining non-async consumer, so implementation removed the helper.

## Gate B Reviewed Target and Planned-Disposition Map

At Gate B this map assigned every source row to an implementation/evidence
target or an explicit seam. It is exhaustive over the 810-row denominator.
`TESTED` and `PORTED` below were planned dispositions while every ledger row
remained `TODO`; the source ledger now carries the reviewed terminal values.

Inlay/model/cancellation target key:

- `C`: `language/cancellation.mbt` token, mutable-token, source, and shortcut
  event symbols;
- `H`: `viewer/inlay_hints_host.mbt` controller, session, request-stamp,
  cancellation, acceptance, and model-state symbols;
- `R`: `viewer/registry.mbt` awaited model-feature request path;
- `L`: attach, detach, replacement, model-disposal, and Viewer-disposal
  lifecycle paths;
- `F`: `viewer/common/languages/inlay_hints_request.mbt` anchors, items,
  fragments, and range/provider request path;
- `M`: `viewer/common/model/text_model.mbt` internal version and whole-value
  replacement/event path.

### Inlay controller (`IHC-001`–`IHC-232`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001 | No local symbol | N-A (TypeScript DI brand) |
| 002–005, 040, 068–070, 123–126 | Future inlay cache and fast-restore/copy path | DEFERRED (fast-restore/cache child) |
| 006–007 | No local symbol | N-A (TypeScript service interface/decorator/singleton registration) |
| 008–018, 037, 041, 043, 090–122, 224–226, 228–232 | Future label-part, gesture, resolve, command, accessibility, and execute-provider surface | DEFERRED (label resolve/command/public interaction surface) |
| 019–020, 026–027, 032, 034, 036, 131, 146–222, 227 | Future complete inlay rendering/CSS and partial-decoration path | DEFERRED (complete render/CSS/partial-decoration parity) |
| 021–024 | `C` plus `H::InlayRequestSession` | TESTED |
| 025, 028–029 | Existing contribution/controller registration in `viewer/inlay_hints_host.mbt` | PORTED |
| 030–031 | `H` controller-lifetime and replaceable-session ownership | TESTED |
| 033, 044–045, 049–050, 075–078, 081–082, 127–130 | Future scheduler, viewport-range, debounce, and provider-change path | DEFERRED (debounce/provider-change/viewport request lane) |
| 035, 132–145 | No local symbol | N-A (typing-only cursor/fixed-length stabilization in a readonly whole-value lane) |
| 038–039, 042 | Existing Viewer-owned editor/language/notification dependencies; behavior lands in `R`/`L` | N-A (no separate service parameter-property seam) |
| 046 | `L` model replacement to `H` cancellation/restart | TESTED |
| 047 | No local symbol | N-A (language ID is immutable per local model; replacement is IHC-046) |
| 048, 051, 054–055, 057–067, 088–089 | Future `ViewerOptions.inlay_hints` and controller configuration/render-mode handling | DEFERRED (inlay option/render-mode surface) |
| 052–053, 056 | `H` plus `R` controller disposal, refresh body, and absent-model/provider branch | TESTED |
| 071 | `L` model-disposal listener to `H` cancellation | TESTED |
| 072, 084 | No local symbol | N-A (pinned dead optional-`cts` seam; real cancellation ownership is `H`) |
| 073–074, 079–080 | `R` awaited body plus `H` stamp/token guard, failure containment, and initial launch | TESTED |
| 083 | `L` content listener to `H` invalidation and `R` replacement request | TESTED |
| 085–087 | No local symbol | N-A (typing cursor-delay runner) |
| 223 | `H::clear_model_state` plus `L` teardown | TESTED |

Planned IHC totals: 17 TESTED, 3 PORTED, 185 DEFERRED, and 27 N-A.

### Inlay fragments (`IHF-001`–`IHF-049`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001–003, 006–009, 024–026, 029–030, 032–033, 035–038, 040–047 | `F` | TESTED |
| 004–005, 011–021 | Future inlay-hint resolve state/API and expanded provider DTOs | DEFERRED (resolve API/state outside P1) |
| 010 | Future cache-copy path shared with the IHC cache target | DEFERRED (fast restore) |
| 022–023, 028, 031, 039 | No local symbol | N-A (MoonBit providers return non-null GC-owned arrays, not optional disposable lists) |
| 027, 034 | Future provider-change event and retained-provider set | DEFERRED (provider observation/P2 registry surface) |
| 048–049 | Future `Command`/command-link API | DEFERRED (command-link API) |

The `F` request path snapshots matching active provider registrations before
any await, preserves the reviewed provider order, never indexes the live
registry after suspension, rejects results from deregistered registrations,
and forwards the identical caller-owned token to every provider call.

Planned IHF totals: 26 TESTED, 18 DEFERRED, and 5 N-A.

### Text-model version cluster (`TMV-001`–`TMV-026`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001–002 | `H::InlayRequestStamp` uses physical model identity instead | N-A (generated model ID is not an async identity key) |
| 003–004, 006, 008–012, 014–015 | `M` | TESTED |
| 005 | No local symbol | N-A (no alternative-version/undo-redo model) |
| 007 | No local symbol | N-A (MoonBit construction requires an explicit URI) |
| 013 | No local symbol | N-A (MoonBit `String` input is non-nullable) |
| 016–018 | Future TextModel EOL transitions | DEFERRED (EOL child ownership) |
| 019–022 | No local symbol | N-A (incremental editing/reverse-edit lane absent from readonly Viewer) |
| 023–025 | No local symbol | N-A (undo/alternative-version overwrite APIs absent) |
| 026 | Existing decoration owner only; never a freshness target | N-A (decoration instance prefix is not physical request identity) |

Planned TMV totals: 10 TESTED, 3 DEFERRED, and 13 N-A.

### Cancellation (`CTS-001`–`CTS-055`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001–007 | `C` token contract, shortcut event, and shared none/cancelled tokens | TESTED |
| 008–018 | `C` private mutable token | TESTED |
| 019–035 | `C::CancellationTokenSource` | TESTED |
| 036–039 | No local symbol | N-A (MoonBit static typing replaces structural token recognition) |
| 040–041 | Future `C::cancel_on_dispose` helper | DEFERRED (no scoped consumer) |
| 042–055 | Future `C::CancellationTokenPool` | DEFERRED (no scoped consumer; preserve all rows for a dedicated child) |

Planned CTS totals: 35 TESTED, 16 DEFERRED, and 4 N-A.

Hover target key:

- `HC`: browser content-hover controller plus `viewer/editor_events.mbt`;
- `HW`: content-hover widget plus its Viewer host;
- `HO`: hover operation/controller, options/result, request ownership, timing,
  and debouncer symbols;
- `HP`: hover participants and `ContentHoverComputer`;
- `HA`: hover anchors; `HR`: hover participant registry; `HU`: hover utility
  predicates/settings; `HI`: contribution/input wiring; `HB`: clearable browser
  timers; `HL`: language-provider hover request plus cancellation.

### Content hover controller (`CHC-001`–`CHC-132`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001 | `HU::hover_sticky_debug` | TESTED |
| 002–007 | `HU::{HoverEnabled, HoverSettings, HoverEnabled::from_config}` | TESTED |
| 008–009 | Future wrapper/controller contents-changed event | DEFERRED (hover render/participant lifecycle) |
| 010 | `HI::register_hover_contribution`, exact contribution ID | PORTED |
| 011 | `HC::hover_keep_open` | TESTED |
| 012 | `HC` listener/task-generation owner plus teardown | TESTED |
| 013 | `Viewer.content_hover_widget` and ensure-widget path | TESTED |
| 014–015 | `HC` latest-pointer/react state plus owned `HB` timer | TESTED |
| 016 | `HC::hover_settings` | TESTED |
| 017–018 | `HC` mouse-down and ignore-mouse state | TESTED |
| 019–021 | Viewer receiver and contribution/keybinding registries | N-A (no retained TypeScript DI parameter-properties) |
| 022, 026–027 | `HI`/`HC` context-menu visibility hook and listener ownership | TESTED |
| 023–025 | `HC` pending reaction plus `HO::HoverDebouncer` | TESTED |
| 028–029 | `HI` option subscription and listener-generation replacement | TESTED |
| 030 | `HC::{get, attach, detach}` | TESTED |
| 031–033 | `HC` settings snapshot and disabled-mode cancel/hide path | TESTED |
| 034–042 | `HI` contribution-owned model/content/mouse/key/scroll listeners | TESTED |
| 043–044 | `HC::cancel_react` and Viewer dismiss cancellation ordering | TESTED |
| 045–047 | Viewer scroll-change handler | TESTED |
| 048–050 | Viewer mouse-down handler and `HU::should_keep_hover_widget_visible` | TESTED |
| 051 | Complete keep-visible composite | DEFERRED (resize waits hover-resize child; color-decorator arm is N-A; widget arm is CHC-052–053) |
| 052–053 | Viewer widget hit-test and `HU::mouse_within_element` | TESTED |
| 054–055 | Planned accepted mouse-up/down-state transition in `HC` | TESTED |
| 056–060 | Viewer mouse-leave cancel-before-retain/hide path | TESTED |
| 061 | Complete current-hover retention composite | DEFERRED (focus/resize/keyboard-visible arms wait widget-state child; color/selection arms are N-A) |
| 062–063 | `HU::should_keep_current_hover` missing/sticky-widget paths | TESTED |
| 064 | No local symbol | N-A (no hover color-picker widget) |
| 065–066 | No local symbol | N-A (no browser-selection retention surface) |
| 067–078 | Viewer mouse-move/react path plus `HU::should_reschedule_hover` | TESTED |
| 079–087 | Future keydown, modifier-only, chord, and Tab retention | DEFERRED (hover keyboard/widget-state child) |
| 088–089, 091 | Viewer hide path plus `HW::hide` | TESTED |
| 090 | No local symbol | N-A (no inline-suggestion hints dropdown) |
| 092–093 | Viewer ensure-widget path | TESTED |
| 094 | Future contents-changed forwarding event | DEFERRED (hover render/participant lifecycle) |
| 095 | Planned show path carrying mode/source/focus | TESTED |
| 096–097 | Future `HW::is_resizing` state/query | DEFERRED (hover resize/layout child) |
| 098–099 | Contribution/controller/widget disposal ownership | TESTED |
| 100, 103–106 | Future rendered-hover focused-index/focus APIs | DEFERRED (hover rendered-part focus child) |
| 101–102 | Future rendered-hover verbosity APIs | DEFERRED (hover verbosity child) |
| 107–122 | `HI::with_hover_widget` plus widget scroll/page/edge methods | TESTED |
| 123–124 | Future widget-content query | DEFERRED (hover render/content API) |
| 125–128 | Future accessible-content queries | DEFERRED (hover accessibility child) |
| 129–130 | No local symbol | N-A (no hover color-picker widget) |
| 131–132 | `HW::is_visible` through controller/widget forwarding | TESTED |

Planned CHC totals: 93 TESTED, 1 PORTED, 29 DEFERRED, and 9 N-A.

### Content hover wrapper (`CHW-001`–`CHW-132`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001 | `HO::HoverController` current-result state | TESTED |
| 002 | Future rendered-hover disposable owner | DEFERRED (rendered-part lifecycle child) |
| 003 | Viewer content-hover widget ownership | TESTED |
| 004 | `HP::ContentHoverComputer.participants` | TESTED |
| 005 | `HO::HoverController.operation` | TESTED |
| 006–007 | Future contents-changed event | DEFERRED (render/participant lifecycle) |
| 008–012 | Viewer receiver/registries and future render-service seams | N-A (no separate TypeScript DI parameter-properties) |
| 013 | Viewer ensure-widget/make-computer and controller ownership | PORTED |
| 014 | Complete participant initialization with optional handlers | DEFERRED (participant render-lifecycle handlers) |
| 015–016 | `HR::build_all` plus ascending participant-ordinal sort | TESTED |
| 017–025 | Future participant resize/scroll/contents dispatch | DEFERRED (participant render-lifecycle handlers) |
| 026 | Contribution/widget listener ownership | TESTED |
| 027–028 | `HO` operation-result application and loading augmentation | TESTED |
| 029–033 | `HW` keydown/mouseleave DOM protocol and dispatch | TESTED |
| 034–035 | Future tokenization-change rerender | DEFERRED (hover render/tokenization child) |
| 036 | Future widget-to-wrapper contents event | DEFERRED (render/participant lifecycle) |
| 037–048 | `HO::HoverController` show/update/start-if-needed path | TESTED |
| 049–052 | `HO::HoverController::set_current_result` | TESTED |
| 053–057 | Planned participant loading message and augmentation | TESTED |
| 058–061 | `HO` complete/incomplete/empty reconciliation | TESTED |
| 062 | Complete `showsOrWillShow` outer method | DEFERRED (resize waits resize child; code-action arm is N-A; candidate path is CHW-065–075) |
| 063 | Future wrapper resizing state | DEFERRED (hover resize/layout child) |
| 064 | No local symbol | N-A (no code-action widget contribution) |
| 065–075 | Anchor-candidate selection in `hover_events.mbt` | TESTED |
| 076–078 | No local symbol | N-A (no `.action-widget` contribution/selector) |
| 079–080 | Planned mouseleave containment handler | TESTED |
| 081–082 | Planned Viewer show-options forwarding | TESTED |
| 083 | `HC`/`HO` cancel-before-clear hide path | TESTED |
| 084 | Built-in mouse-target fallback in `hover_events.mbt` | TESTED |
| 085–086 | Future rendered-hover creation/replacement/show | DEFERRED (hover DOM/render child) |
| 087–089 | Future participant hide-handler lifecycle | DEFERRED (participant render-lifecycle child) |
| 090–092 | Future render-context hide/contents callbacks | DEFERRED (hover render-context child) |
| 093 | Future minimum-dimensions callback | DEFERRED (hover resize/layout child) |
| 094 | Future render-context focus callback | DEFERRED (hover focus child) |
| 095–096 | Future widget-content query | DEFERRED (hover render/content API) |
| 097–100 | Future verbosity APIs | DEFERRED (hover verbosity child) |
| 101–104 | Future accessible-content APIs | DEFERRED (hover accessibility child) |
| 105–116 | Future rendered-part focus/index APIs | DEFERRED (hover rendered-part focus child) |
| 117–124 | Widget scroll/page/edge methods | TESTED |
| 125 | Content-widget `get_dom_node` implementation | TESTED |
| 126–127 | No local symbol | N-A (no hover color-picker widget) |
| 128 | Future keyboard-visible state | DEFERRED (hover keyboard/widget-state child) |
| 129 | `HW::is_visible` | TESTED |
| 130 | `HI::is_hover_focused` | TESTED |
| 131 | Future `HW::is_resizing` | DEFERRED (hover resize/layout child) |
| 132 | Persistent Viewer content-hover widget getter | TESTED |

Planned CHW totals: 68 TESTED, 1 PORTED, 52 DEFERRED, and 11 N-A.

### Hover operation (`HOP-001`–`HOP-075`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001 | `HP` async participant/computer path with caller token | TESTED |
| 002 | `HP::ContentHoverComputer::compute_sync` | TESTED |
| 003–007 | `HO::HoverOpState` logical variants | N-A (typed enum has no observable numeric encoding) |
| 008–009 | Planned typed hover-start-mode variants | N-A (typed enum has no observable numeric encoding) |
| 010–012 | Planned typed hover-start-source variants | N-A (typed enum has no observable numeric encoding) |
| 013–017 | Planned `HO::HoverResult` and operation options | TESTED |
| 018–019 | Planned result effect/event through Viewer transition handling | TESTED |
| 020–028 | Planned `HO::HoverDebouncer` plus owned clearable `HB` timers | TESTED |
| 029–038 | `HO::HoverOperation` plus request-session/source disposal | TESTED |
| 039–044 | Planned hover timing derived from delay | TESTED |
| 045–053 | Async trigger/item/done/error transitions with cancellation | TESTED |
| 054–060 | Sync/loading/result-emission transitions | TESTED |
| 061–069 | Start/cancel/options transitions | TESTED |
| 070–075 | Debouncer latest-options/schedule/cancel semantics | TESTED |

Planned HOP totals: 65 TESTED and 10 N-A. HOP-066 tests every valid typed
state/no-op branch; the source's raw non-enum runtime-value case is N-A under
the typed-mode seam and remains a same-row deviation note.

### Content hover computer (`CHCMP-001`–`CHCMP-026`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001–004 | Planned operation options carrying focus/anchor/source/insist | TESTED |
| 005 | Explicit model argument on every compute call | N-A (computer retains no TypeScript editor dependency) |
| 006 | `HP::ContentHoverComputer.participants` | TESTED |
| 007 | `HP::ContentHoverComputer::new`, with explicit compute model | PORTED |
| 008–019 | Marker participant sync computation/line-decoration selector | TESTED |
| 020–023 | Token-aware async-each path with concurrent arrival-order merge | TESTED |
| 024–026 | `HP::ContentHoverComputer::compute_sync` | TESTED |

Planned CHCMP totals: 24 TESTED, 1 PORTED, and 1 N-A.

### Provider hover request (`GHR-001`–`GHR-016`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001–004 | Future provider-result/provider-ordinal DTO | DEFERRED (P2 provider scoring/order surface) |
| 005 | Planned token-aware `HL::execute_hover_provider` | TESTED |
| 006 | Unified MoonBit async failure-containment boundary | N-A (no synchronous-throw versus Promise-rejection distinction) |
| 007 | Planned provider-result validation in `HL` | TESTED |
| 008–011 | Future eager snapshot, concurrent resolution-order iterable, and accumulator | DEFERRED (P2 multi-provider ordering/aggregation) |
| 012–015 | Future execute-hover-provider commands | DEFERRED (P2 public provider command surface) |
| 016 | Planned `HL::valid_hover` | TESTED |

Planned GHR totals: 3 TESTED, 12 DEFERRED, and 1 N-A. GHR-016 tests the
present-range and content cases; undefined/runtime-null ranges are N-A because
the local range is required and non-nullable, recorded on the same row.

### Hover types (`HTY-001`–`HTY-067`)

| IDs | Reviewed target | Planned disposition |
|---|---|---|
| 001 | Future rendered part retaining participant owner | DEFERRED (rendered-part/participant ownership child) |
| 002 | `HP::hover_part_range` | TESTED |
| 003 | Future force-show-at-range property | DEFERRED (hover layout child) |
| 004 | Future before-content ordering property | DEFERRED (hover render-order child) |
| 005 | `HO::hover_part_valid_for_anchor` | TESTED |
| 006–007 | `HA::HoverAnchorType` logical variants | N-A (typed enum has no observable numeric encoding) |
| 008–015 | `HA::HoverRangeAnchor` fields/equality/adoption | TESTED |
| 016–026 | `HA::HoverForeignElementAnchor` with explicit owner identity | TESTED |
| 027–030 | `HP` ordinal/suggester/sync/async-token contract | TESTED |
| 031 | Planned optional participant loading message | TESTED |
| 032 | `HP` services plus `HR::build_all` | N-A (service-capturing factory replaces editor/DI constructor signature) |
| 033–035 | `HR::{entries, register, get_all}`, retaining backing-array aliasing | TESTED |
| 036–037 | `HW` show-or-will-show and hide protocol | TESTED |
| 038–044 | Future status-bar/action interfaces | DEFERRED (hover status/action child) |
| 045 | No local symbol | N-A (no hover color-picker widget) |
| 046 | Future contents-changed render-context callback | DEFERRED (hover render-context child) |
| 047 | Future minimum-dimensions callback | DEFERRED (hover resize/layout child) |
| 048–049 | Future render-context hide/focus callbacks | DEFERRED (hover render/focus child) |
| 050–051 | Future DOM fragment/status-bar render context | DEFERRED (hover DOM/render child) |
| 052–059 | Future rendered-part collection and ordered disposal | DEFERRED (rendered-part lifecycle child) |
| 060 | Future participant copy-button flag | DEFERRED (hover copy-affordance child) |
| 061 | Existing hover-parts rendering | TESTED |
| 062 | Future accessible-content contract | DEFERRED (hover accessibility child) |
| 063 | Future participant resize handler | DEFERRED (hover resize/layout child) |
| 064–066 | Future participant hide/contents/scroll handlers | DEFERRED (participant render-lifecycle child) |
| 067 | Hover participant registry singleton | PORTED |

Planned HTY totals: 32 TESTED, 1 PORTED, 30 DEFERRED, and 4 N-A.

The reviewed plan-wide terminal target is 373 TESTED, 7 PORTED, 345 DEFERRED,
and 85 N-A = 810 rows. CHC-051, CHC-061, CHW-062, HOP-066, and GHR-016 retain
their owning member/composite row; their mixed subordinate seams are called out
above so a future terminal status cannot overclaim those unrepresentable arms.

### Inventory review checklist — stop gate

- [x] Reviewer confirms the normalized denominator is 810 atomic source rows with
  exact per-prefix counts and no derived/local row counted as source.
- [x] Reviewer confirms complete source methods are not split across scope
  boundaries and every excluded sibling member has its own row.
- [x] Reviewer confirms the 87-row local audit and test-authority corrections
  against the current checkout.
- [x] Reviewer approves or amends physical model/internal-version/generation/
  token freshness and monotonic generations across swaps.
- [x] Reviewer approves controller-owned cancellation sources and clearable
  timer handles, including detach/dispose ordering.
- [x] Reviewer assigns every row a MoonBit target and planned terminal
  disposition while leaving its working status `TODO` until evidence lands.
- [x] Reviewer approves the branch/configuration matrix below.
- [x] Corrected inventory was committed separately; only then was product/test
  implementation allowed to begin.

**Review gate passed:** independent reviews approved inventory milestone
and the exhaustive target/disposition map above. At that milestone,
product/test implementation was authorized without changing the fixed source
denominator.


## Test-Authority Corrections (Gate B baseline)

- viewer/common/model/text_model_test.mbt expected a different model
  revision/instance with the same URI and host version to pass the freshness
  guard. Implementation treated that expectation as an async-ownership test bug.
- The pre-implementation hover reconciliation tests covered operation
  sequencing inside one active model but did not prove model/content
  cancellation.
- The pre-implementation inlay tests mostly installed resolved hints directly
  and did not cover request races.

## Required Test Matrix (Phase 4)

All deferred work uses controlled completion, never a sleep as the result
oracle. A test-only inlay provider and hover provider expose `started`,
per-call `release`, and consumer-side `settled` signals. Outcomes include
nonempty, empty/`None`, ordinary error, and a result/error returned after the
provider observes cancellation. White-box tests await the internal request
body; production alone wraps it in `async_run`.

| Group | Behavior variables and mandatory combinations | Harness / assertions |
|---|---|---|
| Cancellation lifecycle | Token read before/after cancel; listener count 0/1/3; early/late/disposed listener; callback context absent/present; optional disposable bucket absent/present; cancel once/twice; dispose false/true before/after token read; parent absent/present; repeated dispose; shortcut listener retained/disposed before next-turn delivery | Port pinned `cancellation.test.ts` labels `None`, `cancel before token`, `cancel happens only once`, `cancel calls all listeners`, `token stays the same`, both `dispose calls no listeners` cases, `dispose does not cancel`, and `parent cancels child`. Assert flag-before-notify, identity, exact-once, bound callback context, disposable-bucket ownership, late-next-turn delivery, disposal-before-delivery suppression, and order on every target. Pool tests remain row-level DEFERRED evidence. |
| Model/version stamp | Same/different physical model × same/different URI × same host version; internal version unchanged/changed; current/stale generation; live/canceled token; Viewer live/disposed | Model/root white-box tests. Include same object after equal and unequal `set_value`, distinct same-URI/same-host-version objects, detach, model dispose, Viewer dispose. Only the all-current combination applies. Port pinned `setValue eventing`; EOL and incremental-edit rows take their owning-plan/N-A dispositions. |
| IHC session/update | Enabled off/on/onUnlessPressed/other mode; model/provider absent/present; cache miss/empty/nonempty; modifier unchanged/changed; provider event scheduled/idle; request success/canceled/error; scroll top changed/unchanged; content timeout replacement; option match/nonmatch | Controller/model tests or explicit DEFERRED/N-A row evidence. Assert cleanup-before-return, reset cancellation order, four zero-delay schedules, debounce floor 800, watched-provider ownership, and cancel-before-apply. |
| IHC ranges/anchors/apply | View ranges empty/one/many, disjoint/touching/overlap, ±30 clamp; duplicate item, missing/current decoration range; affected/unaffected old decoration; missing current model; cap at 1500; cursor/fixed-length branches and padding shapes | DOM-free range/copy tests plus JS decoration integration where planned. Assert sorted merge, no duplicate copy, transaction pairing, class-ref disposal, scroll capture/restore, and exact render/style DEFERRED mapping for every excluded row. |
| IHF provider/anchor | Providers 0/1/2 × ranges 0/1/2; completion orders A→B/B→A; provider registration active/disposed before launch, during await, and after return; empty/change-event/error; canceled/disposed after settle; word/no-word; one-character token; token indices 0/1/2/count−2/count−1; leading/trailing `else if` | Language/fragment tests. Require a request-start provider snapshot with explicit stable order plus an explicit post-await provider-liveness acceptance policy. Assert same token/model/range, completion-order accumulation, independent error containment, no deregistration-induced provider skip or out-of-bounds access, post-settle guard, before/after anchor direction, exact +1 columns, sort/dedupe/disposal seams, and resolve/command rows' explicit deferred disposition. |
| Hover timing/state | Delayed and every non-Delayed value × each operation state; delay 0/1/2/300/301; before/at half, full, 3×; async/sync computer absent/present; async items 0/1/2 with falsy/truthy and arrival before/after sync; item order versus sync-result order; error; async completes before sync, after sync, after loading; cancel/dispose iterable absent/present | Hover controller tests with a manual scheduler/clearable handles. Assert no pre-delay emission, exact state/order, ordered accumulation, result snapshot, latest options, loading only while waiting, scheduler replacement/cancel/dispose, and late callback rejection. |
| Hover controller/wrapper | Enabled/sticky/hidingDelay; context-menu ignore; model versus content change; scroll neither/top/left/both; mouse down/up/leave/move retention; explicit keep-open, focus, resize, keyboard-visible, sticky widget hit, color-picker visible × mouse-down, browser view absent/present, active element outside/inside, selection absent/collapsed/noncollapsed; runner scheduled/idle; content-widget resizing false/true; key modifier/chord/Tab/default; code-action event target non-`Element`/`Element` × matching/nonmatching `.action-widget`; target `CONTENT_TEXT`/`CONTENT_EMPTY`/other; participant candidates 0/1/2 with lower/equal/higher priority and ties; invisible anchor absent/present; null/equal/compatible/incompatible anchor; loading factory absent/null/present | Existing interaction/browser white-box suites plus focused cases. Assert cancel-before-hide, content cancels pending react, model change cancels+hides, every independent retention predicate, resizing/code-action early returns, source target fallback, descending candidate selection including ties, and every input early return. |
| Hover reconciliation | Previous visible complete × incoming complete × empty × insist; sticky-closer with/without anchor; participant suggester absent/null/present; action target element/non-element; mouseleave missing/outside/inside editor | Wrapper/controller tests. Pin the no-previous-complete fall-through: incomplete or empty+insist may already have applied before the later return. Assert cancel-before-clear and identity no-ops. |
| Hover anchors/registry | New/last anchor Range/Foreign × same/different range, start line, and foreign owner; equality versus adoption; show position same/different line and ignored for foreign owners; registered constructors 0/1/2; mutate the array returned by `getAll` before the next read | Anchor/registry white-box tests. Assert Range equality uses exact range, Range adoption uses only prior type plus the new range's start line against show position, Foreign equality/adoption uses owner identity and ignores show position, registration preserves order, and `getAll` aliases the mutable backing array. |
| Hover computer/provider | Range/foreign anchor × marker support; invalid/valid line; whole-line true/false × decoration start line same/cross × end line same/cross; ordinary/collapsed containment at ±1 and just outside; async participants 0/1/2 with completion orders A→B/B→A and partial emission before completion; provider result range `undefined`/runtime `null`/present × contents `undefined`/falsy/empty/nonempty; provider `Some`/`None`/throw; cancellation before/after completion; eager invocation and resolution order | Hover/languages tests. Assert identical token propagation, source-exact selection/order, exact same-line/fallback columns, concurrent participant merge in arrival order, the pinned runtime-`null` range behavior, first-`Some` local policy, contained logs, and canceled data never reaching reconciliation. Provider scoring/recursive/command rows receive P2 DEFERRED/N-A evidence rather than implicit omission. |
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

- MoonBit has no implicit disposable owner for `async_run` or browser timers.
  The shared request helper therefore defaults to a sequential runner, while
  the browser injects a concurrent runner; every browser timer is wrapped in an
  owned `Disposable` and keeps a generation guard for dispatch races.
- Cancel-before-first-token-read retains a source-specific already-cancelled
  token so late listeners use that source's injected scheduler and remain
  disposable. This deliberately does not use VS Code's allocation-free shared
  `Cancelled` singleton; `CTS-007`, `CTS-023`, and `CTS-025`–`CTS-026` are
  deferred rather than overclaimed.
- Request authority uses physical `TextModel` identity, internal content
  version, monotonic controller generation, and a caller-owned token. URI,
  host version/revision, generated decoration IDs, and a forgeable public stamp
  are excluded. This is the minimum local equivalent of Monaco's model/token
  lifetime and is stronger at every apply boundary.
- Hover and inlay provider traits are typed, token-aware, and `noraise` at the
  participant seam. Required methods returning empty arrays or `None` replace
  JavaScript optional/falsy-member branches; the corresponding ledger rows are
  `N-A`, while ordinary provider failures remain contained and logged in the
  language-provider layer.
- Inlay provider results are GC-owned arrays, not disposable result lists.
  Provider registrations are snapshotted before the first await and rechecked
  both per-settlement and after all siblings finish; deregistration cannot
  mutate the live iteration or commit retained data.
- Content invalidation cancels provider work and all operation/react timers.
  A previously complete hover may remain visible until the next pointer
  request, but partial/loading-only views are cleared and the widget cache is
  synchronized immediately so an equal anchor can restart.
- Full inlay rendering/cache/resolve/command behavior, live hover
  configuration/context-menu ownership, provider scoring/aggregation, and
  hover DOM/render/accessibility/status tails remain in their named deferred
  children. No P2 surface was silently absorbed into this P1 lifetime slice.

## Exit Gate

- [x] inventory rows equal ledger rows: 810/810; TESTED 331, PORTED 7,
  DEFERRED 371, N-A 101, TODO/PASS 0/0
- [x] all completion-order permutations are deterministic and tested
- [x] same-URI/same-host-version replacement cannot accept old results
- [x] set_value cannot accept an older inlay result
- [x] pending hover reaction is canceled on content/model changes
- [x] detach and dispose cancel all scoped work
- [x] provider errors remain contained
- [x] all deviations have reviewed reasons
- [x] all repository quality gates pass
- [x] independent closing reread finds no unaccounted scoped member

## Execution Record

### 2026-07-10 — rejected first inventory milestone

- The milestone recorded 581 mechanically contiguous rows, but fresh Gate B
  review rejected it: several excluded-sibling rows bundled many declared
  members/branches/CSS facts, two derived lifecycle notes were counted as
  source, and the matrix covered P1 races rather than the full denominator.
- No product or test file changed in that rejected documentation milestone.
  History is preserved; the correction below supersedes its denominator.

### 2026-07-10 — rejected second inventory milestone

- The milestone expanded the denominator to 759 and added the branch matrix,
  but its fresh reread still found umbrella rows for nested callbacks,
  interface/object properties, DOM/CSS/custom properties, and exact arithmetic.
- No product or test file changed in that second documentation milestone.
  History is preserved; the third attempt below superseded its denominator.

### 2026-07-10 — rejected third inventory milestone

- The milestone recorded 924 mechanically contiguous rows and expanded the
  nested-callback and DOM/CSS coverage, but a fresh semantic reread rejected
  it. Straight-line statement ordering and exact property arithmetic were
  counted separately from their owning member/property, contrary to the
  uniform rule above.
- No product or test file changed in that third documentation milestone.
  History is preserved; the normalized correction below supersedes its
  denominator.

### 2026-07-10 — normalized Phase 1–2 inventory and Gate B approval

- Inventory milestone is fixed at SHA-256
  `ded2c74abc9be5193a379ccff63f42fd86b36b67b77a80dd97a53033116749bf`.
- Verified the read-only VS Code oracle at
  checked-in source.
- Re-read every closed source unit/cluster under the uniform rule recorded
  above. Excluded siblings, source-owned callbacks, and DOM/CSS/custom
  properties remain atomic rows rather than prose-only or umbrella exclusions.
- Normalized source inventory/ledger: **810/810** rows, all `TODO`:
  `IHC 232, IHF 49, CHC 132, CHW 132, HOP 75, CHCMP 26, GHR 16, HTY 67,
  TMV 26, CTS 55`.
- Separate current-MoonBit ownership audit: **87** rows (`LA-001`–`LA-087`).
  It records two unretained `async_run` launches, four raw hover timer sites,
  model/content subscriptions, operation/react tokens, result guards,
  decoration applies, reset paths, and detach/dispose ordering.
- Mechanical verification passed: per-prefix counts, 810 source IDs and 87
  local IDs are contiguous, all 810 source rows end `TODO`, and
  `git diff --check` is clean. This correction changes the child and parent
  plan only.
- No product or test file changed and no runtime tests were run for this
  documentation-only correction.
- Independent inlay/model/cancellation review mapped all 362 rows to 88 planned
  TESTED, 3 PORTED, 222 DEFERRED, and 49 N-A dispositions. Independent hover
  review and a second split cross-check mapped all 448 rows to 285 planned
  TESTED, 4 PORTED, 123 DEFERRED, and 36 N-A dispositions. Both rereads found
  zero missing, duplicate, or extra IDs.
- Gate B approved the physical-model/internal-version/monotonic-generation/token
  stamp, controller-owned cancellation, clearable timers, provider-registration
  snapshot/liveness policy, branch matrix, and the same-row mixed-seam notes for
  CHC-051, CHC-061, CHW-062, HOP-066, and GHR-016.

**GATE B APPROVAL (historical).** The fixed denominator and reviewed planned
dispositions authorized product/test work. Working statuses remained `TODO`
until implementation evidence supported the terminal source ledger above.

### 2026-07-10 — cancellable request ownership and freshness implementation

- Commits recorded milestone, recorded milestone, and recorded milestone established the cancellation,
  language-request, and hover-operation foundations. Product milestone
  completed the Viewer integration, contracts, deterministic fixtures, and
  browser-visible race scenario.
- `CancellationTokenSource` now owns parent subscriptions, exact-once listener
  delivery, late-listener scheduling/disposal, and cancel/dispose ordering.
  Request stamps are opaque outside their owner and reject physical-model,
  internal-version, generation, cancellation, detach, model-dispose, and
  Viewer-dispose drift.
- Inlay requests snapshot providers/ranges before the first await, run through
  an injected concurrency seam, preserve completion order, contain ordinary
  failures, and reject registrations disposed before launch, during await, or
  after one sibling settles. A stale empty result cannot clear the newest
  decorations.
- Hover owns the mouse-react, async, sync, and loading handles plus one request
  source. Source mode/focus, participant-selected loading, same-anchor
  reconciliation, wrapper mouseleave, scroll, content/model invalidation, and
  stable equal-key ordering are covered directly. Content invalidation retains
  only a complete shown view; an incomplete/loading view is retired so the
  same anchor can start again.
- The browser scenario controls every provider settlement without sleeps and
  covers old-first/new-last and newest-first/old-last, nonempty/empty/error/
  cancellation-honoring outcomes, same-object `set_value`, distinct
  same-URI/same-host-version replacement, new targets, model disposal, detach,
  and Viewer disposal. Provider/apply completion is separated by a task-turn
  barrier and visible assertions wait for rendered turns.

### 2026-07-10 — closing evidence and Gate E

- Final source ledger: **810/810 terminal rows** and zero TODO/PASS:

  | Prefix | TESTED | PORTED | DEFERRED | N-A | Total |
  |---|---:|---:|---:|---:|---:|
  | IHC | 8 | 3 | 193 | 28 | 232 |
  | IHF | 26 | 0 | 18 | 5 | 49 |
  | TMV | 7 | 0 | 4 | 15 | 26 |
  | CTS | 27 | 0 | 24 | 4 | 55 |
  | CHC | 85 | 1 | 37 | 9 | 132 |
  | CHW | 65 | 1 | 52 | 14 | 132 |
  | HOP | 62 | 0 | 1 | 12 | 75 |
  | CHCMP | 21 | 1 | 0 | 4 | 26 |
  | GHR | 2 | 0 | 12 | 2 | 16 |
  | HTY | 28 | 1 | 30 | 8 | 67 |
  | **Total** | **331** | **7** | **371** | **101** | **810** |

- Closing reviews amended planned overclaims rather than forcing evidence:
  absent operation-store/update/cache/debounce/configuration/context-menu seams
  remain deferred; shared cancellation-singleton shortcuts and impossible
  optional/falsy/value-identity branches are deferred or N-A with row-local
  reasons. `HOP-053` is N-A because the local async trait member is required.
- Focused evidence passed on both supported targets: cancellation 17/17,
  languages 34/34, hover 68/68, hover-browser 8/8, and Viewer 102/102 JS.
  The direct async component scenario passed ten repeated runs after its
  post-content render barrier was made explicit.
- Required repository gates passed on the closing product state:
  `just check`; `just test` (JS 964/964, native 759/759); `just build`; and
  `just test-browser` (42/42). The five warning-73 messages are pre-existing
  baseline warnings outside this child; no async-child warning remains.
- Three independent closing passes reconciled the product diff, required test
  matrix, and all 810 terminal rows. Their findings were fixed before freeze;
  the final reread found no missing, duplicate, or extra scoped source member.

**IMPLEMENTED AND FROZEN.** This document is now historical evidence; future
provider-surface, cache/resolve, configuration, and render work belongs to the
explicit deferred children above.
