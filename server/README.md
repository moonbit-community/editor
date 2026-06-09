# server

Native-side remote workspace policy and protocol dispatch.

## Responsibilities

- Resolve `readonly-remote://workspace/...` URIs to normalized root-relative
  paths.
- Read and cache readonly source documents through `ServerHost`.
- Manage file watches, close/dispose behavior, semantic language-feature
  requests, and remote protocol dispatch.

## Boundaries

- May depend on `workspace`, `language`, and `remote_protocol`.
- Must not import renderer packages, browser backend packages, `dom`, or `web`.
- Native effects stay behind the `ServerHost` trait; server code owns policy and
  routing.

## Checks

- Package tests live in `server_test.mbt`.
- Run `just check` for the repository-level type check.
