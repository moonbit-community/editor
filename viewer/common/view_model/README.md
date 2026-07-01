# viewer/view_model

Pure common-layer view-model state, the MoonBit-owned package boundary for
Monaco's readonly `ViewModel`, `ViewModelLinesFromModelAsIs`,
`ViewModelLinesFromProjectedModel`, `CoordinatesConverter`, tokenized
model-line source data, and viewport-scoped render frames.

## Responsibilities

- Own per-version token buckets through `TokenizedDocument`.
- Own provider/decorator buckets through `FrameSource`.
- Own render-frame data: `FrameViewport`, `RenderLine`, and `RenderFrame`.
  Render lines carry token streams and injected inline decorations; the browser
  layer receives frame data rather than recomputing model state.
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
  browser layer styles visible source tokens with their token classes.
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

## Token Model

`TokenizedDocument` stores `LineTokens` per model line. MoonBit lexer tokens are
encoded into Monaco-shaped metadata words, and render frames pass those token
streams to `viewer/view_line_renderer`.

Projected and injected view lines derive from the same token model. Inlay-hint
text is represented as inline decoration data, not as token color data.

Incremental/background retokenization and embedded-language token codecs are not
part of the current readonly viewer contract.

## Checks

- Package tests live in `tokenized_document_test.mbt`,
  `render_frame_test.mbt`, `view_model_test.mbt`, and
  `folding_model_test.mbt`, plus focused selection tests in
  `selection_test.mbt`.
- Run `moon test --target js viewer/view_model` and
  `moon test --target native viewer/view_model` for this package.
