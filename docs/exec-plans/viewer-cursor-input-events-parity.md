# Viewer Cursor Input and Events Parity

Status: proposed — Phase 0 drafted; inventory pending

Date: 2026-07-10

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Findings: P1-01, P1-02

Depends on: viewer-model-lifecycle-ownership-parity.md

No product code may be changed until the inventory and parity ledger are
committed and reviewed.

## Goal

Establish one cursor-state transition and event-emission spine for public API,
mouse gestures, keyboard navigation, and model-content flushes. Readonly means
no text mutation; it does not replace Monaco cursor navigation with viewport
scrolling or permit cursor mutations that public listeners cannot observe.

## Scope (Phase 0)

### Pinned Monaco source

- vscode/src/vs/editor/common/cursor/cursor.ts
  - complete model-content-change, state-transition,
    _emitStateChangedIfNecessary, and outgoing-event cluster.
- vscode/src/vs/editor/common/cursor/cursorMoveCommands.ts
  - complete readonly movement clusters used by left/right/up/down,
    page movement, line start, line end, move-to, and selection extension.
- vscode/src/vs/editor/common/cursor/cursorMoveOperations.ts
  - complete movement operations consumed by the scoped commands.
- vscode/src/vs/editor/common/cursor/cursorCollection.ts
  - complete primary cursor collection/state propagation and event aggregation
    cluster; multi-cursor-only branches receive explicit N-A/DEFERRED rows.
- vscode/src/vs/editor/common/cursor/oneCursor.ts
  - complete state-setting and move clusters consumed above.
- vscode/src/vs/editor/common/cursorCommon.ts
  - complete state/reason/source data contracts consumed by the scoped
    commands.
- vscode/src/vs/editor/common/cursorEvents.ts
  - complete cursor-position/selection event payload contracts.
- vscode/src/vs/editor/browser/coreCommands.ts
  - complete cursor navigation command and keybinding clusters for arrows,
    PageUp/PageDown, Home/End, and Shift variants.
- vscode/src/vs/editor/browser/view/viewController.ts
  - complete dispatchMouse branches that apply to the single-cursor readonly
    surface.
- vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts
  - complete cursor-position/selection event-forwarding and public
    set-position/set-selection clusters.
- vscode/src/vs/editor/common/viewModelEventDispatcher.ts
  - complete outgoing cursor-position/cursor-selection event contracts,
    collector ordering, and emission cluster; configuration, decoration, and
    zone sibling events belong to their owning child plans.
- vscode/src/vs/editor/common/viewModel/viewModelImpl.ts
  - cursor-state outgoing-event emission cluster only; configuration,
    decorations, and whitespace/zone clusters are excluded.

### Local ownership

- viewer/input.mbt
- viewer/view_controller.mbt
- viewer/selection.mbt
- viewer/viewer.mbt
- viewer/common/cursor/cursors_controller.mbt
- viewer/common/cursor/core_navigation_commands.mbt
- viewer/common/cursor/cursor.mbt
- viewer/common/cursor/single_cursor_state.mbt
- viewer/common/cursor/cursor_context.mbt
- viewer/common/core/selection.mbt
- viewer/browser/view/view_user_input_events.mbt
- viewer/cursor_behavior_wbtest.mbt
- viewer/set_value_api_wbtest.mbt

### Explicitly out of scope

- text editing, undo/redo, paste, composition, and textarea/edit-context input;
- multi-cursor, column selection, multicursor modifiers, and middle-button
  clipboard behavior;
- cursor blink/style animation and secondary cursor rendering;
- scrollbar keyboard commands that use distinct registered command IDs;
- mouse-target geometry, except consuming the validated view/model position
  supplied by that subsystem.

Every excluded branch in dispatchMouse and coreCommands still receives a ledger
row with DEFERRED or N-A reason.

## Initial Decision Register

| Behavior | Decision |
|---|---|
| Unmodified arrows, PageUp/PageDown, Home/End scroll the viewport instead of moving the cursor | REQUIRED PARITY: replace |
| Shift variants extend the primary selection | REQUIRED PARITY |
| Left/Right cursor movement is absent | REQUIRED PARITY |
| Mouse click/drag/double/triple selection emits no public cursor events | REQUIRED PARITY |
| set_value flush resets the cursor without ContentFlush cursor events | REQUIRED PARITY |
| API setters use host model.version rather than internal content version in event payloads | REQUIRED PARITY |
| Single-cursor readonly reductions | INTENTIONAL DEVIATION, with per-branch ledger reasons |

This register is not the parity ledger and does not count toward the
source-member denominator.

## Inventory and Parity Ledger (Phases 1–2)

Inventory:

- every keybinding chord, precondition, command ID, movement direction/unit,
  reveal behavior, selection flag, source, and reason;
- every mouse dispatch branch and early return, including explicitly excluded
  multicursor/middle/column paths;
- previous/new cursor state comparison, model/view state update order, event
  order, version IDs, sources, reasons, and secondary-selection fields;
- content-flush reset and event path;
- public API setters and equality/no-op behavior.

The review must choose one shared local transition helper or source-shaped
equivalent so API, mouse, keyboard, and flush paths cannot emit different event
contracts. Do not add event calls independently at each symptom site without
accounting for Monaco's ordering and equality gates.

Review gate: stop after inventory and equal-size ledger are committed.

## Test-Authority Corrections

- Current cursor tests primarily cover public API setters and final cursor
  state. They do not prove mouse/keyboard/flush events.
- Existing scrolling tests do not establish that editor navigation keys should
  be consumed as scroll commands.
- set_value tests that assert only the reset position must add event ordering
  and internal version facts.

## Required Test Matrix (Phase 4)

Package/white-box tests:

- every navigation key with Shift false/true;
- Home/End on indentation, empty lines, wrapped continuation lines, and
  beginning/end boundaries;
- PageUp/PageDown with short and tall viewports;
- Left/Right across line boundaries and surrogate/grapheme-valid positions
  within the current cursor capability;
- exact-state no-op versus changed-state event emission;
- cursor move operations, primary collection state, and outgoing event payload
  arithmetic.

Use reference filenames only for exact upstream cursor tests ported with their
original labels, path, and current pin.

Headless Viewer integration:

- public API, direct keyboard dispatch, and direct mouse-dispatch paths reach
  the same cursor transition spine;
- click, drag, double-click, triple-click, gutter line select, and select-all;
- set_value ContentFlush event ordering and model version IDs;
- model-to-view and view-to-model selection consistency.

Browser tests:

- real keydown default prevention only when the editor handled the key;
- Shift selection is visibly rendered and public events report the same range;
- real pointer gestures emit one coherent event sequence;
- focus behavior is unchanged.

## Milestones

1. Inventory and ledger only; commit and stop.
2. Port exact upstream cursor tests where they exist and add ordinary
   source-derived tests for local event-spine integration.
3. Route API, mouse, and content-flush state changes through the approved
   transition/event spine.
4. Port the readonly core navigation commands and keybindings.
5. Add real browser keyboard/pointer conformance cases.
6. Update viewer/README.md and cursor package contracts.
7. Run focused and full quality gates.
8. Independent source/ledger/diff/test review.

## Deviations (Phase 3)

Expected candidates are editable commands, multi-cursor, column selection, and
middle-button behavior. None is approved until every excluded source branch is
inventoried and given a concrete readonly seam.

## Exit Gate

- [ ] inventory rows equal ledger rows
- [ ] API, mouse, keyboard, and flush share one reviewed transition contract
- [ ] every changed cursor state emits the correct ordered public events
- [ ] no-op transitions emit nothing
- [ ] all required navigation and Shift variants are covered
- [ ] event version IDs use the correct content version
- [ ] every omitted source branch has DEFERRED/N-A evidence
- [ ] all repository quality gates pass
- [ ] independent closing reread finds no unaccounted scoped member

## Execution Record

Not started. Append dated inventory, approval, implementation commits,
validation results, and final ledger totals here. Freeze after implementation.
