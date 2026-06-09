# language

Readonly language-provider contracts and LSP client behavior.

## Responsibilities

- Define hover, diagnostic, definition, symbol, semantic-token, and provider
  result types.
- Define the `LanguageProvider` trait and deterministic demo provider.
- Own the readonly LSP client, transport trait, request/notification flow, and
  conversion of LSP responses into provider results.

## Boundaries

- May depend on `core`, `workspace`, and JSON support.
- Must not import renderer backends, DOM, native host packages, or server
  packages.
- Transport effects are supplied through `LspTransport`; this package owns
  client state and protocol interpretation.

## Checks

- Package tests live in `providers_test.mbt` and `lsp_wbtest.mbt`.
- Run `just check` for the repository-level type check.
