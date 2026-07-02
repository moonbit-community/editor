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
  host packages such as the internal shell backend.

## Boundaries

- May depend on `base/common`, `viewer/common/model`, and JSON support.
- Must not import viewer browser implementation packages, DOM, native host
  packages, server packages, or any `internal/shell` package.
- Must not depend on source-provider payloads; host packages adapt them before
  semantic providers run.
- Browser and native transport effects are not part of the target public
  language-provider architecture.

## Checks

- Package tests live in `providers_test.mbt`.
- Run `just check` for the repository-level type check.
