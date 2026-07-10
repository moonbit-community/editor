# viewer/common/view_model

Long-lived, DOM-free projection from a `TextModel` to renderable view lines.

## Pipeline and API

`ViewModel` owns the model, projected line collection, single cursor,
`ViewLayout`, decoration resolver, coordinate converter, and per-source hidden-area
sets. It is created once when a model attaches and updated in place.

```text
model line + grammar tokens + injected-text decorations
  -> ProjectedTextLine
  -> soft-wrap ModelLineProjection segments
  -> hidden-area filtering
  -> ViewLineData + model/view coordinate conversion
  -> viewport_data_from_view_model -> view_layout.ViewportData
```

- `ViewModelLinesFromProjectedModel` is always used. With wrapping disabled each
  line has a cheap identity projection; there is no separate
  `ViewModelLinesFromModelAsIs` implementation.
- Injected text is projected before line breaking, so its width affects wrapping;
  source mappings, tokens, and decorations remain anchored to model offsets.
- Configuration or injected-text/content flushes reproject affected state at the
  current whole-model granularity, invalidate decoration caches, and reproject the
  cursor from model coordinates. Incremental edit events are not part of the
  readonly contract.
- `set_hidden_areas` merges ranges by source, updates line/layout/decorations/cursor,
  and preserves the top visible model line when folding changes above the viewport.
- `ViewModelDecorations` converts model ranges through
  `viewer/common/inline_decorations` and resolves only the requested viewport.

There are no `FrameSource`, `FrameViewport`, `RenderLine`, or `RenderFrame` APIs;
browser code consumes `ViewModel` plus `view_layout.ViewportData`. Selection/copy
helpers belong to `viewer/common/core` and the root `viewer`, not this package.

The upstream map is the pinned `src/vs/editor/common/viewModel/` files
`viewModelImpl.ts`, `viewModelLines.ts`, `modelLineProjection.ts`,
`monospaceLineBreaksComputer.ts`, and `viewModelDecorations.ts`, plus
`viewLayout/viewLinesViewportData.ts`.
This package must remain multi-target and FFI-free, with no root-viewer, browser,
server, transport, workspace, or host dependency. See `pkg.generated.mbti`; run
`moon test --target js viewer/common/view_model`.
