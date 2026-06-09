# remote_protocol

MoonBit-owned client/server packet contract for remote readonly workspaces.

## Responsibilities

- Define client packets, server packets, payloads, protocol errors, and
  version negotiation.
- Encode and decode remote protocol JSON.
- Carry raw LSP JSON-RPC payloads without moving routing or lifecycle ownership
  out of MoonBit.

## Boundaries

- May depend on `core`, `workspace`, `language`, and JSON support.
- Must not depend on browser, native, DOM, renderer backend, or server host
  effects.
- Protocol errors should preserve provider-error details for callers.

## Checks

- Package tests live in `protocol_test.mbt`.
- Run `just check` for the repository-level type check.
