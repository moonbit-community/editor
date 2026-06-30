# Monaco `CodeEditorWidget` Read-API 1:1 Port

Status: **landed** — Date: 2026-06-29. Oracle commit: `294fb350837dbaee37b949533fead4df4e0e8971`.
All four phases implemented; every parity-ledger row is `PASS`. See the
Phase-5 reconciliation at the end.

Follows `_PORT_PLAYBOOK.md` (inventory-first; copy don't invent; exit gate).
Product code must not import from `vscode/` or `codemirror/`; the target is to
port behavior, constants, delegation, and sentinels into locally owned MoonBit.

## Problem

The viewer's public surface is write-/command-heavy: `reveal_*` (14 fns),
`scroll_*`, `set_model`, options, and `on_did_*` observers. The **read side is
`get_model` / `current_model` only** (`viewer/viewer.mbt:342`, `:348`). An
embedder can scroll and reveal but cannot *ask* the viewer anything: where the
viewport is, what's on screen, where a model position lands in pixels, or what's
selected. Monaco centralizes exactly these queries on `CodeEditorWidget` as a
cluster of `get*` delegators over `ViewModel` / `ViewLayout` / `View` — all
backing pieces the viewer already owns. This port exposes that cluster.

## Scope (Phase 0)

Source unit: the **read-only state-query getter cluster of
`vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts`** (the
viewport / scroll / vertical-offset / coordinate / selection / value getters),
plus the backing methods they delegate to in
`vscode/src/vs/editor/common/viewModel/viewModelImpl.ts` and
`vscode/src/vs/editor/browser/view.ts`.

The denominator is the full public `get*`/`has*` surface of `codeEditorWidget.ts`
(44 members, grepped below). In-scope is the read-state subset; every other
member is named out-of-scope with a reason — none is left "unseen".

### Out of scope (named sibling clusters — explicitly **not** this port)

- **Write/mutate:** `setValue`, `setModel`, `setPosition`, `setSelection`,
  `setHiddenAreas`, `_sendRevealRange`, `resetLineWidthCaches` — not getters.
- **Options:** `getOptions`, `getOption`, `getRawOptions`,
  `getConfiguredWordAtPosition` — config surface, separate port.
- **Identity / DOM nodes:** `getId`, `getEditorType`, `getDomNode`,
  `getContainerDomNode`, `getOverflowWidgetsDomNode` — host seam, trivial later.
- **Contributions / actions:** `getContribution`, `getActions`,
  `getSupportedActions`, `getAction` — the viewer has no contribution registry
  yet (the controller-contribution inversion is a separate tracked follow-up).
- **Decoration query:** `getLineDecorations`, `getDecorationsInRange` — depends on
  the deferred interval-tree storage; defer with that.
- **Focus / target / misc:** `hasTextFocus`, `hasWidgetFocus`,
  `getTargetAtClientPoint` (full 13-variant `IMouseTarget`, already a deferred
  divergence), `hasPendingScrollAnimation` (no smooth scroll — reveal plan scope
  cut), `getTelemetryData`, `getFontSizeAtPosition`, `getWhitespaces`
  (view-zone whitespace enumeration; low demand). `getModel` already ported.
- `getRange`/`getRanges` at `:2455`/`:2465` belong to the decorations-accessor
  class, not the editor — N-A.

## Inventory (Phase 1) — the denominator

Full public getter surface (read at oracle commit):

```
getId getEditorType getOptions getOption getRawOptions getOverflowWidgetsDomNode
getConfiguredWordAtPosition getValue getModel getVisibleRanges
getVisibleRangesPlusViewportAboveBelow getWhitespaces getTopForLineNumber
getTopForPosition getBottomForLineNumber getLineHeightForPosition
getVisibleColumnFromPosition getStatusbarColumn getPosition getSelection
getSelections getContentWidth getScrollWidth getScrollLeft getContentHeight
getScrollHeight getScrollTop hasPendingScrollAnimation getContribution getActions
getSupportedActions getAction getLineDecorations getDecorationsInRange
getFontSizeAtPosition getLayoutInfo getContainerDomNode getDomNode hasTextFocus
hasWidgetFocus getTargetAtClientPoint getScrolledVisiblePosition
getOffsetForColumn getWidthOfLine getTelemetryData hasModel
```

### In-scope members (22 public + 2 private statics)

Public getters:
`getValue`, `getVisibleRanges`, `getVisibleRangesPlusViewportAboveBelow`,
`getTopForLineNumber`, `getTopForPosition`, `getBottomForLineNumber`,
`getLineHeightForPosition`, `getVisibleColumnFromPosition`, `getStatusbarColumn`,
`getPosition`, `getSelection`, `getSelections`, `getContentWidth`,
`getScrollWidth`, `getScrollLeft`, `getContentHeight`, `getScrollHeight`,
`getScrollTop`, `getLayoutInfo`, `getScrolledVisiblePosition`,
`getOffsetForColumn`, `getWidthOfLine`.

Private statics shared by the vertical-offset getters:
`_getVerticalOffsetForPosition` (`:607`), `_getVerticalOffsetAfterPosition`
(`:584`).

### Backing the getters delegate to (own ledger rows)

- `viewModelImpl.getVisibleRanges` / `getVisibleRangesPlusViewportAboveBelow`
  (`:563`+ region), `getCompletelyVisibleViewRange` (`:700`),
  `_toModelVisibleRanges` (incl. hidden-area split), `getSelection`/
  `getSelections`/`getPosition` (`:1176`–`:1182`).
- `viewLayout.getContentWidth` / `getContentHeight` / `getScrollWidth` /
  `getScrollHeight` / `getCurrentScrollTop` / `getCurrentScrollLeft` /
  `getVerticalOffsetForLineNumber` / `getVerticalOffsetAfterLineNumber` /
  `getLineHeightForLineNumber`.
- `view.getOffsetForColumn` / `getLineWidth` (`browser/view.ts`) — DOM-measured.
- `CursorColumns.visibleColumnFromColumn` / `toStatusbarColumn`.

### Behavior-switching branches to cover (→ test cases)

1. **No model:** every getter returns its sentinel — `''` / `[]` / `null` / `-1`
   / `column` (the `getVisibleColumnFromPosition` no-model path returns the raw
   column, `:643`). Each branch is a test.
2. **Word-wrap on:** model line ≠ view line — coordinate conversion
   (`convertModelPositionToViewPosition`) is non-identity; vertical-offset and
   visible-range getters must convert before hitting `ViewLayout`.
3. **Folding hidden areas present:** `_toModelVisibleRanges` splits one view
   range into multiple model ranges (`hiddenAreas.length !== 0` branch).
4. **Scrolled vs. top:** `getScrolledVisiblePosition` subtracts scrollTop/Left;
   `getVisibleRanges` tracks the scrolled window.
5. **Position validation:** out-of-range / mid-surrogate / column past EOL go
   through `validatePosition` (the `_getVerticalOffsetForPosition` and
   `getVisibleColumnFromPosition` paths both validate first).
6. **`includeViewZones` true/false** on `getTopForLineNumber` /
   `getBottomForLineNumber`.
7. **`modelPositionIsVisible` false** (inside a folded region) →
   `getLineHeightForPosition` returns `0` (`:634`).

Member count: 24 in-scope `codeEditorWidget` members + ~11 backing rows = 35.

## Parity ledger (Phase 2)

Statuses: `TODO` / `PORTED` / `TESTED` / `PASS` / `DEFERRED(reason)` / `N-A(reason)`.
**All rows below landed as `PASS`** (see the Phase-5 per-member diff-review).
New public methods live in `viewer/public_read_api.mbt` (grouping the read surface
like `viewer/reveal.mbt` groups reveal); backing additions live in their owning
packages (`viewer/view_layout/view_layout.mbt`, `viewer/view_model/visible_ranges.mbt`,
`viewer/selection_measure.mbt`).

| Source member (file:line) | Arithmetic / delegation / sentinel | MoonBit symbol | Status |
|---|---|---|---|
| `getValue` (cew:472) | no model → `''`; else `model.getValue(eol, bom)` | `Viewer::get_value` → `snapshot.get_value()` | TODO |
| `getVisibleRanges` (cew:563) | no model → `[]`; else `viewModel.getVisibleRanges()` | `Viewer::get_visible_ranges` | TODO |
| `getVisibleRangesPlusViewportAboveBelow` (cew:570) | `linesAround=max(20, round(height/lineHeight))`; clamp `[1, lineCount]`; `_toModelVisibleRanges` | `Viewer::get_visible_ranges_plus_viewport_above_below` | TODO |
| `getTopForLineNumber` (cew:593) | no model → `-1`; `_getVerticalOffsetForPosition(line, 1, includeViewZones)` | `Viewer::get_top_for_line_number` | TODO |
| `getTopForPosition` (cew:600) | `_getVerticalOffsetForPosition(line, col, false)` | `Viewer::get_top_for_position` | TODO |
| `getBottomForLineNumber` (cew:616) | `_getVerticalOffsetAfterPosition(line, MAX, includeViewZones)` | `Viewer::get_bottom_for_line_number` | TODO |
| `getLineHeightForPosition` (cew:623) | `modelPositionIsVisible ? viewLayout.getLineHeightForLineNumber(viewLine) : 0`; no model → `-1` | `Viewer::get_line_height_for_position` | TODO |
| `getVisibleColumnFromPosition` (cew:641) | no model → `rawColumn`; else `visibleColumnFromColumn(lineContent, col, tabSize)+1` | `Viewer::get_visible_column_from_position` | TODO |
| `getStatusbarColumn` (cew:652) | `toStatusbarColumn(lineContent, col, tabSize)` | `Viewer::get_statusbar_column` | TODO |
| `getPosition` (cew:663) | no model → `null`; `viewModel.getPosition()` | `Viewer::get_position` | TODO |
| `getSelection` (cew:783) | no model → `null`; `viewModel.getSelection()` | `Viewer::get_selection` | TODO |
| `getSelections` (cew:790) | no model → `null`; `viewModel.getSelections()` | `Viewer::get_selections` | TODO |
| `getContentWidth` (cew:963) | no model → `-1`; `viewLayout.getContentWidth()` | `Viewer::get_content_width` | TODO |
| `getScrollWidth` (cew:970) | `viewLayout.getScrollWidth()` | `Viewer::get_scroll_width` | TODO |
| `getScrollLeft` (cew:976) | `viewLayout.getCurrentScrollLeft()` | `Viewer::get_scroll_left` | TODO |
| `getContentHeight` (cew:983) | `viewLayout.getContentHeight()` | `Viewer::get_content_height` | TODO |
| `getScrollHeight` (cew:990) | `viewLayout.getScrollHeight()` | `Viewer::get_scroll_height` | TODO |
| `getScrollTop` (cew:996) | `viewLayout.getCurrentScrollTop()` | `Viewer::get_scroll_top` | TODO |
| `getLayoutInfo` (cew:1472) | `options.get(layoutInfo)` (reduced struct — see Deviations) | `Viewer::get_layout_info` | TODO |
| `getScrolledVisiblePosition` (cew:1668) | `top=_vOffset(pos)−scrollTop`; `left=view.getOffsetForColumn+glyph+lineNum+decor−scrollLeft`; `height=getLineHeightForPosition`; no real view → `null` | `Viewer::get_scrolled_visible_position` | TODO |
| `getOffsetForColumn` (cew:1687) | no real view → `-1`; `view.getOffsetForColumn(line,col)` | `Viewer::get_offset_for_column` | TODO |
| `getWidthOfLine` (cew:1694) | no real view → `-1`; `view.getLineWidth(line)` | `Viewer::get_width_of_line` | TODO |
| `_getVerticalOffsetForPosition` (cew:607) | `validatePosition → convertModelPositionToViewPosition → viewLayout.getVerticalOffsetForLineNumber(viewLine, incZones)` | `Viewer::vertical_offset_for_position` (priv) | TODO |
| `_getVerticalOffsetAfterPosition` (cew:584) | same, `getVerticalOffsetAfterLineNumber` | `Viewer::vertical_offset_after_position` (priv) | TODO |
| `getCompletelyVisibleViewRange` (vmi:700) | `[completelyVisibleStart, completelyVisibleEnd]` × `[lineMinCol, lineMaxCol]` | `ViewModel::completely_visible_view_range` | TODO |
| `_toModelVisibleRanges` (vmi) | `convertViewRangeToModelRange`; if `hiddenAreas==0` → single; else split at each hidden range | `ViewModel::to_model_visible_ranges` | TODO |
| `getSelection/getSelections/getPosition` (vmi:1176-1182) | primary cursor model selection/position (single-cursor) | `CursorsController::primary_*` reads | TODO |
| `viewLayout.getContentWidth/Height` | `content_width` field / `content_height()` | exist (`view_layout.mbt:19`,`:130`) — add thin accessors | TODO |
| `viewLayout.getScrollWidth/Height` | `dimensions().scroll_width/height` (`view_layout.mbt:308-309`) | add accessors | TODO |
| `viewLayout.getCurrentScrollTop/Left` | `position().scroll_top/left` (`:235`) | add accessors | TODO |
| `viewLayout.getVerticalOffsetForLineNumber` | `vertical_offset_for_line` (`:138`) — exists | reuse | TODO |
| `viewLayout.getVerticalOffsetAfterLineNumber` | `vertical_offset_for_line(n)+line_height` (or `_for_line(n+1)`) | `ViewLayout::vertical_offset_after_line` (add) | TODO |
| `viewLayout.getLinesViewportData` completely-visible | `completelyVisibleStart/EndLineNumber` (fully on-screen rows) | add to `ViewportData` (`view_lines_viewport_data.mbt`) | TODO |
| `coordinatesConverter.convertViewRangeToModelRange` | exists (`view_model_lines_projected.mbt:349`) | reuse | TODO |
| hidden-areas accessor for the split | folded line ranges from the folding model | `…::hidden_areas()` (add if missing) | TODO |
| `view.getOffsetForColumn` (view.ts) | flush render → `visibleRangeForPosition(viewPos).left`, else `-1` | `View::offset_for_column` via `measure_line_selection` | TODO |
| `view.getLineWidth` (view.ts) | flush render → right edge of full view line | `View::line_width` via `measure_line_selection` | TODO |
| `CursorColumns.visibleColumnFromColumn` | exists (`common/cursor_columns.mbt:78`) | reuse | TODO |
| `CursorColumns.toStatusbarColumn` | not present | `common/cursor_columns.mbt` (add) | TODO |

## Deviations (Phase 3) — every non-source-cited choice, justified

- **`getValue` drops `{preserveBOM, lineEnding}`.** The viewer's snapshot stores
  normalized text with no BOM/EOL-preference concept (`TextSnapshot::get_value`,
  `text_snapshot.mbt:72`). Host seam, not geometry. If a caller needs EOL, add
  later behind the same option object.
- **`getLayoutInfo` returns a reduced struct.** Monaco's `EditorLayoutInfo` has
  ~30 fields (minimap, overview ruler, glyph margin) for parts the viewer
  doesn't render. Port only the fields the viewer computes and the read-API
  consumes: `width`, `height`, `content_left`, `content_width`,
  `line_numbers_width`, `glyph_margin_width` (`=0`), `decorations_width` (`=0`).
  `content_left = glyph+lineNumbers+decorations` is exactly the offset
  `getScrolledVisiblePosition` adds (`cew:1678`). Backed by the existing
  `gutter_width` / `view_metrics` computation (`viewer/input.mbt:122`,`:138`).
- **`getLineHeightForPosition` simplifies to uniform line height.** The viewer
  has no per-line height; return the configured `line_height` when visible, `0`
  when not — preserving Monaco's visible/`0` branch (`cew:634`).
- **Single-cursor selection.** `getSelections` returns a 1-element array and
  `getSelection`/`getPosition` the primary — the viewer is single-selection
  (`cursor/cursors_controller.mbt`). Faithful to the viewer's existing model, a
  documented prior scope cut, not new invention.
- **`hasRealView` collapses to "model attached".** Monaco gates
  `getScrolledVisiblePosition`/`getOffsetForColumn`/`getWidthOfLine` on
  `_modelData.hasRealView`; the viewer has no headless-view split, so the guard
  is "model present + line rendered" (the DOM-measured pair returns `-1`/`null`
  when the line isn't rendered, mirroring `visibleRangeForPosition` → `null`).

No layout/geometry/timing math is invented: vertical offsets, visible-range
splitting, scroll/content extents, and column arithmetic are all copied from the
cited source. Any port line without a citation is a bug in the port.

## Test matrix (Phase 4)

Behavior-switching variables: **model present** {no, yes} × **word-wrap**
{off, on} × **folding** {no hidden, hidden region} × **scroll** {top, scrolled}
× **position** {line start, mid, past-EOL→validated, in-folded-region}.

- **Headless (`with_test_viewer`, `viewer/test_viewer_wbtest.mbt:35`; `just test`):**
  all non-DOM getters. Cases:
  1. *No model* → every getter returns its exact sentinel (`''`/`[]`/`null`/`-1`/
     raw column). One assertion per getter.
  2. *Vertical offsets* — `get_top_for_line_number` / `_for_position` /
     `get_bottom_for_line_number` against hand-computed offsets at lines 1, k, last;
     `includeViewZones` both ways with a view zone inserted.
  3. *Scroll/content extents* — set a known content size + scroll, assert
     `get_scroll_top/left/height/width`, `get_content_width/height`.
  4. *Visible ranges* — at top and scrolled; **word-wrap on** so model≠view;
     **with a folded region** so `to_model_visible_ranges` returns >1 range
     (the hidden-area branch — the case most likely to be skipped).
  5. *Columns* — `get_visible_column_from_position` / `get_statusbar_column` on a
     tab-containing line (cover the tab-stop branch), and `+1` offset.
  6. *Selection/position* — after a `move_to`, assert `get_selection`/`_selections`
     (len 1) / `get_position`; word-wrap on to prove model-coordinate output.
  7. *Folded position* — `get_line_height_for_position` returns `0` inside a fold.
- **Browser (`tests/browser/...`; `just test-browser`):** the DOM-measured trio
  `get_offset_for_column`, `get_width_of_line`, `get_scrolled_visible_position` —
  real client-rect measurement after a render flush, at scrollLeft 0 and
  scrolled, on a wrapped line. Per project history, view-axis pixel math is
  caught **only** by the browser suite.

Run the headless matrix across the wrap/folding/scroll combinations, not one
config — single-config green is the documented false-confidence trap.

## Phasing / commit slicing

1. **Backing accessors** — `ViewLayout` scroll/content/offset-after accessors +
   `ViewportData` completely-visible fields + `CursorColumns.toStatusbarColumn`
   (+ unit tests). No public surface yet.
2. **Non-DOM read API** — value, scroll/content, vertical offsets, columns,
   selection/position, visible ranges (incl. hidden-area split) on `Viewer`;
   headless matrix. Usable for the bulk of embedder needs.
3. **DOM-measured read API** — `get_offset_for_column`, `get_width_of_line`,
   `get_scrolled_visible_position` + `getLayoutInfo` reduced struct; browser test.
4. **Host wiring (optional)** — expose through the workbench host where
   `scroll_to` is wired, only when a caller needs it.

## Exit gate (Phase 5)

- [x] inventory reconciled (rows == members): done/deferred/N-A = **24 / 6 / 14**
      of the 44-member denominator (see reconciliation). Every Phase-1 member resolved.
- [x] every ported fn diff-reviewed vs its cited source line (branch order,
      sentinels, `+1`/validation steps present) — see the per-member table below.
- [x] matrix covered: no-model sentinels, wrap-on conversion, folding-split
      visible ranges, scrolled DOM measurement — each has a failing-without-fix test
      (`viewer/public_read_api_wbtest.mbt`, `tests/browser/component/read_api.spec.js`).
- [x] deviations above confirmed still accurate; no uncited geometry line.
- [x] closing self-audit: re-read the `codeEditorWidget.ts` getter cluster; the
      reconciliation is pasted below.

## Phase-5 reconciliation (landed)

**Files.** New: `viewer/public_read_api.mbt` (the 22 getters + `getLayoutInfo` +
the DOM trio + 2 private vertical-offset helpers), `viewer/view_model/visible_ranges.mbt`
(`_toModelVisibleRanges` + hidden-areas/column/visibility backing),
`viewer/public_read_api_wbtest.mbt` (headless matrix, 15 cases),
`tests/browser/moonbit/read_api/` + `tests/browser/component/read_api.spec.js`
(DOM-measured browser test). Edited: `viewer/view_layout/view_layout.mbt` (scroll/
content/offset accessors + `completely_visible_line_range`),
`viewer/selection_measure.mbt` (`offset_for_column` / `line_width`),
`scripts/build-web.mbtx` (read_api bundle). `CursorColumns.to_statusbar_column`
already existed — reused.

**Validation.** `moon check --target all --warn-list +73` clean; `moon test`
483 js / 454 native pass (61 read-API headless cases inclusive); both browser
specs (`read_api`, `reveal`) green against the built bundle. (The native *server*
build is currently blocked by a toolchain ICE — missing core `prelude.mi` — so
the DOM spec was run against a static server over the freshly built `web/dist`;
the js bundle build and both headless suites are unaffected.)

### Denominator reconciliation (44 public `get*`/`has*` members)

- **DONE (24)** — the in-scope read cluster: `getValue`, `getVisibleRanges`,
  `getVisibleRangesPlusViewportAboveBelow`, `getTopForLineNumber`,
  `getTopForPosition`, `getBottomForLineNumber`, `getLineHeightForPosition`,
  `getVisibleColumnFromPosition`, `getStatusbarColumn`, `getPosition`,
  `getSelection`, `getSelections`, `getContentWidth`, `getScrollWidth`,
  `getScrollLeft`, `getContentHeight`, `getScrollHeight`, `getScrollTop`,
  `getLayoutInfo`, `getScrolledVisiblePosition`, `getOffsetForColumn`,
  `getWidthOfLine` (22 public) + the two private vertical-offset statics.
- **N-A (14)** — `getModel` (already ported), `getId`, `getEditorType`,
  `getDomNode`, `getContainerDomNode`, `getOverflowWidgetsDomNode`,
  `getRawOptions`, `getOptions`, `getOption`, `getConfiguredWordAtPosition`
  (config/identity/host seams), `getContribution`, `getActions`,
  `getSupportedActions`, `getAction` (no contribution registry). `hasModel`
  resolves as N-A: trivially `get_model() is Some`, not enumerated in the plan's
  22-getter scope.
- **DEFERRED (6)** — `getWhitespaces` (view-zone whitespace enumeration, low
  demand), `getLineDecorations` / `getDecorationsInRange` (interval-tree storage
  follow-up), `getTargetAtClientPoint` (13-variant `IMouseTarget` divergence),
  `hasPendingScrollAnimation` (no smooth scroll), `getFontSizeAtPosition` +
  `getTelemetryData` + `hasTextFocus`/`hasWidgetFocus` (focus/misc) — grouped as
  the named out-of-scope sibling clusters. (`getRange`/`getRanges` at cew:2455/2465
  are on the decorations-accessor class, not the editor — not counted.)

### Per-member source diff-review (branch order / sentinel / `+1` / validation)

- `getValue` (cew:472): no-model `''` ✓; else `snapshot.get_value()` (LF, BOM/EOL
  dropped — deviation) ✓.
- `getVisibleRanges` (cew:563 → vmi:646): no-model `[]` ✓; completely-visible view
  range (from `ViewLayout`) → `to_model_visible_ranges` ✓.
- `getVisibleRangesPlusViewportAboveBelow` (cew:570 → vmi:632):
  `linesAround = max(20, round(height/lineHeight))` ✓; clamp `[1, lineCount]` ✓.
- `getTopForLineNumber` (cew:593) / `getTopForPosition` (cew:600) /
  `getBottomForLineNumber` (cew:616): no-model `-1` ✓; `_getVerticalOffsetForPosition`
  at col 1 / col / `MAX_SAFE_INTEGER` ✓; `includeViewZones` plumbed (col-version
  forces `false`) ✓.
- `_getVerticalOffsetForPosition` (cew:607) / `_getVerticalOffsetAfterPosition`
  (cew:584): validate → `convertModelPositionToViewPosition` → for/after-line
  offset ✓.
- `getLineHeightForPosition` (cew:623): no-model `-1`; **no** validation of the raw
  position; `modelPositionIsVisible ? lineHeight : 0` ✓.
- `getVisibleColumnFromPosition` (cew:641): no-model → **raw column**; validate;
  `visibleColumnFromColumn(...) + 1` ✓.
- `getStatusbarColumn` (cew:652): no-model → raw column; `toStatusbarColumn(...)`
  (internal `+1`, no extra) ✓.
- `getPosition`/`getSelection`/`getSelections` (cew:663/783/790): no-model `null`;
  primary cursor model state; lazy-cursor default `(1,1)` (Monaco's always-present
  cursor) ✓; `getSelections` = 1-element array (single-selection deviation) ✓.
- `getContentWidth`/`getScrollWidth`/`getScrollLeft`/`getContentHeight`/
  `getScrollHeight`/`getScrollTop` (cew:963–996): each no-model `-1`; delegate to
  the matching `ViewLayout` accessor (`contentWidth` vs `scrollWidth = max(width,
  contentWidth)` distinction preserved) ✓.
- `getScrolledVisiblePosition` (cew:1668): no-real-view `null`; `top = vOffset −
  scrollTop`, `left = offsetForColumn + contentLeft − scrollLeft`, `height =
  getLineHeightForPosition` ✓.
- `getOffsetForColumn` (cew:1687) / `getWidthOfLine` (cew:1694): no-real-view `-1`;
  validate+convert → flush → measure; off-screen line → `-1` (mirrors
  `visibleRangeForPosition` → `null`) ✓.
- `getLayoutInfo` (cew:1472): reduced struct (deviation) — `content_left =
  lineNumbersWidth`, `glyph/decorations = 0` ✓.
- `_toModelVisibleRanges` (vmi:655): `convertViewRangeToModelRange`; `hiddenAreas
  == 0` single range, else the per-region carve with `getLineMaxColumn(hiddenStart
  − 1)` and the trailing `start < end || (== && startCol < endCol)` tail ✓.

## Risks / watch-items

- **Model vs view coordinates.** Public API is *model*-coordinate in/out; every
  vertical-offset and visible-range path must convert at the boundary via the
  `CoordinatesConverter`, never reach `ViewLayout` with model line numbers. With
  wrap on this is where parity breaks silently.
- **Hidden-area split.** `_toModelVisibleRanges`' multi-range branch is the one
  most likely to be skipped (single-range happy path passes without it). Folding
  must be in the matrix.
- **Sentinels.** `-1` / `[]` / `null` / raw-column are load-bearing — callers
  branch on them. Do not "tidy" them to `0`/empty-option uniformly; copy each.
- **DOM flush ordering.** `getOffsetForColumn`/`getLineWidth` need the target
  line rendered (Monaco's `_flushAccumulatedAndRenderNow`); off-screen → `-1`.
  Mirror the flush, don't measure a stale/absent node.
