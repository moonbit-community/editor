# base/common

Host-neutral base utilities shared by editor packages.

## Responsibilities

- Own `Uri`, `UriResult`, and `UriError`.
- Parse absolute provider-owned `scheme://...` identities.
- Create memory URIs for tests, demos, and simple embedders.
- Expose scheme, path, display-name, and string conversion helpers.
- Own the coordinate geometry: `Position` (line/column), Monaco's line/column
  `Range`, `LineRange`/`LineRangeSet`, and the offset span `OffsetRange`.

## Range geometry

The geometry types are a 1:1 port of Monaco's range system:

- `Range` is line/column (`start_line_number`/`start_column`/…), mirroring
  `vs/editor/common/core/range.ts`.
- `LineRange`/`LineRangeSet` mirror `core/ranges/lineRange.ts`.
- `OffsetRange` is the half-open UTF-16 offset span (`[start, end)`), mirroring
  Monaco's `OffsetRange`; it is what most viewer consumers currently carry.

Migration note: consumers are mid-transition from `OffsetRange` to line/column
`Range`, and `Position` is still 0-based with a `line` field pending the rebase
to Monaco's 1-based `lineNumber`. See
`docs/exec-plans/monaco-test-conformance-port.md` (Progress log).

## Boundaries

- Must not depend on product packages, DOM, browser APIs, native APIs, server
  routing, workspace providers, or viewer packages.
- Product packages should use `@base_common.Uri` for document/resource identity
  instead of reintroducing workspace-owned URI aliases.

## Checks

- Package tests live in `uri_test.mbt`.
- Run `moon test base/common` for focused coverage.
