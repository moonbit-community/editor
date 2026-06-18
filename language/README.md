# language

Readonly language-provider contracts.

## Responsibilities

- Define hover, diagnostic, definition, references, symbol, semantic-token,
  folding-range, inlay-hint, and provider result types.
- Define feature-specific semantic provider traits over
  `@workspace.DocumentSnapshot`, `LanguageSelector` / `LanguageFilter`
  matching, and lightweight cancellation tokens for async provider calls.
- Keep hover contents limited to language-owned plaintext and markdown data;
  diagnostics are represented separately as markers in the viewer layer.
- Keep provider contracts backend-neutral; concrete semantic providers live in
  server or host packages.

## Boundaries

- May depend on `base/common`, `workspace`, and JSON support.
- Must not import renderer backends, DOM, native host packages, or server
  packages.
- Browser and native transport effects are not part of the target public
  language-provider architecture.

## Checks

- Package tests live in `providers_test.mbt`.
- Run `just check` for the repository-level type check.
