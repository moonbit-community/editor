# renderer/view_layout

Pure common-layer layout and scroll state, the MoonBit-owned package boundary
for Monaco's `viewLayout`, `linesLayout`, scrollable state, scrollbar geometry,
viewport-window derivation, and view-zone layout slots.

## Responsibilities

- Own backend-neutral scroll truth: `Scrollable`, `ScrollDimensions`,
  `ScrollPosition`, and `ScrollChange`.
- Own uniform line layout and line-window derivation: `LinesLayout`,
  `LineWindow`, `visible_window`, and `window_needs_update`.
- Own pure scrollbar geometry through `ScrollbarState`.
- Own view-zone layout data (`ViewZone`) as common-layer model state. Browser
  DOM mounting for zones stays in `renderer/browser`.

## Boundaries

- May depend on `core`.
- Must not depend on `renderer`, `renderer/browser`, `dom`, `web`, server,
  transport, workspace, or host packages.
- Must not declare FFI.
- `ViewportData` remains in the parent `renderer` package until the remaining
  `RenderFrame`/`ViewModel` coupling is split enough to promote it cleanly.

## Checks

- Package tests live in `view_layout_test.mbt`, `view_window_test.mbt`, and
  `scrollbar_state_test.mbt`.
- Run `moon test --target js renderer/view_layout` and
  `moon test --target native renderer/view_layout` for this package.
