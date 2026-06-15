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
Playwright uses `http://127.0.0.1:5173` by default; set
`READONLY_EDITOR_BASE_URL=http://127.0.0.1:<port>` when a focused run should
target an already-started server on another port.

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
- The viewer is an imperative island inside the shell's `.viewer-host`
  element. Its root is `.moonbit-viewer.readonly-editor`; clipping and
  the main editor scrollable live under `.overflow-guard`; text nodes are
  windowed `.view-line[data-line]` children of
  `.monaco-scrollable-element.editor-scrollable .lines-content .view-lines`;
  line numbers are `.line-number[data-line]` children of
  `.margin .margin-view-overlays .line-numbers`; token spans and
  diagnostics live inside `.view-line-content`.
- `[data-content-widget="hover"] .monaco-hover` is the range-anchored
  editor hover. Its scrollable content is
  `[data-content-widget="hover"] .monaco-hover-content` inside
  `.monaco-scrollable-element`, with Monaco-conformant custom scrollbar nodes.
  `.overlayWidgets`, `.overflowingContentWidgets`, and
  `.overflowingOverlayWidgets` are stable slots for future viewport or
  overflow-capable UI. The main editor also exposes
  `.monaco-scrollable-element.editor-scrollable`; its wheel input and
  custom scrollbar nodes are bridged into the `ViewLayout` scroll model.
- `tests/reference/monaco-hover-scrollbar/` is the local Monaco oracle fixture
  for hover and scrollbar conformance. It is paired with the readonly viewer by
  `tests/browser/monaco_conformance.spec.js` and the shared payloads in
  `tests/browser/fixtures/monaco_conformance_payloads.js`.

## Scroll Control

The workbench installs `globalThis.__readonlyEditorScrollTo(top)`, which
drives the viewer's `ViewLayout` scroll model (the request clamps to the
document). Specs can also wheel the editor's
`.monaco-scrollable-element.editor-scrollable`; each settled scroll paints
and then emits a `view:scroll` event. Direct DOM scroll offsets are treated
only as browser reveal deltas and are folded back into the model, matching
Monaco's editor scrollbar bridge.

For conformance tests, the workbench also installs
`globalThis.__readonlyEditorConformance`:

- `setPayloads(payloads)` and `setHoverPayload(name)` feed deterministic hover
  payloads into the harness hover provider.
- `showHover(line, column)` dispatches a viewer mouse move at the requested
  text coordinate; `hideHover()` routes Escape into the viewer.
- `scrollEditor(top, left)` drives the synthetic scroll model.
- `measure()` returns compact DOM, computed-style, geometry, scrollbar, shadow,
  hover-row, and accessibility data for the readonly viewer.

The Monaco oracle fixture exposes the analogous
`globalThis.__monacoConformance` API plus `ready()`, `setTheme(theme)`, and
`openDocument(text, languageId)`.

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

- `moonbit:render`: source line count, token count, diagnostic count,
  `tokenizeMs` (whole-document tokenization for this document version;
  near zero when a provider push reuses the cached tokenized document),
  and `buildMs` (viewport window frame build from the per-line buckets).
- `language:diagnostics`: active document diagnostic count and version after
  semantic provider sync.
- `language:hover`: successful on-demand hover resolution for the active
  document.
- `language:error`: provider or protocol errors that did not block readonly
  render. Provider failures are emitted by the workbench logger sink from
  `platform/log` warning/error entries, so remote protocol providers log once
  and do not emit this event directly.
- `dom:mounted`: rendered line and diagnostic counts after DOM creation,
  plus `patchMs` (the duration of the island's DOM flush — the recycler
  write phase — that painted the frame). `renderedLines` is the windowed
  line count actually in the DOM; the shell's `data-line-count`
  attribute stays the document total.
- `view:scroll`: the settled synthetic scroll position (`scrollTop`,
  `scrollLeft`) after a paint, coalesced per animation frame.

These events are intentionally stable so automated agents can diagnose render
failures from console output. The workbench owns event names and payload
formats; the viewer library reports lifecycle facts (`ViewerNotification`)
and the workbench formats and emits them, so embedders of `renderer/browser`
get no harness events unless they add their own.

## Browser Test Logging

Playwright specs import `tests/browser/base.js`, which installs a VS
Code-style smoke logger split from runtime product logging:

- every test writes `runner.log` under `test-results/browser/...`;
- set `READONLY_EDITOR_TEST_VERBOSE=1` or `PW_VERBOSE=1` to mirror runner log
  entries to the terminal;
- browser console messages, page errors, failed requests, and HTTP 4xx/5xx
  responses are captured into the runner log;
- Playwright keeps traces and screenshots on failure (`trace:
  retain-on-failure`, `screenshot: only-on-failure`), and the base fixture also
  attaches a full-page `failure.png` when a test body throws.

## Render Performance Budget

The code surface is an imperative island: shell updates never touch it,
window shifts splice entering/leaving line nodes (`innerHTML` only on
entering lines), and scroll frames are transform writes coalesced per
animation frame. The working budget:

- Interaction re-renders (hover, decorations) should stay under ~2ms
  (`patchMs` evidence sits well under 1ms).
- Scrolling should hold 60fps; between window updates a scroll frame is
  a handful of style writes.

`tests/browser/perf.spec.js` opens the small fixture and a generated
~10k-line fixture and logs `buildMs`/`patchMs` evidence without failing the
suite.
