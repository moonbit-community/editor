# viewer/common/view_model

Pure common-layer view-model state, the MoonBit-owned package boundary for
Monaco's readonly `ViewModel`, `ViewModelLines*`, `CoordinatesConverter`,
`ViewModelDecorations`, tokenized model-line source data, and viewport-scoped
render frames.

## Responsibilities

- Own per-version token buckets through `TokenizedDocument` and
  provider/decorator buckets through `FrameSource`.
- Own render-frame data: `FrameViewport`, `RenderLine`, and `RenderFrame`.
  Render lines carry token streams and injected inline decorations; the browser
  layer receives frame data rather than recomputing model state.
- Own the readonly view models: `ViewModel`, `ViewModelLinesFromModelAsIs`,
  `ViewModelLinesFromProjectedModel` (soft wrap: `ModelLineProjection`,
  `ModelLineProjectionData`, `LineBreaksComputer`), and the coordinates
  converters.
- Own `ViewModelDecorations`: model decorations resolved into per-view-line
  inline decorations through `viewer/common/inline_decorations`' computers,
  with this package providing the concrete model/converter trait impls.
- Own the hidden-area plumbing (`get_hidden_areas` over per-line hidden
  flags) and readonly injected text (`InjectedText`, `ProjectedTextLine`).
  Inlay hints are
  projected before line breaking so hint width participates in wrapping, while
  render-line source mappings keep hit testing and decorations
  model-offset based.
- Own readonly `Selection` model ranges and copy helpers. Plain copy slices the
  selected `TextSnapshot` range directly, so browser-only injected text is
  excluded by default; rich copy has a model-only escaped fallback while the
  browser layer styles visible source tokens with their token classes.
- Own the token metadata encoding (`LineTokens`, token-theme mapping in
  `token_theme.mbt`) and the DOM-free conversion from `RenderLine` to the
  renderer inputs in `viewer/common/view_layout`.

## Boundaries

- May depend on `base/common`, `viewer/common/model`,
  `viewer/common/inline_decorations`, `viewer/common/view_layout` (the layout
  and view-line-renderer layer below this one), `language`, `syntax`, and JSON
  support.
- Must not depend on the parent `viewer/common`, the root `viewer`, browser,
  server, transport, workspace, or host packages.
- Must not declare FFI.

## Token Model

`TokenizedDocument` stores `LineTokens` per model line. MoonBit lexer tokens are
encoded into Monaco-shaped metadata words, and render frames pass those token
streams to the view-line renderer.

Projected and injected view lines derive from the same token model. Inlay-hint
text is represented as inline decoration data, not as token color data.

Incremental/background retokenization and embedded-language token codecs are not
part of the current readonly viewer contract.

## Checks

- Local tests plus `*_reference_test.mbt` / `*_reference_wbtest.mbt`
  conformance ports (line tokens, line-breaks computer, text-model tokens).
- Run `moon test --target all viewer/common/view_model` for this package.
