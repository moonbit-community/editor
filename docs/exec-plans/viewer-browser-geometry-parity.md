# Viewer Browser Geometry Parity

Status: inventory ready — STOP FOR REVIEW

Date: 2026-07-10

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Findings: P1-07, P1-08 geometry half

Depends on: viewer-render-invalidation-parity.md

No product code may be changed until the inventory and parity ledger are
committed and reviewed.

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

Every `Status` is deliberately `TODO` at this gate. `Proposed terminal` is a
review target, not implementation evidence. The normalized, deduplicated
denominator is:

```text
Line geometry: GVL 52 + GVLI 133 + GDRC 16 + GRU 25 + GVLO 16 = 242
Widget/query:  GCW 120 + GRC 54                                  = 174
Layout/font:   GVLay 53 + GVR 41 + GFI 51 + GFM 72               = 217
                                                                    ---
Total                                                               633

Proposed: 421 TESTED + 93 PORTED + 73 DEFERRED + 46 N-A = 633
Working:  633 TODO; 0 PASS
```

The three normalized fragments below supersede rejected raw drafts of
279/225/273 rows. Their independent pre-reviews removed statement-level
inflation, restored omitted declared members and callbacks, removed frozen
cross-plan duplicates, and changed absent GPU/experimental/fixed-option seams
from N-A to explicit DEFERRED where the source behavior remains applicable.
No product or test file changed while this denominator was built.

### Group A — ViewLines, ViewLine, RangeUtil, and options

#### Uniform atom rule

One row represents one declared member, field/property, behavior-changing branch or early return, independently material source-owned callback/control-flow constant, or owned DOM/CSS fact. A field owns its literal/arithmetic. Ordinary allocation, external DOM reads, straight-line statements, intermediate arithmetic, loop mechanics, branch arms, and final returns stay on their owning member or branch row.

#### Cross-plan ownership and excluded siblings

- Frozen render VL-011 owns `_maxLineWidth`; VL-027/VL-028 own wrapping/layout resets; VL-019 owns flush; VL-002 owns `domNode`, including the scroll-width write at `viewLines.ts:318`. Geometry closes those handoffs outside this source denominator.
- Frozen VLI-001–013 own `_options`, `_isMaybeInvalid`, `_renderedViewLine`, getDomNode, and the event/selection invalidation cluster. Group A consumes those exact rows without recounting them.
- `viewLine.ts:109–149,175–178` are explicitly excluded non-geometry render/invalidation/selection siblings; they are not falsely claimed as frozen VLI ledger rows. Geometry owns only the scoped renderer-font/option wiring, DOM/CSS layout, strategy, width, and visible-range clusters below.
- ViewLines reveal requests/arithmetic, DOM-to-position hit testing, standalone GPU rendering, browser-zoom check scheduler, and ViewLine node-to-column helpers remain named excluded siblings. Scoped shared methods are labelled geometry slices and do not claim excluded statements.
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

| ID | Source atom | Local target / gap | Status | Proposed terminal |
|---|---|---|---|---|
| GDRC-001 | `_didDomLayout = false` (`:8`) | `DomReadingContext.did_dom_layout_flag`; constructor default false. | TODO | TESTED |
| GDRC-002 | `_clientRectDeltaLeft = 0` (`:9`) | `client_rect_delta_left_value = 0.0`. | TODO | TESTED |
| GDRC-003 | `_clientRectScale = 1` (`:10`) | `client_rect_scale_value = 1.0`. | TODO | TESTED |
| GDRC-004 | `_clientRectRead = false` (`:11`) | `client_rect_read = false`. | TODO | TESTED |
| GDRC-005 | `didDomLayout` getter (`:13-15`) | `DomReadingContext::did_dom_layout`. | TODO | TESTED |
| GDRC-006 | `readClientRect` (`:17-26`) | `DomReadingContext::read_client_rect`; preserve unread guard, flag, bounding-rect/offsetWidth reads, layout mark, cache assignments, and order. | TODO | TESTED |
| GDRC-007 | unread-only guard (`:18-25`) | Existing `if !client_rect_read`; repeated reads must not relayout. | TODO | TESTED |
| GDRC-008 | positive-width scale/fallback branch (`:24`) | Exact `offsetWidth > 0 ? rect.width / offsetWidth : 1`. | TODO | TESTED |
| GDRC-009 | `clientRectDeltaLeft` getter (`:28-33`) | Existing lazy getter. | TODO | TESTED |
| GDRC-010 | delta getter unread branch (`:29-31`) | First getter call triggers exactly one `readClientRect`. | TODO | TESTED |
| GDRC-011 | `clientRectScale` getter (`:35-40`) | Existing lazy getter. | TODO | TESTED |
| GDRC-012 | scale getter unread branch (`:36-38`) | First getter call triggers exactly one `readClientRect`. | TODO | TESTED |
| GDRC-013 | constructor (`:42-46`) | `DomReadingContext::new` receives `_domNode` and `endNode`; field rows own the four default literals. | TODO | TESTED |
| GDRC-014 | private `_domNode` parameter property (`:43`) | Existing private `dom_node`. | TODO | PORTED |
| GDRC-015 | public `endNode` parameter property (`:44`) | Existing `end_node`, used as Range resting spot. | TODO | TESTED |
| GDRC-016 | `markDidDomLayout` (`:48-50`) | Existing sticky false-to-true transition. | TODO | TESTED |

GDRC denominator: **16**.

#### `rangeUtil.ts` — GRU

| ID | Source atom | Local target / gap | Status | Proposed terminal |
|---|---|---|---|---|
| GRU-001 | static `_handyReadyRange` (`:17`) | Missing: local FFI allocates one DOM Range per call. Retain one document Range. | TODO | TESTED |
| GRU-002 | `_createRange` (`:19-24`) | Missing source-shaped reusable-range member; it owns first-use `document.createRange()` and the ordinary cached return. | TODO | TESTED |
| GRU-003 | absent-range initialization branch (`:20-22`) | Create only on first use; later calls reuse identity. | TODO | TESTED |
| GRU-004 | `_detachRange` (`:26-30`) | Missing resting-spot helper; member owns `selectNodeContents(endNode)`. | TODO | TESTED |
| GRU-005 | `_readClientRects` (`:32-45`) | Add exact try/catch/finally wrapper; member owns ordered setStart/setEnd/getClientRects statements. | TODO | TESTED |
| GRU-006 | DOM Range failure catch/`null` (`:39-41`) | Local returns `[]`; preserve nullable source outcome internally. | TODO | TESTED |
| GRU-007 | unconditional detach in `finally` (`:42-44`) | Missing; must run on success and failure. | TODO | TESTED |
| GRU-008 | `_mergeAdjacentRanges` (`:47-72`) | `merge_adjacent_ranges` exists; reconcile exact source shape. | TODO | TESTED |
| GRU-009 | exactly-one early return (`:48-51`) | Local uses `<= 1`; empty is prevented by source caller and must be tested separately. | TODO | TESTED |
| GRU-010 | browser-rounding tolerance `0.9` (`:61`) | Existing exact constant. | TODO | TESTED |
| GRU-011 | adjacent-vs-disjoint merge branch (`:61–66`) | One `if/else`: inclusive `>=` merges with exact max width; otherwise append prior range and advance. | TODO | TESTED |
| GRU-012 | `_createHorizontalRangesFromClientRects` (`:74-89`) | Missing source-shaped layer; member owns per-rect clamped/scaled left, scaled width, result construction, and final adjacent-range merge. | TODO | TESTED |
| GRU-013 | null-or-empty rect-list early return (`:75-77`) | Local empty array must map to internal `null`. | TODO | TESTED |
| GRU-014 | public `readHorizontalRanges` (`:91-143`) | Replace monolithic FFI; member owns child/offset clamping, firstChild/rect reads, final client-rect read, layout mark, and normalized conversion around counted branches. | TODO | TESTED |
| GRU-015 | minimum child index constant `0` (`:93`) | Preserve as clamp lower bound. | TODO | TESTED |
| GRU-016 | maximum child index `children.length - 1` (`:94`) | Independently reused upper clamp/control bound; target must receive the source reading target directly. | TODO | TESTED |
| GRU-017 | empty-children early return (`:95-97`) | Existing FFI returns empty; preserve nullable source branch. | TODO | TESTED |
| GRU-018 | collapsed empty-span special branch (`:101-107`) | Missing compound empty-span predicate; branch owns element `getClientRects`, layout mark, and bounding-box fallback. | TODO | TESTED |
| GRU-019 | cross-span guard (`:111`) | Missing explicit source branch. | TODO | TESTED |
| GRU-020 | ending-at-next-span-zero branch (`:112-115`) | Move end to prior span and maximum safe offset. | TODO | TESTED |
| GRU-021 | `Constants.MAX_SAFE_SMALL_INTEGER` sentinel (`:114,125,129`) | Missing; one source constant is reused by all three fallbacks. | TODO | TESTED |
| GRU-022 | missing-endpoint wrapper branch (`:121-131`) | Preserve the outer missing-endpoint branch and its two independently counted repairs; member owns ordinary firstChild reads. | TODO | TESTED |
| GRU-023 | missing start + zero offset + prior span branch (`:123-126`) | Missing. | TODO | TESTED |
| GRU-024 | missing end + zero offset + prior span branch (`:127-130`) | Missing. | TODO | TESTED |
| GRU-025 | still-missing endpoint early return (`:133-135`) | Existing endpoint helper instead synthesizes element endpoints. | TODO | TESTED |

GRU denominator: **25**.

#### `viewLineOptions.ts` — GVLO

| ID | Source atom | Local target / gap | Status | Proposed terminal |
|---|---|---|---|---|
| GVLO-001 | `themeType` field (`:11,27,50`) | No typed theme-event/options seam; concrete theme remains CSS/root-owned. | TODO | N-A (no typed theme option contract) |
| GVLO-002 | `renderWhitespace` field (`:12,30,51`) | Existing `ViewLineOptions.render_whitespace`. | TODO | TESTED |
| GVLO-003 | `experimentalWhitespaceRendering` field (`:13,31,52`) | No exposed experimental whitespace renderer. | TODO | DEFERRED (experimental whitespace option absent) |
| GVLO-004 | `renderControlCharacters` field (`:14,32,53`) | Existing field and runtime flow. | TODO | TESTED |
| GVLO-005 | `spaceWidth` field (`:15,33,54`) | Existing field; must come from measured FontInfo. | TODO | TESTED |
| GVLO-006 | `middotWidth` field (`:16,34,55`) | Existing field; currently not supplied by complete browser measurement. | TODO | TESTED |
| GVLO-007 | `wsmiddotWidth` field (`:17,35,56`) | Existing field; currently not supplied by complete browser measurement. | TODO | TESTED |
| GVLO-008 | `useMonospaceOptimizations` field (`:18,36-39,57`) | Field owns exact `fontInfo.isMonospace` plus disable-option conjunction; local must consume measured monospace state. | TODO | TESTED |
| GVLO-009 | `canUseHalfwidthRightwardsArrow` field (`:19,40,58`) | Existing field; must come from measured FontInfo. | TODO | TESTED |
| GVLO-010 | `lineHeight` field (`:20,41,59`) | Existing `line_height`, consumed by retained line layout. | TODO | TESTED |
| GVLO-011 | `stopRenderingLineAfter` field (`:21,42,60`) | Existing field and truncation visibility branches. | TODO | TESTED |
| GVLO-012 | `fontLigatures` field (`:22,43,61`) | Local stores Bool rather than source ligature string; observable renderer predicate is the target. | TODO | TESTED |
| GVLO-013 | `verticalScrollbarSize` field (`:23,44,62`) | Existing field; RTL padding and renderer input must consume it. | TODO | TESTED |
| GVLO-014 | `useGpu` field (`:24,45,63`) | Source field owns exact GPU option equality; Viewer has no GPU renderer. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GVLO-015 | constructor (`:26-46`) | Local construction is split between `ViewLinesConfiguration` and `ViewLineOptions::new`; preserve all applicable reads. | TODO | TESTED |
| GVLO-016 | `equals` 14-field conjunction (`:48-64`) | Local derived equality covers 11 fields; applicable complete identity must remain equality-gated. | TODO | TESTED |

GVLO denominator: **16**.

#### `viewLines.ts` geometry clusters — GVL

| ID | Source atom | Local target / gap | Status | Proposed terminal |
|---|---|---|---|---|
| GVL-001 | `LastRenderedData._currentVisibleRange` (`:33`) | Local has no retained rendered-range owner; add source-shaped state for multi-line range queries. | TODO | TESTED |
| GVL-002 | `LastRenderedData` constructor (`:35-37`) | Initialize exact `Range(1,1,1,1)`. | TODO | TESTED |
| GVL-003 | `getCurrentVisibleRange` (`:39-41`) | Missing getter. | TODO | TESTED |
| GVL-004 | `setCurrentVisibleRange` (`:43-45`) | Missing render-time update. | TODO | TESTED |
| GVL-005 | `_linesContent` field (`:103,147,672-676`) | Existing `ViewLines.lines_content`; retain the layer node. Scoped layer CSS writes have their own rows. | TODO | PORTED |
| GVL-006 | `_textRangeRestingSpot` field (`:104,148,408,432,487`) | Existing detached `text_range_resting_spot`. | TODO | TESTED |
| GVL-007 | `_asyncUpdateLineWidths` field (`:120,160-162,538-543,652-657`) | Missing 200ms slow-width scheduler. | TODO | TESTED |
| GVL-008 | constructor geometry cluster (`:130-174`) | Scoped constructor slice owns geometry-only construction/order for resting spot, width scheduler, and last-rendered state; frozen/excluded fields remain external handoffs. | TODO | TESTED |
| GVL-009 | slow-width scheduler callback (`:160-162`) | Source-owned callback invokes only `_updateLineWidthsSlow`. | TODO | TESTED |
| GVL-010 | slow-width scheduler delay `200` ms (`:162`) | Missing exact delay constant. | TODO | TESTED |
| GVL-011 | `dispose` geometry slice (`:176-180`) | Dispose the width scheduler before inherited `super.dispose`; local ViewLines currently has no disposable width work. | TODO | TESTED |
| GVL-012 | public `getLineWidth` (`:400-413`) | Existing method has the range guard and context/delegate read; add the post-read slow-width piggyback. | TODO | TESTED |
| GVL-013 | unrendered-line early return `-1` (`:403-406`) | Existing exact range guard. | TODO | TESTED |
| GVL-014 | public `resetLineWidthCaches` (`:415-421`) | Missing member; it owns the inclusive visible-window loop and each retained line's cache reset. | TODO | TESTED |
| GVL-015 | public `linesVisibleRangesForRange` (`:423-480`) | Missing multi-line query; the member owns original-end capture, rendered-range intersection, shared context/converter progression, result construction, and slow-width piggyback around the counted branches. | TODO | TESTED |
| GVL-016 | null-intersection early return (`:426-428`) | Missing. | TODO | TESTED |
| GVL-017 | `includeNewLines` initialization branch (`:434-437`) | Missing. | TODO | TESTED |
| GVL-018 | rendered-window miss `continue` (`:443-445`) | Preserve per-line skip after visible-range clipping. | TODO | TESTED |
| GVL-019 | start-column first-line branch (`:447`) | First line uses clipped start; later lines start at column 1. | TODO | TESTED |
| GVL-020 | end-column/continuation branch (`:448-449`) | Non-original-end lines use line max column and set continuation. | TODO | TESTED |
| GVL-021 | null per-line ranges `continue` (`:453-455`) | Missing. | TODO | TESTED |
| GVL-022 | newline-width gate (`includeNewLines && line < originalEnd`) (`:457`) | Missing. | TODO | TESTED |
| GVL-023 | actual model-newline branch (`:461-467`) | Add width only when adjacent view lines map to distinct model lines. | TODO | TESTED |
| GVL-024 | RTL newline branch (`:464-466`) | Subtract the same width from `left` for RTL model lines. | TODO | TESTED |
| GVL-025 | zero-result early return (`:475-477`) | Return `null`, not an empty list. | TODO | TESTED |
| GVL-026 | private `_visibleRangesForLineRange` (`:482-492`) | Missing helper; it owns one context, retained-line delegation, and post-read slow-width piggyback. | TODO | TESTED |
| GVL-027 | helper unrendered-line early return (`:483-485`) | Existing local measurements return empty/None through a different seam. | TODO | TESTED |
| GVL-028 | public `visibleRangeForPosition` (`:502-508`) | Local View query bypasses retained ViewLine semantics; source returns HorizontalPosition from the first range. | TODO | TESTED |
| GVL-029 | missing visible-ranges early return (`:504-506`) | Existing local `left < 0` reduction; reconcile source nullable outcome. | TODO | TESTED |
| GVL-030 | public `updateLineWidths` (`:512-514`) | Missing synchronous slow sweep entrypoint. | TODO | TESTED |
| GVL-031 | `_updateLineWidthsFast` wrapper (`:521-523`) | Missing exact `fast=true` wrapper. | TODO | TESTED |
| GVL-032 | `_updateLineWidthsSlow` wrapper (`:525-527`) | Missing exact `fast=false` wrapper. | TODO | TESTED |
| GVL-033 | `_updateLineWidthsSlowIfDomDidLayout` (`:533-544`) | Missing piggyback method; after both early-return guards it cancels the pending scheduler before the slow sweep. | TODO | TESTED |
| GVL-034 | no-DOM-layout early return (`:534-537`) | Do no sweep when the triggering query did not force layout. | TODO | TESTED |
| GVL-035 | not-scheduled early return (`:538-541`) | Widths are already current when no slow sweep is pending. | TODO | TESTED |
| GVL-036 | `_updateLineWidths(fast)` (`:546-572`) | Missing visible-width sweep; the member owns per-line maximum accumulation, final ensure call, and completeness result. | TODO | TESTED |
| GVL-037 | local maximum initial constant `1` (`:550`) | Preserve minimum feedback width. | TODO | TESTED |
| GVL-038 | fast-and-not-fast-readable branch (`:555-559`) | Set incomplete and continue without forcing layout. | TODO | TESTED |
| GVL-039 | all-widths/full-document branch (`:564-567`) | Only a complete rendered document proves the global maximum current; clear the prior maximum before ensuring the sweep result. | TODO | TESTED |
| GVL-040 | `renderText` geometry cluster (`:613-677`) | Existing method renders rows first; add last-rendered-range update and width feedback before rail layout. | TODO | TESTED |
| GVL-041 | `domNode.setWidth(scrollWidth)` DOM/CSS write (`:617`) | Existing exact write from `layout.dimensions()`. | TODO | TESTED |
| GVL-042 | `domNode.setHeight(min(scrollHeight,1000000))` DOM/CSS write (`:618`) | Existing cap/write. | TODO | TESTED |
| GVL-043 | height cap `1_000_000` (`:618`) | Preserve exact independent constant. | TODO | TESTED |
| GVL-044 | fast-sweep schedule-vs-cancel branch (`:652–657`) | One `if/else`: incomplete fast sweep schedules delayed work; complete sweep cancels it. | TODO | TESTED |
| GVL-045 | `_linesContent.setLayerHinting` DOM/CSS write (`:672`) | Existing `set_layer_hinting` using frozen configuration field. | TODO | TESTED |
| GVL-046 | `_linesContent.setContain('strict')` CSS property (`:673`) | Existing exact value. | TODO | TESTED |
| GVL-047 | `_linesContent.setTop(-adjustedScrollTop)` CSS property (`:674-675`) | Existing exact `-(scrollTop - bigNumbersDelta)` translation. | TODO | TESTED |
| GVL-048 | `_linesContent.setLeft(-scrollLeft)` CSS property (`:676`) | Existing exact negative translation. | TODO | TESTED |
| GVL-049 | `_ensureMaxLineWidth` (`:681-691`) | Missing member; it owns ceiling integerization and monotonic layout feedback. | TODO | TESTED |
| GVL-050 | GPU early return (`:682-685`) | No local GPU ViewLines owner. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GVL-051 | strictly-growing maximum branch (`:687-690`) | Equal/smaller widths do not write; a growth assigns the cache then calls ViewLayout exactly once. | TODO | TESTED |
| GVL-052 | `_lastRenderedData` field (`:124,167,425,616`) | Missing ViewLines-owned rendered-range cache; compose `LastRenderedData` at construction and update it only after rows render. | TODO | TESTED |

GVL denominator: **52**.

#### `viewLine.ts` width, visible-range, and layout clusters — GVLI

| ID | Source atom | Local target / gap | Status | Proposed terminal |
|---|---|---|---|---|
| GVLI-001 | module `canUseFastRenderedViewLine` constant (`:25–47`) | Retain the selected fast-render policy result; the source-owned selector IIFE and its branches are separate. | TODO | DEFERRED (browser zoom and fast-renderer policy seam) |
| GVLI-002 | `canUseFastRenderedViewLine` selector IIFE callback (`:25–47`) | Source-owned callback owns native/platform branch order and ordinary final true fallback. | TODO | DEFERRED (browser zoom and fast-renderer policy seam) |
| GVLI-003 | native-platform early true (`:26-29`) | Root Viewer is js-only. | TODO | N-A (native platform cannot construct browser View) |
| GVLI-004 | Linux, Firefox, or Safari false branch (`:31-44`) | No source-shaped fast-path platform gate; fixed geometry fixture is Chromium. | TODO | DEFERRED (non-fixture platform and browser zoom seam) |
| GVLI-005 | mutable `monospaceAssumptionsAreValid = true` (`:49`) | No global browser-zoom invalidation state. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-006 | constructor `_viewGpuContext` parameter property (`:59`) | No GPU ViewLine context. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GVLI-007 | `ViewLine` constructor (`:59–63`) | Declared member owns construction/order; frozen field rows own retained invalidation assignments and the GPU parameter property remains separately deferred. | TODO | TESTED |
| GVLI-008 | `setDomNode` (`:73-79`) | Existing `ViewLine::set_dom_node`, but local state cannot represent the source's absent-rendered-line error. | TODO | TESTED |
| GVLI-009 | rendered-line-present-vs-throw branch (`:74–78`) | One `if/else`: attach a cached DOM wrapper only when rendered state exists; otherwise throw the exact invariant failure. | TODO | TESTED |
| GVLI-010 | `renderLine` scoped geometry integration (`:102-232`) | Scoped renderLine geometry member owns measured option/font argument flow, ordinary ligature predicate, DOM/layout construction, and rendered strategy around counted branches; frozen/excluded siblings are not recounted. | TODO | TESTED |
| GVLI-011 | GPU `canRender` branch (`:103-107`) | When GPU can render, remove prior DOM, clear retained strategy, and return false; local GPU path is absent. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GVLI-012 | RTL `dir="rtl"` DOM attribute (`:180-182`) | Local row HTML omits direction attributes. | TODO | TESTED |
| GVLI-013 | contains-RTL `dir="ltr"` DOM attribute (`:183-185`) | Local row HTML omits direction attributes. | TODO | TESTED |
| GVLI-014 | row `top` CSS property (`:186-188`) | Existing exact integer-pixel write. | TODO | TESTED |
| GVLI-015 | row `height` CSS property (`:188-190`) | Existing exact integer-pixel write. | TODO | TESTED |
| GVLI-016 | row `line-height` CSS property (`:190-192`) | Existing exact integer-pixel write. | TODO | TESTED |
| GVLI-017 | RTL `padding-right` CSS property (`:192-195`) | Missing; source uses vertical scrollbar size. | TODO | TESTED |
| GVLI-018 | row class attribute (`:196-198`) | Existing `view-line` plus local renderer class; reconcile source-owned class contract. | TODO | TESTED |
| GVLI-019 | seven-factor fast-render candidate branch (`:204-213`) | Local has no FastRenderedViewLine; preserve slow behavior and record optimization deferral. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-020 | no-fast-result fallback branch (`:221-228`) | Local always constructs equivalent slow retained state. | TODO | TESTED |
| GVLI-021 | `layoutLine` (`:235-241`) | Existing `ViewLine::layout_line`. | TODO | TESTED |
| GVLI-022 | rendered-line plus DOM guard (`:236-240`) | Existing optional DOM branch. | TODO | TESTED |
| GVLI-023 | `domNode.setTop` CSS write (`:237`) | Existing exact write. | TODO | TESTED |
| GVLI-024 | `domNode.setHeight` CSS write (`:238`) | Existing exact write. | TODO | TESTED |
| GVLI-025 | `domNode.setLineHeight` CSS write (`:239`) | Existing exact write. | TODO | TESTED |
| GVLI-026 | `getWidth` ViewLine delegator (`:252-257`) | Local direct helper is not a retained ViewLine method and has no cache variants. | TODO | TESTED |
| GVLI-027 | no-rendered-line width `0` (`:253-255`) | Existing FFI fallback is first-child absent `0`, but not the source state guard. | TODO | TESTED |
| GVLI-028 | `getWidthIsFast` ViewLine delegator (`:259-264`) | Missing. | TODO | TESTED |
| GVLI-029 | no-rendered-line fast result `true` (`:260-262`) | Missing exact branch. | TODO | TESTED |
| GVLI-030 | `needsMonospaceFontCheck` (`:266-271`) | Missing browser-zoom diagnostic member; after its no-line guard it returns the fast-strategy instance predicate. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-031 | no-rendered-line false return (`:267-269`) | Same deferred diagnostic cluster. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-032 | `monospaceAssumptionsAreValid` ViewLine member (`:273-281`) | Missing global/strategy dispatch. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-033 | no-rendered-line global fallback (`:274-276`) | Missing. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-034 | fast-instance delegation branch (`:277-279`) | Missing. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-035 | `onMonospaceAssumptionsInvalidated` (`:283-287`) | Missing fast-to-slow replacement. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-036 | fast-instance conversion branch (`:284-286`) | Missing. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-037 | `getVisibleRangesForRange` ViewLine member (`:289-318`) | Missing; the member owns input-length clamping, stop-rendering normalization, retained-strategy delegation, and final nullable result around counted branches. | TODO | TESTED |
| GVLI-038 | no-rendered-line null early return (`:290-292`) | Missing source state guard. | TODO | TESTED |
| GVLI-039 | both columns beyond truncation early return (`:299-302`) | Missing outside-rendered-line result at measured width and zero range width. | TODO | TESTED |
| GVLI-040 | start-column truncation clamp branch (`:304-306`) | Missing. | TODO | TESTED |
| GVLI-041 | end-column truncation clamp branch (`:308-310`) | Missing. | TODO | TESTED |
| GVLI-042 | nonempty delegated ranges branch (`:312-315`) | Missing `VisibleRanges(false, ranges)` wrapper. | TODO | TESTED |
| GVLI-043 | `resetCachedWidth` ViewLine member (`:327-329`) | Missing; local rereads every call. | TODO | TESTED |
| GVLI-044 | `IRenderedViewLine.domNode` field (`:333`) | Local ViewLine owns optional cached DOM directly. | TODO | PORTED |
| GVLI-045 | `IRenderedViewLine.input` field (`:334`) | Existing optional `render_input`. | TODO | PORTED |
| GVLI-046 | `IRenderedViewLine.getWidth` contract (`:335`) | Local free function covers only slow uncached width. | TODO | TESTED |
| GVLI-047 | `IRenderedViewLine.getWidthIsFast` contract (`:336`) | Missing. | TODO | TESTED |
| GVLI-048 | `IRenderedViewLine.resetCachedWidth` contract (`:337`) | Missing. | TODO | TESTED |
| GVLI-049 | `IRenderedViewLine.getVisibleRangesForRange` contract (`:338`) | Missing source-shaped abstraction. | TODO | TESTED |
| GVLI-050 | `Constants.MaxMonospaceDistance = 300` (`:342-351`) | Missing exact threshold. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-051 | FastRenderedViewLine `domNode` field (`:358`) | Missing fast class. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-052 | FastRenderedViewLine `input` field (`:359`) | Missing fast class. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-053 | FastRenderedViewLine `_characterMapping` (`:361`) | Missing fast class. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-054 | FastRenderedViewLine `_charWidth` (`:362,380`) | Source takes `RenderLineInput.spaceWidth`. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-055 | FastRenderedViewLine `_keyColumnPixelOffsetCache` (`:363,369-377`) | Missing. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-056 | FastRenderedViewLine `_cachedWidth = -1` (`:364`) | Missing sentinel cache. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-057 | FastRenderedViewLine constructor (`:366-381`) | Missing; member owns key-count arithmetic, sentinel fill loop, mapping retention, and spaceWidth character width. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-058 | key-column-cache allocation-vs-null branch (`:369–377`) | One `if/else`: positive key count allocates/fills the cache; zero retains null. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-059 | FastRenderedViewLine `getWidth` (`:383-393`) | Missing hybrid member; owns rounded mapped estimate, firstChild offsetWidth read, cache fill, and layout mark around counted branches. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-060 | no-DOM or shorter-than-300 branch (`:384-387`) | Estimate rounded mapped width without layout. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-061 | cached-width-miss branch (`:388-391`) | Read DOM once and mark context. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-062 | FastRenderedViewLine `getWidthIsFast` (`:395-397`) | Short line or populated cache. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-063 | FastRenderedViewLine `resetCachedWidth` (`:399-401`) | Restore `-1`. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-064 | FastRenderedViewLine `monospaceAssumptionsAreValid` (`:403-417`) | Missing zoom/measurement member; owns validation firstChild offsetWidth read and final global result around counted branches. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-065 | no-DOM global-fallback branch (`:404-406`) | Missing. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-066 | shorter-than-300 validation branch (`:407-415`) | Compare estimate to first-child width only for short lines. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-067 | absolute error at least `2` branch (`:410-414`) | Warn and permanently clear global assumption. | TODO | DEFERRED (browser zoom policy excluded by Phase 0) |
| GVLI-068 | `toSlowRenderedLine` (`:419-421`) | Missing strategy conversion. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-069 | FastRenderedViewLine `getVisibleRangesForRange` (`:423-427`) | Missing mapped-offset range. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-070 | `_getColumnPixelOffset` (`:429-455`) | Missing fast hybrid; member owns key ordinal/column arithmetic and actual-key plus mapped-delta result. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-071 | column at or below 300 branch (`:430-433`) | Use pure mapped horizontal offset. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-072 | key-column cache present branch (`:438-444`) | Missing. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-073 | key-column cache miss read/store branch (`:440-443`) | Missing. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-074 | unresolved key-column fallback (`:446-450`) | Return pure mapped estimate when DOM read is unavailable. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-075 | FastRenderedViewLine `_getReadingTarget` (`:457-459`) | First-child reading-target member; the DOM property read stays on this method row. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-076 | FastRenderedViewLine `_actualReadPixelOffset` (`:461-471`) | Missing member; maps the column to one collapsed RangeUtil query and returns its first left. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-077 | fast no-DOM early return `-1` (`:462-464`) | Missing. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-078 | fast null-or-empty range early return (`:467-469`) | Missing. | TODO | DEFERRED (fast rendered-line class absent) |
| GVLI-079 | RenderedViewLine `domNode` field (`:483`) | Local ViewLine owns cached DOM directly. | TODO | PORTED |
| GVLI-080 | RenderedViewLine `input` field (`:484`) | Existing `render_input`. | TODO | PORTED |
| GVLI-081 | RenderedViewLine `_characterMapping` (`:486`) | Existing `character_mapping`. | TODO | PORTED |
| GVLI-082 | RenderedViewLine `_isWhitespaceOnly` (`:487,500`) | Missing cached regex fact. | TODO | TESTED |
| GVLI-083 | RenderedViewLine `_containsForeignElements` (`:488,501`) | Local renderer output does not retain this fact. | TODO | TESTED |
| GVLI-084 | RenderedViewLine `_cachedWidth` (`:489,502,526-530`) | Missing; local rereads on every call. | TODO | TESTED |
| GVLI-085 | RenderedViewLine `_pixelOffsetCache` (`:494,504-510`) | Missing LTR per-column cache. | TODO | TESTED |
| GVLI-086 | RenderedViewLine constructor (`:496-511`) | Local flattened state lacks caches; member owns whitespace/foreign facts, `-1` width, null default, LTR cache size minimum 2, and sentinel fill. | TODO | TESTED |
| GVLI-087 | LTR pixel-cache allocation branch (`:505-510`) | Allocate only for LTR; RTL retains null. | TODO | TESTED |
| GVLI-088 | RenderedViewLine `_getReadingTarget` (`:515-517`) | Expose the slow first-child reading-target member; ordinary DOM property read stays here. | TODO | TESTED |
| GVLI-089 | RenderedViewLine `getWidth` (`:522-531`) | Existing direct width helper; add no-DOM/cache semantics and own the offsetWidth read/layout mark around counted branches. | TODO | TESTED |
| GVLI-090 | slow no-DOM early return `0` (`:523-525`) | Local FFI returns zero for no first child, not no rendered DOM state. | TODO | TESTED |
| GVLI-091 | slow cached-width-miss branch (`:526-529`) | Read once and mark DOM layout. | TODO | TESTED |
| GVLI-092 | RenderedViewLine `getWidthIsFast` (`:533-538`) | Missing; false until cached. | TODO | TESTED |
| GVLI-093 | uncached false branch (`:534-536`) | Missing. | TODO | TESTED |
| GVLI-094 | RenderedViewLine `resetCachedWidth` (`:540-547`) | Missing width and pixel-cache reset. | TODO | TESTED |
| GVLI-095 | nonnull pixel-cache clear branch (`:542-546`) | Fill every entry with `-1`. | TODO | TESTED |
| GVLI-096 | RenderedViewLine `getVisibleRangesForRange` (`:552-572`) | Missing strategy member; local FFI bypasses caches and source endpoint repairs. | TODO | TESTED |
| GVLI-097 | slow no-DOM null early return (`:553-555`) | Missing. | TODO | TESTED |
| GVLI-098 | LTR pixel-cache branch (`:556-569`) | One cache branch: LTR cache reads start/end and returns one range; null cache falls through to raw-range reading. | TODO | TESTED |
| GVLI-099 | start-offset `-1` early return (`:558-561`) | Missing. | TODO | TESTED |
| GVLI-100 | end-offset `-1` early return (`:563-566`) | Missing. | TODO | TESTED |
| GVLI-101 | `_readVisibleRangesForRange` (`:574-585`) | Missing collapsed-versus-range dispatch. | TODO | TESTED |
| GVLI-102 | collapsed-vs-noncollapsed range branch (`:575–584`) | One `if/else`: collapsed reads one pixel/zero width; noncollapsed delegates raw range. Failed collapsed pixel remains separate. | TODO | TESTED |
| GVLI-103 | collapsed pixel `-1` early return (`:577-579`) | Missing. | TODO | TESTED |
| GVLI-104 | `_readPixelOffset` (`:587-626`) | Missing foreign-element and LTR cache control flow. | TODO | TESTED |
| GVLI-105 | empty LTR mapping branch (`:588-610`) | Distinguish four foreign-element cases. | TODO | TESTED |
| GVLI-106 | empty line with no foreign element (`:590-593`) | Return zero. | TODO | TESTED |
| GVLI-107 | empty line with only after foreign element (`:594-597`) | Return zero. | TODO | TESTED |
| GVLI-108 | empty line with only before foreign element (`:598-601`) | Return measured full width. | TODO | TESTED |
| GVLI-109 | before-and-after `firstChild` presence branch (`:602-609`) | Before-and-after empty foreign-content branch reads/marks first-child width when present; otherwise returns zero. | TODO | TESTED |
| GVLI-110 | LTR pixel-cache branch (`:612-623`) | One LTR cache branch owns hit reuse and miss read/store; absence falls through to actual reading. | TODO | TESTED |
| GVLI-111 | cached pixel hit early return (`:615-618`) | Missing. | TODO | TESTED |
| GVLI-112 | RenderedViewLine `_actualReadPixelOffset` (`:628-658`) | Missing helper; it owns mapped collapsed RangeUtil reads and returns actual left unless the counted stabilization branch applies. | TODO | TESTED |
| GVLI-113 | empty mapping RangeUtil branch (`:629-636`) | Query collapsed zero endpoint instead of assuming zero. | TODO | TESTED |
| GVLI-114 | empty-mapping null/empty range early return (`:632-634`) | Missing. | TODO | TESTED |
| GVLI-115 | whitespace-only LTR final-column branch (`:638-641`) | Return measured width for CSS-sized whitespace lines. | TODO | TESTED |
| GVLI-116 | mapped null/empty range early return (`:646-648`) | Missing source nullable behavior. | TODO | TESTED |
| GVLI-117 | basic-ASCII stabilization branch (`:650-656`) | Prefer rounded expected monospace x only within one CSS pixel. | TODO | TESTED |
| GVLI-118 | expected-versus-actual tolerance `<= 1` (`:651-655`) | Preserve exact inclusive tolerance and rounding. | TODO | TESTED |
| GVLI-119 | `_readRawVisibleRangesForRange` (`:660-672`) | Missing member; owns mapped start/end DomPositions and common RangeUtil delegation around the whole-line branch. | TODO | TESTED |
| GVLI-120 | full LTR whole-line branch (`:662-666`) | Return `(0,getWidth)` without a DOM Range. | TODO | TESTED |
| GVLI-121 | WebKitRenderedViewLine override (`:682-706`) | Missing browser-specific correction. | TODO | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-122 | compound no-correction early return (`:686-688`) | Null/empty/collapsed/full-line ranges return unchanged. | TODO | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-123 | LTR-only correction branch (`:692-703`) | Missing. | TODO | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-124 | valid end-pixel branch (`:695-702`) | Missing. | TODO | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-125 | last-range-left-before-end trim branch (`:697-701`) | Set final width to end x minus left. | TODO | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-126 | module `createRenderedLine` function-valued constant (`:709–714`) | Retain the selected normal/WebKit factory; selector IIFE and platform branch are separate. | TODO | TESTED |
| GVLI-127 | `createRenderedLine` selector IIFE callback (`:709–714`) | Source-owned callback selects WebKit on its branch and otherwise returns the normal factory. | TODO | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-128 | WebKit factory-selection branch (`:710-712`) | Missing. | TODO | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-129 | `createWebKitRenderedLine` callback (`:716-718`) | Missing. | TODO | DEFERRED (WebKit branch outside fixed Chromium fixture) |
| GVLI-130 | `createNormalRenderedLine` callback (`:720-722`) | Missing explicit factory; target may remain a MoonBit-owned representation if behavior is exact. | TODO | TESTED |
| GVLI-131 | fast-constructor prior-DOM reuse ternary (`:215`) | Reuse the prior DOM wrapper for the fast constructor when present; otherwise pass null. | TODO | TESTED |
| GVLI-132 | slow-constructor prior-DOM reuse ternary (`:223`) | Reuse the prior DOM wrapper for the slow constructor when present; otherwise pass null. | TODO | TESTED |
| GVLI-133 | experimental whitespace selection branch (`:119`) | Source uses configured whitespace only when experimental rendering is `off`; absent local option constant-folds this branch. | TODO | DEFERRED (experimental whitespace option absent) |

GVLI denominator: **133**.

#### Denominator and proposed disposition

```text
GVL    52 = 50 TESTED + 1 PORTED + 1 DEFERRED
GVLI  133 = 75 TESTED + 5 PORTED + 52 DEFERRED + 1 N-A
GDRC   16 = 15 TESTED + 1 PORTED
GRU    25 = 25 TESTED
GVLO   16 = 13 TESTED + 2 DEFERRED + 1 N-A
       ---
Total 242 = 178 TESTED + 7 PORTED + 55 DEFERRED + 2 N-A
Working status: 242 TODO
```

N-A is limited to the JS-only product's native-platform impossibility and the reviewed CSS/root-owned theme seam. Experimental whitespace, GPU, fast-renderer, zoom-policy, and WebKit gaps remain DEFERRED.

#### Normalization record

- GDRC removed draft `008–011`; `readClientRect` owns its straight-line DOM reads. Result: `20 - 4 = 16`.
- GRU removed draft `004,006,008,009,010,015,018,021,022,028,029,037,038`; merged the two adjacency arms and removed the GRC-owned comparator callsite. Result: `38 - 13 = 25`.
- GVLO removed draft `016/017`; field rows own their arithmetic. Experimental/GPU fields changed N-A→DEFERRED. Result: `18 - 2 = 16`.
- GVL removed draft `007,010,014,015,016,017,018,052`; frozen handoffs stay outside the denominator and schedule/cancel is one branch. Result: `60 - 8 = 52`.
- GVLI removed draft `004,009,012,060,064,070,093,097,107,111,118,121,138,143`; added the two selector IIFE callbacks, the omitted ViewLine constructor, and split the two prior-DOM ternaries. GPU/experimental rows changed N-A→DEFERRED. Result: `143 - 14 + 4 = 133`.

#### Current local mapping and exact gaps

1. Local DomReadingContext already has all **six** retained fields—two nodes plus four mutable cache/layout facts—and source-shaped lazy scale/delta logic. It still needs branch tests and shared Range/width consumption.
2. Local selection measurement combines RangeUtil into one JS FFI plus MoonBit merge. It allocates a Range per call, has an extra `keep_empty` filter, queries `.view-line-content`, synthesizes element endpoints, never parks/reuses a Range, ignores DomReadingContext delta/scale, maps null to empty, and uses a `<= 1` merge guard where source's exactly-one return is reached only after a nonempty caller guard.
3. Local ViewLineOptions has 11 applicable facts. Typed theme remains CSS/root-owned; experimental whitespace and GPU fields/options are deferred. Browser FontInfo is not yet the complete source for every width.
4. Local ViewLine flattens rendered state into one slow strategy. It lacks width and pixel caches, truncation wrappers, foreign-element empty-line branches, fast strategy, WebKit correction, and both source-shaped prior-DOM strategy seams.
5. Local ViewLines has resting spot and direct unrendered width guard, but lacks width scheduler/sweeps, ViewLayout feedback, LastRenderedData, cache resets, and multi-line visible-range queries. Frozen width rows are handoffs, not duplicate source rows.
6. Local HorizontalPosition and direct View caret/range helpers bypass source ViewLine/RangeUtil cache and guard structure, so they cannot close this ledger alone.

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
| renderer strategy | no DOM; slow class; fast class deferred; content length 299/300/301; cache hit/miss; both prior-DOM reuse ternaries; variable-font flag; foreign elements | ViewLine white-box and browser |
| visible ranges | collapsed/noncollapsed; LTR/RTL; empty mapping; whitespace-only; basic ASCII tolerance at 1 and above 1; truncation before/at/after stop column | ViewLine and RangeUtil browser suite |
| foreign content | None, Before, After, and BeforeAndAfter on an empty line; first child present/absent; generated fold ellipsis | deterministic browser fixture |
| options/font facts | each applicable ViewLineOptions field independently changed; equality no-op; monospace disabled; halfwidth arrow; ligatures; vertical scrollbar; theme N-A plus experimental/GPU DEFERRED options | option-flow white-box plus fixed fonts |
| platform | Chromium gating; js-native N-A; GPU, WebKit, and browser-zoom rows remain explicit deferred outcomes | ledger review; no unsupported PASS |

#### Inventory review stop gate

- [x] Source hashes and line counts match the pinned oracle.
- [x] Prefix IDs are contiguous/unique and five-column row counts are 52/133/16/25/16.
- [x] All 242 working statuses are TODO and proposed totals are 178/7/55/2.
- [x] Frozen handoffs and excluded sibling clusters are stated without duplicate ownership.
- [ ] Independent Gate B approves the normalized denominator and boundary decisions.

STOP FOR REVIEW. Do not implement until this inventory is integrated documentation-only and independently approved.

### Group B — ContentWidgets and RenderingContext

#### Uniform atom rule

One row represents one declared member, field/property, behavior-changing branch or early return, independently material source-owned callback or control-flow magic constant, or owned DOM/CSS fact. A field owns its literal/arithmetic. Ordinary allocation, straight-line statements, intermediate arithmetic, loop mechanics, and final returns remain on their owning member row.

Every working status is `TODO`. Proposed terminals are review targets only. The fixed normalized denominator is 174 rows: GCW 120 + GRC 54.

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

Both files were read completely at the pinned commit. GCW closes the geometry-owned container/mount, validation, anchor, measurement/cache, placement, focus, callback, write, and carrier clusters. GRC closes the widget-consumed restricted facts, DOM/GPU query facade, and range/position carriers.

#### GCW ledger — `contentWidgets.ts`

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| GCW-001 | `ViewContentWidgets._viewDomNode` (`:27,35`) | Retain the editor root used as the page-space reference box; local `ContentWidgets.view_dom_node`. | TODO | TESTED |
| GCW-002 | `ViewContentWidgets.domNode` (`:30,38–43`) | Normal, content-space widget container; local `ContentWidgets.dom_node`. | TODO | TESTED |
| GCW-003 | `overflowingContentWidgetsDomNode` (`:31,44–47`) | Editor-root/page-space overflow container; local overflowing container. | TODO | TESTED |
| GCW-004 | `ViewContentWidgets` constructor (`:33–47`) | Preserve root assignment and DOM creation/write order; `_widgets` initialization is inherited CW-001. | TODO | TESTED |
| GCW-005 | `PartFingerprint.ContentWidgets` (`:39`) | Stamp the normal container with the exact fingerprint. | TODO | TESTED |
| GCW-006 | normal class `contentWidgets` (`:40`) | Preserve the owned class. | TODO | TESTED |
| GCW-007 | normal container `position:absolute` (`:41`) | Preserve the coordinate-space CSS property. | TODO | TESTED |
| GCW-008 | normal container `top:0` (`:42`) | Preserve the zero top origin. | TODO | TESTED |
| GCW-009 | `PartFingerprint.OverflowingContentWidgets` (`:45`) | Stamp the overflow container with the exact fingerprint. | TODO | TESTED |
| GCW-010 | overflow class `overflowingContentWidgets` (`:46`) | Preserve the owned class. | TODO | TESTED |
| GCW-011 | `addWidget` geometry subcluster (`:102–113`) | Own construction, map insertion, and dirtying; registration persistence is inherited and the following row alone owns the mount-container branch. | TODO | TESTED |
| GCW-012 | overflow mount branch (`:106–110`) | Append to overflow container iff the effective widget overflow flag is true, otherwise to normal container. | TODO | TESTED |
| GCW-013 | outer `setWidgetPosition` (`:115–122`) | Look up by `getId`, delegate all anchors/preferences/affinity, then apply its render scheduling gate. | TODO | TESTED |
| GCW-014 | `!useDisplayNone` scheduling branch (`:119–121`) | Source suppresses explicit dirtying for widgets that own their display state; local contract has no `useDisplayNone` capability. | TODO | TESTED |
| GCW-015 | outer `onBeforeRender` (`:145–150`) | Visit every retained widget in key order before the read phase. | TODO | TESTED |
| GCW-016 | outer `prepareRender` (`:152–157`) | Visit every retained widget and compute render data. | TODO | TESTED |
| GCW-017 | outer `render` (`:159–164`) | Visit every retained widget in the write phase. | TODO | TESTED |
| GCW-018 | `IBoxLayoutResult.fitsAbove` (`:168`) | Retain the above-fit decision. | TODO | PORTED |
| GCW-019 | `IBoxLayoutResult.aboveTop` (`:169`) | Retain the above coordinate. | TODO | PORTED |
| GCW-020 | `IBoxLayoutResult.fitsBelow` (`:171`) | Retain the below-fit decision. | TODO | PORTED |
| GCW-021 | `IBoxLayoutResult.belowTop` (`:172`) | Retain the below coordinate. | TODO | PORTED |
| GCW-022 | `IBoxLayoutResult.left` (`:174`) | Retain the clamped horizontal coordinate. | TODO | PORTED |
| GCW-023 | off-viewport `kind='offViewport'` (`:178`) | Closed render-data discriminator. | TODO | PORTED |
| GCW-024 | off-viewport `preserveFocus` (`:179`) | Carry the active-descendant probe into the write phase. | TODO | TESTED |
| GCW-025 | in-viewport `kind='inViewport'` (`:183`) | Closed render-data discriminator. | TODO | PORTED |
| GCW-026 | in-viewport `coordinate` (`:184`) | Carry exact top/left. | TODO | PORTED |
| GCW-027 | in-viewport `position` (`:185`) | Carry the selected ABOVE/BELOW/EXACT preference to `afterRender`; local render data drops it. | TODO | TESTED |
| GCW-028 | `IRenderData` union (`:188`) | Preserve exactly the in-viewport/off-viewport union; nullable outer state belongs only to `_renderData`. | TODO | PORTED |
| GCW-029 | `Widget._viewDomNode` (`:192,218`) | Per-widget page reference; local passes the retained outer root into prepare. | TODO | TESTED |
| GCW-030 | `Widget._actual` (`:193,219`) | Retain the public widget for callbacks, flags, and DOM. | TODO | PORTED |
| GCW-031 | `Widget.domNode` (`:195,225`) | Cache the exact owner-provided node. | TODO | TESTED |
| GCW-032 | `Widget.id` (`:196,226,246`) | Cache exact `getId()` and use it for `widgetId`. | TODO | TESTED |
| GCW-033 | `Widget.allowEditorOverflow` (`:197,227,243,287,481,516,579`) | Cache the optional widget flag with false default, then gate it by `allowOverflow`; the effective flag controls mount, coordinates, max width, placement, and writes. | TODO | TESTED |
| GCW-034 | `Widget._fixedOverflowWidgets` (`:200,231,243,385`) | Source option changes fixed positioning and absolute page coordinates; local Viewer has no option. | TODO | DEFERRED (fixedOverflowWidgets option seam not exposed) |
| GCW-035 | `Widget._preference` (`:207,236,295,448,489`) | Retain nullable ordered preferences, initialized to `[]`; local currently collapses null into a non-null array. | TODO | TESTED |
| GCW-036 | `_cachedDomNodeOffsetWidth` (`:208,237,305,461,468,478`) | Initialize/reset the width cache to exact sentinel `-1`; it participates independently in the OR cache-miss gate. | TODO | TESTED |
| GCW-037 | `_cachedDomNodeOffsetHeight` (`:209,238,306,461,469`) | Initialize/reset the height cache to exact sentinel `-1`; it participates independently in the OR cache-miss gate. | TODO | TESTED |
| GCW-038 | `_isVisible` (`:211,240,559,561,587,590`) | Initialize false; sticky last-write state gates visibility and marker mutations. | TODO | TESTED |
| GCW-039 | `_renderData` (`:213,241,553,557–595`) | Retain one nullable prepared result, initialized null, for the write phase. | TODO | TESTED |
| GCW-040 | `useDisplayNone` (`:214,229,296`) | Cache the optional owner flag with false default; it controls display writes and outer scheduling. | TODO | TESTED |
| GCW-041 | `Widget` constructor (`:216–248`) | Preserve option reads, field initialization, then DOM writes in source order. | TODO | TESTED |
| GCW-042 | editor `allowOverflow` gate (`:223,227`) | Effective overflow also requires the editor option; local constant-folds this gate true. | TODO | DEFERRED (allowOverflow option seam not exposed) |
| GCW-043 | fixed-vs-absolute position branch (`:243`) | `fixed` only for fixed+overflow; otherwise `absolute`. | TODO | DEFERRED (fixedOverflowWidgets option seam not exposed) |
| GCW-044 | initial `display:none` (`:244`) | Keep an unpositioned widget out of layout. | TODO | TESTED |
| GCW-045 | initial `visibility:hidden` (`:245`) | Keep initial content invisible while mounted. | TODO | TESTED |
| GCW-046 | `widgetId` attribute (`:246`) | Write the exact hit-test attribute/value. | TODO | TESTED |
| GCW-047 | constructor max-width write (`:247`) | Apply the cached maximum once at construction. | TODO | TESTED |
| GCW-048 | `_setPosition` (`:264–281`) | Retain affinity, then run one method-local validation/conversion helper for primary and secondary in order; ordinary validation and affinity forwarding stay on this member row. | TODO | TESTED |
| GCW-049 | null-position early return (`:269–272`) | Produce `(null,null)` without validation/conversion. | TODO | TESTED |
| GCW-050 | model-visible branch (`:275–278`) | Convert only visible validated model positions; retain the caller's original model position alongside the view result. | TODO | TESTED |
| GCW-051 | `_getMaxWidth` document/window reads (`:283–290`) | Read the widget owner document/window, select overflow fallback chain versus `_contentWidth`, and return the chosen maximum. | TODO | TESTED |
| GCW-052 | max-width overflow branch (`:287–289`) | Overflowing widgets use page/window width; normal widgets use `_contentWidth`. | TODO | TESTED |
| GCW-053 | overflow width fallback chain (`:288`) | Exact priority: `defaultView.innerWidth`, documentElement `offsetWidth`, body `offsetWidth`. Local uses only global `window.innerWidth`. | TODO | TESTED |
| GCW-054 | `Widget.setPosition` (`:293–307`) | Reproject anchors, assign nullable preference, apply the display gate, then reset both size caches to `-1`. | TODO | TESTED |
| GCW-055 | display measurement gate (`:296–304`) | Set block iff source owns display, primary view anchor exists, and preferences are non-null/nonempty; else none. | TODO | TESTED |
| GCW-056 | `_layoutBoxInViewport` (`:309–335`) | Compute vertical candidates and inclusive fit facts, apply right-then-left horizontal clamps, and return one layout carrier. | TODO | TESTED |
| GCW-057 | right-edge clamp first (`:326–329`) | If `left+width` exceeds `scrollLeft+viewportWidth`, move left to exact right containment. | TODO | TESTED |
| GCW-058 | left-edge clamp second (`:330–332`) | Then clamp to `scrollLeft`, including widgets wider than the viewport. | TODO | TESTED |
| GCW-059 | `_layoutHorizontalSegmentInPage` (`:337–363`) | Compute owner-window absolute left, preserve relative/absolute lockstep through both clamps, then return `[left, absoluteLeft]`; constants/branches remain separate rows. | TODO | TESTED |
| GCW-060 | `LEFT_PADDING = 15` (`:339`) | Exact left page clearance. | TODO | TESTED |
| GCW-061 | `RIGHT_PADDING = 15` (`:340`) | Exact right page clearance. | TODO | TESTED |
| GCW-062 | `MIN_LIMIT` (`:343`) | `max(15, editorLeft-width)`. | TODO | TESTED |
| GCW-063 | `MAX_LIMIT` (`:344`) | `min(editorLeft+editorWidth+width, windowWidth-15)`. | TODO | TESTED |
| GCW-064 | right-overflow delta branch (`:350–354`) | Shift both absolute and relative left by the same exact delta. | TODO | TESTED |
| GCW-065 | left-underflow delta branch (`:356–360`) | Apply the second exact delta to both coordinates. | TODO | TESTED |
| GCW-066 | `_layoutBoxInPage` (`:365–396`) | Compute page candidates from the owner node/window/client area, call the horizontal helper, derive fit facts, then return fixed or relative coordinates. | TODO | TESTED |
| GCW-067 | `TOP_PADDING = 22` (`:379`) | Exact top page clearance. | TODO | TESTED |
| GCW-068 | `BOTTOM_PADDING = 22` (`:380`) | Exact bottom page clearance. | TODO | TESTED |
| GCW-069 | fixed-overflow return (`:385–393`) | Use absolute left/below, clamp above to top padding, and preserve fit bits. | TODO | DEFERRED (fixedOverflowWidgets option seam not exposed) |
| GCW-070 | `_prepareRenderWidgetAtExactPositionOverflowing` (`:398–400`) | Shift exact overflow x by `_contentLeft`, leaving top unchanged. | TODO | TESTED |
| GCW-071 | `_getAnchorsCoordinates` (`:407–429`) | Compute primary first and only a same-line secondary through one method-local coordinate helper; ordinary visible-range/top/line-height queries stay on this member row. | TODO | TESTED |
| GCW-072 | same-line secondary gate (`:409–410`) | Discard a secondary on another line before querying DOM geometry. | TODO | TESTED |
| GCW-073 | coordinate null-position early return (`:413–416`) | No position yields no anchor without querying visible ranges. | TODO | TESTED |
| GCW-074 | missing visible-range early return (`:418–421`) | An unrendered/unmeasurable line yields no anchor. Local currently substitutes rendered-window plus uniform-column arithmetic. | TODO | TESTED |
| GCW-075 | left-of-injected-text column-one rule (`:423–424`) | Force left zero exactly for column 1 plus `LeftOfInjectedText`; otherwise use measured `HorizontalPosition.left`. | TODO | TESTED |
| GCW-076 | `_reduceAnchorCoordinates` (`:431–445`) | Declared member owns the fullwidth read, straight-line left arithmetic, and final anchor construction; early return and side branch remain separate. | TODO | TESTED |
| GCW-077 | `_reduceAnchorCoordinates` no-secondary branch (`:431–434`) | Return the primary object unchanged when secondary is absent. | TODO | TESTED |
| GCW-078 | secondary side-of-primary branch (`:438–443`) | Single side-of-primary branch: left uses `max(secondary, primary-width+fullwidth)`; right/equal uses `min(secondary, primary+width-fullwidth)`. | TODO | TESTED |
| GCW-079 | `_prepareRenderWidget` (`:447–534`) | Own anchor query order, rounded size acquisition, reduction, page/viewport placement, two-pass preference traversal, and ordinary final null; behavior branches remain separate. | TODO | TESTED |
| GCW-080 | absent/empty preference early return (`:448–450`) | Null or empty preference produces null render data before anchor work. | TODO | TESTED |
| GCW-081 | missing-primary off-viewport result (`:453–459`) | Return `offViewport` and probe whether the widget contains the owner document's active element. | TODO | TESTED |
| GCW-082 | size-cache OR gate (`:461`) | Measure when either width or height equals `-1`; one valid cache cannot mask the other invalid cache. | TODO | TESTED |
| GCW-083 | optional `beforeRender` callback branch (`:463–466`) | Call only when it is a function, with the widget as `this`, through `safeInvoke`; local trait omits it. | TODO | TESTED |
| GCW-084 | preferred-dimensions/DOM-fallback branch (`:467–475`) | One branch: non-null preferred dimensions supply width/height; otherwise measure the live rect and `Math.round` width/height independently. | TODO | TESTED |
| GCW-085 | page-versus-viewport placement (`:480–485`) | Overflow uses page layout; normal uses viewport layout. | TODO | TESTED |
| GCW-086 | ABOVE discriminator (`:491`) | Handle ABOVE before BELOW/EXACT. | TODO | TESTED |
| GCW-087 | ABOVE null-placement early return (`:492–495`) | Return null if page placement is null. Both scoped layout helpers are non-null at this pin. | TODO | N-A (source-unreachable with pinned layout helpers) |
| GCW-088 | ABOVE fit/pass branch (`:496–502`) | Return above on first pass only when fitting, or unconditionally on pass two. | TODO | TESTED |
| GCW-089 | BELOW discriminator (`:503`) | Handle BELOW after ABOVE. | TODO | TESTED |
| GCW-090 | BELOW null-placement early return (`:504–507`) | Return null if page placement is null. Both scoped layout helpers are non-null at this pin. | TODO | N-A (source-unreachable with pinned layout helpers) |
| GCW-091 | BELOW fit/pass branch (`:508–514`) | Return below on first pass only when fitting, or unconditionally on pass two. | TODO | TESTED |
| GCW-092 | EXACT overflow-vs-normal branch (`:515–528`) | One exact-position branch: overflow shifts x by `_contentLeft`; normal returns anchor top/left unchanged. | TODO | TESTED |
| GCW-093 | `Widget.onBeforeRender` (`:539–550`) | Apply cached max width only for a positionable widget whose anchor line is inside the inclusive rendered viewport; final write stays on this member row. | TODO | TESTED |
| GCW-094 | missing anchor/preference early return (`:540–542`) | Return before any DOM write. | TODO | TESTED |
| GCW-095 | inclusive viewport-line guard (`:544–547`) | Return when line is `< start` or `> end`; both endpoints are included. | TODO | TESTED |
| GCW-096 | `Widget.prepareRender` (`:552–554`) | Replace `_renderData` once with the complete prepare result. | TODO | TESTED |
| GCW-097 | `Widget.render` (`:556–596`) | Declared write-phase member owns hidden/visible ordering and callback timing; branches, early return, magic constant, and transitions remain separate. | TODO | TESTED |
| GCW-098 | `Widget.render` hidden discriminator (`:556–576`) | Null and offViewport share the invisible branch. | TODO | TESTED |
| GCW-099 | visible-to-hidden transition (`:559–562`) | Only a previously visible widget removes the marker and flips `_isVisible`. | TODO | TESTED |
| GCW-100 | preserve-focus-vs-hide branch (`:563–569`) | One focus branch: focused off-viewport widgets park at the magic top; all other hidden transitions write visibility hidden. | TODO | TESTED |
| GCW-101 | focus-preserving `top=-1000` (`:564–566`) | Exact parking constant; source deliberately leaves visibility inherited. Local `apply_style` incorrectly writes hidden. | TODO | TESTED |
| GCW-102 | hidden `afterRender` callback (`:572–574`) | If present, safely invoke with `(null,null)` even when already invisible. | TODO | TESTED |
| GCW-103 | hidden early return (`:575`) | Stop before visible coordinate writes. | TODO | TESTED |
| GCW-104 | visible overflow-vs-normal coordinate branch (`:579–585`) | One visible-coordinate branch: overflow writes prepared top/left; normal writes `top + scrollTop - bigNumbersDelta` and the same left. | TODO | TESTED |
| GCW-105 | hidden-to-visible transition (`:587–591`) | Only on transition set visibility inherit, marker=`true`, then `_isVisible=true`. | TODO | TESTED |
| GCW-106 | visible `afterRender` callback (`:593–595`) | Safely pass selected preference and exact rendered coordinate. | TODO | TESTED |
| GCW-107 | `PositionPair.modelPosition` (`:599–603`) | Immutable nullable original model anchor. | TODO | PORTED |
| GCW-108 | `PositionPair.viewPosition` (`:599–603`) | Immutable nullable projected view anchor. | TODO | PORTED |
| GCW-109 | `Coordinate._coordinateBrand` (`:606–607`) | TypeScript nominal brand only. | TODO | N-A (MoonBit nominal struct type) |
| GCW-110 | `Coordinate.top` (`:609–612`) | Immutable rendered top. | TODO | PORTED |
| GCW-111 | `Coordinate.left` (`:609–612`) | Immutable rendered left. | TODO | PORTED |
| GCW-112 | `AnchorCoordinate._anchorCoordinateBrand` (`:615–616`) | TypeScript nominal brand only. | TODO | N-A (MoonBit nominal struct type) |
| GCW-113 | `AnchorCoordinate.top` (`:618–622`) | Immutable viewport-relative top. | TODO | PORTED |
| GCW-114 | `AnchorCoordinate.left` (`:618–622`) | Immutable content-space left. | TODO | PORTED |
| GCW-115 | `AnchorCoordinate.height` (`:618–622`) | Immutable per-line height. | TODO | PORTED |
| GCW-116 | `safeInvoke` (`:625–632`) | Generic callback wrapper invokes with exact `thisArg`/arguments and returns the result; its catch branch returns null. | TODO | TESTED |
| GCW-117 | callback exception branch (`:629–631`) | Swallow any callback exception and return null. | TODO | TESTED |
| GCW-118 | `PositionPair` constructor (`:599–603`) | Assign model and view positions without conversion; field rows GCW-107/108 own the values. | TODO | PORTED |
| GCW-119 | `Coordinate` constructor (`:609–612`) | Assign top/left without rounding or coordinate-space conversion. | TODO | PORTED |
| GCW-120 | `AnchorCoordinate` constructor (`:618–622`) | Assign top/left/height without transformation. | TODO | PORTED |

GCW denominator: **120** rows.

#### GRC ledger — `renderingContext.ts`

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| GRC-001 | `IViewLines.linesVisibleRangesForRange` (`:12–14`) | Query complete per-line visible ranges with `includeNewLines`; local View exposes only one-line tuple measurements. | TODO | TESTED |
| GRC-002 | `IViewLines.visibleRangeForPosition` (`:14`) | Query a measured caret x or null; local `View::visible_range_for_position` is the existing producer but is not threaded into ContentWidgets. | TODO | TESTED |
| GRC-003 | `RestrictedRenderingContext` brand (`:17–18`) | TypeScript nominal brand only. | TODO | N-A (MoonBit nominal struct type) |
| GRC-004 | `bigNumbersDelta` (`:26,44`) | Widget normal-layer write consumes the exact viewport delta. | TODO | TESTED |
| GRC-005 | `scrollTop` (`:28,47`) | Widget anchor/read and normal write consume the same viewport top. | TODO | TESTED |
| GRC-006 | `scrollLeft` (`:29,48`) | Viewport/page horizontal placement consumes the exact left. | TODO | TESTED |
| GRC-007 | `viewportWidth` (`:31,49`) | Right-edge clamp input. | TODO | TESTED |
| GRC-008 | `viewportHeight` (`:32,50`) | Below-fit input. | TODO | TESTED |
| GRC-009 | `_viewLayout` (`:34,37,46,58,66`) | Retain one layout owner for viewport and per-line geometry queries. | TODO | PORTED |
| GRC-010 | restricted-context constructor (`:36–51`) | Snapshot all scoped fields in source order, using one `getCurrentViewport()` result for top/left/width/height; excluded base fields remain named siblings. | TODO | TESTED |
| GRC-011 | `getVerticalOffsetForLineNumber` (`:57–59`) | Delegate exact line and optional `includeViewZones` to ViewLayout. | TODO | TESTED |
| GRC-012 | `getLineHeightForLineNumber` (`:65–67`) | Delegate per-line height; local widget context currently supplies one global line height. | TODO | TESTED |
| GRC-013 | `RenderingContext` brand (`:75–76`) | TypeScript nominal brand only. | TODO | N-A (MoonBit nominal struct type) |
| GRC-014 | `RenderingContext._viewLines` (`:78,83`) | Retain the DOM view-lines query target. | TODO | PORTED |
| GRC-015 | optional `_viewLinesGpu` (`:79,84,89–103`) | Optional GPU query target; local renderer has no GPU ViewLines. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-016 | `RenderingContext` constructor (`:81–85`) | Call base first, then retain DOM and optional GPU targets. | TODO | PORTED |
| GRC-017 | `linesVisibleRangesForRange` (`:87–100`) | Own DOM-first query order, optional GPU query, DOM-before-GPU concat, and sorted final return; branch/callback atoms remain separate. | TODO | TESTED |
| GRC-018 | no-GPU early return (`:89–91`) | Return DOM result, including null, without another query. | TODO | TESTED |
| GRC-019 | DOM-null GPU return (`:93–95`) | GPU-only result wins when DOM has no ranges. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-020 | GPU-null DOM return (`:96–98`) | DOM-only result wins when GPU has no ranges. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-021 | `visibleRangeForPosition` (`:102–104`) | Own the exact DOM → optional GPU → null expression; the two nullish behavior gates remain separate rows. | TODO | TESTED |
| GRC-022 | DOM position wins (`:103`) | First nullish gate: a non-null DOM result wins; otherwise evaluate the GPU fallback. | TODO | TESTED |
| GRC-023 | GPU position fallback (`:103`) | Second nullish gate: a non-null GPU result wins; otherwise return null. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |
| GRC-024 | `LineVisibleRanges.firstLine` (`:111–122`) | Return the smallest line number independent of input order; an empty array naturally returns null on this member row. | TODO | TESTED |
| GRC-025 | firstLine null-array early return (`:112–114`) | Null input returns null. | TODO | TESTED |
| GRC-026 | firstLine replacement predicate (`:116–120`) | Replace when result is unset or current line number is strictly smaller; ties keep the first. | TODO | TESTED |
| GRC-027 | `LineVisibleRanges.lastLine` (`:127–138`) | Return the largest line number independent of input order; an empty array naturally returns null on this member row. | TODO | TESTED |
| GRC-028 | lastLine null-array early return (`:128–130`) | Null input returns null. | TODO | TESTED |
| GRC-029 | lastLine replacement predicate (`:132–136`) | Replace when unset or strictly larger; ties keep the first. | TODO | TESTED |
| GRC-030 | `LineVisibleRanges.outsideRenderedLine` (`:140–148`) | Carry whether measurement extends outside rendered content. | TODO | TESTED |
| GRC-031 | `LineVisibleRanges.lineNumber` (`:140–148`) | Carry the one-based view line. | TODO | PORTED |
| GRC-032 | `LineVisibleRanges.ranges` (`:140–148`) | Carry ordered rounded horizontal ranges. | TODO | PORTED |
| GRC-033 | `continuesOnNextLine` (`:144–148`) | Carry whether the requested range continues beyond this line. | TODO | TESTED |
| GRC-034 | `LineVisibleRanges` constructor (`:140–148`) | Assign all four immutable fields without transformation. | TODO | PORTED |
| GRC-035 | `HorizontalRange` brand (`:151–152`) | TypeScript nominal brand only. | TODO | N-A (MoonBit nominal struct type) |
| GRC-036 | `HorizontalRange.left` (`:154,166–168`) | Field owns exact JavaScript `Math.round(left)` semantics. | TODO | TESTED |
| GRC-037 | `HorizontalRange.width` (`:155,166–168`) | Field owns independent exact JavaScript `Math.round(width)` semantics. | TODO | TESTED |
| GRC-038 | `HorizontalRange.from` (`:157–164`) | Convert every float range in input order; this member owns exact output length, allocation, indexed loop, and per-index construction. | TODO | TESTED |
| GRC-039 | `HorizontalRange` constructor (`:166–169`) | Construct in field order; left and width fields own their independent rounding arithmetic. | TODO | TESTED |
| GRC-040 | `HorizontalRange.toString` (`:171–173`) | Exact format `[left,width]`. | TODO | TESTED |
| GRC-041 | `FloatHorizontalRange` brand (`:176–177`) | TypeScript nominal brand only. | TODO | N-A (MoonBit nominal struct type) |
| GRC-042 | `FloatHorizontalRange.left` (`:179,182–184`) | Preserve fractional left unchanged. | TODO | PORTED |
| GRC-043 | `FloatHorizontalRange.width` (`:180,182–184`) | Preserve fractional width unchanged. | TODO | PORTED |
| GRC-044 | `FloatHorizontalRange` constructor (`:182–185`) | Assign both values without rounding. | TODO | PORTED |
| GRC-045 | `FloatHorizontalRange.toString` (`:187–189`) | Exact format `[left,width]` with source number formatting. | TODO | TESTED |
| GRC-046 | `FloatHorizontalRange.compare` (`:191–193`) | Comparator is exact `a.left - b.left`. | TODO | TESTED |
| GRC-047 | `HorizontalPosition.outsideRenderedLine` (`:196–205`) | Carry source outside-rendered-line result; existing local producer constant-folds false. | TODO | TESTED |
| GRC-048 | `HorizontalPosition.left` (`:201,207`) | Rounded caret x; field owns the exact dependency `Math.round(originalLeft)`. | TODO | TESTED |
| GRC-049 | `HorizontalPosition.originalLeft` (`:202,206`) | Preserve the unrounded measurement. | TODO | TESTED |
| GRC-050 | `HorizontalPosition` constructor (`:204–208`) | Store outside flag and original first, then initialize rounded left from `originalLeft`; field row owns the arithmetic. | TODO | TESTED |
| GRC-051 | `VisibleRanges.outsideRenderedLine` (`:211–216`) | Carry aggregate outside-rendered state. | TODO | PORTED |
| GRC-052 | `VisibleRanges.ranges` (`:211–216`) | Carry float ranges without rounding. | TODO | PORTED |
| GRC-053 | `VisibleRanges` constructor (`:212–216`) | Assign both immutable fields without transformation. | TODO | PORTED |
| GRC-054 | DOM+GPU sort comparator callback (`:99`) | Source-owned callback returns exact `a.lineNumber - b.lineNumber`; no secondary key. | TODO | DEFERRED (GPU ViewLines excluded by Phase 0) |

GRC denominator: **54** rows.

#### Mechanical denominator and proposed disposition

```text
GCW 120 = 92 TESTED + 20 PORTED + 4 DEFERRED + 4 N-A
GRC  54 = 33 TESTED + 12 PORTED + 5 DEFERRED + 4 N-A
Total 174 = 125 TESTED + 32 PORTED + 9 DEFERRED + 8 N-A
Working status at Gate A: 174 TODO
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
| page clamp | editor near each page edge, scrolled page, widget wider than editor, 15px exact side boundaries, 22px exact top/bottom boundaries | fixed-size Chromium fixture |
| overflow modes | widget overflow false/true; source editor allowOverflow true/false; fixedOverflowWidgets false/true | false/true widget browser; unsupported editor/fixed axes stay explicit DEFERRED |
| visibility/focus | initially hidden; visible→null; visible→offViewport focused/unfocused; already hidden; re-entry to visible | browser focus/attribute/style assertions |
| display ownership | useDisplayNone false/true × positionable/unpositionable × dirty scheduling | widget integration test |
| range source | DOM null/non-null; GPU absent; documented GPU combinations null/non-null; DOM wins position query | query white-box; GPU rows DEFERRED |
| line-range aggregation | null, empty, singleton, unsorted, duplicate line numbers; first/last strict tie behavior | carrier white-box |
| numeric carriers | integer/fractional/half/negative left and width; conversion preserves array order/length; exact string forms and comparator | carrier white-box |
| render order | outer key order; onBeforeRender → prepareRender → render; hidden callback before return; visible coordinate writes before callback | instrumented white-box/browser |

#### Current local gaps and masking

1. `ContentWidgetsRenderContext` still supplies one `char_width`, and anchors use `(column - 1) * char_width` instead of the existing measured `View::visible_range_for_position`; tabs, fullwidth, proportional, combining, injected, and generated content can drift.
2. The local context supplies one global `line_height`; source queries the anchor line. Variable/custom height is excluded, but the query seam and exact line argument must still be preserved.
3. Validation and hidden-line rejection exist, but `ContentWidgetPosition` has no affinity; frozen CW-007 therefore remains an active geometry handoff.
4. The local trait has no `useDisplayNone`, `beforeRender`, or `afterRender`; preferred dimensions, rendered-coordinate callbacks, safe exception isolation, and source display scheduling are absent.
5. DOM fallback caches fractional width/height; source independently applies `Math.round`.
6. Focus parking is defective: local sets `is_visible=false` and `apply_style` rewrites `visibility:hidden` after `top=-1000`, while source leaves visibility inherited.
7. Local render rewrites position/display/visibility/top/left on every frame. Source gates hidden and visible visibility/marker writes on `_isVisible`; no-op DOM-write behavior is absent separately from the focus bug.
8. Overflow max width uses global `window.innerWidth` and lacks owner-document documentElement/body fallbacks.
9. Page placement is not owner-window scoped: local page-position and clamp helpers read global `@rdom.window()` scroll values; source uses `_viewDomNode.ownerDocument.defaultView`.
10. `fixedOverflowWidgets` and editor `allowOverflow` are absent. Their source fields/branches are DEFERRED, not N-A.
11. Local render data drops the selected preference and concrete coordinate, so it cannot satisfy `afterRender(position, coordinate)`.
12. Local `rendering_context.mbt` has only `HorizontalPosition`; it lacks `IViewLines`, the DOM-first facade, `LineVisibleRanges`, rounded/float range carriers, first/last helpers, and `VisibleRanges`.
13. Existing `View::visible_range_for_position` constant-folds `outside_rendered_line=false`; Group A must establish reachability and port or justify the seam.
14. Local preference is a non-null array, collapsing source `null` and `[]`; `allow_editor_overflow` is required instead of optional-default-false.
15. Local `prepare_render_widgets` folds source onBefore max-width writes into prepare/read work; tests must observe source onBefore → prepare → render ordering.
16. Fingerprints and normal-container `position:absolute; top:0` behavior exist locally via the View constructor/CSS rather than constructor writes. Record that as a reviewed ownership/runtime seam, not a missing behavior or duplicate row.

#### Review stop gate

- [x] 120 GCW + 54 GRC active IDs are contiguous and unique.
- [x] All 174 working statuses remain TODO and proposed terminals sum to 174.
- [x] Ownership exclusions and current local gaps are preserved in the owning plan.
- [ ] Independent Gate B approves the normalized denominator and proposed seams.

No product or test edit is authorized before that approval.

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

#### Five-column inventory and parity ledger

Every actual status is `TODO`. The merged behavior/local-target column records
the source transition and current seam; Proposed terminal is the Gate B review
target, not implementation evidence.

##### GVLay — `viewLayout.ts`

| ID | Source atom | Behavior / local target | Status | Proposed terminal |
|---|---|---|---|---|
| GVLay-001 | `EditorScrollDimensions.width` (`:21,30,35,40-42,54`) | Signed-32-bit-coerce viewport width, clamp below zero, retain it. Local: `EditorScrollDimensions.width`; local truncates and clamps but does not reproduce JavaScript signed-32-bit wrap for extreme inputs. | TODO | TESTED |
| GVLay-002 | `contentWidth` (`:22,31,36,43-45,55`) | Signed-32-bit-coerce content width, clamp below zero, retain it independently of viewport width. Local: `content_width`; ordinary geometry matches, extreme signed-32-bit wrap does not. | TODO | TESTED |
| GVLay-003 | `scrollWidth` (`:23,56`) | `max(width, contentWidth)`. Local: `scroll_width`; local matches. | TODO | TESTED |
| GVLay-004 | `height` (`:25,32,37,47-49,58`) | Signed-32-bit-coerce viewport height, clamp below zero, retain it. Local: `height`; ordinary geometry matches, extreme signed-32-bit wrap does not. | TODO | TESTED |
| GVLay-005 | `contentHeight` (`:26,33,38,50-52,59`) | Signed-32-bit-coerce content height, clamp below zero, retain it independently. Local: `content_height`; ordinary geometry matches, extreme signed-32-bit wrap does not. | TODO | TESTED |
| GVLay-006 | `scrollHeight` (`:27,60`) | `max(height, contentHeight)`. Local: `scroll_height`; local matches. | TODO | TESTED |
| GVLay-007 | `EditorScrollDimensions` constructor (`:29-61`) | Normalize all four primary dimensions, then derive two scroll dimensions. Local: `EditorScrollDimensions::new`. | TODO | TESTED |
| GVLay-008 | width negative branch (`:40-42`) | Strict `< 0` becomes `0`; zero stays zero. Local: Covered structurally by `max(0)`, needs boundary test. | TODO | TESTED |
| GVLay-009 | content-width negative branch (`:43-45`) | Strict `< 0` becomes `0`. Local: Local structural equivalent, needs boundary test. | TODO | TESTED |
| GVLay-010 | height negative branch (`:47-49`) | Strict `< 0` becomes `0`. Local: Local structural equivalent, needs boundary test. | TODO | TESTED |
| GVLay-011 | content-height negative branch (`:50-52`) | Strict `< 0` becomes `0`. Local: Local structural equivalent, needs boundary test. | TODO | TESTED |
| GVLay-012 | `EditorScrollDimensions.equals` (`:63-70`) | Compare width/contentWidth/height/contentHeight; derived scroll values add no identity axis. Local: Local derived `Eq` also compares derived fields; observationally redundant, needs equivalence evidence. | TODO | TESTED |
| GVLay-013 | `EditorScrollable._scrollable` (`:75,86-91,118-123`) | Own underlying integer Scrollable and receive its scroll event. Local: `EditorScrollable.scrollable`. | TODO | PORTED |
| GVLay-014 | `_dimensions` (`:76,85,106-116`) | Retain normalized editor dimensions, initially all zero. Local: `editor_dimensions`; local matches. | TODO | TESTED |
| GVLay-015 | `_onDidContentSizeChange` (`:80,127-131`) | Private emitter fires only for content dimensions. Local: `content_size_emitter`; local matches. | TODO | PORTED |
| GVLay-016 | `onDidContentSizeChange` (`:81`) | Public event alias. Local: `EditorScrollable::on_did_content_size_change`. | TODO | PORTED |
| GVLay-017 | dimensional constructor slice (`:83-92`) | Initialize zero dimensions; underlying Scrollable forces integer values and uses supplied scheduler. Local: `EditorScrollable::new(force_integer_values=true, ...)`. | TODO | TESTED |
| GVLay-018 | `getScrollDimensions` (`:106-108`) | Return retained editor dimensions. Local: `editor_dimensions()`. | TODO | TESTED |
| GVLay-019 | `EditorScrollable.setScrollDimensions` (`:110-133`) | Atomically retain old dimensions, assign the new identity, and pass width/scrollWidth/height/scrollHeight to the underlying Scrollable with `useRawScrollPositions=true`; content-event branching remains owned by GVLay-025. Local: `set_editor_dimensions` preserves the same order and four-axis write. | TODO | TESTED |
| GVLay-020 | equal-dimensions early return (`:111-113`) | No underlying write and no content event when identity is unchanged. Local: Local returns `None`; needs no-write/no-event test. | TODO | TESTED |
| GVLay-021 | content-size change branch and payload (`:125-131`) | Compare old/new content width and height, fire for width-only, height-only or both, remain silent for neither, and preserve old width/height before new width/height in the payload. Local: the emitter branch and payload match; require all four combinations. | TODO | TESTED |
| GVLay-022 | `ViewLayout._configuration` (`:158,170`) | Live option source for every geometry calculation. Local: Local `ViewLayout` has no configuration reader; options are reduced to external setters. | TODO | DEFERRED (local ViewLayout has no live IEditorConfiguration owner) |
| GVLay-023 | `_linesLayout` (`:159,175,266,331`) | Own total line height and whitespace minimum width inputs. Local: Local `lines`; total height exists, whitespace-min-width feed is absent. | TODO | PORTED |
| GVLay-024 | `_maxLineWidth` (`:160,176,315,336-338`) | Retain measured widest line, initialized `0`. Local: Missing: local stores externally supplied generic `content_width`. | TODO | TESTED |
| GVLay-025 | `_overlayWidgetsMinWidth` (`:161,177,332,341-343`) | Retain overlay minimum width, initialized `0`. Local: Missing local field/setter. | TODO | DEFERRED (overlay-widget minimum-width state and caller are absent) |
| GVLay-026 | `_scrollable` (`:163,179-189`) | Own normalized editor dimensions and content-size event. Local: Local `scrollable`; matches role. | TODO | PORTED |
| GVLay-027 | `onDidContentSizeChange` alias (`:165,189`) | Forward EditorScrollable content-size event. Local: `ViewLayout::on_did_content_size_change`. | TODO | PORTED |
| GVLay-028 | `ViewLayout` constructor geometry cluster (`:167-192`) | Read layoutInfo and padding, construct LinesLayout from lineCount/lineHeight/top/bottom padding, initialize max-line and overlay minima to zero, seed EditorScrollDimensions as `(contentWidth,0,height,0)`, wire events, then `_updateHeight`. Local: constructor defers viewport size to a later setter and hard-codes zero padding. | TODO | DEFERRED (editor padding and initial layout-info constructor seams are absent) |
| GVLay-029 | `onHeightMaybeChanged` (`:199-201`) | Delegate exactly once to `_updateHeight`. Local: `on_height_maybe_changed`. | TODO | TESTED |
| GVLay-030 | `onConfigurationChanged` dimension orchestration (`:209-236`) | Update line/padding inputs, then choose layoutInfo recompute or height-only recompute. Local: Local uses separate setters; no typed single event route. | TODO | DEFERRED (local configuration delivery is split across setter APIs) |
| GVLay-031 | line-height branch (`:211-213`) | Update LinesLayout default height before dimension recomputation. Local: `set_line_height`; local adds equality early return. | TODO | TESTED |
| GVLay-032 | padding branch (`:214-217`) | Update top/bottom padding before recomputation. Local: Missing: local exposes no padding option. | TODO | DEFERRED (editor padding option seam is absent) |
| GVLay-033 | layoutInfo branch (`:218-229`) | Use new viewport width/height, reuse the retained content width unchanged, and recompute content height against the new box. Local: `set_viewport_size` reuses content width but still lacks the source content-height formula. | TODO | TESTED |
| GVLay-034 | no-layoutInfo branch (`:230-232`) | `_updateHeight()` after any non-layout configuration change. Local: Local setters call `sync_dimensions`; no generic branch. | TODO | TESTED |
| GVLay-035 | `_getHorizontalScrollbarHeight` (`:249-261`) | After the Hidden and no-overflow early returns, return configured `horizontalScrollbarSize`. Local: the complete method/formula is absent. | TODO | TESTED |
| GVLay-036 | horizontal hidden branch (`:252-255`) | Explicit `Hidden` returns `0`, regardless of overflow. Local: Missing option and branch. | TODO | N-A (no horizontal-scrollbar visibility option axis) |
| GVLay-037 | no-overflow branch (`:256-259`) | `width >= scrollWidth` returns `0`; equality is non-visible. Local: Missing branch. | TODO | TESTED |
| GVLay-038 | `_getContentHeight` (`:263-274`) | Initialize from `LinesLayout.getLinesTotalHeight()` and add exactly one bottom extension selected by the following branches. Local: only the base LinesLayout total is currently returned. | TODO | TESTED |
| GVLay-039 | scroll-beyond-last-line branch (`:267-269`) | When enabled, add `max(0, height - lineHeight - padding.bottom)`. Local: the option and nonnegative remainder formula are absent. | TODO | DEFERRED (scrollBeyondLastLine option and bottom-extent formula are absent) |
| GVLay-040 | horizontal-scrollbar content-height branch (`:269-271`) | When scrollBeyondLastLine is false, add scrollbar height iff `ignoreHorizontalScrollbarInContentHeight` is false; the true outcome adds nothing. Local: this option/branch is absent. | TODO | DEFERRED (ignoreHorizontalScrollbarInContentHeight option seam is absent) |
| GVLay-041 | `_updateHeight` (`:276-287`) | Preserve current width/contentWidth/height; replace contentHeight via `_getContentHeight`. Local: Local `sync_dimensions` structurally preserves box but uses base-only height. | TODO | TESTED |
| GVLay-042 | `_computeContentWidth` (`:313-334`) | Source of horizontal content extent from measured max plus options/minima. Local: Entire computation missing locally. | TODO | TESTED |
| GVLay-043 | viewport-wrapping branch (`:319-329`) | For wrapping, apply the nested overflow/minimap exception and otherwise return `maxLineWidth` as the branch final result. Local: final width is externally supplied rather than computed from max line width. | TODO | TESTED |
| GVLay-044 | wrapped overflow threshold (`:321`) | Strict `maxLineWidth > contentWidth + typicalHalfwidthCharacterWidth`. Local: Missing; equality must stay on non-overflow path. | TODO | TESTED |
| GVLay-045 | right-minimap adjustment (`:323-326`) | If minimap enabled and on right, return `maxLineWidth + verticalScrollbarWidth`. Local: Minimap out of product scope; explicit N-A/deferred decision required, branch cannot disappear. | TODO | N-A (no minimap ViewPart or minimap-side axis) |
| GVLay-046 | no-wrap branch/outcome (`:329-333`) | Compute extra space as scrollBeyondLastColumn times typical-halfwidth, read whitespace minimum width, then return the maximum of measured-line-plus-extra-plus-vertical-scrollbar, whitespace minimum, and overlay minimum. Local: the complete formula and whitespace-min-width handoff are absent. | TODO | DEFERRED (LinesLayout whitespace-min-width handoff depends on ViewZones) |
| GVLay-047 | `setMaxLineWidth` (`:336-339`) | Assign without clamping, then immediately `_updateContentWidth`. Local: Missing API; local `set_content_width` writes final width instead. | TODO | TESTED |
| GVLay-048 | `setOverlayWidgetsMinWidth` (`:341-344`) | Assign without clamping, then immediately `_updateContentWidth`. Local: Missing API/field. | TODO | DEFERRED (overlay-widget minimum-width state and caller are absent) |
| GVLay-049 | `_updateContentWidth` (`:346-357`) | Preserve viewport width/height/contentHeight, replace contentWidth with `_computeContentWidth`, then always `_updateHeight` because horizontal scrollbar visibility can change bottom extent. Local: sync_dimensions writes an externally supplied final width and lacks the width-to-height feedback. | TODO | TESTED |
| GVLay-050 | `getContentWidth` (`:441-444`) | Return retained content width, not clamped scroll width. Local: Local matches getter. | TODO | TESTED |
| GVLay-051 | `getScrollWidth` (`:445-448`) | Return `max(viewport, content)` derived scroll width. Local: Local matches getter. | TODO | TESTED |
| GVLay-052 | `getContentHeight` (`:449-452`) | Return retained content height. Local: Local has no direct getter on EditorScrollable and recomputes base LinesLayout height; behavior diverges when bottom extension exists. | TODO | TESTED |
| GVLay-053 | `getScrollHeight` (`:453-456`) | Return `max(viewport, content)` derived scroll height. Local: Local matches getter after its incomplete height input. | TODO | TESTED |

##### GVR — `viewLineRenderer.ts`

| ID | Source atom | Behavior / local target | Status | Proposed terminal |
|---|---|---|---|---|
| GVR-001 | `IRenderLineInputOptions.useMonospaceOptimizations` (`:26`) | Caller supplies whether width-aggregation optimizations are safe. Local: `RenderLineInput.use_monospace_optimizations`. | TODO | PORTED |
| GVR-002 | `canUseHalfwidthRightwardsArrow` (`:27`) | Caller supplies measured arrow compatibility. Local: Local field matches. | TODO | PORTED |
| GVR-003 | `spaceWidth` (`:37`) | Measured ordinary-space width in CSS px. Local: Local field matches. | TODO | PORTED |
| GVR-004 | `middotWidth` (`:38`) | Measured U+00B7 width. Local: Local field matches. | TODO | PORTED |
| GVR-005 | `wsmiddotWidth` (`:39`) | Measured U+2E31 width. Local: Local field matches. | TODO | PORTED |
| GVR-006 | `RenderLineInput.useMonospaceOptimizations` (`:52,88,111`) | Retain the caller fact. Local: Local matches Equality compares this declared field. Local behavior remains as described. | TODO | PORTED |
| GVR-007 | `canUseHalfwidthRightwardsArrow` (`:53,89,112`) | Retain arrow compatibility. Local: Local matches Equality compares this declared field. Local behavior remains as described. | TODO | PORTED |
| GVR-008 | `spaceWidth` (`:63,99,122`) | Retain measured space width. Local: Local matches Equality compares this declared field. Local behavior remains as described. | TODO | PORTED |
| GVR-009 | `renderSpaceWidth` (`:64,142-149`) | Derived width of the whitespace glyph closest to a space. Local: Local recomputes via `derive_render_space` instead of retaining this field Equality compares this normalized derived field rather than both raw candidates. Local behavior remains as described. | TODO | PORTED |
| GVR-010 | `renderSpaceCharCode` (`:65,142-149`) | Retain chosen middle-dot code point. Local: Local resolved input retains chosen code Equality compares this normalized derived glyph. Local behavior remains as described. | TODO | PORTED |
| GVR-011 | font-sensitive `RenderLineInput` constructor slice (`:87-151`) | Assign the scoped inputs, compute absolute wsmiddot-space and middot-space differences, then select one derived render-space width/glyph. Local: raw candidate widths are retained and the same derivation runs at render time. | TODO | TESTED |
| GVR-012 | render-space glyph-selection branch (`:142-150`) | Use U+2E31 only when its width difference is strictly smaller; the equal/greater else outcome uses U+00B7. Local: strict-less and tie behavior match. | TODO | TESTED |
| GVR-013 | magic glyph constant U+2E31 (`:146`) | Independently selected WORD SEPARATOR MIDDLE DOT code point `0x2E31`. Local: exact constant is retained. Your tests must distinguish it from U+00B7. | TODO | TESTED |
| GVR-014 | magic glyph constant U+00B7 (`:149`) | Independently selected MIDDLE DOT code point `0xB7`, including the tie outcome. Local: exact constant is retained. | TODO | TESTED |
| GVR-015 | `RenderLineInput.equals` (`:175-200`) | Compare the complete normalized render identity, including the five scoped fields; raw middot/wsmiddot candidates are intentionally omitted once their derived width/glyph agree. Local derived Eq compares raw candidates and can harmlessly over-invalidate; source-shaped identity or zero-write proof is required. | TODO | TESTED |
| GVR-016 | `ResolvedRenderLineInput.fontIsMonospace` (`:444`) | Resolved fact receives `useMonospaceOptimizations`. Local: Local `font_is_monospace`; matches source naming reduction. | TODO | PORTED |
| GVR-017 | resolved arrow fact (`:445`) | Forward arrow compatibility into final writer. Local: Local matches. | TODO | PORTED |
| GVR-018 | resolved space width (`:455`) | Forward CSS-pixel width into whitespace style arithmetic. Local: Local matches. | TODO | PORTED |
| GVR-019 | resolved render-space char (`:456`) | Forward chosen glyph. Local: Local matches. | TODO | PORTED |
| GVR-020 | declared `ResolvedRenderLineInput` constructor (`:442-462`) | Own the straight projection assignments for all resolved fields. Local: the MoonBit private struct literal provides the same projection boundary. | TODO | PORTED |
| GVR-021 | `resolveRenderLineInput` font projection (`:517-532`) | Project useMono, arrow, spaceWidth, chosen glyph in fixed order. Local: Local projects equivalent facts; derives glyph immediately before projection. | TODO | TESTED |
| GVR-022 | `_applyRenderWhitespace` font-sensitive cluster (`:752-913`) | Own the local monospace copy, initial `startVisibleColumn % tabSize`, both modulo resets, glyph-width splitting, proportional indent split and tab/fullwidth column transitions. Local method mirrors the control flow. | TODO | TESTED |
| GVR-023 | per-whitespace-part gate (`:762`) | `renderSpaceWidth !== spaceWidth`. Local: Local recomputes chosen width then compares. | TODO | TESTED |
| GVR-024 | proportional-indent split (`:843-844`) | Split when leaving whitespace or when `!useMono && tmpIndent >= tabSize`. Local: Local matches both conditions. | TODO | TESTED |
| GVR-025 | tab indent transition (`:863-864`) | Tab sets temporary indent to exactly `tabSize`. Local: Local matches. | TODO | TESTED |
| GVR-026 | reused fullwidth visible-column constant (`:865-866,1140-1143`) | Both whitespace splitting and final rendering assign exactly two visible columns to a fullwidth code unit. Local uses the same predicate and constant. | TODO | TESTED |
| GVR-027 | ordinary indent transition (`:867-868`) | Other code unit adds exactly `1`. Local: Local matches. | TODO | TESTED |
| GVR-028 | `_renderLine` font-sensitive cluster (`:979-1198`) | Own extraction of monospace, arrow, space-width and render-glyph facts before the part loop, then emit scoped HTML/CSS and mapping writes. Local `render_line` mirrors the broad structure. | TODO | TESTED |
| GVR-029 | `partRendersWhitespaceWithWidth` (`:1014-1016`) | Whitespace + non-monospace + (`mtkw` or no foreign elements). Local: Local condition matches. | TODO | TESTED |
| GVR-030 | width-bearing class (`:1024`) | Use class `mtkz` when explicit width is written. Local: Local matches DOM class. | TODO | TESTED |
| GVR-031 | whitespace-part tab width (`:1034-1041`) | Tab width is `tabSize - visibleColumn % tabSize`; non-tab width is `1`; faux indent does not advance visible column. Local: Local probe loop matches. | TODO | TESTED |
| GVR-032 | explicit CSS width DOM write (`:1044-1048`) | Write `style="width:<spaceWidth * partWidth>px"`. Local: Local writes same property/product. | TODO | TESTED |
| GVR-033 | rendered-whitespace tab width (`:1059-1062`) | Produced characters and horizontal width equal remaining tab stop. Local: Local matches. | TODO | TESTED |
| GVR-034 | arrow choice branch (`:1063-1067`) | Use regular arrow when halfwidth is unsafe or tab width > 1; only one-column safe tabs use halfwidth arrow. Local: Local matches. | TODO | TESTED |
| GVR-035 | regular arrow constant (`:1064`) | U+2192. Local: Local `ch_rightwards_arrow`. | TODO | TESTED |
| GVR-036 | halfwidth arrow constant (`:1066`) | U+FFEB. Local: Local `ch_halfwidth_rightwards_arrow`. | TODO | TESTED |
| GVR-037 | tab fill (`:1068-1070`) | Append NBSP for positions `2..charWidth`; a one-column tab adds none. Local: Local loop matches. | TODO | TESTED |
| GVR-038 | rendered-space geometry (`:1072-1078`) | One source space maps to two DOM chars, width one column, chosen dot plus U+200C. Local: Local matches constants and counts. | TODO | TESTED |
| GVR-039 | horizontal-offset accumulation (`:1080-1084`) | Add logical char width; advance visible column only after faux indent. Local: Local matches. | TODO | TESTED |
| GVR-040 | ordinary tab expansion (`:1099-1105`) | Non-whitespace-render path emits `tabSize - visibleColumn % tabSize` NBSPs. Local: Local matches. | TODO | TESTED |
| GVR-041 | mapping stores column units (`:1052,1092,1161-1165,1177,1187`) | `CharacterMapping` horizontal offsets are visible columns, not measured CSS pixels. Local: Local matches; widget geometry must use DOM Range rather than multiply this by one width. | TODO | TESTED |

##### GFI — `fontInfo.ts`

| ID | Source atom | Behavior / local target | Status | Proposed terminal |
|---|---|---|---|---|
| GFI-001 | `GOLDEN_LINE_HEIGHT_RATIO` (`:14`) | macOS `1.5`, all other platforms `1.35`. Local: `golden_line_height_ratio`; local matches. | TODO | TESTED |
| GFI-002 | `MINIMUM_LINE_HEIGHT` (`:19`) | Constant `8`. Local: `minimum_line_height`; local matches. | TODO | PORTED |
| GFI-003 | `BareFontInfo._bareFontInfoBrand` (`:29`) | Nominal type-only brand, no runtime behavior. Local: N-A candidate: MoonBit concrete type needs no brand. | TODO | N-A (MoonBit concrete types need no nominal BareFontInfo brand) |
| GFI-004 | `BareFontInfo._create` (`:34-72`) | Normalize line height (including `Math.round`), editor zoom and variation settings, then construct canonical identity. Local `BareFontInfo::create` matches except for the fixed-away zoom axis and numeric parse detail. | TODO | TESTED |
| GFI-005 | zero line-height branch (`:35-36`) | `lineHeight = goldenRatio * fontSize`. Local: Local matches. | TODO | TESTED |
| GFI-006 | em line-height branch (`:37-40`) | Nonzero value `< 8` multiplies font size. Local: Local matches. | TODO | TESTED |
| GFI-007 | line-height minimum (`:44-46`) | Clamp rounded value below `8` to `8`. Local: Local matches. | TODO | TESTED |
| GFI-008 | editor zoom multiplier branch (`:48-50`) | Compute `1 + (ignoreEditorZoom ? 0 : zoomLevel * 0.1)` and multiply both fontSize and lineHeight by it. Local: readonly Viewer has no editor zoom axis. | TODO | N-A (readonly Viewer has no editor zoom axis) |
| GFI-009 | variation translate gate (`:52`) | Only `fontVariationSettings === 'translate'` enters translation. Local: Local matches. | TODO | TESTED |
| GFI-010 | normal/bold variation branch (`:53-55`) | Translate to `normal` variation without changing weight. Local: Local matches. | TODO | TESTED |
| GFI-011 | numeric-weight variation branch (`:56-59`) | `parseInt(weight,10)`, emit `'wght' N`, normalize weight to `normal`. Local: Local concatenates raw weight; malformed/noncanonical numeric strings may diverge and need test/validation ownership. | TODO | TESTED |
| GFI-012 | `BareFontInfo.pixelRatio` (`:74,87,96`) | Canonical measurement/cache input. Local: Local field matches. | TODO | PORTED |
| GFI-013 | `fontFamily` (`:75,88,97`) | Canonical family coerced through `String`. Local: Local typed String needs no coercion. | TODO | PORTED |
| GFI-014 | `fontWeight` (`:76,89,98`) | Canonical weight coerced through `String`. Local: Local typed String. | TODO | PORTED |
| GFI-015 | `fontSize` (`:77,90,99`) | Canonical CSS-pixel size. Local: Local field matches. | TODO | PORTED |
| GFI-016 | `fontFeatureSettings` (`:78,91,100`) | Controls DOM style and initial monospace eligibility. Local: Local matches. | TODO | PORTED |
| GFI-017 | `fontVariationSettings` (`:79,92,101`) | Controls DOM variation style. Local: Local matches. | TODO | PORTED |
| GFI-018 | `lineHeight` (`:80,93,102`) | Retained as integer via bitwise-OR zero. Local: Local Int field matches after construction. | TODO | PORTED |
| GFI-019 | `letterSpacing` (`:81,94,103`) | DOM measurement/render style input. Local: Local matches. | TODO | PORTED |
| GFI-020 | protected constructor (`:86-104`) | Assign eight canonical bare fields. Local: Flattened into local struct construction. | TODO | PORTED |
| GFI-021 | `getId` (`:109-111`) | Hyphen-join all eight bare axes in fixed order. Local: `BareFontInfo::get_id`; local matches. | TODO | TESTED |
| GFI-022 | `getMassagedFontFamily` (`:116-123`) | Obtain the platform fallback and quote the configured family; the following branch owns conditional fallback append. Local method has the same role. | TODO | TESTED |
| GFI-023 | fallback-family append branch (`:119-121`) | Append `, <fallback>` only when the fallback is nonempty and differs from the configured family. Local: current code checks only difference; its platform fallback is always nonempty, so the empty-fallback source boundary needs a direct test or literal guard. | TODO | TESTED |
| GFI-024 | declared `BareFontInfo._wrapInQuotes` (`:125-135`) | Own family quoting orchestration and the plain-family final return; two behavior branches remain separate below. Local: `wrap_in_quotes` mirrors the member. | TODO | TESTED |
| GFI-025 | `_wrapInQuotes` escaped branch (`:125-129`) | Family containing comma or quote is returned unchanged. Local: Local matches. | TODO | TESTED |
| GFI-026 | `_wrapInQuotes` plus/space branch (`:130-133`) | Wrap in double quotes. Local: Local matches. | TODO | TESTED |
| GFI-027 | `SERIALIZED_FONT_INFO_VERSION` (`:138-139`) | Constant `2`, bumped whenever fields change. Local: Persistence absent locally; explicit N-A candidate. | TODO | N-A (font-info persistence channel is absent) |
| GFI-028 | `FontInfo._editorStylingBrand` (`:142`) | Nominal type-only brand. Local: N-A candidate. | TODO | N-A (MoonBit concrete types need no nominal FontInfo brand) |
| GFI-029 | `version` (`:144`) | Every FontInfo reports serialization version `2`. Local: Local FontInfo omits version with persistence channel. | TODO | N-A (font-info persistence channel is absent) |
| GFI-030 | `isTrusted` (`:145,175,177`) | Distinguish live reliable measurements from restored/fallback readings. Local: `is_trusted`; local matches. | TODO | PORTED |
| GFI-031 | `isMonospace` (`:146,167,178`) | Measured optimization fact. Local: `is_monospace`; local matches. | TODO | PORTED |
| GFI-032 | `typicalHalfwidthCharacterWidth` (`:147,168,179`) | Measured typical halfwidth advance. Local: Local matches. | TODO | PORTED |
| GFI-033 | `typicalFullwidthCharacterWidth` (`:148,169,180`) | Measured typical fullwidth advance. Local: Local matches. | TODO | PORTED |
| GFI-034 | `canUseHalfwidthRightwardsArrow` (`:149,170,181`) | Measured glyph-safety fact. Local: Local matches. | TODO | PORTED |
| GFI-035 | `spaceWidth` (`:150,171,182`) | Measured U+0020 width. Local: Local matches. | TODO | PORTED |
| GFI-036 | `middotWidth` (`:151,172,183`) | Measured U+00B7 width. Local: Local matches. | TODO | PORTED |
| GFI-037 | `wsmiddotWidth` (`:152,173,184`) | Measured U+2E31 width. Local: Local matches. | TODO | PORTED |
| GFI-038 | `maxDigitWidth` (`:153,174,185`) | Maximum measured width of `0..9`. Local: Local matches. | TODO | PORTED |
| GFI-039 | `FontInfo` constructor (`:158-186`) | Call Bare constructor, assign trust and eight measured facts. Local: Local flat struct returned by measurement; all fields exist. | TODO | PORTED |
| GFI-040 | `FontInfo.equals` (`:191-208`) | Compare family, weight, size, feature, variation, line height, letter spacing, typical half/full widths, arrow capability, space/middot/wsmiddot and max digit; intentionally omit pixelRatio, isTrusted and isMonospace. Local equality matches the exact included/omitted axes. | TODO | TESTED |
| GFI-041 | `FONT_VARIATION_OFF` (`:213`) | Constant `normal`. Local: Local matches. | TODO | PORTED |
| GFI-042 | `FONT_VARIATION_TRANSLATE` (`:217`) | Constant `translate`. Local: Local matches. | TODO | PORTED |
| GFI-043 | `DEFAULT_WINDOWS_FONT_FAMILY` (`:222`) | Declared Consolas/Courier New/monospace Windows stack. Local: exact string is embedded in editor defaults. | TODO | PORTED |
| GFI-044 | `DEFAULT_MAC_FONT_FAMILY` (`:226`) | Declared Menlo/Monaco/Courier New/monospace macOS stack. Local: exact string is embedded in editor defaults. | TODO | PORTED |
| GFI-045 | `DEFAULT_LINUX_FONT_FAMILY` (`:230`) | Declared Droid Sans Mono/monospace Linux-other stack. Local: exact string is embedded in editor defaults. | TODO | PORTED |
| GFI-046 | declared `EDITOR_FONT_DEFAULTS` object (`:234-244`) | Own the five default properties and their platform selections; the following rows retain each property/branch fact. Local: `editor_font_defaults` is the corresponding object. | TODO | PORTED |
| GFI-047 | `EDITOR_FONT_DEFAULTS.fontFamily` (`:234-237`) | macOS / Windows / other platform selection. Local: Local matches platform branches. | TODO | TESTED |
| GFI-048 | default weight (`:238`) | `normal`. Local: Local matches. | TODO | PORTED |
| GFI-049 | default size (`:239-241`) | macOS `12`, other platforms `14`. Local: Local matches. | TODO | TESTED |
| GFI-050 | default line height (`:242`) | `0`, later normalized by `_create`. Local: Local matches. | TODO | PORTED |
| GFI-051 | default letter spacing (`:243`) | `0`. Local: Local matches. | TODO | PORTED |

##### GFM — `fontMeasurements.ts`

| ID | Source atom | Behavior / local target | Status | Proposed terminal |
|---|---|---|---|---|
| GFM-001 | `ISerializedFontInfo.version` (`:18`) | Persist schema version. Local: Serialization absent; explicit N-A candidate. | TODO | N-A (font-info persistence channel is absent) |
| GFM-002 | serialized `pixelRatio` (`:19`) | Persist source-window ratio. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-003 | serialized `fontFamily` (`:20`) | Persist family. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-004 | serialized `fontWeight` (`:21`) | Persist weight. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-005 | serialized `fontSize` (`:22`) | Persist size. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-006 | serialized `fontFeatureSettings` (`:23`) | Persist features. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-007 | serialized `fontVariationSettings` (`:24`) | Persist variations. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-008 | serialized `lineHeight` (`:25`) | Persist line height. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-009 | serialized `letterSpacing` (`:26`) | Persist spacing. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-010 | serialized `isMonospace` (`:27`) | Persist measured fact. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-011 | serialized typical halfwidth (`:28`) | Persist measured width. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-012 | serialized typical fullwidth (`:29`) | Persist measured width. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-013 | serialized halfwidth-arrow capability (`:30`) | Persist measured fact. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-014 | serialized space width (`:31`) | Persist measured width. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-015 | serialized middot width (`:32`) | Persist measured width. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-016 | serialized word-separator-middot width (`:33`) | Persist measured width. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-017 | serialized max digit width (`:34`) | Persist measured width. Local: Serialization absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-018 | `FontMeasurementsImpl._cache` (`:39`) | Per-window cache keyed by `getWindowId`. Local: Local reduces to one cache; multi-window candidate N-A/deferred must be reviewed. | TODO | N-A (single-window Viewer has no per-window cache map) |
| GFM-019 | `_evictUntrustedReadingsTimeout` (`:41,47-50,76-81`) | `-1` sentinel means no pending retry. Local: Local Bool pending flag; equivalent single-window state. | TODO | PORTED |
| GFM-020 | `_onDidChange` (`:43`) | Registered emitter lifetime. Local: Local emitter exists but FontMeasurementsImpl has no dispose. | TODO | PORTED |
| GFM-021 | `onDidChange` (`:44`) | Public event alias. Local: Local listener API matches. | TODO | PORTED |
| GFM-022 | `dispose` (`:46-52`) | Cancel pending timeout, reset sentinel, dispose registered resources. Local: Missing local disposal/cancellation handle. | TODO | N-A (process-lifetime singleton has no disposal owner) |
| GFM-023 | dispose timeout branch (`:47-50`) | Only clear/reset when sentinel is not `-1`. Local: Missing; local `set_timeout` result is discarded. | TODO | N-A (process-lifetime singleton has no disposal owner) |
| GFM-024 | `clearAllFontInfos` (`:57-60`) | Clear every window cache then fire change. Local: Local clears single cache and fires. | TODO | TESTED |
| GFM-025 | `_ensureCache` (`:62-70`) | Resolve `windowId`; return existing or create/store a new cache. Local: Local single-window reduction has no method/branch. | TODO | N-A (single-window Viewer has no per-window cache lookup) |
| GFM-026 | missing-window cache branch (`:65-68`) | Allocate exactly once per window. Local: Single-window N-A/deferred candidate. | TODO | N-A (single-window Viewer has no per-window cache lookup) |
| GFM-027 | `_writeToCache` (`:72-83`) | Put measured identity, then maybe schedule one untrusted retry. Local: Local `write_to_cache`; matches single-window behavior. | TODO | TESTED |
| GFM-028 | untrusted/no-timer gate (`:76`) | Schedule iff `!isTrusted && timeout === -1`. Local: Local `!is_trusted && !pending`; matches. | TODO | TESTED |
| GFM-029 | untrusted-reading retry delay (`:81`) | Independently reused timing constant `5000ms`. Local: exact delay is passed to the global timer. | TODO | TESTED |
| GFM-030 | source-owned untrusted-reading timer callback (`:78-81`) | Reset the pending-timeout sentinel before calling `_evictUntrustedReadings(targetWindow)`. Local: callback resets the Bool before single-window eviction; ordering needs a fake-timer test. | TODO | TESTED |
| GFM-031 | `_evictUntrustedReadings` (`:85-98`) | Inspect one window cache, remove every untrusted value, conditionally fire. Local: Local matches over single cache. | TODO | TESTED |
| GFM-032 | untrusted removal branch (`:89-93`) | Trusted retained; untrusted removed and `somethingRemoved=true`. Local: Local matches. | TODO | TESTED |
| GFM-033 | eviction event gate (`:95-97`) | Fire only if at least one value was removed. Local: Local matches. | TODO | TESTED |
| GFM-034 | `serializeFontInfo` (`:103-107`) | Return trusted cached values only. Local: Missing persistence channel; explicit N-A candidate. | TODO | N-A (font-info persistence channel is absent) |
| GFM-035 | source-owned trusted-value filter callback (`:106`) | `item => item.isTrusted` admits only trusted values during serialization. Local: serialization is absent, so the callback has no local owner. | TODO | N-A (font-info persistence channel is absent) |
| GFM-036 | `restoreFontInfo` (`:112-123`) | Iterate saved records, skip mismatched versions, construct accepted FontInfo as untrusted and pass it as both cache key/value. Local: persistence restore channel is absent. | TODO | N-A (font-info persistence channel is absent) |
| GFM-037 | version-mismatch continue (`:116-119`) | Any version other than current is skipped. Local: Missing. | TODO | N-A (font-info persistence channel is absent) |
| GFM-038 | `readFontInfo` (`:128-158`) | Return cache hit; on miss measure, apply the counted suspicious fallback, mark fallback untrusted, cache under the original Bare identity and return the cached reading. Local single-window method matches that orchestration. | TODO | TESTED |
| GFM-039 | cache-miss branch (`:130-156`) | `_actualReadFontInfo` runs only on miss. Local: Local match. | TODO | TESTED |
| GFM-040 | suspicious-reading fallback branch (`:133-153`) | Enter when any of typical-half, typical-full, space or max-digit is `<= 2`; copy unaffected style/isMonospace/arrow fields, re-read target PixelRatio and floor all six measured widths via the counted constant 5. Local: branch and trigger set match. | TODO | TESTED |
| GFM-041 | fallback pixel ratio (`:136`) | Re-read live target-window PixelRatio. Local: Local reads global `window.devicePixelRatio` or `1`. Multi-window reduction explicit. | TODO | TESTED |
| GFM-042 | fallback width-floor constant (`:145-151`) | Independently reused constant `5`, applied to typical half, typical full, space, middot, wsmiddot and max digit widths. Local: exact constant and six applications match. | TODO | TESTED |
| GFM-043 | `_createRequest` (`:160-165`) | Construct one request, always append to all, optionally append same object to monospace list. Local: Local `create_request`; matches. | TODO | TESTED |
| GFM-044 | optional monospace branch (`:163`) | `null` excludes request from monospace comparison. Local: Local `None` branch matches. | TODO | TESTED |
| GFM-045 | `_actualReadFontInfo` (`:167-245`) | Own both request arrays, reference-width setup, loop mechanics, initial arrow capability and the complete request/derive/output orchestration; only real branches/constants/callbacks remain separate. Local method is a close mirror. | TODO | TESTED |
| GFM-046 | typical halfwidth request (`:171`) | Regular `n`, in all and monospace. Local: Local exact. | TODO | TESTED |
| GFM-047 | typical fullwidth request (`:172`) | Regular U+FF4D, in all only. Local: Local exact. | TODO | TESTED |
| GFM-048 | space request (`:173`) | Regular U+0020, in all and monospace. Local: Local exact. | TODO | TESTED |
| GFM-049 | digit request corpus and maximum (`:174-183,205`) | Request Regular digits 0 through 9 in all+monospace and derive maxDigitWidth as their ten-way maximum. Local exact corpus and nonnegative loop are equivalent. | TODO | TESTED |
| GFM-050 | rightwards-arrow request (`:186`) | Regular U+2192, in all and monospace. Local: Local exact. | TODO | TESTED |
| GFM-051 | halfwidth-arrow request (`:187`) | Regular U+FFEB, in all only. Local: Local exact. | TODO | TESTED |
| GFM-052 | middot request (`:190`) | Regular U+00B7, in all and monospace. Local: Local exact. | TODO | TESTED |
| GFM-053 | word-separator-middot request (`:193`) | Regular U+2E31, in all only. Local: Local exact. | TODO | TESTED |
| GFM-054 | monospace test characters (`:196`) | Exact eight-character corpus: vertical bar, slash, hyphen, underscore, `i`, `l`, `m`, percent. Local: Local exact eight-element array. | TODO | TESTED |
| GFM-055 | monospace style matrix (`:197-201`) | For every test char request Regular, Italic, and Bold, all in both lists. Local: Local exact. | TODO | TESTED |
| GFM-056 | `readCharWidths` call (`:203`) | One DOM measurement pass receives target window, Bare style, and full request array. Local: Local calls Rabbita DOM reader with Bare style; single global document. | TODO | TESTED |
| GFM-057 | initial monospace gate (`:207`) | Only ligatures-off font settings are eligible. Local: Local exact constant comparison. | TODO | TESTED |
| GFM-058 | monospace tolerance (`:210-214`) | Difference outside inclusive `[-0.001, 0.001]` sets false and breaks. Local: Local exact strict comparisons; break occurs on next loop guard instead of same block, observationally equivalent. | TODO | TESTED |
| GFM-059 | monospace arrow-width gate (`:218-221`) | If monospace and halfwidth arrow is not exactly reference width, disable it. Local: Local exact. | TODO | TESTED |
| GFM-060 | oversized halfwidth-arrow gate (`:222-225`) | If halfwidth arrow is wider than regular arrow, disable regardless of monospace. Local: Local exact. | TODO | TESTED |
| GFM-061 | output `FontInfo` construction (`:227-244`) | Copy Bare family/weight/size/features/variations/lineHeight/letterSpacing; write derived isMonospace, typical half/full widths, arrow capability, space, middot, wsmiddot and max digit; use the distinct target PixelRatio fact and construct trusted=true. Local record mapping contains every field in the same order. | TODO | TESTED |
| GFM-062 | output PixelRatio (`:228`) | Use target-window live PixelRatio, not Bare input ratio. Local: Local global device ratio; multi-window gap. | TODO | TESTED |
| GFM-063 | `FontMeasurementsCache._keys` (`:250,254`) | Null-prototype id-to-Bare map for enumeration. Local: Local ordered `cache_keys` array; single-window cache reduction. | TODO | N-A (local cache is folded into FontMeasurementsImpl) |
| GFM-064 | `_values` (`:251,255`) | Null-prototype id-to-FontInfo map. Local: Local `Map[String, FontInfo]`. | TODO | N-A (local cache is folded into FontMeasurementsImpl) |
| GFM-065 | cache constructor (`:253-256`) | Create both null-prototype maps. Local: Local singleton literal initializes array/map. | TODO | N-A (local cache is folded into FontMeasurementsImpl) |
| GFM-066 | cache `has` (`:258-261`) | Boolean value lookup by `item.getId()`. Local: Local `Map.contains` within write and direct `get` in read. | TODO | TESTED |
| GFM-067 | cache `get` (`:263-266`) | Return value by Bare id. Local: Local `Map.get`. | TODO | TESTED |
| GFM-068 | cache `put` (`:268-272`) | Store both original Bare key and FontInfo value. Local: Local stores id/value and separately tracks id, not Bare object. Sufficient for eviction; persistence enumeration differs. | TODO | TESTED |
| GFM-069 | cache `remove` (`:274-278`) | Delete both key and value by FontInfo id. Local: Local deletes value and rebuilds id list during eviction. | TODO | TESTED |
| GFM-070 | cache `getValues` (`:280-282`) | Enumerate keys then map to values. Local: Local iterates `cache_keys`; equivalent for eviction, serialization absent. | TODO | TESTED |
| GFM-071 | source-owned `getValues` map callback (`:281`) | `id => this._values[id]` converts enumerated cache keys to FontInfo values in key order. Local: iteration over cache_keys performs the same mapping; require ordering evidence. | TODO | TESTED |
| GFM-072 | `FontMeasurements` singleton (`:285`) | Export one process-wide `FontMeasurementsImpl`. Local: Local module singleton plus `font_measurements()` accessor. | TODO | PORTED |

#### Mechanical denominator

Corrected prefix and proposed-terminal counts from the accepted denominator review:

```text
Prefix:   GVLay 53 + GVR 41 + GFI 51 + GFM 72 = 217
Terminal: 118 TESTED + 54 PORTED + 9 DEFERRED + 36 N-A = 217
Raw reconciliation: 273 - 65 merged/removed + 9 added = 217
```

All 217 actual statuses remain `TODO`; Proposed terminal is a separate Gate B target. IDs are contiguous within each prefix and the corrected five-column denominator is fixed.

#### Behavior-variable matrix

The matrix below is keyed by source cluster rather than raw IDs; after the accepted merges it refers only to the contiguous corrected GVLay/GVR/GFI/GFM rows above.

| Cluster | Axes | Required cases / boundaries | Lowest useful evidence |
|---|---|---|---|
| dimension normalization | width, contentWidth, height, contentHeight | negative, zero, positive fractional, positive integer, signed-32-bit overflow boundary; content smaller/equal/larger than viewport | pure package test |
| content-size event | old/new content axes; viewport-only axes | neither, width-only, height-only, both; viewport-only must not fire | EditorScrollable white-box |
| horizontal scrollbar height | visibility, width vs contentWidth, configured size | Hidden; Auto/Visible with `width >`, `==`, `< contentWidth`; size zero/nonzero | ViewLayout package test |
| content height | scrollBeyondLastLine, ignoreHorizontalScrollbarInContentHeight, padding, lineHeight, overflow | beyond-last on/off; ignore on/off; remainder negative/zero/positive; horizontal scrollbar visible/absent | package + browser bottom-reach test |
| wrapped content width | wrapping, max width threshold, minimap enabled/side | no wrap; wrap at `<`, `==`, `>` `contentWidth + typicalHalfwidth`; minimap off/left/right | pure package test; minimap unsupported row explicit |
| unwrapped content width | maxLineWidth, scrollBeyondLastColumn, typical halfwidth, vertical scrollbar, whitespace min, overlay min | each candidate independently wins; ties; zero; max width shrinks/grows | pure package test |
| width-to-height feedback | content-width transition | no hscroll→hscroll and reverse; content-height event/scroll clamp follows | integration + browser |
| render-space choice | space, middot, wsmiddot widths | wsmiddot closer; middot closer; exact tie (middot); chosen width equal/different from space | renderer package test |
| whitespace width | mono fact, foreign elements, token class, tab stop | mono/proportional; foreign yes/no; `mtkw`/other; one-column and multi-column tabs | renderer HTML/reference test |
| arrow glyph | measured capability, tab width | unsafe/safe × width 1/>1; only safe+1 uses U+FFEB | renderer HTML test |
| column arithmetic | faux indent, start column, tab size, fullwidth | before/at/after faux indent; every tab residue; BMP fullwidth and ordinary; mapping end column | renderer mapping test |
| line-height normalization | raw height and platform | zero; `(0,8)` em; exactly 8; rounded below/above; mac/non-mac; zoom ignored/on | fontInfo package test |
| variation translation | setting and weight | off/non-translate; translate+normal; translate+bold; numeric weights including canonical validation boundary | fontInfo package test |
| family massage | punctuation and fallback identity | comma/double/single quote; plus; space; plain; same/different fallback | fontInfo package test |
| measurement cache | window/cache/trust | hit/miss; single vs multiple window; trusted/untrusted; clear; retry pending/not pending; dispose pending timer | browser/config white-box |
| suspicious measurements | half/full/space/digit widths | each trigger alone at `<2`, `==2`, `>2`; middot-only low is not trigger but is floored after another trigger; floor below/equal/above 5 | deterministic measurement seam test |
| monospace detection | ligatures and request widths | ligatures on/off; every request equal; diff exactly ±0.001; just outside both boundaries; early failure | deterministic request test |
| arrow measurement | mono and three widths | mono/nonmono; halfwidth equal/not reference; halfwidth `>`, `==`, `<` regular | deterministic request test |
| request corpus | char/type/subset | exact n/fullwidth/space/digits/arrows/dots; exact `|/-_ilm%` × Regular/Italic/Bold; all vs monospace membership | spy measurement seam test |
| live browser font | font readiness/platform | committed mono and proportional font; `document.fonts.ready`; deviceScaleFactor 1; 100% zoom; PixelRatio recorded | Playwright Chromium fixture |

#### Current local-state gaps

1. `ViewLayout` has no `_maxLineWidth` or `_overlayWidgetsMinWidth`. The public
   `set_content_width` accepts an already-computed final width, so no local
   owner can reproduce the source's wrap/no-wrap branches, right-minimap
   adjustment, `scrollBeyondLastColumn * typicalHalfwidth`, vertical-scrollbar
   addition, whitespace minimum, or overlay minimum.
2. Local content height is only `LinesLayout.getLinesTotalHeight()`. It omits
   `scrollBeyondLastLine`, padding, `ignoreHorizontalScrollbarInContentHeight`,
   and horizontal-scrollbar height. Consequently content-width changes cannot
   feed back into bottom extent as source `_updateContentWidth` requires.
3. Viewer code still computes a width before calling `set_content_width`; this
   is an ownership inversion relative to source `ViewLines.setMaxLineWidth` →
   `ViewLayout.setMaxLineWidth` → `_computeContentWidth`. Geometry implementation
   must land the measured-width handoff, not merely substitute another estimate.
4. Renderer output arithmetic is already close to the pin. The structural
   difference is that local `RenderLineInput` retains raw middot/wsmiddot and
   derives the chosen glyph during rendering, while source retains the derived
   width/glyph and equality compares only the normalized outcome. Either mirror
   source identity or prove local extra invalidations cause zero DOM writes.
5. Do not add `typicalFullwidthCharacterWidth` to `RenderLineInput`: source does
   not. The local FontInfo must still carry and measure it for wrapping/layout
   consumers; renderer fullwidth bookkeeping remains exactly two visible
   columns and final reachability comes from DOM-measured line width.
6. Local `fontInfo.ts` is broadly source-shaped, but editor zoom is fixed away
   and numeric font-weight translation concatenates the raw string instead of
   source `parseInt`. Both need explicit terminal dispositions and boundary
   evidence; persistence/version fields are absent.
7. Local `fontMeasurements.ts` mirrors the request corpus, tolerance, arrow
   gates, safety floors, untrusted retry, and output mapping. It reduces
   per-window caches/PixelRatio/timers to one global browser window, drops
   serialize/restore and disposal, and cannot cancel its pending timeout.
   These are explicit rows, not implicit exclusions.
8. Existing renderer/font tests are not sufficient Gate D evidence at this
   oracle: the geometry plan already notes stale-pin renderer references and
   incomplete fontInfo path/pin headers. Reconcile or replace them with
   current-pin branch-derived tests plus the fixed-font Chromium matrix.

#### Inventory stop gate

- [x] Four source files read completely at the pinned commit.
- [x] Hashes and line counts recorded.
- [x] Scoped clusters and cross-plan overlaps closed explicitly.
- [x] Cache/platform/persistence exclusions have explicit GFM rows.
- [x] Behavior variables and local gaps recorded.
- [x] Independent denominator review corrections are applied: 217 unique, contiguous, five-column rows.
- [x] Integrated into the geometry child as documentation only for the inventory
  commit; product/test work remains stopped for Gate B.

Review gate: this documentation-only inventory must be committed and then
independently approved before any product or test edit.

## Test-Authority Corrections

- Existing scroll/thumb tests use mostly ASCII and do not establish rendered
  width parity.
- Existing hover/content-widget tests assert visibility/content, not anchor
  geometry across tabs, injected text, or proportional fonts.
- Headless uniform-width arithmetic is not a substitute for browser DOM
  measurement.
- viewer/common/view_layout/monaco_render_line_reference_test.mbt is pinned to
  the old 294fb350 oracle, and font_info_reference_test.mbt lacks a complete
  upstream path/pin header. Neither can count as current-pin PASS evidence
  until every scoped case is reconciled against b18492a.

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

Expected seams are Rabbita DOM bindings, absence of variable line height, and
test-fixture font availability. Each must record the exact source behavior
preserved. The scoped geometry tolerance is 1 CSS px under the fixed fixture;
unsupported branches require explicit test and ledger disposition.
Uniform-width invention is not an acceptable seam.

## Exit Gate

- [ ] inventory rows equal ledger rows
- [ ] measured rendered width drives horizontal extent
- [ ] complex content is fully horizontally reachable
- [ ] widgets use rendered visible-range geometry
- [ ] all measured font facts reach the renderer
- [ ] horizontal scrollbar height participates in bottom extent
- [ ] browser geometry matrix is deterministic and green
- [ ] all repository quality gates pass
- [ ] independent closing reread finds no unaccounted scoped member

## Execution Record

- 2026-07-12: Phase 1–2 documentation-only inventory is ready. All eleven
  pinned source hashes and line counts were checked at oracle
  `b18492a288de038fbc7643aae6de8247029d11bd`. Independent pre-review rejected
  and normalized the raw Group A/B/C drafts before integration: statement-level
  inflation and frozen cross-plan duplicates were removed, omitted declared
  members/callbacks were restored, and applicable absent GPU/experimental seams
  were made explicit DEFERRED proposals instead of N-A.
- 2026-07-12: the fixed proposed denominator is 633/633 TODO rows: 242 line
  geometry, 174 widget/query, and 217 layout/renderer/font atoms. The proposed
  terminal map is 421 TESTED, 93 PORTED, 73 DEFERRED, and 46 N-A. No product or
  test file changed. Commit this inventory and STOP for independent Gate B;
  implementation remains unauthorized until that review passes.
