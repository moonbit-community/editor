# Readonly MoonBit Viewer

This repository has two main parts:

- `viewer`: the reusable MoonBit readonly viewer. It is Monaco-shaped in API
  and behavior where that helps embedders, but it stays MoonBit-owned and does
  not import Monaco, VS Code, or CodeMirror code.
- `workbench` plus the backend shell: the reference app used to see the viewer
  working against a real workspace. It demonstrates one host composition and
  must use the viewer through public APIs.

Monaco/VS Code is the primary design reference. CodeMirror is a secondary
reference when its simpler state/view split is useful. Both submodules are
reference-only.

## Quick Start

```sh
npm install
just check
just build
just dev ROOT=. PORT=5173
```

Open `http://127.0.0.1:5173/`. The dev server is the native backend shell: it
serves `web/dist` and talks to the browser workbench over the readonly remote
protocol WebSocket.

## Validation

```sh
just check
just test
just build
just test-browser
```

Current architecture lives in [docs/architecture.md](docs/architecture.md).
Browser harness behavior lives in [docs/harness.md](docs/harness.md).
