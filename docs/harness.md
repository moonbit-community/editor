# Harness

The harness is designed so agents can inspect, run, and debug the project
without hidden setup.

## Commands

- `just check`: MoonBit type check.
- `just test`: MoonBit unit tests.
- `just build`: build the MoonBit browser bundle in `web/dist` and the native
  editor server executable.
- `just test-browser`: Playwright smoke tests against the native server.
- `just dev ROOT=. PORT=5173`: build and run the native
  editor server.

The `justfile` harness uses `.mbtx` scripts in `scripts/` for helper tasks.

`web/dist/index.html` loads `/style.css` and `/editor.mjs`. The native server
serves `/`, `/index.html`, `/style.css`, and `/editor.mjs` directly and returns
404 for other static paths.

`just dev` serves the browser viewer and handles `/protocol` as a WebSocket.
The browser connects to the same host with Rabbita WebSocket support, requests
`ListWorkspace`, opens files through `readonly-remote://workspace/<path>`, and
receives document, language, and watch packets from the native server.

## Browser Selectors

The browser app preserves stable DOM contracts for Playwright and agent
inspection:

- `.editor-shell` exposes `data-status`, `data-theme` (`dark`/`light`),
  `data-line-count`, and `data-source-uri`.
- `.workspace-sidebar` renders file and folder controls with
  `data-workspace-id`, `data-workspace-kind`, `aria-expanded`, and
  `aria-selected`; the pane header exposes the theme toggle as
  `[data-action="toggle-theme"]`.
- `.code-line`, `.gutter`, `.code`, token spans, and diagnostics keep the
  same class and `data-*` contracts used by browser smoke tests.
- `.hover-widget` is the range-anchored editor hover.

Sidebar selection is app state only. Selecting or expanding workspace entries
must not change `window.location.href`.

The product browser path does not use `?uri=`, `?path=`, hashes, or history
updates to represent the active file. Browser tests should open workspace files
through sidebar selection and the native remote protocol.

## Browser Observability

The browser host logs structured events prefixed with `[readonly-editor]`:

- `moonbit:render`: source line count, token count, diagnostic count, and
  `buildMs` (frame construction duration).
- `language:diagnostics`: active document diagnostic count and version after
  semantic provider sync.
- `language:hover`: successful on-demand hover resolution for the active
  document.
- `language:error`: provider or protocol errors that did not block readonly
  render.
- `dom:mounted`: rendered line and diagnostic counts after DOM creation,
  plus `patchMs` (time from frame build completion to after-paint).
  `renderedLines` is the windowed line count actually in the DOM; the
  shell's `data-line-count` attribute stays the document total.

These events are intentionally stable so automated agents can diagnose render
failures from console output.

## Render Performance Budget

The code surface lives in its own Rabbita child cell with keyed line
children, so shell-only updates skip the line subtrees entirely and feature
updates reuse unchanged line DOM. The working budget:

- Interaction re-renders (hover, decorations) should stay under ~2ms.
- Scrolling should hold 60fps; native scrolling stays untouched between
  window updates.

`tests/browser/perf.spec.js` opens the small fixture and a generated
~10k-line fixture and logs `buildMs`/`patchMs` evidence without failing the
suite.
