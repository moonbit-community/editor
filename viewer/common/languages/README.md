# viewer/common/languages

The viewer's DOM-free language registry and token-to-HTML helpers.

## Registered features

- Ordered, disposable registries exist for hover and document symbols. Hover
  requests snapshot matching registrations before their first await, forward
  the caller's exact cancellation token, reject a result from a registration
  disposed during the await, and keep cancellation silent; ordinary provider
  failures are logged and contained. `hover_at` returns the first non-empty
  live result.
- `set_language_configuration` stores only the folding-rules slice of Monaco's
  `LanguageConfiguration`; region markers are whole-line predicates, not regular
  expressions.
- `set_tokens_provider` forwards to the process-wide
  `syntax.tokenization_registry`. Therefore tokenizer registrations remain global
  even when tests or embedders use an isolated `Languages::new()` instance.
- `tokenize_line_to_html` and `tokenize_to_string` port
  `vs/editor/common/languages/textToHtmlTokenizer.ts`.

There are currently no diagnostics, semantic-token, definition, or references
registries. Diagnostics use `viewer/common/markers`; definition/reference traits
remain host/protocol contracts in `language`.

`languages` is the process-wide instance used by default Viewer services;
`default_languages()` returns that same instance. The package has no viewer-root,
contribution, DOM, or host dependency. See `pkg.generated.mbti` for the complete
surface and run `moon test --target js viewer/common/languages`.
