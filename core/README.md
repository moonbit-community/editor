# core

Shared document primitives for the readonly editor.

## Responsibilities

- Own immutable `DocumentSnapshot` values.
- Define UTF-16 offsets, positions, ranges, and line indexing helpers.
- Provide small, backend-neutral utilities used by higher-level packages.

## Boundaries

- Has no product package dependencies.
- Must not know about workspaces, language providers, rendering, host effects,
  browser APIs, or native APIs.
- Offsets and columns follow the repository-wide UTF-16 convention in
  `../docs/architecture.md`.

## Checks

- Package tests live in `document_test.mbt`.
- Run `just check` for the repository-level type check.
