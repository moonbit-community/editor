# renderer/view_model

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
- Own DOM-free conversion from `RenderLine` to
  `@view_line_renderer.ViewLineRenderingData` and `RenderLineInput`.

## Boundaries

- May depend on `core`, `syntax`, `decorations`, `language`, JSON support, and
  `renderer/view_line_renderer`.
- Must not depend on parent `renderer`, `renderer/view_layout`,
  `renderer/browser`, `dom`, `web`, server, transport, workspace, or host
  packages.
- Must not declare FFI.
- `ViewportData` lives in `renderer/view_layout`, which can depend on this
  package without a cycle.

## Checks

- Package tests live in `tokenized_document_test.mbt`,
  `render_frame_test.mbt`, and `view_model_test.mbt`.
- Run `moon test --target js renderer/view_model` and
  `moon test --target native renderer/view_model` for this package.
