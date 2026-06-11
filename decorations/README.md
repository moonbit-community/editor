# decorations

Range-based visual annotations over immutable documents.

## Responsibilities

- Define decoration kinds, decoration payloads, and `DecorationSet`.
- Query decorations by range or offset for render construction.
- Represent readonly visual state such as diagnostics, links, matches, semantic
  overlays, hover highlights, and current-line markers.

## Boundaries

- May depend on `core`.
- Must not own edit mapping, document mutation, DOM classes beyond stored class
  names, or host-specific rendering.
- Does not compute diagnostics or language data; it only carries annotations.

## Checks

- Package tests live in `decorations_test.mbt`.
- Run `just check` for the repository-level type check.
