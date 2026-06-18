# language

Readonly language-provider contracts.

## Responsibilities

- Define hover, diagnostic, definition, references, symbol, semantic-token,
  folding-range, inlay-hint, and provider result types.
- Define feature-specific semantic provider traits over readonly
  `@model.TextModel` inputs, `LanguageSelector` / `LanguageFilter` matching,
  and lightweight cancellation tokens for async provider calls. Pure
  tokenization remains snapshot-based outside this package.
- Keep hover contents limited to language-owned plaintext and markdown data;
  diagnostics are represented separately as markers in the viewer layer.
- Keep provider contracts backend-neutral; concrete semantic providers live in
  server or host packages.

Implementation note: current provider traits still take
`@workspace.DocumentSnapshot`. That is a temporary mismatch with the
Monaco-shaped model boundary, tracked by
`../docs/exec-plans/monaco-model-viewer-api.md`.

## Boundaries

- May depend on `base/common`, `viewer/model`, and JSON support.
- Must not import renderer backends, DOM, native host packages, or server
  packages.
- Must not depend on `workspace`; source-provider payloads are adapted by host
  packages before semantic providers run.
- Browser and native transport effects are not part of the target public
  language-provider architecture.

## Checks

- Package tests live in `providers_test.mbt`.
- Run `just check` for the repository-level type check.
