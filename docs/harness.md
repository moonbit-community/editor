# Harness

The harness is designed so agents can inspect, run, and debug the project
without hidden setup.

## Commands

- `just check`: MoonBit type check plus the architecture checker
  (`scripts/check-architecture.mbtx`), which greps for forbidden reference
  trees and enforces package import boundaries.
- `just test`: MoonBit unit tests.
- `just build`: build the MoonBit browser bundle in `web/dist` and the native
  editor server executable.
- `just test-browser`: Playwright smoke tests against the native server.
- `just dev ROOT=. PORT=5173`: build and run the native
  editor server.

The `justfile` harness uses `.mbtx` scripts in `scripts/` for helper tasks.

`web/dist/index.html` loads `/style.css` and `/editor.mjs`. The native server
serves `/`, `/index.html`, `/style.css`, `/editor.mjs`, `/embed.html`, and
`/embed.mjs` directly and returns 404 for other static paths. `/embed.html`
is the embedded-viewer example: the viewer plus the file tree running
against in-memory providers with no websocket.

`just dev` serves the browser viewer and handles `/protocol` as a WebSocket.
The workbench connects to the same host with Rabbita WebSocket support,
resolves the explorer tree one directory level at a time with
`ResolveDirectory`, opens files through `readonly-remote://workspace/<path>`
URIs carried on the tree entries, and receives document, language, and
watch packets from the native server.

## Browser Selectors

The browser app preserves stable DOM contracts for Playwright and agent
inspection:

- `.editor-shell` exposes `data-status`, `data-theme` (`dark`/`light`),
  `data-line-count`, and `data-source-uri`.
- `.workspace-sidebar` renders explorer rows with `data-workspace-id`
  (holding the full document URI), `data-workspace-kind`, `aria-expanded`,
  and `aria-selected`; the pane header exposes the theme toggle as
  `[data-action="toggle-theme"]`. Directories start collapsed: nested files
  are not in the DOM until their folders are expanded or the active file is
  auto-revealed, so specs that navigate to nested files expand ancestors
  first (or rely on the startup auto-open's reveal).
- `.code-line`, `.gutter`, `.code`, token spans, and diagnostics keep the
  same class and `data-*` contracts used by browser smoke tests.
- `.hover-widget` is the range-anchored editor hover.

Sidebar selection is app state only. Selecting or expanding workspace entries
must not change `window.location.href`. On startup the workbench auto-opens
the first MoonBit file found by a bounded depth-first resolve walk (falling
back to the first file of any kind); specs should wait for `data-status`
`ready` before navigating so their document switch cannot race the
auto-open.

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
failures from console output. The workbench owns event names and payload
formats; the viewer library reports lifecycle facts (`ViewerNotification`)
and the workbench formats and emits them, so embedders of `renderer/browser`
get no harness events unless they add their own.

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
