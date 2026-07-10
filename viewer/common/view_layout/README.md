# viewer/common/view_layout

DOM-free scrolling, line/whitespace layout, view zones, and view-line rendering.

## Responsibilities

- `Scrollable` owns scroll dimensions and position; `ScrollbarState` contains the
  pure slider geometry. `ViewLayout` is the viewer's single scroll truth and
  computes visible/completely-visible windows and reveal positions.
- `LinesLayout`, prefix-sum computers, and whitespace accessors map line/view-zone
  heights to vertical offsets. The current viewer assumes one uniform view-line
  height; variable line heights are outside the readonly contract.
- `render_view_line*` converts `RenderLineInput` into escaped HTML plus
  `CharacterMapping`/`DomPosition`, preserving the source-to-DOM mapping used by
  hit testing and selections. This package also owns decoration normalization and
  current-line-highlight decisions.
- `ViewportData`, `ViewLineRenderingData`, and view-zone viewport shapes live here
  as dependency-bottom data. Their model-dependent factory is
  `view_model.viewport_data_from_view_model`, keeping the dependency one-way.
- `ViewZone` is layout state only; browser DOM mounting and the public change
  accessor live above this package.

The Monaco map is the pinned `src/vs/editor/common/viewLayout/{viewLayout,
linesLayout,viewLinesViewportData,viewLineRenderer}.ts`,
`src/vs/base/common/scrollable.ts`, and the base browser scrollbar state.

This package depends only on `base/common`, declares no FFI, and must not import
view-model, root viewer, browser, server, transport, workspace, or host packages.
See `pkg.generated.mbti`; run
`moon test --target js viewer/common/view_layout`.
