# Monaco-Faithful Selection Hit-Testing and Measurement

Status: planned.
Date: 2026-06-23.

## Summary

Replace the viewer's monospace-arithmetic selection geometry with Monaco's
DOM-as-source-of-truth model. Pointer-to-position resolution (the column under
the mouse) and position-to-pixel resolution (the rectangles the selection
overlay paints) both stop assuming a fixed glyph advance and instead read the
rendered DOM through the browser's caret and client-rect APIs, bridged back to
model columns by the per-line `CharacterMapping` we already compute but
currently discard.

This is the geometry rework only. Selection granularity (word/line/double- and
triple-click), drag autoscroll, shift-extend, and multi-cursor are explicit
non-goals here and are tracked as follow-ups in [Non-Goals](#non-goals).

Monaco references (design only; product code must not import them — see
`docs/references/monaco.md`):
- `vscode/src/vs/editor/browser/controller/mouseTarget.ts` —
  `MouseTargetFactory.doHitTest`, `_doHitTestWithCaretRangeFromPoint`,
  `_doHitTestWithCaretPositionFromPoint`, `HitTestResult.createFromDOMInfo`.
- `vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts` —
  `getVisibleRangesForRange`, `getColumnOfNodeOffset`, `CharacterMapping`.
- `vscode/src/vs/editor/browser/viewParts/viewLines/rangeUtil.ts` —
  `RangeUtil.readHorizontalRanges` (DOM `Range` + `getClientRects`).
- `vscode/src/vs/editor/browser/viewParts/selections/selections.ts` —
  `SelectionsOverlay`, `_getVisibleRangesWithStyle`,
  `_enrichVisibleRangesWithStyle`, `_actualRenderOneSelection`.
- `vscode/src/vs/editor/browser/view/renderingContext.ts` —
  `RenderingContext.linesVisibleRangesForRange`, `LineVisibleRanges`,
  `HorizontalRange`.

## Current Problems

Both the read path (pointer to column) and the write path (column to pixels)
hardcode a uniform `char_width` / `ch` model. The two are internally consistent
for plain ASCII in a monospace font and wrong for everything else.

- **Hit-testing is monospace arithmetic.** `viewer/common/mouse_target.mbt`
  computes `column = ((viewer_x - gutter_width) / char_width).to_int()`. It
  truncates instead of rounding to the nearest caret boundary (the persistent
  "off by one"), assumes every glyph is exactly `char_width` (tabs, CJK/wide
  characters, emoji, and ligatures all break it), and would be hopeless under a
  proportional font.
- **Horizontal scroll is ignored on hit-test.** `ViewMetrics` carries
  `scroll_top` but no `scroll_left`, and `hit_test` never adds horizontal
  scroll to `viewer_x`. Once content is scrolled horizontally, every resolved
  column is wrong. (Vertical is correct via `content_y = viewer_y +
  scroll_top`.)
- **Selection rendering reuses the same monospace assumption and is
  per-span.** `viewer/view_layer.mbt::append_line_selection_segments` emits one
  `.selected-text` div per intersecting span with `left:{col}ch;
  width:{n}ch`. This produces seams between spans, paints nothing on empty
  lines inside a multi-line selection, and never extends the highlight to the
  right edge to show that an included newline is part of the selection.
- **The produced `CharacterMapping` is thrown away.**
  `viewer/view_line_renderer/render_view_line2` already returns a
  `RenderLineOutput2 { html, character_mapping, ... }`, but
  `viewer/view_line.mbt::write_line_node` keeps only `.html`. The exact bridge
  Monaco uses for both hit-testing and measurement exists and is dropped on the
  floor.

## Why This Direction

Monaco never converts pixels to columns (or back) by arithmetic. It asks the
browser. The vertical axis (which line) is layout math; the horizontal axis
(which column, and where a column sits in pixels) is read from the rendered
DOM. That is the whole reason Monaco stays pixel-accurate across fonts, tabs,
ligatures, and proportional spacing, and it is the design this repo already
declares as its primary reference. We have the rendered span DOM and the
`CharacterMapping` to bridge it; the missing pieces are the two DOM read seams
(`caretRangeFromPoint`, `Range.getClientRects`) and the overlay rewrite.

## What Already Exists

- **DOM line structure suitable for caret hit-testing.** Each line node's
  `innerHTML` is `render_view_line2` output: a `.view-line-content` wrapper
  containing one `<span class="mtk…">` per token part
  (`viewer/view_line_renderer/render_line_renderer.mbt`). `caretRangeFromPoint`
  resolves into one of those text spans.
- **`CharacterMapping` (Monaco's role), fully ported.**
  `viewer/view_line_renderer/character_mapping.mbt` already implements
  `get_dom_position(column)`, `get_column(dom_position, part_length)`,
  `get_horizontal_offset`, and `set_column_info` — the same column to/from
  `(part_index, char_index)` bridge as Monaco's `CharacterMapping`. It is
  produced per line and currently discarded.
- **A `RenderingContext` analog.** `viewer/rendering_context.mbt` mirrors
  Monaco's render context but has no `lines_visible_ranges_for_range`
  measurement seam yet — that is the hook the overlay will call.
- **A retention site.** `viewer/view_layer.mbt::ViewLines` already keeps
  `line_nodes : Array[Element]` and `render_inputs` in lockstep with the
  viewport window; the per-line `CharacterMapping` belongs alongside them.
- **A pure hit-test that already owns the non-DOM parts.**
  `viewer/common/mouse_target.mbt` already resolves line number, gutter,
  view-zone bands, and below-content purely. We keep that and replace only the
  horizontal/column step.

## Target Design

Four roles, mapped onto existing packages. DOM-touching roles live in `viewer`
(which already declares JS FFI); pure roles stay in the common/renderer
packages and remain unit-testable.

| Monaco role | Target location | Nature |
| --- | --- | --- |
| `MouseTargetFactory.doHitTest` (pixel to position) | `viewer` (new `hit_test_dom.mbt`) + pure fallback in `viewer/common/mouse_target.mbt` | DOM |
| `getColumnOfNodeOffset` (DOM node/offset to column) | `viewer/view_line_renderer` (extend `CharacterMapping`) | pure |
| `RangeUtil.readHorizontalRanges` (column range to rects) | `viewer` FFI + `RenderingContext::lines_visible_ranges_for_range` | DOM |
| `SelectionsOverlay` (rects, rounding, EOL fill) | `viewer/view_overlays.mbt`, `viewer/view_layer.mbt`, `viewer/selections.css` | DOM/render |

Axis split (mirrors Monaco):
- **Vertical (line number):** stays pure. The existing view-zone/line math in
  `hit_test` resolves `line_number`, gutter hits, `BelowContent`, and
  `Outside`.
- **Horizontal (column):** becomes DOM-backed. `caretRangeFromPoint(x, y)`
  yields a text node + offset; we find its owning line node and token part
  index, read `char_index` from the offset, and call
  `CharacterMapping::get_column` to get the model column. Arithmetic remains
  only as the fallback when the caret API misses (clicks past end-of-line, in
  padding, or in browsers without the API) — Monaco keeps the same fallback.

## Implementation

### Phase 1: Retain the per-line CharacterMapping

- Switch `write_line_node` (`viewer/view_line.mbt`) to call
  `render_view_line2` once, write `.html`, and return its `character_mapping`.
- Add `line_mappings : Array[@view_line_renderer.CharacterMapping]` to
  `ViewLines` (`viewer/view_layer.mbt`), maintained in lockstep with
  `line_nodes` and `render_inputs` through every grow/shrink/splice path in
  `render_text`.
- Expose lookups keyed by view-line number:
  `ViewLines::line_node_at(line_number) -> Element?` and
  `ViewLines::mapping_at(line_number) -> CharacterMapping?`, both honoring the
  current `window` offset.

### Phase 2: DOM hit-testing (pixel to model position)

- Add `viewer/hit_test_dom.mbt` with FFI `caret_range_from_point` /
  `caret_position_from_point` (see [Phase 5](#phase-5-ffi-additions)) returning
  an opaque `(node, offset)` pair, plus helpers to read a node's parent span,
  its index among `.view-line-content` children (the part index), and its
  owning line node's `data-line`.
- New `Viewer::dom_column_for(view, line_number, x, y) -> Int?`:
  1. `caret_range_from_point` to a text node + offset.
  2. Walk to the enclosing token `<span>`; its sibling index within
     `.view-line-content` is `part_index`; the caret `offset` is `char_index`.
  3. `mapping.get_column({ part_index, char_index }, part_length)` for the
     one-based column; convert to the zero-based column the rest of the viewer
     uses.
- Rework the input path: `viewer/input.mbt` keeps using pure `hit_test` for
  kind/line/gutter/zones, then, when the kind is `ContentText`/`ContentEmpty`,
  refines the column via `dom_column_for`. On a caret-API miss, keep the pure
  arithmetic column (with the Phase-2.5 fixes below) so behavior degrades, not
  breaks.
- **Phase 2.5 (cheap correctness, lands with Phase 2):** in the arithmetic
  fallback only, round instead of truncate and add `scroll_left` to
  `ViewMetrics` and the `x` term, so the fallback is itself sane.

### Phase 3: DOM measurement seam (model range to pixel rects)

- Add FFI `read_horizontal_ranges(line_node, start_part, start_char, end_part,
  end_char, client_left)` that builds a DOM `Range` over the line's text nodes
  and returns merged `getClientRects()` as `Array[(left, width)]` in
  content-relative pixels (mirrors `RangeUtil.readHorizontalRanges`).
- Add `RenderingContext::lines_visible_ranges_for_range(range) ->
  Array[LineVisibleRanges]` (new `LineVisibleRanges { line_number, ranges:
  Array[HorizontalRange] }` types in `viewer/common` so they are shareable and
  testable). Per line it maps the clipped column range through the retained
  `CharacterMapping` to `(part, char)` endpoints, then calls
  `read_horizontal_ranges`.

### Phase 4: SelectionsOverlay rewrite

- Replace `append_line_selection_segments` /  `selection_segment_style`
  (`viewer/view_layer.mbt`) and `render_selection_overlays`
  (`viewer/view_overlays.mbt`) with a Monaco-shaped overlay:
  - Per visible line in the selection, paint **one merged rectangle per
    measured horizontal range** (not one per token span), eliminating seams.
  - For lines fully inside a multi-line selection, **extend to the right edge**
    by a constant so the included newline reads as selected (Monaco's
    end-of-line fill).
  - Paint a small stub on **empty lines** within the selection.
  - Port `_enrichVisibleRangesWithStyle` rounded-corner top/bottom styling so
    multi-line selections render with Monaco's corner treatment; gate it on a
    `rounded_selection` option mirroring `EditorOption.roundedSelection`.
- Update `viewer/selections.css` to the rect + rounded-corner classes; keep the
  `pointer-events: none` overlay and the existing selection background var.

### Phase 5: FFI additions

All new FFI lives in the `viewer` package (allowed to declare JS FFI; it
already does in `selection.mbt`/`input.mbt`). The third-party
`.mooncakes/.../rabbita/dom` binding is **not** edited.

- `caret_range_from_point` / `caret_position_from_point` (feature-detected;
  shadow-root aware like Monaco).
- `read_horizontal_ranges` returning a flat `Array[Double]` of `[left, width,
  …]` (MoonBit-friendly), reassembled on the MoonBit side.
- Small DOM walk helpers (`parent_span`, `child_index`, `closest_line_node`,
  `text_length`).

## Non-Goals

Tracked as separate follow-up plans; not in this rework:

- Selection granularity: double-click word and triple-click line selection.
- Drag autoscroll past the viewport edge (Monaco's `TopBottomDragScrolling`).
- Shift-click extend and keyboard selection.
- Multiple selections / multi-cursor (`Selection[]`).
- Block/column selection.

The selection model stays a single anchor/focus pair
(`viewer/view_model/selection.mbt`); only its geometry changes here.

## Tests

- **Pure unit tests** (`moon test`, both targets):
  - `viewer/view_line_renderer`: `CharacterMapping` column ↔ `(part, char)`
    round-trips, including tab parts, wide-character widths, and trailing
    empty/whitespace parts. Extend `character_mapping`-adjacent tests.
  - `viewer/common`: `LineVisibleRanges`/`HorizontalRange` clipping and merge
    math; rounded-corner enrichment decisions; arithmetic fallback rounding and
    `scroll_left` handling in `mouse_target_test.mbt`.
- **Browser conformance** (Playwright), modeled on
  `tests/browser/conformance/monaco_hover_scrollbar.spec.js` and its pinned
  fixture under `tests/reference/`:
  - New `selection_geometry.spec.js`: against a fixture containing tabs, a CJK
    run, and a ligature pair, assert (a) clicking at known pixel offsets
    resolves to the expected column, and (b) a multi-line selection paints
    contiguous rects with no inter-span gaps, empty-line stubs, and right-edge
    fill. Compare to transcribed Monaco geometry constants; product code still
    must not import the submodule.

## Validation

```sh
just check
just test
just build
just test-browser
```

## Acceptance Criteria

- Clicking anywhere on a line places the caret at the nearest character
  boundary (rounded, not truncated), including lines with tabs, CJK/wide
  characters, and ligatures.
- Hit-testing is correct under horizontal scroll.
- A drag selection paints one contiguous highlight per line (no inter-span
  seams), fills empty lines inside the selection, and extends included newlines
  to the right edge, with Monaco-style rounded corners when
  `rounded_selection` is on.
- Hit-testing and selection rendering both derive geometry from the rendered
  DOM via `CharacterMapping`, with the monospace path used only as a
  caret-API-miss fallback.
- The produced `CharacterMapping` is retained per rendered line and consumed by
  both the hit-test and measurement paths; no product code imports from
  `vscode/`.
- `just check && just test && just build && just test-browser` pass.
```
