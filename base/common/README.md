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
- `OffsetRange` is the half-open UTF-16 offset span (`[start, end_exclusive)`,
  0-based), a 1:1 port of Monaco's `OffsetRange` with its full API (`length`,
  `contains`, `contains_range`, `intersects`, `intersects_or_touches`, `join`,
  `intersect`, `delta`, the `from_to`/`of_length`/`empty_at`/`try_create`
  constructors, …). It is what most viewer consumers currently carry. Deviation:
  the constructor normalizes inverted input instead of throwing (the readonly
  viewer avoids panics).

`Position` is a 1:1 port of Monaco's `Position`: one-based on both axes
(`line_number` starts at 1, `column` starts at 1), with Monaco's methods
(`with_`, `delta`, `equals`, `is_before`/`is_before_or_equal`, `compare`,
`clone`, `to_string`). The offset↔position boundary lives in the snapshots
(`position_at_offset`/`offset_at_position`); the LSP wire (0-based) converts in
`lsp_client`'s `parse_lsp_position`/`lsp_position_json`.

Migration note: consumers are mid-transition from `OffsetRange` to line/column
`Range`. See `docs/exec-plans/monaco-test-conformance-port.md` (Progress log).

## Boundaries

- Must not depend on product packages, DOM, browser APIs, native APIs, server
  routing, workspace providers, or viewer packages.
- Product packages should use `@base_common.Uri` for document/resource identity
  instead of reintroducing workspace-owned URI aliases.

## Checks

- Package tests live in `uri_test.mbt`.
- Run `moon test base/common` for focused coverage.
