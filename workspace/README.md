# workspace

Readonly source identity and filesystem-provider contracts.

## Responsibilities

- Own `DocumentUri`, `SourcePath`, `SourceDocument`, language inference, and
  snapshot conversion.
- Normalize root-relative paths and reject invalid or unsafe source paths.
- Define the backend-neutral `FileSystemProvider` trait, read results, watch
  events, and structured provider errors.

## Boundaries

- May depend on `core`.
- Must not contain browser, native, DOM, server routing, or LSP process effects.
- Host packages implement filesystem behavior through the provider contract.

## Checks

- Package tests live in `source_test.mbt`.
- Run `just check` for the repository-level type check.
