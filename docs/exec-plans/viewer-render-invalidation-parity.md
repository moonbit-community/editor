# Viewer Render Invalidation Parity

Status: proposed — Phase 0 drafted; inventory pending

Date: 2026-07-10

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Findings: P1-06, P1-09. This plan also owns the prerequisite ContentWidget
event-handler cluster needed by P1-08.

Depends on: viewer-model-lifecycle-ownership-parity.md and
viewer-async-model-features-parity.md

No product code may be changed until the inventory and equal-size ledger are
committed and reviewed.

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
    ViewParts.
- vscode/src/vs/editor/common/viewEventHandler.ts
  - complete handler dirty-state/dispatch contract.
- vscode/src/vs/editor/common/viewModelEventDispatcher.ts
  - configuration/decorations/injected-text event collection and dispatch
    clusters only; cursor and zone outgoing-event siblings are excluded.
- vscode/src/vs/editor/common/viewModel/viewModelImpl.ts
  - complete configuration, decorations, injected-text, and line-change
    event-emission clusters. Cursor-state emission belongs to
    viewer-cursor-input-events-parity.md.
- vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts
  - complete updateOptions-to-configuration notification cluster only;
    model lifecycle and cursor event forwarding are excluded.
- vscode/src/vs/editor/browser/config/editorConfiguration.ts
  - complete updateOptions, recompute, changed-option dependency, and emitted
    configuration-change cluster.
- vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts
  - complete onConfigurationChanged, onDecorationsChanged,
    onCursorStateChanged, onLinesChanged, and onScrollChanged handlers plus
    their dirty-state transitions. Width reads and render integration belong to
    viewer-browser-geometry-parity.md.
- vscode/src/vs/editor/browser/viewParts/viewCursors/viewCursors.ts
  - complete ViewPart event-handler cluster.
- vscode/src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts
  - complete ViewPart configuration/decorations/lines/scroll/zones event
    handlers and their dirty-state transitions only. setWidgetPosition,
    placement, and render belong to viewer-browser-geometry-parity.md.
- vscode/src/vs/editor/browser/viewParts/currentLineHighlight/currentLineHighlight.ts
  - complete configuration/cursor/focus/line/scroll invalidation cluster.
- vscode/src/vs/editor/common/config/editorOptions.ts
  - option registrations and change dependencies for renderWhitespace,
    renderControlCharacters, renderLineHighlight, and
    renderLineHighlightOnlyWhenFocus.

### Local ownership

- viewer/viewer_options.mbt
- viewer/browser/view/rendering_context.mbt
- viewer/browser/view/view_events.mbt
- viewer/browser/view/view_part.mbt
- viewer/browser/view_parts/view_lines/view_lines.mbt
- viewer/browser/view_parts/view_cursors/view_cursors.mbt
- viewer/browser/view_parts/content_widgets/content_widgets.mbt
- viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt
- viewer/common/view_model/view_model.mbt
- viewer/viewer.mbt
- viewer/common/view_model/view_model_decorations.mbt
- viewer/attach_model.mbt
- viewer/inlay_hints_host.mbt
- viewer/render_whitespace_options_wbtest.mbt

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

This register is not the parity ledger and does not count toward the
source-member denominator.

This plan explicitly supersedes only the inaccurate invalidation evidence in
the implemented monaco-view-cursors-current-line-port.md. Do not edit that
historical plan.

## Inventory and Parity Ledger (Phases 1–2)

Build a matrix before code changes:

| Change source | ViewLines | ViewCursors | ContentWidgets | CurrentLineHighlight | Other affected parts |
|---|---|---|---|---|---|

For every source handler, record:

- fields inspected;
- early-return conditions;
- whether it returns dirty;
- cache updates that must occur before/after render;
- option combinations such as whitespace Selection, focus-only current line,
  or disabled validation decorations;
- whether line mapping, decoration layout, or only paint changes.

The matrix and member ledger are separate artifacts: the matrix explains
cross-part effects; the ledger proves complete source-unit accounting.

Review gate: stop after the inventory/ledger documentation commit.

## Test-Authority Corrections

- render_whitespace_options_wbtest.mbt proves construction/input forwarding but
  not update_options followed by DOM replacement.
- Existing cursor and inlay tests prove initial state, not dynamic decoration
  mutation while a caret/widget remains stationary.
- The historical cursor plan marks decoration invalidation as ported; current
  code is authoritative and shows the handler is absent.

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

The snapshot-diff event seam is the only expected architectural deviation.
It may remain only if every scoped Monaco event and branch has an equivalent
observable transition and tests. No missing payload field may be excused merely
because a later render can read global state.

## Exit Gate

- [ ] inventory rows equal ledger rows
- [ ] change-source/ViewPart matrix has no unexplained cell
- [ ] every exposed runtime option is tested through update_options
- [ ] dynamic inline decorations trigger cursor/widget recomputation without an unrelated event
- [ ] validation decorations update without an unrelated event
- [ ] no render loop or permanent dirty state is introduced
- [ ] all deviations have reviewed reasons
- [ ] all repository quality gates pass
- [ ] independent closing reread finds no unaccounted scoped member

## Execution Record

Not started. Append dated inventory, approval, implementation commits,
validation results, and final ledger totals here. Freeze after implementation.
