# Viewer Render Invalidation Parity

Status: IMPLEMENTED AND FROZEN

Date: 2026-07-10

Implemented: 2026-07-12

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Findings: P1-06, P1-09. This plan also owns the prerequisite ContentWidget
event-handler cluster needed by P1-08.

Depends on: viewer-model-lifecycle-ownership-parity.md and
viewer-async-model-features-parity.md

Historical stop gate: no product code was changed until the inventory and
equal-size ledger were committed and independently reviewed. That gate passed
before implementation began.

## Goal

Make configuration, cursor, decoration, line, zone, focus, and scroll changes
dirty exactly the ViewParts whose rendered output or geometry depends on them.
Runtime option changes and dynamic inline decorations must become visible in
the next render without relying on an unrelated event.

This plan owns invalidation and event propagation. Pixel measurement and
coordinate algorithms belong to viewer-browser-geometry-parity.md.

## Scope (Phase 0)

### Pinned Monaco source

- vscode/src/vs/editor/common/viewEvents.ts
  - complete event types and configuration-change data consumed by scoped
    ViewParts, including the theme event declaration needed to close the event
    union; typed declaration/dispatch is planned while concrete local theme
    handling remains an explicit N-A seam.
- vscode/src/vs/editor/common/viewEventHandler.ts
  - complete handler dirty-state/dispatch contract.
- vscode/src/vs/editor/common/viewModelEventDispatcher.ts
  - complete generic view-event queue/collector handoff plus the
    configuration/decorations/injected-text clusters; cursor-specific and zone
    outgoing-event siblings are excluded.
- vscode/src/vs/editor/common/viewModel/viewModelImpl.ts
  - complete configuration, decorations, injected-text, and line-change
    event-emission clusters plus the generic collector wrappers handed off by
    frozen cursor VMI rows. Cursor-state emission remains owned by
    viewer-cursor-input-events-parity.md.
- vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts
  - complete updateOptions-to-configuration notification cluster only;
    model lifecycle and cursor event forwarding are excluded.
- vscode/src/vs/editor/browser/config/editorConfiguration.ts
  - complete updateOptions, recompute, environmental setter/digit-count,
    platform extra-class helper, changed-option dependency, and emitted
    configuration-change clusters.
- vscode/src/vs/editor/browser/config/migrateOptions.ts
  - complete generic migration machinery plus the renderWhitespace and
    renderLineHighlight registrations; unrelated option registrations are
    excluded siblings.
- vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts
  - complete scoped handlers for Configuration, Cursor, Decorations, Flushed,
    LinesChanged/Deleted/Inserted, Scroll, Tokens, Zones, and Theme, plus their
    dirty-state transitions and the source-owned visible-line factory callback.
    Width reads and render integration belong to viewer-browser-geometry-parity.md.
- vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts
  - complete retained-line invalidation inputs and option/selection branches.
- vscode/src/vs/editor/browser/view/viewLayer.ts
  - complete visible-line collection invalidation and retained-line update
    clusters consumed by ViewLines.
- vscode/src/vs/editor/browser/viewParts/viewCursors/viewCursors.ts
  - complete ViewPart event-handler cluster.
- vscode/src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts
  - complete ViewPart configuration/decorations/lines/scroll/zones event
    handlers and their dirty-state transitions only. setWidgetPosition,
    placement, and render belong to viewer-browser-geometry-parity.md.
- vscode/src/vs/editor/browser/viewParts/currentLineHighlight/currentLineHighlight.ts
  - complete Theme, Configuration, Cursor, Flushed, Deleted/Inserted, Scroll,
    Zones, and Focus invalidation cluster.
- vscode/src/vs/editor/common/config/editorOptions.ts
  - option registrations and change dependencies for fixed `readOnly`, renderWhitespace,
    renderControlCharacters, renderLineHighlight, and
    renderLineHighlightOnlyWhenFocus, and renderValidationDecorations.

### Local ownership

- viewer/viewer_options.mbt
- viewer/view_host.mbt
- viewer/browser/view/view.mbt
- viewer/browser/view/editor_class_name_wbtest.mbt
- viewer/browser/view/rendering_context.mbt
- viewer/browser/view/view_events.mbt
- viewer/browser/view/view_part.mbt
- viewer/browser/view/view_layer_renderer.mbt
- viewer/browser/view/view_overlays.mbt
- viewer/browser/view_parts/view_lines/view_lines.mbt
- viewer/browser/view_parts/view_lines/view_line.mbt
- viewer/browser/view_parts/view_cursors/view_cursors.mbt
- viewer/browser/view_parts/content_widgets/content_widgets.mbt
- viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt
- viewer/common/view_model/view_model.mbt
- viewer/common/view_model/view_model_options.mbt
- viewer/viewer.mbt
- viewer/common/view_model/view_model_decorations.mbt
- viewer/attach_model.mbt
- viewer/inlay_hints_host.mbt
- viewer/render_whitespace_options_wbtest.mbt
- viewer/README.md

Inventory every option field that changes rendered HTML/CSS, every event source,
every event payload field, every ViewPart handler, snapshot field, dirty-state
transition, force-render path, and last-rendered-value cache.

### Explicitly out of scope

- the actual ContentWidget x-coordinate algorithm;
- ContentWidget validation, visible-range, placement, and focus-preservation
  clusters, which belong to viewer-browser-geometry-parity.md;
- ViewLines width measurement and maximum-width feedback, which belong to
  viewer-browser-geometry-parity.md;
- rendered line width measurement and scroll extent;
- ViewZone DOM/API/callback behavior;
- adding new editor options beyond those already exposed;
- replacing the complete local snapshot-diff event seam with Monaco's event
  dispatcher unless the inventory proves the scoped behavior cannot be
  expressed faithfully through the existing seam;
- line HTML generation unrelated to option-dependent output.

## Initial Decision Register

| Behavior | Decision |
|---|---|
| update_options changes renderWhitespace/renderControlCharacters but ViewLines remains clean | REQUIRED PARITY |
| current-line option changes do not dirty current-line parts | REQUIRED PARITY |
| render_validation_decorations changes the provider without a decoration generation/event | REQUIRED PARITY |
| ContentWidgets ignores ViewDecorationsChanged | REQUIRED PARITY |
| ViewCursors ignores ViewDecorationsChanged | REQUIRED PARITY |
| an unrelated scroll/content/cursor event is needed to reveal the change | REQUIRED PARITY: forbidden |
| local snapshot-diff event sourcing | INTENTIONAL DEVIATION candidate; must prove the same observable event matrix |
| `update_options` replaces one complete typed snapshot instead of accepting Monaco's partial object | INTENTIONAL DEVIATION candidate; preserve exact no-op/change behavior and document the API seam in `viewer/README.md` |
| `ViewThemeChangedEvent.theme` source `IColorTheme` becomes the existing local `String` theme identity | INTENTIONAL DEVIATION candidate; declaration/dispatch only, with no typed producer or concrete handler |
| Safari/WebKit/macOS platform classes are absent from the root class helper | REQUIRED PARITY; add a pure platform-class helper and root-class integration |

This register is not the parity ledger and does not count toward the
source-member denominator.

This plan explicitly supersedes only the inaccurate invalidation evidence in
the implemented monaco-view-cursors-current-line-port.md. Do not edit that
historical plan.

## Inventory and Parity Ledger (Phases 1–2)

This inventory uses one row per declared member, field/property,
behavior-changing branch or early return, independently reused/control-flow
constant, and source-owned callback. A field row owns its constructor
assignment and literal. Straight-line bookkeeping, loop mechanics, and final
returns are not separate atoms. Whole excluded siblings are named in the
boundary registry instead of compressed into umbrella rows.

At Gate B every source row below was `TODO`, and the proposed terminal was only
a review target. The collapsed four-column ledgers now record the final
reviewed terminal status for the frozen implementation. The deduplicated
denominator remains:

```text
ViewParts: VL 33 + VLI 13 + VLCI 4 + VLC 16 + RLC 30
         + VC 40 + CW 21 + CLH 27                         = 184
Events:    VE 75 + VEH 45 + RVC 35 + RVD 14 + RVMI 36
         + CEWU 2                                           = 207
Config:    ECF 33 + ECS 13 + ECX 3 + ECU 27 + EOP 25
         + EOB 37 + MIG 34                                  = 172
                                                               ---
Total                                                          563
```

### Source evidence and closed boundaries

Oracle: `b18492a288de038fbc7643aae6de8247029d11bd`.

| File | Lines | SHA-256 |
|---|---:|---|
| `browser/viewParts/viewLines/viewLines.ts` | 875 | `b312dba68bbf6ebfd33f90ad2c2d6ea403f595d80bc25f82999328153517df5a` |
| `browser/viewParts/viewCursors/viewCursors.ts` | 417 | `b4f2e15e8600c3cf188b35bd3f99a0c8912046dd7d538f3dbb2a22fa6ffee1eb` |
| `browser/viewParts/contentWidgets/contentWidgets.ts` | 633 | `e524a6baaf256fb8e8d427a76f217cd832954bdabaf11b73e1e066b6dd50f7a6` |
| `browser/viewParts/currentLineHighlight/currentLineHighlight.ts` | 264 | `74e10848de7ea076230aef844110f7471326581178a4f56bab2792c9f5928596` |
| `browser/viewParts/viewLines/viewLine.ts` | 734 | `8ab7866695ac0138524e2ce5d5f43abb377232b694bfd115e08dc81221bf3b8d` |
| `browser/view/viewLayer.ts` | 630 | `8e8fc4f816931648bcae1ebb01cf8aa67d723311f2f78bd67b649c6ef74e92ca` |

Closed ViewPart boundaries are the complete event/invalidation clusters in
the six files above. Explicit sibling exclusions are:

- `viewLines.ts`: DOM lookup, measurement, line-width/render feedback, render
  preparation/write, hit testing, and reveal helpers; `onRevealRangeRequest`
  (`:269–304`) remains owned by the historical reveal work, and width feedback
  remains browser-geometry-owned.
- `viewLine.ts`: `setDomNode`, render/layout/width work, DOM helpers, and the
  GPU-only renderer-clearing branch (`:103–106`). The inventoried invalidators
  retain `_renderedViewLine` and set only `_isMaybeInvalid`.
- `viewLayer.ts`: omitted interface members, `_get`, DOM creation/access,
  render entrypoints, and `ViewLayerRenderer`; only the retained collection
  event/invalidation cluster is included.
- `viewCursors.ts`: blink timers/state machine, DOM class/visibility writes,
  prepare/render, cursor glyph geometry, and theming-participant CSS.
- `contentWidgets.ts`: add/remove/set APIs, anchor validation, measurement,
  placement, focus/callback preservation, prepare/render, and DOM writes;
  `_setPosition` and affinity/placement geometry remain geometry-owned.
- `currentLineHighlight.ts`: prepare/render/predicates, concrete overlay
  subclasses, and theming-participant CSS; only retained cache/event behavior
  is included.

StableViewport, custom-height, and attached-view helper bodies remain
geometry-owned. Theme event declarations close the source union, while the
concrete local product applies theme through CSS/root attributes and has no
typed theme-handler contract.

### ViewPart ledger — 184 rows

#### `viewLines.ts` (`VL`, 33 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| VL-001 | `_visibleLines` (`:105,149–152,189,227–251,261,319`) | Constructor assigns the retained ViewLayer field; scoped events delegate and return its dirtiness. | TESTED |
| VL-002 | `domNode` (`:106,152,210,318`) | Constructor obtains the collection DOM; configuration font and scroll-width writes affect it. | TESTED |
| VL-003 | `_lineHeight` (`:109,138,198`) | Constructor and configuration read the exact line height. | TESTED |
| VL-004 | `_typicalHalfwidthCharacterWidth` (`:110,139,199`) | Constructor and configuration read the halfwidth metric. | TESTED |
| VL-005 | `_isViewportWrapping` (`:111,140,200`) | Constructor and configuration read viewport wrapping. | TESTED |
| VL-006 | `_revealHorizontalRightPadding` (`:112,141,201`) | Constructor/configuration retain a historical reveal-owned value. | N-A (historical reveal-owned field) |
| VL-007 | `_cursorSurroundingLines` (`:113,142,202`) | Constructor/configuration retain a historical reveal-owned value. | N-A (historical reveal-owned field) |
| VL-008 | `_cursorSurroundingLinesStyle` (`:114,143,203`) | Constructor/configuration retain a historical reveal-owned value. | N-A (historical reveal-owned field) |
| VL-009 | `_canUseLayerHinting` (`:115,144,204,672`) | Read as `!disableLayerHinting` and consumed by `renderText`; local renderer deliberately fixes the equivalent fact true. | TESTED |
| VL-010 | `_viewLineOptions` (`:116,145,223–231`) | Constructor and updates retain the option snapshot driving line invalidation. | TESTED |
| VL-011 | `_maxLineWidth` (`:119,159,190–192,214–216,257,326`) | Constructor/flush/config/zones maintain geometry-owned maximum width. | DEFERRED (browser geometry dependency) |
| VL-012 | `_horizontalRevealRequest` (`:123,169,305–316`) | Constructor clears it; scroll invalidation cancels/retains the historical reveal request. | TESTED |
| VL-013 | `_stickyScrollEnabled` (`:127,172,207`) | Constructor/configuration retain a value for an absent local sticky-scroll part. | N-A (no sticky-scroll ViewPart) |
| VL-014 | `_maxNumberStickyLines` (`:128,173,208`) | Constructor/configuration retain a value for an absent local sticky-scroll part. | N-A (no sticky-scroll ViewPart) |
| VL-015 | `onConfigurationChanged` (`:188–219`) | Reread caches and propagate option changes in source order. | TESTED |
| VL-016 | `_onOptionsMaybeChanged` (`:220–237`) | Equality-gate retained-line option invalidation. | TESTED |
| VL-017 | `onCursorStateChanged` (`:238–246`) | Dirty only for Selection whitespace/high-contrast selection behavior. | TESTED |
| VL-018 | `onDecorationsChanged` (`:247–254`) | Forward inline-decoration invalidation to visible lines. | TESTED |
| VL-019 | `onFlushed` (`:255–259`) | Flush retained lines and width state. | TESTED |
| VL-020 | `onLinesChanged` (`:260–262`) | Return retained collection overlap result. | TESTED |
| VL-021 | `onLinesDeleted` (`:263–265`) | Return retained collection deletion result. | TESTED |
| VL-022 | `onLinesInserted` (`:266–268`) | Return retained collection insertion result. | TESTED |
| VL-023 | `onScrollChanged` (`:305–320`) | Apply exact horizontal/vertical invalidation conditions. | TESTED |
| VL-024 | `onTokensChanged` (`:322–324`) | Dirty only retained lines intersecting token ranges. | TESTED |
| VL-025 | `onZonesChanged` (`:325–328`) | Zones always invalidate ViewLines. | TESTED |
| VL-026 | `onThemeChanged` (`:329–331`) | Local theme is applied directly through CSS/root state. | N-A (no local theme-event contract) |
| VL-027 | wrapping-info width reset (`:190–192`) | Resets maximum line width on wrap changes. | DEFERRED (browser geometry dependency) |
| VL-028 | layout-info width reset (`:214–216`) | Resets maximum line width on layout changes. | DEFERRED (browser geometry dependency) |
| VL-029 | option equality (`:224–236`) | Invalidate retained lines iff ViewLineOptions changed. | TESTED |
| VL-030 | horizontal reveal cancellation (`:306–309`) | Horizontal change clears the pending horizontal reveal. | TESTED |
| VL-031 | vertical pending-and-top gate (`:310–317`) | Check a pending reveal only when scrollTop changed. | TESTED |
| VL-032 | normalized-band strictness (`:311–316`) | Cancel only strictly outside the normalized band; endpoints remain valid. | TESTED |
| VL-033 | visible-line factory callback (`:149–151`) | Source-owned `createLine` callback constructs `new ViewLine(viewGpuContext, this._viewLineOptions)` with current captured dependencies. | TESTED |

#### `viewLine.ts` retained-line inputs (`VLI`, 13 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| VLI-001 | `_options` (`:55,60,92,95`) | Retain last line options. | TESTED |
| VLI-002 | `_isMaybeInvalid` (`:56,61,82,85,88,91,96`) | Sticky maybe-invalid bit accumulates source changes. | TESTED |
| VLI-003 | `_renderedViewLine` (`:57,62,68–69,95`) | Retains the last renderer; ordinary invalidators only set `_isMaybeInvalid`. Clearing is confined to the excluded GPU render branch (`:103–106`). | TESTED |
| VLI-004 | `getDomNode` (`:67–72`) | Return DOM only when a rendered line exists. | TESTED |
| VLI-005 | `onContentChanged` (`:81–83`) | Mark maybe-invalid. | TESTED |
| VLI-006 | `onTokensChanged` (`:84–86`) | Mark maybe-invalid. | TESTED |
| VLI-007 | `onDecorationsChanged` (`:87–89`) | Mark maybe-invalid. | TESTED |
| VLI-008 | `onOptionsChanged` (`:90–93`) | Retain options and mark maybe-invalid. | TESTED |
| VLI-009 | `onSelectionChanged` (`:94–100`) | Re-render only when selection-sensitive output changed. | TESTED |
| VLI-010 | DOM-presence branch (`:68–71`) | Null before a rendered line exists; otherwise return its node. | TESTED |
| VLI-011 | selection-outcome branch (`:95–99`) | Mark maybe-invalid and return true iff high contrast is active or the prior renderer input used `renderWhitespace=Selection`; otherwise return false. | TESTED |
| VLI-012 | high-contrast selection predicate (`:95`) | Local product has no typed high-contrast theme branch. | N-A (no local high-contrast event contract) |
| VLI-013 | last-rendered Selection-whitespace predicate (`:95`) | Selection changes matter when the prior render used Selection whitespace. | TESTED |

#### `viewLayer.ts` interfaces (`VLCI`, 4 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| VLCI-001 | `IVisibleLine.getDomNode` (`:19`) | Visible-line DOM contract. | TESTED |
| VLCI-002 | `ILine.onContentChanged` (`:35`) | Retained-line content invalidation contract. | TESTED |
| VLCI-003 | `ILine.onTokensChanged` (`:36`) | Retained-line token invalidation contract. | TESTED |
| VLCI-004 | `ILineFactory.createLine` (`:40`) | Factory boundary for newly visible rows. | TESTED |

#### `viewLayer.ts` collection (`VLC`, 16 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| VLC-001 | `_linesCollection` (`:256,263,291–340`) | Own retained rendered lines. | TESTED |
| VLC-002 | `onConfigurationChanged` (`:277–282`) | Return true only when `layoutInfo` changed; do not flush the collection. | TESTED |
| VLC-003 | `onFlushed` (`:284–299`) | Flush collection and optional DOM/GPU state. | TESTED |
| VLC-004 | `onLinesChanged` (`:301–303`) | Forward to retained collection. | TESTED |
| VLC-005 | `onLinesDeleted` (`:305–316`) | Reconcile retained lines and optional DOM. | TESTED |
| VLC-006 | `onLinesInserted` (`:318–329`) | Reconcile retained lines and optional DOM. | TESTED |
| VLC-007 | `onScrollChanged` (`:331–333`) | Return exactly `scrollTopChanged`; horizontal-only changes stay false here. | TESTED |
| VLC-008 | `onTokensChanged` (`:335–337`) | Forward inclusive token ranges. | TESTED |
| VLC-009 | `onZonesChanged` (`:339–341`) | Zones always invalidate visible layout. | TESTED |
| VLC-010 | layout-info branch (`:278–281`) | Return true for `layoutInfo` change and false otherwise; do not flush. | TESTED |
| VLC-011 | `flushDom`/GPU branch (`:290–296`) | Local renderer has no GPU view-line path. | N-A (no GPU renderer) |
| VLC-012 | optional GPU DOM flush (`:294`) | Local renderer has no GPU DOM collection. | N-A (no GPU renderer) |
| VLC-013 | deleted-result null/non-null (`:307–313`) | Mutate DOM only when collection reports a deletion. | TESTED |
| VLC-014 | deleted optional DOM (`:310–311`) | Remove returned rendered nodes in order. | TESTED |
| VLC-015 | inserted-result null/non-null (`:320–326`) | Mutate DOM only when collection reports insertion. | TESTED |
| VLC-016 | inserted optional DOM (`:323–324`) | Remove returned displaced/deleted line DOM nodes; insertion never inserts these returned nodes. | TESTED |

#### `viewLayer.ts` rendered collection (`RLC`, 30 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| RLC-001 | `_lines` (`:44,58`) | Retained ordered line array. | TESTED |
| RLC-002 | `_rendLineNumberStart` (`:45,59`) | One-based first retained line. | TESTED |
| RLC-003 | `_lineFactory` (`:48,209`) | Creates inserted/tail lines. | TESTED |
| RLC-004 | constructor (`:47–51`) | Initializes with `_set(1, [])`. | TESTED |
| RLC-005 | `flush` (`:53–55`) | Reset collection to one/empty. | TESTED |
| RLC-006 | `_set` (`:57–60`) | Replace start and retained lines together. | TESTED |
| RLC-007 | `getStartLineNumber` (`:72–74`) | Return first retained line. | TESTED |
| RLC-008 | `getEndLineNumber` (`:79–81`) | Exact `start + length - 1`. | TESTED |
| RLC-009 | `getCount` (`:83–85`) | Return retained length. | TESTED |
| RLC-010 | `getLine` (`:87–93`) | Translate one-based line to retained index. | TESTED |
| RLC-011 | `onLinesDeleted` (`:98–154`) | Complete deletion reconciliation. | TESTED |
| RLC-012 | `onLinesChanged` (`:156–177`) | Complete changed-range propagation. | TESTED |
| RLC-013 | `onLinesInserted` (`:179–219`) | Complete insertion reconciliation. | TESTED |
| RLC-014 | `onTokensChanged` (`:221–250`) | Clip and propagate inclusive ranges. | TESTED |
| RLC-015 | `getLine` out-of-range throw (`:89–91`) | Local closed render loop never asks outside retained bounds. | N-A (unreachable through local retained-line API) |
| RLC-016 | deletion empty early return (`:99–102`) | Empty collection returns null. | TESTED |
| RLC-017 | deletion above shifts start (`:107–112`) | Inclusive above-range deletion shifts the retained start. | TESTED |
| RLC-018 | deletion below early return (`:114–117`) | Entire deletion below retained range returns null. | TESTED |
| RLC-019 | retained line in deletion interval (`:125–134`) | Remove every retained line covered by inclusive bounds. | TESTED |
| RLC-020 | first/later deletion accounting (`:127–133`) | Record first index/count, then increment count. | TESTED |
| RLC-021 | deletion starts above retained start (`:138–150`) | Adjust start and retained splice together. | TESTED |
| RLC-022 | nested `deleteTo < start` arm (`:142–145`) | Dominated by the earlier disjoint-range return at this pin. | N-A (source-unreachable nested branch) |
| RLC-023 | lines-changed empty branch (`:158–161`) | Empty collection returns false. | TESTED |
| RLC-024 | changed-range overlap (`:169–173`) | Notify each inclusive affected line and return true. | TESTED |
| RLC-025 | insertion empty early return (`:180–183`) | Empty collection returns null. | TESTED |
| RLC-026 | insertion at/above start (`:189–193`) | Inclusive insertion shifts retained start. | TESTED |
| RLC-027 | insertion below end early return (`:195–198`) | Entire insertion below retained window returns null. | TESTED |
| RLC-028 | insertion tail split (`:200–218`) | If insertion displaces every remaining line, splice and return them; otherwise create `insertCnt` lines, rebuild before+new+retained-after, and return the displaced tail. | TESTED |
| RLC-029 | tokens empty branch (`:222–225`) | Empty collection returns false. | TESTED |
| RLC-030 | token range clipping (`:234–246`) | Skip disjoint ranges; clip and notify inclusive overlap. | TESTED |

#### `viewCursors.ts` (`VC`, 40 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| VC-001 | `_readOnly` (`:34,60,115,236–239`) | Source caches and consumes the option in blinking selection; readonly Viewer constant-folds it true and tests that branch. | TESTED |
| VC-002 | `_cursorBlinking` (`:35,61,116`) | Cursor blinking style is absent locally. | N-A (no blinking-style option) |
| VC-003 | `_cursorStyle` (`:36,62,117`) | Source exposes cursor-style configuration; local rendering is fixed to Line. | DEFERRED (missing cursor-style option seam) |
| VC-004 | `_cursorSmoothCaretAnimation` (`:37,63,118`) | Source exposes smooth-caret configuration and reason-sensitive behavior. | DEFERRED (missing smooth-caret option seam) |
| VC-005 | `_editContextEnabled` (`:38,64,119`) | EditContext/composition is absent locally. | N-A (readonly input seam) |
| VC-006 | `_selectionIsEmpty` (`:39,65,168–172`) | Cache emptiness for cursor DOM class changes. | TESTED |
| VC-007 | `_isComposingInput` (`:40,66,102–110`) | Composition state is absent locally. | N-A (readonly input seam) |
| VC-008 | `_editorHasFocus` (`:50,86,183–186`) | Cache focus and update visibility/blinking state. | TESTED |
| VC-009 | `_primaryCursor` (`:52,70,124,135–136`) | Primary cursor consumes configuration/position updates. | TESTED |
| VC-010 | `_secondaryCursors` (`:53,71,125–158`) | Local Viewer is primary-cursor only. | N-A (single-cursor product boundary) |
| VC-011 | `_domNode` (`:44,74–79,96–98`) | Cursor container retained and rendered by local part. | TESTED |
| VC-012 | `onCompositionStart` (`:102–106`) | Composition producer is absent locally. | N-A (readonly input seam) |
| VC-013 | `onCompositionEnd` (`:107–111`) | Composition producer is absent locally. | N-A (readonly input seam) |
| VC-014 | `onConfigurationChanged` (`:112–129`) | Reread cursor configuration and dirty the part. | TESTED |
| VC-015 | `_onCursorPositionChanged` (`:130–160`) | Update primary position/blinking and plurality. | TESTED |
| VC-016 | `onCursorStateChanged` (`:161–175`) | Convert selections to positions, update emptiness, dirty. | TESTED |
| VC-017 | `onDecorationsChanged` (`:176–179`) | Inline decorations can relayout text; the local handler invalidates the cursor part. | TESTED |
| VC-018 | `onFlushed` (`:180–182`) | Always dirty. | TESTED |
| VC-019 | `onFocusChanged` (`:183–187`) | Mutate focus/blinking then return false; local render-write seam differs. | TESTED |
| VC-020 | `onLinesChanged` (`:188–190`) | Always dirty. | TESTED |
| VC-021 | `onLinesDeleted` (`:191–193`) | Always dirty. | TESTED |
| VC-022 | `onLinesInserted` (`:194–196`) | Always dirty. | TESTED |
| VC-023 | `onScrollChanged` (`:197–199`) | Always dirty. | TESTED |
| VC-024 | `onTokensChanged` (`:200–218`) | Dirty only if an inclusive range contains a cursor line. | TESTED |
| VC-025 | `onZonesChanged` (`:219–221`) | Always dirty. | TESTED |
| VC-026 | token-range callback (`:201–208`) | Inclusive range scan for one cursor position. | TESTED |
| VC-027 | secondary configuration loop (`:125–127`) | Local Viewer has no secondary cursors. | N-A (single-cursor product boundary) |
| VC-028 | cursor-count mismatch predicate (`:132`) | Secondary-cursor cardinality mismatch contributes to `pauseAnimation`. | N-A (single-cursor product boundary) |
| VC-029 | smooth-explicit reason predicate (`:133`) | Smooth-caret `explicit` plus a non-Explicit reason contributes to `pauseAnimation`. | DEFERRED (missing smooth-caret option seam) |
| VC-030 | plurality selection (`:135`) | MultiPrimary versus Single is absent locally. | N-A (single-cursor product boundary) |
| VC-031 | reused `pauseAnimation` constant (`:131–134,136,157`) | One computed constant is consumed by primary and every secondary cursor update. | DEFERRED (missing smooth-caret option/cardinality seam) |
| VC-032 | secondary creation (`:139–146`) | No local secondary cursor DOM. | N-A (single-cursor product boundary) |
| VC-033 | secondary removal (`:147–154`) | No local secondary cursor DOM. | N-A (single-cursor product boundary) |
| VC-034 | secondary position loop (`:156–158`) | No local secondary cursor positions. | N-A (single-cursor product boundary) |
| VC-035 | secondary positions slice (`:166`) | `positions.slice(1)` supplies only secondary positions; the local primary-only seam has no such slice. | N-A (single-cursor product boundary) |
| VC-036 | emptiness-cache branch (`:168–172`) | Update DOM class only when empty/nonempty changes. | TESTED |
| VC-037 | token inclusive hit (`:202–204`) | Both range endpoints include the cursor line. | TESTED |
| VC-038 | primary token hit early return (`:209–211`) | Return true before scanning secondaries. | TESTED |
| VC-039 | secondary token scan (`:212–216`) | No local secondary cursors. | N-A (single-cursor product boundary) |
| VC-040 | secondary token early hit (`:213–214`) | No local secondary cursors. | N-A (single-cursor product boundary) |

#### `contentWidgets.ts` invalidation cluster (`CW`, 21 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| CW-001 | `_widgets` (`:28,57–59,95–99`) | Iterate every retained widget for config/anchor refresh. | TESTED |
| CW-002 | `Widget._context` (`:191,217,251,261`) | Supplies configuration and model/view conversion. | TESTED |
| CW-003 | `_contentWidth` (`:201,232,255`) | Cache layout width used by placement. | TESTED |
| CW-004 | `_contentLeft` (`:202,233,254`) | Cache layout left used by placement. | TESTED |
| CW-005 | `_primaryAnchor` (`:204,261`) | Reproject primary anchor after mapping changes. | TESTED |
| CW-006 | `_secondaryAnchor` (`:205,261`) | Reproject secondary anchor after mapping changes. | TESTED |
| CW-007 | `_affinity` (`:206,235,261`) | Retained affinity participates in anchor validation/reprojection and is owned with widget placement. | DEFERRED (browser geometry dependency) |
| CW-008 | `_maxWidth` (`:210,239,256`) | Recompute on layout configuration. | TESTED |
| CW-009 | outer `onConfigurationChanged` (`:56–62`) | Notify every retained widget, refresh layoutInfo-gated caches, then dirty. | TESTED |
| CW-010 | `onDecorationsChanged` (`:63–66`) | Inline decorations can relayout text; the local handler dirties ContentWidgets. | TESTED |
| CW-011 | `onFlushed` (`:67–69`) | Always dirty. | TESTED |
| CW-012 | `onLineMappingChanged` (`:70–73`) | Reproject anchors then dirty. | TESTED |
| CW-013 | `onLinesChanged` (`:74–77`) | Reproject anchors then dirty. | TESTED |
| CW-014 | `onLinesDeleted` (`:78–81`) | Reproject anchors then dirty. | TESTED |
| CW-015 | `onLinesInserted` (`:82–85`) | Reproject anchors then dirty. | TESTED |
| CW-016 | `onScrollChanged` (`:86–88`) | Always dirty. | TESTED |
| CW-017 | `onZonesChanged` (`:89–91`) | Always dirty. | TESTED |
| CW-018 | `_updateAnchorsViewPositions` (`:95–100`) | Update every retained widget anchor in key order. | TESTED |
| CW-019 | `Widget.onConfigurationChanged` (`:250–258`) | Reread layout fields only when layoutInfo changed. | TESTED |
| CW-020 | `updateAnchorViewPosition` (`:260–262`) | Reapply retained affinity/model anchors. | TESTED |
| CW-021 | layoutInfo branch (`:252–257`) | Leave caches unchanged when layoutInfo did not change. | TESTED |

#### `currentLineHighlight.ts` (`CLH`, 27 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| CLH-001 | `_context` (`:20,37–45`) | Live configuration source. | TESTED |
| CLH-002 | `_renderLineHighlight` (`:21,41,90`) | Cache none/gutter/line/all mode. | TESTED |
| CLH-003 | `_wordWrap` (`:22,43,92`) | Cache viewport-wrapping state. | TESTED |
| CLH-004 | `_contentLeft` (`:23,44,93`) | Cache content left. | TESTED |
| CLH-005 | `_contentWidth` (`:24,45,94`) | Cache content width. | TESTED |
| CLH-006 | `_selectionIsEmpty` (`:25,46,74–77`) | Cache all-selections-empty result. | TESTED |
| CLH-007 | `_renderLineHighlightOnlyWhenFocus` (`:26,42,91`) | Gate focus invalidation/rendering. | TESTED |
| CLH-008 | `_focused` (`:27,47,121`) | Cache current focus. | TESTED |
| CLH-009 | `_cursorLineNumbers` (`:31,48,69–71`) | Unique sorted cursor-line cache. | TESTED |
| CLH-010 | `_selections` (`:32,49,64,74,98`) | Retain current selections. | TESTED |
| CLH-011 | constructor (`:35–53`) | Initialize option/focus/selection caches and register handler. | TESTED |
| CLH-012 | `dispose` (`:55–58`) | Remove handler before superclass disposal. | TESTED |
| CLH-013 | `_readFromSelections` (`:60–81`) | Recompute line set and emptiness with a changed accumulator. | TESTED |
| CLH-014 | `onThemeChanged` (`:84–86`) | Local theme is applied directly through CSS/root state. | N-A (no local theme-event contract) |
| CLH-015 | `onConfigurationChanged` (`:87–96`) | Reread highlight/layout options and always dirty. | TESTED |
| CLH-016 | `onCursorStateChanged` (`:97–100`) | Retain selections and return derived cache change. | TESTED |
| CLH-017 | `onFlushed` (`:101–103`) | Always dirty. | TESTED |
| CLH-018 | `onLinesDeleted` (`:104–106`) | Always dirty. | TESTED |
| CLH-019 | `onLinesInserted` (`:107–109`) | Always dirty. | TESTED |
| CLH-020 | `onScrollChanged` (`:110–112`) | Dirty only for width or top change. | TESTED |
| CLH-021 | `onZonesChanged` (`:113–115`) | Always dirty. | TESTED |
| CLH-022 | `onFocusChanged` (`:116–123`) | Dirty only in focus-only mode; update focus then true. | TESTED |
| CLH-023 | numeric comparator (`:68`) | Multi-cursor line-set sorting has no second cursor locally. | N-A (single-cursor product boundary) |
| CLH-024 | every-selection-empty predicate (`:74`) | All current selections must be empty. | TESTED |
| CLH-025 | cursor-line equality branch (`:69–72`) | Update only when unique sorted line set changes. | TESTED |
| CLH-026 | emptiness equality branch (`:75–78`) | Update only when empty/nonempty changes. | TESTED |
| CLH-027 | focus-only early return (`:117–119`) | Ignore focus changes when option is disabled. | TESTED |

The final ViewPart disposition is mechanically **148 TESTED, 8 DEFERRED, and
28 N-A = 184**. There are no PORTED rows in this slice: source-shaped local
seams already existed, while their event inputs, handlers, and evidence are
owned by the event/configuration slices below.

### Event and propagation ledger — 207 rows

| File | Lines | SHA-256 |
|---|---:|---|
| `common/viewEvents.ts` | 325 | `5259d6c440c38bf32ace131cae7a171bd036aca5dd123ffdf359bc220488cbd8` |
| `common/viewEventHandler.ts` | 220 | `1eb8aa7b6af6240b85684838155c8b2ed650e7f3bca26c73f8caf32e25d9b3d5` |
| `common/viewModelEventDispatcher.ts` | 591 | `64c5aee53d0bd580e8bb13d6f6ca563fcd02b8f78cf764ed0be87747f7d58448` |
| `common/viewModel/viewModelImpl.ts` | 1,472 | `b8b9f80ed51fa64c7baa4589aa99c2e2bab4eb365b025586e78d9b0db8f8e28a` |
| `browser/widget/codeEditor/codeEditorWidget.ts` | 2,559 | `18dd294ed185a29c590df75656f18f27d0cefc8d4d778559db946d447130e5d8` |

The `viewEvents.ts` boundary includes fifteen scoped event classes, including
declaration/dispatch-only Composition and Theme variants so the source union is closed. It excludes
only LanguageConfiguration (`:23,116–119`), RevealRange and
VerticalRevealType (`:28,184–230`), and TokensColors (`:32,288–295`).
Concrete composition/theme handlers remain N-A at the readonly/CSS seam, but
their typed declarations and dispatch arms are PORTED.
`viewEventHandler.ts` is complete. The RVD/RVMI rows include
only configuration, decoration, injected/content, and model-option propagation
clusters. RVC rows formally hand the generic queue/collector atoms deferred by
the now-frozen cursor child to this child without editing cursor history. The CodeEditorWidget boundary owns only
`updateOptions`; its configuration storage/notification lifecycle is inherited.

Frozen cursor `VED-003–007,009,015,019–041` and
`VMI-006,029–032` remain immutable handoff references, but their 35 render-owned
atoms now count once as RVC-001–035. Lifecycle
`CEW-001,012,052,064–065,070` and `CFG-001–020` remain inherited and outside
this denominator.
`ModelContentChangedEvent` wrapper construction belongs to the EOL child.
Tokenization owns token-range production while this child owns handler
consumption. Geometry owns StableViewport, custom-height, and attached-view
helper bodies. Branches and call order inside an inventoried RVMI method remain
on that owning method row; the helper declarations themselves are excluded.

#### `viewEvents.ts` (`VE`, 75 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| VE-001 | `ViewCompositionStart` enum (`:16`, numeric 0) | Semantic declaration/dispatch variant is present even though readonly Viewer has no producer. | PORTED |
| VE-002 | `ViewCompositionEnd` (`:17`, 1) | Semantic declaration/dispatch variant is present even though readonly Viewer has no producer. | PORTED |
| VE-003 | `ViewConfigurationChanged` (`:18`, 2) | Exact typed configuration event is present. | PORTED |
| VE-004 | `ViewCursorStateChanged` (`:19`, 3) | Variant carries consumed view/model selections and reason payload. | PORTED |
| VE-005 | `ViewDecorationsChanged` (`:20`, 4) | Existing event presence; preserve exact identity | TESTED |
| VE-006 | `ViewFlushed` (`:21`, 5) | Existing first-frame/flush semantic | TESTED |
| VE-007 | `ViewFocusChanged` (`:22`, 6) | Existing Bool payload semantic | TESTED |
| VE-008 | `ViewLineMappingChanged` (`:24`, 8) | Semantic mapping variant is present. | PORTED |
| VE-009 | `ViewLinesChanged` (`:25`, 9) | Variant carries exact from/count payload. | PORTED |
| VE-010 | `ViewLinesDeleted` (`:26`, 10) | Typed inclusive deletion payload is present even where production remains deferred. | PORTED |
| VE-011 | `ViewLinesInserted` (`:27`, 11) | Typed inclusive insertion payload is present even where production remains deferred. | PORTED |
| VE-012 | `ViewScrollChanged` (`:29`, 13) | Event carries exact new values and independent axis flags. | PORTED |
| VE-013 | `ViewTokensChanged` (`:31`, 15) | Distinct inclusive token-range event is present. | PORTED |
| VE-014 | `ViewZonesChanged` (`:33`, 17) | Existing semantic | TESTED |
| VE-015 | composition-start `type` (`:37`) | Source-shaped semantic variant; concrete producer remains absent. | PORTED |
| VE-016 | composition-start constructor (`:38`) | Empty typed event constructor. | PORTED |
| VE-017 | composition-end `type` (`:42`) | Source-shaped semantic variant; concrete producer remains absent. | PORTED |
| VE-018 | composition-end constructor (`:43`) | Empty typed event constructor. | PORTED |
| VE-019 | configuration `type` (`:48`) | Local enum discriminant | PORTED |
| VE-020 | configuration `_source` (`:50`) | Full changed-option bitset; current two booleans insufficient | PORTED |
| VE-021 | configuration constructor (`:52–54`) | Retain changed-option source unchanged | PORTED |
| VE-022 | `hasChanged` (`:56–58`) | Exact indexed option lookup | PORTED |
| VE-023 | cursor `type` (`:63`) | Local discriminant | PORTED |
| VE-024 | cursor `selections` (`:66`) | Required by ViewCursors and CurrentLine | PORTED |
| VE-025 | cursor `modelSelections` (`:67`) | Carry the complete source payload even though current scoped parts do not read it. | PORTED |
| VE-026 | cursor `reason` (`:68`) | Required by cursor animation/pause decision | PORTED |
| VE-027 | cursor constructor (`:65–69`) | Retain selections/modelSelections/reason | PORTED |
| VE-028 | decorations `type` (`:74`) | Existing semantic event identity | TESTED |
| VE-029 | `affectsMinimap` (`:76`) | Preserve the complete decoration payload for closed event parity. | PORTED |
| VE-030 | `affectsOverviewRuler` (`:77`) | Preserve the complete decoration payload for closed event parity. | PORTED |
| VE-031 | `affectsGlyphMargin` (`:78`) | Preserve the complete decoration payload for closed event parity. | PORTED |
| VE-032 | `affectsLineNumber` (`:79`) | Preserve the complete decoration payload for closed event parity. | PORTED |
| VE-033 | decorations constructor (`:81–93`) | Copy source flags; local model event owns facts | PORTED |
| VE-034 | null-source branch (`:82–92`) | Null forces all four flags true | PORTED |
| VE-035 | flushed `type` (`:98`) | Existing semantic discriminant | TESTED |
| VE-036 | flushed constructor (`:100–102`) | No payload | TESTED |
| VE-037 | focus `type` (`:107`) | Existing semantic discriminant | TESTED |
| VE-038 | `isFocused` (`:109`) | Exact current focus | TESTED |
| VE-039 | focus constructor (`:111–113`) | Retain flag | TESTED |
| VE-040 | line-mapping `type` (`:123`) | Local semantic variant is present. | PORTED |
| VE-041 | line-mapping constructor (`:125–127`) | No payload | PORTED |
| VE-042 | lines-changed `type` (`:132`) | Distinct line event | PORTED |
| VE-043 | `fromLineNumber` (`:138`) | One-based first changed view line | PORTED |
| VE-044 | `count` (`:142`) | Number of changed view lines | PORTED |
| VE-045 | lines-changed constructor (`:134–143`) | Retain from/count | PORTED |
| VE-046 | lines-deleted `type` (`:148`) | Distinct deletion event | PORTED |
| VE-047 | deleted `fromLineNumber` (`:153`) | Inclusive start | PORTED |
| VE-048 | deleted `toLineNumber` (`:157`) | Inclusive end | PORTED |
| VE-049 | deleted constructor (`:159–162`) | Retain bounds | PORTED |
| VE-050 | lines-inserted `type` (`:167`) | Distinct insertion event | PORTED |
| VE-051 | inserted `fromLineNumber` (`:172`) | First inserted view line | PORTED |
| VE-052 | inserted `toLineNumber` (`:176`) | Inclusive; count=`to-from+1` | PORTED |
| VE-053 | inserted constructor (`:178–181`) | Retain bounds | PORTED |
| VE-054 | scroll `type` (`:234`) | Existing event needs exact payload | PORTED |
| VE-055 | `scrollWidth` (`:236`) | Exact new width; ViewLines writes it | PORTED |
| VE-056 | `scrollLeft` (`:237`) | Exact new left | PORTED |
| VE-057 | `scrollHeight` (`:238`) | Exact new height | PORTED |
| VE-058 | `scrollTop` (`:239`) | Exact new top; reveal cancellation reads it | PORTED |
| VE-059 | `scrollWidthChanged` (`:241`) | Independent flag; CurrentLine consumes | PORTED |
| VE-060 | `scrollLeftChanged` (`:242`) | Independent flag; ViewLines consumes | PORTED |
| VE-061 | `scrollHeightChanged` (`:243`) | Independent payload field | PORTED |
| VE-062 | `scrollTopChanged` (`:244`) | Independent flag; ViewLines/CurrentLine consume | PORTED |
| VE-063 | scroll constructor (`:246–256`) | Copy values first, then flags | PORTED |
| VE-064 | tokens `type` (`:270`) | Distinct token event is present. | PORTED |
| VE-065 | tokens `ranges` (`:272–281`) | Ordered inclusive view-line ranges | PORTED |
| VE-066 | range `fromLineNumber` (`:276`) | Inclusive | PORTED |
| VE-067 | range `toLineNumber` (`:280`) | Inclusive | PORTED |
| VE-068 | tokens constructor (`:283–285`) | Retain range array | PORTED |
| VE-069 | zones `type` (`:299`) | Existing semantic discriminant | TESTED |
| VE-070 | zones constructor (`:301–303`) | No payload | TESTED |
| VE-071 | `ViewEvent` alias (`:306–325`) | Closed typed union over 15 scoped classes, including declaration-only Composition/Theme; excludes only LanguageConfiguration, RevealRange/VerticalRevealType, and TokensColors. | PORTED |
| VE-072 | `ViewThemeChanged` enum (`:30`, numeric 14) | Typed theme declaration/dispatch variant is present; concrete local theme handling remains CSS-owned. | PORTED |
| VE-073 | theme `type` (`:261`) | Constant `ViewThemeChanged` discriminant. | PORTED |
| VE-074 | `theme` field (`:264`) | Source carries `IColorTheme`; reviewed local declaration carries the existing `String` theme identity, with no typed producer/handler. | PORTED |
| VE-075 | theme constructor (`:263–265`) | Retain the reviewed `IColorTheme`→`String` identity reduction in a declaration-only event with no typed producer or concrete handler. | PORTED |

#### `viewEventHandler.ts` (`VEH`, 45 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| VEH-001 | `_shouldRender` (`:11`) | Per-part sticky dirty bit | TESTED |
| VEH-002 | constructor (`:13–16`) | Starts dirty=true | TESTED |
| VEH-003 | `shouldRender` (`:18–20`) | Return bit | TESTED |
| VEH-004 | `forceShouldRender` (`:22–24`) | Idempotently set true | TESTED |
| VEH-005 | `setShouldRender` (`:26–28`) | Same transition for part mutation | TESTED |
| VEH-006 | `onDidRender` (`:30–32`) | Clear after write | TESTED |
| VEH-007 | composition-start default false (`:36–38`) | Typed base-handler default is observable even without a readonly producer. | TESTED |
| VEH-008 | composition-end default false (`:39–41`) | Typed base-handler default is observable even without a readonly producer. | TESTED |
| VEH-009 | configuration default false (`:42–44`) | Per-concrete match/wildcard | TESTED |
| VEH-010 | cursor default false (`:45–47`) | Same | TESTED |
| VEH-011 | decorations default false (`:48–50`) | Same | TESTED |
| VEH-012 | flushed default false (`:51–53`) | Same | TESTED |
| VEH-013 | focus default false (`:54–56`) | Same | TESTED |
| VEH-014 | language-config default false (`:57–59`) | Language-configuration event is an excluded sibling. | N-A (language-configuration event excluded from this child) |
| VEH-015 | line-mapping default false (`:60–62`) | Event/default branch is present. | PORTED |
| VEH-016 | lines-changed default false (`:63–65`) | Existing per-part matches | TESTED |
| VEH-017 | lines-deleted default false (`:66–68`) | Event/default branch is present. | PORTED |
| VEH-018 | lines-inserted default false (`:69–71`) | Event/default branch is present. | PORTED |
| VEH-019 | reveal default false (`:72–74`) | Historical reveal-owned handler declaration. | DEFERRED (historical reveal-handler dependency) |
| VEH-020 | scroll default false (`:75–77`) | Payload/axes incomplete | PORTED |
| VEH-021 | theme default false (`:78–80`) | Typed base-handler default is observable while concrete CSS delivery remains N-A. | TESTED |
| VEH-022 | tokens default false (`:81–83`) | Distinct event/default branch is present. | PORTED |
| VEH-023 | token-colors default false (`:84–86`) | Token-color/theme event is an excluded sibling. | N-A (token-colors event excluded from this child) |
| VEH-024 | zones default false (`:87–89`) | Existing | TESTED |
| VEH-025 | `handleEvents` (`:93–219`) | Ordered loop, local accumulator false | PORTED |
| VEH-026 | composition-start dispatch (`:102–106`) | Dispatch the declaration-only variant; base default-false behavior is TESTED, while concrete ViewCursors composition override remains N-A. | PORTED |
| VEH-027 | composition-end dispatch (`:108–112`) | Dispatch the declaration-only variant; base default-false behavior is TESTED, while concrete ViewCursors composition override remains N-A. | PORTED |
| VEH-028 | configuration dispatch (`:114–118`) | Complete event/payload reaches every part. | PORTED |
| VEH-029 | cursor dispatch (`:120–124`) | Complete payload is dispatched in source order. | PORTED |
| VEH-030 | decorations dispatch (`:126–130`) | Dispatch and all scoped consumers are present. | PORTED |
| VEH-031 | flushed dispatch (`:132–136`) | Existing | TESTED |
| VEH-032 | focus dispatch (`:138–142`) | Existing | TESTED |
| VEH-033 | language-config dispatch (`:144–148`) | Language-configuration event is an excluded sibling. | N-A (language-configuration event excluded from this child) |
| VEH-034 | line-mapping dispatch (`:150–154`) | Semantic mapping dispatch is present. | PORTED |
| VEH-035 | lines-changed dispatch (`:156–160`) | Exact payload dispatch is present. | PORTED |
| VEH-036 | lines-deleted dispatch (`:162–166`) | Inclusive deletion dispatch is present. | PORTED |
| VEH-037 | lines-inserted dispatch (`:168–172`) | Inclusive insertion dispatch is present. | PORTED |
| VEH-038 | reveal dispatch (`:174–178`) | Historical reveal-owned dispatch arm. | DEFERRED (historical reveal-handler dependency) |
| VEH-039 | scroll dispatch (`:180–184`) | Exact values and independent flags are dispatched. | PORTED |
| VEH-040 | tokens dispatch (`:186–190`) | Distinct inclusive ranges are dispatched. | PORTED |
| VEH-041 | theme dispatch (`:192–196`) | Dispatch typed theme events; concrete local theme handler remains CSS-owned. | PORTED |
| VEH-042 | token-colors dispatch (`:198–202`) | Token-color/theme event is an excluded sibling. | N-A (token-colors event excluded from this child) |
| VEH-043 | zones dispatch (`:204–208`) | Existing | TESTED |
| VEH-044 | unknown-event logging (`:210–213`) | A closed MoonBit event enum cannot contain an unknown runtime tag. | N-A (unknown event tag unrepresentable in closed enum) |
| VEH-045 | accumulated final branch (`:216–218`) | Set sticky dirty iff any true; false never clears | TESTED |

#### frozen-cursor collector handoff (`RVC`, 35 rows)

These rows formally transfer the frozen cursor plan's render deferrals into
this denominator. The frozen VED/VMI IDs remain immutable references.

| ID | Source atom / frozen row | Planned local disposition | Status |
|---|---|---|---|
| RVC-001 | VED-003; `viewModelEventDispatcher.ts:20` `_eventHandlers` ordered handler array | `View.view_parts` retains the fixed ordered handle array; test complete batch order. | TESTED |
| RVC-002 | VED-004; `:21` `_viewEventQueue` null or ordered event array | Source-shaped pending typed view-event batch queue. | PORTED |
| RVC-003 | VED-005; `:22` `_isConsumingViewEventQueue` reentrancy gate | Explicit consuming bit for reentrant typed-event enqueue. | PORTED |
| RVC-004 | VED-006; `:23` `_collector` current nested collector/null | Pending typed collector slot. | PORTED |
| RVC-005 | VED-007; `:24` `_collectorCnt` nested depth | Exact depth counter. | PORTED |
| RVC-006 | VED-009; `:27–35` constructor initialization | Prove corresponding fixed-handles, view-queue/collector, and inherited outgoing-FIFO initial state. | TESTED |
| RVC-007 | VED-015; `:56–59` active collector/consumption postpones outgoing drain | Cursor/public outgoing FIFO and direct model subscriptions are not unified with the render collector. | DEFERRED (unified view/outgoing delivery seam; frozen cursor FIFO remains authoritative) |
| RVC-008 | VED-019; `:68–73` add-handler duplicate scan/warn | Runtime registration cannot occur because View owns one closed handle set. | N-A (fixed ViewPart membership; prove callbacks cannot register a part) |
| RVC-009 | VED-020; `:74` append handler after scan | Same fixed-membership seam. | N-A (fixed ViewPart membership) |
| RVC-010 | VED-021; `:77–84` remove first identical handler | Parts live and die with View and cannot remove themselves during dispatch. | N-A (fixed ViewPart membership; no per-handler removal API) |
| RVC-011 | VED-022; `:86–87` begin increments depth first | Exact transition. | TESTED |
| RVC-012 | VED-023; `:88–90` depth exactly 1 creates collector | Exact outermost-creation gate. | TESTED |
| RVC-013 | VED-024; `:91` nested begin returns same collector | Collector identity under nesting. | TESTED |
| RVC-014 | VED-025; `:94–96` end decrements; only zero flushes | Exact nested/outermost behavior. | TESTED |
| RVC-015 | VED-026; `:97–99` capture arrays then null collector | Captures both view and outgoing arrays before nulling; the outgoing half remains unavailable locally. | DEFERRED (mixed capture requires unified outgoing collector seam) |
| RVC-016 | VED-027; `:101–103` collected outgoing events enter merge queue in order | Separate outgoing FIFO is not fed from the view collector. | DEFERRED (unified view/outgoing delivery seam) |
| RVC-017 | VED-028; `:105–107` nonempty view events precede final outgoing drain | Cross-channel order is unprovable while model/decor events use direct subscriptions. | DEFERRED (unified view/outgoing delivery seam plus RVD direct-subscription seam) |
| RVC-018 | VED-029; `:109` final outgoing drain after every end | Same absent coupling. | DEFERRED (unified view/outgoing delivery seam) |
| RVC-019 | VED-030; `:112–119` emit one event with begin/append/end in `finally` | Exact single-event transaction. | TESTED |
| RVC-020 | VED-031; `:121–126` concatenate reentrant events or install first batch | Exact FIFO batch append. | TESTED |
| RVC-021 | VED-032; `:128–130` consume only when not already consuming | Exact reentrancy gate. | TESTED |
| RVC-022 | VED-033; `:133–140` set consuming, drain, restore in `finally` | Exact failure-safe gate. | N-A (deliver and ViewPart callbacks are statically non-raising; escaping handler failure is unrepresentable) |
| RVC-023 | VED-034; `:142–147` snapshot/clear queue before handlers | Reentrant events form a later, non-interleaved batch. | TESTED |
| RVC-024 | VED-035; `:148–149` clone handler list before callbacks | Closed ViewPart set cannot remove/register during dispatch. | N-A (fixed immutable membership during a frame) |
| RVC-025 | VED-036; `:150–152` every handler receives whole batch in registration order | Dispatch the complete batch to fixed handles in source order. | TESTED |
| RVC-026 | VED-037; `:159` collector `viewEvents` field | Typed ordered view-event array. | PORTED |
| RVC-027 | VED-038; `:160` collector `outgoingEvents` field | Common outgoing collector storage is absent while RVD uses direct subscriptions. | DEFERRED (unified outgoing collector seam) |
| RVC-028 | VED-039; `:162–165` collector constructor | View-array initialization is implemented, but the same constructor's outgoing-array state needs the unified seam. | DEFERRED (mixed constructor requires unified outgoing collector seam) |
| RVC-029 | VED-040; `:167–169` `emitViewEvent` | Append one typed event in order. | TESTED |
| RVC-030 | VED-041; `:171–173` `emitOutgoingEvent` | Common collector append is absent while outgoing events use separate/direct delivery. | DEFERRED (unified outgoing collector seam) |
| RVC-031 | VMI-006; `viewModelImpl.ts:462–469` content/injected delivery transaction | Bracket typed view production; inherited physical-model FIFO retains content-before-cursor, while event construction stays EOL-owned. | TESTED |
| RVC-032 | VMI-029; `:1262–1266` batch target precedes `_emitViewEvent` | Local frame scheduling coalesces but has no source-equivalent batchable target. | DEFERRED (explicit IBatchableTarget/nested-batch seam) |
| RVC-033 | VMI-030; `:1268–1271` begin collector, invoke callback, return result | Exact generic callback/result path. | TESTED |
| RVC-034 | VMI-031; `:1272–1274` dispatcher end in `finally` | Exact failure/early-return cleanup. | TESTED |
| RVC-035 | VMI-032; `:1277–1279` `batchEvents` ignores Unit result | No local batchEvents/transactional-target API. | DEFERRED (RVC-032 batchable-target seam) |

#### render-owned `viewModelEventDispatcher.ts` (`RVD`, 14 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| RVD-001 | ModelDecorations arm (`:185`) | Direct model subscription bypasses the outgoing union. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-002 | decorations kind (`:204`, numeric 8) | No local outgoing model-decoration surface. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-003 | class `kind` (`:466`) | Constant kind for the missing outgoing event. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-004 | `event` field (`:469`) | Exact model decoration payload for outgoing delivery. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-005 | constructor (`:468–470`) | Retain the outgoing decoration event. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-006 | `isNoOp=false` (`:472–474`) | Never suppress outgoing decoration delivery. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-007 | merge always null (`:476–478`) | Never coalesce outgoing decoration delivery. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-008 | ModelOptions arm (`:189`) | Direct model subscription has no local outgoing options event. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-009 | options kind (`:208`, numeric 12) | No local outgoing model-options surface. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-010 | class `kind` (`:530`) | Constant kind for the missing outgoing event. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-011 | `event` field (`:533`) | Exact model-options payload for outgoing delivery. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-012 | constructor (`:532–534`) | Retain the outgoing options event. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-013 | `isNoOp=false` (`:536–538`) | Never suppress outgoing options delivery. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVD-014 | merge always null (`:540–542`) | Never coalesce outgoing options delivery. | DEFERRED (direct-model-subscription/outgoing-event seam) |

#### render-owned `viewModelImpl.ts` (`RVMI`, 36 rows)

Gate-B amendment mapping: old RVMI-001→001; old 002 splits into new
002–003; old 003–007→004–008; geometry-owned old 008–009 are removed; old
010–031→009–030; geometry-owned callback old 032 is removed; old
033–038→031–036. StableViewport/custom-height helper bodies remain in the
geometry denominator; geometry-dependent caller branches retained here are
explicitly deferred.

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| RVMI-001 | `_configuration` (`:54`) | Live option source. | TESTED |
| RVMI-002 | `_updateConfigurationViewLineCount` field and delay (`:59,89`) | Own one RunOnceScheduler with exact delay `0`. | DEFERRED (line-count configuration scheduler seam) |
| RVMI-003 | scheduler callback (`:89`) | Source-owned callback invokes `_updateConfigurationViewLineCountNow()`. | DEFERRED (line-count configuration scheduler seam) |
| RVMI-004 | `_decorations` (`:66,146`) | Live cache owner after line/layout construction. | TESTED |
| RVMI-005 | fast-configuration callback (`:150–157`) | Begin collector, call configuration handler, end in `finally`. | PORTED |
| RVMI-006 | add handler (`:191–193`) | Runtime registration is impossible with fixed local View membership. | N-A (fixed ViewPart membership) |
| RVMI-007 | remove handler (`:195–197`) | Runtime removal is impossible with fixed local View membership. | N-A (fixed ViewPart membership) |
| RVMI-008 | update view-line count (`:218–220`) | Copy the current ViewModel line count into configuration. | DEFERRED (editor-configuration view-line-count synchronization seam) |
| RVMI-009 | `_onConfigurationChanged` (`:274–314`) | Preserve event/cache ordering; stable-viewport geometry and line-count scheduler calls remain explicitly deferred in their owning rows. | PORTED |
| RVMI-010 | wrapping branch (`:283–292`) | Flush→mapping→decor event→cursor→decor cache→layout→schedule; exact tail depends on the deferred line-count scheduler. | DEFERRED (line-count configuration scheduler seam) |
| RVMI-011 | readonly branch (`:294–298`) | A changed readonly option resets decorations then emits Decorations. | N-A (readonly Viewer cannot change its fixed readonly state) |
| RVMI-012 | validation branch (`:300–303`) | Reset decorations then emit Decorations. | PORTED |
| RVMI-013 | cursor recreation (`:310–313`) | Recreate configuration and update inherited cursor owner. | TESTED |
| RVMI-014 | content/injected method (`:319–457`) | Collector, two passes, projection/layout/events, then recovery tail. | DEFERRED (whole-document Flush/injected reduction omits incremental two-pass and recovery tail) |
| RVMI-015 | changes source (`:327`) | Internal raw changes versus injected changes. | TESTED |
| RVMI-016 | version source (`:328`) | Internal content version versus injected null. | DEFERRED (incremental content-version source and acceptance seam absent) |
| RVMI-017 | first-pass Inserted (`:334–339`) | Request one break computation per inserted line. | DEFERRED (incremental line-projection production seam) |
| RVMI-018 | first-pass LineChanged (`:340–343`) | Request one post-edit break computation. | DEFERRED (incremental line-projection production seam) |
| RVMI-019 | Flush (`:356–363`) | Flush lines→event→decor reset→layout→`hadOther`. | TESTED |
| RVMI-020 | LinesDeleted (`:364–373`) | Always sets `hadOther=true`. | DEFERRED (incremental line-deletion projection seam) |
| RVMI-021 | non-null delete result (`:366–370`) | Emit deletion, update layout, then collect height range. | DEFERRED (incremental line-deletion projection seam) |
| RVMI-022 | LinesInserted (`:374–383`) | Take exact inserted count and set `hadOther=true`. | DEFERRED (incremental line-insertion projection seam) |
| RVMI-023 | non-null insert result (`:377–381`) | Emit insertion, update layout, then collect post-edit range. | DEFERRED (incremental line-insertion projection seam) |
| RVMI-024 | LineChanged (`:385–404`) | Dequeue result; overwrite mapping flag rather than OR. | DEFERRED (incremental line-change projection seam) |
| RVMI-025 | optional Changed event (`:390–392`) | Emit Changed first. | DEFERRED (incremental line-change projection seam) |
| RVMI-026 | optional Inserted event (`:393–397`) | Emit Inserted second, then update layout/range. | DEFERRED (incremental line-change projection seam) |
| RVMI-027 | optional Deleted event (`:398–402`) | Emit Deleted third, then update layout/range. | DEFERRED (incremental line-change projection seam) |
| RVMI-028 | EOLChanged (`:405–408`) | No projection action; version acceptance still follows. | DEFERRED (text-buffer EOL event dependency) |
| RVMI-029 | non-null version (`:412–414`) | Accept only an actual content version. | DEFERRED (incremental content-version acceptance seam) |
| RVMI-030 | custom-height ranges nonempty (`:417–426`) | Apply deferred height ranges only after projections stabilize. | DEFERRED (browser geometry custom-height dependency) |
| RVMI-031 | mapping-only tail (`:430–435`) | Mapping event→decor event→cursor→decor cache when no other event occurred. | DEFERRED (incremental line-mapping projection seam) |
| RVMI-032 | multi-editor recovery gate (`:447–454`) | Exact `!focus && attached>=2 && prior valid` caller gate. | DEFERRED (browser geometry attached-view recovery dependency) |
| RVMI-033 | tracked-range-present branch (`:449–453`) | Convert range and set immediate scrollTop plus retained delta. | DEFERRED (browser geometry attached-view recovery dependency) |
| RVMI-034 | model-options callback (`:538–559`) | Tab work, cursor config, then outgoing options event last. | DEFERRED (direct-model-subscription/outgoing-event seam) |
| RVMI-035 | tab-size changed branch (`:540–553`) | Flush→mapping→decor→cursor/cache→layout→schedule; exact tail depends on the deferred line-count scheduler. | DEFERRED (line-count configuration scheduler seam) |
| RVMI-036 | decorations callback (`:561–565`) | Cache first→view event second→outgoing decoration event third. | DEFERRED (direct-model-subscription/outgoing-event seam) |

#### `codeEditorWidget.updateOptions` (`CEWU`, 2 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| CEWU-001 | `updateOptions` (`:445–447`) | Delegate once; Viewer update must complete notification/invalidation | PORTED |
| CEWU-002 | default-empty `newOptions` branch (`:446`) | Source uses `newOptions` or an empty object; MoonBit argument is concrete/nonoptional. | N-A (no optional options argument) |

The final event disposition is mechanically **52 TESTED, 90 PORTED, 51
DEFERRED, and 14 N-A = 207**. Composition/Theme declarations and dispatch arms
are present while concrete readonly/CSS handlers remain explicit seams;
`VE-071` closes fifteen included event classes. Closing review downgraded the
unrepresentable dispatcher-throw branch and the wholesale content/version
overclaims recorded in RVC-022 and RVMI-014/016.

### Configuration and local-option ledger — 172 rows

| File | Lines | SHA-256 |
|---|---:|---|
| `browser/config/editorConfiguration.ts` | 358 | `84d3e1369bd70b9fbe7d9f6bf1c2154c594749e88fbed83606f8477c979c1128` |
| `common/config/editorOptions.ts` | 6,869 | `8f24aa725cbab484d78588985d7ed657efc8449d784063b2bbaa85cd8482d8f0` |
| `browser/config/migrateOptions.ts` | 260 | `9e3341a56e40127f083cc527bf7a5937f911f18704cab74f33bee6cf479fa800` |

The ECF boundary retains 33 render-relevant configuration atoms and ECS owns
13 setter/caller atoms; their shared `_recomputeOptions` callee remains frozen
lifecycle authority. Frozen lifecycle `CFG-001–020` owns both emitters/public
aliases, the container
observer, constructor and automatic-layout branch, seven external recompute
subscriptions, `_recomputeOptions` and its unchanged return, target-window
binding, accessibility-service field, `_readFontInfo`, and disposal. Those
atoms are inherited references and are not duplicated here. Retained field
citations omit constructor/recompute lines already owned by CFG.

ECX owns the complete `getExtraEditorClassName` helper and its independent
browser/macOS branches. Its local target is a pure platform-class function
consumed by the existing Viewer root-class builder; browser geometry owns no
part of this string-only behavior.

ECU covers the complete validated/computed storage and equality/update
machinery needed to classify the typed local seam. EOP/EOB include the generic
option primitives and complete declarations/dependencies/defaults for
fixed `readOnly`, `renderWhitespace`, `renderControlCharacters`, `renderLineHighlight`,
`renderLineHighlightOnlyWhenFocus`, and
`renderValidationDecorations`; unrelated editor options are excluded.
MIG includes the generic migration machinery (`:8–79`) and exactly the two
scoped registrations (`:84–85`); migrations for unrelated editor options
(`:86–260`) are excluded siblings.

#### retained `EditorConfiguration` cluster (`ECF`, 33 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| ECF-001 | `IEditorConstructionOptions.dimension` (`editorConfiguration.ts:28–32`) | Optional initial dimensions avoid measuring the container. Local `Viewer::layout`/measurement belongs to geometry. | DEFERRED (browser geometry dimension seam) |
| ECF-006 | `isSimpleWidget` field and compute dependency (`editorConfiguration.ts:48,118`) | Immutable widget-kind input participates in bare-font computation. Constructor assignment at `:81` is frozen under CFG-004 and is not recounted. Local: Single readonly widget kind | N-A (no widget-kind axis) |
| ECF-008 | `_isDominatedByLongLines = false` (`editorConfiguration.ts:52`) | Environmental computed-option input starts false. Local: All five owned render options are `SimpleEditorOption` identity values | N-A (no dependency in this slice) |
| ECF-009 | `_viewLineCount = 1` (`editorConfiguration.ts:53`) | Environmental view-line count starts at one; local ViewModel owns and reads the direct current count. | TESTED |
| ECF-010 | `_lineNumbersDigitCount = 1` (`editorConfiguration.ts:54`) | Environmental digit-count input starts at one; local gutter digits expose the equivalent fact. | TESTED |
| ECF-011 | `_reservedHeight = 0` (`editorConfiguration.ts:55`) | Initial height subtraction is zero. | N-A (no dependency in this slice) |
| ECF-012 | `_glyphMarginDecorationLaneCount = 1` (`editorConfiguration.ts:56`) | Environmental glyph-lane count starts at one. | N-A (no dependency in this slice) |
| ECF-014 | `_computeOptionsMemory` (`editorConfiguration.ts:59`) | Persistent memory is reused across option computations. Local: No owned option uses compute memory | N-A (source state absent from typed local seam) |
| ECF-015 | `_rawOptions` field (`editorConfiguration.ts:63`) | Stores caller-shaped options separately from validated/computed state. Initial assignment at `:86` is frozen under CFG-004. Local: `Viewer.options` is a typed complete snapshot | N-A (no raw/partial layer) |
| ECF-016 | `_validatedOptions` field (`editorConfiguration.ts:67`) | Stores canonical validated values separately. Initial assignment at `:87` is frozen under CFG-004. Local: `ViewerOptions` makes enum/Bool inputs valid by construction | N-A (no untyped validation layer) |
| ECF-017 | `options` field (`editorConfiguration.ts:71`) | Current complete computed snapshot. Initial assignment at `:88` and recompute assignment at `:111` remain frozen-owned. Local: `Viewer.options` (`viewer/viewer.mbt:23`) | TESTED |
| ECF-030 | `_computeOptions` (`editorConfiguration.ts:116-138`) | Read partial environment and font facts, build `IEnvironmentalOptions`, then compute every registry option in registry order. The five owned render options return their validated values unchanged. Local: Direct `ViewerOptions` fields | TESTED |
| ECF-031 | reserved-height arithmetic (`editorConfiguration.ts:123`) | Computed `outerHeight = partialEnv.outerHeight - _reservedHeight`. | N-A (no dependency in the five-option slice) |
| ECF-032 | tab-focus fallback (`editorConfiguration.ts:131`) | Validated true wins; otherwise read global `TabFocus`. | N-A (no dependency in the five-option slice) |
| ECF-033 | `_readEnvConfiguration` (`editorConfiguration.ts:140-145,147-155`) | Produces class, dimensions, browser clipboard, EditContext, and accessibility facts. Target-window PixelRatio line `:146` is excluded as frozen CFG-016. Local: Owned render options are environment-independent | N-A (for this slice) |
| ECF-034 | empty-selection clipboard branch (`editorConfiguration.ts:145`) | True exactly for WebKit or Firefox. | N-A (source state absent from typed local seam) |
| ECF-036 | EditContext support branch (`editorConfiguration.ts:147-148`) | True exactly when `globalThis.EditContext` is a function. | N-A (source state absent from typed local seam) |
| ECF-037 | accessibility branch (`editorConfiguration.ts:149-153`) | Screen-reader optimized forces `Enabled`; otherwise use service-reported support. Local: No accessibility service | DEFERRED (service seam) |
| ECF-039 | `getRawOptions` (`editorConfiguration.ts:161-163`) | Returns raw options, not validated or computed options. Local: Local `get_options` returns the typed complete snapshot | N-A (no raw view) |
| ECF-040 | `updateOptions` (`editorConfiguration.ts:165-175`) | Clone/migrate partial input, apply raw update, return on raw no-op, validate all options, then invoke recomputation once. Local: `Viewer::update_options` (`viewer/viewer.mbt:535-569`) covers observable owned-option behavior; partial/raw mechanics are a deviation. | TESTED |
| ECF-041 | per-call clone and migration (`editorConfiguration.ts:166`) | Protect caller input and canonicalize legacy values before applying it. Local: Immutable typed snapshot | N-A (legacy migration separately inventoried) |
| ECF-042 | raw `applyUpdate` invocation (`editorConfiguration.ts:168`) | Only supplied own properties participate; local API instead receives one complete `ViewerOptions` snapshot. | DEFERRED (complete-snapshot versus partial-update API deviation) |
| ECF-043 | raw no-change early return (`editorConfiguration.ts:169-171`) | Skip validation, recomputation, assignment, and events. Local: Whole-snapshot equality guard at `viewer/viewer.mbt:536-538` | TESTED |
| ECF-044 | revalidation after raw change (`editorConfiguration.ts:173`) | Validate the complete raw registry after any raw update. Local: Enum/Bool values are statically valid | N-A (source state absent from typed local seam) |
| ECF-045 | post-validation recompute invocation (`editorConfiguration.ts:174`) | Invoke recomputation exactly once after validation. `_recomputeOptions` itself is frozen CFG-013. Local: One `Viewer::on_configuration_changed` route | TESTED |
| ECF-046 | `IEnvConfiguration.extraEditorClassName` (`editorConfiguration.ts:248-249`) | Partial environment payload field. | N-A (no five-option dependency) |
| ECF-047 | `IEnvConfiguration.outerWidth` (`editorConfiguration.ts:250`) | Partial environment payload field. | N-A (source state absent from typed local seam) |
| ECF-048 | `IEnvConfiguration.outerHeight` (`editorConfiguration.ts:251`) | Partial environment payload field. | N-A (source state absent from typed local seam) |
| ECF-049 | `IEnvConfiguration.emptySelectionClipboard` (`editorConfiguration.ts:252`) | Partial environment payload field. | N-A (source state absent from typed local seam) |
| ECF-050 | `IEnvConfiguration.pixelRatio` (`editorConfiguration.ts:253`) | Partial environment payload field. | N-A (source state absent from typed local seam) |
| ECF-051 | `IEnvConfiguration.accessibilitySupport` (`editorConfiguration.ts:254`) | Partial environment payload field. | N-A (source state absent from typed local seam) |
| ECF-052 | `IEnvConfiguration.editContextSupported` (`editorConfiguration.ts:255`) | Partial environment payload field. | N-A (source state absent from typed local seam) |
| ECF-053 | `deepCloneAndMigrateOptions` (`editorConfiguration.ts:354-358`) | `objects.deepClone` strictly precedes `migrateOptions`. Local: Typed immutable snapshot | N-A (migration cluster separately inventoried) |

#### `EditorConfiguration` environmental setters (`ECS`, 13 rows)

These caller methods are render-owned even though their shared
`_recomputeOptions` callee remains frozen lifecycle `CFG-013`. Each method row
owns assignment/call order; its equality early return is independent.

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| ECS-001 | `setIsDominatedByLongLines` (`editorConfiguration.ts:181–187`) | Assign the changed fact then recompute once. | N-A (no minimap/long-line-dominance option) |
| ECS-002 | long-lines equality return (`:182–184`) | Exact equality exits before assignment/recompute. | N-A (no minimap/long-line-dominance option) |
| ECS-003 | `setModelLineCount` (`:189–196`) | Derive decimal digit count, assign a changed count, then recompute once. | TESTED |
| ECS-004 | model-digit equality return (`:191–193`) | Equal digit bands exit even when raw line count changed. | TESTED |
| ECS-005 | `setViewLineCount` (`:198–204`) | Assign changed view-line count then recompute once. | DEFERRED (no EditorConfiguration setViewLineCount/recompute API; raw view-line identity is retained locally) |
| ECS-006 | view-line equality return (`:199–201`) | Equal view-line count exits before assignment/recompute. | DEFERRED (no EditorConfiguration view-line equality/recompute seam) |
| ECS-007 | `setReservedHeight` (`:206–212`) | Assign changed reserved height then recompute once. | N-A (no reserved-height option) |
| ECS-008 | reserved-height equality return (`:207–209`) | Equal reserved height exits before assignment/recompute. | N-A (no reserved-height option) |
| ECS-009 | `setGlyphMarginDecorationLaneCount` (`:214–220`) | Assign changed lane count then recompute once. | N-A (no glyph-margin lane allocator) |
| ECS-010 | glyph-lane equality return (`:215–217`) | Equal lane count exits before assignment/recompute. | N-A (no glyph-margin lane allocator) |
| ECS-011 | `digitCount` (`:223–230`) | Return the number of base-10 digits with a minimum of one. | TESTED |
| ECS-012 | decimal reduction loop (`:225–228`) | Repeatedly floor-divide by 10 and increment the count. | TESTED |
| ECS-013 | zero fallback (`:229`) | Return one when the loop counted zero digits. | TESTED |

#### platform root-class helper (`ECX`, 3 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| ECX-001 | `getExtraEditorClassName` and return (`editorConfiguration.ts:232–246`) | Build and return the platform class suffix; local target is a pure helper feeding `get_editor_class_name`. | TESTED |
| ECX-002 | Safari/WebKitWebView versus other branch (`:234–241`) | Safari/native WebView add `no-minimap-shadow enable-user-select`; all other browsers add `no-user-select`. | TESTED |
| ECX-003 | independent macOS branch (`:242–244`) | Append `mac` independently of the browser branch. | TESTED |

#### option storage and `EditorOptionsUtil` (`ECU`, 27 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| ECU-001 | `ValidatedEditorOptions._values` (`editorConfiguration.ts:259`) | Option-ID-indexed value array. Local: Typed struct fields | N-A (source state absent from typed local seam) |
| ECU-002 | `ValidatedEditorOptions._read` (`editorConfiguration.ts:260-262`) | Unchecked indexed read and cast. Local: Direct typed field read | N-A (source state absent from typed local seam) |
| ECU-003 | `ValidatedEditorOptions.get` (`editorConfiguration.ts:263-265`) | Typed ID lookup from `_values`. Local: Direct typed field read | N-A (source state absent from typed local seam) |
| ECU-004 | `ValidatedEditorOptions._write` (`editorConfiguration.ts:266-268`) | Indexed write by option ID. Local: Typed constructor fields | N-A (source state absent from typed local seam) |
| ECU-005 | `ComputedEditorOptions._values` (`editorConfiguration.ts:272`) | Option-ID-indexed computed array. Local: `ViewerOptions` | N-A (source state absent from typed local seam) |
| ECU-006 | `ComputedEditorOptions._read` (`editorConfiguration.ts:273-278`) | Check initialization range before returning a cast value. Local: Direct typed field read | N-A (source state absent from typed local seam) |
| ECU-007 | uninitialized-read branch (`editorConfiguration.ts:274-276`) | `id >= _values.length` throws `Cannot read uninitialized value`. Local: Static fields make invalid IDs unrepresentable | N-A (source state absent from typed local seam) |
| ECU-008 | `ComputedEditorOptions.get` (`editorConfiguration.ts:279-281`) | Delegate to `_read`. Local: Direct field access | N-A (source state absent from typed local seam) |
| ECU-009 | `ComputedEditorOptions._write` (`editorConfiguration.ts:282-284`) | Indexed computed-value write. Local: Complete typed-value assignment | N-A (source state absent from typed local seam) |
| ECU-010 | `EditorOptionsUtil.validateOptions` (`editorConfiguration.ts:289-296`) | Traverse registry in order, validate each raw value, and write by ID. Local: Typed option construction | N-A (source state absent from typed local seam) |
| ECU-011 | `_never_` validation branch (`editorConfiguration.ts:292`) | Computed-only options receive `undefined` rather than a raw property read. Local: All five owned options are ordinary simple options | N-A (source state absent from typed local seam) |
| ECU-012 | `EditorOptionsUtil.computeOptions` (`editorConfiguration.ts:298-304`) | Traverse registry in order; each computation can read already-written computed options. Local: The five owned options compute by identity and have no cross-option dependency | N-A (source state absent from typed local seam) |
| ECU-013 | `_deepEquals` (`editorConfiguration.ts:306-322`) | Deep comparison dispatcher for primitive, array, and object values. Local: Derived equality; owned primitive path | TESTED |
| ECU-014 | primitive/null branch (`editorConfiguration.ts:307-309`) | If either side is non-object or null, compare with `===`. Local: Enum/Bool equality | TESTED |
| ECU-015 | array/mixed branch (`editorConfiguration.ts:310-312`) | Both arrays use `arrays.equals`; array/non-array is false. Local: No owned option is an array | N-A (source state absent from typed local seam) |
| ECU-016 | object key-count branch (`editorConfiguration.ts:313-315`) | Different enumerable key counts return false. Local: No owned option is an object | N-A (source state absent from typed local seam) |
| ECU-017 | recursive object mismatch (`editorConfiguration.ts:316-320`) | First recursively unequal key returns false. Local: No owned option is an object | N-A (source state absent from typed local seam) |
| ECU-018 | equal-object outcome (`editorConfiguration.ts:321`) | Return true after all keys match. Local: No owned option is an object | N-A (source state absent from typed local seam) |
| ECU-019 | `EditorOptionsUtil.checkEquals` (`editorConfiguration.ts:324-335`) | Compare every computed registry value and return one `ConfigurationChangedEvent` or null. Local: Snapshot-derived configuration diff with five added option facts | TESTED |
| ECU-020 | per-option changed bit (`editorConfiguration.ts:327-329`) | Store `!deepEquals(old,new)` at the exact option ID. Local: Five explicit local `*_changed` flags | TESTED |
| ECU-021 | `somethingChanged` aggregation (`editorConfiguration.ts:330-332`) | Any changed option makes the aggregate true; later equal options cannot clear it. Local: One config-event emission guard | TESTED |
| ECU-022 | event/null outcome (`editorConfiguration.ts:334`) | Any computed change creates one event; no computed change returns null. Local: At most one configuration event per frame snapshot | TESTED |
| ECU-023 | `EditorOptionsUtil.applyUpdate` (`editorConfiguration.ts:341–351`) | Traverse registry and merge only update-owned properties; local API replaces a full typed snapshot. | DEFERRED (complete-snapshot versus partial-update API deviation) |
| ECU-024 | own-property branch (`editorConfiguration.ts:344`) | Missing or inherited properties are ignored; no dynamic partial object exists locally. | DEFERRED (complete-snapshot versus partial-update API deviation) |
| ECU-025 | delegate/write order (`editorConfiguration.ts:345–346`) | Call option-specific update, then write `newValue`; local performs one complete assignment. | DEFERRED (complete-snapshot versus partial-update API deviation) |
| ECU-026 | cumulative change OR (`editorConfiguration.ts:347`) | Preserve any earlier true `didChange`. Local: Multi-field snapshot equality and combined event facts | TESTED |
| ECU-027 | aggregate return (`editorConfiguration.ts:350`) | Return whether any supplied raw property changed. Local: Whole-snapshot equality guard | TESTED |

#### scoped editor-option/event/registry atoms (`EOP`, 25 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| EOP-001 | `IEditorOptions.renderValidationDecorations` input and three-value domain | `editorOptions.ts:199-202`; local: local enum/filter matrix; source default is reconciled in EOB-034 | TESTED |
| EOP-002 | `IEditorOptions.renderWhitespace` input and five-value domain | `editorOptions.ts:725-729` | TESTED |
| EOP-003 | `IEditorOptions.renderControlCharacters` input | `editorOptions.ts:730-734` | TESTED |
| EOP-004 | `IEditorOptions.renderLineHighlight` input and four-value domain | `editorOptions.ts:735-739`; local: the JSDoc says `all`, but registration EOB-032's actual default `line` is authoritative | TESTED |
| EOP-005 | `IEditorOptions.renderLineHighlightOnlyWhenFocus` input | `editorOptions.ts:740-744` | TESTED |
| EOP-006 | `ConfigurationChangedEvent._values` per-option bitmap | `editorOptions.ts:1022`; local: required local option-specific configuration facts | TESTED |
| EOP-007 | `ConfigurationChangedEvent` constructor | `editorOptions.ts:1026-1028`; local: one retained changed-facts payload | TESTED |
| EOP-008 | `ConfigurationChangedEvent.hasChanged` | `editorOptions.ts:1029-1031`; local: option-specific ViewPart queries | TESTED |
| EOP-009 | `IComputedEditorOptions.get` typed query contract | `editorOptions.ts:1037-1039` | N-A (local consumers read typed fields) |
| EOP-010 | `IEditorOption.id` | `editorOptions.ts:1081` | N-A (no numeric option registry) |
| EOP-011 | `IEditorOption.name` | `editorOptions.ts:1082` | N-A (no dynamic property-key update) |
| EOP-012 | `IEditorOption.defaultValue` | `editorOptions.ts:1083` | N-A (defaults are typed constructor arguments; observable defaults are registration rows) |
| EOP-013 | `IEditorOption.schema` | `editorOptions.ts:1087` | N-A (no JSON configuration schema) |
| EOP-014 | `IEditorOption.validate` contract | `editorOptions.ts:1091` | N-A (typed enum/Bool boundary) |
| EOP-015 | `IEditorOption.compute` contract | `editorOptions.ts:1095` | N-A (directly owned derived facts; simple identity is EOB-015) |
| EOP-016 | `IEditorOption.applyUpdate` contract | `editorOptions.ts:1100`; the local complete-snapshot API omits the applicable partial-update contract. | DEFERRED (complete-snapshot versus partial-update API deviation) |
| EOP-017 | `editorOptionsRegistry` | `editorOptions.ts:5766` | N-A (no dynamic registry) |
| EOP-018 | `register` stores by ID and returns the option | `editorOptions.ts:5768-5771` | N-A (no dynamic registry) |
| EOP-019 | `EditorOption.renderControlCharacters` = numeric ID **108** | `editorOptions.ts:5882` | N-A (local named field/flag) |
| EOP-020 | `EditorOption.renderLineHighlight` = numeric ID **110** | `editorOptions.ts:5884` | N-A (local named field/flag) |
| EOP-021 | `EditorOption.renderLineHighlightOnlyWhenFocus` = numeric ID **111** | `editorOptions.ts:5885` | N-A (local named field/flag) |
| EOP-022 | `EditorOption.renderValidationDecorations` = numeric ID **112** | `editorOptions.ts:5886` | N-A (local named field/flag) |
| EOP-023 | `EditorOption.renderWhitespace` = numeric ID **113** | `editorOptions.ts:5887` | N-A (local named field/flag) |
| EOP-024 | `IEditorOptions.readOnly` input/default false | `editorOptions.ts:175–179`; readonly Viewer intentionally exposes no mutable axis. | N-A (fixed readonly product boundary) |
| EOP-025 | `EditorOption.readOnly` = numeric ID **104** | `editorOptions.ts:5878`; local code uses a named constant-folded fact. | N-A (no numeric option registry) |

#### scoped update, validation, filter, and registration behavior (`EOB`, 37 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| EOB-001 | `ApplyUpdateResult.newValue` | `editorOptions.ts:1142` | N-A (no partial-update result object) |
| EOB-002 | `ApplyUpdateResult.didChange` | `editorOptions.ts:1143` | N-A (whole-value equality is the local gate) |
| EOB-003 | `ApplyUpdateResult` constructor | `editorOptions.ts:1140-1145` | N-A (no partial-update result object) |
| EOB-004 | generic `applyUpdate` primitive/null branch | `editorOptions.ts:1147-1150`; local: all five owned enum/Bool options take this source branch; local equality is equivalent | TESTED |
| EOB-005 | generic `applyUpdate` array/mixed branch | `editorOptions.ts:1151-1154` | N-A (no array-valued owned option) |
| EOB-006 | generic object update initializes `didChange=false` | `editorOptions.ts:1155` | N-A (no object-valued owned option) |
| EOB-007 | generic object update visits own keys, recursively updates changed children, and accumulates change | `editorOptions.ts:1156-1164` | N-A (no object-valued owned option) |
| EOB-008 | generic object update returns original object plus aggregate flag | `editorOptions.ts:1165` | N-A (no object-valued owned option) |
| EOB-009 | `SimpleEditorOption.id` | `editorOptions.ts:1197` | N-A (no numeric registry) |
| EOB-010 | `SimpleEditorOption.name` | `editorOptions.ts:1198` | N-A (no dynamic key) |
| EOB-011 | `SimpleEditorOption.defaultValue` | `editorOptions.ts:1199`; local: owned option defaults | TESTED |
| EOB-012 | `SimpleEditorOption.schema` | `editorOptions.ts:1200` | N-A (no JSON schema) |
| EOB-013 | `SimpleEditorOption` constructor | `editorOptions.ts:1202-1207` | N-A (typed option constructor) |
| EOB-014 | simple `applyUpdate` delegates to generic merge | `editorOptions.ts:1209-1211`; local: primitive equality/no-op split | TESTED |
| EOB-015 | simple `compute` returns validated value unchanged | `editorOptions.ts:1215-1217`; local: five values flow unchanged into local render/view-model inputs | TESTED |
| EOB-016 | `boolean`: undefined selects default | `editorOptions.ts:1223-1226` | N-A (omitted typed constructor argument supplies the default) |
| EOB-017 | `boolean`: string `'false'` compatibility branch | `editorOptions.ts:1227-1230` | N-A (typed Bool rejects strings) |
| EOB-018 | `boolean`: remaining JavaScript truthiness conversion | `editorOptions.ts:1231` | N-A (typed Bool) |
| EOB-019 | `EditorBooleanOption` constructor/schema setup | `editorOptions.ts:1234-1242` | N-A (typed Bool; no JSON schema) |
| EOB-020 | boolean option validation | `editorOptions.ts:1244-1246` | N-A (typed Bool) |
| EOB-021 | `stringSet`: non-string returns default | `editorOptions.ts:1371-1374` | N-A (closed MoonBit enum) |
| EOB-022 | `stringSet`: optional renamed-value mapping | `editorOptions.ts:1375-1377` | N-A (registrations supply no rename map; no aliases locally) |
| EOB-023 | `stringSet`: disallowed string returns default | `editorOptions.ts:1378-1380` | N-A (closed MoonBit enum) |
| EOB-024 | `stringSet`: allowed string passes through | `editorOptions.ts:1381`; local: all declared local enum values are accepted | TESTED |
| EOB-025 | `EditorStringEnumOption._allowedValues` | `editorOptions.ts:1386` | N-A (closed enum type is the allowed set) |
| EOB-026 | `EditorStringEnumOption` constructor/schema/default setup | `editorOptions.ts:1388-1396` | N-A (typed enum; no JSON schema) |
| EOB-027 | string-enum validation delegates to `stringSet` | `editorOptions.ts:1398-1400` | N-A (closed enum) |
| EOB-028 | `filterValidationDecorations` reads the option and returns whether validation decorations are filtered | `editorOptions.ts:3936-3942` | TESTED |
| EOB-029 | validation mode `editable` returns the current `readOnly` value | `editorOptions.ts:3937-3940`; local: readonly Viewer makes this true | TESTED |
| EOB-030 | validation modes `on`/`off` return false/true respectively | `editorOptions.ts:3941` | TESTED |
| EOB-031 | `renderControlCharacters` registration: Bool, default true, restricted schema | `editorOptions.ts:6534-6537`; local: value/default/render flow; schema policy is absent locally | TESTED |
| EOB-032 | `renderLineHighlight` registration: default `line`, allowed `[none,gutter,line,all]` in that order | `editorOptions.ts:6544-6557` | TESTED |
| EOB-033 | `renderLineHighlightOnlyWhenFocus` registration: Bool default false | `editorOptions.ts:6558-6561` | TESTED |
| EOB-034 | `renderValidationDecorations` registration: default `editable`, allowed `[editable,on,off]` | `editorOptions.ts:6562–6566`; the already-approved readonly Viewer policy exposes all values but defaults to `On`, with contract/test evidence. | TESTED |
| EOB-035 | `renderWhitespace` registration: default `selection`, allowed `[none,boundary,selection,trailing,all]` in that order | `editorOptions.ts:6567-6581` | TESTED |
| EOB-036 | `SimpleEditorOption.validate` abstract contract | `editorOptions.ts:1213`; local enums/Bools are valid at the typed constructor boundary. | N-A (typed option-validation boundary) |
| EOB-037 | `readOnly` registration: Bool default false | `editorOptions.ts:6526–6528`; readonly Viewer fixes the fact true instead of exposing the option. | N-A (fixed readonly product boundary) |

#### generic migration machinery and scoped registrations (`MIG`, 34 rows)

| ID | Source atom | Behavior / local target | Status |
|---|---|---|---|
| MIG-001 | `ISettingsReader` callable capability | `migrateOptions.ts:8-10` | N-A (typed API/no settings store) |
| MIG-002 | `ISettingsWriter` callable capability | `migrateOptions.ts:12-14` | N-A (typed API/no settings store) |
| MIG-003 | `EditorSettingMigration.items` registry | `migrateOptions.ts:16-18` | N-A (no migration registry) |
| MIG-004 | migration `key` field | `migrateOptions.ts:20-22` | N-A (no settings keys) |
| MIG-005 | migration callback field | `migrateOptions.ts:22` | N-A (no migration callbacks) |
| MIG-006 | `EditorSettingMigration` constructor | `migrateOptions.ts:20-23` | N-A (no migration objects) |
| MIG-007 | `apply` method orchestration | `migrateOptions.ts:25-30` | N-A (no legacy input) |
| MIG-008 | `apply` initially reads this migration's key | `migrateOptions.ts:26` | N-A (no settings keys) |
| MIG-009 | `apply` builds recursive read closure | `migrateOptions.ts:27` | N-A (no settings reader) |
| MIG-010 | `apply` builds recursive write closure | `migrateOptions.ts:28` | N-A (no settings writer) |
| MIG-011 | `apply` invokes migration callback with value/read/write | `migrateOptions.ts:29` | N-A (no migration callback) |
| MIG-012 | recursive `_read` method | `migrateOptions.ts:32-43` | N-A (no untyped settings object) |
| MIG-013 | `_read` undefined/null early return | `migrateOptions.ts:33-35` | N-A (typed value) |
| MIG-014 | `_read` first-dot calculation | `migrateOptions.ts:37` | N-A (no dotted key) |
| MIG-015 | `_read` dotted-key segment recursion | `migrateOptions.ts:38-40` | N-A (no settings object) |
| MIG-016 | `_read` leaf property access | `migrateOptions.ts:42` | N-A (typed field) |
| MIG-017 | recursive `_write` method | `migrateOptions.ts:45-54` | N-A (immutable typed value) |
| MIG-018 | `_write` first-dot calculation | `migrateOptions.ts:46` | N-A (no dotted key) |
| MIG-019 | `_write` dotted branch creates missing object, recurses, returns | `migrateOptions.ts:47-51` | N-A (no settings object) |
| MIG-020 | `_write` leaf assignment | `migrateOptions.ts:53` | N-A (immutable typed value) |
| MIG-021 | `registerEditorSettingMigration` pushes registry item | `migrateOptions.ts:57-59` | N-A (no migration registry) |
| MIG-022 | `registerSimpleEditorSettingMigration` wrapper | `migrateOptions.ts:61-72` | N-A (no legacy input) |
| MIG-023 | simple migration defined-value gate | `migrateOptions.ts:63` | N-A (typed input) |
| MIG-024 | simple migration loops old/new pairs | `migrateOptions.ts:64` | N-A (closed enum) |
| MIG-025 | simple migration strict old-value equality | `migrateOptions.ts:65` | N-A (closed enum) |
| MIG-026 | matched simple migration writes new value and returns | `migrateOptions.ts:66-67` | N-A (no migration) |
| MIG-027 | undefined/unmatched simple migration is a no-op | `migrateOptions.ts:63-71` | N-A (no migration) |
| MIG-028 | `migrateOptions` applies every registered migration in order | `migrateOptions.ts:77-79` | N-A (no migration registry) |
| MIG-029 | `renderWhitespace` simple migration registration | `migrateOptions.ts:84` | N-A (typed enum) |
| MIG-030 | legacy whitespace `true` maps to `'boundary'` | `migrateOptions.ts:84` | N-A (Bool cannot enter enum field) |
| MIG-031 | legacy whitespace `false` maps to `'none'` | `migrateOptions.ts:84` | N-A (Bool cannot enter enum field) |
| MIG-032 | `renderLineHighlight` simple migration registration | `migrateOptions.ts:85` | N-A (typed enum) |
| MIG-033 | legacy line-highlight `true` maps to `'line'` | `migrateOptions.ts:85` | N-A (Bool cannot enter enum field) |
| MIG-034 | legacy line-highlight `false` maps to `'none'` | `migrateOptions.ts:85` | N-A (Bool cannot enter enum field) |

The final configuration disposition is mechanically **44 TESTED, 0 PORTED,
9 DEFERRED, and 119 N-A = 172**. Closing review keeps the absent exact
`setViewLineCount` assignment/equality/recompute seam deferred even though the
local layout identity now tracks raw view-line count independently. Across all
three slices, the frozen map is **244 TESTED, 90 PORTED, 68 DEFERRED, and 161
N-A = 563**. No TODO or PASS row remains.


### Cross-part source matrix

`C` means the source handler is conditional. This matrix explains cross-part
effects; the 563-row ledger, not this matrix, is the denominator.

| Event | ViewLines | ViewCursors | ContentWidgets | CurrentLineHighlight |
|---|---|---|---|---|
| CompositionStart | false | true: composing/blink | false | false |
| CompositionEnd | false | true: composing/blink | false | false |
| Configuration | true and reread caches | true and reread caches | true and notify widgets | true and reread caches |
| Cursor | C: Selection whitespace/high contrast | true | false | C: unique line set or emptiness changed |
| Decorations | true | true | true | false |
| Flushed | collection/width reset | true | true | true |
| Focus | false | side effect, then false | false | C: focus-only option |
| LineMapping | false | false | true plus anchor reprojection | false |
| LinesChanged | C: visible overlap | true | true plus anchor reprojection | false |
| LinesDeleted | true | true | true plus anchor reprojection | true |
| LinesInserted | true | true | true plus anchor reprojection | true |
| Scroll | always write scrollWidth; dirty iff top or left changed; reveal cancellation separately conditional | true | true | width-changed or top-changed |
| Tokens | C: retained ranges | C: cursor in inclusive range | false | false |
| Zones | true | true | true | true |
| Theme | C: `_onOptionsMaybeChanged` | no scoped handler; theming participant excluded | false | C: `_readFromSelections`; concrete local delivery N-A |

### Gate B local-state audit (historical baseline)

Everything in this subsection describes the pre-implementation tree reviewed
at documentation-only commit `bff07db`. It is retained as the evidence that
authorized the work; the final contract is the terminal ledger and closing
execution record below.

#### Frame and dirty-state order

At the Gate B baseline, `Viewer::flush_render`
(`viewer/view_host.mbt:66–158`) conditionally measured, synchronized hover
decorations, built one render input, called `View::render`, then flushed
reveal/public-rendered/scroll events. `View::render`
(`viewer/browser/view/view.mbt:206–259`) rewrote the root class, derived a
snapshot diff, dispatched it to eight retained handles, snapshotted dirty
non-line parts, rendered ViewLines first, prepared every selected non-line part
before any write, cleared each successful write with `on_did_render`, then
stored the new snapshot.

The handle order is ViewLines, ViewZones, ContentViewOverlays,
MarginViewOverlays, ContentWidgets, ViewCursors, OverlayWidgets, and
EditorScrollbar (`view_part.mbt:34–85`). Each handle starts dirty;
`handle_view_events` (`:22–31`) force-sets a sticky bit for every true handler
result, and `on_did_render` clears it. No ViewPart schedules itself.

ViewLines retains `last_render_whitespace`, per-row `RenderLineInput`, and
`CharacterMapping`; equal row input skips DOM replacement
(`view_lines.mbt:20–25,109–110`; `view_line.mbt:27–33,77–110`). The shared
line renderer lays out retained rows, then batches new rows before invalid
rows (`view_layer_renderer.mbt:58–128,274–338`). Content and margin aggregates
reprepare all three dynamic overlays whenever their aggregate is dirty, while
concatenated row HTML is deduplicated by `rendered_content`
(`view_overlays.mbt:11–19,49–63,96–127,173–226`).

#### Snapshot omissions and exact Gate B baseline matrix

`ViewRenderSnapshot` (`rendering_context.mbt:137–168`) stores only window,
content/decorations generations, scroll position, aggregate dimensions,
gutter width, space width, complete view selection, shallow-copied zones, and
focus. Its fixed event order is Lines, Decorations, Scroll, Cursor,
Configuration, Zones, Focus; the first frame emits only Flushed
(`view_events.mbt:68–117`). It omits all five scoped render options, line
decorations width, halfwidth-arrow capability, fullwidth width, line height and
complete FontInfo identity, word wrap, typed content/token/mapping ranges,
decoration-affects flags, and the six independent scroll values/flags.

| Gate B baseline event | VL | VZ | Content overlays | Margin overlays | CW | VC | Overlay widgets | Scrollbar |
|---|---|---|---|---|---|---|---|---|
| Flushed | true | true | true | true | true | true | true | true |
| generic LinesChanged | true | true | true | true | true | true | false | false |
| DecorationsChanged | true | false | true | true | false | false | false | false |
| Scroll position/dimensions/window | true | true | window or position | window or position | true | true | dimensions | position or dimensions |
| CursorStateChanged | only prior Selection whitespace | false | true | true | false | true | false | false |
| ConfigurationChanged | gutter or space width | false | true | gutter only | false | true | false | gutter only |
| ZonesChanged | false | true | true | true | true | true | false | false |
| FocusChanged | false | false | true | true | false | true | false | false |

Exact gaps and masking at this milestone:

1. `Viewer::update_options` (`viewer.mbt:535–569`) schedules a frame but the
   four paint options are neither ViewModel options nor snapshot facts, so the
   frame can contain zero events and clean parts retain stale DOM.
2. Runtime `renderValidationDecorations` rotates `ViewModelDecorations`
   (`view_model.mbt:148–184`) without advancing decorations generation or
   emitting Decorations/Configuration.
3. ViewCursors lacks Decorations; ContentWidgets lacks both Configuration and
   Decorations. An ordinary letter-spacing-affecting inline decoration can
   therefore leave a stationary cursor/widget stale. At that baseline,
   injected text masked this by also reprojection-bumping content generation.
4. Content/Margin overlays ignore dimensions-only scroll events although their
   geometry reads viewport/scroll width.
5. ViewLines lacks Zones; `change_view_zones` masks it by also bumping generic
   content generation. Same-geometry replacement nodes/callbacks are omitted
   by `same_browser_view_zones`.
6. One `content_generation` conflates content flush, token reset, mapping,
   hover, and zones. Token ranges are discarded, all token changes dirty the
   cursor, and hover/zones masquerade as LinesChanged.
7. The model decoration payload already carries affects flags, but
   `attach_model.mbt:21–43` collapses it to a scalar generation.
8. ViewLayout supplies exact `ScrollChange` values/flags, while
   `apply_scroll_change` discards them and the View reconstructs aggregate
   flags from snapshots.
9. Configuration compares only gutter and `space_width`; equal-space changes
   to line height/font/fullwidth/arrow facts can miss dependent parts.
10. `tab_size` is passed into ViewModel options only when soft wrap is enabled;
    this adjacent option-wiring gap must be represented rather than hidden by
    invalidation work.
11. Aggregate margin overlays dirty for every cursor event, whereas source
    current-line behavior can return false for a same-line column-only move
    with unchanged selection emptiness.

No permanent dirty loop was observed at that baseline. Successful writes clear every selected
handle and no handler schedules itself. `schedule_render` coalesces pending
work. Hover decoration synchronization can intentionally cause one additional
clean frame; tests must distinguish it from an unbounded loop.

### Behavior-variable test matrix

| Axis | Required cases | Lowest useful evidence |
|---|---|---|
| dirty lifecycle | initial, after-render, force, all-false, false/true/false, already dirty, multiple true | ViewPart white-box |
| configuration | no-op; each scoped option; combinations; wrap/no-wrap; validation modes; same-width font change; A→B→A | snapshot/handler + headless + browser |
| decorations | add/remove; stationary cursor/widget; ordinary/injected; null source; affects flags; validation toggle; several changes per frame | model/headless + browser |
| content | internal/injected; Flush/Changed/Inserted/Deleted/EOL; optional Changed tuple permutations; null/non-null version; `hadOther` × mapping; overwrite behavior | ViewModel white-box |
| scroll | each value/flag independently; width+top; height-only; left-only; window-only | snapshot/handler + browser geometry consumer |
| tokens | outside viewport; viewport overlap; cursor overlap; multiple/boundary inclusive ranges | retained-line/cursor white-box |
| focus | focus-only off/on × focused/blurred; ViewCursors side effect returning false | handler + browser |
| zones | source event alone; same-geometry node/callback replacement | handler + browser; callback exceptions remain zone child |
| delivery | ordered events, accumulated dirty bit, RVC collector/reentrant queue, unified-outgoing deferral | handler/dispatcher white-box |
| render stability | immediate DOM replacement, no-op writes zero, two extra frames stabilize | browser component |

Existing `render_whitespace_options_wbtest.mbt` proves construction/input
forwarding only. Existing initial-option, cursor/inlay, current-line predicate,
viewport-construction, fingerprint, and recycler/perf tests do not establish
dynamic invalidation or exact handler dirtiness.

### Gate B deviation decisions (historical)

1. The frame snapshot-diff event seam was not retained. Payload-bearing and
   transient facts now enter a typed source dispatcher, including A→B→A within
   one scheduled frame.
2. `ViewPart` dispatch now accumulates every handler result and sets the dirty
   bit once after the whole batch, matching source order.
3. Fixed ViewPart membership remains an approved N-A seam for generic
   add/remove APIs. Reentrant typed events queue as later FIFO batches, and
   tests prove all eight fixed handles receive each complete batch.
4. Grouped content/margin overlays retain harmless sub-overlay
   over-invalidation. Source-derived tests prove a same-line column-only cursor
   batch can select the aggregate while causing zero cached-style writes,
   attribute writes, row replacement, or retained-row identity change.
5. ViewCursors now performs the source focus side effect in the handler and
   returns false; the rendered cursor rectangle remains paired with its last
   rendered position until the next render.
6. Concrete local theme handlers remain N-A because CSS/root state applies the
   theme directly. Typed composition/theme declarations and dispatch exist,
   without claiming a local producer/handler.
7. The public local `update_options` API intentionally replaces one complete
   typed `ViewerOptions` snapshot, while Monaco accepts a partial object. Exact
   no-op/change behavior is tested and the complete-snapshot contract is in
   `viewer/README.md`.
8. `ViewThemeChangedEvent.theme` intentionally reduces source `IColorTheme` to
   the existing local `String` identity. It is declaration/dispatch-only and
   has no claimed producer or concrete handler.

### Gate B inventory approval

- [x] Exactly 563 unique rows exist with prefix counts
  `VL33,VLI13,VLCI4,VLC16,RLC30,VC40,CW21,CLH27,VE75,VEH45,RVC35,RVD14,RVMI36,CEWU2,ECF33,ECS13,ECX3,ECU27,EOP25,EOB37,MIG34`.
- [x] At Gate B every source row had `Status = TODO`; proposed terminal status
  was a separate review target.
- [x] The source hashes and inclusive/excluded boundaries are independently
  reread, including the four theme atoms and 15-class `ViewEvent` union.
- [x] Cross-child inheritance and helper ownership have no duplicate rows.
- [x] Cross-part and behavior-variable matrices explain every conditional cell.
- [x] Proposed DEFERRED/N-A seams and deviation candidates are approved.
- [x] `viewer/README.md` records the approved complete-snapshot
  `update_options` API deviation before implementation closes.
- [x] ECX's pure Safari/WebKit/macOS class helper is integrated into the root
  class builder and source-derived branch tests cover all platform axes.
- [x] Documentation-only inventory is committed separately and reviewed.

**Gate B approved implementation, and both implementation-close obligations
were satisfied before this child was frozen.**


## Test-Authority Corrections

- At Gate B, `render_whitespace_options_wbtest.mbt` proved
  construction/input forwarding but not `update_options` followed by DOM
  replacement. This child adds the missing dynamic evidence.
- The pre-existing cursor and inlay tests proved initial state, not dynamic
  decoration mutation while a caret/widget remained stationary. The closing
  browser matrix now covers that axis.
- The historical cursor plan marked decoration invalidation as ported; the
  Gate B baseline showed the handler was absent. This frozen child supersedes
  only that inaccurate evidence and now supplies the handler and tests.

## Required Test Matrix (Phase 4)

Package/white-box source-derived tests:

- inline decoration insertion/removal before a stationary cursor/widget emits
  the expected event and dirties the expected parts;
- content-only, token-only, line-mapping, scroll-only, focus-only, zone-only,
  and cursor-only events do not over- or under-invalidate.
- each ViewPart handler returns the source-required dirty result for every
  configuration/event branch.

These are ordinary local _test.mbt/_wbtest.mbt files unless an exact upstream
test suite is actually ported with its original labels, path, and current pin.

Headless Viewer integration:

- each relevant option changes independently and in meaningful combinations;
- option no-op update does not advance the relevant generation or schedule
  work;
- validation-decoration provider on/off changes model/view-model generation
  and data;
- dynamic decorations emit the expected Viewer/ViewModel event without
  requiring a Browser View.

Browser/component:

- whitespace/control characters update immediately after update_options;
- current-line line/fill/gutter variants and focus-only mode update immediately;
- validation squiggles appear/disappear without unrelated interaction;
- a dynamic inlay/inline-decoration change alone causes ViewCursors and
  ContentWidgets to recompute and write their position in the next frame;
  DOM Range/pixel correctness is closed only by the geometry plan;
- render-count assertions detect accidental render loops.

## Milestones

1. Inventory, cross-part event matrix, and ledger only; commit and stop.
2. Add ordinary source-derived white-box tests for event-to-part dirtiness;
   use reference naming only for exact upstream test ports.
3. Complete configuration/decorations payload generation and snapshot facts.
4. Port ViewLines, ViewCursors, ContentWidgets, and current-line handlers.
5. Add runtime browser option and dynamic-decoration scenarios.
6. Update browser view/ViewPart and owning package contracts.
7. Run focused and full quality gates.
8. Independent source/ledger/diff/test review.

## Deviations (Phase 3)

The final reviewed deviations are:

- `Viewer::update_options` accepts and replaces one complete typed
  `ViewerOptions` snapshot instead of Monaco's partial object. Exact no-op and
  changed-axis behavior is tested and owned by `viewer/README.md`.
- View owns one fixed eight-member ViewPart array, so runtime handler
  registration/removal is N-A. Nested/reentrant events still preserve the
  source FIFO batch contract.
- Dispatcher delivery and ViewPart callbacks are statically non-raising in
  MoonBit, so the source branch that restores the consuming gate after an
  escaping handler exception is N-A. `defer` restores the gate for every
  representable delivery exit; separately, the generic raising
  `with_view_event_batch` callback uses `defer` to close its collector, which is
  the tested RVC-034 path rather than evidence for RVC-022.
- Content and margin overlays remain grouped. Some events harmlessly select
  the aggregate when a nested overlay returns false; equality gates and row
  dedupe are tested to produce zero DOM writes/replacements for those cases.
- `ViewThemeChangedEvent.theme` uses the existing local `String` identity
  instead of `IColorTheme`. It is declaration/dispatch-only because concrete
  theme application remains CSS/root-owned.
- Render events and public/model outgoing events are not unified in one
  collector. Direct model subscriptions and the frozen cursor FIFO remain
  authoritative; the affected RVC/RVD rows are explicitly DEFERRED.
- The local ViewModel still reduces incremental content/injected changes to
  whole-document Flush/injected paths. Incremental two-pass projection,
  content-version acceptance, custom-height recovery, and the exact
  `EditorConfiguration.setViewLineCount` seam remain row-local DEFERRED.

The former frame snapshot-diff event seam is not a final deviation: it was
removed in favor of source-time typed events and a reentrant collector.

## Exit Gate

- [x] inventory rows equal ledger rows
- [x] change-source/ViewPart matrix has no unexplained cell
- [x] every exposed runtime option is tested through update_options
- [x] dynamic inline decorations trigger cursor/widget recomputation without an unrelated event
- [x] validation decorations update without an unrelated event
- [x] no render loop or permanent dirty state is introduced
- [x] all deviations have reviewed reasons
- [x] `viewer/README.md` records the complete-snapshot `update_options` contract
- [x] theme payload reduction is documented without claiming a producer/handler
- [x] ECX platform classes are integrated into the Viewer root class
- [x] all repository quality gates pass
- [x] independent closing reread finds no unaccounted scoped member

## Execution Record

### 2026-07-12 — normalized Phase 1–2 inventory ready

The documentation-only inventory has **509/509 TODO rows** with exact prefix
counts `VL32,VLI13,VLCI4,VLC16,RLC30,VC40,CW21,CLH27,VE75,VEH45,RVD14,RVMI38,CEWU2,ECF33,ECU27,EOP23,EOB35,MIG34`.
The review proposal is **213 TESTED, 72 PORTED, 39 DEFERRED, and 185 N-A**.
All fourteen pinned source hashes were recomputed successfully; row count,
unique ID, prefix count, terminal-shape, five-column table, and diff checks
pass. The inventory records inherited cursor/lifecycle ownership and the EOL,
tokenization, geometry, reveal, and theme boundaries without duplicate rows.

No product or test file changed. This child is at **STOP FOR REVIEW**; Gate B
has not passed and implementation is not authorized.

### 2026-07-12 — Gate B rejected inventory commit `23b7200`

Independent review rejected the 509-row milestone. The denominator omitted the
35 generic view-queue/collector atoms frozen cursor had explicitly handed to
render invalidation, `EditorConfiguration` setter/digit-count atoms, and
the readonly/generic-option atoms. It also counted three geometry helper atoms
inside RVMI, collapsed the scheduler callback, used unsupported N-A/DEFERRED
classifications, left generic dependency reasons, and did not close every
ViewPart sibling boundary. Commit `23b7200` remains the historical docs-only
rejected milestone; no product or test work was authorized from it.

### 2026-07-12 — Gate B amendment ready

The amended documentation-only inventory has **559/559 TODO rows**:
183 ViewPart, 207 event/propagation, and 169 configuration atoms. Exact prefix
counts are
`VL32,VLI13,VLCI4,VLC16,RLC30,VC40,CW21,CLH27,VE75,VEH45,RVC35,RVD14,RVMI36,CEWU2,ECF33,ECS13,ECU27,EOP25,EOB37,MIG34`.
The revised proposal is **245 TESTED, 93 PORTED, 59 DEFERRED, and 162 N-A**.
RVC now owns the frozen cursor handoff; RVMI removes geometry-owned helpers and
records its split/renumber mapping; configuration includes setters, readonly,
and the explicit complete-snapshot API deviation. All fourteen pinned source
hashes were recomputed successfully; no product or test file changed. This
amendment is at **STOP FOR FRESH REVIEW** and Gate B has not passed.

### 2026-07-12 — Gate B rejected amendment commit `69f33f3`

Fresh review rejected the 559-row amendment. It omitted the source-owned
ViewLines `createLine` callback and `getExtraEditorClassName` helper, retained a
duplicate cursor-cardinality umbrella instead of the reused `pauseAnimation`
constant, and overclaimed collector/scheduler branches. Theme payload typing
also lacked an explicit `IColorTheme`→`String` identity deviation. Commit
`69f33f3` remains the historical docs-only rejected amendment; it authorized
no product or test work.

### 2026-07-12 — second Gate B amendment ready

The second amended inventory has **563/563 TODO rows**: 184 ViewPart, 207
event/propagation, and 172 configuration atoms. Exact prefix counts are
`VL33,VLI13,VLCI4,VLC16,RLC30,VC40,CW21,CLH27,VE75,VEH45,RVC35,RVD14,RVMI36,CEWU2,ECF33,ECS13,ECX3,ECU27,EOP25,EOB37,MIG34`.
The revised proposal is **247 TESTED, 92 PORTED, 64 DEFERRED, and 160 N-A**.
It adds the source factory callback and ECX platform helper, replaces the
cursor umbrella, narrows mixed collector/scheduler claims, and records the
declaration-only theme identity reduction. All fourteen pinned source hashes
were recomputed successfully; no product or test file changed. This amendment
is at **STOP FOR FRESH REVIEW** and Gate B has not passed.

### 2026-07-12 — Gate B approved

Independent ViewPart, event/propagation, and configuration reviews approved
documentation-only inventory commit `bff07db`. The fixed denominator is
**563/563 TODO rows** with **247 proposed TESTED, 92 PORTED, 64 DEFERRED, and
160 N-A**; the child-plan SHA-256 is
`95d326a81000c368ac9cf9ac6d783f5cd9d2fcf21daf6cbf9a8fb7ec477c0d5a`.
All three reviews confirmed the pinned hashes, ownership boundaries, matrices,
row mechanics, and registered deviations without finding another inventory
gap. No product or test edit preceded approval. Gate B is recorded and
implementation is authorized.

### 2026-07-12 — implementation, Gate D remediation, and freeze

Product/test commit `14ed3c1` replaces frame snapshot diffs with the typed
15-variant ViewEvent union, nested/reentrant FIFO collection, source-time root
events, exact payloads, and accumulated ViewPart delivery. It ports retained
ViewLine/ViewLines invalidation, complete locally applicable ViewLineOptions
identity and one dynamic factory, ContentWidgets retained model/view anchors,
current-line/content/margin caches, cursor focus/decoration/token handling,
independent model/view line-count identity, platform root classes, and exact
configuration/decorations/scroll/token/zone sources.

The browser matrix covers runtime whitespace/control/highlight/validation/tab/
wrap changes, A→B→A within one frame, stationary cursor/widget decoration
changes, real wrapped ContentWidget reprojection, wrapped model→view token
ranges, compensated layout lanes, model 9→10 digit bands with content-width
conservation, same-geometry ViewZone node/callback replacement, no-op writes,
and Chromium platform classes.

Independent Gate D reviews rejected earlier green states and drove fixes for:

- retained-line reconciliation, option equality, dynamic factory capture, and
  previously untested range/reveal branches;
- stale cursor render-data/position pairing and equality-gated selection class
  writes;
- ContentWidgets anchor reprojection plus layoutInfo-gated
  contentLeft/contentWidth/maxWidth caches;
- exact model→view token ranges and separate model-line digit versus raw
  view-line identities;
- real eight-ViewPart order/whole-batch evidence and source array identity;
- current-line/content/margin retained focus/layout caches, margin height, and
  zero-write evidence for harmless grouped over-invalidation.

Closing review changed five Gate-B proposals: RVC-022 is N-A because handler
failure is statically unrepresentable; RVMI-014/016 and ECS-005/006 are
DEFERRED because the wholesale content/version and exact
`setViewLineCount`/recompute seams remain absent. The final 563-row ledger is
**244 TESTED + 90 PORTED + 68 DEFERRED + 161 N-A**, with zero TODO/PASS and the
approved prefix denominator unchanged.

Final isolated gates pass:

- `just check`;
- `just test`: JS **1169/1169**, native **858/858**; Wasm/Wasm-GC have no test
  entry;
- `just build`;
- `just test-browser`: **68/68** on fresh port 5190;
- focused render/ViewPart suites: **50/50** before the final aggregate-cache
  additions, followed by `viewer/browser/view` **26/26**;
- `git diff --check`.

The owning READMEs and generated package contracts are updated. Multiple
independent closing rereads found no remaining scoped product blocker. This
child is now implemented and frozen historical evidence.
