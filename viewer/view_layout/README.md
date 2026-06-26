# viewer/view_layout

Pure common-layer layout and scroll state, the MoonBit-owned package boundary
for Monaco's `viewLayout`, `linesLayout`, scrollable state, scrollbar geometry,
viewport-window derivation, and readonly view-zone displacement.

## Responsibilities

- Own backend-neutral scroll truth: `Scrollable`, `ScrollDimensions`,
  `ScrollPosition`, and `ScrollChange`.
- Own line layout and line-window derivation. `LinesLayout` is a **faithful
  1:1 port of Monaco's `linesLayout.ts`** (`EditorWhitespace`, 1-based line
  numbers, whitespaces addressed by id/ordinal, padding, `changeWhitespace`/
  `onLinesDeleted`/`onLinesInserted`, viewport data) — see the conformance
  suite below. `ViewLayout` is the viewer's **zero-based view-zone adapter**
  over it: it maps `ViewZone { anchor_line, height_px }` onto whitespaces
  (`afterLineNumber = anchor_line`; zero-based line `L` ↔ Monaco 1-based
  `L + 1`) and exposes the zero-based `LineWindow`/`visible_window`/
  `window_needs_update`/`relative_vertical_offset_for_line`/`window_origin`
  surface the render path consumes. `LineWindow`, `visible_window`, and
  `window_needs_update` remain in `view_window.mbt`.
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

## Conformance

- `lines_layout_reference_test.mbt` is a faithful 1:1 port of Monaco's
  `linesLayout.test.ts` (all 12 `suite('Editor ViewLayout - LinesLayout')`
  cases), validating the production `LinesLayout` directly.
- **Deviation — uniform line heights.** The port drops Monaco's
  `LineHeightsManager` (variable line heights, the out-of-scope Conditional
  `lineHeights.test.ts` row); `accumulated_line_heights_including_line_number`
  collapses to `lineNumber * default_line_height`. Every `linesLayout.test.ts`
  case constructs the layout with empty `customLineHeightData` (`[]`), so this
  matches upstream exactly.
- The zero-based view-zone semantics live in the `ViewLayout` adapter and are
  pinned by `view_layout_test.mbt` (the migration's regression net), which
  preserved the prior behavior byte-for-byte.

## Checks

- Package tests live in `view_layout_test.mbt`, `view_window_test.mbt`,
  `scrollbar_state_test.mbt`, and `lines_layout_reference_test.mbt`, with
  viewport integration in `view_model_viewport_test.mbt`.
- Run `moon test --target js viewer/view_layout` and
  `moon test --target native viewer/view_layout` for this package.
