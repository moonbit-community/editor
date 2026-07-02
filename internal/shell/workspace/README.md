# workspace

Readonly source and tree provider contracts for host packages.

## Responsibilities

- Own `SourcePath`, `DocumentSnapshot`, `DocumentProvider`, language
  inference, filesystem-provider conversion, and document change events.
- Use `@base_common.Uri` for provider-minted document identity.
- Normalize root-relative paths and reject invalid or unsafe source paths.
- Define the backend-neutral `FileSystemProvider` trait, `DocumentContent`,
  read results, watch events, and structured provider errors.
- Define host-side composition contracts: `DocumentProvider`
  (document-level read/watch/close in `DocumentSnapshot` terms) and
  `WorkspaceTreeProvider` + `WorkspaceStat` (the `IFileStat`/
  `IFileService.resolve` copy: stats carry provider-minted URIs and children
  resolve lazily one level per request). Host packages adapt
  `DocumentSnapshot` values into `viewer/common/model.TextModel` before calling the
  viewer; the viewer core should not consume workspace payload types directly.

## Boundaries

- May depend on `base/common` and JSON support.
- Must not contain browser, native, DOM, server routing, or LSP process effects.
- Host packages implement filesystem behavior through the provider contract.
- Must not become the viewer model API. `DocumentSnapshot` is source-provider
  data; editor model identity belongs in `viewer/common/model`.

## Checks

- Package tests live in `source_test.mbt`.
- Run `just check` for the repository-level type check.
