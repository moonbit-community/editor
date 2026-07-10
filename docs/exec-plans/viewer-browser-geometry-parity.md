# Viewer Browser Geometry Parity

Status: proposed — Phase 0 drafted; inventory pending

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

The inventory must distinguish:

- logical model length;
- projected/view-line text length;
- character-mapping visible ranges;
- DOM offsetWidth/scrollWidth and whether layout occurred;
- cached maximum versus current visible maximum;
- wrap-enabled versus no-wrap width ownership;
- content, viewport, scrollbar, and right-padding dimensions;
- primary/secondary widget anchors and above/below/exact placement;
- measured versus estimated FontInfo.

Record every constant and timing/layout guard. A local formula may remain only
when it is source-cited or documented as a reviewed DOM/runtime seam.

Review gate: stop after inventory and equal-size ledger are committed.

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

Not started. Append dated inventory, approval, implementation commits,
measurements, validation results, and final ledger totals here. Freeze after
implementation.
