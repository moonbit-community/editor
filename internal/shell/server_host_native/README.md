# server_host_native

Native effect adapter for the reference backend shell.

## Responsibilities

- Provide the native implementation point for the `server.ServerHost` trait.
- Keep filesystem reads, file watching, process spawning, timers, and sockets
  outside server policy code.
- Serve the browser client from `web/dist` and bridge `/protocol` WebSocket
  traffic into `server.RemoteServer`, serializing outbound packets through a
  per-connection writer task so concurrent watch pushes and responses never
  interleave on the socket.
- List workspace entries, validate root-relative paths, and poll watched files
  under the configured workspace root.
- Back semantic features with the `moon` command line: hover shells out to
  `moon ide hover --output-json`, and diagnostics come from single-flight
  `moon check --output-json` runs pushed to every connected session.
- Return structured host errors for invalid paths, missing files, directories,
  and unavailable native capabilities.

## Boundaries

- May depend on internal shell `server`, `remote_protocol`, `workspace`, and
  native async runtime packages.
- Must not own remote protocol routing, workspace policy, provider semantics, or
  browser behavior.
- Keep this package native-only through `supported_targets = "native"`.
- This package is not part of the reusable viewer API.

## Checks

- Package tests live in `native_host_test.mbt`.
- Run `just check` for the repository-level type check.
