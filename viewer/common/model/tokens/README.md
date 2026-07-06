# viewer/common/model/tokens

The model-facing tokenization part. Mirrors Monaco's
`editor/common/model/tokens/`.

## Responsibilities

- Own `TokenizationTextModelPart`, the readonly subset of Monaco's
  `TokenizationTextModelPart` merged with its grammar backend
  `TokenizerSyntaxTokenBackend` and the state-threading sweep of
  `TokenizerWithStateStore`: one lazy memoized whole-document sweep that
  resolves the language through `@syntax.tokenization_registry`, threads
  `TokenizerState` line to line, and answers `get_line_tokens(line_number)`
  per one-based model line. `TextModel` constructs and owns it as its
  `tokenization` field.
- Own the lexer-output encoding: `line_tokens_from_lexer_tokens`
  (`line_tokens_encoder.mbt`) turns line-local `@syntax.LineToken`s into the
  binary `LineTokens` store, and `token_theme.mbt` maps `HighlightTag`s to
  packed metadata words and the `mtk<colorId>` color map.

Deviations from Monaco (all consequences of the readonly `TextModel`) are
listed in `tokenization_text_model_part.mbt`'s header: frozen-line-array
construction, no background tokenizer, viewer-relayed registry-change resets,
no semantic-token overlay.

## Boundaries

- May depend on `base/common`, `syntax` (the tokenization contract and
  registry), `viewer/common/services`, and `viewer/common/tokens`.
- Must not depend on `viewer/common/model` (the part is constructed from line
  text precisely so `TextModel` can own it without a package cycle), the view
  model, DOM, or host packages.

## Checks

- `tokenization_text_model_part_wbtest.mbt` (state threading, language-id
  round-trips, reset/memoization) and `line_tokens_encoder_wbtest.mbt`
  (gap/trailing fills, clamping) plus `token_theme_wbtest.mbt`.
- Run `moon test --target all viewer/common/model/tokens` for this package.
