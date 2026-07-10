# internal/shell/examples/embedded_viewer

Minimal JS embedding proof for the reusable `viewer`. It uses in-memory files
and an in-memory `WorkspaceTreeProvider`; no workbench, remote protocol, server,
or WebSocket participates.

## Flow

- Startup registers the MoonBit tokenizer in the default `Languages` registry.
- `FileTree.on_open` asks the in-memory host for a new
  `viewer/common/model.TextModel` and calls `Viewer::set_model`.
- A fresh `ViewerModelRenderedEvent` drives `FileTree::set_active` (`autoReveal`).
- Rabbita renders a stable, childless `.viewer-host`; after the first paint the
  host mounts the imperative editor with `Viewer::create`.

This is the standalone-host boundary: the host owns storage, model creation,
selection, and feature registration; the viewer owns its DOM subtree.

## Validation

`just build-moon-web` emits `web/dist/embed.{html,mjs}`. The native server serves
`/embed.html`; `tests/browser/smoke/embed.spec.js` covers render, lazy expansion,
navigation, and the absence of a WebSocket.
