# remote_protocol

MoonBit-owned client/server packet contract for remote readonly workspaces.

## Responsibilities

- Define client packets, server packets, payloads, protocol errors, and
  version negotiation.
- Encode and decode remote protocol JSON.
- Carry semantic editor-domain document and language-feature packets, including
  diagnostics, hover, definition, references (with server-enriched line,
  column, and line-text previews), document symbols, and semantic tokens.
- Preserve structured provider errors without exposing raw LSP JSON-RPC.

## Boundaries

- May depend on `core`, `workspace`, `language`, and JSON support.
- Must not depend on browser, native, DOM, renderer backend, or server host
  effects.
- Protocol errors should preserve provider-error details for callers.

## Checks

- Package tests live in `protocol_test.mbt`.
- Run `just check` for the repository-level type check.
