# viewer/browser/view_parts/view_lines

The text-line view part, ported from Monaco's
`editor/browser/viewParts/viewLines/viewLines.ts` (`ViewLines`, the recycler)
and `viewLine.ts` (per-line render input + DOM write). Both Monaco files merge
into this one package since `viewLine.ts` has no consumer besides `ViewLines`.

## Responsibilities

- `ViewLines`: the `.view-lines` container, the rendered-window recycler
  (`render_text` — splices entering/leaving line nodes, rewrites `innerHTML`
  only on entering lines or a changed content generation), and the retained
  `CharacterMapping`s hit-testing and selection measurement read off it.
  `pub(all)` for the same reason as `viewer/browser/view_parts/view_zones`'s
  types — its `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, not here.
- `write_line_number_node` / `line_node_style` / `is_first_view_line_for_model_line`:
  `pub` — also used by `viewer/margin.mbt`'s line-number gutter and
  folding-marker render, which position their nodes the same way `ViewLines`
  positions text lines.

## Boundaries

- Does not implement the `ViewPart` trait here — see this refactor's
  cycle-backlog note in `docs/exec-plans/viewer-directory-mirror.md` and
  `viewer/browser/view_parts/view_zones/README.md`.
- Holds no `Viewer::` method: MoonBit forbids defining a method on a foreign
  type, so any `Viewer`-facing glue stays in the root `viewer` package.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*` and `rabbita/dom`, nothing else.
