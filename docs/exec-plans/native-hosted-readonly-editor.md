# Native-Hosted Readonly Editor Plan

## Goal

Replace the Vite-based dev server and in-page fake protocol transport with a
native MoonBit server that serves the browser assets and handles the real
readonly editor protocol.

The target development flow is:

```sh
just build
just dev ROOT=docs/fixtures/project PORT=5173
```

Then open `http://127.0.0.1:5173/`. The page should load `index.html`,
`style.css`, and `editor.mjs` from the native server. The browser should connect
to the same server over WebSocket, request the workspace tree, open files
through `remote_protocol`, and receive document, language, and watch results
from the native server.

## Target Shape

- `server` remains policy-only: workspace-root validation, document cache,
  remote protocol dispatch, watches, and language-provider routing.
- `server_host_native` owns native effects: HTTP serving, WebSocket upgrade,
  filesystem reads, workspace listing, polling file watches, and LSP process
  transport.
- A small native executable package wires CLI flags, static assets, the native
  host, and the `server.RemoteServer` instance.
- `renderer/browser` uses Rabbita's browser WebSocket support for protocol
  transport. Do not add custom browser WebSocket FFI in `dom`.
- `dom` keeps only any remaining narrow host boundary and observability helpers
  that are still needed after protocol transport moves to Rabbita.

## Static Asset Serving

The native server serves the built browser client directly:

- `web/dist/editor.mjs` is produced from `moon build --target js web`.
- `web/dist/style.css` is copied from `app/src/style.css`.
- `web/dist/index.html` loads:

```html
<link rel="stylesheet" href="/style.css">
<script type="module" src="/editor.mjs"></script>
```

The native server only needs these routes for v1:

- `/` and `/index.html` -> `index.html`
- `/style.css` -> `style.css`
- `/editor.mjs` -> `editor.mjs`
- anything else -> 404

Use `moonbitlang/async/http`, `moonbitlang/async/socket`, and
`moonbitlang/async/websocket` on the native side. This removes Vite from the
dev and browser-test serving path.

## Protocol And Browser Flow

Extend the MoonBit-owned `remote_protocol` with workspace listing:

- Add `ListWorkspace` as a client packet.
- Add `WorkspaceListed` as a server packet.
- `WorkspaceListed` returns a flat pre-order list with `path`, `name`, `kind`,
  and `depth`.
- `path` is always the full root-relative workspace path. Never send absolute
  host filesystem paths to the browser.

The browser protocol flow is:

- On app startup, connect to `ws://<same-host>/protocol` using
  `moonbit-community/rabbita/websocket`.
- Use a stable connection id such as `readonly-editor-protocol`.
- Send raw `remote_protocol` JSON strings with Rabbita WebSocket commands.
- Receive server packets through Rabbita WebSocket subscriptions and dispatch
  them into the Rabbita update loop.
- Request `ListWorkspace` after the socket opens.
- Render the sidebar from `WorkspaceListed`, not hard-coded workspace entries.
- Selecting a file derives `readonly-remote://workspace/<path>`, sends
  `OpenDocument`, then starts `WatchDocument`.
- Hover, definition, diagnostics, document symbols, and semantic tokens keep
  using semantic `remote_protocol` packets, not raw LSP JSON-RPC.

## Native Workspace Behavior

The native host resolves every source path relative to `--root`.

- Normalize and validate root-relative paths before filesystem access.
- Reject paths that are absolute, contain `..`, contain NUL, are directories, or
  resolve outside the workspace root.
- Map filesystem failures to existing structured provider errors.
- Read text files through `NativeServerHost.read_text_file`.
- Implement v1 watches by polling existence and mtime; emit `Changed` or
  `Deleted`.
- Workspace listing should skip `.git`, `_build`, `.mooncakes`, `node_modules`,
  `web/generated`, and `web/dist`.

Use explicitly injected language providers so the server path is always wired
through the same provider boundary. Add an optional CLI path for wiring
`moon-lsp --stdio` through the existing native LSP transport after the static
server and WebSocket flow are passing.

## Harness Changes

- Add `docs/fixtures/project` as a deterministic workspace fixture with a small
  MoonBit project and at least two source files.
- Make `just build` produce the static dist assets and native executable.
- Make `just dev` run the native executable with default root
  `docs/fixtures/project` and default port `5173`.
- Update Playwright to use the native server command instead of Vite.
- Remove Vite from the default dev and browser-test path once the native server
  serves the app successfully.

## Validation

Unit tests:

- `remote_protocol` encodes and decodes `ListWorkspace` and `WorkspaceListed`.
- `server` covers workspace listing order, invalid path rejection, open/read
  errors, watch changed events, and watch deleted events.
- `server_host_native` covers static routes, content types, 404s, root escape
  rejection, fixture file reads, and polling watch behavior.

Browser tests:

- The app starts from the native server, not Vite.
- The browser connects through Rabbita WebSocket.
- The sidebar renders fixture project entries using full root-relative
  `data-workspace-id` values.
- Selecting a file opens it through WebSocket and does not change the browser
  URL.
- Diagnostics, hover, definition, symbols, and semantic tokens request the
  native server through `remote_protocol`.
- Changing, deleting, and restoring a watched fixture file updates the rendered
  state.

Repository checks:

```sh
just check
just test
just build
just test-browser
```

## Non-Goals

- Do not implement edit support; the editor remains readonly.
- Do not expose absolute host filesystem paths to the browser.
- Do not add custom browser WebSocket FFI while Rabbita's WebSocket package
  covers the browser transport.
- Do not move remote protocol routing or workspace policy into
  `renderer/browser` or `web`.
- Do not expose LSP details outside the native host-server provider boundary.
