# server_host_native

Native host adapter for server-side effects.

## Responsibilities

- Provide the native implementation point for the `server.ServerHost` trait.
- Provide the native implementation point for the server-owned
  `server.LspTransport` trait.
- Keep filesystem reads, file watching, process spawning, timers, sockets, and
  `moon-lsp --stdio` lifecycle effects outside server policy code.
- Serve the browser client from `web/dist` and bridge `/protocol` WebSocket
  traffic into `server.RemoteServer`.
- List workspace entries, validate root-relative paths, and poll watched files
  under the configured workspace root.
- Own configured stdio LSP process startup, `Content-Length` framing, and
  structured JSON-RPC errors when no process command is configured.
- Return structured host errors for invalid paths, missing files, directories,
  and unavailable native capabilities.

## Boundaries

- May depend on `server`, `remote_protocol`, `workspace`, and native async
  runtime packages.
- Must not own remote protocol routing, workspace policy, provider semantics, or
  browser behavior.
- Keep this package native-only through `supported_targets = "native"`.

## Checks

- Package tests live in `native_host_test.mbt`.
- Run `just check` for the repository-level type check.
