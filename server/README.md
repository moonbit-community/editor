# server

Native-side remote workspace policy and protocol dispatch.

## Responsibilities

- Resolve `readonly-remote://workspace/...` URIs to normalized root-relative
  paths.
- Read and cache readonly source documents through `ServerHost`.
- Manage file watches, close/dispose behavior, semantic language-feature
  requests, and remote protocol dispatch.
- Dispatch semantic feature requests through explicitly injected `language`
  provider traits.
- Own the hidden LSP client, request/notification flow, capability gating, and
  LSP-to-semantic result conversion for server-backed providers.

## Boundaries

- May depend on `core`, `workspace`, `language`, `remote_protocol`, and JSON
  support.
- Must not import renderer packages, browser backend packages, `dom`, or `web`.
- Native effects stay behind the `ServerHost` trait; server code owns policy and
  routing.

## Checks

- Package tests live in `server_test.mbt`.
- Run `just check` for the repository-level type check.
