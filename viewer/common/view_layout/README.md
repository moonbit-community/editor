# viewer/common/view_layout

Pure common-layer layout, scroll state, and the view-line renderer: the
MoonBit-owned package boundary for Monaco's `viewLayout`, `linesLayout`,
scrollable state, scrollbar geometry, reveal math, view-zone layout, and
`viewLineRenderer` (the renderer package was merged in here).

## Responsibilities

- Own backend-neutral scroll truth: `Scrollable`, `ScrollDimensions`,
  `ScrollPosition`, and `ScrollChange`, plus the reveal-range math.
- Own line layout and line-window derivation. `LinesLayout` is the
  Monaco-shaped line/whitespace layout primitive; `ViewLayout` adapts it to the
  viewer's viewport, view-zone, and scroll-window needs.
- Own the DOM-free view-line renderer: `RenderLineInput` becomes escaped line
  HTML plus `CharacterMapping`/`DomPosition` data, with inline/line decoration
  normalization and current-line highlight logic.
- Own pre-DOM viewport data (`ViewportData`, `ViewZoneViewportData`) and pure
  scrollbar geometry (`ScrollbarState`).
- Own view-zone layout data (`ViewZone`) as common-layer model state. Browser
  DOM mounting and the change accessor stay with the viewer packages.

## Boundaries

- Depends only on `base/common`. This is the bottom layer of the viewer common
  tier: `viewer/common/view_model` and the browser packages build on it.
- Must not depend on `viewer/common`, `viewer/common/view_model`, the root
  `viewer`, browser, server, transport, workspace, or host packages.
- Must not declare FFI.

## Checks

- Local tests plus `*_reference_test.mbt` conformance ports (`linesLayout`,
  `viewLineRenderer`, prefix-sum computer, current-line highlight).
- The current viewer assumes uniform line heights; variable line-height support
  is outside the readonly contract.
- Run `moon test --target all viewer/common/view_layout` for this package.
