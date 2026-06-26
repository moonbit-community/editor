# viewer/view_model

Pure common-layer view-model state, the MoonBit-owned package boundary for
Monaco's readonly `ViewModel`, `ViewModelLinesFromModelAsIs`,
`ViewModelLinesFromProjectedModel`, `CoordinatesConverter`, tokenized
model-line source data, and viewport-scoped render frames.

## Responsibilities

- Own per-version token buckets through `TokenizedDocument`.
- Own provider/decorator buckets through `FrameSource`.
- Own render-frame data: `FrameViewport`, `RenderSpan`, `RenderLine`, and
  `RenderFrame`.
- Own the readonly identity view model: `ViewModel`,
  `ViewModelLinesFromModelAsIs`, `ViewModelDecorations`,
  `CoordinatesConverter`, and `IdentityCoordinatesConverter`.
- Own projected view-line data for soft wrap through
  `ViewModelLinesFromProjectedModel`, `ModelLineProjection`,
  `ModelLineProjectionData`, and `LineBreaksComputer`.
- Own readonly folding normalization through `FoldingModel` and `HiddenRange`
  data; projected view lines consume hidden ranges so folded model lines produce
  no view lines while coordinates remain model-owned.
- Own readonly injected text through `InjectedText` and `ProjectedTextLine`.
  Inlay hints are projected before line breaking so hint width participates in
  wrapping, while render-line source mappings keep hit testing and decorations
  model-offset based.
- Own readonly `Selection` model ranges and copy helpers. Plain copy slices the
  selected `TextSnapshot` range directly, so browser-only injected text is
  excluded by default; rich copy has a model-only escaped fallback while the
  browser layer can decorate visible source spans with token classes.
- Own DOM-free conversion from `RenderLine` to
  `@view_line_renderer.ViewLineRenderingData` and `RenderLineInput`.

## Boundaries

- May depend on `base/common`, `viewer/model`, `syntax`, `viewer/decorations`,
  `language`, JSON support, and `viewer/view_line_renderer`.
- Must not depend on parent `viewer/common`, `viewer/view_layout`,
  `viewer`, `web`, server, transport, workspace, or host packages.
- Must not declare FFI.
- `ViewportData` lives in `viewer/view_layout`, which can depend on this
  package without a cycle.

## Conformance-only token ports (drift risk)

`LineTokens` / `SliceLineTokens` / `IViewLineTokens` (`line_tokens.mbt`),
`TokenMetadata` / `MetadataConsts` (`encoded_token_attributes.mbt`),
`RangePriorityQueueImpl` (`text_model_tokens.mbt`), and `text_to_html_tokenizer`
are **faithful 1:1 Monaco ports exercised only by their reference tests and each
other**. Production rendering ships the parallel `@syntax.Token` pipeline
(`TokenizedDocument` → `FrameSource` → `RenderFrame`) instead. The two are not
reconciled, so this faithful token subsystem can silently drift from the path
production actually renders — treat it as a Monaco oracle, not the live code.
Full reconciliation is a deferred token-model port (out of scope of
`docs/exec-plans/std-dedup-and-divergence-review.md`).

## Checks

- Package tests live in `tokenized_document_test.mbt`,
  `render_frame_test.mbt`, `view_model_test.mbt`, and
  `folding_model_test.mbt`, plus focused selection tests in
  `selection_test.mbt`.
- Run `moon test --target js viewer/view_model` and
  `moon test --target native viewer/view_model` for this package.
