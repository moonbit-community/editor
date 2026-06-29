# Monaco `reveal*` Range API 1:1 Port

Status: proposed — Date: 2026-06-29.

Oracle: `vscode` submodule —
- `src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts` (public `reveal*`
  surface + `_sendRevealRange`).
- `src/vs/editor/browser/viewParts/viewLines/viewLines.ts`
  (`_computeScrollTopToRevealRange`, `_computeScrollLeftToReveal`,
  `_computeMinimumScrolling`, the `_horizontalRevealRequest` deferral).

Product code must not import from `vscode/` or `codemirror/`; the target is to
port behavior, constants, and state transitions into locally owned MoonBit.

## Problem

The viewer has only **pixel- and delta-based** scroll entry points
(`viewer/viewer.mbt:428`–`:468`): `scroll_to`, `scroll_to_position`,
`scroll_by_lines`, `scroll_by_pages`, `scroll_home`, `scroll_end`. There is no
**content-coordinate** scroll API — nothing takes a model `Position`/`Range`
("line 10, column 15") and computes the minimal scroll to bring it into view.

The 86 `reveal` hits in `viewer/` today are unrelated: scrollbar visibility
reveal (`reveal_scrollbars` / `reveal_for_scroll`, `vertical_revealed` in
`viewer/ui/scrollbar/scrollable_element.mbt`) and browser-driven reveal
(`hook_browser_desperate_reveal` in `viewer/controller/mouse_handler.mbt`).
Neither is the Monaco `revealPosition` / `revealLine` / `revealRange` family.

Consequence: callers that want "jump to line N" or "scroll the cursor into
view" have to do their own offset math against `vertical_offset_for_line` and
poke `scroll_to`, duplicating logic Monaco centralizes in one reveal pipeline.

## What already exists (reuse, do not rebuild)

| Need | Viewer piece | Location |
|---|---|---|
| Line → content-Y | `ViewLayout::vertical_offset_for_line` | `viewer/view_layout/view_layout.mbt:138` |
| Viewport box | `ViewLayout::dimensions()` (height) + `position()` (scroll_top/left) | `view_layout.mbt:235`, `:241` |
| Apply + clamp scroll | `ViewLayout::scroll_to(scroll_top~, scroll_left?)` → `Scrollable::set_position` clamps | `view_layout.mbt:210`, `viewer/view_layout/scrollable.mbt:98` |
| Repaint after scroll | `Viewer::apply_scroll_change` (sets `scroll_dirty`, `schedule_render`) | `viewer/viewer.mbt:518` |
| Model→view line/col | `coordinates_converter().model_position_to_view_position` / `model_range_to_view_range` | `viewer/view_model/view_model_lines_projected.mbt:122`, `:329` |
| Column → x box (horizontal) | `View::measure_line_selection(line, startCol, endCol) -> Array[(left,right)]` | `viewer/selection_measure.mbt:72` |
| Existing converter access pattern | `view_model.coordinates_converter()` used in `view_to_model` | `viewer/view_controller.mbt:180`–`:187` |

## Reference pipeline (grounded)

| Monaco file:line | Role |
|---|---|
| `codeEditorWidget.ts:654`–`:894` | Public `revealLine`/`revealLines`/`revealPosition`/`revealRange` + `*InCenter` / `*NearTop` / `*AtTop` / `*IfOutsideViewport` wrappers |
| `codeEditorWidget.ts:641` `_sendRevealRange` | `validateRange` → `convertModelRangeToViewRange` → `viewModel.revealRange(...)` |
| `viewLines.ts:269` `onRevealRangeRequest` | Computes `desiredScrollTop`; `-1` aborts; queues `_horizontalRevealRequest` for single-line; multi-line forces `scrollLeft=0` |
| `viewLines.ts:693` `_computeScrollTopToRevealRange` | The vertical math: box from view lines, padding, branch ladder per `VerticalRevealType` |
| `viewLines.ts:784` `_computeScrollLeftToReveal` | Horizontal math from `_visibleRangesForLineRange` (needs rendered line) |
| `viewLines.ts:838` `_computeMinimumScrolling` | Shared minimal-scroll-to-fit (`| 0` int truncation) |
| `viewLines.ts:305` `onScrollChanged` | Cancels the deferred horizontal request on user scroll |

`VerticalRevealType` variants used: `Simple`, `Center`, `CenterIfOutsideViewport`,
`NearTop`, `NearTopIfOutsideViewport`, `Top`, `Bottom`.

## Scope cuts (confirmed absent in the viewer — drop, don't invent)

1. **`scrollType` / smooth animation.** The viewer has no smooth-scroll concept
   (`grep` for `ScrollType`/`smooth` finds nothing in `viewer/`); every scroll
   is immediate. Port without the `scrollType` argument; all reveals are
   immediate. This also collapses Monaco's `getFutureViewport()`
   (`viewLines.ts:272`) to the current viewport.
2. **Scroll-off padding** (`cursorSurroundingLines`, sticky-scroll lines,
   `viewLines.ts:720`–`:736`) — no such config exists. Start with
   `paddingTop = paddingBottom = 0`. Keep only the behavioral `+1 line` bottom
   pad for `Simple`/`Bottom` (`viewLines.ts:737`–`:742`).
3. **`minimalReveal`, RTL, multi-selection reveal** — out of scope for v1.
   Reveal takes a single range/position only. (`revealRange` collapses to one
   `Range`; selections-based reveal is not exposed.)

## Ownership boundary

The vertical/horizontal *math* is pure model state and belongs in
`viewer/view_layout/` (alongside `ViewLayout`, which already owns
`vertical_offset_for_line` and the scroll truth). The **public API + model→view
conversion + DOM measurement + deferral** belong on `Viewer` (the role that
holds `view_model`, `layout`, and `view`). Keep the pure core free of any DOM /
`view_model` dependency so it stays `moon test`-able without a browser.

---

## Phase 0 — Types + module skeleton

- New file `viewer/view_layout/reveal.mbt`.
- `pub enum VerticalRevealType { Simple; Center; CenterIfOutsideViewport; NearTop; NearTopIfOutsideViewport; Top; Bottom }`
  (mirror Monaco's enum; omit the `Mouse`-only variant).
- No behavior yet — keeps the first behavioral diff reviewable.

## Phase 1 — Vertical reveal core (pure, unit-testable)

Port `_computeScrollTopToRevealRange` as a pure method on `ViewLayout`, in
**view** coordinates:

```
pub fn ViewLayout::compute_scroll_top_to_reveal(
  self, start_line : Int, end_line : Int, vertical_type : VerticalRevealType
) -> Double  // -1.0 sentinel = abort (oversized box), like Monaco's -1
```

- `box_start_y = vertical_offset_for_line(start_line)`,
  `box_end_y = vertical_offset_for_line(end_line) + line_height`
  (`viewLines.ts:712`–`:715`).
- Viewport from `position().scroll_top` + `dimensions().height`.
- Port the branch ladder verbatim: oversized box → top (`:748`); `NearTop`
  (20% / 5-line gap, `:760`–`:766`); `Center` (`:773`–`:775`); else
  `_computeMinimumScrolling` (`:838`).
- Add a private `compute_minimum_scrolling` helper. Decide once whether to
  replicate Monaco's `| 0` int truncation (`:839`–`:842`) for pixel-parity or
  keep full `Double`; record the choice inline.

**Tests** (`viewer/view_layout/view_layout_test.mbt` style — pure, no browser):
assert computed `scroll_top` for each `VerticalRevealType` against hand-computed
offsets, including the `-1.0` oversized-box abort. The suite there already drives
`scroll_to` with explicit pixel expectations — add a sibling block.

## Phase 2 — Public vertical API on `Viewer`

Add next to the existing `scroll_*` surface (`viewer/viewer.mbt:428`–`:468`):

```
pub fn Viewer::reveal_line(self, line_number : Int) -> Unit
pub fn Viewer::reveal_line_in_center(self, line_number : Int) -> Unit
pub fn Viewer::reveal_line_near_top(self, line_number : Int) -> Unit
pub fn Viewer::reveal_position(self, line_number : Int, column : Int) -> Unit   // + _in_center / _near_top
pub fn Viewer::reveal_range(self, range : <model range>) -> Unit                 // + _in_center / _near_top / _at_top / _if_outside_viewport
```

Internal `Viewer::send_reveal_range`, mirroring `_sendRevealRange`:
1. Convert model range → view range via
   `coordinates_converter().model_range_to_view_range` (the wrapping-aware
   step; access pattern already used at `view_controller.mbt:187`).
2. `scroll_top = layout.compute_scroll_top_to_reveal(view_start, view_end, type)`;
   if `-1.0`, abort (no scroll).
3. **Horizontal v1 rule** (Monaco `viewLines.ts:282`–`:289`): multi-line view
   range → `scroll_left = 0`; single-line → leave `scroll_left` unchanged
   (defer real horizontal reveal to Phase 3).
4. `apply_scroll_change(layout.scroll_to(scroll_top~, scroll_left?))` — clamping
   is free via `Scrollable`.

After Phase 2 the API is usable for "jump to line N" and line-level horizontal
reset.

## Phase 3 — Horizontal reveal (needs a rendered line)

Port `_computeScrollLeftToReveal` (`viewLines.ts:784`) using
`measure_line_selection(view_line, start_col, end_col)`:

- That helper returns `[]` when the line is not currently rendered (the
  `mapping_at` / `line_node_at` guards, `selection_measure.mbt:78`–`:82`) —
  exactly why Monaco defers via `_horizontalRevealRequest`.
- Box = `min(left)` / `max(right)` over returned rects + `HORIZONTAL_EXTRA_PX`
  / right padding (`viewLines.ts:821`–`:823`); then `_computeMinimumScrolling`
  horizontally.
- **Deferral**: store a `mut pending_horizontal_reveal` on `Viewer` (or `View`).
  After the vertical scroll triggers repaint and the target line renders, flush
  it in the post-render step (`viewer/view.mbt:286` `flush_render`). Cancel it
  if the user scrolls in between — port `onScrollChanged` (`viewLines.ts:305`–
  `:315`): drop on `scroll_left` change, or when `scroll_top` leaves the
  `[start_scroll_top, stop_scroll_top]` band.

**Tests**: browser-only (`just test-browser`). Horizontal reveal depends on real
DOM client-rect measurement; per
`docs/exec-plans/monaco-arch-divergence-closeout.md` and the project notes,
view-axis regressions are caught only by the browser suite.

## Phase 4 — Host wiring (optional, only when a caller needs it)

Expose through the workbench host the same way `scroll_to` is wired
(`internal/shell/workbench/app.mbt:223`,
`internal/shell/workbench/browser_host.mbt:74`) if an external "go to line"
trigger needs it. Not required for the editor-internal API.

---

## Risks / watch-items

- **Model vs view coordinates.** The pure core works in *view* lines; with
  word-wrap on, model line ≠ view line. Conversion must happen at the `Viewer`
  boundary (Phase 2, step 1), never inside the core.
- **`-1.0` abort sentinel.** Monaco's `-1` means "don't scroll" (oversized box /
  multi-cursor). Preserve it; do not clamp it to a real offset or reveals jump
  wrongly.
- **Horizontal deferral lifetime.** The pending request is the only stateful
  piece. Get the cancel conditions right or a stale reveal fires after an
  unrelated scroll.
- **`| 0` truncation.** Pick replicate-for-parity vs. full-`Double` once and
  apply consistently across vertical + horizontal `compute_minimum_scrolling`.

## Suggested commit slicing

1. `reveal: VerticalRevealType + compute_scroll_top core + unit tests` (Phase 0–1)
2. `reveal: Viewer vertical reveal API` (Phase 2)
3. `reveal: horizontal reveal w/ deferred request` (Phase 3)
4. `reveal: workbench host wiring` (Phase 4, optional)

Each phase is independently testable; Phases 0–2 need no browser.
