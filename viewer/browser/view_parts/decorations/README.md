# viewer/browser/view_parts/decorations

Mirrors `vscode/src/vs/editor/browser/viewParts/decorations`
(`DecorationsOverlay`): whole-line and inline decoration rectangles,
including the marker squiggles, rendered as flat `div.cdr` pieces.

## Responsibilities

- The pure piece computation (`compute_decoration_overlay_pieces`):
  filter/sort, whole-line spans, same-class touching merge,
  `showIfCollapsed` widening, `shouldFillLineOnLineBreak` expansion.
- The DOM half (`render_decorations_overlay`), appending pieces to the
  shared `.view-overlays` container.

## Boundaries

- The `.view-overlays` container and its `ViewPart` shell belong to
  `view_parts/selections` (`ContentViewOverlays`) and
  `viewer/browser/view/view_part.mbt` respectively — the foreign-method rule
  keeps methods with their type's package, so this package exposes free
  functions the shell sequences (current-line → selection → decorations,
  Monaco's `view.ts:218-221` registration order).
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*` and `rabbita/dom`.
