# viewer/browser/view_parts/margin

The line-number gutter view part, ported from Monaco's
`editor/browser/viewParts/margin/margin.ts`, plus the folding-marker render
from `editor/contrib/folding/browser/foldingDecorations.ts` (both write into
the same `.margin` DOM region, so this port keeps them in one package).

## Responsibilities

- `MarginViewOverlays`: the `.margin` container (folding-marker layer +
  line-number layer), its dirty flag, and the prepared render input for one
  frame. `pub(all)` for the same reason as
  `viewer/browser/view_parts/view_zones`'s types — its `ViewPart` trait impl
  lives in `viewer/browser/view/view_part.mbt`, not here.
- `render_line_numbers`: the line-number gutter recycler, mirroring
  `viewer/browser/view_parts/view_lines`'s text-line recycler (reuses its
  `viewport_window` / `write_line_number_node` / `line_node_style`).
- `render_folding_markers`: one clickable marker per foldable range's first
  view line, sourced from `viewer/contrib/folding` (the DOM-free folding
  model).

## Boundaries

- Does not implement the `ViewPart` trait here — see this refactor's
  cycle-backlog note in `docs/exec-plans/viewer-directory-mirror.md` and
  `viewer/browser/view_parts/view_zones/README.md`.
- Holds no `Viewer::` method: MoonBit forbids defining a method on a foreign
  type, so any `Viewer`-facing glue (the fold-toggle callback is threaded in
  as a plain closure) stays in the root `viewer` package.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*`, `viewer/contrib/folding`, `viewer/browser/view_parts/view_lines`,
  and `rabbita/dom`.
