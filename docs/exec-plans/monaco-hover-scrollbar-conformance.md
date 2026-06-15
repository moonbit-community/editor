# Monaco Hover and Scrollbar Conformance

Status: implemented.
Date: 2026-06-15

## Summary

Make the readonly editor hover widget and scrollbar behavior match Monaco one to
one for the readonly surface this project exposes. This plan supersedes the
implemented `monaco-exact-hover-widget.md` follow-up without rewriting it. The
previous plan moved the implementation to Monaco-shaped DOM and shared
scrollable-element code, but the live UI still diverges in visible scrollbar
behavior, hover sizing, hover affordances, and interaction polish.

This is a conformance plan, not a feature-shape plan. It is not complete when
the DOM has Monaco-like class names. It is complete only when a Playwright-driven
comparison against a local Monaco reference fixture proves that DOM subtree,
computed styles, geometry, visibility transitions, pointer/keyboard behavior,
and screenshots match Monaco within the tolerances listed in the parity ledger.

The implementation loop for this plan is source-ledger first, failing oracle
second, product port third, proof last. Agents executing this plan must not copy
visible DOM and CSS in isolation, because Monaco's final behavior also depends
on TypeScript layout code, CSS variables, measured scroll dimensions, runtime
class transitions, and widget-specific event handling.

Product code still must not import from `vscode/` or `codemirror/`. The target
is to port Monaco behavior, DOM subtree, CSS rules, constants, and state
transitions into locally owned MoonBit and CSS code.

## Pinned Reference

Use the checked-out VS Code submodule at commit:

```text
294fb350837dbaee37b949533fead4df4e0e8971
```

Do not silently update the reference commit while executing this plan. If the
submodule changes, either reset to the pinned commit for this work or create a
new plan/addendum that records the new commit and explains why the oracle
changed.

Reference files the implementing agent must read before editing product code:

- `vscode/src/vs/base/browser/ui/scrollbar/media/scrollbars.css`
- `vscode/src/vs/base/browser/ui/scrollbar/scrollableElement.ts`
- `vscode/src/vs/base/browser/ui/scrollbar/scrollbarVisibilityController.ts`
- `vscode/src/vs/base/browser/ui/scrollbar/abstractScrollbar.ts`
- `vscode/src/vs/base/browser/ui/scrollbar/verticalScrollbar.ts`
- `vscode/src/vs/base/browser/ui/scrollbar/horizontalScrollbar.ts`
- `vscode/src/vs/base/browser/ui/scrollbar/scrollbarState.ts`
- `vscode/src/vs/editor/common/config/editorOptions.ts`
- `vscode/src/vs/editor/contrib/hover/browser/hover.css`
- `vscode/src/vs/editor/contrib/hover/browser/contentHoverWidget.ts`
- `vscode/src/vs/editor/contrib/hover/browser/contentHoverWidgetWrapper.ts`
- `vscode/src/vs/editor/contrib/hover/browser/contentHoverRendered.ts`
- `vscode/src/vs/editor/contrib/hover/browser/contentHoverStatusBar.ts`
- `vscode/src/vs/editor/contrib/hover/browser/resizableContentWidget.ts`
- `vscode/src/vs/editor/contrib/hover/browser/hoverCopyButton.ts`
- `vscode/src/vs/editor/contrib/hover/browser/markdownHoverParticipant.ts`
- `vscode/src/vs/base/browser/ui/hover/hoverWidget.css`
- `vscode/src/vs/base/browser/ui/resizable/resizable.ts`

The first implementation commit for this plan should add a reference summary to
the parity ledger before changing the product UI. That summary should name the
Monaco constants and source lines being copied.

## Behavior-Copying Protocol

Before changing product code for any ledger row, the implementing agent must:

- read the Monaco files named for that row and record the source path, line
  range, constants, classes, CSS variables, and state transitions in the parity
  ledger;
- identify whether the behavior comes from CSS, DOM structure, TypeScript layout
  code, event handling, or the combination of those pieces;
- add or extend a conformance assertion that fails against the current readonly
  viewer for the specific mismatch;
- port the behavior into locally owned MoonBit and CSS code without importing
  from `vscode/` or `codemirror/`;
- move the ledger row only to `PASS` after the conformance assertion and any
  relevant focused browser test pass.

No row may be marked `PASS` from visual inspection alone. Screenshot comparison
is supporting evidence, not a substitute for computed-style, geometry, and
interaction assertions.

Where Monaco behavior depends on measured layout, the port must copy the
measurement algorithm and constants, not only the resulting class names. This
applies especially to hover max width, hover max height, above/below placement,
right-edge shifting, custom scrollbar dimensions, visible/invisible/fade
classes, and wheel or keyboard scroll containment.

## Scope

In scope:

- The main editor custom scrollbar visible in the readonly viewer.
- Hover widget DOM, sizing, placement, scrollbars, status/actions/copy affordance
  where Monaco shows them for equivalent content.
- Hover markdown rendering and fenced-code rendering where they affect visible
  Monaco hover parity.
- Pointer, wheel, drag, track-click, keyboard, focus, and dismissal behavior for
  these surfaces.
- Light and dark theme parity for the same Monaco theme variables already used
  by this repo.

Out of scope:

- Editable Monaco features: cursor, selections, text area, composition, edit
  context, minimap, overview ruler, suggest, peek, rename, inline completions.
- Importing Monaco/VS Code runtime code or CSS into product packages.
- Changing the outer readonly viewer contract from MoonBit-owned names such as
  `.moonbit-viewer.readonly-editor`.

## Non-Negotiable Completion Rule

Do not mark this plan implemented because behavior is "close", "Monaco-shaped",
or "visually similar". Completion requires:

- every row in the parity ledger is `PASS`, or is listed under `Deferred` with a
  concrete user-approved reason;
- the Monaco reference fixture and our readonly viewer fixture are both exercised
  by the same Playwright conformance spec;
- computed-style, geometry, behavior, and screenshot checks run in CI/local
  browser tests;
- the final manual smoke records the Monaco reference screenshot and our viewer
  screenshot for the same state.

If any row is not proven, the plan remains incomplete.

## Artifacts To Add

Add these files as part of the plan execution:

- `docs/references/monaco-hover-scrollbar-parity.md`
  - The parity ledger. It is the source of truth for what must match.
  - It records Monaco source paths, copied constants, local implementation paths,
    test evidence, and status.
- `tests/reference/monaco-hover-scrollbar/`
  - A small local Monaco reference fixture that renders the same source text,
    hover payloads, theme, dimensions, and viewport states as the readonly
    viewer tests.
  - It may use a minimal `package.json`/bundle step modeled after
    `vscode/test/monaco`, but it must pin dependency versions or reuse the
    checked-in VS Code test package lock.
- `tests/browser/monaco_conformance.spec.js`
  - A Playwright spec that opens both the Monaco reference fixture and the
    readonly viewer, drives the same states, and compares DOM, computed styles,
    geometry, behavior, and screenshots.
- `tests/browser/fixtures/monaco_conformance_payloads.js`
  - Shared source text and hover payloads so the Monaco fixture and readonly
    viewer fixture cannot drift.

Existing tests in `hover.spec.js` and `scroll.spec.js` may remain, but passing
those tests is not sufficient for this plan.

## Monaco Oracle Fixture

The reference fixture must expose deterministic hooks for the conformance spec:

- `window.__monacoConformance.ready()`
- `window.__monacoConformance.setTheme("light" | "dark")`
- `window.__monacoConformance.openDocument(text, languageId)`
- `window.__monacoConformance.showHover(payloadName, line, column)`
- `window.__monacoConformance.hideHover()`
- `window.__monacoConformance.scrollEditor(top, left)`
- `window.__monacoConformance.measure()`

`measure()` must return a compact JSON object with:

- editor and hover DOM subtree selectors/classes;
- bounding boxes for editor scrollbars, scrollbar sliders, hover wrapper, hover
  container, hover content, hover scrollbars, hover rows, actions/status rows,
  and copy button when present;
- computed styles for opacity, display, pointer-events, transition, background,
  color, border, border-radius, box-shadow, padding, font, overflow, max-width,
  max-height, cursor, z-index, and visibility;
- scrollbar state, including visible/invisible/fade classes, thumb size, thumb
  position, active state, and whether native scrollbars are hidden.

The readonly viewer must expose an equivalent measurement hook for tests. Prefer
a test-only helper installed by the workbench, not a broad production API:

- `window.__readonlyEditorConformance.measure()`
- `window.__readonlyEditorConformance.setHoverPayload(name)`
- `window.__readonlyEditorConformance.showHover(line, column)`
- `window.__readonlyEditorConformance.hideHover()`

## Parity Ledger Seed

The implementing agent must expand this seed into
`docs/references/monaco-hover-scrollbar-parity.md` and keep statuses current.

| Area | Monaco source | Required parity | Evidence |
| --- | --- | --- | --- |
| Scrollbar DOM | `scrollableElement.ts`, `abstractScrollbar.ts` | `.monaco-scrollable-element` contains horizontal and vertical `.scrollbar` nodes, each with `.slider`, `role="presentation"`, and `aria-hidden="true"` where Monaco sets them. | DOM comparison test |
| Scrollbar visibility | `scrollbarVisibilityController.ts`, `scrollbars.css` | Use Monaco visible/invisible/fade classes, opacity transitions, and pointer-events behavior. Do not replace this with `display: none` unless Monaco does. | Computed-style and transition test |
| Scrollbar default options | `editorOptions.ts` | Match default vertical/horizontal visibility, scrollbar sizes, slider sizes, arrow settings, wheel handling, `alwaysConsumeMouseWheel`, and `scrollByPage`. | Constant ledger and behavior tests |
| Scrollbar rail/thumb CSS | `scrollbars.css`, theme variables | Match transparent rail behavior, thumb background, hover background, active background, shadows, z-index, and transition timing. | Computed-style and screenshot tests |
| Scrollbar thumb geometry | `scrollbarState.ts`, vertical/horizontal scrollbar files | Match minimum slider size, representable range, thumb position, and horizontal/vertical sizing within 1px. | Geometry test |
| Track click | `abstractScrollbar.ts` | Match Monaco default: if `scrollByPage` is false, jump so the thumb centers around the pointer; if true, page toward pointer. Use the same default as Monaco. | Pointer behavior test |
| Thumb drag | `abstractScrollbar.ts` | Match active class, drag delta mapping, drag-end cleanup, and Windows orthogonal reset behavior where applicable. | Pointer behavior test |
| Wheel handling | `scrollableElement.ts` | Match wheel delta normalization and consume/chaining behavior for editor and hover scrollables. | Wheel behavior test |
| Scroll shadows | `scrollbars.css`, scrollable element code | Match top/left shadow nodes and visibility when content is scrolled. | DOM/style/screenshot test |
| Hover outer wrapper | `contentHoverWidget.ts`, `resizableContentWidget.ts` | Use Monaco resizable content widget semantics: wrapper class, z-index, overflow policy, sashes when present, minimum size, max size, and placement preference. | DOM and geometry test |
| Hover container CSS | `hover.css`, `hoverWidget.css` | Match border, radius, color, background, shadow, font, focus outline, link/code styling, and fade timing. | Computed-style and screenshot tests |
| Hover placement | `resizableContentWidget.ts`, `contentHoverWidget.ts` | Match above/below preference, vertical available-space constants, horizontal max width, and overflow shifting. | Geometry tests at top/middle/bottom/right edge |
| Hover sizing | `contentHoverWidget.ts` | Match max dimensions, content dimensions, re-layout after resize/content changes, and scrollbar scan behavior. | Geometry and overflow tests |
| Hover content rows | `hover.css`, `contentHoverRendered.ts` | Match row, row contents, markdown hover, hover contents, margin/padding, wrapping, and source code block layout. | DOM/style/screenshot test |
| Hover status/actions | `contentHoverStatusBar.ts`, `hover.css`, hover actions files | If Monaco shows status/action/copy affordances for the same payload, our hover must show the same affordance with the same layout and interaction. | DOM and interaction test |
| Hover copy button | `hoverCopyButton.ts`, `hover.css` | Match visibility on hover/focus, position, icon sizing, focus outline, hover background, and clipboard behavior where applicable. | Interaction test |
| Hover scrollbars | `HoverWidget`, `scrollableElement.ts`, `scrollbars.css` | Hover content uses Monaco scrollable element behavior, not native visible scrollbars. Vertical/horizontal scrollbars appear/fade like Monaco and do not scroll the editor. | Behavior/style test |
| Hover keyboard | `contentHoverWidget.ts` | Match Escape dismissal, arrow/page/home/end scrolling, focus behavior, and horizontal scrolling keys for overflowing code blocks. | Keyboard test |
| Markdown/fenced code | `markdownHoverParticipant.ts`, `hoverWidget.css` | Match Monaco DOM and style for markdown, inline code, block code, links, lists, paragraphs, separators, and tokenized source where the readonly viewer intentionally provides tokenization. | DOM/style/screenshot test |
| Accessibility | Monaco hover and scrollbar sources | Match tooltip role, focusability, aria attributes, keyboard reachability, and accessible names for buttons. | DOM and keyboard test |

Each row in the real ledger must have one of these statuses:

- `TODO`
- `PORTED`
- `TESTED`
- `PASS`
- `DEFERRED: <user-approved reason>`

Only `PASS` and approved `DEFERRED` rows count toward completion.

## Phase 1: Build the Oracle Before Changing UI

Work items:

- Add the Monaco reference fixture and shared payloads.
- Make it render the pinned Monaco editor in a fixed viewport, with the same
  light/dark theme variables used by the readonly viewer.
- Add deterministic ways to show a hover for:
  - a short signature;
  - multi-paragraph markdown;
  - a long vertical markdown list;
  - a wide fenced code block;
  - a hover near the top edge;
  - a hover near the right edge;
  - a hover near the bottom edge.
- Add screenshot capture states for editor scrollbar idle, scrollbar hover,
  scrollbar active drag, short hover, long vertical hover, and wide code hover.
- Create the parity ledger with Monaco constants and initial `TODO` statuses.

Exit criteria:

- `tests/browser/monaco_conformance.spec.js` can open the Monaco fixture and
  write the reference measurements.
- The plan is still incomplete; no product UI changes are required in this
  phase.

## Phase 2: Add Failing Conformance Tests

Work items:

- Extend the conformance spec to open the readonly viewer at
  `/Users/baozhiyuan/Workspace/moonbit-project/simple` or a committed fixture
  with equivalent source text.
- Compare the Monaco and readonly measurements for every ledger row.
- Add screenshot comparisons using Playwright screenshot assertions or a small
  pixel-diff helper. Use a fixed viewport and disable animations only in states
  where Monaco itself disables animations; otherwise transitions are part of the
  behavior under test.
- Use tight tolerances:
  - geometry: 1px for stable boxes, 2px only where browser font rendering makes
    1px unrealistic;
  - colors: exact computed RGB/RGBA strings from the same browser;
  - opacity, pointer-events, transition duration, display, visibility: exact;
  - screenshot: require no visible drift in hover and scrollbar regions, with a
    small documented antialias threshold if pixel diffing is used.

Exit criteria:

- The tests fail on the current implementation for the known mismatches.
- The failure messages name the ledger row they protect.

## Phase 3: Port Scrollbar Behavior One To One

Work items:

- Replace local visibility behavior with Monaco's
  `ScrollbarVisibilityController` state model:
  `visible scrollbar ...`, `invisible scrollbar ...`, optional `fade`, opacity
  transition, and pointer-events behavior.
- Port rail/thumb CSS from `scrollbars.css` into `app/src/style.css`, scoped so
  product code remains locally owned.
- Match Monaco default scrollbar options from `editorOptions.ts`.
- Correct track-click behavior to match Monaco's `scrollByPage` default.
- Match thumb drag active class and drag-end cleanup.
- Add scroll shadow DOM and visibility if Monaco shows it for the tested state.
- Keep `renderer.ViewLayout` as the editor scroll truth; only the browser
  presentation and input semantics should change.

Exit criteria:

- Scrollbar ledger rows are `PASS`.
- Existing `scroll.spec.js` still passes.
- Conformance screenshots for idle, hovered, and active scrollbar states match
  the Monaco fixture.

## Phase 4: Port Hover Widget Behavior One To One

Work items:

- Port Monaco hover container CSS from `hover.css` and `hoverWidget.css` without
  local simplifications that change visible UX.
- Match `ContentHoverWidget` and `ResizableContentWidget` sizing and placement
  constants, including minimum dimensions, available-space calculations, max
  dimensions, above/below preference, and right-edge shifting.
- Add the Monaco status/action/copy affordances for payloads where Monaco shows
  them. Do not omit them just because the readonly viewer has fewer editor
  features; if the payload has an equivalent Monaco affordance, include it.
- Match hover scrollable behavior, including fade/visibility, wheel containment,
  horizontal scrolling, keyboard scrolling, and Escape dismissal.
- Match markdown row, paragraph, list, link, inline-code, fenced-code, separator,
  and tokenized-source DOM/style for the shared payloads.
- Keep provider semantics and stale-result guards locally owned; this phase is
  about widget presentation and interaction parity.

Exit criteria:

- Hover ledger rows are `PASS`.
- Existing `hover.spec.js` still passes or is updated to assert the stricter
  Monaco behavior.
- Conformance screenshots for short hover, long vertical hover, wide code hover,
  top-edge hover, right-edge hover, and bottom-edge hover match the Monaco
  fixture.

## Phase 5: Documentation and Harness Update

Work items:

- Update `docs/harness.md` with the conformance selectors and state hooks.
- Update `renderer/browser/README.md` to distinguish:
  - MoonBit-owned outer viewer contract;
  - Monaco-conformant inner hover and scrollbar behavior.
- Update `docs/references/monaco.md` with the new reference fixture and parity
  ledger path.
- Mark this plan implemented only after the final evidence exists. Do not edit
  the old implemented plans except to add a dated superseding link if needed.

Exit criteria:

- Documentation no longer says "Monaco-shaped" where the behavior is now
  expected to be Monaco-conformant.
- The parity ledger is fully updated.

## Validation

Run:

```sh
just check
just test
just build
just test-browser
git diff --check
```

Also run the Monaco conformance spec directly if it is not already included in
`just test-browser`:

```sh
./node_modules/.bin/playwright test tests/browser/monaco_conformance.spec.js
```

Then smoke the real viewer:

```sh
just dev ROOT=/Users/baozhiyuan/Workspace/moonbit-project/simple PORT=<free-port>
```

In the browser:

- open `simple.mbt`;
- compare the Monaco reference and readonly viewer screenshots for the same
  viewport and theme;
- hover a short symbol;
- show a long vertical hover;
- show a wide code-block hover;
- wheel inside the hover and confirm the editor does not scroll;
- hover, drag, and track-click the editor scrollbar;
- repeat in light and dark themes.

## Acceptance Criteria

- A local Monaco reference fixture exists and is pinned to the VS Code submodule
  commit named in this plan.
- The parity ledger exists, names every required Monaco source, and has only
  `PASS` or approved `DEFERRED` rows.
- The conformance Playwright spec compares Monaco and the readonly viewer for
  DOM, computed styles, geometry, interaction behavior, and screenshots.
- Scrollbar visibility, fade, rail/thumb CSS, thumb geometry, track clicks,
  dragging, wheel behavior, and scroll shadows match Monaco for the readonly
  editor.
- Hover DOM, CSS, sizing, placement, scrollbars, markdown/source rendering,
  status/actions/copy affordances, focus, keyboard behavior, and dismissal match
  Monaco for the shared payloads.
- Existing focused browser tests still pass.
- No product code imports from `vscode/` or `codemirror/`.
- The final response for implementation includes the Monaco reference screenshot
  path, readonly viewer screenshot path, validation commands, and any approved
  deferred ledger rows.
