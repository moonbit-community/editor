# viewer/folding

Backend-neutral folding model for the readonly viewing path. A port of the pure
parts of Monaco's `contrib/folding/`, reduced to what a readonly viewer needs.

## Responsibilities

- The folded-range set operations the folding controller drives:
  `toggled_folded_ranges` (toggle one range), `preserved_folded_ranges` (drop
  ranges that are no longer foldable after a ranges update),
  `folding_range_for_start_line` / `is_line_folded` (the gutter/margin lookups).
- `fallback_folding_ranges`: the indentation/brace heuristic used to derive
  folding ranges from the model text when no provider supplies them (today only
  MoonBit).
- Faithful Monaco ports backing the conformance suites: `FoldingRegions` /
  `FoldRange` / `FoldSource` (range storage, parent computation, `find_range`,
  `sanitize_and_merge`), and `RangesCollector` / `compute_ranges` (the
  indentation + fold-marker range computation, with `FoldingMarkers` modelled
  as matcher closures since there is no regex engine).

The browser-side folding *controls* — the gutter toggle, `Viewer::toggle_fold`,
`Viewer::set_folding_ranges`, and the re-render — stay on the viewer, which owns
the DOM and the editor state. This package is the pure model those controls
operate on.

## Boundaries

- Pure logic: no DOM, browser, or native FFI; builds on `js` and `native`.
- Depends only on `language` (`FoldingRange`) and `viewer/model` (`TextModel` /
  `TextSnapshot`, for the fallback computation).
- Depends on neither the `viewer` browser package nor any other view part. The
  dependency edge is one-directional: `viewer -> viewer/folding`.
