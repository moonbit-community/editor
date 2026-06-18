# renderer/core

Backend-neutral editor coordinate primitives.

## Responsibilities

- Own zero-based `Position` values.
- Own half-open UTF-16 offset `Range` values.
- Provide range normalization, containment, intersection, emptiness, and integer
  clamping helpers.

## Boundaries

- Must not depend on DOM, browser APIs, native APIs, workspace providers,
  server routing, syntax, language providers, or renderer/browser packages.
- Text ownership belongs in `renderer/model`; URI ownership belongs in
  `base/common`.

## Checks

- Package tests live in `position_range_test.mbt`.
- Run `moon test renderer/core` for focused coverage.

