# viewer/common/tokens

The binary token data structures. Mirrors Monaco's `editor/common/tokens/`.

## Responsibilities

- Own `LineTokens` / `SliceLineTokens` / the `IViewLineTokens` trait
  (`tokens/lineTokens.ts`): a line's tokens as a flat `[endOffset, metadata]`
  pair array over the line text, with slicing for wrapped view lines and
  `with_inserted` for injected text.
- Own the encoded token attributes (`encodedTokenAttributes.ts`): the
  `MetadataConsts` bit layout, `FontStyle`/`ColorId`/`StandardTokenType`
  constants, and the `TokenMetadata` decoders. Monaco keeps that file at the
  `editor/common/` root; it lives here because the `viewer/common` root
  package sits above this code in the import graph (see the file header).

The mutable stores built on these shapes (`contiguousTokensStore.ts`,
`sparseTokensStore.ts`) are N-A: the readonly viewer's per-model store is the
immutable memo in `viewer/common/model/tokens`.

## Boundaries

- May depend only on `base/common` and `viewer/common/services` (the
  `LanguageIdCodec` the token words reference).
- Must not depend on the model, view model, syntax, DOM, or host packages.

## Checks

- `line_tokens_reference_wbtest.mbt`, the faithful port of Monaco's
  `lineTokens.test.ts` suite.
- Run `moon test --target all viewer/common/tokens` for this package.
