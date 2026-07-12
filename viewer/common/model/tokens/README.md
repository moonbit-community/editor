# viewer/common/model/tokens

The model-owned grammar-tokenization part, state/backend machinery, attached-view
priority, host-neutral scheduler contract, syntactic font payloads, and fixed
syntax-theme mapping.

- `TokenizationTextModelPart` borrows a `TextModel`-owned
  `TokenizationModelAccess`. Its closures always read current normalized lines,
  language, attachment, large-file, disposal, scheduler, and reporting facts;
  this package never stores a copied document or imports its parent model.
- `get_line_tokens` and `token_count` are passive store reads. They return
  stored/default language-tagged tokens and never invoke the lexer. Explicit
  per-line force/cheap demand, stabilized or debounced visible refresh, and the
  attached background worker are the only lexer drivers.
- The state store tracks one-based carried end states and invalid ranges. The
  default worker schedules only while attached and a scheduler is present,
  yields between bounded slices, and cancels idle/zero/delayed callbacks by
  generation on final detach or disposal. Large models and missing/failing
  support retain passive defaults.
- `AttachedViews` owns identity and aggregate visible ranges; returned handles
  stay caller-owned. Stabilized updates refresh synchronously, while unstable
  updates use the exact 50 ms debounce.
- `annotations.mbt` owns the single syntactic font carrier forwarded unchanged
  through backend and model-part events. The semantic sparse overlay and visual
  font-decoration provider remain outside this package.
- `line_tokens_encoder.mbt` produces raw start-offset token words and converts
  them to end offsets exactly once. Raw UTF-16 lengths and offsets permit lone
  surrogate halves. `token_theme.mbt` maps `HighlightTag` to packed metadata and
  the generated `mtk*` style block.

The package is the readonly-applicable port of the pinned Monaco
`tokenizationTextModelPart.ts`, `abstractSyntaxTokenBackend.ts`,
`tokenizerSyntaxTokenBackend.ts`, and `textModelTokens.ts` units. It depends on
`base/common`, `syntax`, `viewer/common/services`, and `viewer/common/tokens`;
it must not import its parent model, view-model, DOM, or host packages. See
`pkg.generated.mbti`; run `moon test --target js viewer/common/model/tokens`.
