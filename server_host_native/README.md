# server_host_native

Native host adapter for server-side effects.

## Responsibilities

- Provide the native implementation point for the `server.ServerHost` trait.
- Provide the native implementation point for the server-owned
  `server.LspTransport` trait.
- Keep filesystem reads, file watching, process spawning, timers, sockets, and
  `moon-lsp --stdio` lifecycle effects outside server policy code.
- Own configured stdio LSP process startup, `Content-Length` framing, and
  structured JSON-RPC errors when no process command is configured.
- Return structured host errors when native capabilities are unavailable.

## Boundaries

- May depend on `server` and `workspace`.
- Must not own remote protocol routing, workspace policy, provider semantics, or
  browser behavior.
- Keep this package native-only through `supported_targets = "native"`.

## Checks

- Package tests live in `native_host_test.mbt`.
- Run `just check` for the repository-level type check.
