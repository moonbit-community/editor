# viewer/browser/view_parts/current_line_highlight

Mirrors `vscode/src/vs/editor/browser/viewParts/currentLineHighlight`
(content half of `CurrentLineHighlightOverlay`): the current-line highlight
divs, painted under the selection. The margin half lives in
`viewer/browser/view_parts/margin`; the DOM-free predicates and class
strings live in `viewer/common/view_layout`.

## Responsibilities

- `render_current_line`: the wrapped-line and exact passes appending
  highlight divs for one frame.
- `current_line_span`: the view-line span the highlight covers.

## Boundaries

- The `.view-overlays` container and its `ViewPart` shell belong to
  `view_parts/selections` (`ContentViewOverlays`) and
  `viewer/browser/view/view_part.mbt` respectively — the foreign-method rule
  keeps methods with their type's package, so this package exposes free
  functions the shell sequences (current-line → selection → decorations,
  Monaco's `view.ts:218-221` registration order).
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*` and `rabbita/dom`.
