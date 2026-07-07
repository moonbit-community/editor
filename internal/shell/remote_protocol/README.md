# remote_protocol

MoonBit-owned client/server packet contract for remote readonly workspaces.

## Responsibilities

- Define client packets, server packets, payloads, protocol errors, and
  version negotiation.
- Encode and decode remote protocol JSON.
- Carry semantic editor-domain document and language-feature packets, including
  hover, definition, references (with server-enriched line, column, and
  line-text previews), document symbols, and semantic tokens.
- Carry server-initiated pushes: watched-document changes and diagnostics
  (the wire form of LSP `publishDiagnostics`; diagnostics packets have no
  request id and are never answers to a client request).
- Preserve structured provider errors without exposing raw LSP JSON-RPC.

## Boundaries

- May depend on public domain packages, internal shell `workspace`, and JSON
  support.
- Must not depend on browser, native, DOM, viewer implementation, or server host
  effects.
- Protocol errors should preserve provider-error details for callers.

## Checks

- Package tests live in `protocol_test.mbt`.
- Run `just check` for the repository-level type check.
