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
- `.code-line`, `.gutter`, `.code`, token spans, diagnostics, hover data, and
  definition target attributes keep the same class and `data-*` contracts used
  by browser smoke tests.
- `.hover-widget` is the range-anchored editor hover; `.peek-widget` is the
  inline references peek (head `.peek-title`/`.peek-close`, result rows
  `.peek-ref-row` with `data-ref-index`).

Sidebar selection is app state only. Selecting or expanding workspace entries
must not change `window.location.href`.

The product browser path does not use `?uri=`, `?path=`, hashes, or history
updates to represent the active file. Browser tests should open workspace files
through sidebar selection and the native remote protocol.

## Browser Observability

The browser host logs structured events prefixed with `[readonly-editor]`:

- `moonbit:render`: source line count, token count, diagnostic count.
- `language:diagnostics`: active document diagnostic count and version after
  semantic provider sync.
- `language:hover`: successful on-demand hover resolution for the active
  document.
- `language:definition`: successful on-demand definition resolution for the
  active document.
- `language:references`: on-demand references resolution for the active
  document, with the result count.
- `language:error`: provider or protocol errors that did not block readonly
  render.
- `dom:mounted`: rendered line and diagnostic counts after DOM creation.

These events are intentionally stable so automated agents can diagnose render
failures from console output.
