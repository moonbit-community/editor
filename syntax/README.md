# syntax

Whole-document lexical highlighting for readonly source snapshots.

## Responsibilities

- Convert a `core.DocumentSnapshot` into ordered highlight tokens.
- Classify token ranges with stable `HighlightTag` values and CSS class names.
- Keep highlighting deterministic and independent of host rendering.

## Boundaries

- May depend on `core`.
- Must not depend on workspace loading, language providers, DOM, renderer
  backends, server packages, or reference submodules.
- Does not own semantic tokens or diagnostics; those belong to `language`.

## Checks

- Package tests live in `highlight_test.mbt`.
- Run `just check` for the repository-level type check.
