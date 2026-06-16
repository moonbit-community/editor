# Monaco Hover and Scrollbar Parity

Status: implemented.
Reference: VS Code submodule `294fb350837dbaee37b949533fead4df4e0e8971`.
Plan: `docs/exec-plans/monaco-hover-scrollbar-conformance.md`.

This ledger tracks the readonly viewer's hover and scrollbar conformance work.
The oracle fixture under `tests/reference/monaco-hover-scrollbar/` transcribes
the pinned Monaco DOM, CSS, and geometry constants named below so Playwright can
compare the same states against the MoonBit viewer without importing product
code from `vscode/`.

## Source Summary

- `scrollbars.css:12-28`: visible scrollbars use `opacity: 1`, transparent
  click background, `transition: opacity 100ms linear`, and `z-index: 11`;
  invisible scrollbars keep their DOM node, use `opacity: 0`, disable pointer
  events, and add `fade` for an `800ms` opacity transition.
- `scrollbars.css:35-65`: scroll shadows are separate `.shadow` nodes with
  `.top`, `.left`, and `.top-left-corner` classes.
- `scrollbars.css:67-81`: rails and sliders use
  `--vscode-scrollbar-background`, `--vscode-scrollbarSlider-background`,
  hover background, and active background.
- `editorOptions.ts:4164-4178`: editor defaults are vertical/horizontal
  `auto`, `arrowSize: 11`, no arrows, `horizontalScrollbarSize: 12`,
  `verticalScrollbarSize: 14`, `alwaysConsumeMouseWheel: true`, and
  `scrollByPage: false`.
- `scrollbarState.ts:6-9,125-155`: minimum slider size is `20px`; available
  range is `visibleSize - oppositeScrollbarSize`; the thumb position is rounded
  from the scroll ratio.
- `abstractScrollbar.ts:224-230`: track clicks use centered thumb jumps when
  `scrollByPage` is false and page jumps only when it is true.
- `abstractScrollbar.ts:244-273`: thumb drag toggles `.active`, maps pointer
  delta through scrollbar state, and clears active state on drag end.
- `scrollableElement.ts:231-251,582-592`: the scrollable element owns horizontal
  and vertical scrollbar nodes plus optional shadow nodes.
- `hoverWidget.css:6-18,29-40,63-113`: hover container positioning, fade,
  content padding, markdown width, code font, and tokenized source whitespace.
- `hover.css:10-29,39-47,83-121`: resizable hover border/background, hover row
  layout, status/action row background, copy button position, opacity, focus,
  and icon sizing.
- `contentHoverWidget.ts:66-77,307-311,406-426`: content hover minimum size is
  `150px` by line-height plus 8; max size is at least one quarter editor height
  or `250px`, and at least two thirds editor width or `750px`; content changes
  relayout the scrollable element.
- `resizableContentWidget.ts:13-14,64-103`: above/below placement reserves
  `30px` above and `24px` below and enables sashes according to placement.
- `contentHoverStatusBar.ts:32-35` and `hoverCopyButton.ts:29-38`: status bars
  and copy buttons are regular hover rows/actions when Monaco renders them.
- `markdownHoverParticipant.ts:514-533`: markdown hover DOM is
  `.hover-row > .hover-row-contents > .markdown-hover > .hover-contents`.

## Ledger

| Area | Monaco source | Local implementation | Evidence | Status |
| --- | --- | --- | --- | --- |
| Scrollbar DOM | `scrollableElement.ts`, `abstractScrollbar.ts` | `renderer/browser/scrollable_element.mbt`, `app/src/style.css` | `tests/browser/monaco_conformance.spec.js` compares scrollbar nodes, roles, aria attributes, sliders, and shadows; `just test-browser` passed. | PASS |
| Scrollbar visibility | `scrollbarVisibilityController.ts`, `scrollbars.css` | `renderer/browser/scrollable_element.mbt`, `app/src/style.css` | Conformance measurement checks opacity, pointer-events, transition, and visible/invisible/fade classes; `just test-browser` passed. | PASS |
| Scrollbar default options | `editorOptions.ts` | `renderer/browser/view.mbt`, `renderer/browser/scrollable_element.mbt` | Ledger constants plus conformance measurement check 14px vertical, 12px editor horizontal, no arrows, and centered track jumps; `just test-browser` passed. | PASS |
| Scrollbar rail/thumb CSS | `scrollbars.css`, theme variables | `app/src/style.css` | Computed-style comparison in conformance spec for background, hover/active classes, z-index, transition; `just test-browser` passed. | PASS |
| Scrollbar thumb geometry | `scrollbarState.ts`, vertical/horizontal scrollbar files | `renderer/view_layout/scrollbar_state.mbt`, `renderer/browser/scrollable_element.mbt` | `renderer/view_layout/scrollbar_state_test.mbt` plus conformance checks for track length, thumb size, and thumb position tolerance; `just test` and `just test-browser` passed. | PASS |
| Track click | `abstractScrollbar.ts` | `renderer/browser/scrollable_element.mbt`, `renderer/browser/input.mbt` | Conformance spec clicks track and verifies centered-thumb scroll result. | PASS |
| Thumb drag | `abstractScrollbar.ts` | `renderer/browser/input.mbt` | `scroll.spec.js` covers drag behavior and active slider cleanup; `just test-browser` passed. | PASS |
| Wheel handling | `scrollableElement.ts` | `renderer/browser/input.mbt`, `renderer/browser/scrollable_element.mbt` | `scroll.spec.js`, `hover.spec.js`, and conformance wide-hover wheel containment checks passed. | PASS |
| Scroll shadows | `scrollbars.css`, `scrollableElement.ts` | `renderer/browser/scrollable_element.mbt`, `app/src/style.css` | Conformance measurement checks shadow node classes before and after scrolling; `just test-browser` passed. | PASS |
| Hover outer wrapper | `contentHoverWidget.ts`, `resizableContentWidget.ts` | `renderer/browser/content_widgets.mbt`, `app/src/style.css` | Conformance spec checks `.monaco-resizable-hover > .monaco-hover` structure and wrapper styles; `just test-browser` passed. | PASS |
| Hover container CSS | `hover.css`, `hoverWidget.css` | `app/src/style.css` | Computed-style comparison in conformance spec for border, radius, colors, shadow, font, overflow, and focus outline; `just test-browser` passed. | PASS |
| Hover placement | `resizableContentWidget.ts`, `contentHoverWidget.ts` | `renderer/browser/content_widgets.mbt` | Hover placement measurement flips below and shifts from the right edge; focused hover and conformance specs passed. | PASS |
| Hover sizing | `contentHoverWidget.ts` | `renderer/browser/content_widgets.mbt`, `app/src/style.css` | Conformance spec checks min/max dimensions for standard payloads and custom hover scrollbars; `just test-browser` passed. | PASS |
| Hover content rows | `hover.css`, `contentHoverRendered.ts` | `renderer/browser/hover_render.mbt`, `app/src/style.css` | `hover.spec.js`, `hover_render_wbtest.mbt`, and conformance shared payload DOM checks passed. | PASS |
| Hover status/actions | `contentHoverStatusBar.ts`, `hover.css`, `markerHoverParticipant.ts` | `language/providers.mbt`, `renderer/browser/hover_render.mbt`, `app/src/style.css` | Marker hover payload renders the Monaco status row/action and conformance compares row classes/action text; `just test-browser` passed. | PASS |
| Hover copy button | `hoverCopyButton.ts`, `hover.css`, `contentHoverRendered.ts` | `renderer/browser/hover_render.mbt`, `renderer/browser/content_widgets.mbt`, `app/src/style.css` | Marker hover payload renders the copy affordance, delegates copy clicks, and conformance compares/clicks both oracle and viewer buttons; `just test-browser` passed. | PASS |
| Hover scrollbars | `HoverWidget`, `scrollableElement.ts`, `scrollbars.css` | `renderer/browser/content_widgets.mbt`, `renderer/browser/scrollable_element.mbt` | `hover.spec.js` and conformance tests check native scrollbar hiding, custom bars, and wheel containment; `just test-browser` passed. | PASS |
| Hover keyboard | `contentHoverWidget.ts` | `renderer/browser/content_widgets.mbt` | `hover.spec.js` covers Escape/Home; conformance spec covers Arrow/Page/Home/End. | PASS |
| Markdown/fenced code | `markdownHoverParticipant.ts`, `hoverWidget.css` | `renderer/browser/hover_render.mbt`, `app/src/style.css` | `hover.spec.js` and conformance shared payloads cover paragraphs, lists, inline code, links, and wide fenced code; `just test-browser` passed. | PASS |
| Accessibility | Monaco hover and scrollbar sources | `renderer/browser/scrollable_element.mbt`, `renderer/browser/content_widgets.mbt`, `renderer/browser/hover_render.mbt` | Conformance measurement checks role, tabindex, aria-hidden, and copy button accessible label; `just test-browser` passed. | PASS |

## Deferred

No deferred rows.
