# language

Readonly language-provider contracts.

## Responsibilities

- Define hover, diagnostic, definition, symbol, semantic-token, and provider
  result types.
- Define feature-specific semantic provider traits and the migration
  `LanguageProvider` aggregate.
- Keep the deterministic demo provider for local tests and fallback fixtures.

## Boundaries

- May depend on `core`, `workspace`, and JSON support.
- Must not import renderer backends, DOM, native host packages, or server
  packages.
- Browser and native transport effects are not part of the target public
  language-provider architecture.

## Checks

- Package tests live in `providers_test.mbt`.
- Run `just check` for the repository-level type check.
