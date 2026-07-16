# Viewer Browser Geometry Parity

Status: IMPLEMENTED AND FROZEN

Date: 2026-07-10

Implemented: 2026-07-12

Oracle: checked-in reference tree

Parent: viewer-monaco-parity-remediation.md

Findings: P1-07, P1-08 geometry half

Depends on: viewer-render-invalidation-parity.md

Historical stop gate: no product code changed until the inventory and parity
ledger were committed and independently approved. That gate passed before
implementation began.

## Goal

Derive horizontal scroll extent and ContentWidget anchors from rendered line
geometry, and pass all measured font facts required by the line renderer.
Tabs, fullwidth text, proportional fonts, injected text, and generated content
must remain reachable and must position widgets at the same visual location as
the text.

## Scope (Phase 0)

### Pinned Monaco source

- vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts
  - complete line-width measurement, slow-DOM-layout update,
    _maxLineWidth, setMaxLineWidth, getLineWidth, and render integration
    clusters.
- vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts
  - complete width/visible-range/layout clusters consumed by ViewLines and
    ContentWidgets.
- vscode/src/vs/editor/browser/viewParts/viewLines/domReadingContext.ts
  - complete DOM-layout reading context and line-width read guards.
- vscode/src/vs/editor/browser/view/renderingContext.ts
  - complete visible-range and line-width query cluster consumed by widgets
    and ViewLines; unrelated viewport rendering helpers are excluded siblings.
- vscode/src/vs/editor/browser/viewParts/viewLines/rangeUtil.ts
  - complete visible-range DOM measurement helpers.
- vscode/src/vs/editor/browser/viewParts/viewLines/viewLineOptions.ts
  - complete renderer-font-facts construction.
- vscode/src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts
  - complete position validation, model visibility, anchor-coordinate,
    visible-range, setWidgetPosition, placement, focus-preservation, and render
    clusters. Event handlers belong to viewer-render-invalidation-parity.md.
- vscode/src/vs/editor/common/viewLayout/viewLayout.ts
  - complete max-line-width, scroll-dimension, horizontal-scrollbar-height,
    and content-size integration clusters.
- vscode/src/vs/editor/common/viewLayout/viewLineRenderer.ts
  - input fields and arithmetic that consume typical, space, middot,
    whitespace-middot, fullwidth, and monospace facts.
- vscode/src/vs/editor/common/config/fontInfo.ts
  - complete font facts consumed by the scoped renderer.
- vscode/src/vs/editor/browser/config/fontMeasurements.ts
  - complete measurement-to-FontInfo field mapping consumed by the scoped
    renderer; exclude cache/platform clusters only with explicit rows.

### Local ownership

- viewer/attach_model.mbt
- viewer/input.mbt
- viewer/view_host.mbt
- viewer/browser/view_parts/view_lines/view_lines.mbt
- viewer/browser/view_parts/view_lines/dom_reading_context.mbt
- viewer/browser/view_parts/view_lines/view_line.mbt
- viewer/browser/view/rendering_context.mbt
- viewer/browser/view/view_part.mbt
- viewer/browser/view_parts/content_widgets/content_widgets.mbt
- viewer/browser/config/font_measurements.mbt
- viewer/common/config/font_info.mbt
- viewer/common/view_layout/view_layout.mbt
- viewer/common/view_layout/scrollable.mbt
- viewer/common/view_layout/view_line_renderer_input.mbt
- viewer/common/view_layout/render_line_renderer.mbt
- viewer/browser/view/selection_measure.mbt
- viewer/browser/view_parts/view_lines/README.md
- viewer/browser/view_parts/content_widgets/README.md

Inventory all measurement reads/writes, DOM-layout guards, cached widths,
widest-line transitions, padding/constants, generated-content treatment,
position validation, hidden-line behavior, and horizontal-scrollbar effects.

### Explicitly out of scope

- ViewZone DOM, callbacks, ordinal, or API shape;
- ViewLines and ContentWidgets ViewPart event-handler/dirty-state clusters,
  which belong to viewer-render-invalidation-parity.md;
- hover widget's own max-size/above-below/resizable layout;
- scroll animation and wheel classification;
- variable/custom line height;
- GPU view lines, minimap, overview ruler, and browser zoom policy;
- visual glyph/cursor styles unrelated to the measured coordinate.

## Initial Decision Register

| Behavior | Decision |
|---|---|
| content width equals max UTF-16 length times one character width | REQUIRED PARITY: replace with rendered-width feedback |
| ViewLines does not feed measured line width into ViewLayout | REQUIRED PARITY |
| generated content and injected text may be unreachable horizontally | REQUIRED PARITY |
| ContentWidget left equals column times uniform char width | REQUIRED PARITY |
| ContentWidget position ignores folded/hidden model positions | REQUIRED PARITY as sibling branch of the complete coordinate cluster |
| focused off-viewport widget is hidden rather than parked | REQUIRED PARITY as sibling branch |
| renderer drops measured monospace/middot/whitespace-middot facts | REQUIRED PARITY |
| horizontal scrollbar height is omitted from bottom content extent | REQUIRED PARITY as sibling dimension branch |

This register is not the parity ledger and does not count toward the
source-member denominator.

## Inventory and Parity Ledger (Phases 1–2)

This inventory uses one row per declared member, field/property,
behavior-changing branch or early return, independently material source-owned
callback/control-flow constant, and owned DOM/CSS fact. A field owns its
literal and straight-line arithmetic. Plain allocation, external DOM reads,
intermediate assignments, loop mechanics, branch arms, and final returns stay
on their owning member or branch row.

At Gate B every row below was `TODO`, and `Proposed terminal` was only a review
target. The collapsed four-column ledgers now record the final independently
reviewed terminal status. The normalized, deduplicated denominator remains:

```text
Line geometry: GVL 55 + GVLI 134 + GDRC 16 + GRU 25 + GVLO 16 = 246
Widget/query:  GCW 122 + GRC 54                                  = 176
Layout/font:   GVLay 53 + GVR 41 + GFI 51 + GFM 72               = 217
                                                                    ---
Total                                                               639

Final:    424 TESTED + 96 PORTED + 80 DEFERRED + 39 N-A = 639
          0 TODO; 0 PASS
```

The three amended fragments below supersede rejected raw drafts of 279/225/273
rows and the rejected 633-row documentation-only inventory milestone.
Pre-review removed statement-level inflation and frozen cross-plan duplicates;
formal Gate B then restored four omitted Group A declared members and two
Group B owner-window fallbacks, corrected terminal classifications, and
expanded the branch-derived matrices. Closing review changed one Gate-B
proposal: `GVLay-044` is N-A because its threshold only selects a right-side
minimap adjustment and this product has no minimap owner.

### Group A — ViewLines, ViewLine, RangeUtil, and options

#### Uniform atom rule

One row represents one declared member, field/property, behavior-changing branch or early return, independently material source-owned callback/control-flow constant, or owned DOM/CSS fact. A field owns its literal/arithmetic. Ordinary allocation, external DOM reads, straight-line statements, intermediate arithmetic, loop mechanics, branch arms, and final returns stay on their owning member or branch row.

#### Cross-plan ownership and excluded siblings

- Frozen render VL-001 owns `_visibleLines`; VL-002 owns `domNode`, including the scroll-width write at `viewLines.ts:318`; VL-004 owns `_typicalHalfwidthCharacterWidth`; VL-009 owns `_canUseLayerHinting`; VL-010 owns `_viewLineOptions`; VL-011 owns `_maxLineWidth`; VL-019 owns flush; VL-025 owns the zones reapply; VL-027/VL-028 own wrapping/layout resets; and VL-033 owns the visible-line factory callback. Geometry consumes those exact rows without recounting them.
- Frozen VLI-001–013 own `_options`, `_isMaybeInvalid`, `_renderedViewLine`, getDomNode, and the event/selection invalidation cluster. Group A consumes those exact rows without recounting them.
- `viewLine.ts:109–149,175–178` are explicitly excluded non-geometry render/invalidation/selection siblings; they are not falsely claimed as frozen VLI ledger rows. Geometry owns only the scoped renderer-font/option wiring, DOM/CSS layout, strategy, width, and visible-range clusters below.
- ViewLines reveal requests/arithmetic, DOM-to-position hit testing, standalone GPU rendering, and the browser-zoom check scheduler remain named excluded siblings. `ViewLine.isRenderedRTL` (`viewLine.ts:245-250`) is a reveal-only helper and remains excluded with that cluster. ViewLine node-to-column helpers remain excluded siblings. Scoped shared methods are labelled geometry slices and do not claim excluded statements.
- `domReadingContext.ts`, `rangeUtil.ts`, and `viewLineOptions.ts` are complete units. Passing GRC-owned `FloatHorizontalRange.compare` to RangeUtil sort is a callsite, not a second callback atom.
- GPU atoms that occur inside closed scoped members remain DEFERRED under the Phase-0 GPU exclusion; absence is not N-A.

#### Source evidence

| Prefix | Source file | Lines | SHA-256 |
|---|---|---:|---|
| GVL | `vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts` | 875 | `b312dba68bbf6ebfd33f90ad2c2d6ea403f595d80bc25f82999328153517df5a` |
| GVLI | `vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts` | 734 | `8ab7866695ac0138524e2ce5d5f43abb377232b694bfd115e08dc81221bf3b8d` |
| GDRC | `vscode/src/vs/editor/browser/viewParts/viewLines/domReadingContext.ts` | 51 | `4a11a0a5bc68b9e9f78ab8866030c3ae06db3316daa0119f2974592de60a5ff3` |
| GRU | `vscode/src/vs/editor/browser/viewParts/viewLines/rangeUtil.ts` | 144 | `00c9a24b56214d309b53cab54cff25fe44db0124f30e9e4e85a0ce5662c7039a` |
| GVLO | `vscode/src/vs/editor/browser/viewParts/viewLines/viewLineOptions.ts` | 66 | `b7205d06dfe7b1918d798a3c7ef99968dfb63d6d4df224e7198fd3c5c3d9c619` |

#### `domReadingContext.ts` — GDRC

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GDRC-001 | `_didDomLayout = false` (`:8`) | `DomReadingContext.did_dom_layout_flag`; constructor default false. | TESTED |
| GDRC-002 | `_clientRectDeltaLeft = 0` (`:9`) | `client_rect_delta_left_value = 0.0`. | TESTED |
| GDRC-003 | `_clientRectScale = 1` (`:10`) | `client_rect_scale_value = 1.0`. | TESTED |
| GDRC-004 | `_clientRectRead = false` (`:11`) | `client_rect_read = false`. | TESTED |
| GDRC-005 | `didDomLayout` getter (`:13-15`) | `DomReadingContext::did_dom_layout`. | TESTED |
| GDRC-006 | `readClientRect` (`:17-26`) | `DomReadingContext::read_client_rect`; preserve unread guard, flag, bounding-rect/offsetWidth reads, layout mark, cache assignments, and order. | TESTED |
| GDRC-007 | unread-only guard (`:18-25`) | Existing `if !client_rect_read`; repeated reads must not relayout. | TESTED |
| GDRC-008 | positive-width scale/fallback branch (`:24`) | Exact `offsetWidth > 0 ? rect.width / offsetWidth : 1`. | TESTED |
| GDRC-009 | `clientRectDeltaLeft` getter (`:28-33`) | Existing lazy getter. | TESTED |
| GDRC-010 | delta getter unread branch (`:29-31`) | First getter call triggers exactly one `readClientRect`. | TESTED |
| GDRC-011 | `clientRectScale` getter (`:35-40`) | Existing lazy getter. | TESTED |
| GDRC-012 | scale getter unread branch (`:36-38`) | First getter call triggers exactly one `readClientRect`. | TESTED |
| GDRC-013 | constructor (`:42-46`) | `DomReadingContext::new` receives `_domNode` and `endNode`; field rows own the four default literals. | TESTED |
| GDRC-014 | private `_domNode` parameter property (`:43`) | Existing private `dom_node`. | PORTED |
| GDRC-015 | public `endNode` parameter property (`:44`) | Existing `end_node`, used as Range resting spot. | TESTED |
| GDRC-016 | `markDidDomLayout` (`:48-50`) | Existing sticky false-to-true transition. | TESTED |
GDRC denominator: **16**.

#### `rangeUtil.ts` — GRU

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GRU-001 | static `_handyReadyRange` (`:17`) | Local RangeUtil retains one lazily created owner-document Range across calls. | TESTED |
| GRU-002 | `_createRange` (`:19-24`) | Source-shaped reusable-range member owns first-use `document.createRange()` and the ordinary cached return. | TESTED |
| GRU-003 | absent-range initialization branch (`:20-22`) | Create only on first use; later calls reuse identity. | TESTED |
| GRU-004 | `_detachRange` (`:26-30`) | Resting-spot helper owns `selectNodeContents(endNode)`. | TESTED |
| GRU-005 | `_readClientRects` (`:32-45`) | Exact try/catch/finally wrapper owns ordered setStart/setEnd/getClientRects statements. | TESTED |
| GRU-006 | DOM Range failure catch/`null` (`:39-41`) | Local returns `[]`; preserve nullable source outcome internally. | TESTED |
| GRU-007 | unconditional detach in `finally` (`:42-44`) | Runs on both success and failure. | TESTED |
| GRU-008 | `_mergeAdjacentRanges` (`:47-72`) | `merge_adjacent_ranges` preserves the source early return, loop, 0.9 tolerance, inclusive merge, and disjoint append order. | TESTED |
| GRU-009 | exactly-one early return (`:48-51`) | Local uses `<= 1`; source callers prevent empty input, and the empty compatibility boundary is tested separately. | TESTED |
| GRU-010 | browser-rounding tolerance `0.9` (`:61`) | Existing exact constant. | TESTED |
| GRU-011 | adjacent-vs-disjoint merge branch (`:61–66`) | One `if/else`: inclusive `>=` merges with exact max width; otherwise append prior range and advance. | TESTED |
| GRU-012 | `_createHorizontalRangesFromClientRects` (`:74-89`) | Source-shaped layer owns per-rect clamped/scaled left, scaled width, result construction, and final adjacent-range merge. | TESTED |
| GRU-013 | null-or-empty rect-list early return (`:75-77`) | Local empty array is normalized to the internal nullable source outcome. | TESTED |
| GRU-014 | public `readHorizontalRanges` (`:91-143`) | Source-shaped facade owns child/offset clamping, firstChild/rect reads, final client-rect read, layout mark, and normalized conversion around counted branches. | TESTED |
| GRU-015 | minimum child index constant `0` (`:93`) | Preserve as clamp lower bound. | TESTED |
| GRU-016 | maximum child index `children.length - 1` (`:94`) | Independently reused upper clamp/control bound is applied to the source reading target directly. | TESTED |
| GRU-017 | empty-children early return (`:95-97`) | Existing FFI returns empty; preserve nullable source branch. | TESTED |
| GRU-018 | collapsed empty-span special branch (`:101-107`) | Exact compound empty-span predicate owns element `getClientRects`, layout mark, and bounding-box fallback. | TESTED |
| GRU-019 | cross-span guard (`:111`) | Explicit source guard is preserved. | TESTED |
| GRU-020 | ending-at-next-span-zero branch (`:112-115`) | Move end to prior span and maximum safe offset. | TESTED |
| GRU-021 | `Constants.MAX_SAFE_SMALL_INTEGER` sentinel (`:114,125,129`) | One source-equivalent constant is reused by all three fallbacks. | TESTED |
| GRU-022 | missing-endpoint wrapper branch (`:121-131`) | Preserve the outer missing-endpoint branch and its two independently counted repairs; member owns ordinary firstChild reads. | TESTED |
| GRU-023 | missing start + zero offset + prior span branch (`:123-126`) | Repairs the start from the prior span and sentinel offset. | TESTED |
| GRU-024 | missing end + zero offset + prior span branch (`:127-130`) | Repairs the end from the prior span and sentinel offset. | TESTED |
| GRU-025 | still-missing endpoint early return (`:133-135`) | Returns the normalized nullable outcome instead of synthesizing element endpoints. | TESTED |
GRU denominator: **25**.

#### `viewLineOptions.ts` — GVLO

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GVLO-001 | `themeType` field (`:11,27,50`) | No typed theme-event/options seam; concrete theme remains CSS/root-owned. | N-A (no typed theme option contract) |
| GVLO-002 | `renderWhitespace` field (`:12,30,51`) | Existing `ViewLineOptions.render_whitespace`. | TESTED |
| GVLO-003 | `experimentalWhitespaceRendering` field (`:13,31,52`) | No exposed experimental whitespace renderer. | DEFERRED (experimental whitespace option absent) |
| GVLO-004 | `renderControlCharacters` field (`:14,32,53`) | Existing field and runtime flow. | TESTED |
| GVLO-005 | `spaceWidth` field (`:15,33,54`) | Existing field receives measured FontInfo unchanged. | TESTED |
| GVLO-006 | `middotWidth` field (`:16,34,55`) | Supplied unchanged from measured browser FontInfo. | TESTED |
| GVLO-007 | `wsmiddotWidth` field (`:17,35,56`) | Supplied unchanged from measured browser FontInfo. | TESTED |
| GVLO-008 | `useMonospaceOptimizations` field (`:18,36-39,57`) | Field owns the exact `fontInfo.isMonospace` plus disable-option conjunction and consumes measured monospace state. | TESTED |
| GVLO-009 | `canUseHalfwidthRightwardsArrow` field (`:19,40,58`) | Existing field receives the measured FontInfo capability unchanged. | TESTED |
| GVLO-010 | `lineHeight` field (`:20,41,59`) | Existing `line_height`, consumed by retained line layout. | TESTED |
| GVLO-011 | `stopRenderingLineAfter` field (`:21,42,60`) | Existing field and truncation visibility branches. | TESTED |
| GVLO-012 | `fontLigatures` field (`:22,43,61`) | Local stores Bool rather than source ligature string; observable renderer predicate is the target. | TESTED |
| GVLO-013 | `verticalScrollbarSize` field (`:23,44,62`) | Existing field feeds both RTL padding and renderer input. | TESTED |
| GVLO-014 | `useGpu` field (`:24,45,63`) | Source field owns exact GPU option equality; Viewer has no GPU renderer. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GVLO-015 | constructor (`:26-46`) | Local construction is split between `ViewLinesConfiguration` and `ViewLineOptions::new`; preserve all applicable reads. | TESTED |
| GVLO-016 | `equals` 14-field conjunction (`:48-64`) | Local equality covers all 11 applicable fields; the theme, experimental-whitespace, and GPU axes retain their row-local N-A/DEFERRED outcomes. | TESTED |
GVLO denominator: **16**.

#### `viewLines.ts` geometry clusters — GVL

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GVL-001 | `LastRenderedData._currentVisibleRange` (`:33`) | ViewLines retains source-shaped current-visible-range state for multi-line range queries. | TESTED |
| GVL-002 | `LastRenderedData` constructor (`:35-37`) | Initialize exact `Range(1,1,1,1)`. | TESTED |
| GVL-003 | `getCurrentVisibleRange` (`:39-41`) | Source-shaped getter returns the retained rendered range. | TESTED |
| GVL-004 | `setCurrentVisibleRange` (`:43-45`) | Render-time update replaces the retained range after rows render. | TESTED |
| GVL-005 | `_linesContent` field (`:103,147,672-676`) | Existing `ViewLines.lines_content`; retain the layer node. Scoped layer CSS writes have their own rows. | PORTED |
| GVL-006 | `_textRangeRestingSpot` field (`:104,148,408,432,487`) | Existing detached `text_range_resting_spot`. | TESTED |
| GVL-007 | `_asyncUpdateLineWidths` field (`:120,160-162,538-543,652-657`) | ViewLines owns the deterministic 200ms slow-width scheduler. | TESTED |
| GVL-008 | `_lastRenderedData` field (`:124,167,425,616`) | ViewLines owns `LastRenderedData`, constructs it eagerly, and updates it only after rows render. | TESTED |
| GVL-009 | constructor geometry cluster (`:130-174`) | Scoped constructor slice owns geometry-only construction/order for resting spot, width scheduler, and last-rendered state; frozen/excluded fields remain external handoffs. | TESTED |
| GVL-010 | slow-width scheduler callback (`:160-162`) | Source-owned callback invokes only `_updateLineWidthsSlow`. | TESTED |
| GVL-011 | slow-width scheduler delay `200` ms (`:162`) | Exact delay constant is retained. | TESTED |
| GVL-012 | `dispose` geometry slice (`:176-180`) | Local ViewLines disposes/cancels its width scheduler before the resource-free inherited slice. | TESTED |
| GVL-013 | public `getDomNode` (`:182-184`) | Existing `ViewLines::get_dom_node` returns the exact retained collection DOM node. | TESTED |
| GVL-014 | public `getLineWidth` (`:400-413`) | Preserves the range guard and context/delegate read, then performs the post-read slow-width piggyback. | TESTED |
| GVL-015 | unrendered-line early return `-1` (`:403-406`) | Existing exact range guard. | TESTED |
| GVL-016 | public `resetLineWidthCaches` (`:415-421`) | Member owns the inclusive visible-window loop and each retained line's cache reset. | TESTED |
| GVL-017 | public `linesVisibleRangesForRange` (`:423-480`) | Multi-line query owns original-end capture, rendered-range intersection, shared context/converter progression, result construction, and slow-width piggyback around the counted branches. | TESTED |
| GVL-018 | null-intersection early return (`:426-428`) | Returns the nullable result before any DOM read. | TESTED |
| GVL-019 | `includeNewLines` initialization branch (`:434-437`) | Initializes the source newline policy before line iteration. | TESTED |
| GVL-020 | rendered-window miss `continue` (`:443-445`) | Preserve per-line skip after visible-range clipping. | TESTED |
| GVL-021 | start-column first-line branch (`:447`) | First line uses clipped start; later lines start at column 1. | TESTED |
| GVL-022 | end-column/continuation branch (`:448-449`) | Non-original-end lines use line max column and set continuation. | TESTED |
| GVL-023 | null per-line ranges `continue` (`:453-455`) | Skips the unmeasurable line and continues the shared query. | TESTED |
| GVL-024 | newline-width gate (`includeNewLines && line < originalEnd`) (`:457`) | Exact compound source gate controls newline-width accounting. | TESTED |
| GVL-025 | actual model-newline branch (`:461-467`) | Adds width only when adjacent view lines map to distinct model lines. | TESTED |
| GVL-026 | RTL newline branch (`:464-466`) | Subtract the same width from `left` for RTL model lines. | TESTED |
| GVL-027 | zero-result early return (`:475-477`) | Return `null`, not an empty list. | TESTED |
| GVL-028 | private `_visibleRangesForLineRange` (`:482-492`) | Helper owns one context, retained-line delegation, and post-read slow-width piggyback. | TESTED |
| GVL-029 | helper unrendered-line early return (`:483-485`) | Existing local measurements return empty/None through a different seam. | TESTED |
| GVL-030 | public `visibleRangeForPosition` (`:502-508`) | Delegates through retained ViewLine semantics and returns `HorizontalPosition` from the first measured range. | TESTED |
| GVL-031 | missing visible-ranges early return (`:504-506`) | Normalizes the local negative-left sentinel to the source nullable outcome. | TESTED |
| GVL-032 | public `updateLineWidths` (`:512-514`) | Public entrypoint performs the synchronous slow sweep. | TESTED |
| GVL-033 | `_updateLineWidthsFast` wrapper (`:521-523`) | Exact `fast=true` wrapper is preserved. | TESTED |
| GVL-034 | `_updateLineWidthsSlow` wrapper (`:525-527`) | Exact `fast=false` wrapper is preserved. | TESTED |
| GVL-035 | `_updateLineWidthsSlowIfDomDidLayout` (`:533-544`) | Piggyback method preserves both early-return guards and cancels the pending scheduler before the slow sweep. | TESTED |
| GVL-036 | no-DOM-layout early return (`:534-537`) | Do no sweep when the triggering query did not force layout. | TESTED |
| GVL-037 | not-scheduled early return (`:538-541`) | Widths are already current when no slow sweep is pending. | TESTED |
| GVL-038 | `_updateLineWidths(fast)` (`:546-572`) | Visible-width sweep owns per-line maximum accumulation, final ensure call, and completeness result. | TESTED |
| GVL-039 | local maximum initial constant `1` (`:550`) | Preserve minimum feedback width. | TESTED |
| GVL-040 | fast-and-not-fast-readable branch (`:555-559`) | Set incomplete and continue without forcing layout. | TESTED |
| GVL-041 | all-widths/full-document branch (`:564-567`) | Only a complete rendered document proves the global maximum current; clear the prior maximum before ensuring the sweep result. | TESTED |
| GVL-042 | public `prepareRender` unsupported entrypoint (`:605-607`) | `ViewPart::prepare_render` for ViewLines aborts with exact `Not supported`, covered by a direct regression check. | TESTED |
| GVL-043 | public `render` unsupported entrypoint (`:609-611`) | Existing `ViewPart::render` for ViewLines aborts with exact `Not supported`; `renderText` remains the only text-render route. | TESTED |
| GVL-044 | `renderText` geometry cluster (`:613-677`) | Renders rows, updates the retained rendered range, performs width feedback, and only then lays out the rail. | TESTED |
| GVL-045 | `domNode.setWidth(scrollWidth)` DOM/CSS write (`:617`) | Existing exact write from `layout.dimensions()`. | TESTED |
| GVL-046 | `domNode.setHeight(min(scrollHeight,1000000))` DOM/CSS write (`:618`) | Existing cap/write. | TESTED |
| GVL-047 | height cap `1_000_000` (`:618`) | Preserve exact independent constant. | TESTED |
| GVL-048 | fast-sweep schedule-vs-cancel branch (`:652–657`) | One `if/else`: incomplete fast sweep schedules delayed work; complete sweep cancels it. | TESTED |
| GVL-049 | `_linesContent.setLayerHinting` DOM/CSS write (`:672`) | Existing `set_layer_hinting` using frozen configuration field. | TESTED |
| GVL-050 | `_linesContent.setContain('strict')` CSS property (`:673`) | Existing exact value. | TESTED |
| GVL-051 | `_linesContent.setTop(-adjustedScrollTop)` CSS property (`:674-675`) | Existing exact `-(scrollTop - bigNumbersDelta)` translation. | TESTED |
| GVL-052 | `_linesContent.setLeft(-scrollLeft)` CSS property (`:676`) | Existing exact negative translation. | TESTED |
| GVL-053 | `_ensureMaxLineWidth` (`:681-691`) | Member owns ceiling integerization and monotonic layout feedback. | TESTED |
| GVL-054 | GPU early return (`:682-685`) | No local GPU ViewLines owner. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GVL-055 | strictly-growing maximum branch (`:687-690`) | Equal/smaller widths do not write; a growth assigns the cache then calls ViewLayout exactly once. | TESTED |
GVL denominator: **55**.

#### `viewLine.ts` width, visible-range, and layout clusters — GVLI

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GVLI-001 | module `canUseFastRenderedViewLine` constant (`:25–47`) | Retain the selected fast-render policy result; the source-owned selector IIFE and its branches are separate. | DEFERRED (browser zoom and fast-renderer policy seam) |
| GVLI-002 | `canUseFastRenderedViewLine` selector IIFE callback (`:25–47`) | Source-owned callback owns native/platform branch order and ordinary final true fallback. | DEFERRED (browser zoom and fast-renderer policy seam) |
| GVLI-003 | native-platform early true (`:26-29`) | Source `platform.isNative` is a JS native/Node/Electron host fact, not the MoonBit native backend; no local native-host zoom-invalidation owner exists. | DEFERRED (native-host/browser-zoom policy seam) |
| GVLI-004 | Linux, Firefox, or Safari false branch (`:31-44`) | No source-shaped fast-path platform gate; fixed geometry fixture is Chromium. | DEFERRED (non-fixture platform and browser zoom seam) |
| GVLI-005 | mutable `monospaceAssumptionsAreValid = true` (`:49`) | No global browser-zoom invalidation state. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-006 | static `ViewLine.CLASS_NAME = 'view-line'` (`:53`) | Existing public `VIEW_LINE_CLASS_NAME`; keep the rendered-row and DOM hit-test class contract exact. | TESTED |
| GVLI-007 | constructor `_viewGpuContext` parameter property (`:59`) | No GPU ViewLine context. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GVLI-008 | `ViewLine` constructor (`:59–63`) | Declared member owns construction/order; frozen field rows own retained invalidation assignments and the GPU parameter property remains separately deferred. | TESTED |
| GVLI-009 | `setDomNode` (`:73-79`) | `ViewLine::set_dom_node` attaches the cached wrapper when rendered state exists and exposes the exact absent-state invariant failure. | TESTED |
| GVLI-010 | rendered-line-present-vs-throw branch (`:74–78`) | One `if/else`: attach a cached DOM wrapper only when rendered state exists; otherwise throw the exact invariant failure. | TESTED |
| GVLI-011 | `renderLine` scoped geometry integration (`:102-232`) | Scoped renderLine geometry member owns measured option/font argument flow, ordinary ligature predicate, DOM/layout construction, and rendered strategy around counted branches; frozen/excluded siblings are not recounted. | TESTED |
| GVLI-012 | GPU `canRender` branch (`:103-107`) | When GPU can render, remove prior DOM, clear retained strategy, and return false; local GPU path is absent. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GVLI-013 | experimental whitespace selection branch (`:119`) | Source uses configured whitespace only when experimental rendering is `off`; absent local option constant-folds this branch. | DEFERRED (experimental whitespace option absent) |
| GVLI-014 | RTL `dir="rtl"` DOM attribute (`:180-182`) | RTL rows emit the exact `dir="rtl"` attribute. | TESTED |
| GVLI-015 | contains-RTL `dir="ltr"` DOM attribute (`:183-185`) | LTR rows containing RTL text emit the exact `dir="ltr"` attribute. | TESTED |
| GVLI-016 | row `top` CSS property (`:186-188`) | Existing exact integer-pixel write. | TESTED |
| GVLI-017 | row `height` CSS property (`:188-190`) | Existing exact integer-pixel write. | TESTED |
| GVLI-018 | row `line-height` CSS property (`:190-192`) | Existing exact integer-pixel write. | TESTED |
| GVLI-019 | RTL `padding-right` CSS property (`:192-195`) | Source-equivalent CSS uses the measured vertical scrollbar size. | TESTED |
| GVLI-020 | row class attribute (`:196-198`) | Preserves source-owned `view-line` plus the local renderer class. | TESTED |
| GVLI-021 | seven-factor fast-render candidate branch (`:204-213`) | Local has no FastRenderedViewLine; preserve slow behavior and record optimization deferral. | DEFERRED (fast rendered-line class absent) |
| GVLI-022 | fast-constructor prior-DOM reuse ternary (`:215`) | The fast constructor remains absent with the deferred fast rendered-line class, so this branch is not locally reachable. | DEFERRED (fast rendered-line class absent) |
| GVLI-023 | no-fast-result fallback branch (`:221-228`) | Local always constructs equivalent slow retained state. | TESTED |
| GVLI-024 | slow-constructor prior-DOM reuse ternary (`:223`) | Reuse the prior DOM wrapper for the slow constructor when present; otherwise pass null. | TESTED |
| GVLI-025 | `layoutLine` (`:235-241`) | Existing `ViewLine::layout_line`. | TESTED |
| GVLI-026 | rendered-line plus DOM guard (`:236-240`) | Existing optional DOM branch. | TESTED |
| GVLI-027 | `domNode.setTop` CSS write (`:237`) | Existing exact write. | TESTED |
| GVLI-028 | `domNode.setHeight` CSS write (`:238`) | Existing exact write. | TESTED |
| GVLI-029 | `domNode.setLineHeight` CSS write (`:239`) | Existing exact write. | TESTED |
| GVLI-030 | `getWidth` ViewLine delegator (`:252-257`) | Retained ViewLine method delegates to the rendered strategy and its cache variants. | TESTED |
| GVLI-031 | no-rendered-line width `0` (`:253-255`) | Exact retained-state guard returns zero before any DOM read. | TESTED |
| GVLI-032 | `getWidthIsFast` ViewLine delegator (`:259-264`) | Delegates to the retained rendered-line strategy. | TESTED |
| GVLI-033 | no-rendered-line fast result `true` (`:260-262`) | Exact source early-return branch is preserved. | TESTED |
| GVLI-034 | `needsMonospaceFontCheck` (`:266-271`) | Missing browser-zoom diagnostic member; after its no-line guard it returns the fast-strategy instance predicate. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-035 | no-rendered-line false return (`:267-269`) | Same deferred diagnostic cluster. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-036 | `monospaceAssumptionsAreValid` ViewLine member (`:273-281`) | Missing global/strategy dispatch. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-037 | no-rendered-line global fallback (`:274-276`) | Missing. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-038 | fast-instance delegation branch (`:277-279`) | Missing. | DEFERRED (fast rendered-line class absent) |
| GVLI-039 | `onMonospaceAssumptionsInvalidated` (`:283-287`) | Missing fast-to-slow replacement. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-040 | fast-instance conversion branch (`:284-286`) | Missing. | DEFERRED (fast rendered-line class absent) |
| GVLI-041 | `getVisibleRangesForRange` ViewLine member (`:289-318`) | Member owns input-length clamping, stop-rendering normalization, retained-strategy delegation, and final nullable result around counted branches. | TESTED |
| GVLI-042 | no-rendered-line null early return (`:290-292`) | Source state guard returns before strategy access. | TESTED |
| GVLI-043 | both columns beyond truncation early return (`:299-302`) | Returns the outside-rendered-line result at measured width and zero range width. | TESTED |
| GVLI-044 | start-column truncation clamp branch (`:304-306`) | Clamps the start column at the rendered cutoff. | TESTED |
| GVLI-045 | end-column truncation clamp branch (`:308-310`) | Clamps the end column at the rendered cutoff. | TESTED |
| GVLI-046 | nonempty delegated ranges branch (`:312-315`) | Wraps the strategy result as `VisibleRanges(false, ranges)`. | TESTED |
| GVLI-047 | `resetCachedWidth` ViewLine member (`:327-329`) | Delegates cache reset to the retained rendered line. | TESTED |
| GVLI-048 | `IRenderedViewLine.domNode` field (`:333`) | Local ViewLine owns optional cached DOM directly. | PORTED |
| GVLI-049 | `IRenderedViewLine.input` field (`:334`) | Existing optional `render_input`. | PORTED |
| GVLI-050 | `IRenderedViewLine.getWidth` contract (`:335`) | Local rendered-line abstraction preserves the source strategy contract and cached/uncached outcomes. | TESTED |
| GVLI-051 | `IRenderedViewLine.getWidthIsFast` contract (`:336`) | Source-shaped strategy contract is represented by the local rendered-line abstraction. | TESTED |
| GVLI-052 | `IRenderedViewLine.resetCachedWidth` contract (`:337`) | Source-shaped strategy contract is represented by the local rendered-line abstraction. | TESTED |
| GVLI-053 | `IRenderedViewLine.getVisibleRangesForRange` contract (`:338`) | Source-shaped strategy contract is represented by the local rendered-line abstraction. | TESTED |
| GVLI-054 | `Constants.MaxMonospaceDistance = 300` (`:342-351`) | Missing exact threshold. | DEFERRED (fast rendered-line class absent) |
| GVLI-055 | FastRenderedViewLine `domNode` field (`:358`) | Missing fast class. | DEFERRED (fast rendered-line class absent) |
| GVLI-056 | FastRenderedViewLine `input` field (`:359`) | Missing fast class. | DEFERRED (fast rendered-line class absent) |
| GVLI-057 | FastRenderedViewLine `_characterMapping` (`:361`) | Missing fast class. | DEFERRED (fast rendered-line class absent) |
| GVLI-058 | FastRenderedViewLine `_charWidth` (`:362,380`) | Source takes `RenderLineInput.spaceWidth`. | DEFERRED (fast rendered-line class absent) |
| GVLI-059 | FastRenderedViewLine `_keyColumnPixelOffsetCache` (`:363,369-377`) | Missing. | DEFERRED (fast rendered-line class absent) |
| GVLI-060 | FastRenderedViewLine `_cachedWidth = -1` (`:364`) | Missing sentinel cache. | DEFERRED (fast rendered-line class absent) |
| GVLI-061 | FastRenderedViewLine constructor (`:366-381`) | Missing; member owns key-count arithmetic, sentinel fill loop, mapping retention, and spaceWidth character width. | DEFERRED (fast rendered-line class absent) |
| GVLI-062 | key-column-cache allocation-vs-null branch (`:369–377`) | One `if/else`: positive key count allocates/fills the cache; zero retains null. | DEFERRED (fast rendered-line class absent) |
| GVLI-063 | FastRenderedViewLine `getWidth` (`:383-393`) | Missing hybrid member; owns rounded mapped estimate, firstChild offsetWidth read, cache fill, and layout mark around counted branches. | DEFERRED (fast rendered-line class absent) |
| GVLI-064 | no-DOM or shorter-than-300 branch (`:384-387`) | Estimate rounded mapped width without layout. | DEFERRED (fast rendered-line class absent) |
| GVLI-065 | cached-width-miss branch (`:388-391`) | Read DOM once and mark context. | DEFERRED (fast rendered-line class absent) |
| GVLI-066 | FastRenderedViewLine `getWidthIsFast` (`:395-397`) | Short line or populated cache. | DEFERRED (fast rendered-line class absent) |
| GVLI-067 | FastRenderedViewLine `resetCachedWidth` (`:399-401`) | Restore `-1`. | DEFERRED (fast rendered-line class absent) |
| GVLI-068 | FastRenderedViewLine `monospaceAssumptionsAreValid` (`:403-417`) | Missing zoom/measurement member; owns validation firstChild offsetWidth read and final global result around counted branches. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-069 | no-DOM global-fallback branch (`:404-406`) | Missing. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-070 | shorter-than-300 validation branch (`:407-415`) | Compare estimate to first-child width only for short lines. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-071 | absolute error at least `2` branch (`:410-414`) | Warn and permanently clear global assumption. | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-072 | `toSlowRenderedLine` (`:419-421`) | Missing strategy conversion. | DEFERRED (fast rendered-line class absent) |
| GVLI-073 | FastRenderedViewLine `getVisibleRangesForRange` (`:423-427`) | Missing mapped-offset range. | DEFERRED (fast rendered-line class absent) |
| GVLI-074 | `_getColumnPixelOffset` (`:429-455`) | Missing fast hybrid; member owns key ordinal/column arithmetic and actual-key plus mapped-delta result. | DEFERRED (fast rendered-line class absent) |
| GVLI-075 | column at or below 300 branch (`:430-433`) | Use pure mapped horizontal offset. | DEFERRED (fast rendered-line class absent) |
| GVLI-076 | key-column cache present branch (`:438-444`) | Missing. | DEFERRED (fast rendered-line class absent) |
| GVLI-077 | key-column cache miss read/store branch (`:440-443`) | Missing. | DEFERRED (fast rendered-line class absent) |
| GVLI-078 | unresolved key-column fallback (`:446-450`) | Return pure mapped estimate when DOM read is unavailable. | DEFERRED (fast rendered-line class absent) |
| GVLI-079 | FastRenderedViewLine `_getReadingTarget` (`:457-459`) | First-child reading-target member; the DOM property read stays on this method row. | DEFERRED (fast rendered-line class absent) |
| GVLI-080 | FastRenderedViewLine `_actualReadPixelOffset` (`:461-471`) | Missing member; maps the column to one collapsed RangeUtil query and returns its first left. | DEFERRED (fast rendered-line class absent) |
| GVLI-081 | fast no-DOM early return `-1` (`:462-464`) | Missing. | DEFERRED (fast rendered-line class absent) |
| GVLI-082 | fast null-or-empty range early return (`:467-469`) | Missing. | DEFERRED (fast rendered-line class absent) |
| GVLI-083 | RenderedViewLine `domNode` field (`:483`) | Local ViewLine owns cached DOM directly. | PORTED |
| GVLI-084 | RenderedViewLine `input` field (`:484`) | Existing `render_input`. | PORTED |
| GVLI-085 | RenderedViewLine `_characterMapping` (`:486`) | Existing `character_mapping`. | PORTED |
| GVLI-086 | RenderedViewLine `_isWhitespaceOnly` (`:487,500`) | Cached whitespace-only fact is retained with the rendered line. | TESTED |
| GVLI-087 | RenderedViewLine `_containsForeignElements` (`:488,501`) | Retains the full None/Before/After/BeforeAndAfter foreign-element fact. | TESTED |
| GVLI-088 | RenderedViewLine `_cachedWidth` (`:489,502,526-530`) | Cached width is retained and reused until explicit reset. | TESTED |
| GVLI-089 | RenderedViewLine `_pixelOffsetCache` (`:494,504-510`) | LTR per-column cache retains measured pixel offsets. | TESTED |
| GVLI-090 | RenderedViewLine constructor (`:496-511`) | Member owns whitespace/foreign facts, `-1` width, null default, LTR cache size minimum 2, and sentinel fill. | TESTED |
| GVLI-091 | LTR pixel-cache allocation branch (`:505-510`) | Allocate only for LTR; RTL retains null. | TESTED |
| GVLI-092 | RenderedViewLine `_getReadingTarget` (`:515-517`) | Expose the slow first-child reading-target member; ordinary DOM property read stays here. | TESTED |
| GVLI-093 | RenderedViewLine `getWidth` (`:522-531`) | Owns no-DOM and cache semantics plus the offsetWidth read and layout mark around the counted branches. | TESTED |
| GVLI-094 | slow no-DOM early return `0` (`:523-525`) | Exact rendered-DOM state guard returns zero before the width cache or DOM is touched. | TESTED |
| GVLI-095 | slow cached-width-miss branch (`:526-529`) | Read once and mark DOM layout. | TESTED |
| GVLI-096 | RenderedViewLine `getWidthIsFast` (`:533-538`) | Returns false until width is cached and true afterward. | TESTED |
| GVLI-097 | uncached false branch (`:534-536`) | Exact uncached branch is preserved. | TESTED |
| GVLI-098 | RenderedViewLine `resetCachedWidth` (`:540-547`) | Resets both width and pixel-offset caches. | TESTED |
| GVLI-099 | nonnull pixel-cache clear branch (`:542-546`) | Fill every entry with `-1`. | TESTED |
| GVLI-100 | RenderedViewLine `getVisibleRangesForRange` (`:552-572`) | Strategy member uses the retained caches and source endpoint repairs. | TESTED |
| GVLI-101 | slow no-DOM null early return (`:553-555`) | Returns the nullable outcome before a slow DOM read. | TESTED |
| GVLI-102 | LTR pixel-cache branch (`:556-569`) | One cache branch: LTR cache reads start/end and returns one range; null cache falls through to raw-range reading. | TESTED |
| GVLI-103 | start-offset `-1` early return (`:558-561`) | Returns the nullable outcome for an unmappable start. | TESTED |
| GVLI-104 | end-offset `-1` early return (`:563-566`) | Returns the nullable outcome for an unmappable end. | TESTED |
| GVLI-105 | `_readVisibleRangesForRange` (`:574-585`) | Preserves collapsed-versus-range dispatch. | TESTED |
| GVLI-106 | collapsed-vs-noncollapsed range branch (`:575–584`) | One `if/else`: collapsed reads one pixel/zero width; noncollapsed delegates raw range. Failed collapsed pixel remains separate. | TESTED |
| GVLI-107 | collapsed pixel `-1` early return (`:577-579`) | Returns the nullable outcome when the collapsed pixel is unavailable. | TESTED |
| GVLI-108 | `_readPixelOffset` (`:587-626`) | Preserves foreign-element and LTR cache control flow. | TESTED |
| GVLI-109 | empty LTR mapping branch (`:588-610`) | Distinguish four foreign-element cases. | TESTED |
| GVLI-110 | empty line with no foreign element (`:590-593`) | Return zero. | TESTED |
| GVLI-111 | empty line with only after foreign element (`:594-597`) | Return zero. | TESTED |
| GVLI-112 | empty line with only before foreign element (`:598-601`) | Return measured full width. | TESTED |
| GVLI-113 | before-and-after `firstChild` presence branch (`:602-609`) | Before-and-after empty foreign-content branch reads/marks first-child width when present; otherwise returns zero. | TESTED |
| GVLI-114 | LTR pixel-cache branch (`:612-623`) | One LTR cache branch owns hit reuse and miss read/store; absence falls through to actual reading. | TESTED |
| GVLI-115 | cached pixel hit early return (`:615-618`) | Returns the retained LTR pixel without another DOM read. | TESTED |
| GVLI-116 | RenderedViewLine `_actualReadPixelOffset` (`:628-658`) | Helper owns mapped collapsed RangeUtil reads and returns actual left unless the counted stabilization branch applies. | TESTED |
| GVLI-117 | empty mapping RangeUtil branch (`:629-636`) | Query collapsed zero endpoint instead of assuming zero. | TESTED |
| GVLI-118 | empty-mapping null/empty range early return (`:632-634`) | Returns `-1` for a missing collapsed DOM range. | TESTED |
| GVLI-119 | whitespace-only LTR final-column branch (`:638-641`) | Return measured width for CSS-sized whitespace lines. | TESTED |
| GVLI-120 | mapped null/empty range early return (`:646-648`) | Preserves the source nullable result. | TESTED |
| GVLI-121 | basic-ASCII stabilization branch (`:650-656`) | Prefer rounded expected monospace x only within one CSS pixel. | TESTED |
| GVLI-122 | expected-versus-actual tolerance `<= 1` (`:651-655`) | Preserve exact inclusive tolerance and rounding. | TESTED |
| GVLI-123 | `_readRawVisibleRangesForRange` (`:660-672`) | Member owns mapped start/end DomPositions and common RangeUtil delegation around the whole-line branch. | TESTED |
| GVLI-124 | full LTR whole-line branch (`:662-666`) | Return `(0,getWidth)` without a DOM Range. | TESTED |
| GVLI-125 | WebKitRenderedViewLine override (`:682-706`) | Missing browser-specific correction. | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-126 | compound no-correction early return (`:686-688`) | Null/empty/collapsed/full-line ranges return unchanged. | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-127 | LTR-only correction branch (`:692-703`) | Missing. | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-128 | valid end-pixel branch (`:695-702`) | Missing. | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-129 | last-range-left-before-end trim branch (`:697-701`) | Set final width to end x minus left. | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-130 | module `createRenderedLine` function-valued constant (`:709–714`) | Retain the selected normal/WebKit factory; selector IIFE and platform branch are separate. | TESTED |
| GVLI-131 | `createRenderedLine` selector IIFE callback (`:709–714`) | Source-owned callback selects WebKit on its branch and otherwise returns the normal factory. | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-132 | WebKit factory-selection branch (`:710-712`) | Missing. | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-133 | `createWebKitRenderedLine` callback (`:716-718`) | Missing. | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-134 | `createNormalRenderedLine` callback (`:720-722`) | Function-valued normal factory preserves the source callback seam with a MoonBit-owned representation. | TESTED |
GVLI denominator: **134**.

#### Denominator and final disposition

```text
GVL    55 = 53 TESTED + 1 PORTED + 1 DEFERRED
GVLI  134 = 75 TESTED + 5 PORTED + 54 DEFERRED
GDRC   16 = 15 TESTED + 1 PORTED
GRU    25 = 25 TESTED
GVLO   16 = 13 TESTED + 2 DEFERRED + 1 N-A
       ---
Total 246 = 181 TESTED + 7 PORTED + 57 DEFERRED + 1 N-A
```

N-A is limited to the reviewed CSS/root-owned theme seam. Native-host, experimental-whitespace, GPU, fast-renderer, zoom-policy, and WebKit gaps remain DEFERRED.

#### Normalization record

- GDRC removed draft `008–011`; `readClientRect` owns its straight-line DOM reads. Result: `20 - 4 = 16`.
- GRU removed draft `004,006,008,009,010,015,018,021,022,028,029,037,038`; merged the two adjacency arms and removed the GRC-owned comparator callsite. Result: `38 - 13 = 25`.
- GVLO removed draft `016/017`; field rows own their arithmetic. Experimental/GPU fields changed N-A→DEFERRED. Result: `18 - 2 = 16`.
- GVL removed draft `007,010,014,015,016,017,018,052`; frozen handoffs stay outside the denominator and schedule/cancel is one branch. Independent Gate B restored omitted `getDomNode`, `prepareRender`, and `render` members and source-ordered `_lastRenderedData`. Result: `60 - 8 + 3 = 55`.
- GVLI removed draft `004,009,012,060,064,070,093,097,107,111,118,121,138,143`; added the two selector IIFE callbacks, the omitted ViewLine constructor, and split the two prior-DOM ternaries. Independent Gate B restored `ViewLine.CLASS_NAME`, source-ordered the appended experimental/prior-DOM atoms, changed the native-host and fast-constructor rows to DEFERRED, and retained GPU/experimental DEFERRED outcomes. Result: `143 - 14 + 5 = 134`.

#### Final local mapping and reviewed seams

1. `DomReadingContext` owns the two nodes and four lazy cache/layout facts;
   first/repeated reads, scale/delta, and zero-width fallback are tested.
2. `RangeUtil` reuses one owner-document Range, preserves nullable failures,
   unconditionally parks it, and closes every endpoint/merge/scale branch.
3. `ViewLineOptions` consumes measured FontInfo facts. Typed theme remains
   CSS/root-owned; experimental whitespace and GPU options stay DEFERRED.
4. The normal slow `RenderedViewLine` owns width/pixel caches, truncation,
   whitespace, and both foreign-element bits. Fast, WebKit, zoom-policy, and
   GPU strategies remain the row-local DEFERRED seams recorded above.
5. `ViewLines` owns the 200ms cancel/reschedule sweep, measured max feedback,
   full-document shrink reset, converter/direction progression, and raw
   multi-line visible-range queries. The current ViewModel supplies LTR only.
6. Rabbita lacks a global typed Range binding, so the reusable Range is created
   from the first start node's `ownerDocument`; rendered rows retain the
   browser harness's `data-line` marker. Both seams are contract-documented.

#### Behavior-variable and branch matrix

| Axis | Required cases and boundaries | Lowest useful evidence |
|---|---|---|
| DOM reading context | first read versus repeated read; delta left; scale above and below 1; `offsetWidth` zero fallback | browser unit plus read-count spy |
| DOM children/endpoints | zero children; one nonempty span; empty span; cross-span end offset zero; missing start; missing end; both missing; negative and oversized indices/offsets | browser RangeUtil suite |
| DOM Range lifetime | first create; identity reuse; success; throwing `setStart` or `setEnd`; unconditional detach on both outcomes | browser unit with Range spy |
| rect normalization | null, empty, one, bidi-unsorted many; negative normalized left; overlapping/adjacent gap at `0.9`; gap just above `0.9`; nonunit scale | browser RangeUtil suite |
| rendered window | requested line/range before, inside, after, and partially overlapping the rendered range; zero versus several results | ViewLines white-box plus browser |
| newline width | `includeNewLines` false/true; same model line due wrapping versus next model line; LTR/RTL; first/middle/final view line | white-box converter matrix |
| width cache | no rendered line; uncached; cached; reset; fast-readable and slow-readable; partial window and full document | retained-line/ViewLines white-box |
| max width | initial zero; minimum local width one; grows; equal; shrinks while partial; full-document reset; wrapping/layout/flush reset; zones reapply | ViewLines plus ViewLayout integration |
| scheduling | fast sweep complete/incomplete; scheduler idle/scheduled; unrelated DOM query did/did not force layout; cancel-before-slow; exact 200ms delay | deterministic scheduler white-box |
| render geometry | scroll width/height; height at and around 1,000,000; positive/zero scroll offsets; bigNumbersDelta; layer hinting; strict containment | browser component |
| rendered attachment | rendered strategy absent/present for `setDomNode`: exact invariant failure versus cached-wrapper attachment | ViewLine white-box |
| row direction and CSS | RTL gives `dir="rtl"` plus scrollbar-sized right padding; LTR with `containsRTL` gives `dir="ltr"`; plain LTR has no direction attribute; class/top/height/line-height remain exact | HTML unit plus browser component |
| layout-line DOM guard | no rendered strategy; rendered strategy with null DOM; rendered strategy with DOM; only the last case writes top/height/line-height | ViewLine white-box with DOM-write spy |
| renderer strategy | no DOM; slow class; width/pixel cache hit/miss; slow-constructor prior-DOM reuse; foreign elements; fast class, 299/300/301 threshold, variable-font gate, and fast prior-DOM ternary remain ledger-DEFERRED with no TESTED claim | ViewLine white-box and browser |
| unsupported ViewLines entrypoints | `prepareRender` and `render` each fail with exact `Not supported`; `renderText` remains the only text-render route | ViewPart white-box panic checks |
| visible ranges | collapsed/noncollapsed; LTR/RTL; empty mapping; whitespace-only; basic ASCII tolerance at 1 and above 1; truncation before/at/after stop column | ViewLine and RangeUtil browser suite |
| foreign content | None, Before, After, and BeforeAndAfter on an empty line; first child present/absent; generated fold ellipsis | deterministic browser fixture |
| options/font facts | each applicable ViewLineOptions field independently changed; equality no-op; monospace disabled; halfwidth arrow; ligatures; vertical scrollbar; theme N-A plus experimental/GPU DEFERRED options | option-flow white-box plus fixed fonts |
| platform | Chromium gating; native-host/browser-zoom, GPU, and WebKit rows remain explicit DEFERRED outcomes; only the CSS/root-owned theme seam is N-A | ledger review; no unsupported PASS |

#### Historical inventory stop gate

- [x] Source hashes and line counts match the pinned oracle.
- [x] Prefix IDs are contiguous/unique, source-ordered, and final four-column row counts are 55/134/16/25/16.
- [x] Final terminals total 181/7/57/1 with zero TODO/PASS.
- [x] Frozen handoffs and excluded sibling clusters are stated without duplicate ownership.
- [x] Independent Gate B approves the normalized denominator and boundary decisions.

The historical stop was independently approved before implementation.

### Group B — ContentWidgets and RenderingContext

#### Uniform atom rule

One row represents one declared member, field/property, behavior-changing branch or early return, independently material source-owned callback or control-flow magic constant, or owned DOM/CSS fact. A field owns its literal/arithmetic. Ordinary allocation, straight-line statements, intermediate arithmetic, loop mechanics, and final returns remain on their owning member row.

The corrected normalized denominator is 176 final rows: GCW 122 + GRC 54.

#### Ownership and exclusions

- Frozen render rows CW-001–CW-021 own `_widgets`, `Widget._context`, `_contentWidth`, `_contentLeft`, both retained anchors, `_affinity`, `_maxWidth`, all ViewPart handlers, anchor reprojection, inner configuration/update methods, and the layoutInfo gate. This ledger consumes those facts without recounting their fields.
- Frozen lifecycle CEW-058 owns editor-level widget-registration persistence and VIEW-061 owns global lines-content child order. GCW owns only inner construction, normal/overflow mount choice, positioning, and render geometry.
- `dispose`, `removeWidget`, and map-removal lifetime are excluded lifecycle siblings. `shouldSuppressMouseDownOnWidget` and `Widget.suppressMouseDown` are excluded input/controller siblings. They are named exclusions, not denominator rows.
- In `renderingContext.ts`, unrelated base viewport/decorations helpers are excluded siblings: `viewportData`, `scrollWidth`, `scrollHeight`, `visibleRange`, `getScrolledTopFromAbsoluteTop`, `getVerticalOffsetAfterLineNumber`, and `getDecorationsInViewport`.
- GPU query atoms remain ledgered because they occur inside closed query members, but Phase 0 explicitly excludes GPU ViewLines; they are DEFERRED, not N-A.
- ViewLines, ViewLine, DomReadingContext, and RangeUtil own DOM/range producers. GRC owns only the query facade, fallback/merge order, and returned carriers.

#### Source evidence

| Prefix | Pinned file | Lines | SHA-256 |
|---|---|---:|---|
| GCW | `vscode/src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts` | 633 | `e524a6baaf256fb8e8d427a76f217cd832954bdabaf11b73e1e066b6dd50f7a6` |
| GRC | `vscode/src/vs/editor/browser/view/renderingContext.ts` | 217 | `1f10fa65e8235e03bfcb987cd19df7aaca34cac8d73b8be3bca31b8c556e47f9` |

Both files were read completely at the checked-in source. GCW closes the geometry-owned container/mount, validation, anchor, measurement/cache, placement, focus, callback, write, and carrier clusters. GRC closes the widget-consumed restricted facts, DOM/GPU query facade, and range/position carriers.

#### GCW ledger — `contentWidgets.ts`

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GCW-001 | `ViewContentWidgets._viewDomNode` (`:27,35`) | Retain the editor root used as the page-space reference box; local `ContentWidgets.view_dom_node`. | TESTED |
| GCW-002 | `ViewContentWidgets.domNode` (`:30,38–43`) | Normal, content-space widget container; local `ContentWidgets.dom_node`. | TESTED |
| GCW-003 | `overflowingContentWidgetsDomNode` (`:31,44–47`) | Editor-root/page-space overflow container; local overflowing container. | TESTED |
| GCW-004 | `ViewContentWidgets` constructor (`:33–47`) | Preserve root assignment and DOM creation/write order; `_widgets` initialization is inherited CW-001. | TESTED |
| GCW-005 | `PartFingerprint.ContentWidgets` (`:39`) | Stamp the normal container with the exact fingerprint. | TESTED |
| GCW-006 | normal class `contentWidgets` (`:40`) | Preserve the owned class. | TESTED |
| GCW-007 | normal container `position:absolute` (`:41`) | Preserve the coordinate-space CSS property. | TESTED |
| GCW-008 | normal container `top:0` (`:42`) | Preserve the zero top origin. | TESTED |
| GCW-009 | `PartFingerprint.OverflowingContentWidgets` (`:45`) | Stamp the overflow container with the exact fingerprint. | TESTED |
| GCW-010 | overflow class `overflowingContentWidgets` (`:46`) | Preserve the owned class. | TESTED |
| GCW-011 | `addWidget` geometry subcluster (`:102–113`) | Own construction, map insertion, and dirtying; registration persistence is inherited and the following row alone owns the mount-container branch. | TESTED |
| GCW-012 | overflow mount branch (`:106–110`) | Append to overflow container iff the effective widget overflow flag is true, otherwise to normal container. | TESTED |
| GCW-013 | outer `setWidgetPosition` (`:115–122`) | Look up by `getId`, delegate all anchors/preferences/affinity, then apply its render scheduling gate. | TESTED |
| GCW-014 | `!useDisplayNone` scheduling branch (`:119–121`) | Explicit widget capability suppresses dirtying for widgets that own their display state; both arms are tested. | TESTED |
| GCW-015 | outer `onBeforeRender` (`:145–150`) | Visit every retained widget in key order before the read phase. | TESTED |
| GCW-016 | outer `prepareRender` (`:152–157`) | Visit every retained widget and compute render data. | TESTED |
| GCW-017 | outer `render` (`:159–164`) | Visit every retained widget in the write phase. | TESTED |
| GCW-018 | `IBoxLayoutResult.fitsAbove` (`:168`) | Retain the above-fit decision. | PORTED |
| GCW-019 | `IBoxLayoutResult.aboveTop` (`:169`) | Retain the above coordinate. | PORTED |
| GCW-020 | `IBoxLayoutResult.fitsBelow` (`:171`) | Retain the below-fit decision. | PORTED |
| GCW-021 | `IBoxLayoutResult.belowTop` (`:172`) | Retain the below coordinate. | PORTED |
| GCW-022 | `IBoxLayoutResult.left` (`:174`) | Retain the clamped horizontal coordinate. | PORTED |
| GCW-023 | off-viewport `kind='offViewport'` (`:178`) | Closed render-data discriminator. | PORTED |
| GCW-024 | off-viewport `preserveFocus` (`:179`) | Carry the active-descendant probe into the write phase. | TESTED |
| GCW-025 | in-viewport `kind='inViewport'` (`:183`) | Closed render-data discriminator. | PORTED |
| GCW-026 | in-viewport `coordinate` (`:184`) | Carry exact top/left. | PORTED |
| GCW-027 | in-viewport `position` (`:185`) | Render data carries the selected ABOVE/BELOW/EXACT preference unchanged to `afterRender`. | TESTED |
| GCW-028 | `IRenderData` union (`:188`) | Preserve exactly the in-viewport/off-viewport union; nullable outer state belongs only to `_renderData`. | PORTED |
| GCW-029 | `Widget._viewDomNode` (`:192,218`) | Per-widget page reference; local passes the retained outer root into prepare. | TESTED |
| GCW-030 | `Widget._actual` (`:193,219`) | Retain the public widget for callbacks, flags, and DOM. | PORTED |
| GCW-031 | `Widget.domNode` (`:195,225`) | Cache the exact owner-provided node. | TESTED |
| GCW-032 | `Widget.id` (`:196,226,246`) | Cache exact `getId()` and use it for `widgetId`. | TESTED |
| GCW-033 | `Widget.allowEditorOverflow` (`:197,227,243,287,481,516,579`) | Cache the optional widget flag with false default; GCW-042 alone owns the subsequent editor `allowOverflow` conjunction. Downstream mount, coordinate, max-width, placement, and write branches consume the resulting effective boolean. | TESTED |
| GCW-034 | `Widget._fixedOverflowWidgets` (`:200,231,243,385`) | Source option changes fixed positioning and absolute page coordinates; local Viewer has no option. | DEFERRED (fixedOverflowWidgets option seam not exposed) |
| GCW-035 | `Widget._preference` (`:207,236,295,448,489`) | Retain nullable ordered preferences, initialized to `[]`; local distinguishes null, empty, and ordered values. | TESTED |
| GCW-036 | `_cachedDomNodeOffsetWidth` (`:208,237,305,461,468,478`) | Initialize/reset the width cache to exact sentinel `-1`; it participates independently in the OR cache-miss gate. | TESTED |
| GCW-037 | `_cachedDomNodeOffsetHeight` (`:209,238,306,461,469`) | Initialize/reset the height cache to exact sentinel `-1`; it participates independently in the OR cache-miss gate. | TESTED |
| GCW-038 | `_isVisible` (`:211,240,559,561,587,590`) | Initialize false; sticky last-write state gates visibility and marker mutations. | TESTED |
| GCW-039 | `_renderData` (`:213,241,553,557–595`) | Retain one nullable prepared result, initialized null, for the write phase. | TESTED |
| GCW-040 | `useDisplayNone` (`:214,229,296`) | Cache the optional owner flag with false default; it controls display writes and outer scheduling. | TESTED |
| GCW-041 | `Widget` constructor (`:216–248`) | Preserve option reads, field initialization, then DOM writes in source order. | TESTED |
| GCW-042 | editor `allowOverflow` gate (`:223,227`) | Solely own the `&& allowOverflow` conjunction: an owner widget request becomes effective only when the editor option permits overflow. Local Viewer exposes no such option. | DEFERRED (allowOverflow option seam not exposed) |
| GCW-043 | fixed-vs-absolute position branch (`:243`) | `fixed` only for fixed+overflow; otherwise `absolute`. | DEFERRED (fixedOverflowWidgets option seam not exposed) |
| GCW-044 | initial `display:none` (`:244`) | Keep an unpositioned widget out of layout. | TESTED |
| GCW-045 | initial `visibility:hidden` (`:245`) | Keep initial content invisible while mounted. | TESTED |
| GCW-046 | `widgetId` attribute (`:246`) | Write the exact hit-test attribute/value. | TESTED |
| GCW-047 | constructor max-width write (`:247`) | Apply the cached maximum once at construction. | TESTED |
| GCW-048 | `_setPosition` (`:264–281`) | Retain affinity, then run one method-local validation/conversion helper for primary and secondary in order; ordinary validation and affinity forwarding stay on this member row. | TESTED |
| GCW-049 | null-position early return (`:269–272`) | Produce `(null,null)` without validation/conversion. | TESTED |
| GCW-050 | model-visible branch (`:275–278`) | Convert only visible validated model positions; retain the caller's original model position alongside the view result. | TESTED |
| GCW-051 | `_getMaxWidth` document/window reads (`:283–290`) | Read the widget owner document/window, select overflow fallback chain versus `_contentWidth`, and return the chosen maximum. | TESTED |
| GCW-052 | max-width overflow branch (`:287–289`) | Overflowing widgets use page/window width; normal widgets use `_contentWidth`. | TESTED |
| GCW-053 | overflow width fallback chain (`:288`) | Preserves exact owner-document priority: `defaultView.innerWidth`, documentElement `offsetWidth`, then body `offsetWidth`. | TESTED |
| GCW-054 | `Widget.setPosition` (`:293–307`) | Reproject anchors, assign nullable preference, apply the display gate, then reset both size caches to `-1`. | TESTED |
| GCW-055 | display measurement gate (`:296–304`) | Set block iff source owns display, primary view anchor exists, and preferences are non-null/nonempty; else none. | TESTED |
| GCW-056 | `_layoutBoxInViewport` (`:309–335`) | Compute vertical candidates and inclusive fit facts, apply right-then-left horizontal clamps, and return one layout carrier. | TESTED |
| GCW-057 | right-edge clamp first (`:326–329`) | If `left+width` exceeds `scrollLeft+viewportWidth`, move left to exact right containment. | TESTED |
| GCW-058 | left-edge clamp second (`:330–332`) | Then clamp to `scrollLeft`, including widgets wider than the viewport. | TESTED |
| GCW-059 | `_layoutHorizontalSegmentInPage` (`:337–363`) | Compute owner-window absolute left, preserve relative/absolute lockstep through both clamps, then return `[left, absoluteLeft]`; constants/branches remain separate rows. | TESTED |
| GCW-060 | `LEFT_PADDING = 15` (`:339`) | Exact left page clearance. | TESTED |
| GCW-061 | `RIGHT_PADDING = 15` (`:340`) | Exact right page clearance. | TESTED |
| GCW-062 | `MIN_LIMIT` (`:343`) | `max(15, editorLeft-width)`. | TESTED |
| GCW-063 | `MAX_LIMIT` (`:344`) | `min(editorLeft+editorWidth+width, windowWidth-15)`. | TESTED |
| GCW-064 | owner-window `scrollX ?? 0` fallback (`:346–348`) | Read `_viewDomNode.ownerDocument.defaultView`; when it is absent, subtract exact zero rather than consulting the global window. | TESTED |
| GCW-065 | right-overflow delta branch (`:350–354`) | Shift both absolute and relative left by the same exact delta. | TESTED |
| GCW-066 | left-underflow delta branch (`:356–360`) | Apply the second exact delta to both coordinates. | TESTED |
| GCW-067 | `_layoutBoxInPage` (`:365–396`) | Compute page candidates from the owner node/window/client area, call the horizontal helper, derive fit facts, then return fixed or relative coordinates. | TESTED |
| GCW-068 | owner-window `scrollY ?? 0` fallback (`:370–373`) | Apply the same owner-document `defaultView` choice and exact-zero fallback to both absolute-above and absolute-below calculations; never read global scroll state. | TESTED |
| GCW-069 | `TOP_PADDING = 22` (`:379`) | Exact top page clearance. | TESTED |
| GCW-070 | `BOTTOM_PADDING = 22` (`:380`) | Exact bottom page clearance. | TESTED |
| GCW-071 | fixed-overflow return (`:385–393`) | Use absolute left/below, clamp above to top padding, and preserve fit bits. | DEFERRED (fixedOverflowWidgets option seam not exposed) |
| GCW-072 | `_prepareRenderWidgetAtExactPositionOverflowing` (`:398–400`) | Shift exact overflow x by `_contentLeft`, leaving top unchanged. | TESTED |
| GCW-073 | `_getAnchorsCoordinates` (`:407–429`) | Compute primary first and only a same-line secondary through one method-local coordinate helper; ordinary visible-range/top/line-height queries stay on this member row. | TESTED |
| GCW-074 | same-line secondary gate (`:409–410`) | Discard a secondary on another line before querying DOM geometry. | TESTED |
| GCW-075 | coordinate null-position early return (`:413–416`) | No position yields no anchor without querying visible ranges. | TESTED |
| GCW-076 | missing visible-range early return (`:418–421`) | An unrendered/unmeasurable line yields no anchor; no uniform-column fallback is synthesized. | TESTED |
| GCW-077 | left-of-injected-text column-one rule (`:423–424`) | Force left zero exactly for column 1 plus `LeftOfInjectedText`; otherwise use measured `HorizontalPosition.left`. | TESTED |
| GCW-078 | `_reduceAnchorCoordinates` (`:431–445`) | Declared member owns the fullwidth read, straight-line left arithmetic, and final anchor construction; early return and side branch remain separate. | TESTED |
| GCW-079 | `_reduceAnchorCoordinates` no-secondary branch (`:431–434`) | Return the primary object unchanged when secondary is absent. | TESTED |
| GCW-080 | secondary side-of-primary branch (`:438–443`) | Single side-of-primary branch: left uses `max(secondary, primary-width+fullwidth)`; right/equal uses `min(secondary, primary+width-fullwidth)`. | TESTED |
| GCW-081 | `_prepareRenderWidget` (`:447–534`) | Own anchor query order, rounded size acquisition, reduction, page/viewport placement, two-pass preference traversal, and ordinary final null; behavior branches remain separate. | TESTED |
| GCW-082 | absent/empty preference early return (`:448–450`) | Null or empty preference produces null render data before anchor work. | TESTED |
| GCW-083 | missing-primary off-viewport result (`:453–459`) | Return `offViewport` and probe whether the widget contains the owner document's active element. | TESTED |
| GCW-084 | size-cache OR gate (`:461`) | Measure when either width or height equals `-1`; one valid cache cannot mask the other invalid cache. | TESTED |
| GCW-085 | optional `beforeRender` callback branch (`:463–466`) | Calls only when the capability is present, with the widget argument, through the safe helper. | TESTED |
| GCW-086 | preferred-dimensions/DOM-fallback branch (`:467–475`) | One branch: non-null preferred dimensions supply width/height; otherwise measure the live rect and `Math.round` width/height independently. | TESTED |
| GCW-087 | page-versus-viewport placement (`:480–485`) | Overflow uses page layout; normal uses viewport layout. | TESTED |
| GCW-088 | ABOVE discriminator (`:491`) | Handle ABOVE before BELOW/EXACT. | TESTED |
| GCW-089 | ABOVE null-placement early return (`:492–495`) | Return null if page placement is null. Both scoped layout helpers are non-null at this pin. | N-A (source-unreachable with pinned layout helpers) |
| GCW-090 | ABOVE fit/pass branch (`:496–502`) | Return above on first pass only when fitting, or unconditionally on pass two. | TESTED |
| GCW-091 | BELOW discriminator (`:503`) | Handle BELOW after ABOVE. | TESTED |
| GCW-092 | BELOW null-placement early return (`:504–507`) | Return null if page placement is null. Both scoped layout helpers are non-null at this pin. | N-A (source-unreachable with pinned layout helpers) |
| GCW-093 | BELOW fit/pass branch (`:508–514`) | Return below on first pass only when fitting, or unconditionally on pass two. | TESTED |
| GCW-094 | EXACT overflow-vs-normal branch (`:515–528`) | One exact-position branch: overflow shifts x by `_contentLeft`; normal returns anchor top/left unchanged. | TESTED |
| GCW-095 | `Widget.onBeforeRender` (`:539–550`) | Apply cached max width only for a positionable widget whose anchor line is inside the inclusive rendered viewport; final write stays on this member row. | TESTED |
| GCW-096 | missing anchor/preference early return (`:540–542`) | Return before any DOM write. | TESTED |
| GCW-097 | inclusive viewport-line guard (`:544–547`) | Return when line is `< start` or `> end`; both endpoints are included. | TESTED |
| GCW-098 | `Widget.prepareRender` (`:552–554`) | Replace `_renderData` once with the complete prepare result. | TESTED |
| GCW-099 | `Widget.render` (`:556–596`) | Declared write-phase member owns hidden/visible ordering and callback timing; branches, early return, magic constant, and transitions remain separate. | TESTED |
| GCW-100 | `Widget.render` hidden discriminator (`:556–576`) | Null and offViewport share the invisible branch. | TESTED |
| GCW-101 | visible-to-hidden transition (`:559–562`) | Only a previously visible widget removes the marker and flips `_isVisible`. | TESTED |
| GCW-102 | preserve-focus-vs-hide branch (`:563–569`) | One focus branch: focused off-viewport widgets park at the magic top; all other hidden transitions write visibility hidden. | TESTED |
| GCW-103 | focus-preserving `top=-1000` (`:564–566`) | Focused off-viewport widgets use the exact parking constant while leaving visibility inherited. | TESTED |
| GCW-104 | hidden `afterRender` callback (`:572–574`) | If present, safely invoke with `(null,null)` even when already invisible. | TESTED |
| GCW-105 | hidden early return (`:575`) | Stop before visible coordinate writes. | TESTED |
| GCW-106 | visible overflow-vs-normal coordinate branch (`:579–585`) | One visible-coordinate branch: overflow writes prepared top/left; normal writes `top + scrollTop - bigNumbersDelta` and the same left. | TESTED |
| GCW-107 | hidden-to-visible transition (`:587–591`) | Only on transition set visibility inherit, marker=`true`, then `_isVisible=true`. | TESTED |
| GCW-108 | visible `afterRender` callback (`:593–595`) | Safely pass selected preference and exact rendered coordinate. | TESTED |
| GCW-109 | `PositionPair.modelPosition` (`:599–603`) | Immutable nullable original model anchor. | PORTED |
| GCW-110 | `PositionPair.viewPosition` (`:599–603`) | Immutable nullable projected view anchor. | PORTED |
| GCW-111 | `Coordinate._coordinateBrand` (`:606–607`) | TypeScript nominal brand only. | N-A (MoonBit nominal struct type) |
| GCW-112 | `Coordinate.top` (`:609–612`) | Immutable rendered top. | PORTED |
| GCW-113 | `Coordinate.left` (`:609–612`) | Immutable rendered left. | PORTED |
| GCW-114 | `AnchorCoordinate._anchorCoordinateBrand` (`:615–616`) | TypeScript nominal brand only. | N-A (MoonBit nominal struct type) |
| GCW-115 | `AnchorCoordinate.top` (`:618–622`) | Immutable viewport-relative top. | PORTED |
| GCW-116 | `AnchorCoordinate.left` (`:618–622`) | Immutable content-space left. | PORTED |
| GCW-117 | `AnchorCoordinate.height` (`:618–622`) | Immutable per-line height. | PORTED |
| GCW-118 | `safeInvoke` (`:625–632`) | Generic callback wrapper invokes with exact `thisArg`/arguments and returns the result; its catch branch returns null. | TESTED |
| GCW-119 | callback exception branch (`:629–631`) | Swallow any callback exception and return null. | TESTED |
| GCW-120 | `PositionPair` constructor (`:599–603`) | Assign model and view positions without conversion; field rows GCW-109/110 own the values. | PORTED |
| GCW-121 | `Coordinate` constructor (`:609–612`) | Assign top/left without rounding or coordinate-space conversion. | PORTED |
| GCW-122 | `AnchorCoordinate` constructor (`:618–622`) | Assign top/left/height without transformation. | PORTED |
GCW denominator: **122** rows.

#### GRC ledger — `renderingContext.ts`

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GRC-001 | `IViewLines.linesVisibleRangesForRange` (`:12–14`) | Local query facade returns complete per-line visible ranges with `includeNewLines`. | TESTED |
| GRC-002 | `IViewLines.visibleRangeForPosition` (`:14`) | Local query facade returns a measured caret x or null and is threaded into ContentWidgets. | TESTED |
| GRC-003 | `RestrictedRenderingContext` brand (`:17–18`) | TypeScript nominal brand only. | N-A (MoonBit nominal struct type) |
| GRC-004 | `bigNumbersDelta` (`:26,44`) | Widget normal-layer write consumes the exact viewport delta. | TESTED |
| GRC-005 | `scrollTop` (`:28,47`) | Widget anchor/read and normal write consume the same viewport top. | TESTED |
| GRC-006 | `scrollLeft` (`:29,48`) | Viewport/page horizontal placement consumes the exact left. | TESTED |
| GRC-007 | `viewportWidth` (`:31,49`) | Right-edge clamp input. | TESTED |
| GRC-008 | `viewportHeight` (`:32,50`) | Below-fit input. | TESTED |
| GRC-009 | `_viewLayout` (`:34,37,46,58,66`) | Retain one layout owner for viewport and per-line geometry queries. | PORTED |
| GRC-010 | restricted-context constructor (`:36–51`) | Snapshot all scoped fields in source order, using one `getCurrentViewport()` result for top/left/width/height; excluded base fields remain named siblings. | TESTED |
| GRC-011 | `getVerticalOffsetForLineNumber` (`:57–59`) | Delegate exact line and optional `includeViewZones` to ViewLayout. | TESTED |
| GRC-012 | `getLineHeightForLineNumber` (`:65–67`) | Delegate the exact requested line through the retained layout capability. | TESTED |
| GRC-013 | `RenderingContext` brand (`:75–76`) | TypeScript nominal brand only. | N-A (MoonBit nominal struct type) |
| GRC-014 | `RenderingContext._viewLines` (`:78,83`) | Retain the DOM view-lines query target. | PORTED |
| GRC-015 | optional `_viewLinesGpu` (`:79,84,89–103`) | Optional GPU query target; local renderer has no GPU ViewLines. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-016 | `RenderingContext` constructor (`:81–85`) | Call base first, then retain DOM and optional GPU targets. | PORTED |
| GRC-017 | `linesVisibleRangesForRange` GPU-bearing remainder (`:87–100`) | The declared member queries DOM first; after GRC-018's no-GPU early return, this row owns the optional GPU query and the both-present DOM-before-GPU concat/sort path. Those behaviors remain absent while GPU ViewLines is excluded. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-018 | no-GPU early return (`:89–91`) | Return DOM result, including null, without another query. | TESTED |
| GRC-019 | DOM-null GPU return (`:93–95`) | GPU-only result wins when DOM has no ranges. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-020 | GPU-null DOM return (`:96–98`) | DOM-only result wins when GPU has no ranges. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-021 | `visibleRangeForPosition` (`:102–104`) | Own the exact DOM → optional GPU → null expression; the two nullish behavior gates remain separate rows. | TESTED |
| GRC-022 | DOM position wins (`:103`) | First nullish gate: a non-null DOM result wins; otherwise evaluate the GPU fallback. | TESTED |
| GRC-023 | GPU position fallback (`:103`) | Second nullish gate: a non-null GPU result wins; otherwise return null. | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-024 | `LineVisibleRanges.firstLine` (`:111–122`) | Return the smallest line number independent of input order; an empty array naturally returns null on this member row. | TESTED |
| GRC-025 | firstLine null-array early return (`:112–114`) | Null input returns null. | TESTED |
| GRC-026 | firstLine replacement predicate (`:116–120`) | Replace when result is unset or current line number is strictly smaller; ties keep the first. | TESTED |
| GRC-027 | `LineVisibleRanges.lastLine` (`:127–138`) | Return the largest line number independent of input order; an empty array naturally returns null on this member row. | TESTED |
| GRC-028 | lastLine null-array early return (`:128–130`) | Null input returns null. | TESTED |
| GRC-029 | lastLine replacement predicate (`:132–136`) | Replace when unset or strictly larger; ties keep the first. | TESTED |
| GRC-030 | `LineVisibleRanges.outsideRenderedLine` (`:140–148`) | Carry whether measurement extends outside rendered content. | TESTED |
| GRC-031 | `LineVisibleRanges.lineNumber` (`:140–148`) | Carry the one-based view line. | PORTED |
| GRC-032 | `LineVisibleRanges.ranges` (`:140–148`) | Carry ordered rounded horizontal ranges. | PORTED |
| GRC-033 | `continuesOnNextLine` (`:144–148`) | Carry whether the requested range continues beyond this line. | TESTED |
| GRC-034 | `LineVisibleRanges` constructor (`:140–148`) | Assign all four immutable fields without transformation. | PORTED |
| GRC-035 | `HorizontalRange` brand (`:151–152`) | TypeScript nominal brand only. | N-A (MoonBit nominal struct type) |
| GRC-036 | `HorizontalRange.left` (`:154,166–168`) | Field owns exact JavaScript `Math.round(left)` semantics. | TESTED |
| GRC-037 | `HorizontalRange.width` (`:155,166–168`) | Field owns independent exact JavaScript `Math.round(width)` semantics. | TESTED |
| GRC-038 | `HorizontalRange.from` (`:157–164`) | Convert every float range in input order; this member owns exact output length, allocation, indexed loop, and per-index construction. | TESTED |
| GRC-039 | `HorizontalRange` constructor (`:166–169`) | Construct in field order; left and width fields own their independent rounding arithmetic. | TESTED |
| GRC-040 | `HorizontalRange.toString` (`:171–173`) | Exact format `[left,width]`. | TESTED |
| GRC-041 | `FloatHorizontalRange` brand (`:176–177`) | TypeScript nominal brand only. | N-A (MoonBit nominal struct type) |
| GRC-042 | `FloatHorizontalRange.left` (`:179,182–184`) | Preserve fractional left unchanged. | PORTED |
| GRC-043 | `FloatHorizontalRange.width` (`:180,182–184`) | Preserve fractional width unchanged. | PORTED |
| GRC-044 | `FloatHorizontalRange` constructor (`:182–185`) | Assign both values without rounding. | PORTED |
| GRC-045 | `FloatHorizontalRange.toString` (`:187–189`) | Exact format `[left,width]` with source number formatting. | TESTED |
| GRC-046 | `FloatHorizontalRange.compare` (`:191–193`) | Comparator is exact `a.left - b.left`. | TESTED |
| GRC-047 | `HorizontalPosition.outsideRenderedLine` (`:196–205`) | Carries the source outside-rendered-line result from the measured producer. | TESTED |
| GRC-048 | `HorizontalPosition.left` (`:201,207`) | Rounded caret x; field owns the exact dependency `Math.round(originalLeft)`. | TESTED |
| GRC-049 | `HorizontalPosition.originalLeft` (`:202,206`) | Preserve the unrounded measurement. | TESTED |
| GRC-050 | `HorizontalPosition` constructor (`:204–208`) | Store outside flag and original first, then initialize rounded left from `originalLeft`; field row owns the arithmetic. | TESTED |
| GRC-051 | `VisibleRanges.outsideRenderedLine` (`:211–216`) | Carry aggregate outside-rendered state. | PORTED |
| GRC-052 | `VisibleRanges.ranges` (`:211–216`) | Carry float ranges without rounding. | PORTED |
| GRC-053 | `VisibleRanges` constructor (`:212–216`) | Assign both immutable fields without transformation. | PORTED |
| GRC-054 | DOM+GPU sort comparator callback (`:99`) | Source-owned callback returns exact `a.lineNumber - b.lineNumber`; no secondary key. | DEFERRED (GPU ViewLines excluded by Phase 0) |
GRC denominator: **54** rows.

#### Mechanical denominator and final disposition

```text
GCW 122 = 94 TESTED + 20 PORTED + 4 DEFERRED + 4 N-A
GRC  54 = 32 TESTED + 12 PORTED + 6 DEFERRED + 4 N-A
Total 176 = 126 TESTED + 32 PORTED + 10 DEFERRED + 8 N-A
```

N-A is limited to pinned-source-unreachable early returns and TypeScript nominal brand fields. Missing fixed/allowOverflow and GPU ViewLines features remain applicable deferred parity work.

#### Normalization record

The rejected 225-row draft was normalized before product work:

- Removed draft GCW IDs `005,010,044,046,054,056,057,061,063,065,067,068,071,077,080,082,083,084,085,088,089,091,094,099,100,102,104,105,108,113,114,115,117,125,126,130,136,140,153,158,159`.
- Plain allocation, field-literal duplication, validation/query sequencing, intermediate arithmetic, loop bookkeeping, and final returns were absorbed by their owning member/field rows.
- Merged the two arms of each single branch: draft `104→103`, `113→112`, `125→124`, `136→134`, and `140→139`.
- Draft local helpers `158/159` were absorbed into `_setPosition` and `_getAnchorsCoordinates`: they are not source-owned callbacks. Their actual branches remain rows.
- Added missing declared-member rows for `_reduceAnchorCoordinates` and `Widget.render`, yielding `159 - 41 + 2 = 120`.
- Removed draft GRC IDs `011,019,021,024,028,031,035,046,047,049,050,062`; constructor/query/loop/rounding/final-return facts were absorbed by owning members/fields, yielding `66 - 12 = 54`.
- Reclassified draft fixed/allowOverflow IDs `036,045,047,090` and GPU IDs `016,022,023,027,066` from N-A to DEFERRED. Source-unreachable and nominal-brand N-A rows remain.
- Gate B correction narrowed GCW-033 to the owner widget flag/default and left the editor conjunction solely to GCW-042; it also restored the omitted owner-window `scrollX ?? 0` and `scrollY ?? 0` atoms in source order. GCW is therefore `120 + 2 = 122`.
- Gate B correction narrowed GRC-017 to the GPU-bearing method remainder and changed its proposal from TESTED to DEFERRED. The GRC denominator remains 54.

#### Behavior-variable matrix

| Axis | Required cases / ordering | Lowest useful evidence |
|---|---|---|
| anchor input | primary null/invalid/clamped/visible/hidden; secondary null, same line, different line; affinity null and each supported value | converter white-box plus browser |
| measured anchor x | column 1 and later columns; tab stops; fullwidth; proportional font; combining text; injected text and generated content; rendered vs unrendered line | DOM Range/browser, <=1 CSS px |
| `LeftOfInjectedText` | column 1 forces zero only for that affinity; other columns/affinities use measured left | query/anchor white-box + browser |
| per-line vertical facts | line-specific vertical offset and line height, scrollTop zero/nonzero, bigNumbersDelta zero/nonzero | layout/context white-box + browser |
| secondary reduction | absent; left/equal/right of primary; widget narrower/equal/wider than separation; fullwidth clamp boundaries | pure geometry white-box |
| size cache | both `-1`; width-only invalid; height-only invalid; both valid; setPosition reset; fractional DOM rect; preferred dimensions | widget read-phase white-box + browser |
| owner callbacks | beforeRender absent/value/null/throws; afterRender absent/hidden/ABOVE/BELOW/EXACT/throws; correct `this` and argument order | callback white-box/browser |
| preference traversal | null, empty, each single preference; mixed orders; above/below both fit, one fit, neither fit; first-pass perfect fit then pass-two first-option fallback | pure placement white-box |
| viewport clamp | left inside, right overflow, left underflow, widget wider than viewport, equality at both edges; scrollLeft zero/nonzero | pure placement white-box |
| page clamp | editor near each page edge, scrolled page, widget wider than editor, 15px exact side boundaries, 22px exact top/bottom boundaries; assert both returned relative/absolute left coordinates and identical right/left clamp deltas | pure geometry white-box + fixed-size Chromium fixture |
| owner document/window | widget DOM and view root owned by the global document vs a distinct iframe/detached document; owner/global `scrollX`/`scrollY` deliberately differ; `defaultView` present/absent exercises exact zero fallbacks; max width covers `innerWidth` truthy/zero → `documentElement.offsetWidth` → `body.offsetWidth`; owner `activeElement` inside/outside the widget | deterministic JS white-box + iframe browser |
| overflow modes | widget overflow false/true; source editor allowOverflow true/false; fixedOverflowWidgets false/true | false/true widget browser; unsupported editor/fixed axes stay explicit DEFERRED |
| visibility/focus | initially hidden; visible→null; visible→offViewport focused/unfocused; already hidden; re-entry to visible | browser focus/attribute/style assertions |
| display ownership | useDisplayNone false/true × positionable/unpositionable × dirty scheduling | widget integration test |
| range source | DOM null/non-null; GPU absent; documented GPU combinations null/non-null; DOM wins position query | query white-box; GPU rows DEFERRED |
| line-range aggregation | null, empty, singleton, unsorted, duplicate line numbers; first/last strict tie behavior | carrier white-box |
| numeric carriers | integer/fractional/half/negative left and width; conversion preserves array order/length; exact string forms and comparator | carrier white-box |
| render order | outer key order; onBeforeRender → prepareRender → render; hidden callback before return; visible coordinate writes before callback | instrumented white-box/browser |

#### Final local mapping and reviewed seams

1. ContentWidgets projects validated model anchors with every affinity value,
   then reads per-line vertical facts and measured ViewLines caret geometry.
2. Nullable preferences, independently rounded size caches, source-ordered
   `onBeforeRender`/prepare/render phases, safe callbacks, and focused
   off-viewport parking are all branch-tested.
3. Each outer phase snapshots widget ids before live map lookup, matching
   `Object.keys`; reentrant current/future removal behavior is tested.
4. Owner-document width, scroll, page clamps, detached zero fallbacks, and iOS
   `visualViewport` are covered. A real scrolled iframe proves normal and
   overflowing widgets plus the exact 15px/22px boundaries.
5. `has_before_render`/`has_after_render` are MoonBit's explicit optional-method
   capabilities; two safe helpers preserve exception and argument behavior.
6. Fingerprints are stamped by `View::new` to avoid a package cycle. Raw
   Rabbita style writes preserve source order/values but do not claim
   `FastDomNode` setter-level caching.
7. RenderingContext uses cycle-free tuples/capabilities, immutable MoonBit
   carriers, and a DOM-only query facade. GPU fallback/concat/sort remains
   DEFERRED; editor `allowOverflow`, fixed overflow, and the concrete hover
   affinity producer remain the explicit product seams above.

#### Historical review stop gate

- [x] 122 GCW + 54 GRC active IDs are contiguous and unique.
- [x] All 176 final terminals sum to 176 with zero TODO/PASS.
- [x] Ownership exclusions and current local gaps are preserved in the owning plan.
- [x] Independent Gate B approves the corrected denominator and proposed seams.

The historical approval preceded all product and test edits.

### Group C — ViewLayout, renderer, and font measurement


#### Cross-plan overlap and ownership boundary

- `viewLayout.ts` line/zone mutation, viewport queries, smooth scrolling, and
  scroll-position APIs are already owned by lifecycle/cursor/ViewZone work or
  remain outside this geometry slice. Group C counts only the complete
  `EditorScrollDimensions`, `EditorScrollable` dimension/content-size channel,
  and `ViewLayout` max-width/content-width/content-height/horizontal-scrollbar
  clusters. Calls into `LinesLayout.getLinesTotalHeight()` and
  `getWhitespaceMinWidth()` are counted here as geometry inputs; the
  implementation of line/whitespace ordering is ViewZones-owned.
- `viewLineRenderer.ts` tokenization, decoration normalization, RTL splitting,
  control-character semantics, overflow labeling, and general HTML escaping
  were ported/reviewed elsewhere. Group C counts the complete input facts and
  downstream arithmetic that consume monospace, halfwidth-arrow, space,
  middot, word-separator-middot, tab, and fullwidth facts. It does not recount
  unrelated renderer branches.
- `fontInfo.ts` option registrations and `EditorConfiguration` delivery were
  counted by render invalidation. Group C counts the canonical font identity,
  normalization, measured facts, and equality needed by geometry. The
  declaration-only validation interface is excluded.
- `fontMeasurements.ts` measurement-to-`FontInfo` mapping is fully counted.
  Cache, persistence, target-window, timer, and singleton/platform siblings are
  not silently dropped: each excluded or reduced member has its own `GFM` row.
- `FontInfo.typicalFullwidthCharacterWidth` is measured and carried, but pinned
  `viewLineRenderer.ts` does not accept it as a `RenderLineInput` field; fullwidth
  renderer bookkeeping uses a fixed two visible columns. It must not be
  invented as a new renderer input. The measured fullwidth fact is consumed by
  wrapping/layout code outside this renderer slice.

#### Source evidence

| Source file | Lines | SHA-256 | Scoped unit |
|---|---:|---|---|
| `vscode/src/vs/editor/common/viewLayout/viewLayout.ts` | 490 | `628be8f63ced174d6325773b20cb8bf263ebc073fc19632bd7657300d60c70a3` | scroll dimensions, content-size event, max/content width, content height, horizontal scrollbar |
| `vscode/src/vs/editor/common/viewLayout/viewLineRenderer.ts` | 1213 | `afafe97c4eb46bd4d22a3e0605b5d35789c124106972a74bf0c0100751ea451c` | font-related input fields and consumed arithmetic |
| `vscode/src/vs/editor/common/config/fontInfo.ts` | 244 | `39b5fc2435351945fc2b56bc16207481d5371b9cecd050a52a73a73d0fa50291` | canonical bare/measured font facts |
| `vscode/src/vs/editor/browser/config/fontMeasurements.ts` | 285 | `f4d42aa34b936e49bd1c1dae555277c5314239a698881dde88001f83edfad75d` | complete request/measurement/FontInfo mapping plus explicit cache/platform siblings |

All four hashes were recomputed from the checked-out pinned submodule before
inventorying. The files were then read in full, not searched selectively.

#### Closed source boundaries

##### `viewLayout.ts`

Included: `EditorScrollDimensions` (`:19-71`); the dimensional and content-size
members of `EditorScrollable` (`:73-133`); `ViewLayout` dimensional fields and
constructor wiring (`:156-192`), relevant configuration integration
(`:199-236`), `_getHorizontalScrollbarHeight`, `_getContentHeight`,
`_updateHeight` (`:249-287`), `_computeContentWidth`, `setMaxLineWidth`,
`setOverlayWidgetsMinWidth`, `_updateContentWidth` (`:313-357`), and four
content/scroll size getters (`:441-456`).

Excluded scroll/cursor-owned siblings: `EditorScrollable.onDidScroll` (`:78,91`), `ViewLayout.onDidScroll` (`:164,188`), `_configureSmoothScrollDuration` (`:203-205`), the smooth-scrolling branch (`:233-235`), remaining smooth/position delegates, viewport/state/whitespace queries, and vertical-offset/scroll-position APIs. LinesLayout mutation/query implementations remain ViewZones-owned; this group counts only the field and total-height/whitespace-minimum consumption inside included ViewLayout methods.

##### `viewLineRenderer.ts`

Included: the five font-sensitive `IRenderLineInputOptions` facts; matching
`RenderLineInput` state, constructor derivation, and equality; matching
`ResolvedRenderLineInput` projection; font-sensitive branches in
`_applyRenderWhitespace` and `_renderLine`; tab/fullwidth visible-column and
horizontal-offset arithmetic; glyph/CSS-width constants and DOM writes.

Excluded siblings: general whitespace mode selection, token/decor/RTL/control processing, overflow/output wrappers, and `CharacterMapping` search/packing algorithms. The scoped mapping write of font-derived horizontal columns remains included. Group A `ViewLineOptions` and `ViewLine.renderLine` atoms are not recounted here.

##### `fontInfo.ts`

Included: font constants, `BareFontInfo` construction/identity/style-family
normalization, every inherited field used by measurement/rendering,
`FontInfo` measured fields/constructor/equality, and platform defaults. Only
`IValidatedEditorOptions` (`:24-26`) and nominal brand fields are non-runtime
type siblings; the brands still receive explicit N-A rows.

##### `fontMeasurements.ts`

Included in full. Measurement/output rows are required parity. Cache,
persistence, per-window/platform, timer, disposal, and singleton rows are
explicitly inventoried so Gate B can choose `PORTED`, `DEFERRED`, or `N-A`
without shrinking the denominator.

#### Final four-column inventory and parity ledger

The merged behavior/local-target column records the source transition and
reviewed local seam; the last column is the final terminal status.

##### GVLay — `viewLayout.ts`

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GVLay-001 | `EditorScrollDimensions.width` (`:21,30,35,40-42,54`) | `EditorScrollDimensions::new` applies portable ToInt32 modulo/wrap before clamping and retaining viewport width; ±2^31/2^32 edges are tested. | TESTED |
| GVLay-002 | `contentWidth` (`:22,31,36,43-45,55`) | Applies portable ToInt32 modulo/wrap before clamping and retaining content width independently; ±2^31/2^32 edges are tested. | TESTED |
| GVLay-003 | `scrollWidth` (`:23,56`) | `max(width, contentWidth)`. Local: `scroll_width`; local matches. | TESTED |
| GVLay-004 | `height` (`:25,32,37,47-49,58`) | Applies portable ToInt32 modulo/wrap before clamping and retaining viewport height; ±2^31/2^32 edges are tested. | TESTED |
| GVLay-005 | `contentHeight` (`:26,33,38,50-52,59`) | Applies portable ToInt32 modulo/wrap before clamping and retaining content height independently; ±2^31/2^32 edges are tested. | TESTED |
| GVLay-006 | `scrollHeight` (`:27,60`) | `max(height, contentHeight)`. Local: `scroll_height`; local matches. | TESTED |
| GVLay-007 | `EditorScrollDimensions` constructor (`:29-61`) | Normalize all four primary dimensions, then derive two scroll dimensions. Local: `EditorScrollDimensions::new`. | TESTED |
| GVLay-008 | width negative branch (`:40-42`) | Strict `< 0` becomes `0`; zero stays zero. Local `max(0)` equivalence and the boundary are tested. | TESTED |
| GVLay-009 | content-width negative branch (`:43-45`) | Strict `< 0` becomes `0`; zero stays zero. Local `max(0)` equivalence and the boundary are tested. | TESTED |
| GVLay-010 | height negative branch (`:47-49`) | Strict `< 0` becomes `0`; zero stays zero. Local `max(0)` equivalence and the boundary are tested. | TESTED |
| GVLay-011 | content-height negative branch (`:50-52`) | Strict `< 0` becomes `0`; zero stays zero. Local `max(0)` equivalence and the boundary are tested. | TESTED |
| GVLay-012 | `EditorScrollDimensions.equals` (`:63-70`) | Compare width/contentWidth/height/contentHeight; local derived fields are observationally redundant and equivalence is tested. | TESTED |
| GVLay-013 | `EditorScrollable._scrollable` (`:75,86-91,118-123`) | Own underlying integer Scrollable and receive its scroll event. Local: `EditorScrollable.scrollable`. | PORTED |
| GVLay-014 | `_dimensions` (`:76,85,106-116`) | Retain normalized editor dimensions, initially all zero. Local: `editor_dimensions`; local matches. | TESTED |
| GVLay-015 | `_onDidContentSizeChange` (`:80,127-131`) | Private emitter fires only for content dimensions. Local: `content_size_emitter`; local matches. | PORTED |
| GVLay-016 | `onDidContentSizeChange` (`:81`) | Public event alias. Local: `EditorScrollable::on_did_content_size_change`. | PORTED |
| GVLay-017 | dimensional constructor slice (`:83-92`) | Initialize zero dimensions; underlying Scrollable forces integer values and uses supplied scheduler. Local: `EditorScrollable::new(force_integer_values=true, ...)`. | TESTED |
| GVLay-018 | `getScrollDimensions` (`:106-108`) | Return retained editor dimensions. Local: `editor_dimensions()`. | TESTED |
| GVLay-019 | `EditorScrollable.setScrollDimensions` (`:110-133`) | Atomically retain old dimensions, assign the new identity, and pass width/scrollWidth/height/scrollHeight to the underlying Scrollable with `useRawScrollPositions=true`; content-event branching remains owned by GVLay-025. Local: `set_editor_dimensions` preserves the same order and four-axis write. | TESTED |
| GVLay-020 | equal-dimensions early return (`:111-113`) | No underlying write and no content event when identity is unchanged; the local `None` result and no-write path are tested. | TESTED |
| GVLay-021 | content-size change branch and payload (`:125-131`) | Neither, viewport-only, width-only, height-only, and both paths are tested together with exact old/new payload order. | TESTED |
| GVLay-022 | `ViewLayout._configuration` (`:158,170`) | Live option source for every geometry calculation. Local: Local `ViewLayout` has no configuration reader; options are reduced to external setters. | DEFERRED (local ViewLayout has no live IEditorConfiguration owner) |
| GVLay-023 | `_linesLayout` (`:159,175,266,331`) | Local `lines` owns total line height and now supplies the whitespace minimum-width handoff used by the applicable content-width formula. | PORTED |
| GVLay-024 | `_maxLineWidth` (`:160,176,315,336-338`) | Local ViewLayout retains measured widest line, initialized `0`. | TESTED |
| GVLay-025 | `_overlayWidgetsMinWidth` (`:161,177,332,341-343`) | Retain overlay minimum width, initialized `0`. Local: Missing local field/setter. | DEFERRED (overlay-widget minimum-width state and caller are absent) |
| GVLay-026 | `_scrollable` (`:163,179-189`) | Own normalized editor dimensions and content-size event. Local: Local `scrollable`; matches role. | PORTED |
| GVLay-027 | `onDidContentSizeChange` alias (`:165,189`) | Forward EditorScrollable content-size event. Local: `ViewLayout::on_did_content_size_change`. | PORTED |
| GVLay-028 | `ViewLayout` constructor geometry cluster (`:167-192`) | Read layoutInfo and padding, construct LinesLayout from lineCount/lineHeight/top/bottom padding, initialize max-line and overlay minima to zero, seed EditorScrollDimensions as `(contentWidth,0,height,0)`, wire events, then `_updateHeight`. Local: constructor defers viewport size to a later setter and hard-codes zero padding. | DEFERRED (editor padding and initial layout-info constructor seams are absent) |
| GVLay-029 | `onHeightMaybeChanged` (`:199-201`) | Delegate exactly once to `_updateHeight`. Local: `on_height_maybe_changed`. | TESTED |
| GVLay-030 | `onConfigurationChanged` dimension orchestration (`:209-236`) | Update line/padding inputs, then choose layoutInfo recompute or height-only recompute. Local: Local uses separate setters; no typed single event route. | DEFERRED (local configuration delivery is split across setter APIs) |
| GVLay-031 | line-height branch (`:211-213`) | Update LinesLayout default height before dimension recomputation. Local: `set_line_height`; local adds equality early return. | TESTED |
| GVLay-032 | padding branch (`:214-217`) | Update top/bottom padding before recomputation. Local: Missing: local exposes no padding option. | DEFERRED (editor padding option seam is absent) |
| GVLay-033 | layoutInfo branch (`:218-229`) | Uses new viewport width/height, reuses retained content width unchanged, and recomputes content height against the new box. | TESTED |
| GVLay-034 | no-layoutInfo branch (`:230-232`) | Typed non-layout setters call `update_height`; only the generic configuration-event route remains deferred in GVLay-030. | TESTED |
| GVLay-035 | `_getHorizontalScrollbarHeight` (`:249-261`) | Implements fixed Auto behavior: no overflow returns zero, otherwise the configured horizontal scrollbar height; Hidden remains GVLay-036. | TESTED |
| GVLay-036 | horizontal hidden branch (`:252-255`) | Explicit `Hidden` returns `0`, regardless of overflow. Local: Missing option and branch. | DEFERRED (horizontal-scrollbar visibility option axis is absent) |
| GVLay-037 | no-overflow branch (`:256-259`) | `width >= scrollWidth` returns `0`; local equality remains non-visible. | TESTED |
| GVLay-038 | `_getContentHeight` (`:263-274`) | Local initializes from total line height and adds the fixed product's selected horizontal-scrollbar extension. | TESTED |
| GVLay-039 | scroll-beyond-last-line branch (`:267-269`) | When enabled, add `max(0, height - lineHeight - padding.bottom)`. Local: the option and nonnegative remainder formula are absent. | DEFERRED (scrollBeyondLastLine option and bottom-extent formula are absent) |
| GVLay-040 | horizontal-scrollbar content-height branch (`:269-271`) | When scrollBeyondLastLine is false, add scrollbar height iff `ignoreHorizontalScrollbarInContentHeight` is false; the true outcome adds nothing. Local: this option/branch is absent. | DEFERRED (ignoreHorizontalScrollbarInContentHeight option seam is absent) |
| GVLay-041 | `_updateHeight` (`:276-287`) | Preserves width/contentWidth/height and replaces contentHeight with total lines plus the applicable horizontal-scrollbar extension. | TESTED |
| GVLay-042 | `_computeContentWidth` (`:313-334`) | Computes horizontal content extent from measured max plus options and minima. | TESTED |
| GVLay-043 | viewport-wrapping branch (`:319-329`) | Wrapping returns retained `max_line_width`; the minimap-only predicate and adjustment are N-A in GVLay-044/045. | TESTED |
| GVLay-044 | wrapped overflow threshold (`:321`) | Strict `maxLineWidth > contentWidth + typicalHalfwidthCharacterWidth`; it only guards the right-minimap adjustment in GVLay-045. The local no-minimap product has no observable owner for this predicate. | N-A (no minimap ViewPart or minimap-side axis) |
| GVLay-045 | right-minimap adjustment (`:323-326`) | This adjustment applies only to the absent minimap ViewPart and minimap-side axis. | N-A (no minimap ViewPart or minimap-side axis) |
| GVLay-046 | no-wrap branch/outcome (`:329-333`) | The whitespace-minimum handoff exists; scrollBeyondLastColumn, overlay width, and a nonzero ViewZone minimum-width producer remain future seams. | DEFERRED (LinesLayout whitespace-min-width handoff depends on ViewZones) |
| GVLay-047 | `setMaxLineWidth` (`:336-339`) | Local `set_max_line_width` assigns without clamping and immediately recomputes width and height. | TESTED |
| GVLay-048 | `setOverlayWidgetsMinWidth` (`:341-344`) | Assign without clamping, then immediately `_updateContentWidth`. Local: Missing API/field. | DEFERRED (overlay-widget minimum-width state and caller are absent) |
| GVLay-049 | `_updateContentWidth` (`:346-357`) | Preserves viewport width/height/contentHeight, replaces contentWidth with `_computeContentWidth`, then always updates height because horizontal scrollbar visibility can change bottom extent. | TESTED |
| GVLay-050 | `getContentWidth` (`:441-444`) | Return retained content width, not clamped scroll width. Local: Local matches getter. | TESTED |
| GVLay-051 | `getScrollWidth` (`:445-448`) | Return `max(viewport, content)` derived scroll width. Local: Local matches getter. | TESTED |
| GVLay-052 | `getContentHeight` (`:449-452`) | Reads retained `editor_dimensions.content_height`, including the fixed horizontal-scrollbar bottom extension. | TESTED |
| GVLay-053 | `getScrollHeight` (`:453-456`) | Returns `max(viewport, content)` from the complete retained height computation. | TESTED |
##### GVR — `viewLineRenderer.ts`

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GVR-001 | `IRenderLineInputOptions.useMonospaceOptimizations` (`:26`) | Caller supplies whether width-aggregation optimizations are safe. Local: `RenderLineInput.use_monospace_optimizations`. | PORTED |
| GVR-002 | `canUseHalfwidthRightwardsArrow` (`:27`) | Caller supplies measured arrow compatibility. Local: Local field matches. | PORTED |
| GVR-003 | `spaceWidth` (`:37`) | Measured ordinary-space width in CSS px. Local: Local field matches. | PORTED |
| GVR-004 | `middotWidth` (`:38`) | Measured U+00B7 width. Local: Local field matches. | PORTED |
| GVR-005 | `wsmiddotWidth` (`:39`) | Measured U+2E31 width. Local: Local field matches. | PORTED |
| GVR-006 | `RenderLineInput.useMonospaceOptimizations` (`:52,88,111`) | Retain the caller fact. Local: Local matches Equality compares this declared field. Local behavior remains as described. | PORTED |
| GVR-007 | `canUseHalfwidthRightwardsArrow` (`:53,89,112`) | Retain arrow compatibility. Local: Local matches Equality compares this declared field. Local behavior remains as described. | PORTED |
| GVR-008 | `spaceWidth` (`:63,99,122`) | Retain measured space width. Local: Local matches Equality compares this declared field. Local behavior remains as described. | PORTED |
| GVR-009 | `renderSpaceWidth` (`:64,142-149`) | Retains the normalized width of the whitespace glyph closest to a space; equality consumes this field rather than both discarded raw candidates. | PORTED |
| GVR-010 | `renderSpaceCharCode` (`:65,142-149`) | Retains the normalized chosen middle-dot code point and uses it as part of render identity. | PORTED |
| GVR-011 | font-sensitive `RenderLineInput` constructor slice (`:87-151`) | `from_view_line` computes and retains normalized `render_space_width` and `render_space_char_code` once; raw candidates are discarded. | TESTED |
| GVR-012 | render-space glyph-selection branch (`:142-150`) | Use U+2E31 only when its width difference is strictly smaller; the equal/greater else outcome uses U+00B7. Local: strict-less and tie behavior match. | TESTED |
| GVR-013 | magic glyph constant U+2E31 (`:146`) | Exact WORD SEPARATOR MIDDLE DOT code point `0x2E31` is retained and tested distinctly from U+00B7. | TESTED |
| GVR-014 | magic glyph constant U+00B7 (`:149`) | Independently selected MIDDLE DOT code point `0xB7`, including the tie outcome. Local: exact constant is retained. | TESTED |
| GVR-015 | `RenderLineInput.equals` (`:175-200`) | Derived equality compares normalized render identity; different raw candidates with identical normalized fields produce zero retained second write. | TESTED |
| GVR-016 | `ResolvedRenderLineInput.fontIsMonospace` (`:444`) | Resolved fact receives `useMonospaceOptimizations`. Local: Local `font_is_monospace`; matches source naming reduction. | PORTED |
| GVR-017 | resolved arrow fact (`:445`) | Forward arrow compatibility into final writer. Local: Local matches. | PORTED |
| GVR-018 | resolved space width (`:455`) | Forward CSS-pixel width into whitespace style arithmetic. Local: Local matches. | PORTED |
| GVR-019 | resolved render-space char (`:456`) | Forward chosen glyph. Local: Local matches. | PORTED |
| GVR-020 | declared `ResolvedRenderLineInput` constructor (`:442-462`) | Own the straight projection assignments for all resolved fields. Local: the MoonBit private struct literal provides the same projection boundary. | PORTED |
| GVR-021 | `resolveRenderLineInput` font projection (`:517-532`) | Projects useMono, arrow, spaceWidth, and the retained chosen glyph in fixed order without re-deriving it. | TESTED |
| GVR-022 | `_applyRenderWhitespace` font-sensitive cluster (`:752-913`) | Own the local monospace copy, initial `startVisibleColumn % tabSize`, both modulo resets, glyph-width splitting, proportional indent split and tab/fullwidth column transitions. Local method mirrors the control flow. | TESTED |
| GVR-023 | per-whitespace-part gate (`:762`) | Compares retained `render_space_width != space_width` directly. | TESTED |
| GVR-024 | proportional-indent split (`:843-844`) | Split when leaving whitespace or when `!useMono && tmpIndent >= tabSize`. Local: Local matches both conditions. | TESTED |
| GVR-025 | tab indent transition (`:863-864`) | Tab sets temporary indent to exactly `tabSize`. Local: Local matches. | TESTED |
| GVR-026 | reused fullwidth visible-column constant (`:865-866,1140-1143`) | Both whitespace splitting and final rendering assign exactly two visible columns to a fullwidth code unit. Local uses the same predicate and constant. | TESTED |
| GVR-027 | ordinary indent transition (`:867-868`) | Other code unit adds exactly `1`. Local: Local matches. | TESTED |
| GVR-028 | `_renderLine` font-sensitive cluster (`:979-1198`) | Own extraction of monospace, arrow, space-width and render-glyph facts before the part loop, then emit scoped HTML/CSS and mapping writes. Local `render_line` mirrors the broad structure. | TESTED |
| GVR-029 | `partRendersWhitespaceWithWidth` (`:1014-1016`) | Whitespace + non-monospace + (`mtkw` or no foreign elements). Local: Local condition matches. | TESTED |
| GVR-030 | width-bearing class (`:1024`) | Use class `mtkz` when explicit width is written. Local: Local matches DOM class. | TESTED |
| GVR-031 | whitespace-part tab width (`:1034-1041`) | Tab width is `tabSize - visibleColumn % tabSize`; non-tab width is `1`; faux indent does not advance visible column. Local: Local probe loop matches. | TESTED |
| GVR-032 | explicit CSS width DOM write (`:1044-1048`) | Write `style="width:<spaceWidth * partWidth>px"`. Local: Local writes same property/product. | TESTED |
| GVR-033 | rendered-whitespace tab width (`:1059-1062`) | Produced characters and horizontal width equal remaining tab stop. Local: Local matches. | TESTED |
| GVR-034 | arrow choice branch (`:1063-1067`) | Use regular arrow when halfwidth is unsafe or tab width > 1; only one-column safe tabs use halfwidth arrow. Local: Local matches. | TESTED |
| GVR-035 | regular arrow constant (`:1064`) | U+2192. Local: Local `ch_rightwards_arrow`. | TESTED |
| GVR-036 | halfwidth arrow constant (`:1066`) | U+FFEB. Local: Local `ch_halfwidth_rightwards_arrow`. | TESTED |
| GVR-037 | tab fill (`:1068-1070`) | Append NBSP for positions `2..charWidth`; a one-column tab adds none. Local: Local loop matches. | TESTED |
| GVR-038 | rendered-space geometry (`:1072-1078`) | One source space maps to two DOM chars, width one column, chosen dot plus U+200C. Local: Local matches constants and counts. | TESTED |
| GVR-039 | horizontal-offset accumulation (`:1080-1084`) | Add logical char width; advance visible column only after faux indent. Local: Local matches. | TESTED |
| GVR-040 | ordinary tab expansion (`:1099-1105`) | Non-whitespace-render path emits `tabSize - visibleColumn % tabSize` NBSPs. Local: Local matches. | TESTED |
| GVR-041 | mapping stores column units (`:1052,1092,1161-1165,1177,1187`) | `CharacterMapping` horizontal offsets are visible columns, not measured CSS pixels; widget geometry uses DOM Range instead of multiplying by one width. | TESTED |
##### GFI — `fontInfo.ts`

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GFI-001 | `GOLDEN_LINE_HEIGHT_RATIO` (`:14`) | macOS `1.5`, all other platforms `1.35`. Local: `golden_line_height_ratio`; local matches. | TESTED |
| GFI-002 | `MINIMUM_LINE_HEIGHT` (`:19`) | Constant `8`. Local: `minimum_line_height`; local matches. | PORTED |
| GFI-003 | `BareFontInfo._bareFontInfoBrand` (`:29`) | Nominal type-only brand, no runtime behavior. Local: N-A candidate: MoonBit concrete type needs no brand. | N-A (MoonBit concrete types need no nominal BareFontInfo brand) |
| GFI-004 | `BareFontInfo._create` (`:34-72`) | `BareFontInfo::create` implements source rounding and decimal-prefix parsing; only editor zoom is fixed to 1 and owned by GFI-008. | TESTED |
| GFI-005 | zero line-height branch (`:35-36`) | `lineHeight = goldenRatio * fontSize`. Local: Local matches. | TESTED |
| GFI-006 | em line-height branch (`:37-40`) | Nonzero value `< 8` multiplies font size. Local: Local matches. | TESTED |
| GFI-007 | line-height minimum (`:44-46`) | Clamp rounded value below `8` to `8`. Local: Local matches. | TESTED |
| GFI-008 | editor zoom multiplier branch (`:48-50`) | Compute `1 + (ignoreEditorZoom ? 0 : zoomLevel * 0.1)` and multiply both fontSize and lineHeight by it. Local: readonly Viewer has no editor zoom axis. | N-A (readonly Viewer has no editor zoom axis) |
| GFI-009 | variation translate gate (`:52`) | Only `fontVariationSettings === 'translate'` enters translation. Local: Local matches. | TESTED |
| GFI-010 | normal/bold variation branch (`:53-55`) | Translate to `normal` variation without changing weight. Local: Local matches. | TESTED |
| GFI-011 | numeric-weight variation branch (`:56-59`) | Parses decimal weight, emits canonical `'wght' N`, and normalizes the CSS weight to `normal`; malformed/noncanonical boundaries are tested. | TESTED |
| GFI-012 | `BareFontInfo.pixelRatio` (`:74,87,96`) | Canonical measurement/cache input. Local: Local field matches. | PORTED |
| GFI-013 | `fontFamily` (`:75,88,97`) | Canonical family coerced through `String`. Local: Local typed String needs no coercion. | PORTED |
| GFI-014 | `fontWeight` (`:76,89,98`) | Canonical weight coerced through `String`. Local: Local typed String. | PORTED |
| GFI-015 | `fontSize` (`:77,90,99`) | Canonical CSS-pixel size. Local: Local field matches. | PORTED |
| GFI-016 | `fontFeatureSettings` (`:78,91,100`) | Controls DOM style and initial monospace eligibility. Local: Local matches. | PORTED |
| GFI-017 | `fontVariationSettings` (`:79,92,101`) | Controls DOM variation style. Local: Local matches. | PORTED |
| GFI-018 | `lineHeight` (`:80,93,102`) | Retained as integer via bitwise-OR zero. Local: Local Int field matches after construction. | PORTED |
| GFI-019 | `letterSpacing` (`:81,94,103`) | DOM measurement/render style input. Local: Local matches. | PORTED |
| GFI-020 | protected constructor (`:86-104`) | Assign eight canonical bare fields. Local: Flattened into local struct construction. | PORTED |
| GFI-021 | `getId` (`:109-111`) | Hyphen-join all eight bare axes in fixed order. Local: `BareFontInfo::get_id`; local matches. | TESTED |
| GFI-022 | `getMassagedFontFamily` (`:116-123`) | Obtain the platform fallback and quote the configured family; the following branch owns conditional fallback append. Local method has the same role. | TESTED |
| GFI-023 | fallback-family append branch (`:119-121`) | Appends `, <fallback>` only when the fallback is nonempty and differs from the configured family; both boundaries are tested. | TESTED |
| GFI-024 | declared `BareFontInfo._wrapInQuotes` (`:125-135`) | Own family quoting orchestration and the plain-family final return; two behavior branches remain separate below. Local: `wrap_in_quotes` mirrors the member. | TESTED |
| GFI-025 | `_wrapInQuotes` escaped branch (`:125-129`) | Family containing comma or quote is returned unchanged. Local: Local matches. | TESTED |
| GFI-026 | `_wrapInQuotes` plus/space branch (`:130-133`) | Wrap in double quotes. Local: Local matches. | TESTED |
| GFI-027 | `SERIALIZED_FONT_INFO_VERSION` (`:138-139`) | Constant `2`, bumped whenever fields change. Local: Persistence absent locally; explicit N-A candidate. | N-A (font-info persistence channel is absent) |
| GFI-028 | `FontInfo._editorStylingBrand` (`:142`) | Nominal type-only brand. Local: N-A candidate. | N-A (MoonBit concrete types need no nominal FontInfo brand) |
| GFI-029 | `version` (`:144`) | Every FontInfo reports serialization version `2`. Local: Local FontInfo omits version with persistence channel. | N-A (font-info persistence channel is absent) |
| GFI-030 | `isTrusted` (`:145,175,177`) | Distinguish live reliable measurements from restored/fallback readings. Local: `is_trusted`; local matches. | PORTED |
| GFI-031 | `isMonospace` (`:146,167,178`) | Measured optimization fact. Local: `is_monospace`; local matches. | PORTED |
| GFI-032 | `typicalHalfwidthCharacterWidth` (`:147,168,179`) | Measured typical halfwidth advance. Local: Local matches. | PORTED |
| GFI-033 | `typicalFullwidthCharacterWidth` (`:148,169,180`) | Measured typical fullwidth advance. Local: Local matches. | PORTED |
| GFI-034 | `canUseHalfwidthRightwardsArrow` (`:149,170,181`) | Measured glyph-safety fact. Local: Local matches. | PORTED |
| GFI-035 | `spaceWidth` (`:150,171,182`) | Measured U+0020 width. Local: Local matches. | PORTED |
| GFI-036 | `middotWidth` (`:151,172,183`) | Measured U+00B7 width. Local: Local matches. | PORTED |
| GFI-037 | `wsmiddotWidth` (`:152,173,184`) | Measured U+2E31 width. Local: Local matches. | PORTED |
| GFI-038 | `maxDigitWidth` (`:153,174,185`) | Maximum measured width of `0..9`. Local: Local matches. | PORTED |
| GFI-039 | `FontInfo` constructor (`:158-186`) | Call Bare constructor, assign trust and eight measured facts. Local: Local flat struct returned by measurement; all fields exist. | PORTED |
| GFI-040 | `FontInfo.equals` (`:191-208`) | Compare family, weight, size, feature, variation, line height, letter spacing, typical half/full widths, arrow capability, space/middot/wsmiddot and max digit; intentionally omit pixelRatio, isTrusted and isMonospace. Local equality matches the exact included/omitted axes. | TESTED |
| GFI-041 | `FONT_VARIATION_OFF` (`:213`) | Constant `normal`. Local: Local matches. | PORTED |
| GFI-042 | `FONT_VARIATION_TRANSLATE` (`:217`) | Constant `translate`. Local: Local matches. | PORTED |
| GFI-043 | `DEFAULT_WINDOWS_FONT_FAMILY` (`:222`) | Declared Consolas/Courier New/monospace Windows stack. Local: exact string is embedded in editor defaults. | PORTED |
| GFI-044 | `DEFAULT_MAC_FONT_FAMILY` (`:226`) | Declared Menlo/Monaco/Courier New/monospace macOS stack. Local: exact string is embedded in editor defaults. | PORTED |
| GFI-045 | `DEFAULT_LINUX_FONT_FAMILY` (`:230`) | Declared Droid Sans Mono/monospace Linux-other stack. Local: exact string is embedded in editor defaults. | PORTED |
| GFI-046 | declared `EDITOR_FONT_DEFAULTS` object (`:234-244`) | Own the five default properties and their platform selections; the following rows retain each property/branch fact. Local: `editor_font_defaults` is the corresponding object. | PORTED |
| GFI-047 | `EDITOR_FONT_DEFAULTS.fontFamily` (`:234-237`) | macOS / Windows / other platform selection. Local: Local matches platform branches. | TESTED |
| GFI-048 | default weight (`:238`) | `normal`. Local: Local matches. | PORTED |
| GFI-049 | default size (`:239-241`) | macOS `12`, other platforms `14`. Local: Local matches. | TESTED |
| GFI-050 | default line height (`:242`) | `0`, later normalized by `_create`. Local: Local matches. | PORTED |
| GFI-051 | default letter spacing (`:243`) | `0`. Local: Local matches. | PORTED |
##### GFM — `fontMeasurements.ts`

| ID | Source atom | Local implementation / evidence | Final status |
|---|---|---|---|
| GFM-001 | `ISerializedFontInfo.version` (`:18`) | Persist schema version. Local: Serialization absent; explicit N-A candidate. | N-A (font-info persistence channel is absent) |
| GFM-002 | serialized `pixelRatio` (`:19`) | Persist source-window ratio. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-003 | serialized `fontFamily` (`:20`) | Persist family. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-004 | serialized `fontWeight` (`:21`) | Persist weight. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-005 | serialized `fontSize` (`:22`) | Persist size. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-006 | serialized `fontFeatureSettings` (`:23`) | Persist features. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-007 | serialized `fontVariationSettings` (`:24`) | Persist variations. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-008 | serialized `lineHeight` (`:25`) | Persist line height. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-009 | serialized `letterSpacing` (`:26`) | Persist spacing. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-010 | serialized `isMonospace` (`:27`) | Persist measured fact. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-011 | serialized typical halfwidth (`:28`) | Persist measured width. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-012 | serialized typical fullwidth (`:29`) | Persist measured width. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-013 | serialized halfwidth-arrow capability (`:30`) | Persist measured fact. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-014 | serialized space width (`:31`) | Persist measured width. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-015 | serialized middot width (`:32`) | Persist measured width. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-016 | serialized word-separator-middot width (`:33`) | Persist measured width. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-017 | serialized max digit width (`:34`) | Persist measured width. Local: Serialization absent. | N-A (font-info persistence channel is absent) |
| GFM-018 | `FontMeasurementsImpl._cache` (`:39`) | Per-window cache keyed by `getWindowId`. Local: Local retains one global cache; the per-window owner remains deferred consistently with frozen CFG-016. | DEFERRED (frozen CFG-016 leaves the multi-window configuration/cache owner absent) |
| GFM-019 | `_evictUntrustedReadingsTimeout` (`:41,47-50,76-81`) | `-1` sentinel means no pending retry. Local: Local Bool pending flag; equivalent single-window state. | PORTED |
| GFM-020 | `_onDidChange` (`:43`) | Registered emitter lifetime. Local: Local emitter exists but FontMeasurementsImpl has no dispose. | PORTED |
| GFM-021 | `onDidChange` (`:44`) | Public event alias. Local: Local listener API matches. | PORTED |
| GFM-022 | `dispose` (`:46-52`) | Cancel pending timeout, reset sentinel, dispose registered resources. Local: Missing local disposal/cancellation handle. | N-A (process-lifetime singleton has no disposal owner) |
| GFM-023 | dispose timeout branch (`:47-50`) | Only clear/reset when sentinel is not `-1`. Local: Missing; local `set_timeout` result is discarded. | N-A (process-lifetime singleton has no disposal owner) |
| GFM-024 | `clearAllFontInfos` (`:57-60`) | Clear every window cache then fire change. Local: Local clears single cache and fires. | TESTED |
| GFM-025 | `_ensureCache` (`:62-70`) | Resolve `windowId`; return existing or create/store a new cache. Local: Local single-window reduction has no method/branch. | DEFERRED (frozen CFG-016 leaves the multi-window configuration/cache owner absent) |
| GFM-026 | missing-window cache branch (`:65-68`) | Allocate exactly once per window. Local: Missing; the multi-window allocation branch remains deferred consistently with frozen CFG-016. | DEFERRED (frozen CFG-016 leaves the multi-window configuration/cache owner absent) |
| GFM-027 | `_writeToCache` (`:72-83`) | Put measured identity, then maybe schedule one untrusted retry. Local: Local `write_to_cache`; matches single-window behavior. | TESTED |
| GFM-028 | untrusted/no-timer gate (`:76`) | Schedule iff `!isTrusted && timeout === -1`. Local: Local `!is_trusted && !pending`; matches. | TESTED |
| GFM-029 | untrusted-reading retry delay (`:81`) | Independently reused timing constant `5000ms`. Local: exact delay is passed to the global timer. | TESTED |
| GFM-030 | source-owned untrusted-reading timer callback (`:78-81`) | Resets the pending-timeout sentinel before eviction; fake-timer evidence covers the ordering. | TESTED |
| GFM-031 | `_evictUntrustedReadings` (`:85-98`) | Inspect one window cache, remove every untrusted value, conditionally fire. Local: Local matches over single cache. | TESTED |
| GFM-032 | untrusted removal branch (`:89-93`) | Trusted retained; untrusted removed and `somethingRemoved=true`. Local: Local matches. | TESTED |
| GFM-033 | eviction event gate (`:95-97`) | Fire only if at least one value was removed. Local: Local matches. | TESTED |
| GFM-034 | `serializeFontInfo` (`:103-107`) | Return trusted cached values only. Local: Missing persistence channel; explicit N-A candidate. | N-A (font-info persistence channel is absent) |
| GFM-035 | source-owned trusted-value filter callback (`:106`) | `item => item.isTrusted` admits only trusted values during serialization. Local: serialization is absent, so the callback has no local owner. | N-A (font-info persistence channel is absent) |
| GFM-036 | `restoreFontInfo` (`:112-123`) | Iterate saved records, skip mismatched versions, construct accepted FontInfo as untrusted and pass it as both cache key/value. Local: persistence restore channel is absent. | N-A (font-info persistence channel is absent) |
| GFM-037 | version-mismatch continue (`:116-119`) | Any version other than current is skipped. Local: Missing. | N-A (font-info persistence channel is absent) |
| GFM-038 | `readFontInfo` (`:128-158`) | Return cache hit; on miss measure, apply the counted suspicious fallback, mark fallback untrusted, cache under the original Bare identity and return the cached reading. Local single-window method matches that orchestration. | TESTED |
| GFM-039 | cache-miss branch (`:130-156`) | `_actualReadFontInfo` runs only on miss. Local: Local match. | TESTED |
| GFM-040 | suspicious-reading fallback branch (`:133-153`) | Enter when any of typical-half, typical-full, space or max-digit is `<= 2`; copy unaffected style/isMonospace/arrow fields, re-read target PixelRatio and floor all six measured widths via the counted constant 5. Local: branch and trigger set match. | TESTED |
| GFM-041 | fallback pixel ratio (`:136`) | Re-read live target-window PixelRatio. Local: Local reads global `window.devicePixelRatio` or `1`. Multi-window reduction explicit. | TESTED |
| GFM-042 | fallback width-floor constant (`:145-151`) | Independently reused constant `5`, applied to typical half, typical full, space, middot, wsmiddot and max digit widths. Local: exact constant and six applications match. | TESTED |
| GFM-043 | `_createRequest` (`:160-165`) | Construct one request, always append to all, optionally append same object to monospace list. Local: Local `create_request`; matches. | TESTED |
| GFM-044 | optional monospace branch (`:163`) | `null` excludes request from monospace comparison. Local: Local `None` branch matches. | TESTED |
| GFM-045 | `_actualReadFontInfo` (`:167-245`) | Own both request arrays, reference-width setup, loop mechanics, initial arrow capability and the complete request/derive/output orchestration; only real branches/constants/callbacks remain separate. Local method is a close mirror. | TESTED |
| GFM-046 | typical halfwidth request (`:171`) | Regular `n`, in all and monospace. Local: Local exact. | TESTED |
| GFM-047 | typical fullwidth request (`:172`) | Regular U+FF4D, in all only. Local: Local exact. | TESTED |
| GFM-048 | space request (`:173`) | Regular U+0020, in all and monospace. Local: Local exact. | TESTED |
| GFM-049 | digit request corpus and maximum (`:174-183,205`) | Request Regular digits 0 through 9 in all+monospace and derive maxDigitWidth as their ten-way maximum. Local exact corpus and nonnegative loop are equivalent. | TESTED |
| GFM-050 | rightwards-arrow request (`:186`) | Regular U+2192, in all and monospace. Local: Local exact. | TESTED |
| GFM-051 | halfwidth-arrow request (`:187`) | Regular U+FFEB, in all only. Local: Local exact. | TESTED |
| GFM-052 | middot request (`:190`) | Regular U+00B7, in all and monospace. Local: Local exact. | TESTED |
| GFM-053 | word-separator-middot request (`:193`) | Regular U+2E31, in all only. Local: Local exact. | TESTED |
| GFM-054 | monospace test characters (`:196`) | Exact eight-character corpus: vertical bar, slash, hyphen, underscore, `i`, `l`, `m`, percent. Local: Local exact eight-element array. | TESTED |
| GFM-055 | monospace style matrix (`:197-201`) | For every test char request Regular, Italic, and Bold, all in both lists. Local: Local exact. | TESTED |
| GFM-056 | `readCharWidths` call (`:203`) | One DOM measurement pass receives target window, Bare style, and full request array. Local: Local calls Rabbita DOM reader with Bare style; single global document. | TESTED |
| GFM-057 | initial monospace gate (`:207`) | Only ligatures-off font settings are eligible. Local: Local exact constant comparison. | TESTED |
| GFM-058 | monospace tolerance (`:210-214`) | Difference outside inclusive `[-0.001, 0.001]` sets false; the local next-guard exit is observationally equivalent and tested. | TESTED |
| GFM-059 | monospace arrow-width gate (`:218-221`) | If monospace and halfwidth arrow is not exactly reference width, disable it. Local: Local exact. | TESTED |
| GFM-060 | oversized halfwidth-arrow gate (`:222-225`) | If halfwidth arrow is wider than regular arrow, disable regardless of monospace. Local: Local exact. | TESTED |
| GFM-061 | output `FontInfo` construction (`:227-244`) | Copy Bare family/weight/size/features/variations/lineHeight/letterSpacing; write derived isMonospace, typical half/full widths, arrow capability, space, middot, wsmiddot and max digit; use the distinct target PixelRatio fact and construct trusted=true. Local record mapping contains every field in the same order. | TESTED |
| GFM-062 | output PixelRatio (`:228`) | Uses the live PixelRatio of the one supported browser owner window rather than the Bare input ratio. | TESTED |
| GFM-063 | `FontMeasurementsCache._keys` (`:250,254`) | Null-prototype id-to-Bare map for enumeration. Local: Local ordered `cache_keys` array; single-window cache reduction. | PORTED |
| GFM-064 | `_values` (`:251,255`) | Null-prototype id-to-FontInfo map. Local: Local `Map[String, FontInfo]`. | PORTED |
| GFM-065 | cache constructor (`:253-256`) | Create both null-prototype maps. Local: Local singleton literal initializes array/map. | PORTED |
| GFM-066 | cache `has` (`:258-261`) | Boolean value lookup by `item.getId()`. Local: Local `Map.contains` within write and direct `get` in read. | TESTED |
| GFM-067 | cache `get` (`:263-266`) | Return value by Bare id. Local: Local `Map.get`. | TESTED |
| GFM-068 | cache `put` (`:268-272`) | Store both original Bare key and FontInfo value. Local: Local stores id/value and separately tracks id, not Bare object. Sufficient for eviction; persistence enumeration differs. | TESTED |
| GFM-069 | cache `remove` (`:274-278`) | Delete both key and value by FontInfo id. Local: Local deletes value and rebuilds id list during eviction. | TESTED |
| GFM-070 | cache `getValues` (`:280-282`) | Enumerate keys then map to values. Local: Local iterates `cache_keys`; equivalent for eviction, serialization absent. | TESTED |
| GFM-071 | source-owned `getValues` map callback (`:281`) | Folded-cache evidence proves insert/overwrite/remove/re-add key order and the id-to-value mapping order returned by `cached_values`. | TESTED |
| GFM-072 | `FontMeasurements` singleton (`:285`) | Export one process-wide `FontMeasurementsImpl`. Local: Local module singleton plus `font_measurements()` accessor. | PORTED |
#### Historical Gate B correction record

The formal read-only Gate B audit confirmed the 217-atom denominator but
rejected the initial proposed terminal map and test authority. The amendment
changed only `GVLay-036`, `GFM-018`, `GFM-025`, `GFM-026`, and
`GFM-063`–`GFM-065`. Closing review later reclassified only `GVLay-044`.

#### Mechanical denominator

Final prefix and terminal counts:

```text
Prefix:   GVLay 53 + GVR 41 + GFI 51 + GFM 72 = 217
Terminal: 117 TESTED + 57 PORTED + 13 DEFERRED + 30 N-A = 217
Raw reconciliation: 273 - 65 merged/removed + 9 added = 217
```

IDs are contiguous within each prefix; all 217 rows have a final terminal and
the denominator remains fixed.

#### Behavior-variable matrix

The matrix below is keyed by source cluster rather than raw IDs; after the accepted merges it refers only to the contiguous corrected GVLay/GVR/GFI/GFM rows above.

| Cluster | Axes | Required cases / boundaries | Lowest useful evidence |
|---|---|---|---|
| dimension normalization | width, contentWidth, height, contentHeight | negative, zero, positive fractional, positive integer, signed-32-bit overflow boundary; content smaller/equal/larger than viewport | pure package test |
| content-size event | old/new content axes; viewport-only axes | neither, width-only, height-only, both; viewport-only must not fire | EditorScrollable white-box |
| horizontal scrollbar height | effective visibility, width vs contentWidth, configured size | Auto/Visible with `width >`, `==`, `< contentWidth`; size zero/nonzero; Hidden is explicitly mapped to SKIPPED below | ViewLayout package test + ledger mapping |
| content height | scrollBeyondLastLine, ignoreHorizontalScrollbarInContentHeight, padding, lineHeight, overflow | beyond-last on/off; ignore on/off; remainder negative/zero/positive; horizontal scrollbar visible/absent | package + browser bottom-reach test |
| wrapped content width | wrapping and absent minimap owner | wrapping returns measured max width; the source threshold/right-minimap pair is N-A (`GVLay-044/045`) | package test plus ledger review |
| unwrapped content width | maxLineWidth, scrollBeyondLastColumn, typical halfwidth, vertical scrollbar, whitespace min, overlay min | each candidate independently wins; ties; zero; max width shrinks/grows | pure package test |
| width-to-height feedback | content-width transition | no hscroll→hscroll and reverse; content-height event/scroll clamp follows | integration + browser |
| render-space choice | space, middot, wsmiddot widths | wsmiddot closer; middot closer; exact tie (middot); chosen width equal/different from space | renderer package test |
| normalized render-input identity | five scoped fields plus raw middot/wsmiddot candidates | identical inputs; each scoped field changes independently; raw candidates differ while derived width/glyph stay equal; derived width differs; derived glyph differs; tie remains U+00B7 | renderer equality + retained-render no-write test |
| whitespace width | mono fact, foreign elements, token class, tab stop | mono/proportional; foreign yes/no; `mtkw`/other; one-column and multi-column tabs | renderer HTML/reference test |
| arrow glyph | measured capability, tab width | unsafe/safe × width 1/>1; only safe+1 uses U+FFEB | renderer HTML test |
| column arithmetic | faux indent, start column, tab size, fullwidth | before/at/after faux indent; every tab residue; BMP fullwidth and ordinary; mapping end column | renderer mapping test |
| line-height normalization | raw height and platform | zero; `(0,8)` em; exactly 8; rounded below/above; mac/non-mac; editor-zoom cases are explicitly mapped to SKIPPED below | fontInfo package test + ledger mapping |
| variation translation | setting and weight | off/non-translate; translate+normal; translate+bold; numeric weights including canonical validation boundary | fontInfo package test |
| family massage | punctuation and fallback identity | comma/double/single quote; plus; space; plain; same/different fallback | fontInfo package test |
| bare-font cache identity | all eight `BareFontInfo.getId` axes | same object/value; change pixelRatio, family, weight, size, feature settings, variation settings, line height, and letter spacing independently; verify fixed join order | fontInfo package test |
| measured-font equality | every included and intentionally omitted `FontInfo.equals` axis | each included axis differs independently and returns false; pixelRatio, isTrusted, and isMonospace differ independently and remain equal | fontInfo package test |
| platform font defaults | macOS, Windows, Linux/other | exact three family stacks; macOS size 12 versus other size 14; weight normal, line height 0, letter spacing 0 | pure platform-selection helper/reference test |
| measurement cache | cache/trust/timer | hit/miss; trusted/untrusted; clear; retry pending/not pending; single-window event behavior; multi-window and dispose axes are explicitly mapped to SKIPPED below | browser/config white-box + ledger mapping |
| folded cache ordering | insertion, overwrite, removal, re-addition | insert A then B; overwrite A without reordering; remove A; re-add A at the tail; `getValues` maps ids to values in key order; clear resets both stores | browser/config white-box |
| explicit SKIPPED seams | unavailable option/window/lifecycle axes | Hidden scrollbar -> SKIPPED (`GVLay-036` DEFERRED); minimap threshold/side -> SKIPPED (`GVLay-044/045` N-A); multiple windows -> SKIPPED (`GFM-018/025/026` DEFERRED); pending-timer dispose -> SKIPPED (`GFM-022/023` N-A); editor zoom -> SKIPPED (`GFI-008` N-A) | ledger review; no PASS may cite a skipped axis |
| suspicious measurements | half/full/space/digit widths | each trigger alone at `<2`, `==2`, `>2`; middot-only low is not trigger but is floored after another trigger; floor below/equal/above 5 | deterministic measurement seam test |
| monospace detection | ligatures and request widths | ligatures on/off; every request equal; diff exactly ±0.001; just outside both boundaries; early failure | deterministic request test |
| arrow measurement | mono and three widths | mono/nonmono; halfwidth equal/not reference; halfwidth `>`, `==`, `<` regular | deterministic request test |
| request corpus | char/type/subset | exact n/fullwidth/space/digits/arrows/dots; exact `\|/-_ilm%` × Regular/Italic/Bold; all vs monospace membership | spy measurement seam test |
| live browser font | font readiness/platform | committed mono and proportional font; `document.fonts.ready`; deviceScaleFactor 1; 100% zoom; PixelRatio recorded | Playwright Chromium fixture |

#### Final local mapping and reviewed seams

1. ViewLayout retains measured max width, computes the fixed product's wrapped
   or unwrapped extent, and feeds horizontal-scrollbar visibility into bottom
   content height. Auto scrollbar, zero padding, no minimap/overlay minimum,
   and measured 16px line CSS padding are contract-documented fixed arms.
2. `setMaxLineWidth` is owned by ViewLines feedback. A compatibility
   `set_content_width` spelling and two-stage `ScrollChange` merge preserve
   local callers and complete transition flags without changing event order.
3. RenderLineInput stores normalized render-space middot width/glyph identity;
   different raw candidates with the same normalized result produce a retained
   zero-write render. Arrow, tab residue, faux-indent, and mapping matrices are
   source-derived ordinary tests.
4. FontInfo is a flattened MoonBit hierarchy with a portable ToInt32 and
   parseInt helper. Zoom/persistence and TypeScript nominal layers are the
   row-local N-A/DEFERRED seams recorded above.
5. FontMeasurements preserves the complete request corpus/subset, exact 5px
   fallback, digit maximum, tolerance, arrow gates, cache ordering, and timer
   truth table. It deliberately folds per-window cache/PixelRatio/timer state
   into the single browser window; the process-lifetime singleton has no
   disposal or persistence channel.
6. The four non-upstream suites use ordinary `*_geometry_*` names; the pinned
   Monaco renderer reference file again contains only its upstream-labelled
   cases. Owning config and view-layout READMEs record the final contracts.

#### Historical inventory stop gate

- [x] Four source files read completely at the checked-in source.
- [x] Hashes and line counts recorded.
- [x] Scoped clusters and cross-plan overlaps closed explicitly.
- [x] Cache/platform/persistence exclusions have explicit GFM rows.
- [x] Behavior variables and local gaps recorded.
- [x] Independent denominator review corrections are applied: 217 unique, contiguous, final four-column rows.
- [x] Final terminals are 117 TESTED / 57 PORTED / 13 DEFERRED / 30 N-A.
- [x] The expanded matrix covers normalized renderer identity, font identities/equality, platform defaults, folded-cache ordering, and explicit SKIPPED mappings.
- [x] Integrated this corrected fragment into the geometry child as a
  documentation-only amendment; product/test work remains stopped for fresh
  Gate B re-review.
- [x] Fresh independent Gate B re-review approves the Group C denominator,
  terminals, and expanded matrix.

The corrected documentation-only amendment was independently approved before
any product or test edit.

## Test-Authority Corrections

- Existing scroll/thumb tests use mostly ASCII and do not establish rendered
  width parity.
- Existing hover/content-widget tests assert visibility/content, not anchor
  geometry across tabs, injected text, or proportional fonts.
- Headless uniform-width arithmetic is not a substitute for browser DOM
  measurement.
- `monaco_render_line_reference_test.mbt` remains the exact historical upstream
  suite at its own checked-in source pin and is not claimed as current-pin evidence.
  Geometry-specific renderer, FontInfo, FontMeasurements, and ViewLayout cases
  now live in ordinary `*_geometry_test.mbt` / `*_geometry_wbtest.mbt` files
  derived against checked-in source.

## Required Test Matrix (Phase 4)

Package/white-box tests:

- pure max-width cache transitions after a measured width is supplied;
- ViewLayout horizontal scrollbar height and bottom-extent arithmetic;
- all measured font facts reach renderer input unchanged;
- invalid/hidden widget positions follow source visibility decisions.

These are ordinary source-derived tests unless an exact upstream suite is
ported with its original labels/path/current pin.

Headless Viewer integration:

- wrap on/off and viewport/content-width transitions after a deterministic
  content-width input;
- public scroll dimensions and last-line reveal arithmetic after a measured
  width is injected;
- no claim about DOM line width, font measurement, ContentWidget placement, or
  ViewPart rendering.

Browser/component measurements use the repository Playwright Chromium project
at deviceScaleFactor 1 and 100 percent browser zoom. The fixture must use fixed
integer CSS dimensions, load committed deterministic monospace and proportional
test fonts, and await document.fonts.ready before measuring:

- ASCII, tabs at different tab stops, fullwidth text, combining text, and the
  deterministic proportional font;
- before/after injected text and dynamic inlay changes;
- CSS generated fold ellipsis or equivalent generated width;
- widest line initially visible, initially hidden, scrolled into view, then
  removed/replaced;
- the farthest rendered pixel is reachable without excessive permanent width;
- Viewer scrollWidth equals the source-required measured maximum plus padding
  within 1 CSS px;
- ContentWidget/hover anchor left matches a collapsed DOM Range at the model
  position within 1 CSS px;
- focused widget remains focus-preserving when its anchor leaves the viewport;
- horizontal scrollbar plus last line remains fully revealable.

A branch that cannot run under the fixed Chromium/font fixture requires an
explicit SKIPPED (reason) marker in the test map and a corresponding
DEFERRED/N-A member-ledger row; vague phrases such as where supported are not
an exit condition.

A pinned local Monaco fixture may collect comparative numeric measurements for
the same cases as non-gating diagnostic evidence only. Assertions target the
local offsetWidth, DOM Range, scroll reachability, and source arithmetic above;
cross-fixture pixel equality and screenshots do not determine pass/fail.

## Milestones

1. Inventory and ledger only; commit and stop.
2. Add exact upstream reference tests where a suite exists, ordinary
   source-derived tests elsewhere, and the fixed Chromium measurement fixture.
3. Thread complete FontInfo facts into renderer input.
4. Port ViewLines measured-width feedback and ViewLayout dimension updates.
5. Port ContentWidget validation, visible-range anchors, placement, and
   focus-preservation cluster.
6. Add complex-content browser geometry matrix.
7. Update owning READMEs and run all quality gates.
8. Independent source/ledger/diff/test review.

## Deviations (Phase 3)

The final reviewed seams are:

- Rabbita has no global typed DOM Range binding, so RangeUtil creates its one
  reusable Range from the first start node's `ownerDocument`; it still caches,
  catches, and parks the Range in source order. Rendered rows retain the
  harness-owned `data-line` attribute.
- The fixed Chromium target selects the normal slow RenderedViewLine factory.
  Fast/native-host, WebKit correction, browser-zoom policy, experimental
  whitespace, and GPU ViewLines remain row-local DEFERRED outcomes.
- The ViewModel currently emits LTR rendering data. ViewLines nevertheless
  owns an explicit model-direction capability and exact LTR/RTL newline
  arithmetic; production installs LTR until a real direction producer exists.
- Variable/custom line height remains outside the readonly product, while
  RenderingContext and ContentWidgets preserve the per-line query boundary.
- MoonBit traits represent optional widget callbacks with
  `has_before_render`/`has_after_render` capabilities and split safe helpers.
  ContentWidgets fingerprints are stamped in `View::new` to avoid a package
  cycle. Raw Rabbita style writes preserve order/value but omit FastDomNode's
  setter cache. Editor `allowOverflow`, fixed-overflow positioning, and the
  hover `shouldAppearBeforeContent` affinity producer remain DEFERRED.
- ViewLines crosses the package boundary with raw tuples and ContentWidgets
  receives a capability record. RenderingContext reconstructs the source
  carriers; MoonBit keeps public numeric carrier fields immutable because the
  scoped source has no mutating consumer. GPU fallback/concat/sort is DEFERRED.
- ViewLayout specializes fixed product options: Auto scrollbars (14px vertical,
  12px horizontal), zero editor padding, `scrollBeyondLastLine=false`,
  `ignoreHorizontalScrollbarInContentHeight=false`, no minimap or overlay
  minimum, and 16px right padding already measured in line DOM. The absent
  minimap makes `GVLay-044/045` N-A. Separate setters and a two-stage
  `ScrollChange` compatibility merge preserve source write/event order.
- Portable helpers reproduce JavaScript ToInt32 and parseInt behavior without
  importing browser code into dependency-bottom packages. FontInfo flattens
  the TypeScript inheritance/brand layers; editor zoom and persistence remain
  explicit N-A/DEFERRED rows.
- FontMeasurements folds per-window cache, PixelRatio, and timer ownership into
  the one browser window. Its process-lifetime singleton has no dispose or
  serialize/restore channel; the request corpus, exact safety floors, cache
  order, retry gate, and events remain source-shaped.
- Root render scheduling uses a single-window current/next queue equivalent to
  `runAtThisOrScheduleAtNextAnimationFrame`; smooth scrolling retains true
  next-frame scheduling. This preserves width-feedback scroll events without
  introducing an extra native frame.

The browser oracle embeds self-owned mono/proportional fonts, waits for font
readiness, fixes deviceScaleFactor 1, and uses a 1 CSS px geometry tolerance.

## Exit Gate

- [x] inventory rows equal ledger rows
- [x] measured rendered width drives horizontal extent
- [x] complex content is fully horizontally reachable
- [x] widgets use rendered visible-range geometry
- [x] all measured font facts reach the renderer
- [x] horizontal scrollbar height participates in bottom extent
- [x] browser geometry matrix is deterministic and green
- [x] all repository quality gates pass
- [x] independent closing reread finds no unaccounted scoped member

## Execution Record

- 2026-07-12: Phase 1–2 documentation-only inventory is ready. All eleven
  pinned source hashes and line counts were checked at oracle
  checked-in source. Independent pre-review rejected
  and normalized the raw Group A/B/C drafts before integration: statement-level
  inflation and frozen cross-plan duplicates were removed, omitted declared
  members/callbacks were restored, and applicable absent GPU/experimental seams
  were made explicit DEFERRED proposals instead of N-A.
- 2026-07-12: the initial normalized proposed denominator was 633/633 TODO rows: 242 line
  geometry, 174 widget/query, and 217 layout/renderer/font atoms. The proposed
  terminal map is 421 TESTED, 93 PORTED, 73 DEFERRED, and 46 N-A. No product or
  test file changed. It was committed as recorded milestone and stopped for Gate B.
- 2026-07-12: three independent Gate B reviews rejected recorded milestone. Group A
  omitted `ViewLines.getDomNode`, its two unsupported generic render methods,
  and `ViewLine.CLASS_NAME`; Group B omitted owner-window `scrollX ?? 0` and
  `scrollY ?? 0` fallbacks and duplicated/misclassified overflow/GPU ownership;
  Group C had seven incorrect N-A/PORTED/DEFERRED proposals. The reviews also
  required strategy, iframe/window, renderer identity, font identity/default,
  cache-order, and explicit SKIPPED matrix axes. The rejected commit remains
  historical and authorized no product/test work.
- 2026-07-12: the amended inventory is ready with 639/639 TODO rows: 246 line
  geometry, 176 widget/query, and 217 layout/renderer/font atoms. Its proposed
  map is 425 TESTED, 96 PORTED, 80 DEFERRED, and 38 N-A. All review corrections
  are integrated, all source hashes remain pinned, and no product or test file
  changed. Commit this amendment and STOP for fresh independent Gate B review.
- 2026-07-12: browser-geometry Gate B passed at documentation-only amendment
  milestone. The approved fixed
  denominator is 639/639 TODO rows with 425 planned TESTED, 96 PORTED, 80
  DEFERRED, and 38 N-A; the child-plan SHA-256 is
  `16a5e943fef417443f4cdbd3078c4491a1a0f3e64caa2f1adddb21609230258f`.
  Cross-assigned reviewers independently approved Group A, Group B, and Group
  C against the pinned sources, local ownership, proposed terminals, matrices,
  combined mechanics, and docs-only diff. No product or test edit preceded
  approval; implementation is authorized.

### 2026-07-12 — implementation, Gate D remediation, and freeze

Implementation milestone ports ViewLayout measured-width ownership,
horizontal-scrollbar bottom extent, renderer font facts, FontInfo defaults and
identity, and the single-window FontMeasurements cache/timer/request pipeline.
The milestone ports the normal ViewLine/RangeUtil strategy, ViewLines width
sweeps and visible-range facade, ContentWidgets validation/placement/callback/
focus behavior, rendering phases, generated contracts, and source-derived
white-box matrices. The milestone restores Monaco's current-frame render
queue so width-feedback scroll events do not request a second native frame.
The milestone adds the embedded-font Chromium oracle and real iframe owner-
window/page-clamp fixture.

Independent Group A review rejected earlier green states and drove exact
WrappingInfo/LayoutInfo resets, cancel/reschedule scheduling, converter and
direction progression, the function-valued normal factory, foreign-element
bit preservation, and the complete RangeUtil/ViewLine/ViewLines matrix.
Independent Group B review drove primary-before-secondary evaluation, frozen
outer key snapshots, the affinity/cache/callback/display matrices, detached
and iOS owner-window fallbacks, and real normal/overflow iframe evidence.
Independent Group C review drove exact six-field 5px floors, exhaustive request
subset and digit maxima, timer truth tables, initial layout facts, unsafe tab
arrows, nonzero start-column residues, retained no-write evidence, ordinary
test naming, and owning config contracts.

Closing review changed one Gate-B proposal: `GVLay-044` is N-A because the
predicate only selects the absent right-side minimap. The final 639-row ledger
is **424 TESTED + 96 PORTED + 80 DEFERRED + 39 N-A**, with zero TODO/PASS and
the approved prefix denominator unchanged.

Final isolated gates pass:

- `just check` and the architecture checker;
- `just test`: JS **1247/1247**, native **873/873**; Wasm/Wasm-GC have no test
  entry;
- `just build`;
- `just test-browser`: Chromium **74/74**, including geometry **6/6**;
- focused ViewLines **31/31**, ContentWidgets **26/26**, browser/view **32/32**,
  ViewLayout **185/185** on JS and native, common config **11/11** on JS and
  native, and browser config **10/10** on JS;
- `git diff --check`.

All owning READMEs and generated interfaces are current. Independent Group A,
Group B, and Group C closing rereads report no remaining code/test blocker.
This child is now implemented and frozen historical evidence.
