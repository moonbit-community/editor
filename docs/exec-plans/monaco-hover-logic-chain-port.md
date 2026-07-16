# Monaco Content/Glyph Hover Logic-Chain 1:1 Port

Status: in progress — rewritten 2026-06-30 to the `_PORT_PLAYBOOK.md` format
(orig. proposed 2026-06-29). Oracle: checked-in `vscode` submodule.

This plan ports the editor **hover logic chain** (controller / operation /
widget sizing / wrapper / rendered parts / status-bar actions / glyph hover) one
file at a time, per `_PORT_PLAYBOOK.md`. It supersedes the two predecessor hover
plans **only for the logic chain**; do not rewrite either:

- `monaco-exact-hover-widget.md` — ported the hover **DOM subtree** and the
  shared `.monaco-scrollable-element` family.
- `monaco-hover-scrollbar-conformance.md` — proved **DOM/CSS/scrollbar**
  conformance against a local Monaco reference fixture.

Product code must not import from `vscode/` or `codemirror/`; the target is to
port behavior, constants, and state transitions into locally owned MoonBit.

## How this plan maps onto the playbook

The playbook template is written for a **single** source unit. This chain spans
15 source files, so the adaptation is:

- **Phase 0 (Scope)** is global: one closed set of files, one out-of-scope list.
- The plan's **work-units are numbered Phase 1–7** (each independently
  shippable). Each work-unit names its source file(s) and carries its own
  playbook **Inventory** (the denominator) and **Parity ledger** (one row per
  member). No file's surface is enumerated more than once: every member of every
  in-scope file is assigned to exactly one work-unit's ledger.
- **Deviations**, **Test matrix**, and **Exit gate** are global sections at the
  end, sliced per work-unit.

Statuses (playbook §Phase 2): `TODO` / `PORTED` (code matches source) / `TESTED`
(whitebox/oracle/browser proof exists) / `PASS` (proof green) /
`DEFERRED (reason)` / `N-A (reason)`. No member is absent; absence-as-deferral is
forbidden.

## Scope (Phase 0)

**Source unit set (closed).** Whole files unless a cluster is named:

| # | Source file | Slice | Work-unit |
|---|---|---|---|
| 1 | `resizableContentWidget.ts` | whole | Phase 1 |
| 2 | `contentHoverWidget.ts` | sizing cluster | Phase 1 / 1b |
| 3 | `hoverOperation.ts` | whole | Phase 2 |
| 4 | `contentHoverController.ts` | whole | Phase 3 |
| 5 | `hoverUtils.ts` | whole | Phase 3 |
| 6 | `contentHoverWidgetWrapper.ts` | whole | Phase 4 |
| 7 | `contentHoverRendered.ts` | whole | Phase 4 |
| 8 | `contentHoverWidget.ts` | structure/resize remainder | Phase 4 |
| 9 | `contentHoverStatusBar.ts` | whole | Phase 5 |
| 10 | `hoverActionIds.ts` | whole | Phase 5 |
| 11 | `hoverActions.ts` | whole | Phase 5 |
| 12 | `hoverContribution.ts` | whole | Phase 5 |
| 13 | `contentHoverWidget.ts` | scroll cluster | Phase 5 |
| 14 | `markdownHoverParticipant.ts` | verbosity cluster | Phase 6 |
| 15 | `glyphHoverComputer.ts` | whole | Phase 7 |
| 16 | `glyphHoverController.ts` | whole | Phase 7 |
| 17 | `glyphHoverWidget.ts` | whole | Phase 7 |

`contentHoverWidget.ts` is the one file split across phases (sizing → 1,
structure/resize → 4, scroll → 5); each member is listed in exactly one phase
ledger and the file's full member list is reconciled in the Exit gate.

**Out of scope (named clusters), each with a reason:**

- `contentHoverComputer.ts`, `contentHoverTypes.ts`, `hoverTypes.ts` (participant
  iface + registry), `markdownHoverParticipant.ts` (data + render, **except** the
  verbosity cluster), `markerHoverParticipant.ts`, `getHover.ts`,
  `hoverCopyButton.ts` — the **participant/computer data layer**, already ported
  under the predecessor plans (`hover/hover_participants.mbt`,
  `hover/hover_registry.mbt`, `hover/hover_render.mbt`, `languages.hover_at`).
  This plan re-touches them only where the logic chain fans events into them.
- `hoverAccessibleViews.ts` + all accessible-content getters
  (`getAccessibleWidgetContent*`, aria hints) — **accessibility**, excluded (see
  Non-goals).
- `colorPicker/*` participant, `inlayHints/*` hover — separate contrib chains.
- `base/browser/ui/hover/*` workbench tooltip service — non-editor tooltip system.
- Re-porting the hover DOM subtree / scrollbar visuals — done + conformant under
  the predecessor plans; this plan changes logic, not the target DOM.

## Ownership boundary to respect

The `@hover` sub-package (`viewer/hover/`) is pure data + render: participants,
computer, part→HTML rendering. The viewer core (`viewer/`) owns the controller
state machine and the widget DOM. Keep that split: geometry/sizing and
interaction land in `viewer/`; part structure and rendering land in
`viewer/hover/`. The hover package must not gain a dependency on viewer-core
`ViewerServices` (it takes a `HoverParticipantServices` record).

---

## Phase 1 — `resizableContentWidget.ts` (whole) + `contentHoverWidget.ts` sizing cluster — DONE (sashes deferred)

The viewer hover is **non-overflowing** (lives in `.overflow-guard`), so
available-space edges are the *editor* box, not the page body as in Monaco. The
known bug this phase fixed: a hover in a small window rendered truncated with no
scrollbar because `apply_sizing` capped `max-height` at `max(80, rootHeight−24)`
(the whole editor) instead of the space above/below the anchor line.

### Inventory (Phase 1)

`resizableContentWidget.ts` (whole, 108 lines):
- **Constants:** `TOP_HEIGHT = 30` (:13), `BOTTOM_HEIGHT = 24` (:14).
- **Fields:** `allowEditorOverflow=true` (:18), `suppressMouseDown=false` (:19),
  `_resizableNode` (:21), `_contentPosition` (:22), `_isResizing` (:24).
- **Methods/getters:** constructor (:26, sashes + resize wiring), `get isResizing`
  (:46), abstract `getId` (:50), `getDomNode` (:52), `getPosition` (:56),
  `get position` (:60), `_availableVerticalSpaceAbove` (:64),
  `_availableVerticalSpaceBelow` (:74), `_findPositionPreference` (:86, incl.
  `enableSashes` side-flip :97-101), `_resize` (:105).
- **Branches to cover:** `editorDomNode||mouseBox` missing → `undefined`
  (:67, :77); `hover.above` true vs false (:92/:94); `height ≤ maxHeightAbove`
  (:93); `height ≤ maxHeightBelow` (:95).

`contentHoverWidget.ts` **sizing cluster** (slice):
- **Methods:** `_findAvailableSpaceVertically` (:179),
  `_findMaximumRenderingHeight` (:189), `_isHoverTextOverflowing` (:202),
  `_findMaximumRenderingWidth` (:217), `_setHoverWidgetMaxDimensions` (:149, sets
  `--vscode-hover-maxWidth` :153), height-cap apply in `show` (:336-362).
- **DOM/CSS owned:** `--vscode-hover-maxWidth`, `--vscode-hover-whiteSpace` /
  `--vscode-hover-sourceWhiteSpace` (overflow probe), `max-height`/`max-width`.
- **Branches to cover:** `availableSpace` falsy → `undefined` (:191);
  `_positionPreference === ABOVE` chooses above-space else below-space (:184);
  `overflowing || clientWidth < initialWidth` → body-width cap else current width
  (:229).

Member count (Phase 1): 17 (resizable) + 6 (sizing cluster) = **23**.

### Parity ledger (Phase 1)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `resizableContentWidget` `TOP_HEIGHT=30` (:13) | constant | `hover_available_space_above` (−30) | TESTED |
| `BOTTOM_HEIGHT=24` (:14) | constant | `hover_available_space_below` (−24) | TESTED |
| `_availableVerticalSpaceAbove` (:64-72) | `editorBox.top + mouseBox.top − 30` → editor-relative `line_top − 30` | `hover_available_space_above` | TESTED |
| `_availableVerticalSpaceBelow` (:74-84) | `bodyBox.height − (editorBox.top+mouseBox.top+mouseBox.height) − 24` → `editor_height − (line_top+line_height) − 24` | `hover_available_space_below` | TESTED |
| `_findPositionPreference` (:86-103) | `maxAbove=min(spaceAbove,h)`, `maxBelow=min(spaceBelow,h)`, `maxHeight=min(max(maxAbove,maxBelow),h)`, `height=min(h,maxHeight)`; above-default → `ABOVE` iff `height≤maxAbove`, else by `maxBelow` | `hover_prefer_above` (+ `hover_prefer_above_default=true`) | TESTED |
| `_findMaximumRenderingHeight` (cHW :189-200) | `min(availableSpace, Σ child heights)` | `hover_maximum_rendering_height` | TESTED |
| `_findAvailableSpaceVertically` (cHW :179-187) | pick above/below by `_positionPreference` | folded into `hover_maximum_rendering_height` | TESTED |
| `show` height-cap apply (cHW :336-362) | render → measure natural height → pick side → cap `.monaco-hover-content` `max-height` to chosen-side space | `HoverWidgetDom::apply_sizing` / `render_hover_widget` measure pass | TESTED |
| `enableSashes` side-flip (:97-101) | toggle sash edges per ABOVE/BELOW | — | DEFERRED (sashes follow-on) |
| constructor sash/resize wiring (:26-44) | `enableSashes(t,t,t,t)`; `onDidResize`→`_resize`; `onDidWillResize`→`_isResizing` | — | DEFERRED (sashes follow-on) |
| `_resize` (:105-107) | `_resizableNode.layout(h,w)` | — | DEFERRED (sashes follow-on) |
| `get isResizing` (:46-48) | `_isResizing` | — | DEFERRED (sashes follow-on) |
| `_resizableNode`/`_contentPosition`/`_isResizing` fields (:21,:22,:24) | resize state | — | DEFERRED (sashes follow-on) |
| `allowEditorOverflow=true` (:18) | overflow flag | n/a — widget is non-overflowing | N-A (viewer hover lives in `.overflow-guard`) |
| `suppressMouseDown=false` (:19) | mouse-down passthrough | — | N-A (no resizable host node) |
| `getDomNode` (:52) | return `_resizableNode.domNode` | `HoverWidgetDom` root node | PORTED |
| `getPosition` / `get position` (:56,:60) | return `_contentPosition` | widget anchor (`line_col_for_offset`) | PORTED |
| abstract `getId` (:50) | identity string | `HoverWidget.ID` const | N-A (identity) |

### Phase 1b — available-width cap (sizing cluster, horizontal axis)

| Source member (file:line) | Arithmetic | MoonBit symbol | Status |
|---|---|---|---|
| `_setHoverWidgetMaxDimensions` `--vscode-hover-maxWidth` (cHW :153) | set the CSS custom property the markdown `.hover-contents` `max-width` reads, so it caps to available width not the 500px default | `hover_width_style` (sets `--vscode-hover-maxWidth` + `max-width`) | TESTED |
| `_findMaximumRenderingWidth` (cHW :217-235) | cap to the editor **content area** (`width − contentLeft − 24`), not the whole editor box, so the right-aligned widget cannot push left into the gutter | `hover_available_width` (takes `gutter_width`) | TESTED |
| `_isHoverTextOverflowing` (cHW :202-215) | nowrap probe: `scrollWidth > clientWidth` over children | `HoverWidgetDom::measure_natural_width` (`content_widgets.mbt`, Phase 4 width-sizing completion — see below) | TESTED — **correction**: this row previously claimed TESTED via "folded into `hover_available_width` overflow check", but `hover_available_width` was (and remains) a static box-derived cap with no DOM measurement at all; there was no real nowrap probe until the Phase 4 completion landed. |

**Proof.** Verified directly against the real editor, no Monaco reference page:
- `tall hover is capped to the available space and stays fully scrollable`
- `wrappable hover content is capped to the editor content area in a narrow window`
- `a medium hover payload renders proportioned to its text, not collapsed to the CSS min-width floor`
  (added with the Phase 4 width-sizing completion; empirically confirmed to
  *fail* against the pre-completion `apply_width_sizing` — the marker-hover
  message collapsed to `.monaco-resizable-hover`'s CSS `min-width: 150px`
  floor instead of its own natural width)

both in `tests/browser/conformance/monaco_hover_scrollbar.spec.js`. These *fail*
against the old `max(80, clientHeight−24)` `apply_sizing` and *pass* after the
port. Reconciliation: 23 members → 9 done/tested, 11 deferred (sashes), 3 N-A.

---

## Phase 2 — `hoverOperation.ts` (whole) — DONE (immediate-mode product trigger → Phase 5)

`hoverOperation.ts` ported into `hover_controller.mbt` as a pure `HoverOperation`
(state + token + accumulating `parts` + `async_done`); the viewer
(`editor_events.mbt`) drives the schedulers and the sync/async computes.

### Inventory (Phase 2)

`hoverOperation.ts` (whole, 230 lines):
- **Enums:** `HoverOperationState` (Idle/FirstWait/SecondWait/WaitingForAsync/
  WaitingForAsyncShowingLoading) (:25-31); `HoverStartMode` (Delayed/Immediate)
  (:33); `HoverStartSource` (Mouse/Click/Keyboard) (:38).
- **Class `HoverResult`** (value, isComplete, hasLoadingMessage, options) (:44).
- **Class `HoverOperation`:** `_onResult`/`onResult` (:65), three `Debouncer`
  fields (:68-70), `_state`/`_asyncIterable`/`_asyncIterableDone`/`_result`/
  `_options` (:72-76), constructor (:78), `dispose` (:85), `get _hoverTime` (:94),
  `get _firstWaitTime` (:98), `get _secondWaitTime` (:102),
  `get _loadingMessageTime` (:106), `_setState` (:110),
  `_triggerAsyncComputation` (:116), `_triggerSyncComputation` (:148),
  `_triggerLoadingMessage` (:155), `_fireResult` (:161), `start` (:171),
  `cancel` (:193), `get options` (:206).
- **Class `Debouncer`** (RunOnceScheduler wrapper) (:211).
- **Branches to cover:** `start(Delayed)` only when `Idle` (:173);
  `start(Immediate)` switch Idle vs SecondWait (:179-189); async done →
  Idle only from WaitingForAsync/WaitingForAsyncShowingLoading (:134);
  sync trigger `asyncDone ? Idle : WaitingForAsync` (:152); loading only from
  WaitingForAsync (:156); `_fireResult` suppressed in FirstWait/SecondWait (:162).

Member count (Phase 2): 3 enums + `HoverResult` + 18 `HoverOperation` members +
`Debouncer` = **23**.

### Parity ledger (Phase 2)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `HoverOperationState` (:25-31) | 5 states | `HoverOpState` | TESTED |
| `HoverStartMode` (:33-36) | Delayed=0 / Immediate=1 | `HoverStartMode` | TESTED |
| `HoverStartSource` (:38-42) | Mouse/Click/Keyboard | `HoverStartSource` | TESTED |
| `HoverResult` (:44-51) | `{value, isComplete, hasLoadingMessage, options}` | `HoverController::emit` payload | TESTED |
| `_firstWaitTime`/`_secondWaitTime`/`_loadingMessageTime` (:98-108) | `delay/2` / `delay − delay/2` / `3·delay` | `hover_first_wait_ms` / `hover_second_wait_ms` / `hover_loading_message_ms` | TESTED |
| `_setState` (:110-114) | set options+state, then `_fireResult` | `op_set_state` | TESTED |
| `start(Delayed)` (:171-177) | Idle→FirstWait; schedule async@first, loading@loading | `start_delayed` + `apply_hover_effect(HoverScheduleDelayed)` | TESTED |
| `start(Immediate)` (:178-190) | Idle: async-trigger then sync-trigger; SecondWait: sync-trigger | `op_trigger_async` + `op_trigger_sync` back-to-back (wbtest) | TESTED |
| `_triggerAsyncComputation` (:116-146) | →SecondWait; schedule sync@second; kick streamed `computeAsync` | `op_trigger_async` + `hover_trigger_async` + `kick_hover_async` + `compute_async_each` | TESTED |
| `_triggerSyncComputation` (:148-153) | `result += computeSync`; `asyncDone ? Idle : WaitingForAsync` | `op_trigger_sync` + `compute_hover_sync` | TESTED |
| `_triggerLoadingMessage` (:155-159) | WaitingForAsync→WaitingForAsyncShowingLoading | `op_trigger_loading` | TESTED |
| async item / `_asyncIterableDone` (:124-145) | push each item + re-fire; on done complete to Idle | `op_async_item` / `op_async_done` | TESTED |
| `_fireResult` (:161-169) | suppress in FirstWait/SecondWait; else emit `{value,isComplete,hasLoadingMessage}` | `HoverController::emit` (+ `is_complete`) | TESTED |
| `cancel` (:193-204) | drop result, cancel schedulers + async, reset Idle | `HoverController::cleared` | TESTED |
| `dispose` (:85-92) | cancel async, clear options | `HoverController` drop path | PORTED |
| `get options` (:206-208) | current `_options` | `HoverController::options` | PORTED |
| `get _hoverTime` (:94-96) | `editor.getOption(hover).delay` | `hover_delay_ms` | PORTED |
| `Debouncer` (:211-230) | `RunOnceScheduler` wrapper | `editor_events.mbt` scheduler driving | PORTED (host-driven; see Deviations) |

**Deviation (carried):** the viewer's `did_resolve_hover` status event fires
exactly once per anchor on completion (`maybe_notify_hover_resolved`), replacing
the old per-result notification. Immediate-mode's *product* trigger
(keyboard/click `showHover`) lands in Phase 5; the operation already supports it.

Reconciliation: 23 members → 23 ported/tested (schedulers host-driven).

---

## Phase 3 — `contentHoverController.ts` (whole) + `hoverUtils.ts` (whole) — DONE (interaction core; keyboard / contribution / Phase-4 delegations deferred)

Ported the editor-contribution interaction behaviors. The pure helpers
(`hoverUtils.ts`) and the controller's behavior-switching predicates landed as
side-effect-free functions in `viewer/hover_utils.mbt` (whitebox-tested across the
hover-setting matrix); the event handlers (`_onEditorMouseMove`/`Down`/`Leave`,
`_onEditorScrollChanged`, `hideContentHover`) landed as `Viewer` methods in
`viewer/editor_events.mbt`, wired from the input bridge (`viewer/input.mbt`) and
the scroll seam (`apply_scroll_change`). The widget-wrapper delegations (focus /
verbosity / scroll commands / `showContentHover`), the editor-level `_onKeyDown`
chain, and the contribution-registry lifecycle are deferred to Phase 4/5/6 and the
outstanding seams (see the per-row owners and Deviations 6–9).

### Inventory (Phase 3)

`hoverUtils.ts` (whole, 59 lines):
- **Const:** `PADDING.VALUE = 3` (:9).
- **Functions:** `isMousePositionWithinElement` (:13),
  `shouldShowHover` (:33, on/off/onKeyboardModifier), `isTriggerModifierPressed`
  (:51, altKey vs ctrl/meta).

`contentHoverController.ts` (whole, 416 lines):
- **Const:** `_sticky = false` (:29).
- **Interface:** `IHoverSettings {enabled, sticky, hidingDelay}` (:33).
- **Fields:** `_onHoverContentsChanged`/`onHoverContentsChanged` (:41), `ID` (:44),
  `shouldKeepOpenOnEditorMouseMoveOrLeave` (:46), `_listenersStore` (:48),
  `_contentWidget` (:50), `_mouseMoveEvent` (:52), `_reactToEditorMouseMoveRunner`
  (:53), `_hoverSettings` (:55), `_isMouseDown` (:56), `_ignoreMouseEvents` (:58).
- **Methods:** constructor (:60, context-menu show/hide → hide+ignore; config
  change → re-hook), static `get` (:90), `_hookListeners` (:94),
  `_unhookListeners` (:114), `_cancelSchedulerAndHide` (:118), `_cancelScheduler`
  (:123), `_onEditorScrollChanged` (:128), `_onEditorMouseDown` (:137),
  `_shouldKeepHoverWidgetVisible` (:149), `_isMouseOnContentHoverWidget` (:153),
  `_onEditorMouseUp` (:160), `_onEditorMouseLeave` (:167), `_shouldKeepCurrentHover`
  (:185), `_onEditorMouseMove` (:223), `_shouldRescheduleHoverComputation` (:243),
  `_reactToEditorMouseMove` (:251), `_onKeyDown` (:268),
  `_isPotentialKeyboardShortcut` (:293), `hideContentHover` (:307),
  `_getOrCreateContentWidget` (:317), `showContentHover` (:325),
  `_isContentWidgetResizing` (:334), `dispose` (:410).
- **Delegations owned by later phases / out of scope** (listed here so the
  denominator is complete; rows below mark the owner): `focusedHoverPartIndex`
  (:338), `doesHoverAtIndexSupportVerbosityAction` (:342),
  `updateHoverVerbosityLevel` (:346), `focus`/`focusHoverPartWithIndex`
  (:350,:354), `scrollUp/Down/Left/Right`/`pageUp/Down`/`goToTop/Bottom`
  (:358-388), `getWidgetContent` (:390), `getAccessibleWidgetContent(+AtIndex)`
  (:394,:398), `get isColorPickerVisible` (:402), `get isHoverVisible` (:406).
- **Branches to cover:** `enabled==='off'` cancel+hide (:101); `_ignoreMouseEvents`
  guard on every handler; scroll `scrollTopChanged||scrollLeftChanged` (:132);
  mouse-down `_shouldKeepHoverWidgetVisible` (:142); leave `shouldKeepOpen` /
  `_sticky` (:171,:179); `_shouldKeepCurrentHover` 7-way OR (:214-220);
  `_shouldRescheduleHoverComputation` `visible && sticky && hidingDelay>0` (:248);
  `_reactToEditorMouseMove` `shouldShowHover` gate (:252); keydown
  onKeyboardModifier-trigger / potential-shortcut / focused-Tab (:273,:282,:287);
  `_isPotentialKeyboardShortcut` MoreChordsNeeded vs KbFound-hover-action
  (:298-304); `hideContentHover` `_sticky` / dropdown-visible (:308,:311).

Member count (Phase 3): 4 (`hoverUtils`) + 1 const + 1 iface + 11 fields +
24 controller methods (incl. 18 interaction + 6 delegation rows) = **41**.

### Parity ledger (Phase 3)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol (target) | Status |
|---|---|---|---|
| `PADDING.VALUE=3` (hu :9) | constant | `hover_hit_padding` | TESTED |
| `isMousePositionWithinElement` (hu :13-22) | rect inset by 3px on all sides | `mouse_within_element` | TESTED |
| `shouldShowHover` (hu :33-45) | `on`→true; `off`→false; else `isTriggerModifierPressed` | `should_show_hover` | TESTED |
| `isTriggerModifierPressed` (hu :51-59) | `altKey`→ctrl||meta; else alt | `is_trigger_modifier_pressed` | TESTED |
| `_sticky=false` (:29) | dev kill-switch | `hover_sticky_debug=false` | TESTED |
| `IHoverSettings` (:33-37) | `{enabled, sticky, hidingDelay}` | `HoverSettings` (+ `HoverEnabled::from_config` / `MultiCursorModifier::from_config`) | TESTED |
| `_hookListeners` (:94-112) | snapshot opts; `off`→cancel+hide; bind editor events | `HoverSettings::defaults` snapshot + input-bridge / scroll-seam event hookup | PORTED |
| `_unhookListeners` (:114) | clear store | — | N-A (listeners bound once at construction; no `DisposableStore`) |
| `onDidChangeConfiguration(hover)` re-hook (:82-87) | unhook+hook on `hover` change | — | DEFERRED (no hover-options config event; see Deviation 9) |
| context-menu open/close (:74-80) | open → `hide`+`_ignoreMouseEvents=true`; close → false | `hover_ignore_mouse_events` (guarded everywhere) | DEFERRED (guard ported; no context-menu surface in the viewer to set it) |
| `_cancelScheduler`/`_cancelSchedulerAndHide` (:118-126) | drop `_mouseMoveEvent`, cancel runner (+hide) | `cancel_hover_react` / `dismiss_hover` (exist) | PORTED |
| `_onEditorScrollChanged` (:128-135) | ignore guard; `scrollTop||scrollLeft` changed → hide | `Viewer::on_editor_scroll_changed` | TESTED (browser: scroll_windowing) |
| `_onEditorMouseDown` (:137-147) | keep-visible → return else hide (`_isMouseDown` set) | `Viewer::on_editor_mouse_down` | PORTED |
| `_shouldKeepHoverWidgetVisible` (:149-151) | onWidget \|\| resizing \|\| onColorDecorator | `should_keep_hover_widget_visible` | TESTED |
| `_isMouseOnContentHoverWidget` (:153-158) | `isMousePositionWithinElement(widget, posx, posy)` | `Viewer::mouse_on_hover_widget` | PORTED |
| `_onEditorMouseUp` (:160-165) | `_isMouseDown=false` | — | DEFERRED (`_isMouseDown` only feeds the color-picker arm, N-A) |
| `_onEditorMouseLeave` (:167-183) | ignore; keepOpen; cancel; keep-visible; `_sticky` → hide | `Viewer::on_editor_mouse_leave` | TESTED (browser: hover_rendering keep-open) |
| `_shouldKeepCurrentHover` (:185-221) | OR of focused / resizing / sticky-keyboard / sticky-on-widget / colorPicker / text-selected | `should_keep_current_hover` (in-scope arms: keep-open, sticky-on-widget) | TESTED |
| `_onEditorMouseMove` (:223-241) | keepCurrent → cancel; reschedule grace; else react | `Viewer::on_editor_mouse_move` | TESTED (browser: hover_rendering grace) |
| `_shouldRescheduleHoverComputation` (:243-249) | `visible && sticky && hidingDelay>0` | `should_reschedule_hover` | TESTED |
| `_reactToEditorMouseMove` (:251-266) | `shouldShowHover` gate → `showsOrWillShow`; else hide | `Viewer::react_to_editor_mouse_move` | TESTED (browser) |
| `_onKeyDown` (:268-291) | onKeyboardModifier-trigger show; potential-shortcut/modifier → return; focused+Tab → return; else hide | — (Escape arm via `EscapePressed`) | DEFERRED (needs editor-keydown seam carrying keyCode/modifiers + Phase 4 `isFocused` + Phase 5 shortcut ids) |
| `_isPotentialKeyboardShortcut` (:293-305) | `MoreChordsNeeded` \|\| (`KbFound` hover-action && visible) | `is_potential_hover_shortcut` | DEFERRED (the command ids exist since deviations-closeout Track D; still needs the editor-keydown seam carrying raw keyCodes for chord resolution plus Phase 4 `isFocused` — feature work tracked with `_onKeyDown`) |
| `hideContentHover` (:307-315) | `_sticky`/dropdown-visible guards; widget hide | `Viewer::hide_content_hover` (dropdown guard N-A) | PORTED |
| `_getOrCreateContentWidget` (:317-323) | lazy create wrapper + wire `onContentsChanged` | wrapper accessor | DEFERRED (wrapper = Phase 4) |
| `showContentHover` (:325-332) | `startShowingAtRange(range, mode, source, focus)` | `HoverController::show_at_range` | DEFERRED (immediate-mode product trigger = Phase 5, per Phase 2 note) |
| `_isContentWidgetResizing` (:334-336) | `widget.isResizing` | resize probe | DEFERRED (sashes) |
| static `get` (:90-92) / `ID` (:44) / `dispose` (:410-415) | contribution identity + teardown | `editor.contrib.contentHover` registered in the contribution registry (`hover_contribution.mbt`); `Viewer::get_contribution` is the `get` analog; instance disposes with the viewer | PORTED (deviations-closeout Track D, 2026-07-03) |
| `shouldKeepOpenOnEditorMouseMoveOrLeave` (:46) | external keep-open flag | `hover_keep_open` (read in mouse-move keep-current + mouse-leave) | PORTED |
| `_onHoverContentsChanged`/`onHoverContentsChanged` (:41) | re-layout fan-out | contents-changed event | DEFERRED (Phase 4 wiring) |
| color-picker arms of `_shouldKeepCurrentHover` (:195-201) | colorPicker visible/choosing | — | N-A (colorPicker out of scope) |
| text-selection arm of `_shouldKeepCurrentHover` (:203-209) | sticky + active selection in widget | — | N-A (sticky text-select; revisit with sticky) |
| `focusedHoverPartIndex` (:338) / `focusHoverPartWithIndex` (:354) / `focus` (:350) | delegate to wrapper | — | DEFERRED (Phase 4) |
| `doesHoverAtIndexSupportVerbosityAction` (:342) / `updateHoverVerbosityLevel` (:346) | delegate to wrapper | — | DEFERRED (Phase 6) |
| `scrollUp/Down/Left/Right`,`pageUp/Down`,`goToTop/Bottom` (:358-388) | delegate to widget (8) | — | DEFERRED (Phase 5) |
| `getWidgetContent` (:390) | `node.textContent` | `HoverController::widget_content` | DEFERRED (Phase 5) |
| `getAccessibleWidgetContent(+AtIndex)` (:394,:398) | accessible text | — | N-A (accessibility) |
| `get isColorPickerVisible` (:402) | wrapper flag | — | N-A (colorPicker) |
| `get isHoverVisible` (:406) | wrapper `isVisible` | `HoverController::widget_visible` (exists) | PORTED |

**Proof.** `hoverUtils` + the controller predicates are whitebox-tested in
`viewer/hover_interaction_wbtest.mbt` across the matrix
(`enabled ∈ {on, off, onKeyboardModifier}` × `sticky` × `hidingDelay ∈ {0, >0}` ×
multi-cursor modifier ∈ {alt, ctrl, meta}); each `should*` branch and the 3px
padding ring have a case. The live handlers are covered by the browser
conformance specs: `hover_rendering.spec.js` ("keeps the hover open while the
pointer travels onto the widget" — `_onEditorMouseMove` keep-current / grace,
`_onEditorMouseLeave`), `scroll_windowing.spec.js` ("resolves hover … after
deterministic scrolling" — `_onEditorScrollChanged` hide-then-recompute), and
`mouse_selection.spec.js` (mouse-down no longer dismisses via cursor placement).

**Reconciliation (Phase 3): 41 members → 20 done (PORTED/TESTED), 16 deferred,
5 N-A.** Deferred owners: Phase 4 wrapper (`_getOrCreateContentWidget`,
`_contentWidget`, `onContentsChanged`, focus cluster), Phase 5 (scroll/page/goto
commands, `showContentHover`, `getWidgetContent`, `_isPotentialKeyboardShortcut`),
Phase 6 (verbosity), sashes (`_isContentWidgetResizing`), and the
editor-keydown / config-event / contribution-registry seams (`_onKeyDown`,
`onDidChangeConfiguration` re-hook, context-menu `_ignoreMouseEvents` setter,
static `get`/`ID`/`dispose`, `_onEditorMouseUp`/`_isMouseDown`). N-A:
`_unhookListeners`/`_listenersStore` (no `DisposableStore`), color-picker +
text-selection arms, `getAccessibleWidgetContent(+AtIndex)`, `isColorPickerVisible`.

---

## Phase 4 — `contentHoverWidgetWrapper.ts` + `contentHoverRendered.ts` + `contentHoverWidget.ts` structure remainder — IN PROGRESS (increments 1–7 landed)

Give rendered parts real structure instead of one HTML blob: a
`RenderedContentHover` analog that owns per-part nodes, supports focus
navigation, applies per-part `hoverHighlight` decorations, and fans
`onDidResize`/`onDidScroll`/`onContentsChanged` out to participants. Rendering
stays in `viewer/hover/`; node-ownership/focus wiring is viewer-core.

**Increment 1 (pure-logic-first, landed).** Per the "internal refactor / no
backward-compat / pure-logic-first" guidance, the side-effect-free placement row
landed ahead of the DOM rework: `RenderedContentHover.computeHoverPositions`
ported as `compute_hover_positions` (`viewer/hover_widget_geometry.mbt`),
whitebox-tested across its branches
(`viewer/hover_widget_geometry_wbtest.mbt`), and **wired** at the content-widget
render seam (`content_widgets.mbt::render_hover_widget`) to drive the body's
horizontal anchor column from the secondary position. The wiring is
behavior-neutral (proof: the viewer anchors at `hover.range.start`, the
union-of-parts start = the global minimum start offset, so every on-anchor-line
part's start column is ≥ that column and the secondary clamp resolves back to
it).

**Increment 2 (pure-logic-first, landed).** The sticky mouse-getting-closer
keep: `isMouseGettingCloser` + `computeDistanceFromPointToRectangle` ported as
`MouseCloserState::is_mouse_getting_closer` /
`compute_distance_from_point_to_rectangle` (whitebox-tested), and **wired** —
`react_to_editor_mouse_move` now keeps a visible sticky hover when the pointer
is approaching the widget (Monaco `_startShowingOrUpdateHover` :114-124), with
the closer state reset per shown view (`after_hover_transition`) to mirror
Monaco's fresh `RenderedContentHover`. The deferred mouse-move runner now fires
`react_to_editor_mouse_move` (Monaco's `_reactToEditorMouseMoveRunner` →
`_reactToEditorMouseMove`) so the grace path re-gates `shouldShowHover` and the
keep. Validated: the hover conformance specs (incl. keep-open + exact-pixel
anchor) stay green.

**Increment 3 (shown-hover reconciliation, landed).** The
`_startShowingOrUpdateHover` / `_startHoverOperationIfNecessary` / `_withResult`
/ `_setCurrentResult` chain, ported into `HoverController`
(`hover_controller.mbt`). The controller now tracks the shown `_currentResult`
(its parts, the anchor that produced them, and whether it was complete)
separately from the in-flight operation, so: the same anchor keeps the hover
untouched; a compatible (same model line) anchor keeps the still-valid parts
(`filter`) and restarts the operation; an incompatible anchor hides then
restarts; and `_withResult` holds a complete shown hover until the new result
completes (no flicker to a partial). `canAdoptVisibleHover`,
`isValidForHoverAnchor`, and `ContentHoverResult.filter` (from the otherwise
out-of-scope `hoverTypes.ts`/`contentHoverTypes.ts`) are ported inline as
`hover_anchor_can_adopt` / `hover_part_valid_for_anchor` / `filter_hover_parts`
in offset space. The anchor's model start line flows through a new
`EditorContext.offset_to_model_line` seam. Whitebox-tested across the six
reconciliation branches; the hover conformance specs stay green.

**Increment 4 (`isMouseGettingCloser` insist-update, landed).** With the
reconciliation in place, the sticky mouse-getting-closer branch moved from the
input-seam keep (increment 2) into the controller's
`start_showing_or_update_hover`, matching Monaco `_startShowingOrUpdateHover`
:114-124: a visible sticky hover the pointer is approaching is kept untouched
*and* kicks `start_hover_operation_if_necessary(insist=true)` at the new anchor,
so an empty result keeps the previous hover (`_withResult`
`shouldKeepPreviousHoverVisible`) instead of hiding. The
`sticky && isMouseGettingCloser` signal is measured once per reaction in
`run_hover_react` and threaded through `on_event`. Two whitebox tests cover the
keep+insist and the empty-keep; the hover conformance specs stay green.
`setMinimumDimensions`/`_updateMinimumWidth` and the wrapper/rendered DOM rows
remain TODO; they land with their consumers (sashes / the per-part structure
rework) rather than as committed dead code.

**Increment 5 (per-part rendered structure, landed).** The first slice of the
DOM rework: `RenderedContentHoverParts._renderParts` ported as
`render_hover_parts` (`viewer/hover/hover_render.mbt`) — the content is rendered
as one HTML string **per rendered hover part** (a single-root `.hover-row`) instead
of one concatenated blob, with a multi-content markdown part grouped into a single
row carrying one `.markdown-hover` block per content (Monaco `renderMarkdown`), and
a marker hover split into its `.hover-row` plus a separate status-bar row (Monaco's
distinct `statusBar` rendered part). The viewer core mounts the rows and applies
the `_registerListenersOnRenderedParts` `tabIndex = 0` line to every part
(`content_widgets.mbt::set_hover_parts`), so each rendered part is an independent
focus stop. The participant-`renderHoverParts` indirection is collapsed — the
`@hover` package renders parts directly (DI seam, Deviation 4) — so the per-part
`focusin`/`focusout` index tracking, the `focus*` navigation it feeds, and the
real action-backed status bar remain DEFERRED to their keyboard / verbosity
(Phase 5/6) consumers rather than landing as dead state. Whitebox-tested for the
markdown grouping and the marker/status-bar split
(`viewer/hover/hover_render_wbtest.mbt`); the hover conformance specs stay green
(a per-part `> .hover-row[tabindex="0"]` assertion added to `hover_rendering.spec.js`).

**Increment 6 (width-sizing completion, landed).** Fixed a real rendering bug
found while auditing this phase: `apply_width_sizing` only ever set CSS
`max-width` on `scrollable.content` — a *ceiling*, not a *lock*. Since nothing
else in the DOM chain forced a shrink-to-fit width, a block-level element with
only `max-width` set collapses to its container's default width behavior,
which bottomed out at `.monaco-resizable-hover`'s CSS `min-width: 150px` —
so *any* hover content, regardless of its own natural length, could render in
a box as narrow as 150px, wrapping far more aggressively than Monaco's real
box. Reproduces the reported symptom exactly (a diagnostic message wrapped
across many narrow lines). Ported the missing half of Monaco's
`handleContentsChanged`/`_setHoverWidgetDimensions`
(`contentHoverWidget.ts:113-137,406-428`) width axis: `_isHoverTextOverflowing`
(:202-215)'s nowrap probe as `HoverWidgetDom::measure_natural_width`
(force `--vscode-hover-whiteSpace`/`--vscode-hover-sourceWhiteSpace: nowrap`
via the CSS hooks `hover.css` already exposed but never drove, measure, then
release); `_findMaximumRenderingWidth`'s decision (:217-236, no page-body
branch — this port's non-overflowing-viewer deviation carries forward) as the
pure, tested `hover_resolved_width` (natural width if it fits, else the
available-width cap); and the width axis of `_setHoverWidgetDimensions`
(applying an **explicit `width`**, not `max-width`) extended from the single
`scrollable.content` node to all three DOM levels Monaco touches —
`hover`/`scrollable.wrapper`/`scrollable.content` (`containerDomNode`/
`scrollbar.getDomNode()`/`contentsDomNode`). The outermost `wrapper`
(Monaco's `_resizableNode.domNode`) stays untouched — still the deferred
sash machinery's job. `setMinimumDimensions`/`_updateMinimumWidth` stay
un-ported (not just unconsumed): no caller exists for either side of that
pair, and this repo's convention is to not commit dead code, not even a
tested-only pure function — see the corrected Phase 1b `_isHoverTextOverflowing`
row below, which had claimed this was already done. Proof: a new browser case
in `tests/browser/conformance/monaco_hover_scrollbar.spec.js` reproducing the
marker-hover scenario, empirically confirmed to fail (150px CSS-floor
collapse) against the pre-completion code and pass (231px, proportioned to the
text) after.

**Increment 7 (faithful above/below positioning, landed — fixes a paint bug
Increment 6 introduced).** Increment 6's extra style churn on `.hover`
(`.monaco-hover`, the element carrying the theme background/border) exposed a
latent bug: `ContentWidget::style()` positioned the widget's `top` at the
anchor line unconditionally and relied on a CSS `transform:
translateY(-100%)` on `.monaco-resizable-hover` to visually shift "above"
placements up by their own height. That transform is **not** something
Monaco does — grepping `contentHoverWidget.ts` and
`contentWidgets.ts` for `transform`/`translateY` finds nothing; Monaco
computes the exact top coordinate once in JS
(`_layoutBoxInViewport`, `contentWidgets.ts:309-317`: `aboveTop = aboveLineTop
- height`) and sets it directly via `domNode.setTop(...)`
(`contentWidgets.ts:580-581`) — no transform, ever. It was an invented
technique from a predecessor DOM/CSS plan. Combined with Increment 6's
heavier synchronous style churn on `.hover` (an `innerHTML` remount +
multiple style writes, all under a GPU-promoted transformed ancestor layer),
this reproducibly left `.hover`'s background unpainted in Chromium — visible
in a real window/full-page screenshot even though every computed style
queried correctly (an element-scoped screenshot, which forces its own
repaint as part of capture, never showed it — misleadingly "confirming" the
port as correct during Increment 6's own validation).

Fixed by porting the real mechanism instead of patching around the symptom:
`ContentWidget` gained a `height` field (Monaco's `_cachedDomNodeOffsetHeight`
parameter to `_layoutBoxInViewport`); `ContentWidget::style()`'s `top` for
`ContentWidgetAbove` is now `anchor.top - height` (`ContentWidgetBelow`
unchanged, already matching Monaco's `belowTop = underLineTop`); the CSS
`transform` rules on `.monaco-resizable-hover`/`.monaco-resizable-hover.below`
are deleted. `render_hover_widget` threads `hover_view.placement.max_height`
in as `height` (`0.0` during the throwaway measuring pass, before placement
is known — Monaco's own DOM-offset cache is similarly unset until a real
layout has happened). Confirmed against a real full-page screenshot capture
(not just `getComputedStyle`, which had passed throughout): the background
paints correctly, and the final pixel position is unchanged (verified the
computed `top` matches the old transform-shifted position exactly — this is
a rendering-mechanism fix, not a visual/layout change).

### Inventory (Phase 4)

`contentHoverWidgetWrapper.ts` (whole, 419 lines):
- **Fields:** `_currentResult`, `_renderedContentHover`, `_contentHoverWidget`,
  `_participants`, `_hoverOperation`, `_onContentsChanged`/`onContentsChanged`.
- **Methods:** constructor (:39), `_initializeHoverParticipants` (:53, sort by
  ordinal + resize/scroll/contents fan-out), `_registerListeners` (:72, Escape
  key, mouseleave, TokenizationRegistry re-render, contents-changed),
  `_startShowingOrUpdateHover` (:99), `_startHoverOperationIfNecessary` (:151),
  `_setCurrentResult` (:166), `_addLoadingMessage` (:184), `_withResult` (:198),
  `_showHover` (:219), `_hideHover` (:229), `_getHoverContext` (:234),
  `showsOrWillShow` (:249), `_findHoverAnchorCandidates` (:263), `_onMouseLeave`
  (:298), `startShowingAtRange` (:306), `getWidgetContent` (:310),
  `updateHoverVerbosityLevel`/`doesHoverAtIndexSupportVerbosityAction` (:318,:322 →
  Phase 6), `getAccessibleWidgetContent(+AtIndex)` (:326,:330 → accessibility),
  `focusedHoverPartIndex` (:334), `containsNode` (:338), `focus` (:342),
  `focusHoverPartWithIndex` (:351), scroll/page/goto delegations (:355-385 →
  Phase 5), `hide` (:387), `getDomNode` (:392), `isColorPickerVisible` (:396 →
  N-A), `isVisibleFromKeyboard`/`isVisible`/`isFocused`/`isResizing` (:400-413),
  `widget` getter (:416).
- **Branches:** `_startShowingOrUpdateHover` 7-way (not-visible+anchor; sticky+
  getting-closer; no-anchor hide; same-anchor; incompatible-anchor; filter)
  (:106-148); `_withResult` complete/insist-keep (:199-216);
  `_findHoverAnchorCandidates` `CONTENT_TEXT` vs `CONTENT_EMPTY` epsilon (:276-293);
  `focus` `hoverPartsCount===1` (:344).

`contentHoverRendered.ts` (whole, 487 lines):
- **`RenderedContentHover`:** constructor (:44), `domNode`/`domNodeHasChildren`
  (:76,:80), `focusedHoverPartIndex` (:84), `hoverPartsCount` (:88),
  `focusHoverPartWithIndex` (:92), `getAccessibleWidgetContent(+AtIndex)` (:96,:100
  → accessibility), `updateHoverVerbosityLevel`/`doesHover…SupportVerbosity`
  (:104,:108 → Phase 6), `isColorPickerVisible` (:112 → N-A), static
  `computeHoverPositions` (:116).
- **`IRenderedContentHoverPart`/`IRenderedContentStatusBar`/union** (:167-201).
- **`RenderedStatusBar`** (:203).
- **`RenderedContentHoverParts`:** `_DECORATION_OPTIONS` (`hoverHighlight`) (:224),
  constructor (:237), `_createEditorDecorations` (:255, `plusRange` fold),
  `_renderParts` (:274), `_renderHoverPartsForParticipant` (:307),
  `_renderStatusBar` (:316), `_registerListenersOnRenderedParts` (:323, FOCUS_IN/
  FOCUS_OUT per-part index, MarkerHover copy button), `_updateMarkdownAndColor…`
  (:349 → markdown only), `focusHoverPartWithIndex` (:359), `getAccessibleContent
  (+AtIndex)` (:366,:374 → accessibility), `updateHoverVerbosityLevel` (:394 →
  Phase 6), `doesHover…SupportVerbosity` (:430 → Phase 6), `isColorPickerVisible`
  (:441 → N-A), `_normalizedIndexToMarkdownHoverIndexRange` (:445),
  `_findRangeOfMarkdownHoverParts` (:464), `domNode`/`domNodeHasChildren`/
  `focusedHoverPartIndex`/`hoverPartsCount` (:472-486).
- **Branches:** `computeHoverPositions` `forceShowAtRange` vs anchor (:152);
  on-anchor-line clamp (:138-144); `_createEditorDecorations` empty-parts
  early-return (:256); copy-button only for `MarkerHover` (:337).

`contentHoverWidget.ts` **structure/resize remainder** (slice): `_lastDimensions`
(:27), `onDidResize`/`onDidScroll`/`onContentsChanged` emitters (:38-45),
`isMouseGettingCloser` (:238), `_render` (:314), `handleContentsChanged` (:406),
`_removeConstraintsRenderNormally` (:379), `setMinimumDimensions` (:387),
`_updateMinimumWidth` (:396), `_updateMaxDimensions` (:307),
`_updateResizableNodeMaxDimensions` (:162), `_resize` override (:169),
`_setHoverWidgetDimensions`/`_setAdjustedHoverWidgetDimensions` + the four DOM
dimension setters (:113-160), `_setRenderedHover` (:278), `_updateContent` (:295),
`_layoutContentWidget` (:302), `computeDistanceFromPointToRectangle` (:477).

Member count (Phase 4): 30 (wrapper) + 28 (rendered) + 20 (widget remainder) =
**78**. (Accessibility/colorPicker/verbosity rows carry `N-A`/`DEFERRED` here.)

### Parity ledger (Phase 4)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol (target) | Status |
|---|---|---|---|
| `_initializeHoverParticipants` fan-out (wrap :53-70) | sort by `hoverOrdinal`; on resize/scroll/contents → `participant.handle*` | `RenderedContentHover::wire_participants` (new) | TODO |
| `_startShowingOrUpdateHover` (wrap :99-149) | 7-branch anchor reconciliation | `HoverController::start_showing_or_update_hover` (sticky-getting-closer arm pre-handled at the input seam; no-anchor → `cleared`) | TESTED |
| `_startHoverOperationIfNecessary` (wrap :151-164) | skip if anchor==prev; else cancel + `operation.start` | `HoverController::start_hover_operation_if_necessary` (wraps Phase 2 `HoverOperation`) | TESTED |
| `_setCurrentResult` (wrap :166-182) | dedupe; empty→null; show/hide | `HoverController::set_current_result` | TESTED |
| `_addLoadingMessage` (wrap :184-196) | first participant `createLoadingMessage` | loading hover synthesized in `widget_view` (Phase 2) | DEFERRED (participant `createLoadingMessage` seam; loading already shows) |
| `_withResult` (wrap :198-217) | complete-vs-partial + insist-keep gating | `HoverController::emit` (`_fireResult` suppression + `_withResult` gating; insist arm inert per Deviation 11) | TESTED |
| `_showHover`/`_hideHover` (wrap :219-232) | build `RenderedContentHover`; `handleHide` fan-out | `show_hover`/`hide_hover` | TODO |
| `_getHoverContext` (wrap :234-246) | `{hide, onContentsChanged, setMinimumDimensions, focus}` | `HoverContext` record | TODO |
| `showsOrWillShow` (wrap :249-261) | resizing→true; anchor[0] or null → start | `HoverController::on_event(MouseMoved)` arm (`isResizing`/code-action early-keeps N-A: no sashes, no action widget) | TESTED |
| `_findHoverAnchorCandidates` (wrap :263-296) | participant anchors + CONTENT_TEXT / CONTENT_EMPTY epsilon; sort by priority | `find_anchor_candidates` (`hover_anchor.mbt`, with the `hoverTypes.ts` `HoverAnchor` enum: range anchor at the mouse position, `suggestHoverAnchor` trait seam, inlay `HoverForeignElementAnchor` priority 10 / `supportsMarkerHover`; `MouseTarget.horizontal_distance_to_text` feeds the CONTENT_EMPTY epsilon) | TESTED |
| `_onMouseLeave` (wrap :298-304) | hide if mouse outside editor | mouse-leave bridge | TODO |
| `startShowingAtRange` (wrap :306-308) | range anchor → start | `start_showing_at_range` | TODO |
| `focus` (wrap :342-349) | `hoverPartsCount===1` → focus part 0 else widget | `wrapper_focus` (new) | TODO |
| `focusedHoverPartIndex`/`focusHoverPartWithIndex`/`containsNode` (wrap :334-353) | part nav + node containment | focus-nav cluster | TODO |
| `RenderedContentHover.computeHoverPositions` (rend :116-164) | view-line column clamp; `forceShowAtRange` vs anchor start; secondary column min/max | `compute_hover_positions` (`hover_widget_geometry.mbt`; wired at the render seam) | TESTED |
| `_renderParts` (rend :274-305) | per-participant render → one rendered part (`hoverElement`) per part; status bar split as its own part | `render_hover_parts` (`hover/hover_render.mbt`; participant-`renderHoverParts` indirection collapsed per Deviation 4 — markdown contents grouped into one `.hover-row`, marker row + status-bar row as separate single-root parts) | TESTED |
| `_createEditorDecorations` (rend :255-272) | fold `Range.plusRange`; set `hoverHighlight` decoration | `HoverController::decorations` (single `Range.plusRange`-fold decoration over the union span = `hover_parts_range`) | PORTED (class `has-hover` per predecessor DOM plan) |
| `_registerListenersOnRenderedParts` (rend :323-347) | per-part `tabIndex=0`; FOCUS_IN→index, FOCUS_OUT→−1; `MarkerHover`→copy button | `set_hover_parts` (`content_widgets.mbt`) sets `tabIndex=0` per part; FOCUS_IN/OUT index tracking DEFERRED (Phase 5/6 focus consumer), copy button N-A (global click delegation) | TESTED (tabIndex) |
| `_normalizedIndexToMarkdownHoverIndexRange`/`_findRangeOfMarkdownHoverParts` (rend :445-470) | map global index ↔ markdown-part index range | index-mapping helpers (new) | DEFERRED (Phase 6 verbosity) |
| `RenderedStatusBar` + `_renderStatusBar` (rend :203-220,:316-321) | append status bar element if `hasContent` | marker status bar now emitted as its own single-root rendered-part row (`marker_status_bar_row`); real action-backed `EditorHoverStatusBar` = Phase 5 | PORTED (structure split; actions Phase 5) |
| `_DECORATION_OPTIONS hoverHighlight` (rend :224-227) | decoration class | `HoverController::highlight_decorations` (`className 'hoverHighlight'`, description `content-hover-highlight`), `Range`-native since the Track E anchor rebase | PORTED |
| `contentHoverWidget._resize` override (cHW :169-177) | `_lastDimensions`; adjust dims; relayout; `onDidResize.fire` | — | DEFERRED (sashes) |
| `_updateResizableNodeMaxDimensions`/`_updateMaxDimensions` (cHW :162,:307) | `max(layoutInfo.h/4, 250, last.h)` × `max(w·0.66, 750, last.w)` | `hover_update_max_dimensions` (new) | DEFERRED (sashes) |
| `setMinimumDimensions`/`_updateMinimumWidth` (cHW :387,:396) | combine min dims; min width = `min(contentWidth, minWidth)` | — | DEFERRED (no caller — nothing calls the Monaco equivalent of `setMinimumDimensions` yet, `HoverContext` itself is still a TODO row above; not committed as untested dead code) |
| `handleContentsChanged` (cHW :406-428) width subset | measure natural (nowrap) width, lock an explicit width | `HoverWidgetDom::measure_natural_width` + `hover_resolved_width` (`content_widgets.mbt`) | TESTED (the height/position-preference re-pick this function also does was already covered by the existing two-pass `render_hover_widget` flow, not re-ported as a discrete function) |
| `_removeConstraintsRenderNormally` (cHW :379-385) | layout to editor box; dims `auto`; update max | folded into the existing two-pass flow's unconstrained-then-measured cycle (`render_hover_widget`'s `clear_sizing` + measuring pass) | PORTED (equivalent effect, not a discrete function) |
| `isMouseGettingCloser` + `computeDistanceFromPointToRectangle` (cHW :238-276,:477-483) | point-to-rect distance, 4px tolerance, track closest | `MouseCloserState::is_mouse_getting_closer` / `compute_distance_from_point_to_rectangle` (`hover_widget_geometry.mbt`; `sticky && getting-closer` signal threaded into `start_showing_or_update_hover`'s insist-update; reset per shown view) | TESTED |
| `_render`/`_setRenderedHover`/`_updateContent`/`_layoutContentWidget` (cHW :314-322,:278-305) | render + visibility key + content swap | render pipeline | TODO |
| dimension setters `_setHoverWidgetDimensions` etc. (cHW :113-160) | width/height px apply (4 setters) | `HoverWidgetDom::apply_width_sizing`/`apply_sizing`/`clear_sizing`, `hover_width_style` (`content_widgets.mbt`) | TESTED (width axis, applied to all 3 levels `_setHoverWidgetDimensions` touches — `hover`/`scrollable.wrapper`/`scrollable.content`; the outermost `wrapper`, Monaco's `_resizableNode.domNode`, stays untouched, its sizing is the deferred sash machinery's job. Height stays a `max-height` cap, not an exact height — Monaco's exact-height lock is part of the sash-resize `_resizableNode` sizing this port doesn't have a caller for) |
| `onDidResize`/`onDidScroll`/`onContentsChanged` emitters (cHW :38-45) | participant fan-out events | event seams | TODO |
| `getAccessibleWidgetContent*` (wrap/rend) | accessible text | — | N-A (accessibility) |
| `isColorPickerVisible`/`_updateMarkdownAndColor…` colorPicker arm | colorPicker state | — | N-A (colorPicker out of scope) |
| `updateHoverVerbosityLevel`/`doesHover…SupportVerbosity` (wrap/rend) | verbosity delegation | — | DEFERRED (Phase 6) |
| scroll/page/goto delegations (wrap :355-385) | widget passthrough (8) | — | DEFERRED (Phase 5) |

---

## Phase 5 — status bar actions + `hoverActionIds.ts` + `hoverActions.ts` + `hoverContribution.ts` + widget scroll cluster — IN PROGRESS (scroll cluster + status-bar structure landed)

Replace the static "View Problem" markup with a real `EditorHoverStatusBar`
analog whose actions invoke commands, and register the `hoverActionIds` command
set (scroll/page/goto, keyboard `showHover`, `hideHover`) as real editor
commands, replacing inline-only `handle_hover_keydown` (`content_widgets.mbt`)
with command-backed handlers (same key bindings).

**Increment 1 (widget scroll cluster, landed).** The eight
`ContentHoverWidget` scroll methods + `HORIZONTAL_SCROLLING_BY = 30` ported as
`HoverWidgetDom::scroll_up`/`scroll_down`/`scroll_left`/`scroll_right`/`page_up`/
`page_down`/`go_to_top`/`go_to_bottom` (`content_widgets.mbt`), each matching
Monaco's arithmetic line-for-line (`scrollTop ± lineHeight`; `scrollLeft ± 30`;
`scrollTop ± getScrollDimensions().height` for page; `0` / `scrollHeight` for the
edges). The focused widget's `handle_hover_keydown` now dispatches to them with
Monaco's exact key map from `hoverActions.ts`: arrow primaries
(`Scroll{Up,Down,Left,Right}HoverAction`), `PageUp`/`PageDown`/`Home`/`End`, plus
the previously-missing **secondary keybindings** — `Alt+Arrow` pages
(`Page{Up,Down}HoverAction`) and `CtrlCmd+Arrow` jumps to an edge
(`GoTo{Top,Bottom}HoverAction`). This corrects the only arithmetic divergence in
the old inline handler — horizontal scroll used a font-dependent `4 × charWidth`
nudge instead of Monaco's fixed `30` (Deviation 13). The command/contribution
registration and the `hoverFocused` context key remain TODO (they need the
viewer command registry — Deviation 4). Proof: two new keyboard cases in
`tests/browser/conformance/hover_rendering.spec.js` (the scroll-cluster
keybindings incl. `Alt`/`CtrlCmd` secondaries; the fixed horizontal step),
hover conformance specs stay green.

**Increment 2 (status-bar structure, landed).** Fixed a real rendering bug
found while auditing this phase: `render_hover_parts`
(`viewer/contrib/hover/hover_render.mbt`) pushed the marker's status-bar row
*inline, mid-loop*, immediately after the marker's content row — so a
later-ordinal part (e.g. an LSP/markdown hover on the same anchor) rendered
*after* the status bar instead of before it, producing a visually disconnected
extra row. Monaco's `_renderParts` (`contentHoverRendered.ts:274-305`) loops
over every participant collecting content rows first and appends the single
shared status bar **after the whole loop**, never interleaved. Ported that
ordering: `render_hover_parts` now collects a `has_status_bar_content` flag
during the loop and pushes `marker_status_bar_row()` once, after every part's
content row. `marker_status_bar_row`'s DOM shape was also corrected to match
`HoverAction.render` (`hoverWidget.ts:52-92`) exactly — `tabindex` moved from
`<a class="action">` to `.action-container` (Monaco never sets it on the
`<a>`), and the label text is now a `<span>` child rather than the `<a>`'s
direct text. The still-static `run` handler (a documented no-op) and the
missing `hoverActionIds`/`hoverActions`/`hoverContribution` command
registration are unchanged — seeing this through end-to-end needs
`markerController.showAtMarker`'s target, an in-editor peek widget
(`MarkerNavigationWidget`) this codebase hasn't ported; that's its own future
exec-plan, not folded into this one. Proof: a new ordering regression case in
`hover_render_wbtest.mbt` (marker + later-ordinal markdown part → status bar
row is last, not sandwiched) and a new browser case in
`tests/browser/conformance/dom_structure.spec.js` (same scenario, asserting
`.monaco-hover-content`'s direct children in order).

### Inventory (Phase 5)

`contentHoverStatusBar.ts` (whole, 58 lines): `EditorHoverStatusBar` —
`hoverElement` (:17), `actions` (:18), `actionsElement` (:20), `_hasContent`
(:21), `get hasContent` (:23), constructor (:27, `div.hover-row.status-bar` +
`div.actions`, `tabIndex=0`), `addAction` (:37, keybinding lookup + managed
hover + push), `append` (:53).

`hoverActionIds.ts` (whole, 24 lines): the action-id constants —
`SHOW_OR_FOCUS_HOVER` (:7), `SHOW_DEFINITION_PREVIEW_HOVER` (:8), `HIDE_HOVER`
(:9), `SCROLL_{UP,DOWN,LEFT,RIGHT}_HOVER` (:10-13), `PAGE_{UP,DOWN}_HOVER`
(:14-15), `GO_TO_{TOP,BOTTOM}_HOVER` (:16-17), `INCREASE/DECREASE_HOVER_VERBOSITY`
(+accessible +label) (:18-23 → Phase 6), `HIDE_LONG_LINE_WARNING_HOVER` (:24).

`hoverActions.ts` (whole, 472 lines): `HoverFocusBehavior` enum (:22);
`ShowOrFocusHoverAction` (:28, `Ctrl+K Ctrl+I`, isHoverVisible/focus branches);
`ShowDefinitionPreviewHoverAction` (:109 → DEFERRED, needs goToDefinition);
`HideContentHoverAction` (:152); `Scroll{Up,Down,Left,Right}HoverAction`
(:171-297, arrow keys, `hoverFocused` precondition); `Page{Up,Down}HoverAction`
(:299-363, PageUp/Down + `Alt+Arrow` secondary); `GoTo{Top,Bottom}HoverAction`
(:365-430, Home/End + `Ctrl+Arrow` secondary); `IncreaseHoverVerbosityLevel` /
`DecreaseHoverVerbosityLevel` (:432-472 → Phase 6).

`hoverContribution.ts` (whole, 54 lines): `registerEditorContribution`
×2 (content + glyph) (:22-23); `registerEditorAction` ×13 (:24-36); participant
registry ×2 (:37-38); `HIDE_LONG_LINE_WARNING` command (:39); theming participant
`editorHoverBorder` (:44-51); accessible-view registrations (:52-54 → N-A).

`contentHoverWidget.ts` **scroll cluster** (slice): `HORIZONTAL_SCROLLING_BY=30`
(:22); `scrollUp/Down` (:434,:440, ±`lineHeight`); `scrollLeft/Right` (:446,:451,
±30); `pageUp/Down` (:456,:462, ±scroll-height); `goToTop/Bottom` (:468,:472).

Member count (Phase 5): 9 (status bar) + ~16 (ids; verbosity ids → Phase 6) +
14 (actions; 4 verbosity/preview → Phase 6/DEFERRED) + 18 (contribution) +
8 (scroll cluster) = **~65**.

### Parity ledger (Phase 5)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol (target) | Status |
|---|---|---|---|
| `EditorHoverStatusBar` (csb :15-58) | `div.hover-row.status-bar` + `div.actions`; `addAction` keybinding + managed hover; `hasContent` | `marker_status_bar_row` (`hover_render.mbt`) + participant-loop-then-status-bar-last ordering (`render_hover_parts`) | PORTED (structure/DOM shape/ordering); `addAction` `run` dispatch DEFERRED — the command registry exists (deviations-closeout Track D), but the actions' targets (`MarkerController.showAtMarker`, quick fixes) are the gotoError/codeAction contribs, explicitly out of scope in the closeout plan |
| `hoverActionIds` scroll/page/goto/show/hide consts (hai :7-17,:24) | id strings | Monaco id strings registered in `hover_contribution.mbt` (scroll/page/goto/hide) | PORTED (deviations-closeout Track D; show/definition-preview ids land with their actions) |
| `ShowOrFocusHoverAction` (ha :28-107) | visible+focusOption→focus vs `showContentHover(Immediate, Keyboard, focus)`; a11y-support focus | `show_or_focus_hover` (new) | DEFERRED (needs multi-chord keybindings — Ctrl+K Ctrl+I — beyond the Track D single-chord table, plus the Phase 4 wrapper focus cluster; lands with focus-nav) |
| `HideContentHoverAction` (ha :152-169) | `hideContentHover()` | `editor.action.hideHover` command (Escape, `hoverVisible`) → `Viewer::hide_content_hover` | PORTED (deviations-closeout Track D) |
| `Scroll{Up,Down,Left,Right}HoverAction` (ha :171-297) | arrow keys; `hoverFocused`; delegate to widget (4) | `editor.action.scroll{Up,Down,Left,Right}Hover` commands | PORTED (deviations-closeout Track D) |
| `Page{Up,Down}HoverAction` (ha :299-363) | PageUp/Down + `Alt+Arrow`; widget `pageUp/Down` (2) | `editor.action.page{Up,Down}Hover` commands (PageUp/PageDown + Alt+Arrow secondaries) | PORTED (deviations-closeout Track D) |
| `GoTo{Top,Bottom}HoverAction` (ha :365-430) | Home/End + `Ctrl+Arrow`; widget `goToTop/Bottom` (2) | `editor.action.goTo{Top,Bottom}Hover` commands (Home/End + CtrlCmd+Arrow secondaries) | PORTED (deviations-closeout Track D) |
| widget `scrollUp/Down` (cHW :434,:440) | `scrollTop ± lineHeight` | `HoverWidgetDom::scroll_up`/`scroll_down` (dispatched from `handle_hover_keydown` on `ArrowUp`/`ArrowDown`) | TESTED |
| widget `scrollLeft/Right` (cHW :446,:451) `HORIZONTAL_SCROLLING_BY=30` | `scrollLeft ± 30` | `HoverWidgetDom::scroll_left`/`scroll_right` + `hover_horizontal_scrolling_by=30.0` (on `ArrowLeft`/`ArrowRight`) | TESTED |
| widget `pageUp/Down` (cHW :456,:462) | `scrollTop ± getScrollDimensions().height` (visible height) | `HoverWidgetDom::page_up`/`page_down` (on `PageUp`/`PageDown` + `Alt+Arrow` secondary) | TESTED |
| widget `goToTop/Bottom` (cHW :468,:472) | `scrollTop = 0` / `scrollHeight` | `HoverWidgetDom::go_to_top`/`go_to_bottom` (on `Home`/`End` + `CtrlCmd+Arrow` secondary) | TESTED |
| `Scroll/Page/GoTo*HoverAction` key bindings (ha :171-430) | arrow / page / home-end primaries + `Alt`/`CtrlCmd+Arrow` secondaries, `hoverFocused` | registered commands with Monaco's ids + keybinding rows (`hover_contribution.mbt`), gated on a live `hoverFocused` predicate; both keyboard owners resolve through the registry | PORTED (registry dispatch since deviations-closeout Track D) |
| `registerEditorContribution`/`registerEditorAction`/participant registry (hc :22-38) | wire commands + key bindings (same as Monaco) | contribution + scroll-cluster command registration through `editor_extensions.mbt` (deviations-closeout Track D); the remaining `registerEditorAction` rows (show/focus, verbosity) stay with their Phase 5/6 rows | PARTIAL (registry exists; scroll cluster + hideHover registered) |
| theming participant `editorHoverBorder` (hc :44-51) | `.hover-row` / `hr` borders | CSS (predecessor DOM plan) | PORTED |
| `ShowDefinitionPreviewHoverAction` (ha :109-150) | `goToDefinition` then `showContentHover` | — | DEFERRED (goToDefinition not ported) |
| `HIDE_LONG_LINE_WARNING_HOVER` command (hc :39-41) | toggle `editor.hover.showLongLineWarning` | — | DEFERRED (long-line warning unported) |
| `INCREASE/DECREASE_HOVER_VERBOSITY` ids + actions (hai :18-23, ha :432-472) | verbosity command set | — | DEFERRED (Phase 6) |
| `AccessibleViewRegistry.register` ×3 (hc :52-54) | accessible views | — | N-A (accessibility) |
| `status-bar` `append`/`addAction` accessible label paths | a11y text | — | N-A (accessibility) |

---

## Phase 6 — `markdownHoverParticipant.ts` verbosity cluster — TODO

Port `HoverVerbosityAction` end to end. Gated on Phase 4 (needs per-part identity)
and Phase 5 (needs the increase/decrease commands + ids).

### Inventory (Phase 6)

`markdownHoverParticipant.ts` verbosity cluster (slice):
- `MarkdownHover.supportsVerbosityAction` (:70) [Increase vs Decrease branch].
- `MarkdownHoverParticipant.doesMarkdownHoverAtIndexSupportVerbosityAction` (:219).
- `MarkdownHoverParticipant.updateMarkdownHoverVerbosityLevel` (:223).
- `MarkdownRenderedHoverParts._renderHoverExpansionAction` (:334) [increase/
  decrease icon, `actionEnabled`].
- `MarkdownRenderedHoverParts.updateMarkdownHoverPartVerbosityLevel` (:375)
  [supportsVerbosityAction guard].
- `MarkdownRenderedHoverParts.doesMarkdownHoverAtIndexSupportVerbosityAction`
  (:423).
- `MarkdownRenderedHoverParts._fetchHover` (:432) [`verbosityDelta = ±1`].
- `labelForHoverVerbosityAction` (:543).
- `HoverSource` type + verbosity icon CSS.
- `contentHoverRendered` verbosity index-mapping (already inventoried in Phase 4,
  DEFERRED there): `updateHoverVerbosityLevel` (:394),
  `doesHoverAtIndexSupportVerbosityAction` (:430),
  `_normalizedIndexToMarkdownHoverIndexRange`/`_findRangeOfMarkdownHoverParts`.

Member count (Phase 6): 9 (markdown) + 4 (rendered, transferred from Phase 4) =
**13**.

### Parity ledger (Phase 6)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol (target) | Status |
|---|---|---|---|
| `MarkdownHover.supportsVerbosityAction` (mhp :70-78) | Increase: `hover.canIncreaseVerbosity`; Decrease: `canDecreaseVerbosity` | `supports_verbosity_action` (new) | TODO |
| `_renderHoverExpansionAction` (mhp :334-373) | render +/− chevron; disabled if unsupported; click → command | `render_verbosity_action` (new) | TODO |
| `updateMarkdownHoverPartVerbosityLevel` (mhp :375-421) | guard `supportsVerbosityAction`; `_fetchHover`; re-render part | `update_verbosity_part` (new) | TODO |
| `_fetchHover` verbosity delta (mhp :432-...) | `verbosityDelta = Increase ? +1 : −1`; provider re-query | `fetch_hover_verbosity` (new) | TODO |
| `doesMarkdownHoverAtIndexSupportVerbosityAction` (mhp :219,:423) | per-index support query | `does_markdown_support_verbosity` (new) | TODO |
| `updateMarkdownHoverVerbosityLevel` (mhp :223) | participant entry point | participant verbosity API (new) | TODO |
| `labelForHoverVerbosityAction` (mhp :543) | Increase/Decrease label | `verbosity_action_label` (new) | TODO |
| `RenderedContentHoverParts.updateHoverVerbosityLevel` (rend :394-428) | resolve index range; re-render parts; focus; `onContentsChanged` | `rendered_update_verbosity` (new) | TODO |
| `_normalizedIndexToMarkdownHoverIndexRange`/`_findRangeOfMarkdownHoverParts` (rend :445-470) | global↔markdown index mapping | index-mapping helpers (new) | TODO |

---

## Phase 7 — glyph / margin hover chain (`glyphHoverComputer.ts` + `glyphHoverController.ts` + `glyphHoverWidget.ts`) — TODO

Gutter-diagnostic hovers. Independent of the content-hover phases; reuses the
Phase 1 sizing and Phase 2 operation. New files under `viewer/` (+ `viewer/hover/`
for the computer).

### Inventory (Phase 7)

`glyphHoverComputer.ts` (whole, 62 lines): `LaneOrLineNumber` type (:12),
`IHoverMessage` (:14), `GlyphHoverComputerOptions {lineNumber, laneOrLine}` (:18),
`GlyphHoverComputer.computeSync` (:30) [isLineHover branch; lane filter; empty
markdown skip].

`glyphHoverController.ts` (whole, 244 lines): `IHoverSettings` (:24),
`IHoverState {mouseDown}` (:30), `ID='editor.contrib.marginHover'` (:36), fields
(:38-49), constructor (:51), static `get` (:70), `_hookListeners` (:74, enabled-on
vs off binding sets), `_unhookListeners` (:102), `_cancelScheduler` (:106),
`_onEditorScrollChanged` (:111), `_onEditorMouseDown` (:117),
`_isMouseOnGlyphHoverWidget` (:126), `_onEditorMouseUp` (:134),
`_onEditorMouseLeave` (:138), `_shouldNotRecomputeCurrentHoverWidget` (:154),
`_onEditorMouseMove` (:160), `_reactToEditorMouseMove` (:174), `_tryShowHoverWidget`
(:200), `_onKeyDown` (:205), `hideGlyphHover` (:224), `_getOrCreateGlyphWidget`
(:231), `dispose` (:238).

`glyphHoverWidget.ts` (whole, 210 lines): `ID` (:21), `allowEditorOverflow` (:22),
fields (:24-33), constructor (:35), `dispose` (:63), `getId` (:69), `getDomNode`
(:73), `getPosition` (:77), `_updateFont` (:81), `_onModelDecorationsChanged`
(:87), `showsOrWillShow` (:96, GLYPH_MARGIN vs LINE_NUMBERS branch),
`_startShowingAt` (:109, same-line skip), `hide` (:122), `_withResult` (:132),
`_renderMessages` (:142), `_updateContents` (:159), `_showAt` (:165,
fixedOverflowWidgets branch + `constrainedTop` clamp), `_onMouseLeave` (:203).

Member count (Phase 7): 4 (computer) + 21 (controller) + 19 (widget) = **44**.

### Parity ledger (Phase 7)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol (target) | Status |
|---|---|---|---|
| `GlyphHoverComputer.computeSync` (ghc :30-61) | per line-decoration; `isLineHover` vs lane filter; skip empty markdown | `glyph_compute_sync` (new, `viewer/hover/`) | TODO |
| `GlyphHoverComputerOptions`/`LaneOrLineNumber`/`IHoverMessage` (ghc :12-21) | options + lane/line union | glyph hover types (new) | TODO |
| `GlyphHoverController._hookListeners` (ghcon :74-100) | enabled-on binds mouse/key; off binds move/key only; +leave/model/scroll | `GlyphHoverController::hook` (new) | TODO |
| controller mouse down/up/move/leave (ghcon :117-172) | mouseDown state; keep-on-widget; sticky-recompute skip | glyph mouse handlers (new) | TODO |
| `_reactToEditorMouseMove` (ghcon :174-198) | `shouldShowHover` gate; `_tryShowHoverWidget`; else hide | `glyph_react_to_mouse_move` (new) | TODO |
| `_onKeyDown` (ghcon :205-222) | onKeyboardModifier-trigger show; modifier-key keep; else hide | glyph keydown (new) | TODO |
| `_onEditorScrollChanged`/`hideGlyphHover`/`_getOrCreateGlyphWidget`/`dispose`/static `get`/`ID` (ghcon :70,:111,:224,:231,:238) | lifecycle + scroll-hide | glyph controller lifecycle (new) | TODO |
| `GlyphHoverWidget.showsOrWillShow` (ghw :96-107) | GLYPH_MARGIN+lane vs LINE_NUMBERS → `_startShowingAt` | `glyph_shows_or_will_show` (new) | TODO |
| `_startShowingAt` (ghw :109-120) | same line+lane skip; else cancel + start `Delayed` | `glyph_start_showing_at` (new) | TODO |
| `_withResult`/`_renderMessages`/`_updateContents` (ghw :132-163) | messages→markdown rows; hide if empty | glyph render (new) | TODO |
| `_showAt` (ghw :165-201) | `top = topForLine − scrollTop − (nodeH − lineH)/2`; `left = glyphMarginLeft + glyphMarginWidth + (lineNo ? lineNumbersWidth : 0)`; clamp `constrainedTop ∈ [0, editorH − nodeH]`; fixedOverflowWidgets → fixed vs absolute | `glyph_show_at` (new) | TODO |
| `_onModelDecorationsChanged` (ghw :87-94) | recompute on decoration change when visible | decoration-change handler (new) | TODO |
| `_onMouseLeave` (ghw :203-209) | hide if mouse outside editor | glyph mouse-leave (new) | TODO |
| `_updateFont`/`getId`/`getDomNode`/`getPosition`/`hide`/`dispose` (ghw :63-130) | overlay widget plumbing | glyph widget plumbing (new) | TODO |

---

## Deviations (Phase 3 of protocol — every non-source-cited line, justified)

Local seams (host/FFI/async/services) are expected; layout/geometry/timing math
is **not** and must trace to a source line.

1. **Non-overflowing widget → editor-box edges.** Monaco's
   `_availableVerticalSpaceBelow` measures to `body` height; the viewer hover
   lives inside `.overflow-guard`, so the port measures to the editor box
   (`editor_height − …`). `_findMaximumRenderingWidth` likewise caps to the editor
   **content area** (`width − contentLeft − 24`) instead of `body.width − 14`.
   Justification: genuine host difference (overflow container), not a math change.
   `allowEditorOverflow`/`suppressMouseDown` are therefore `N-A`.
2. **`did_resolve_hover` once per anchor.** The viewer's public hover-resolution
   status event fires once on operation completion
   (`maybe_notify_hover_resolved`), not per intermediate result. Justification:
   public-API ergonomics seam; the underlying `HoverOperation` transitions match
   source exactly.
3. **Host-driven schedulers.** Monaco's three `Debouncer`s
   (`RunOnceScheduler`) become viewer effects scheduled by `editor_events.mbt`;
   the wait-time arithmetic (`delay/2`, `delay−delay/2`, `3·delay`) is unchanged.
   Justification: no in-engine timer; effect indirection only.
4. **Instantiation / context-key / keybinding services.** Monaco threads
   `IInstantiationService`, `IContextKeyService`, `IKeybindingService`. The viewer
   uses direct construction + a `HoverParticipantServices` record + the
   contribution registry. Justification: no DI container; behavior preserved.
5. **Sashes / user resize deferred.** `_resize`, `_updateResizableNodeMaxDimensions`,
   `_updateMaxDimensions` (`max(h/4,250,last)` × `max(w·0.66,750,last)`),
   `_lastDimensions`, `enableSashes` are inventoried but `DEFERRED`. Justification:
   not needed for the sizing/clipping fix; tracked as an explicit follow-on, not
   an omission.

6. **Client- vs page-space pointer coordinates (Phase 3).** Monaco's
   `_isMouseOnContentHoverWidget` / `shouldShowHover` read `posx`/`posy` as page
   coordinates against `getDomNodePagePosition`. The viewer measures the widget
   with `getBoundingClientRect` and reads `clientX`/`clientY`, so both sides are
   client-space — a consistent pair, no math change. Justification: host
   measurement API, not geometry.
7. **Pointer recorded at the input bridge, not on the hit-target seam
   (Phase 3).** Monaco reads the modifier flags + position off the
   `IEditorMouseEvent`. The viewer's pointer-handler seam (`notify_mouse_moved`)
   carries only a hit `MouseTarget`, so `record_hover_pointer` snapshots the
   client position + modifiers in `viewer/input.mbt` before the move dispatches;
   the controller reads that snapshot (`_mouseMoveEvent` analog). Justification:
   seam shape, behavior preserved.
8. **`_onEditorMouseDown` fired independently of cursor placement (Phase 3).**
   Monaco's hover controller is a separate contribution that only decides the
   hide; the viewer previously folded an unconditional `dismiss_hover()` into
   `dispatch_mouse` (cursor placement). The port moves the hide to
   `Viewer::on_editor_mouse_down`, fired from the input bridge, so a press on the
   hover widget keeps it (`_shouldKeepHoverWidgetVisible`) and any editor press —
   not only ones that resolve a content target — hides. Justification: matches
   the source's contribution split; fixes a real keep-open gap.
9. **Hover config plumbing deferred (Phase 3).** `_hookListeners` snapshots
   `editor.getOption(EditorOption.hover)`; the viewer does not surface hover
   options, so `HoverSettings::defaults()` snapshots VS Code's defaults
   (`enabled:'on'`, `sticky:true`, `hidingDelay:300`) via the ported
   `from_config` resolvers. The live `onDidChangeConfiguration` re-hook and the
   `enabled:'off'` cancel path are therefore inert until hover options are
   modeled. Justification: option-model port is a separate unit; the snapshot +
   predicate logic is faithful and fully tested.
10. **`computeHoverPositions` seam (Phase 4, increment 1).** Monaco derives
    `startColumnBoundary` from the coordinates converter (view-line min column →
    model column); the viewer passes `1` (Monaco's no-model default) until the
    converter seam is threaded, and builds the `anchorRange` argument from the
    hover's single offset anchor (`hover.range.start`) as a zero-width range
    rather than a model `Range`. The per-part on-anchor-line clamp and
    `forceShowAtRange` branch are ported and tested but inert in the live path
    (no viewer participant sets `forceShowAtRange`, and the union-start anchor
    makes the clamp a no-op), so the wiring is behavior-neutral. Justification:
    coordinates-converter / single-offset-anchor seams; the arithmetic matches
    source line-for-line and is whitebox-tested across all branches.
11. **`isMouseGettingCloser` sticky keep + insist-update (Phase 4, increments 2 & 4).**
    Monaco's `_startShowingOrUpdateHover` sticky-getting-closer branch keeps the
    hover *and* kicks `_startHoverOperationIfNecessary(..., insistOnKeepingHoverVisible=true)`.
    Increment 2 landed the keep; increment 4 (after the reconciliation) moved the
    branch into the controller's `start_showing_or_update_hover` and kicks the
    `insist=true` operation, so an empty result for the approached anchor keeps
    the previous hover (`_withResult` `shouldKeepPreviousHoverVisible`) instead of
    hiding. The `sticky && isMouseGettingCloser` signal is measured once per
    reaction in `run_hover_react` (the host seam — DOM rect + the `sticky` option)
    and threaded into `on_event`. The deferred mouse-move runner fires
    `react_to_editor_mouse_move` (Monaco's `_reactToEditorMouseMoveRunner` →
    `_reactToEditorMouseMove`, re-gating `shouldShowHover` on the grace path).
    Justification: `sticky`/DOM-measurement are host concerns computed at the
    seam; the keep, insist-update, and empty-keep gating match source and are
    whitebox-tested, validated against the hover conformance specs.
12. **Reconciliation predicates in offset space (Phase 4, increment 3).**
    `HoverRangeAnchor.canAdoptVisibleHover` (same model line),
    `IHoverPart.isValidForHoverAnchor` (`startColumn <= anchor.startColumn &&
    endColumn >= anchor.endColumn`), and `ContentHoverResult.filter` come from
    the otherwise out-of-scope `hoverTypes.ts` / `contentHoverTypes.ts`; they are
    ported inline (`hover_anchor_can_adopt`, `hover_part_valid_for_anchor`,
    `filter_hover_parts`) using document **offsets** instead of line/column
    `Range`s, matching the viewer's offset-based hover anchor. The same-line
    comparison uses the anchor's model start line, resolved through the new
    `EditorContext.offset_to_model_line` seam (Monaco reads it off the
    `showAtPosition`). Justification: offset-vs-column is the viewer's data-model
    seam (single-line hover anchors make the two equivalent); the branch
    structure and containment test match source.
13. **Inline scroll-cluster dispatch, no command registry (Phase 5,
    increment 1) — CLOSED (deviations-closeout Track D, 2026-07-03): the
    eight actions and `hideHover` are registered editor commands with
    Monaco's ids and keybinding rows; `handle_hover_keydown` and the root
    keydown both resolve through the registry.** Original record: Monaco registers `Scroll{Up,Down,Left,Right}HoverAction`,
    `Page{Up,Down}HoverAction`, and `GoTo{Top,Bottom}HoverAction` as editor
    commands gated on the `hoverFocused` context key, each delegating to a
    `ContentHoverWidget` method. The viewer has no command/keybinding registry
    (the controller-contribution-registry inversion is the outstanding
    follow-up — Deviation 4), so the eight widget methods are ported faithfully
    but invoked from the focused hover widget's `keydown` handler
    (`handle_hover_keydown`) with Monaco's exact key map, including the `Alt+Arrow`
    page and `CtrlCmd+Arrow` edge secondaries. The `hoverFocused` precondition is
    implicit (the handler only fires when the widget — `tabIndex=0` — owns focus).
    The arithmetic itself is unchanged from source; the only behavioral change is
    replacing the old inline horizontal nudge (`4 × charWidth`, font-dependent)
    with Monaco's fixed `HORIZONTAL_SCROLLING_BY = 30`. Justification: command-bus
    seam; the methods and key bindings match source and are validated against the
    hover conformance specs.

Any new logic line added during Phases 4–7 that is **not** traceable to a cited
source line must be appended here before that phase's exit gate can be checked.

## Test matrix (Phase 4 of protocol)

Behavior-switching variables, with the combinations to cover (one case per
source branch, run across configs — single-config green is false confidence):

- **Phase 1/1b — sizing.** `{anchor near top, near bottom}` × `{content shorter
  than space, taller than space}` × `{content narrower than editor, wider than
  editor}` × `{hover.above true, false}`. The historically-missing cell —
  narrow-width × wide-content — is mandatory. Proven cells live in
  `tests/browser/conformance/monaco_hover_scrollbar.spec.js`.
- **Phase 2 — operation.** Each `HoverOperationState` transition (whitebox);
  `start(Delayed)` from Idle vs non-Idle; `start(Immediate)` from Idle vs
  SecondWait; async-completes-before-sync vs after; loading-message fires only
  from WaitingForAsync; `cancel` mid-flight token drop.
- **Phase 3 — controller.** `enabled ∈ {on, off, onKeyboardModifier}` ×
  `sticky ∈ {true, false}` × `hidingDelay ∈ {0, >0}`; mouse-down on widget vs
  outside; scroll-change hide; mouse-leave with keep-open flag; keydown
  trigger-modifier vs modifier-key vs Tab-while-focused; context-menu open
  suppresses then restores.
- **Phase 4 — wrapper/rendered.** `_startShowingOrUpdateHover` each of 7 branches;
  anchor `CONTENT_TEXT` vs `CONTENT_EMPTY` (within-epsilon vs beyond);
  `focus` with `hoverPartsCount` ∈ {1, >1}; `computeHoverPositions` with/without
  `forceShowAtRange`; per-part focus index round-trip.
- **Phase 5 — actions.** Each command (`scroll{Up,Down,Left,Right}`, `page{Up,
  Down}`, `goTo{Top,Bottom}`, `showHover`, `hideHover`) via its primary + secondary
  keybinding while `hoverFocused`; status-bar action invokes its command.
- **Phase 6 — verbosity.** `supportsVerbosityAction` Increase vs Decrease, enabled
  vs disabled; `index ≥ 0` (single part) vs `index < 0` (whole markdown range);
  `verbosityDelta` ±1 re-query.
- **Phase 7 — glyph.** `laneOrLine ∈ {lineNo, glyph lane}`; lane filter match vs
  mismatch; empty markdown skip; `_showAt` `fixedOverflowWidgets` true vs false;
  `constrainedTop` clamp at both edges; scroll-change hide.

Prefer porting any existing Monaco unit test per `docs/quality.md` "Conformance
ports". Whitebox cases use the `with_test_viewer` harness from
`headless-viewer-test-harness.md`.

## Exit gate (Phase 5 of protocol)

A phase is "1:1 done" only when all five boxes are checked and the
reconciliation counts are filled. `just check` / `just test` / `just test-browser`
green is **necessary, not sufficient**.

| Phase | Source unit(s) | Members | done / deferred / N-A | Inventory reconciled | Diff-reviewed | Matrix covered | Deviations logged | Self-audit pasted |
|---|---|---|---|---|---|---|---|---|
| 1/1b | resizable + cHW sizing | 23 | 9 / 11 / 3 | ☑ | ☑ | ☑ | ☑ | ☑ |
| 2 | hoverOperation | 23 | 23 / 0 / 0 | ☑ | ☑ | ☑ | ☑ | ☑ |
| 3 | controller + utils | 41 | 20 / 16 / 5 | ☑ | ☑ | ☑ | ☑ | ☑ |
| 4 | wrapper + rendered + cHW rest | 78 | 11 / TBD / TBD | ☐ | ☐ | ☐ | ☐ | ☐ |
| 5 | statusbar + actions + ids + contrib + scroll | ~65 | 9 (scroll cluster) / TBD / TBD | ☐ | ☐ | ☐ | ☐ | ☐ |
| 6 | markdown verbosity | 13 | 0 / 0 / 0 | ☐ | ☐ | ☐ | ☐ | ☐ |
| 7 | glyph chain | 44 | 0 / 0 / 0 | ☐ | ☐ | ☐ | ☐ | ☐ |

Per-phase exit checklist (repeat for each):

- [ ] **Inventory reconciled:** `count(ledger rows) == count(inventory members)`;
      report `done / deferred / N-A`.
- [ ] **Diff review:** every ported function read side-by-side vs its source;
      branch order, constants, early returns confirmed present.
- [ ] **Matrix coverage:** every behavior-switching variable/combination above has
      a test; harness run across configs (not one happy path).
- [ ] **Deviations documented:** every non-source-cited line listed + justified.
- [ ] **Closing self-audit:** re-read the source unit; confirm each member present
      and behavior-matching; paste the reconciliation here.

## Non-goals

- **Accessibility** — `hoverAccessibleViews.ts`, accessible widget content, aria
  hints, screen-reader hints, the `getAccessibleWidgetContent*` getters. Excluded.
- **Color-picker** participant and inline-completion hint interaction — separate
  contrib chains; port only if/when those features are pursued. The color-picker
  arms of `_shouldKeepCurrentHover` are inventoried as `N-A`.
- **`platform/hover` + `base/browser/ui/hover` workbench tooltip** service (hover
  delegates, `updatableHoverWidget`) — non-editor tooltip system.
- **Re-porting the DOM subtree or scrollbar visuals** — done and conformant under
  the two predecessor plans; this plan changes logic, not the target DOM.
- **`ShowDefinitionPreviewHover`** and **long-line-warning** — depend on
  goToDefinition / a config flag not yet ported; `DEFERRED` rows in Phase 5.
