# viewer/common/inline_decorations

DOM-free port of Monaco's `vs/editor/common/viewModel/inlineDecorations.ts`.

- `InlineModelDecorationsComputer` queries model decorations, converts their
  ranges through a `CoordinatesConverter`, caches by decoration id, and groups
  regular/before/after/font-affecting decorations per view line. Call
  `on_model_decorations_changed` or `on_line_mapping_changed` at the matching
  invalidation boundary.
- `InjectedTextInlineDecorationsComputer` projects injected-text spans across
  wrapped lines.
- `InlineDecorationsModel`, `CoordinatesConverter`, and
  `InlineDecorationOptions` keep the computer generic. This package supplies the
  `TextModel` and `ModelDecorationOptions` implementations.
- The public shapes are `InlineDecoration`, `InlineDecorationType`,
  `ViewModelDecoration`, and `ViewDecorationsCollection`; `view_model` exposes
  specialized aliases for its decoration option type.

The deliberate Monaco deviation is
`hideInCommentTokens`/`hideInStringTokens`: the visibility predicate has no token
query seam, so those flags are not evaluated. The upstream conformance file ports
the 23 `inlineDecorations.test.ts` cases.

This package depends only on `base/common` and `viewer/common/model`, declares no
FFI, and is multi-target. See `pkg.generated.mbti`; run
`moon test --target js viewer/common/inline_decorations`.
