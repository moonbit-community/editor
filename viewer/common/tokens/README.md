# viewer/common/tokens

Immutable binary token shapes shared by model tokenization and view-line rendering.

- `LineTokens` mirrors Monaco's flat `Uint32Array`: each pair is an exclusive end
  offset followed by a packed metadata word. It provides token lookup, text/class/
  style reads, zero-copy slicing for wrapped lines, and `with_inserted` for injected
  text. `IViewLineTokens` is the common view implemented by full and sliced tokens.
- `encoded_token_attributes.mbt` defines the 32-bit language, standard-token-type,
  balanced-bracket, font-style, foreground, and background layout plus
  `TokenMetadata` decoders. Metadata is `UInt` because the background occupies the
  high byte.
- The package intentionally has no mutable contiguous/sparse token stores.
  `viewer/common/model/tokens` owns the readonly per-model memo, and semantic-token
  overlay is not implemented.

Upstream sources are `vs/editor/common/tokens/lineTokens.ts` and
`vs/editor/common/encodedTokenAttributes.ts`. The reduced `IViewLineTokens` omits
Monaco's concrete-type `equals`/codec accessor, and the unported `TokenArray` family
keeps `getTokensInRange` out of scope.

This package may depend only on `base/common` and `viewer/common/services`; it must
not import model, view-model, syntax, DOM, or host packages. See
`pkg.generated.mbti`; run `moon test --target js viewer/common/tokens`.
