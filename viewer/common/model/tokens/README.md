# viewer/common/model/tokens

The model-owned grammar-tokenization part and fixed syntax theme mapping.

- `TokenizationTextModelPart` is constructed from a frozen line array and language
  id. First token read (or `force_tokenization`) resolves the global syntax
  registry, threads `TokenizerState` through every line, encodes `LineTokens`, and
  memoizes the whole document. A missing tokenizer produces one language-tagged
  default token per line.
- Re-registering the model's language clears the memo and emits one token-change
  range covering the document. `dispose` removes the registry subscription and
  listeners.
- `line_tokens_from_lexer_tokens` fills lexer gaps/trailing text and clamps input
  spans before encoding. `token_theme.mbt` maps `HighlightTag` to Monaco metadata,
  the fixed color map, and the generated `mtk*` style block.

This combines the readonly portions of the pinned
`src/vs/editor/common/model/tokens/tokenizationTextModelPart.ts`,
`tokenizerSyntaxTokenBackend.ts`, and the state store in
`model/textModelTokens.ts`. There is no per-line/background retokenization,
mutable-text convergence scheduling, or semantic-token `SparseTokensStore` overlay.

The package depends on `base/common`, `syntax`, `viewer/common/services`, and
`viewer/common/tokens`; it must not import its parent model, view-model, DOM, or
host packages. See `pkg.generated.mbti`; run
`moon test --target js viewer/common/model/tokens`.
