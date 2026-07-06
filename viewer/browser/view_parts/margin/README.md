# viewer/browser/view_parts/margin

The line-number gutter view part, ported from Monaco's
`editor/browser/viewParts/margin/margin.ts`, plus the margin
half of `viewParts/currentLineHighlight/currentLineHighlight.ts` (both write
into the same `.margin` DOM region, so this port keeps them in one package).

## Responsibilities

- `MarginViewOverlays`: the `.margin` container (line-number layer and
  friends), its dirty flag, and the prepared render input for one frame.
- `render_line_numbers`: the line-number gutter recycler, mirroring
  `viewer/browser/view_parts/view_lines`'s text-line recycler (reuses its
  `viewport_window` / `write_line_number_node` / `line_node_style`).
- The margin current-line highlight.

## Boundaries

- The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, the
  trait-owning package — see its README for the orphan-rule/cycle reasoning.
  That is also why the types here are `pub(all)`.
- Holds no `Viewer::` method.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*`, `viewer/browser/view_parts/view_lines`, and `rabbita/dom`.
