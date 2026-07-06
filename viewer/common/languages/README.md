# viewer/common/languages

The viewer's language-feature registry: the MoonBit analog of Monaco's
`ILanguageFeaturesService` together with the relevant `vs/editor/common`
language-feature registries. Hosts register providers here; the viewer core and
the hover feature resolve them through it.

## Responsibilities

- `set_tokens_provider`, the `monaco.languages.setTokensProvider` analog: a
  thin forward into the process-wide `@syntax.tokenization_registry`, which
  `TextModel`'s tokenization part resolves languages through.
- `text_to_html_tokenizer.mbt`, the faithful
  `common/languages/textToHtmlTokenizer.ts` port (`tokenize_line_to_html`,
  `tokenize_to_string`).
- Ordered provider registries with disposal-safe registration for hover,
  diagnostics, document symbols, semantic tokens, and inlay
  hints, plus the per-feature resolution methods (`hover_at`,
  `diagnostics_for_model`, `document_symbols`, `semantic_tokens_for_model`,
  `inlay_hints_for_model`).
- The process-wide `languages` value (and `default_languages()`), which hosts
  register against and which `ViewerServices::new()` uses by default; tests and
  embedded viewers can pass an isolated `Languages::new()` instead. Tokenizer
  registrations are global even for isolated instances, as in Monaco.

## Boundaries

- Pure logic: no DOM, browser, or native FFI; builds on `js` and `native`.
- Depends on `base/common`, `language`, `platform/log`, `syntax`,
  `viewer/common/model`, `viewer/common/services`, and
  `viewer/common/tokens`.
- Depends on neither the root `viewer` package nor `viewer/contrib/hover`. The
  dependency edges are one-directional: `viewer -> viewer/common/languages` and
  `viewer/contrib/hover -> viewer/common/languages`.
