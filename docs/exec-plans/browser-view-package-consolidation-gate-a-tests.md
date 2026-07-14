# Browser View Package Consolidation — Gate A Test and CSS Inventory

Status: inventory ready — STOP FOR REVIEW
Date: 2026-07-14
Plan: docs/exec-plans/browser-view-package-consolidation.md
Oracle commit: vscode submodule at
b18492a288de038fbc7643aae6de8247029d11bd
Local baseline: repository HEAD
687703763adfd44de08f15f5b5b8161f3e999f4f

This docs-only companion is the test, behavior-variable, CSS, and mechanical
validation half of Gate A. It does not authorize a product, package, test, or
asset move. The upstream source-member denominator and local declaration
denominator remain authoritative in the sibling Gate A companions; rows here
link existing evidence to those denominators without recounting source
members.

## Reproducible Denominators

The literal pinned upstream scope is 59 files:

- the complete browser/view.ts TypeScript source unit;
- six named browser/view TypeScript files;
- all 34 TypeScript files under browser/viewParts;
- all 18 CSS files under browser/viewParts.

That is 41 TypeScript files / 13,623 lines and 18 CSS files / 505 lines: 59
files / 14,128 lines total. The explicitly ordered manifest starts with
browser/view.ts, continues with the six named browser/view units, then lists
the viewParts TypeScript and CSS files in sorted order. Its src-relative path,
wc -l, and SHA-256 tab-separated entries hash to:

0a4962eaa7e96c724520c7d9c0c862981cb8d218767712b36f1fb8b82912b535

The local relocation denominator is:

| Kind | Files | Count | Terminal disposition |
|---|---:|---:|---|
| Production MoonBit | 30 | 9,323 lines | PRESERVE |
| MoonBit tests | 16 | 118 unique named tests | PRESERVE |
| CSS | 14 | 512 lines | KEEP PATH AND ORDER |
| Package manifests | 12 | 12 | one KEEP+REWRITE, eleven DELETE |
| READMEs | 12 | 12 | one KEEP+FOLD, eleven DELETE |
| Generated interfaces | 12 | 12 | one REGENERATE, eleven DELETE |

All 118 test labels are unique. Their sorted name-only SHA-256 is:

802b390612801a787a6a21e247f55cd747877e498a8f71f63cbad31ac92052dc

The hash is reproduced with:

~~~sh
rg --no-filename '^((async )?test) "' \
  viewer/browser/view viewer/browser/view_layer viewer/browser/view_parts \
  --glob '*_test.mbt' --glob '*_wbtest.mbt' |
  sed -E 's/^((async )?test) "([^"]+)".*/\3/' |
  LC_ALL=C sort |
  shasum -a 256
~~~

Before consolidation, the package-level test split is:

| Current package | Test files | Named tests | Current command | Evidence status |
|---|---:|---:|---|---|
| viewer/browser/view | 7 | 48 | moon test viewer/browser/view --target js -v | TESTED |
| view_parts/content_widgets | 1 | 26 | moon test viewer/browser/view_parts/content_widgets --target js -v | TESTED |
| view_parts/decorations | 1 | 7 | moon test viewer/browser/view_parts/decorations --target js -v | TESTED |
| view_parts/view_cursors | 1 | 3 | moon test viewer/browser/view_parts/view_cursors --target js -v | TESTED |
| view_parts/view_lines | 5 | 31 | moon test viewer/browser/view_parts/view_lines --target js -v | TESTED |
| view_parts/view_zones | 1 | 3 | moon test viewer/browser/view_parts/view_zones --target js -v | TESTED |
| Total | 16 | 118 | six JS-only package invocations | TESTED |

The other six scoped packages have no package-local test file. Their concrete
behavior evidence is mapped below rather than treated as absent:
browser/view_layer, current_line_highlight, editor_scrollbar, margin,
overlay_widgets, and selections.

## Test-to-Production Branch Map

Each row names only the behavior slice directly exercised by the test file.
It does not promote untested siblings to TESTED.

| Test file | Tests | Production/source slice exercised | Terminal evidence |
|---|---:|---|---|
| view/editor_class_name_wbtest.mbt | 5 | view.mbt root-class builder: default, each option independently disabled, both disabled, Safari/WebKit/macOS suffix axes | TESTED |
| view/rendering_context_wbtest.mbt | 4 | rendering_context.mbt and renderingContext.ts: numeric carriers, strict first/last ties, missing ViewLines guard, viewport snapshot and includeViewZones forwarding | TESTED |
| view/view_events_wbtest.mbt | 23 | dispatcher FIFO/reentrancy/nesting; full-batch order; sticky dirtiness; overlay registration; ViewLines change/delete/insert/flush recycler paths; option identity; every current event handler; render read/write order | TESTED |
| view/view_lifecycle_wbtest.mbt | 2 | View-owned ViewZones DOM order and idempotent ViewPart-before-lifetime disposal | TESTED |
| view/view_part_test.mbt | 1 | fixed PartFingerprint numeric slots consumed by DOM hit testing | TESTED |
| view/view_user_input_events_wbtest.mbt | 1 | viewUserInputEvents.ts mouse-target conversion: every closed target arm | TESTED |
| view/view_zones_branch_matrix_wbtest.mbt | 12 | viewZones.ts anchors, affinities, hidden areas, raw heights, ordinal choice, layout recompute, frozen-key/live-delegate iteration, callback ordering and failure positions | TESTED |
| content_widgets/content_widgets_wbtest.mbt | 26 | contentWidgets.ts construction, mount choice, anchor validation/projection, layout caches, affinity, outer-key snapshots, visibility/focus, placement traversal, viewport/page clamps, owner window/document, iOS and detached fallbacks | TESTED |
| decorations/decorations_wbtest.mbt | 7 | decorations.ts filter/sort, whole-line pieces, touching merge, class split, collapse pullback/widening, wrapped-line fill | TESTED |
| view_cursors/view_cursors_wbtest.mbt | 3 | viewCursors.ts reachable readonly class arms, DPR snapping, Line-style render data | TESTED |
| view_lines/geometry_range_wbtest.mbt | 4 | domReadingContext.ts and rangeUtil.ts: cached reads, zero width, Range reuse/parking, scale/merge threshold 0.9, endpoint repair and empty span | TESTED |
| view_lines/geometry_view_line_wbtest.mbt | 8 | viewLine.ts retained slow strategy: width caches, absent strategy guards, visible ranges, one-pixel stabilization, foreign elements, pixel cache, prior DOM reuse, row HTML/CSS, invariant failure | TESTED |
| view_lines/geometry_view_lines_wbtest.mbt | 9 | viewLines.ts and viewLineOptions.ts: retained range, config reset bits, multi-line/newline/RTL geometry, converter progression, JS rounding, width feedback, 200 ms scheduling and disposal | TESTED |
| view_lines/render_whitespace_selection_wbtest.mbt | 5 | viewLine.ts Selection-whitespace branch: miss, clipped single line, non-anchor clamp, empty drop, non-Selection bypass | TESTED |
| view_lines/retained_lines_wbtest.mbt | 5 | viewLine.ts retained invalidators, Selection-only selection dirtiness, normalized no-write identity, live factory options, complete applicable option equality | TESTED |
| view_zones/view_zones_geometry_wbtest.mbt | 3 | viewZones.ts width threshold, zero/nonzero contentLeft, callback/geometry/container write order, visible-to-none retained widths | TESTED |

### Scoped packages without a direct test file

| Current package | Existing evidence that moves with or follows the code | Residual status |
|---|---|---|
| browser/view_layer | view_events_wbtest covers ViewLines delete/insert/flush reconciliation; scroll_frame_parity.spec.js covers unchanged, one-line/multi-line overlap, no-overlap jump, entering/leaving and invalid batches, including new-batch versus invalid-batch DOM writes | TESTED |
| current_line_highlight | view_events_wbtest covers same-line column moves, selection emptiness, focus/configuration predicates and aggregate order; render_invalidation.spec.js covers focus-only and line-fill invalidation in Chromium | TESTED |
| editor_scrollbar | view_events_wbtest covers the source handler matrix and four independent scroll flags; scroll_animation.spec.js and smoke/scroll.spec.js cover wheel classification, animation, shared rail, reveal/fade and thumb drag | TESTED |
| margin | view_events_wbtest covers margin aggregate order and current-line predicate; render_invalidation.spec.js covers independent gutter widths and line-fill variants; folding, quick-diff, agent-feedback, mouse-selection and selection-geometry browser suites exercise concrete margin output | TESTED |
| overlay_widgets | view_events_wbtest covers only the empty-registry source handler matrix and no-op lifecycle; there is no concrete add/remove or model-swap persistence assertion, and preference placement remains outside the implemented null-position subset | DEFERRED (present-registry, model-swap, and placement coverage absent) |
| selections | view_events_wbtest covers dynamic overlay ordering and line slicing; whitespace-selection and selection-geometry browser suites cover measured rectangles, continuation fill and projected lines | TESTED |

The indirect rows above are relocation evidence, not permission to add the
missing feature subsets during this structural plan.

## Exact Named-Test Ledger — 118 Rows

### viewer/browser/view/editor_class_name_wbtest.mbt — 5

- L7 — root class defaults include showUnused and showDeprecated
- L20 — show_unused off drops only the showUnused class
- L34 — show_deprecated off drops only the showDeprecated class
- L48 — both off keeps the base classes and focus suffix
- L64 — extra editor classes cover browser and macOS axes

### viewer/browser/view/rendering_context_wbtest.mbt — 4

- L2 — rendering geometry carriers preserve source rounding and order
- L55 — LineVisibleRanges first and last are order independent with strict ties
- L88 — RenderingContext DOM facade returns null without rendered ViewLines
- L115 — RenderingContext snapshots current viewport and forwards includeViewZones

### viewer/browser/view/view_events_wbtest.mbt — 23

- L35 — source-shaped payloads retain independent fields and array identity
- L86 — dispatcher gives every handler a whole batch before reentrant FIFO batch
- L118 — ViewZones outgoing continuation waits for reentrant internal delivery
- L146 — nested begin shares one collector and only outer end flushes
- L166 — hidden-area batch delivers mapping events before recovery scroll
- L231 — View dispatcher retains eight handlers in source order and gives each the full batch
- L297 — view-event batch visits every event and accumulates sticky dirty once
- L336 — dynamic overlay subsets preserve registration order and line slicing
- L387 — generic View batch returns a value and always closes on error
- L511 — ViewLines propagates changed token decoration option and selection invalidators per retained row
- L717 — ViewLines changed range notifies every retained row through the inclusive endpoint
- L766 — ViewLines option equality catches same-space font render axes
- L814 — ViewLines deletion reconciles start rows and removes only evicted DOM nodes
- L885 — ViewLines insertion shifts or recycles rows and removes displaced tail DOM
- L965 — ViewLines empty flush resets to one and defers ordinary DOM replacement
- L1016 — cursor state then focus uses new selection shape and focus returns false
- L1139 — ContentWidgets handlers refresh layout and reproject every mapping event
- L1200 — ContentWidgets and ViewZones source handler matrices
- L1311 — overlay aggregates, OverlayWidgets, and EditorScrollbar handler matrix
- L1456 — ViewLines and ViewCursors cover four scroll flags and token endpoints
- L1582 — current-line predicate ignores same-line column moves but tracks emptiness
- L1719 — View renders text before prepare and completes all prepares before writes
- L1830 — grouped same-line cursor over-render retains caches and performs zero DOM writes

### viewer/browser/view/view_lifecycle_wbtest.mbt — 2

- L94 — View mounts both ViewZones containers at the source relative positions
- L134 — View disposes ViewParts before its lifetime store exactly once

### viewer/browser/view/view_part_test.mbt — 1

- L4 — part fingerprint numeric slots round-trip

### viewer/browser/view/view_user_input_events_wbtest.mbt — 1

- L35 — convertViewToModelMouseTarget converts every target arm

### viewer/browser/view/view_zones_branch_matrix_wbtest.mbt — 12

- L158 — ViewZones maps zero, first, middle, last, and clamped model anchors
- L208 — ViewZones forwards every affinity at wrap and injected-text boundaries
- L292 — ViewZones hidden-area omitted false and true toggle exact heights
- L431 — ViewZones preserves raw height callbacks through retained ToInt32
- L493 — ViewZones layoutZone rereads geometry but retains ordinal width and nodes
- L595 — ViewZones derives explicit zero equal and fallback ordinals
- L650 — ViewZones line-height bit recomputes and unchanged layout keeps cadence
- L799 — ViewZones recompute freezes keys but reads future delegates live
- L880 — ViewZones render freezes keys, writes after callback, and reads live values
- L976 — panic ViewZones render exposes source stale-future-key failure
- L1019 — ViewZones contains computed-height throws at first middle and last
- L1079 — ViewZones contains DOM-top throws at first middle and last

### viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt — 26

- L380 — constructor and add preserve container styles and overflow mount choice
- L447 — addWidget reads layout before handle getters in source constructor order
- L472 — panic setWidgetPosition rejects an unknown widget id
- L489 — configuration visits every retained widget and gates layout cache reads
- L604 — onBefore distinguishes null and empty preference and includes viewport endpoints
- L690 — mapping reprojection retains model anchors and visits widgets in key order
- L753 — projection keeps original anchors while exposing clamped and hidden results
- L834 — measured anchors preserve affinity, nullable preference, and per-line geometry
- L933 — all position affinity values forward distinctly and only LeftOfInjectedText owns column-one zero
- L1000 — anchor queries keep same-line secondary and use measured x at later affinity columns
- L1077 — display ownership and read phase preserve source ordering and caches
- L1259 — useDisplayNone and positionability preserve the full display scheduling matrix
- L1356 — prepare snapshot continues after beforeRender removes its current widget
- L1406 — render snapshot continues after afterRender removes its current widget
- L1459 — panic prepare snapshot directly looks up a reentrantly removed future widget
- L1494 — panic render snapshot directly looks up a reentrantly removed future widget
- L1529 — focused off-viewport widgets park without hiding and hidden writes are gated
- L1611 — preference traversal uses first-pass fit then second-pass first option
- L1697 — empty single and mixed preferences preserve source order
- L1815 — ABOVE and BELOW write visible coordinates before afterRender callbacks
- L1894 — secondary anchor reduction preserves primary contact boundaries
- L1962 — viewport layout clamps a nonzero scroll window at inclusive edges
- L2028 — owner document supplies max width, page scroll, and paired clamps
- L2103 — iOS owner visual viewport precedes inner and document client areas
- L2124 — detached owner scroll helpers and page layout use explicit zero fallbacks
- L2170 — page layout keeps 15px and 22px equality boundaries and wide boxes

### viewer/browser/view_parts/decorations/decorations_wbtest.mbt — 7

- L65 — keeps className only and sorts by zIndex, className, range starts
- L95 — whole-line decorations clamp to the visible window as width:100% pieces
- L123 — same-class touching ranges merge into one flushed decoration
- L147 — different classes do not merge
- L156 — showIfCollapsed pulls an endColumn=1 range back to the previous line
- L179 — collapsed range widens to a centered half-width
- L208 — shouldFillLineOnLineBreak expands continuing lines to width:100%

### viewer/browser/view_parts/view_cursors/view_cursors_wbtest.mbt — 3

- L2 — cursors_layer_class ports _getClassName's reachable arms
- L16 — compute_screen_aware_size snaps to the device pixel grid
- L27 — prepare_cursor_render_data ports the Line-style arm

### viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt — 4

- L15 — DomReadingContext reads delta and scale once with zero-width fallback
- L48 — RangeUtil reuses one Range and parks it after success and failure
- L113 — RangeUtil normalization clamps scales sorts and merges at exact 0.9
- L158 — RangeUtil endpoint branches preserve empty span and prior-span repairs

### viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt — 8

- L79 — ViewLine slow width cache reads once resets and marks layout
- L98 — ViewLine absent strategy guards width ranges and layout writes
- L131 — ViewLine visible ranges preserve collapsed raw and truncation branches
- L190 — ViewLine basic ASCII stabilization uses exact inclusive one-pixel tolerance
- L244 — ViewLine empty foreign-content branches distinguish none after before and both
- L306 — ViewLine pixel cache whitespace endpoint and prior DOM reuse
- L365 — ViewLine row HTML preserves direction padding class and geometry CSS
- L406 — panic ViewLine setDomNode rejects absent rendered strategy

### viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt — 9

- L99 — LastRenderedData initializes and replaces the exact visible Range
- L107 — ViewLines configuration resets widths from exact event bits
- L132 — ViewLines raw multi-line query intersects rounds and adds only model newlines
- L186 — ViewLines newline width skips wraps and shifts RTL left
- L249 — ViewLines converter progression covers first middle final and partial windows
- L326 — ViewLines range integerization keeps JavaScript negative-half rounding
- L333 — ViewLines width sweep preserves one ceil monotonic and full-document reset
- L370 — ViewLines scheduler debounces fires the latest callback and disposes pending work
- L404 — ViewLines 200ms scheduler guards and cancel-before-slow ordering

### viewer/browser/view_parts/view_lines/render_whitespace_selection_wbtest.mbt — 5

- L42 — selection derivation: a selection that misses the line yields no offsets
- L55 — selection derivation: a partial single-line selection clips to its columns
- L70 — selection derivation: a non-anchor line clamps to min/max column
- L87 — selection derivation: an empty per-line range is dropped
- L100 — selection derivation: only Selection mode gathers offsets

### viewer/browser/view_parts/view_lines/retained_lines_wbtest.mbt — 5

- L34 — retained ViewLine consumes sticky content token decoration and option invalidators
- L67 — retained ViewLine selection invalidates only last-rendered Selection whitespace
- L88 — retained ViewLine skips writes for distinct raw whitespace widths with equal normalized identity
- L114 — retained line factory reads the current option snapshot on every creation
- L126 — ViewLineOptions equality covers every applicable source render axis

### viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt — 3

- L135 — ViewZones width gate covers below equal above and contentLeft zero nonzero
- L162 — ViewZones writes callbacks and zone geometry before container widths
- L202 — ViewZones some to none retains both container widths

Reconciliation: 5 + 4 + 23 + 2 + 1 + 1 + 12 + 26 + 7 + 3 + 4 + 8 +
9 + 5 + 5 + 3 = 118.

## Behavior-Variable Matrix

This matrix combines the 118 MoonBit tests with the lowest browser layer that
can observe DOM, layout, pointer, animation, or CSS behavior.

| Parent-plan axis | Existing evidence | Terminal coverage |
|---|---|---|
| no model / attached / model swap / dispose | view_lifecycle_wbtest; component/model_swap.spec.js; set_value.spec.js; the two generated Viewer/model disposal cells in view_zones.spec.js | TESTED (root lifecycle is intentionally outside leaf unit tests) |
| empty / normal / scrolled viewport | ViewLines empty flush; ContentWidgets viewport endpoints and nonzero scroll; ViewZones offscreen/visible cases; browser geometry and smoke scroll | TESTED |
| wrapped / unwrapped | zone affinity at wrap boundaries; decoration line-break fill; ViewLines newline-skips-wrap; browser geometry wrap transition, wrapped widget reprojection, wrapped cursor drag and selection | TESTED |
| content and margin overlays independently dirty | dynamic overlay subset/order test; handler matrix; grouped no-write test; render_invalidation line-fill/gutter/focus cases | TESTED |
| selection absent/present | cursor class selection bit; Selection-whitespace miss/present cases; smoke selection geometry and whitespace-selection browser suite | TESTED |
| cursor absent/present/focus | cursor/focus event sequence, current-line predicate, cursor render data; cursor-input browser suite | TESTED |
| decorations absent/present/change | seven decoration-piece branches; retained line invalidators; stationary cursor/widget decoration browser cases; multi-change convergence | TESTED |
| content widgets absent/present/offscreen/focused | 26-case ContentWidgets matrix plus real iframe/browser geometry and hover stability | TESTED |
| overlay widgets absent / empty registry | empty-registry event handler matrix and no-op lifecycle | TESTED |
| overlay widgets present / add-remove / model swap / placement | no existing test registers a concrete overlay widget, asserts add/remove DOM behavior, or carries one across a root model swap; preference placement is also unimplemented | DEFERRED (present-registry, model-swap, and placement coverage absent) |
| view zones absent/present/hidden/offscreen/disposed | 15 direct zone tests plus eight browser cells including generated disposal cases | TESTED |
| smooth scrolling disabled/enabled | component scroll_animation physical/trackpad cells; scroll_frame_parity matrix uses smooth false/true, physical/trackpad, 10/37/100 viewport lines and three repetitions | TESTED (observed host cadence only) |
| viewport width/height and horizontal scroll | RenderingContext snapshots; ContentWidgets viewport/page clamps; ViewLines max-width feedback; ViewZones width gates; browser geometry, invalidation and scroll suites | TESTED |
| DOM node order and render phase order | ViewZones mount test; eight-handler/full-batch test; text-before-prepare and all-reads-before-writes test; zone write-order tests | TESTED |
| transform ownership | ViewLines rail top/left geometry; steady-scroll no-rewrite browser test; smoke shared-rail test | TESTED |
| stale-node recycling | ViewLines insert/delete/flush unit cases; scroll perf unchanged/overlap/jump/enter/leave/invalid batches | TESTED |
| CSS classes and output order | root/cursor/row class tests; Chromium platform class test; CSS source-order and byte hash below | TESTED |
| disposal order and pending work | ViewPart-before-store exactly once; ViewLines scheduler disposal; zone Viewer/model disposal browser cells; scrollbar fade/drag smoke behavior | TESTED |

### Explicit matrix gaps retained by this structural plan

| Axis/source subset | Why current tests do not cover it | Terminal disposition |
|---|---|---|
| alternate 60 Hz versus 120 Hz rAF cadence | the host exposes only one observed cadence; scroll_frame_parity records the other cell in its report | DEFERRED (unavailable host cadence) |
| GPU ViewLines and RenderingContext fallback/concat/sort | no GPU renderer or GPU-owned ViewPart exists | DEFERRED (GPU owner absent) |
| fast/WebKit rendered-line strategy and browser-zoom monospace diagnostics | local product intentionally retains the normal slow strategy | DEFERRED (strategy owners absent) |
| experimental whitespace renderer | no exposed experimental rendering option | DEFERRED (option absent) |
| ContentWidgets editor allowOverflow and fixedOverflowWidgets | Viewer exposes neither editor option | DEFERRED (configuration seam absent) |
| external overflow host and aggregate-focus lifecycle | no overflow-host option or aggregate-focus contract | DEFERRED (host contract absent) |
| concrete hover shouldAppearBeforeContent producer | generic affinity handoff exists, concrete producer does not | DEFERRED (producer absent) |
| preference-positioned OverlayWidgets | implemented package is the null-position/self-positioning registry subset | DEFERRED (placement subset absent) |
| multi-cursor, cursor blink interval and cursor-style matrix | readonly viewer has one Line-style solid cursor | DEFERRED (multi-cursor/style owners absent) |
| glyph margin, relative/interval/custom line numbers | margin package implements current-line, line-decoration and lineNumbers-on subset | DEFERRED (view-part/options absent) |
| edit-context and GPU teardown | no edit-context owner, accessibility seam, or GPU renderer exists | DEFERRED (lifecycle owners absent) |
| typed theme and composition producers | event declarations exist, but readonly product has direct CSS theme state and no composition producer | N-A (no current producer) |
| unsupported upstream block decorations, glyph margin, gpu mark, indent guides, minimap family, margin decorations, overview rulers, rulers, scroll decoration, GPU lines, and standalone whitespace part | no local production counterpart; exact member terminals live in the upstream companion | DEFERRED (unsupported view parts stay out of scope) |

No gap above may be silently converted into new product work during package
flattening.

## CSS Assembly and Byte-Parity Inventory

scripts/build-web.mbtx lines 486–511 own the complete global order.
assembled_style_css writes a provenance comment containing each source path,
then the file bytes, a terminating newline if needed, and one blank separator.
It writes web/dist/style.css; the reference app, embed app, and generated
browser-test pages all link that single file.

The 14 scoped CSS files occupy these exact global positions:

| Global position | CSS source | Lines | SHA-256 | Terminal disposition |
|---:|---|---:|---|---|
| 4 | viewer/browser/view/codicon/codicon.css | 55 | dce03fd97747a5fc3514142d41a274e53c0a12d27466cf36995d533bf835a8e7 | KEEP PATH AND ORDER |
| 5 | viewer/browser/view/editor.css | 35 | e60b301444996ccb8ef7a3f3899fa9c5947553e0e03d8d7f9adb7e88752b2a9a | KEEP PATH AND ORDER |
| 7 | viewer/browser/view_parts/view_lines/view_lines.css | 46 | 9d2f8f659e9fb5b13bcd15c9bc738945b44a4d8810335b94b24ef2e0b7ecf7f6 | KEEP PATH AND ORDER |
| 8 | viewer/browser/view_parts/selections/view_overlays.css | 18 | a3c3962e09b1eadb68bc22fc7c407526b05e1dc10217e66b21f72f7e3d258fbc | KEEP PATH AND ORDER |
| 9 | viewer/browser/view_parts/content_widgets/content_widgets.css | 13 | bf087c560d6448461cb9d5542bb5c47d613434a43c7d81fce0bb1bbe9e32a593 | KEEP PATH AND ORDER |
| 10 | viewer/browser/view_parts/overlay_widgets/overlay_widgets.css | 13 | 00cc017770869d9e03efc0341d73a86737364bb8e4a595d4f6e34d7b69025ea1 | KEEP PATH AND ORDER |
| 11 | viewer/browser/view_parts/selections/selections.css | 42 | 7f7beaf3d3832d3c588354b900135568b9caa71b3913489672c045648c3fed8c | KEEP PATH AND ORDER |
| 12 | viewer/browser/view_parts/current_line_highlight/current_line_highlight.css | 55 | ca8168e586d081f6e57009066ffc3baf9fa71d4d7bf18c6f36e7cfa58532649e | KEEP PATH AND ORDER |
| 13 | viewer/browser/view_parts/decorations/decorations.css | 15 | e89338f1f398b6d93f3fa9a6e234600b010fb05c445fd383d950d5d6b13d1689 | KEEP PATH AND ORDER |
| 14 | viewer/browser/view_parts/view_cursors/view_cursors.css | 31 | 468224a34805fd6c0f38d7556fa3991da3a7ccf4d6f5884b15f49238027bcf94 | KEEP PATH AND ORDER |
| 15 | viewer/browser/view_parts/margin/margin.css | 37 | e422fa0d3a4aac1782c0e8bc1c70fb6dfe8f097a32f71b01b4621f48a62cd249 | KEEP PATH AND ORDER |
| 16 | viewer/browser/view_parts/margin/lines_decorations.css | 7 | f0c22830763933b564a3d82ffb59b3e7c149214ecee0fbd3bccdce4cafb92ba4 | KEEP PATH AND ORDER |
| 17 | viewer/browser/view_parts/view_lines/tokens.css | 74 | 1ce97292a60d80b22e648f42e46c213413fe71c59ab8a19cb2d58f147d00709e | KEEP PATH AND ORDER |
| 18 | viewer/browser/view_parts/view_lines/markers.css | 71 | a60eb675dfd545c514f798b90a219da0de072b122e755fa49497080ed5fe6be0 | KEEP PATH AND ORDER |

The current generated output is 56,378 bytes and hashes to:

bcf27861211e6731f0208a756946f9d1f2110c1e8c24bc936cbe5d5d76d66599

A streamed reassembly from the 22 entries in css_sources is byte-identical to
web/dist/style.css at this baseline (cmp exit 0) and produces the same hash.
The ordered css_sources function slice currently hashes to
98bef67a50532b5a1ca241f8d690a49da3e4f7a3da2542002e8cc706d4a62060;
the assembly-function slice hashes to
e33adcd5b2d3421c7f397bd5d6f95e759077b0cb1b8dadba8cca82a9428be296.

Because the generated provenance comments contain the source paths, moving a
CSS file changes the generated bytes even when its rules are unchanged.
Therefore the exact byte-parity decision is to keep the two root paths and all
twelve leaf CSS paths. Eight old leaf directories remain as asset-only
directories after their MoonBit source/manifests/interfaces/READMEs move:
content_widgets, current_line_highlight, decorations, margin, overlay_widgets,
selections, view_cursors, and view_lines.

There is no checked-in automated byte-hash test. just build proves assembly
succeeds, and smoke/viewer.spec.js proves /style.css is requested; the
baseline hash comparison below is the additional relocation gate.

## Mechanical Relocation Checkpoints

### Baseline checkpoint

Record and retain:

- 30 production files / 9,323 lines;
- 16 test files / 118 unique labels;
- name-only test hash
  802b390612801a787a6a21e247f55cd747877e498a8f71f63cbad31ac92052dc;
- 14 CSS paths, their order and per-file hashes;
- generated style hash
  bcf27861211e6731f0208a756946f9d1f2110c1e8c24bc936cbe5d5d76d66599;
- pinned upstream path/line/hash manifest
  0a4962eaa7e96c724520c7d9c0c862981cb8d218767712b36f1fb8b82912b535.

### Constructor-surface checkpoint

Milestone D changes each touched primary `Type::new` constructor to
`Type::Type` unless `new` is a genuinely distinct alternate construction path.
Before each move, reconcile the moved unit against the constructor decision
table in the local companion. After the move, enumerate every remaining
production `::new` definition in the merged package:

~~~sh
! rg -n \
  '^(pub(\(all\))? )?fn(\[[^]]+\])? [A-Za-z_][A-Za-z0-9_]*::new\(' \
  viewer/browser/view --glob '*.mbt' \
  --glob '!**/*_test.mbt' --glob '!**/*_wbtest.mbt'
~~~

Any remaining production primary `::new` fails this gate. Distinct alternate
factories retain their non-`new` names and do not match the assertion. For each
converted constructor, update all call sites in the same milestone, run
`moon ide find-references` on the old name to require zero live references,
and let `moon check --target js`, `moon info --target all`, and the moved
unit's tests validate the new surface.

### After each coherent leaf or atomic group

Run:

~~~sh
moon check --target js
moon test viewer/browser/view --target js -v
just check
git diff --check
~~~

Move each test file in the same commit as its production owner. The cumulative
test total in the target package must rise only by the moved file's fixed
count. File basenames are already unique, so no test rename is required.

The recycler move is atomic with ViewLines. Its gate additionally runs:

~~~sh
./node_modules/.bin/playwright test \
  tests/browser/perf/scroll_frame_parity.spec.js \
  tests/browser/smoke/scroll.spec.js \
  tests/browser/component/browser_geometry.spec.js \
  tests/browser/component/render_invalidation.spec.js
~~~

The current-line highlight and margin move is atomic. Its gate additionally
runs:

~~~sh
./node_modules/.bin/playwright test \
  tests/browser/component/render_invalidation.spec.js \
  tests/browser/smoke/mouse_selection.spec.js \
  tests/browser/smoke/selection_geometry.spec.js \
  tests/browser/component/folding.spec.js \
  tests/browser/component/folding_nested.spec.js \
  tests/browser/component/quick_diff.spec.js
~~~

ContentWidgets, zones, cursors/selections/decorations, and scrollbar groups
use their corresponding component/smoke files from the behavior matrix before
their milestone commit.

### Final structural checkpoint

After every source and test is in viewer/browser/view:

~~~sh
moon test viewer/browser/view --target js -v
moon check --target all
moon info --target all
moon ide analyze viewer/browser/view
just check
just test
just build
just test-browser
git diff --check
~~~

The final view package must report all 118 named tests. Recompute the
name-only hash against viewer/browser/view alone and require the same
802b390612801a787a6a21e247f55cd747877e498a8f71f63cbad31ac92052dc
value.

Require zero old MoonBit imports:

~~~sh
! rg -n \
  '"moonbit-community/editor/viewer/browser/(view_layer|view_parts/)' \
  --glob moon.pkg .
~~~

Require one scoped MoonBit manifest and one generated interface:

~~~sh
test "$(rg --files viewer/browser/view viewer/browser/view_layer \
  viewer/browser/view_parts | rg '/moon\.pkg$' | wc -l | tr -d ' ')" = 1
test "$(rg --files viewer/browser/view viewer/browser/view_layer \
  viewer/browser/view_parts | rg '/pkg\.generated\.mbti$' |
  wc -l | tr -d ' ')" = 1
~~~

Require the approved 31-file production layout, including the source-shaped
rename and extracted margin owner:

~~~sh
test "$(rg --files viewer/browser/view | rg '\.mbt$' |
  rg -v '(_test|_wbtest)\.mbt$' | wc -l | tr -d ' ')" = 31
test -f viewer/browser/view/view_part.mbt
test -f viewer/browser/view/margin.mbt
test ! -e viewer/browser/view/part_fingerprints.mbt
~~~

After just build, require exact CSS output:

~~~sh
test "$(shasum -a 256 web/dist/style.css | awk '{print $1}')" = \
  bcf27861211e6731f0208a756946f9d1f2110c1e8c24bc936cbe5d5d76d66599
~~~

Finally reread the 59-file upstream denominator and reconcile every main
ledger row. Green tests and the hashes above are necessary relocation gates;
they do not replace source-member accounting.

## Gate A Review Stop

The reviewer is asked to approve or revise:

1. the fixed 16-file / 118-name test denominator and terminal branch map;
2. the indirect evidence for the six packages without direct test files;
3. the explicit behavior-variable deferrals;
4. the decision to retain all fourteen CSS paths and exact global order;
5. the 31-file target map, `view_part.mbt` rename, and `margin.mbt` extraction;
6. the name-hash, import-absence, single-manifest, API and style-byte gates.

STOP FOR REVIEW. No browser product, package, test, CSS, build-script, README,
or generated-interface move is authorized by this companion.
