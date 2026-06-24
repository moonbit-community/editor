# viewer/view_layout

Pure common-layer layout and scroll state, the MoonBit-owned package boundary
for Monaco's `viewLayout`, `linesLayout`, scrollable state, scrollbar geometry,
viewport-window derivation, and readonly view-zone displacement.

## Responsibilities

- Own backend-neutral scroll truth: `Scrollable`, `ScrollDimensions`,
  `ScrollPosition`, and `ScrollChange`.
- Own uniform line layout and line-window derivation: `LinesLayout`,
  `LineWindow`, `visible_window`, and `window_needs_update`. `LinesLayout`
  also owns readonly view-zone displacement for content height, line vertical
  offsets, viewport-window derivation, and viewport zone data.
- Own pre-DOM viewport data: `ViewportData` converts `ViewModel`/`RenderFrame`
  data plus layout windows into visible `ViewLineRenderingData` and line
  decorations, including `ViewZoneViewportData` for zones intersecting the
  rendered window.
- Own pure scrollbar geometry through `ScrollbarState`.
- Own view-zone layout data (`ViewZone`) as common-layer model state. Browser
  DOM mounting and the add/update/remove accessor stay in `viewer`.

## Boundaries

- May depend on `base/common`, `viewer/model`, `syntax`, `viewer/decorations`,
  `language`, `viewer/view_line_renderer`, and `viewer/view_model`.
- Must not depend on `viewer/common`, `viewer`, `web`, server, transport,
  workspace, or host packages.
- Must not declare FFI.
- Browser DOM mounting and event handling stay in `viewer`.

## Checks

- Package tests live in `view_layout_test.mbt`, `view_window_test.mbt`, and
  `scrollbar_state_test.mbt`, with viewport integration in
  `view_model_viewport_test.mbt`.
- Run `moon test --target js viewer/view_layout` and
  `moon test --target native viewer/view_layout` for this package.
