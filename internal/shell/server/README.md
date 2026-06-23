# server

Reference backend policy for remote readonly workspaces.

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

- May depend on public domain packages plus internal shell `workspace` and
  `remote_protocol`, and JSON support.
- Must not import browser shell packages, the public `viewer` package, or
  `internal/shell/web`.
- Native effects stay behind the `ServerHost` trait; server code owns policy and
  routing.
- This package is part of the reference shell/backend stack, not a requirement
  for embedding the viewer.

## Checks

- Package tests live in `server_test.mbt`.
- Run `just check` for the repository-level type check.
