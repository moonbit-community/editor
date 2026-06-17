# base/common

Host-neutral base utilities shared by editor packages.

## Responsibilities

- Own `Uri`, `UriResult`, and `UriError`.
- Parse absolute provider-owned `scheme://...` identities.
- Create memory URIs for tests, demos, and simple embedders.
- Expose scheme, path, display-name, and string conversion helpers.

## Boundaries

- Must not depend on product packages, DOM, browser APIs, native APIs, server
  routing, workspace providers, or renderer packages.
- Product packages should use `@base_common.Uri` for document/resource identity
  instead of reintroducing workspace-owned URI aliases.

## Checks

- Package tests live in `uri_test.mbt`.
- Run `moon test base/common` for focused coverage.

