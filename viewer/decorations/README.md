# viewer/decorations

Range-based visual annotations over immutable documents. The DOM-free viewer
common-layer carrier for readonly decorations, the local analog of Monaco's
`vs/editor/common/model` decoration data (the readonly subset).

## Responsibilities

- Define decoration kinds, decoration payloads, and `DecorationSet`.
- Query decorations by range or offset for render construction.
- Represent readonly visual state such as diagnostics, links, matches, semantic
  overlays, hover highlights, and current-line markers.

## Boundaries

- A viewer common-layer subpackage: DOM-free and FFI-free. May depend only on
  `base/common`.
- Must not depend on the viewer browser core (`viewer`), `viewer/common`,
  `rabbita/*`, host effects, or the shell. `scripts/check-architecture.mbtx`
  classifies `viewer/*` non-browser manifests as common-layer and enforces this.
- Must not own edit mapping, document mutation, DOM classes beyond stored class
  names, or host-specific rendering.
- Does not compute diagnostics or language data; it only carries annotations.

## Checks

- Package tests live in `decorations_test.mbt`.
- Run `just check` for the repository-level type check.
