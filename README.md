# Readonly MoonBit Editor

This repository is a from-scratch readonly code viewer built in MoonBit, with
Monaco and CodeMirror checked in as reference-only submodules.

## Quick Start

```sh
npm install
just check
just build
just dev ROOT=. PORT=5173
```

Then open `http://127.0.0.1:5173/`. The browser client is served by the native
MoonBit host from `web/dist` and talks to the same host over the readonly
remote protocol WebSocket.

## Validation

```sh
just check
just test
just build
just test-browser
```

See [docs/architecture.md](docs/architecture.md) and [docs/harness.md](docs/harness.md).
