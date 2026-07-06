# viewer/common/view_model

Pure common-layer view-model state, the MoonBit-owned package boundary for
Monaco's readonly `ViewModel`, `ViewModelLines*`, `CoordinatesConverter`,
`ViewModelDecorations`, and viewport-scoped render frames.

## Responsibilities

- Own `FrameSource` (the backing `TextModel` plus pushed provider data —
  tokens live on `model.tokenization`, Monaco's `TokenizationTextModelPart`
  in `viewer/common/model/tokens`).
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
- Own the DOM-free conversion from `RenderLine` to the renderer inputs in
  `viewer/common/view_layout`. The token store itself lives below this
  package: `LineTokens`/metadata words in `viewer/common/tokens`, the
  tag-to-metadata theme mapping in `viewer/common/model/tokens`.

## Boundaries

- May depend on `base/common`, `viewer/common/model`,
  `viewer/common/inline_decorations`, `viewer/common/tokens`,
  `viewer/common/view_layout` (the layout and view-line-renderer layer below
  this one), `language`, and JSON support.
- Must not depend on the parent `viewer/common`, the root `viewer`, browser,
  server, transport, workspace, or host packages.
- Must not declare FFI.

## Token Model

Render frames read `model.tokenization.get_line_tokens` — the memoized
per-line `LineTokens` store owned by the model's tokenization part
(`viewer/common/model/tokens`) — and pass those token streams to the
view-line renderer.

Projected and injected view lines derive from the same token model. Inlay-hint
text is represented as inline decoration data, not as token color data.

Incremental/background retokenization and embedded-language token codecs are not
part of the current readonly viewer contract.

## Checks

- Local tests plus `*_reference_test.mbt` / `*_reference_wbtest.mbt`
  conformance ports (line-breaks computer; the line-tokens and
  text-model-tokens conformance ports live in `viewer/common/tokens` and
  `viewer/common/model` since the three-way split).
- Run `moon test --target all viewer/common/view_model` for this package.
