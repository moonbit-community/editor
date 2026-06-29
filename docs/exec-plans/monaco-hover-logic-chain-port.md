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
| `hoverOperation.ts` | hand-rolled timers in `hover_controller.mbt` | 🟡 no incremental async streaming, no immediate mode, different state shape |
| `contentHoverController.ts` | `hover_controller.mbt` `HoverController` | 🟡 no sticky / enablement modes / trigger-modifier / mouse-down keep / scroll-hide / resizing-keep / context-menu |
| `contentHoverWidgetWrapper.ts` | split across `hover_controller.mbt` + `content_widgets.mbt` | 🟡 no focus-part nav / verbosity / color-picker / participant resize+scroll fan-out |
| `contentHoverWidget.ts` | `content_widgets.mbt` `HoverWidgetDom` | 🟡 no available-space sizing, no resize, no min/max dims, no `_lastDimensions` |
| `resizableContentWidget.ts` | — | ❌ not ported (available-space, position preference, sashes) |
| `contentHoverRendered.ts` | `hover/hover_render.mbt` (HTML string) | 🟡 no per-part focus/nav, no per-part highlight decorations |
| `contentHoverStatusBar.ts` | static HTML in `hover_render.mbt` | ❌ no real actions |
| `hoverCopyButton.ts` | `hover_render.mbt` + `handle_hover_copy_click` | 🟡 partial |
| `getHover.ts` | `languages.hover_at` | 🟡 partial |
| `hoverActions.ts` / `hoverActionIds.ts` | inline `handle_hover_keydown` (`content_widgets.mbt:344`) | 🟡 scroll/page/home/end behavior only; not registered commands; no keyboard-triggered `showHover`; no verbosity |
| `hoverContribution.ts` | — | ❌ no contribution registration concept |
| `glyphHover{Controller,Widget,Computer}.ts` | — | ❌ entire margin/gutter-diagnostic hover chain absent |

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

**Phase 0 — Inventory + oracle ledger (no product change).** For each Monaco
method this plan ports, record the source location, the exact arithmetic
(`TOP_HEIGHT`/`BOTTOM_HEIGHT` constants in `resizableContentWidget.ts`, the
`Math.max(layoutInfo.height/4, 250, …)` in `contentHoverWidget._updateMaxDimensions`,
the `_findPositionPreference` comparison), and the corresponding MoonBit symbol
it will live next to. Drop this as a parity ledger at the top of the conformance
spec so the port is source-first, not eyeballed. Confirm the seams in
`content_widgets.mbt` (`render_hover_widget`, `apply_sizing`, the read-after-write
measure block at `content_widgets.mbt:229`) and the anchor data the widget
already has (`line_col_for_offset`).

**Phase 1 — `resizableContentWidget` + available-space sizing (fixes the bug).**
Port into `viewer/content_widgets.mbt` (new helpers, viewer-core-owned):
- `_availableVerticalSpaceAbove/Below(position)` — distance between the anchor
  line box and the editor/viewport edge, minus `TOP_HEIGHT`/`BOTTOM_HEIGHT`.
- `_findMaximumRenderingHeight()` = `min(availableSpace, contentHeight)`.
- `_findPositionPreference(widgetHeight, position)` — choose ABOVE/BELOW by which
  side fits / has more room, honoring the `hover.above` preference; replaces the
  current "flip only if it spilled off the top" test (`content_widgets.mbt:233`).
- Rework `apply_sizing` so `max-height` is the chosen side's available space (not
  `rootHeight−24`), so the `.monaco-hover-content` `overflow:auto` + custom
  scrollbar engages instead of `.overflow-guard` clipping.

Update the **conformance oracle** in parallel: `tests/reference/monaco-hover-scrollbar/conformance-oracle.js:311-312`
currently mirrors the *buggy* `Math.max(80, clientHeight−24)`. It must port the
real `_findMaximumRenderingHeight` so the oracle stops blessing the bug. Add a
small-window case (anchor near top and near bottom) to
`tests/browser/conformance/monaco_hover_scrollbar.spec.js` that asserts the
scrollbar becomes visible and full content is reachable by scroll.

Resizable sashes (user drag-resize) are in scope as a follow-on sub-step but may
land after the sizing fix, since the bug fix does not need drag.

**Phase 2 — Faithful `HoverOperation`.** Port the
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
- The Phase 1 oracle update makes `monaco_hover_scrollbar.spec.js` *fail* against
  the old `apply_sizing` and *pass* after the port; the new small-window case
  proves the scrollbar engages and full content is reachable.
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
