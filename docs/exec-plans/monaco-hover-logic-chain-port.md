# Monaco Hover Logic-Chain 1:1 Port

Status: proposed — Date: 2026-06-29.

Follows the two implemented hover plans, which this supersedes only for the
**logic chain** (controller / widget sizing / operation / rendered parts /
actions). Do not rewrite either:

- `monaco-exact-hover-widget.md` — ported the hover **DOM subtree** and the
  shared `.monaco-scrollable-element` family.
- `monaco-hover-scrollbar-conformance.md` — proved **DOM/CSS/scrollbar**
  conformance against a local Monaco reference fixture.

Oracle: `vscode` submodule, `src/vs/editor/contrib/hover/browser/*` (plus the
`resizableContentWidget.ts` base). Product code must not import from `vscode/`
or `codemirror/`; the target is to port behavior, constants, and state
transitions into locally owned MoonBit.

## Problem

The earlier plans made the hover *look* and *scroll* like Monaco, but only a
thin slice of Monaco's hover **logic** was ported. The widget does not know its
own placement geometry, the timing is a hand-rolled approximation of
`HoverOperation`, and the controller is missing most of Monaco's interaction
settings. The chain is "`ContentHoverWidget` minus its `ResizableContentWidget`
base, minus `HoverOperation`, minus most of `ContentHoverController`."

The concrete symptom already observed: in a small window a hover renders
truncated with **no scrollbar to recover the hidden part**. Root cause is the
missing available-space port — `HoverWidgetDom::apply_sizing`
(`viewer/content_widgets.mbt:447`) caps `max-height` at `max(80, rootHeight−24)`
(the whole editor), not at the space available above/below the anchor line, so
the `overflow:auto` scrollbar never engages and `.overflow-guard`
(`viewer/editor.css:13`) clips the spill. That bug is a *symptom* of Phase 1
below, not a one-off.

## Current port status (what exists vs. what's missing)

| Monaco file | MoonBit today | Gap |
|---|---|---|
| `contentHoverComputer.ts` | `hover/hover_participants.mbt` `ContentHoverComputer` | ✅ parts + ordering |
| `hoverTypes.ts` (participant iface + registry) | `hover_participants.mbt` + `hover/hover_registry.mbt` | 🟡 no `renderHoverParts` / `handleResize` / `handleScroll` / verbosity hooks |
| `markdownHoverParticipant.ts` | `MarkdownHoverParticipant` | 🟡 parts only |
| `markerHoverParticipant.ts` | `MarkerHoverParticipant` | 🟡 parts only; status bar is static HTML |
| `hoverOperation.ts` | `hover_controller.mbt` `HoverOperation` | 🟡 5-state machine + 3 schedulers + streamed async ported (Phase 2); immediate mode = synchronous triggers (product trigger lands with Phase 5) |
| `contentHoverController.ts` | `hover_controller.mbt` `HoverController` | 🟡 no sticky / enablement modes / trigger-modifier / mouse-down keep / scroll-hide / resizing-keep / context-menu |
| `contentHoverWidgetWrapper.ts` | split across `hover_controller.mbt` + `content_widgets.mbt` | 🟡 no focus-part nav / verbosity / color-picker / participant resize+scroll fan-out |
| `contentHoverWidget.ts` | `content_widgets.mbt` `HoverWidgetDom` | 🟡 available-space sizing ported (Phase 1); no resize, no min/max dims, no `_lastDimensions` |
| `resizableContentWidget.ts` | `content_widgets.mbt` hover sizing helpers | 🟡 available-space + position preference ported (Phase 1); sashes deferred |
| `contentHoverRendered.ts` | `hover/hover_render.mbt` (HTML string) | 🟡 no per-part focus/nav, no per-part highlight decorations |
| `contentHoverStatusBar.ts` | static HTML in `hover_render.mbt` | ❌ no real actions |
| `hoverCopyButton.ts` | `hover_render.mbt` + `handle_hover_copy_click` | 🟡 partial |
| `getHover.ts` | `languages.hover_at` | 🟡 partial |
| `hoverActions.ts` / `hoverActionIds.ts` | inline `handle_hover_keydown` (`content_widgets.mbt:344`) | 🟡 scroll/page/home/end behavior only; not registered commands; no keyboard-triggered `showHover`; no verbosity |
| `hoverContribution.ts` | — | ❌ no contribution registration concept |
| `glyphHover{Controller,Widget,Computer}.ts` | — | ❌ entire margin/gutter-diagnostic hover chain absent |

## Parity ledger (logic chain)

Source-first record of the ported methods: the Monaco source location, the exact
arithmetic, and the MoonBit symbol it now lives next to. Statuses: `TODO` /
`PORTED` (code matches source) / `TESTED` (whitebox/oracle/browser proof) /
`PASS` (proof green).

### Phase 1 — available-space sizing

Oracle commit pinned at `294fb350837dbaee37b949533fead4df4e0e8971`. Constants
`TOP_HEIGHT = 30`, `BOTTOM_HEIGHT = 24` from `resizableContentWidget.ts:13-14`.
The viewer hover is **non-overflowing** (lives in `.overflow-guard`), so the
available-space edges are the *editor* box, not the page body as in Monaco.

| Monaco method (source) | Arithmetic | MoonBit symbol | Status |
|---|---|---|---|
| `_availableVerticalSpaceAbove` (`resizableContentWidget.ts:64-72`) | `editorBox.top + mouseBox.top − TOP_HEIGHT` → editor-relative `line_top − 30` | `hover_available_space_above` (`content_widgets.mbt`) | TESTED |
| `_availableVerticalSpaceBelow` (`resizableContentWidget.ts:74-84`) | `bodyBox.height − (editorBox.top + mouseBox.top + mouseBox.height) − BOTTOM_HEIGHT` → editor-relative `editor_height − (line_top + line_height) − 24` | `hover_available_space_below` | TESTED |
| `_findMaximumRenderingHeight` (`contentHoverWidget.ts:189-200`) | `Math.min(availableSpace, contentHeight)` | `hover_maximum_rendering_height` | TESTED |
| `_findPositionPreference` (`resizableContentWidget.ts:86-103`) | `maxAbove=min(spaceAbove,h)`, `maxBelow=min(spaceBelow,h)`, `maxHeight=min(max(maxAbove,maxBelow),h)`, `height=min(h,maxHeight)`; `above` default → `ABOVE` iff `height≤maxAbove`, else by `maxBelow` | `hover_prefer_above` (+ `hover_prefer_above_default = true`) | TESTED |
| `ContentHoverWidget.show` height-cap apply (`contentHoverWidget.ts:336-362`) | render → measure natural height → pick side → cap `.monaco-hover-content` `max-height` to chosen-side space | `HoverWidgetDom::apply_sizing` / measurement pass in `render_hover_widget` | TESTED |

Deferred to a Phase 1 follow-on: resizable sashes / user drag
(`_resize`, `_updateResizableNodeMaxDimensions`, `_lastDimensions`,
`_updateMaxDimensions`) — not needed for the sizing/clipping bug fix.

The available-space cap (`_findMaximumRenderingHeight` =
`min(availableSpaceBelow, contentHeight)`, replacing the buggy
`Math.max(80, clientHeight − 24)`) is verified directly against the real editor
by the `tall hover is capped to the available space and stays fully scrollable`
case in `tests/browser/conformance/monaco_hover_scrollbar.spec.js`.

#### Phase 1b — available-width cap (horizontal counterpart)

Same bug class as the height cap, on the horizontal axis: a hover wider than the
editor renders with its leading text clipped and unreachable. Two gaps were
closed in `content_widgets.mbt`:

| Monaco method (source) | Arithmetic | MoonBit symbol | Status |
|---|---|---|---|
| `_setHoverWidgetMaxDimensions` `--vscode-hover-maxWidth` (`contentHoverWidget.ts:153`) | set the CSS custom property the markdown `.hover-contents` `max-width` reads, so it caps to the available width instead of the 500px default | `hover_width_style` (sets `--vscode-hover-maxWidth` alongside `max-width`) | TESTED |
| `_findMaximumRenderingWidth` (content-relative) (`contentHoverWidget.ts:217-235`) | cap to the editor **content area** (`width − contentLeft − 24`), not the whole editor box, so the right-aligned `shift_left` cannot push the widget left into the line-number gutter where the margin overlays clip it | `hover_available_width` (takes `gutter_width`) | TESTED |

Verified by the `wrappable hover content is capped to the editor content area in
a narrow window` case in `tests/browser/conformance/monaco_hover_scrollbar.spec.js`
(520px window: content wraps with no horizontal overflow, widget stays right of
the gutter and inside the editor's right edge).

### Phase 2 — HoverOperation

`hoverOperation.ts` ported into `hover_controller.mbt` as a pure `HoverOperation`
(state + token + accumulating `parts` + `async_done`); the viewer
(`editor_events.mbt`) drives the schedulers and the sync/async computes.

| Monaco method (source) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `HoverOperationState` (`hoverOperation.ts:25-31`) | Idle / FirstWait / SecondWait / WaitingForAsync / WaitingForAsyncShowingLoading | `HoverOpState` | TESTED |
| `_firstWaitTime` / `_secondWaitTime` / `_loadingMessageTime` (`:98-108`) | `delay/2` / `delay − delay/2` / `3·delay` | `hover_first_wait_ms` / `hover_second_wait_ms` / `hover_loading_message_ms` | TESTED |
| `start(Delayed)` (`:171-177`) | Idle→FirstWait; schedule async@first, loading@loading | `start_delayed` + `apply_hover_effect`(`HoverScheduleDelayed`) | TESTED |
| `start(Immediate)` (`:178-190`) | run async-trigger + sync-trigger synchronously (no waits) | `op_trigger_async` + `op_trigger_sync` invoked back to back (wbtest) | TESTED |
| `_triggerAsyncComputation` (`:116-146`) | →SecondWait; schedule sync@second; kick streamed `computeAsync` | `op_trigger_async` + `hover_trigger_async` + `kick_hover_async` + `compute_async_each` | TESTED |
| `_triggerSyncComputation` (`:148-153`) | `result += computeSync`; `asyncDone ? Idle : WaitingForAsync` | `op_trigger_sync` + `compute_hover_sync` | TESTED |
| `_triggerLoadingMessage` (`:155-159`) | WaitingForAsync→WaitingForAsyncShowingLoading | `op_trigger_loading` | TESTED |
| async item / `_asyncIterableDone` (`:124-145`) | push each item + re-fire; on done, complete to Idle | `op_async_item` / `op_async_done` | TESTED |
| `_fireResult` (`:161-169`) | suppress during FirstWait/SecondWait; else emit `{value, isComplete, hasLoadingMessage}` | `HoverController::emit` (+ `is_complete`) | TESTED |
| `cancel()` (`:193-204`) | drop result, reset Idle (token rotation drops in-flight) | `HoverController::cleared` | TESTED |

Deviation: the viewer's hover-resolution status event (`did_resolve_hover`,
public API) now fires exactly once per anchor when the operation completes
(`maybe_notify_hover_resolved`), replacing the old per-result notification.
Immediate mode's *product* trigger (keyboard/click `showHover`) is defined in
Phase 5; the operation already supports it (the same triggers, no schedulers).

## Ownership boundary to respect

The `@hover` sub-package (`viewer/hover/`) is pure data + render: participants,
computer, and part→HTML rendering. The viewer core (`viewer/`) owns the
controller state machine and the widget DOM. Keep that split: geometry/sizing
and interaction land in `viewer/`; part structure and rendering land in
`viewer/hover/`. The hover package must not gain a dependency on viewer-core
`ViewerServices` (it already takes a `HoverParticipantServices` record).

## Plan

Phases are in dependency order. Each phase is independently shippable and
verifiable; Phase 1 is the only one that also fixes a known bug, so it goes
first.

**Phase 0 — Inventory + oracle ledger (no product change). — DONE** (see
"Parity ledger (logic chain)" above). For each Monaco
method this plan ports, record the source location, the exact arithmetic
(`TOP_HEIGHT`/`BOTTOM_HEIGHT` constants in `resizableContentWidget.ts`, the
`Math.max(layoutInfo.height/4, 250, …)` in `contentHoverWidget._updateMaxDimensions`,
the `_findPositionPreference` comparison), and the corresponding MoonBit symbol
it will live next to. Drop this as a parity ledger at the top of the conformance
spec so the port is source-first, not eyeballed. Confirm the seams in
`content_widgets.mbt` (`render_hover_widget`, `apply_sizing`, the read-after-write
measure block at `content_widgets.mbt:229`) and the anchor data the widget
already has (`line_col_for_offset`).

**Phase 1 — `resizableContentWidget` + available-space sizing (fixes the bug).
— DONE (sashes deferred).** Ported into `viewer/content_widgets.mbt` (new
helpers, viewer-core-owned):
- `_availableVerticalSpaceAbove/Below(position)` — distance between the anchor
  line box and the editor/viewport edge, minus `TOP_HEIGHT`/`BOTTOM_HEIGHT`.
- `_findMaximumRenderingHeight()` = `min(availableSpace, contentHeight)`.
- `_findPositionPreference(widgetHeight, position)` — choose ABOVE/BELOW by which
  side fits / has more room, honoring the `hover.above` preference; replaces the
  current "flip only if it spilled off the top" test (`content_widgets.mbt:233`).
- Rework `apply_sizing` so `max-height` is the chosen side's available space (not
  `rootHeight−24`), so the `.monaco-hover-content` `overflow:auto` + custom
  scrollbar engages instead of `.overflow-guard` clipping.

Verify directly against the real editor: a small-window case (anchor near top
and near bottom) in `tests/browser/conformance/monaco_hover_scrollbar.spec.js`
asserts the scrollbar becomes visible and full content is reachable by scroll.
(There is no Monaco reference page to keep in sync — the removed oracle used to
mirror the *buggy* `Math.max(80, clientHeight−24)`; the port is now proven by
the real-editor browser test alone.)

Resizable sashes (user drag-resize) are in scope as a follow-on sub-step but may
land after the sizing fix, since the bug fix does not need drag.

**Phase 2 — Faithful `HoverOperation`. — DONE (immediate-mode product trigger
deferred to Phase 5).** Port the
`Idle → FirstWait → SecondWait → WaitingForAsync → WaitingForAsyncShowingLoading`
state machine and its three debounced schedulers (firstWait = delay/2,
secondWait = delay − firstWait, loadingMessage = 3×delay), plus `computeSync`
(at secondWait) vs streamed `computeAsync` results that fire incrementally, plus
`HoverStartMode.Immediate`. Replace the ad-hoc half/full/triple timing in
`hover_controller.mbt`. Keep the existing `keep_hover_open` grace integration.

**Phase 3 — `contentHoverController` interactions.** Port the editor-contribution
behaviors currently absent: `hover.enabled` (`on`/`off`/`onKeyboardModifier`),
`hover.sticky`, `hidingDelay` grace already partially present, trigger-modifier
gating (`shouldShowHover` / `isTriggerModifierPressed` from `hoverUtils.ts`),
mouse-down keep-visible (`_shouldKeepHoverWidgetVisible`), keep-open while
resizing or focused, hide on scroll-change, and context-menu open/close
suppression. These thread through `viewer/hover_controller.mbt` and its
`EditorEvent` inputs.

**Phase 4 — `contentHoverWidgetWrapper` + `RenderedContentHover` structure.**
Give rendered parts real structure instead of one HTML blob: a
`RenderedContentHover` analog that owns per-part nodes, supports
`focusedHoverPartIndex` / `focusHoverPartWithIndex`, applies per-part
`has-hover` highlight decorations (today the controller emits one combined
range, `hover_controller.mbt:258`), and fans `onDidResize` / `onDidScroll` /
`onContentsChanged` out to participants. Rendering stays in `viewer/hover/`; the
node-ownership/focus wiring is viewer-core.

**Phase 5 — Status bar actions + hover editor commands.** Replace the static
"View Problem" markup (`hover/hover_render.mbt:75`) with a real
`EditorHoverStatusBar` analog whose actions invoke commands (marker → reveal /
quick-fix where those services exist; otherwise wire the no-op-safe subset).
Register the `hoverActionIds.ts` command set as real editor commands —
`scrollUp/Down/Left/Right`, `pageUp/Down`, `goToTop/Bottom`, keyboard-triggered
`showHover`, `hideHover` — replacing the inline-only `handle_hover_keydown`
behavior with command-backed handlers (keep the same key bindings).

**Phase 6 — Verbosity.** Port `HoverVerbosityAction` end to end:
`doesHoverAtIndexSupportVerbosityAction`, `updateHoverVerbosityLevel`, the
increase/decrease commands, and the markdown participant's verbosity support.
Gated on Phase 4 (needs per-part identity).

**Phase 7 — Glyph / margin hover chain.** Port
`glyphHoverComputer` + `glyphHoverController` + `glyphHoverWidget` for
gutter-diagnostic hovers. Independent of the content-hover phases; reuses the
Phase 1 sizing and Phase 2 operation. New files under `viewer/` (+ `viewer/hover/`
for the computer).

## Verification

- `just test-moon` (js target) stays green; new whitebox tests cover the
  available-space arithmetic (Phase 1), the operation state transitions
  (Phase 2), and the controller settings matrix (Phase 3) headlessly — ideally
  via the `with_test_viewer` harness from `headless-viewer-test-harness.md`.
- The Phase 1 small-window case in `monaco_hover_scrollbar.spec.js` *fails*
  against the old `apply_sizing` and *passes* after the port, proving the
  scrollbar engages and full content is reachable.
- Each phase extends the parity ledger; a phase is done only when its ported
  methods match the oracle's arithmetic/transitions, not when class names match
  (per the conformance-plan rule).

## Non-goals

- **Accessibility** — `hoverAccessibleViews.ts`, accessible widget content, aria
  hints, screen-reader hints. Explicitly excluded from this plan.
- Color-picker participant and inline-completion hint interaction — separate
  contrib chains; port only if/when those features are pursued.
- The generic `platform/hover` + `base/browser/ui/hover` workbench **tooltip**
  service (hover delegates, `updatableHoverWidget`). That is the non-editor
  tooltip system; out of scope for the editor hover chain.
- Re-porting the DOM subtree or scrollbar visuals — already done and conformant
  under the two predecessor plans; this plan changes logic, not the target DOM.
