# Viewer Cursor Input and Events Parity

Status: second inventory amendment ready — STOP FOR FINAL GATE B REVIEW

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
    commands, plus the movement-consumed cursor-configuration atoms for tab
    size, indent size, sticky tab stops, line height, page size, and visible-
    column conversion. Atomic-tab implementation remains a separately named
    deferred dependency.
- vscode/src/vs/editor/common/cursorEvents.ts
  - complete cursor-position/selection event payload contracts.
- vscode/src/vs/editor/browser/coreCommands.ts
  - complete cursor navigation command and keybinding clusters for arrows,
    PageUp/PageDown, Home/End, and Shift variants.
- vscode/src/vs/editor/browser/view/viewController.ts
  - complete dispatchMouse branches that apply to the single-cursor readonly
    surface.
- vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts
  - public get/set-position and get/set-selection(s) clusters. The frozen
    lifecycle child already owns the shared delivery queue, cursor emitter
    lifetimes/aliases, and complete outgoing-event switch relay at its
    CEW-001, CEW-015/016, and CEW-123–139 rows; this child inherits and audits
    that authority without duplicating those source atoms.
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

### Uniform counting rule and combined denominator

The authoritative atom rule is one row per declared member, field/property,
behavior-changing branch or early return, independently reused/control-flow
magic constant, and source-owned callback. A property row carries its literal
or arithmetic without double-counting the constructor assignment. Straight-line
non-callback ordering stays on the owning method row. Plain allocation, final
return, and loop bookkeeping are not separate atoms. Excluded whole sibling
clusters are named in registries rather than represented by umbrella rows.

Every source row below remains `TODO` through Gate B. `Proposed terminal` is a
review target, not implementation evidence. Inherited lifecycle CEW rows and
current-MoonBit audit facts are outside this child's source denominator.

Exact source denominator:

```text
CUR 68 + COL 49 + ONE 28 + CCM 50 + CEV 18
+ CMC 156 + CMO 62
+ CORE 186 + VC 70 + CEW 23 + VED 60 + VMI 32
= 802 source rows
```

Proposed Gate-B map after the two failed-review amendments: **334 TESTED, 71
PORTED, 216 DEFERRED, 181 N-A = 802**. These totals must be recomputed after
any further review amendment.

The review must approve one shared transition/emission contract so API, mouse,
keyboard, and flush cannot drift into separate event semantics. No product or
test file may change before this documentation-only denominator is committed
and independently reviewed.

### Source inventory reports

#### Cursor core Phase 1 inventory (normalized, read-only)

Oracle: `b18492a288de038fbc7643aae6de8247029d11bd`

All 2,055 lines of the five assigned source files were read at the pinned
submodule commit. This revision uses the normalized atom rule: one row per
declared member/field/property, behavior-changing branch or early return,
independently reused/control-flow magic constant, and source-owned callback.
Straight-line statements remain on their owning constructor/method row.

| File | Lines | SHA-256 |
|---|---:|---|
| `cursor/cursor.ts` | 1,116 | `559cc56683e69b41fd30fedc22aeb49523994389c03863b073c0396f53bf6445` |
| `cursor/cursorCollection.ts` | 252 | `64237df92f27eb889a5b62da32f6f84fe08fd1c8a7714c93b746a7f26ee99353` |
| `cursor/oneCursor.ts` | 165 | `daaaad723fd72efb7436e89a1c746e9eb393967192336d5a7b5b36d9dc5b6ffa` |
| `cursorCommon.ts` | 427 | `4543ee4e4d583d9f237f5c4c32209b71358d076221a84cd0991ec25e70ae09cf` |
| `cursorEvents.ts` | 95 | `5a1375f826f617ad090628cf23eda9ce38bd4d20812b280a74161be8f493d081` |

Every ledger status is `TODO`; “Planned” is a proposed terminal disposition.

##### Closed inclusive boundaries

| File | Included complete unit(s) | Explicit sibling exclusions |
|---|---|---|
| `cursor.ts` | controller state fields/construction `27-88`; state read/write `104-139`; persisted state conversion `161-224`; model/injected-content change `226-271`; primary getters/setter `273-319`; event emitter `400-426`; `CursorModelState` `641-672` | auto-close validation `90-102`; reveal producers `141-159`; column selection `137-139,285-299`; edit accessors/handlers `313-398,428-639`; auto-close/command/composition units `674-1116` |
| `cursorCollection.ts` | whole `CursorCollection`, `15-252`; multi-cursor-only atoms remain explicit N-A | none hidden |
| `oneCursor.ts` | whole state owner, `16-165`; marker-only atoms remain explicit deferred | none hidden |
| `cursorCommon.ts` | movement-consumed configuration members `55-60,110-168,233-247`; `ICursorSimpleModel` `253-267`; cursor-state contracts `269-400` | column/edit/language configuration siblings `22-54,61-108,170-232`; edit result/quote helper `402-427` |
| `cursorEvents.ts` | whole reason and public payload contract, `12-95` | none |

Scope correction: movement consumes `tabSize`, `columnFromVisibleColumn`, and
`pageSize`; the page-size field carries exact
`max(1, floor(height / lineHeight) - 2)` arithmetic. The same source contract
also declares `stickyTabStops`, `indentSize`, and `getLineIndentColumn`.
Sticky-tab movement and its line-indent query feed the unscoped
`cursorAtomicMoveOperations.ts`; `indentSize` is only an inert signature
pass-through at this pin because the called helper never reads it.

##### `cursorCommon.ts` ledger (`CCM`, 50 rows)

| ID | Source atom | Description | Local target/seam | Proposed terminal | Status |
|---|---|---|---|---|---|
| CCM-001 | `tabSize` (`cursorCommon.ts:55,123`) | Field copies resolved model tab size. | cursor config from `ViewerOptions.tab_size` | TESTED | TODO |
| CCM-002 | `indentSize` (`:56,124`) | Field copies `modelOptions.indentSize`, but at this pin it has no movement effect: `right` forwards it to `rightPositionAtomicSoftTabs`, whose parameter is unused; `AtomicTabMoveOperations` receives `tabSize` only. | inert atomic-tab signature pass-through; no local behavior dependency | DEFERRED (unscoped atomic-tab signature; not a behavior dependency at this pin) | TODO |
| CCM-003 | `stickyTabStops` (`:58,126`) | Field selects atomic-soft-tab versus character movement. | cursorAtomicMoveOperations.ts is outside normalized movement D2 | DEFERRED (atomic-tab movement dependency is unscoped) | TODO |
| CCM-004 | `pageSize` (`:59,129`) | Field is exactly `max(1,floor(layoutHeight/lineHeight)-2)`. | derive from live viewport and line height | TESTED | TODO |
| CCM-005 | `lineHeight` (`:60,127`) | Field copies font line height used by page size. | existing layout/options | TESTED | TODO |
| CCM-006 | `CursorConfiguration` constructor (`:110-168`) | Constructs configuration in source order; tab/page/line-height projection is scoped, but the same member also owns unscoped atomic-tab and language/edit configuration. | split readonly navigation projection cannot claim the whole source constructor | DEFERRED (mixed constructor includes unscoped atomic-tab dependency) | TODO |
| CCM-007 | `columnFromVisibleColumn` (`:233-247`) | Converts using line content/tab size and returns the in-range raw result. | `viewer/common/core.column_from_visible_column` plus model clamps | TESTED | TODO |
| CCM-008 | minimum clamp (`:236-239`) | Result below line minimum returns minimum early. | navigation model adapter | TESTED | TODO |
| CCM-009 | maximum clamp (`:241-244`) | Result above line maximum returns maximum early. | navigation model adapter | TESTED | TODO |
| CCM-010 | `getLineCount` (`:254`) | Simple-model interface member. | TextModel/ViewModel adapter | TESTED | TODO |
| CCM-011 | `getLineContent` (`:255`) | Simple-model interface member in current coordinate space. | TextModel/ViewModel adapter | TESTED | TODO |
| CCM-012 | `getLineMinColumn` (`:256`) | Simple-model minimum valid one-based column. | adapter | TESTED | TODO |
| CCM-013 | `getLineMaxColumn` (`:257`) | Simple-model one-past-final UTF-16 column. | adapter | TESTED | TODO |
| CCM-014 | `getLineFirstNonWhitespaceColumn` (`:258`) | Interface member with `0` empty-line sentinel. | adapter | TESTED | TODO |
| CCM-015 | `getLineLastNonWhitespaceColumn` (`:259`) | Interface member for line-end navigation. | adapter | TESTED | TODO |
| CCM-016 | `normalizePosition` (`:260`) | Interface member clamps/snaps with affinity. | model/view adapter | TESTED | TODO |
| CCM-017 | `getLineIndentColumn` (`:266`) | Interface member supplies sticky-tab indentation stop. | consumed only by unscoped cursorAtomicMoveOperations.ts | DEFERRED (atomic-tab movement dependency is unscoped) | TODO |
| CCM-018 | `PartialCursorState` (`:269`) | Union of full, model-only, and view-only cursor states. | source-shaped transition input | TESTED | TODO |
| CCM-019 | `CursorState._cursorStateBrand` (`:272`) | TypeScript nominal brand field. | no runtime analogue | N-A (TypeScript nominal brand) | TODO |
| CCM-020 | `CursorState.fromModelState` (`:274-276`) | Constructs model-only partial state. | transition input constructor | TESTED | TODO |
| CCM-021 | `CursorState.fromViewState` (`:278-280`) | Constructs view-only partial state. | transition input constructor | TESTED | TODO |
| CCM-022 | `CursorState.fromModelSelection` (`:282-290`) | Lifts selection; builds collapsed Simple anchor and active end with both leftovers `0`. | `SingleCursorState::new` plus validation | TESTED | TODO |
| CCM-023 | `CursorState.fromModelSelections` (`:292-298`) | Converts selections in array order. | primary-only boundary; secondaries explicit N-A elsewhere | TESTED | TODO |
| CCM-024 | `CursorState.modelState` (`:300`) | Full-state model-coordinate property. | CursorState struct | TESTED | TODO |
| CCM-025 | `CursorState.viewState` (`:301`) | Full-state view-coordinate property. | CursorState struct | TESTED | TODO |
| CCM-026 | `CursorState` constructor (`:303-306`) | Retains model and view states. | CursorState constructor | TESTED | TODO |
| CCM-027 | `CursorState.equals` (`:308-310`) | Compares view then model state. | shared equality gate | TESTED | TODO |
| CCM-028 | `PartialModelCursorState.modelState` (`:314`) | Concrete model property. | transition input | TESTED | TODO |
| CCM-029 | `PartialModelCursorState.viewState` (`:315`) | Exact null view property. | MoonBit `Option` | TESTED | TODO |
| CCM-030 | `PartialModelCursorState` constructor (`:317-320`) | Retains model and null view. | transition constructor | TESTED | TODO |
| CCM-031 | `PartialViewCursorState.modelState` (`:324`) | Exact null model property. | MoonBit `Option` | TESTED | TODO |
| CCM-032 | `PartialViewCursorState.viewState` (`:325`) | Concrete view property. | transition input | TESTED | TODO |
| CCM-033 | `PartialViewCursorState` constructor (`:327-330`) | Retains null model and view. | transition constructor | TESTED | TODO |
| CCM-034 | `SelectionStartKind.Simple` (`:334`) | Enum value `0`. | existing `Simple` | TESTED | TODO |
| CCM-035 | `SelectionStartKind.Word` (`:335`) | Enum value `1`. | existing `Word` | TESTED | TODO |
| CCM-036 | `SelectionStartKind.Line` (`:336`) | Enum value `2`. | existing `Line` | TESTED | TODO |
| CCM-037 | `SingleCursorState._singleCursorStateBrand` (`:343`) | TypeScript nominal brand field. | no runtime analogue | N-A (TypeScript nominal brand) | TODO |
| CCM-038 | `SingleCursorState.selection` (`:345,354`) | Derived selection property computed at construction. | existing derived `selection` method | TESTED | TODO |
| CCM-039 | `selectionStart` (`:348`) | Anchor-range parameter-property. | existing start/end fields | TESTED | TODO |
| CCM-040 | `selectionStartKind` (`:349`) | Anchor-kind parameter-property. | existing kind | TESTED | TODO |
| CCM-041 | `selectionStartLeftoverVisibleColumns` (`:350`) | Anchor sticky-column parameter-property. | add missing field | TESTED | TODO |
| CCM-042 | `position` (`:351`) | Active-end parameter-property. | existing position | TESTED | TODO |
| CCM-043 | `leftoverVisibleColumns` (`:352`) | Active sticky-column parameter-property. | add missing field | TESTED | TODO |
| CCM-044 | `SingleCursorState` constructor (`:347-355`) | Retains five properties and computes selection. | extend `SingleCursorState::new` | TESTED | TODO |
| CCM-045 | `SingleCursorState.equals` (`:357-365`) | Compares both leftovers, kind, position, and anchor range. | derived Eq with new fields | TESTED | TODO |
| CCM-046 | `hasSelection` (`:367-369`) | True when derived selection or anchor range is nonempty. | existing `has_selection` | TESTED | TODO |
| CCM-047 | `move` (`:371-391`) | Returns a new state with supplied target/leftover. | extend existing `moved` | TESTED | TODO |
| CCM-048 | `move` selection branch (`:372-390`) | Selection mode preserves anchor/kind/anchor leftover; other arm collapses Simple and uses supplied leftover for both fields. | `SingleCursorState::moved` | TESTED | TODO |
| CCM-049 | `_computeSelection` (`:393-399`) | Produces oriented Selection from anchor range and active end. | existing selection derivation | TESTED | TODO |
| CCM-050 | `_computeSelection` branch (`:394-398`) | An empty anchor uses its start. For a nonempty anchor, active strictly after the anchor start uses the start; active equal to or before the anchor start uses the end. | selection-direction tests covering before/equal/after | TESTED | TODO |

##### `cursorEvents.ts` ledger (`CEV`, 18 rows)

| ID | Source atom | Description | Local target/seam | Proposed terminal | Status |
|---|---|---|---|---|---|
| CEV-001 | `NotSet = 0` (`cursorEvents.ts:16`) | Exact neutral reason used by API setPosition/setSelection and non-gesture transitions. | API setters must stop emitting Explicit | TESTED | TODO |
| CEV-002 | `ContentFlush = 1` (`:20`) | Exact flush reason. | emit on set-value reset | TESTED | TODO |
| CEV-003 | `RecoverFromMarkers = 2` (`:24`) | Exact recovery reason. | retained data contract | PORTED | TODO |
| CEV-004 | `Explicit = 3` (`:28`) | Exact mouse/keyboard/user-gesture reason; API setPosition/setSelection do not use it. | shared mouse/keyboard gesture producer | TESTED | TODO |
| CEV-005 | `Paste = 4` (`:32`) | Exact paste reason. | retained readonly-excluded contract | PORTED | TODO |
| CEV-006 | `Undo = 5` (`:36`) | Exact undo reason. | retained readonly-excluded contract | PORTED | TODO |
| CEV-007 | `Redo = 6` (`:40`) | Exact redo reason. | retained readonly-excluded contract | PORTED | TODO |
| CEV-008 | position event `position` (`:49`) | Primary model position property. | existing event field | TESTED | TODO |
| CEV-009 | `secondaryPositions` (`:53`) | Ordered secondary-position array property; under the approved single-cursor reduction every emitted payload carries exact `[]`. | public position payload field; assert empty for API/keyboard/mouse/flush | TESTED | TODO |
| CEV-010 | position event `reason` (`:57`) | Transition reason property. | shared emitter | TESTED | TODO |
| CEV-011 | position event `source` (`:61`) | Transition source property. | shared emitter | TESTED | TODO |
| CEV-012 | selection event `selection` (`:70`) | Primary model selection property. | existing field | TESTED | TODO |
| CEV-013 | `secondarySelections` (`:74`) | Ordered secondary-selection array property; under the approved single-cursor reduction every emitted payload carries exact `[]`. | public selection payload field; assert empty for API/keyboard/mouse/flush | TESTED | TODO |
| CEV-014 | `modelVersionId` (`:78`) | New internal content version. | use `get_version_id()`, not host `version` | TESTED | TODO |
| CEV-015 | `oldSelections` (`:82`) | Nullable old selection array. | change local field to Option | TESTED | TODO |
| CEV-016 | `oldModelVersionId` (`:86`) | Old internal version; `0` when no old state. | shared snapshot | TESTED | TODO |
| CEV-017 | selection event `source` (`:90`) | Same normalized transition source. | shared emitter | TESTED | TODO |
| CEV-018 | selection event `reason` (`:94`) | Same transition reason. | shared emitter | TESTED | TODO |

##### `oneCursor.ts` ledger (`ONE`, 28 rows)

| ID | Source atom | Description | Local target/seam | Proposed terminal | Status |
|---|---|---|---|---|---|
| ONE-001 | `modelState` (`oneCursor.ts:18,28-31`) | Model-state field is initialized to origin through `_setState`. | existing `Cursor.model_state` | TESTED | TODO |
| ONE-002 | `viewState` (`:19,31`) | View-state field is initialized to origin through `_setState`. | existing `Cursor.view_state` | TESTED | TODO |
| ONE-003 | `_selTrackedRange` (`:21,25`) | Marker ID field starts null. | no readonly cursor marker owner | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-004 | `_trackSelection` (`:22,26`) | Tracking flag starts true. | no edit transaction | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-005 | `Cursor` constructor (`:24-33`) | Source calls `_setState` with independent model/view `(1,1)`, Simple, zero-leftover states. The local constructor directly creates the same unambiguous origin pair; dual-side cross-validation remains ONE-028. | `Cursor::new` plus new leftovers | TESTED | TODO |
| ONE-006 | `dispose` (`:35-37`) | Removes owned tracked range. | no marker resource | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-007 | `startTrackingSelection` (`:39-42`) | Enables tracking then refreshes the marker. | no edit transaction | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-008 | `stopTrackingSelection` (`:44-47`) | Disables tracking then removes the marker. | no edit transaction | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-009 | `_updateTrackedRange` (`:49-55`) | Replaces marker from model selection using `AlwaysGrowsWhenTypingAtEdges`. | no tracked-range API | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-010 | tracking-disabled branch (`:50-53`) | Disabled tracking returns before marker mutation. | no edit transaction | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-011 | `_removeTrackedRange` (`:57-59`) | Sets tracked range to null with the same stickiness. | no tracked-range API | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-012 | `asCursorState` (`:61-63`) | Snapshots model and view state together. | add/source-shape CursorState | TESTED | TODO |
| ONE-013 | `readSelectionFromMarkers` (`:65-74`) | Reads marker and otherwise returns it with preserved old direction. | no cursor markers | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-014 | collapsed-marker branch (`:68-71`) | Empty old selection plus grown marker collapses to marker end. | no cursor markers | DEFERRED (editable marker-recovery lane) | TODO |
| ONE-015 | `ensureValidState` (`:76-78`) | Re-runs `_setState` with both current sides and therefore consumes the ONE-028 cross-validation branch. | no dual-side converter validation surface; local mapping change re-derives view state from validated model state only | DEFERRED (dual-side validation dependency absent) | TODO |
| ONE-016 | `setState` (`:80-82`) | Forwards nullable model/view inputs unchanged. | central cursor transition | TESTED | TODO |
| ONE-017 | `_validatePositionWithCache` (`:84-89`) | Cache miss normalizes with `PositionAffinity.None`. | cursor/view adapter | TESTED | TODO |
| ONE-018 | validation-cache branch (`:85-87`) | Equal cache input returns cache output early. | cursor validation tests | TESTED | TODO |
| ONE-019 | `_validateViewState` (`:91-112`) | Normalizes active/anchor endpoints and rebuilds with exact leftover correction arithmetic. | shared cursor validator | TESTED | TODO |
| ONE-020 | valid-view fast path (`:100-103`) | Three unchanged endpoints return original view state. | validator fast-path test | TESTED | TODO |
| ONE-021 | `_setState` (`:114-164`) | Validates/derives both coordinate states, assigns model then view, then updates marker. | central transition spine | TESTED | TODO |
| ONE-022 | supplied-view validation branch (`:115-117`) | A non-null view input is validated before model-side branching. | shared transition | TESTED | TODO |
| ONE-023 | missing-model branch (`:119-144`) | Missing model derives it from view; supplied model validates/rebuilds it. | shared transition | TESTED | TODO |
| ONE-024 | both-sides-null early return (`:120-122`) | Missing model and view returns without mutation. | Option-input no-op test | TESTED | TODO |
| ONE-025 | anchor-leftover conditional (`:136`) | Preserve iff validated anchor unchanged, otherwise exact `0`. | add leftover field | TESTED | TODO |
| ONE-026 | active-leftover conditional (`:141`) | Preserve iff validated active unchanged, otherwise exact `0`. | add leftover field | TESTED | TODO |
| ONE-027 | missing-view branch (`:146-152`) | Missing view converts both validated model anchor endpoints and the active position to view coordinates, preserving model kind and leftovers. | model-driven transition through the existing converter | TESTED | TODO |
| ONE-028 | supplied-both validation branch (`:153-158`) | When both model and view states are supplied, source cross-validates the view range/position against the model range/position before rebuilding the view state. | no `validateViewRange`/`validateViewPosition` converter surface; constructor origin is direct, while ensure/reflow dependents are deferred | DEFERRED (dual-side validation seam absent) | TODO |

##### `cursorCollection.ts` ledger (`COL`, 49 rows)

| ID | Source atom | Description | Local target/seam | Proposed terminal | Status |
|---|---|---|---|---|---|
| COL-001 | `context` (`cursorCollection.ts:17,30`) | Mutable collection context field. | existing controller context | TESTED | TODO |
| COL-002 | `cursors` (`:19-23,31`) | Array field starts with one primary at index `0`; length invariant `>=1`. | local single Cursor | TESTED | TODO |
| COL-003 | `lastAddedCursorIndex` (`:25-27,32`) | Secondary-relative index field starts exact `0`. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-004 | `CursorCollection` constructor (`:29-33`) | Retains context, creates primary, initializes last-added index. | `CursorsController::new` | TESTED | TODO |
| COL-005 | `dispose` (`:35-39`) | Disposes every cursor in order. | no marker resources | DEFERRED (editable marker-recovery lane) | TODO |
| COL-006 | `startTrackingSelections` (`:41-45`) | Starts tracking on every cursor. | no edit transaction | DEFERRED (editable marker-recovery lane) | TODO |
| COL-007 | `stopTrackingSelections` (`:47-51`) | Stops tracking on every cursor. | no edit transaction | DEFERRED (editable marker-recovery lane) | TODO |
| COL-008 | `updateContext` (`:53-55`) | Replaces context without implicit validation. | split current set-context/reproject ordering | TESTED | TODO |
| COL-009 | `ensureValidState` (`:57-61`) | Calls ONE-015 for every cursor, requiring both-side range/position cross-validation. | no dual-side converter validation surface; local one-cursor reflow is model-side reprojection | DEFERRED (dual-side validation dependency absent) | TODO |
| COL-010 | `readSelectionFromMarkers` (`:63-65`) | Maps cursors to recovered selections. | no marker recovery | DEFERRED (editable marker-recovery lane) | TODO |
| COL-011 | marker-read map callback (`:64`) | Calls each cursor with current context. | no marker recovery | DEFERRED (editable marker-recovery lane) | TODO |
| COL-012 | `getAll` (`:67-69`) | Maps cursors to full snapshots. | single-state getter | TESTED | TODO |
| COL-013 | full-state map callback (`:68`) | Calls `asCursorState` for each cursor. | primary snapshot | TESTED | TODO |
| COL-014 | `getViewPositions` (`:71-73`) | Maps cursors to active view positions. | view-position getter | TESTED | TODO |
| COL-015 | view-position map callback (`:72`) | Projects `viewState.position`. | view-position getter | TESTED | TODO |
| COL-016 | `getTopMostViewPosition` (`:75-80`) | Returns first minimum; non-null by collection invariant. | primary position locally | TESTED | TODO |
| COL-017 | topmost projection callback (`:78`) | `compareBy` projects each view position. | primary/sort conformance | TESTED | TODO |
| COL-018 | `getBottomMostViewPosition` (`:82-87`) | Returns last maximum; non-null by invariant. | primary position locally | TESTED | TODO |
| COL-019 | bottommost projection callback (`:85`) | `compareBy` projects each view position. | primary/sort conformance | TESTED | TODO |
| COL-020 | `getSelections` (`:89-91`) | Maps cursors to model selections. | model-selection getter | TESTED | TODO |
| COL-021 | model-selection map callback (`:90`) | Projects `modelState.selection`. | primary getter | TESTED | TODO |
| COL-022 | `getViewSelections` (`:93-95`) | Maps cursors to view selections. | view-selection getter | TESTED | TODO |
| COL-023 | view-selection map callback (`:94`) | Projects `viewState.selection`. | primary getter | TESTED | TODO |
| COL-024 | `setSelections` (`:97-99`) | Converts model selections then calls `setStates`. | shared primary transition | TESTED | TODO |
| COL-025 | `getPrimaryCursor` (`:101-103`) | Returns exact cursor index `0` snapshot. | controller state getter | TESTED | TODO |
| COL-026 | `setStates` (`:105-111`) | Sets primary first, then applies `states.slice(1)` to secondaries. | central primary transition | TESTED | TODO |
| COL-027 | null-state early return (`:106-108`) | Null states are a no-op. | Option input test | TESTED | TODO |
| COL-028 | `_setSecondaryStates` (`:116-135`) | Grows/shrinks cursor count, then assigns secondary states at `i+1`. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-029 | secondary-grow branch (`:120-124`) | Fewer cursors creates exact difference. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-030 | secondary-shrink branch (`:125-130`) | More cursors removes exact difference at `length-2`. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-031 | `killSecondaryCursors` (`:137-139`) | Sets secondary states to empty array. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-032 | `_addSecondaryCursor` (`:141-144`) | Appends Cursor and records `length-1`. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-033 | `getLastAddedCursorIndex` (`:146-151`) | Returns recorded secondary index outside fallback. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-034 | last-added fallback branch (`:147-149`) | Length `1` or recorded `0` returns exact `0`. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-035 | `_removeSecondaryCursor` (`:153-159`) | Adjusts index, disposes/splices at `removeIndex+1`. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-036 | removal-index branch (`:154-156`) | Recorded index at/after removal decrements. | no secondary cursor | N-A (single-cursor viewer) | TODO |
| COL-037 | `normalize` (`:161-251`) | Sorts and merges eligible overlapping secondary cursors; primary-only path exits. | exercise single-cursor early return | TESTED | TODO |
| COL-038 | normalize single-cursor early return (`:162-164`) | Exact length `1` returns before allocation/sort. | local invariant test | TESTED | TODO |
| COL-039 | `SortedCursor.index` (`:168`) | Local interface property retains original index. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-040 | `SortedCursor.selection` (`:169`) | Local mutable interface property retains selection. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-041 | normalization sort callback (`:179`) | `compareBy` projects sorted selection and compares range starts. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-042 | merge-option branch (`:188-190`) | Disabled merge continues to next pair. | no multi-cursor option | N-A (single-cursor viewer) | TODO |
| COL-043 | empty/ranged merge branch (`:193-199`) | Empty side merges touching (`<=`); two ranges merge only overlap (`<`). | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-044 | should-merge branch (`:201-249`) | Only eligible pair enters destructive merge/removal. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-045 | winner/loser index branch (`:202-206`) | Lower original cursor index wins; paired ternaries choose complementary sorted/original winner and loser indices. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-046 | unequal-selection branch (`:211-236`) | Equal winner/loser skips range/state recomputation. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-047 | last-added orientation branch (`:218-224`) | Last-added loser preserves loser direction and transfers index; else winner direction wins. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-048 | result-direction branch (`:227-231`) | LTR constructs start→end; else constructs end→start. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |
| COL-049 | reindex branch (`:238-242`) | Stored indices greater than removed loser decrement. | no multi-cursor normalization | N-A (single-cursor viewer) | TODO |

##### `cursor.ts` ledger (`CUR`, 68 rows)

| ID | Source atom | Description | Local target/seam | Proposed terminal | Status |
|---|---|---|---|---|---|
| CUR-001 | `_model` (`cursor.ts:29,45`) | Stable controller model field. | add model access to cursor owner | TESTED | TODO |
| CUR-002 | `_knownModelVersionId` (`:30,46`) | Field starts at model `getVersionId()`. | internal content-version snapshot | TESTED | TODO |
| CUR-003 | `_viewModel` (`:31,47`) | Stable simple view-model field. | navigation/view adapter | TESTED | TODO |
| CUR-004 | `_coordinatesConverter` (`:32,48`) | Stable model↔view converter field. | existing CursorContext | TESTED | TODO |
| CUR-005 | `context` (`:33,49`) | Replaceable CursorContext field. | extend existing context with nav config | TESTED | TODO |
| CUR-006 | `_cursors` (`:34,50`) | Collection field starts fresh and is replaceable on flush. | existing mutable single cursor | TESTED | TODO |
| CUR-007 | `_hasFocus` (`:36,52`) | Focus field starts false and controls non-flush recovery. | Viewer focus owner | DEFERRED (editable incremental-content lane) | TODO |
| CUR-008 | `_isHandling` (`:37,53`) | Reentrancy field starts false. | injected/reflow transition guard | TESTED | TODO |
| CUR-009 | `CursorsController` constructor (`:43-58`) | Captures dependencies, builds context then collection, and initializes scoped/excluded controller state. | controller construction | TESTED | TODO |
| CUR-010 | `dispose` (`:60-64`) | Disposes collection, auto-close actions, then superclass. | no marker/auto-close cursor resources | N-A (readonly resource seam) | TODO |
| CUR-011 | `updateConfiguration` (`:66-69`) | Rebuilds context then updates collection context. | preserve context/reprojection order | TESTED | TODO |
| CUR-012 | `onLineMappingChanged` (`:71-84`) | Calls `setStates(..., getCursorStates())` with source `viewModel` and reason NotSet; the full model/view pair reaches ONE-016/ONE-021 and the ONE-028 cross-validation branch directly. It does not call COL-009/ONE-015. | local mapping change re-derives view state from the validated model side only | DEFERRED (dual-side validation dependency absent) | TODO |
| CUR-013 | mapping-version early return (`:72-81`) | Known/live version mismatch returns until content event arrives. | view/content event ordering | TESTED | TODO |
| CUR-014 | `setHasFocus` (`:86-88`) | Replaces focus fact. | Viewer focus callback | DEFERRED (editable incremental-content lane) | TODO |
| CUR-015 | `getPrimaryCursorState` (`:106-108`) | Returns primary full state. | state getter | TESTED | TODO |
| CUR-016 | `getCursorStates` (`:114-116`) | Returns all full states in order. | single-element state array | TESTED | TODO |
| CUR-017 | `setStates` (`:118-135`) | Captures old snapshot, applies/normalizes states, clears edit auxiliaries, then delegates emission and returns changed. | one shared API/mouse/keyboard/flush spine | TESTED | TODO |
| CUR-018 | max-cursor branch (`:121-124`) | Too many non-null states are sliced and max flag set. | no secondary cursors | N-A (single-cursor viewer) | TODO |
| CUR-019 | `saveState` (`:161-183`) | Converts ordered model selections to persisted cursor-state objects. | no persisted-editor-state API | N-A (persistence surface out of scope) | TODO |
| CUR-020 | saved `inSelectionMode` (`:170`) | Returned property is `!selection.isEmpty()`. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-021 | saved `selectionStart` (`:171-174`) | Returned nested anchor object property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-022 | saved anchor `lineNumber` (`:172`) | Atomic nested returned property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-023 | saved anchor `column` (`:173`) | Atomic nested returned property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-024 | saved `position` (`:175-178`) | Returned nested active object property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-025 | saved position `lineNumber` (`:176`) | Atomic nested returned property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-026 | saved position `column` (`:177`) | Atomic nested returned property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-027 | `restoreState` (`:185-224`) | Normalizes persisted inputs into model selections, sets states, then reveals. | no persisted-editor-state API | N-A (persistence surface out of scope) | TODO |
| CUR-028 | restore default constant (`:192-193`) | Reused missing position line/column default is exact `1`; anchor defaults to resolved position. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-029 | position-line branch (`:196-198`) | Truthy provided line overrides default. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-030 | position-column branch (`:199-201`) | Truthy provided column overrides default. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-031 | anchor-line branch (`:207-209`) | Truthy provided anchor line overrides active default. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-032 | anchor-column branch (`:210-212`) | Truthy provided anchor column overrides active default. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-033 | restored `selectionStartLineNumber` (`:215`) | Atomic ISelection object property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-034 | restored `selectionStartColumn` (`:216`) | Atomic ISelection object property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-035 | restored `positionLineNumber` (`:217`) | Atomic ISelection object property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-036 | restored `positionColumn` (`:218`) | Atomic ISelection object property. | no persistence API | N-A (persistence surface out of scope) | TODO |
| CUR-037 | `onModelContentChanged` (`:226-271`) | Owns injected and raw content transitions in source order: injected reprojection; raw version capture; raw edit-group reset to `EditOperationType.Other`; then flush reset/emission or result/marker recovery. The edit-group reset is explicitly excluded editable bookkeeping. | set-value plus injected/reflow spine; edit-group reset excluded at `:251` | TESTED | TODO |
| CUR-038 | injected/raw branch (`:227-270`) | Injected events reproject current states under handling guard; raw events update version and take flush/recovery path. | source-shaped event seam | TESTED | TODO |
| CUR-039 | injected handling early return (`:229-232`) | Nested injected event returns while an outer handling operation will update positions. | reentrancy test seam | TESTED | TODO |
| CUR-040 | raw handling early return (`:246-248`) | Raw nested event returns after known version is updated. | flush/reentrancy ordering | TESTED | TODO |
| CUR-041 | flush branch (`:253-269`) | Flush disposes/recreates the cursor collection, validates auto-closed actions, then emits source `model`, reason `ContentFlush`, null old state, and reached-max false; nonflush raw events enter result/marker recovery. Auto-close validation is explicitly excluded editable bookkeeping. | set-value ordered cursor events; auto-close validation excluded at `:257` | TESTED | TODO |
| CUR-042 | focused-result branch (`:260-268`) | Focus plus nonempty resulting selections uses them; otherwise marker selections recover. | no incremental editable producer | DEFERRED (editable marker-recovery lane) | TODO |
| CUR-043 | undo reason branch (`:262`) | `isUndoing` selects Undo before any redo check. | no incremental editable producer | DEFERRED (editable incremental-content lane) | TODO |
| CUR-044 | redo reason branch (`:262`) | When not undoing, `isRedoing` selects Redo; otherwise RecoverFromMarkers. | no incremental editable producer | DEFERRED (editable incremental-content lane) | TODO |
| CUR-045 | changed-result reveal branch (`:262-264`) | Recovery reveals only when `setStates` reports changed. | no incremental editable producer | DEFERRED (editable incremental-content lane) | TODO |
| CUR-046 | `getSelection` (`:273-275`) | Returns primary model selection. | existing getter | TESTED | TODO |
| CUR-047 | `getTopMostViewPosition` (`:277-279`) | Delegates topmost view position. | primary view position locally | TESTED | TODO |
| CUR-048 | `getBottomMostViewPosition` (`:281-283`) | Delegates bottommost view position. | primary view position locally | TESTED | TODO |
| CUR-049 | `getSelections` (`:301-303`) | Returns ordered model selections. | single-selection read | TESTED | TODO |
| CUR-050 | `getPosition` (`:305-307`) | Returns primary model active position. | existing getter | TESTED | TODO |
| CUR-051 | `setSelections` (`:309-311`) | Converts model selections and delegates unchanged source/reason to `setStates`. | common transition entry | TESTED | TODO |
| CUR-052 | `_emitStateChangedIfNecessary` (`:403-426`) | Captures new snapshot, equality-gates, emits view first, conditionally emits outgoing aggregate, returns changed. | common render/public emitter | TESTED | TODO |
| CUR-053 | full-state equality early return (`:405-407`) | Equal old/new snapshot emits nothing and returns false. | no-op transition tests | TESTED | TODO |
| CUR-054 | outgoing-event branch (`:416-423`) | Emits only for null old state, cursor-count change, or any changed model state; view-only changes skip public event. | second emission gate | TESTED | TODO |
| CUR-055 | model-state `some` callback (`:418`) | Compares each new model state to same-index old model state. | source-owned callback | TESTED | TODO |
| CUR-056 | old-selections conditional (`:420`) | Null old state yields null; otherwise maps old model selections. | make local payload nullable | TESTED | TODO |
| CUR-057 | old-selection map callback (`:420`) | Projects each old state's model selection. | source-owned callback | TESTED | TODO |
| CUR-058 | old-version conditional (`:421`) | Null old state yields exact `0`; otherwise old internal version. | shared snapshot | TESTED | TODO |
| CUR-059 | source fallback (`:422`) | Null/undefined/empty source falls back to exact `keyboard`. | explicit MoonBit normalization | TESTED | TODO |
| CUR-060 | `CursorModelState.from` (`:645-647`) | Captures model internal version and cursor states together. | private snapshot helper | TESTED | TODO |
| CUR-061 | `modelVersionId` (`:650`) | Snapshot parameter-property. | `TextModel.get_version_id()` | TESTED | TODO |
| CUR-062 | `cursorState` (`:651`) | Ordered full-state array parameter-property. | one-element local array | TESTED | TODO |
| CUR-063 | `CursorModelState` constructor (`:649-653`) | Retains version and cursor states. | private snapshot type | TESTED | TODO |
| CUR-064 | `CursorModelState.equals` (`:655-671`) | Compares nullable snapshot, version, count, then every full state. | shared equality helper | TESTED | TODO |
| CUR-065 | null-snapshot early return (`:656-658`) | Null other is unequal. | flush/no-old tests | TESTED | TODO |
| CUR-066 | version-mismatch early return (`:659-661`) | Different internal versions are unequal. | version-only change test | TESTED | TODO |
| CUR-067 | count-mismatch early return (`:662-664`) | Different cursor counts are unequal. | count invariant locally | N-A (single-cursor viewer) | TODO |
| CUR-068 | per-state mismatch early return (`:665-668`) | First unequal full CursorState returns false. | state equality tests | TESTED | TODO |

##### Explicit sibling registry (outside the 213-row denominator)

These closed siblings were found by the whole-file reread. Their internals are
not counted unless Phase 0 expands scope.

###### `cursor.ts`

| Lines | Complete excluded sibling/member(s) | Reason |
|---|---|---|
| `38-41,54-57` | `_compositionState`, `_columnSelectData`, `_autoClosedActions`, `_prevEditOperationType` and constructor literals | composition, column selection, auto-close, edit grouping |
| `62` | auto-closed-action disposal inside shared `dispose` | auto-close lifecycle |
| `90-102` | `_validateAutoClosedActions`, its invalid-action branch and loop rewind | auto-close edit state |
| `110-112` | `getLastAddedCursorIndex` | secondary cursor |
| `137-139` | `setCursorColumnSelectData` | column selection |
| `141-153` | `revealAll`, including one-vs-many branch and reveal event | reveal/scroll child ownership |
| `155-159` | `revealPrimary` | reveal/scroll child ownership |
| `251` | raw-content `_prevEditOperationType = EditOperationType.Other` reset inside included `onModelContentChanged` | edit grouping |
| `257` | post-flush `_validateAutoClosedActions()` call inside included `onModelContentChanged` | auto-close editing |
| `285-299` | `getCursorColumnSelectData`, stored/synthetic branch and `isReal:false` result | column selection |
| `313-319` | get/set previous edit-operation type | edit grouping |
| `321-348` | `_pushAutoClosedAction`, decoration callbacks/properties and exact DOM class descriptions | auto-close editing |
| `350-388` | `_executeEditOperation` and all edit/stack/auto-close branches | text editing |
| `390-398` | `_interpretCommandResult` and marker fallback | command execution |
| `431-465` | `_findAutoClosingPairs`, regex and all early returns/index arithmetic | auto-close/snippet editing |
| `467-507` | `executeEdits`, push-edit callback and tracked-range arithmetic | programmatic editing |
| `509-532` | `_executeEdit`, readonly early return, edit callback/try/catch/reveal | edit transaction |
| `534-536` | `getAutoClosedCharacters` | auto-close editing |
| `538-554` | start/end composition and callback | IME editing |
| `556-579` | `type` and keyboard/non-keyboard branches | typing |
| `581-599` | `compositionType` and no-op/position-delta branches | IME editing |
| `601-607` | `paste` | paste editing |
| `609-614` | `cut` | cut editing |
| `616-627` | `executeCommand` | command editing |
| `629-638` | `executeCommands` | command editing |
| `674-738` | complete `AutoClosedAction`: static aggregator; `_model`; both decoration fields; constructor; dispose; range getter; validity method/branches | auto-close lifecycle |
| `740-745` | `IExecContext`: model, pre-selections, tracked ranges, tracked directions | command executor |
| `747-755` | `ICommandData`/`ICommandsData`: operations and tracked-edit flags | command executor |
| `757-1032` | complete `CommandExecutor` and owned callbacks/branches/constants | text commands and multi-cursor conflict resolution |
| `1034-1041` | `CompositionLineState`: four parameter-properties and constructor | IME editing |
| `1043-1116` | complete `CompositionState`: `_original`, capture/constructor/outcome methods and branches | IME editing |

###### `cursorCommon.ts`

| Lines | Complete excluded sibling/member(s) | Reason |
|---|---|---|
| `22-28` | `IColumnSelectData`: `isReal`, `fromViewLineNumber`, `fromViewVisualColumn`, `toViewLineNumber`, `toViewVisualColumn` | column selection |
| `34-41` | `EditOperationType`: exact values `0,2,3,4,5,6` and intentional gap `1` | edit grouping |
| `43-45` | `CharacterMap` index property | auto-surround editing |
| `47-49` | three auto-close callbacks and exact space/tab values | auto-close editing |
| `52,54,57,61-85` | brand plus all non-navigation config fields: readonly, insert-spaces, width, tab/delete/word/clipboard/multicursor/auto-close/surround/indent/pair/comment/locale/overtype/language/electric fields | non-navigation configuration |
| `87-108` | `shouldRecreate` and all 18 option checks | configuration lifecycle |
| `110-168` | non-navigation constructor assignments, language-service property, surrounding-pair branch, nullable comment token | shared constructor's excluded language/edit projection |
| `170-181` | electric-character getter and branches | typing |
| `183-185` | input-mode getter | insert/overtype editing |
| `190-197` | `onElectricCharacter` and absent-support branch | typing |
| `199-201` | `normalizeIndentation` | typing |
| `203-214` | `_getShouldAutoClose` and four switch branches | auto-close editing |
| `216-219` | language-defined auto-close method and callback | auto-close editing |
| `225-227` | `visibleColumnFromColumn` | assigned-file caller is excluded column-selection fallback; movement calls CursorColumns directly |
| `402-423` | `EditOperationResult`: brand, four properties, constructor | command editing |
| `425-427` | `isQuote` and exact quote literals | typing |

`cursorCollection.ts`, `oneCursor.ts`, and `cursorEvents.ts` have no hidden
sibling units: multi-cursor and marker atoms are ledgered as N-A/DEFERRED.

##### Counts and planned terminal map

| Prefix/file | Rows | TESTED | PORTED | DEFERRED | N-A |
|---|---:|---:|---:|---:|---:|
| `CUR` / `cursor.ts` | 68 | 40 | 0 | 7 | 21 |
| `COL` / `cursorCollection.ts` | 49 | 22 | 0 | 6 | 21 |
| `ONE` / `oneCursor.ts` | 28 | 16 | 0 | 12 | 0 |
| `CCM` / `cursorCommon.ts` | 50 | 44 | 0 | 4 | 2 |
| `CEV` / `cursorEvents.ts` | 18 | 14 | 4 | 0 | 0 |
| **Total** | **213** | **136** | **4** | **29** | **44** |

##### Required local seams exposed by the inventory

1. Add one source-shaped cursor transition/emission spine below API, mouse,
   keyboard, mapping/injected-text reflow, and content flush.
2. Snapshot `TextModel.get_version_id()`, not host-controlled `model.version`.
3. Make `old_selections` nullable for the flush `oldState=null` contract.
4. Add both leftover-visible-column fields and preserve/reset exact arithmetic.
5. Centralize model/view validation and partial-side derivation at the
   ViewModel/cursor seam; live callers supply exactly one coordinate side and
   ONE-028 explicitly defers the absent dual-side cross-validation branch.
6. Notify/render view before public outgoing events, while suppressing outgoing
   events for view-only projection changes.
7. Preserve source fallback: null/undefined/empty source becomes `keyboard`.
8. Preserve source reason ownership: API setPosition/setSelection use NotSet;
   mouse and keyboard gestures use Explicit.

##### Source-derived test axes

- Page-size floor/minus-two/min-one boundaries and tab/indent option axes.
- Model-only, view-only, and both-null cursor states; validation fast paths and
  leftover-column clamp resets. Both-present cross-validation is the explicit
  ONE-028 deferred negative control.
- Full no-op, model change, view-only change, version-only change, and flush with
  null old state.
- Mutation → view/render → outgoing order and changed-return semantics.
- API, mouse, keyboard, injected/reflow, and flush through one transition spine.
- Primary index zero, normalization early return, empty secondary payloads.

#### Cursor movement Phase 1 inventory — normalized

Oracle: `vscode` at `b18492a288de038fbc7643aae6de8247029d11bd` (verified with `git -C vscode rev-parse HEAD`). Both named files were read completely.

##### Normalization rule

One row per declared method/field/constant/type member, behavior-changing branch or early return, and independently material callback/control-flow magic constant. Straight-line statements, ordinary final returns, and allocation/bookkeeping remain on their owning member row. A cursor-array loop gets a separate row only where its cardinality is independently material to the viewer's single-cursor reduction.

##### Closed scope

- `cursorMoveCommands.ts`: complete `CursorMoveCommands` class, lines 16-693 (42 methods), plus consumed `SimpleMoveArguments`/`Direction`/direction-union/`Unit` cluster, lines 922-978.
- `cursorMoveOperations.ts`: complete file behavior unit, lines 15-356: all four `CursorPosition` fields, its constructor, and all 24 `MoveOperations` methods.
- Explicit non-denominator boundary in `cursorMoveCommands.ts`: generic JSON `cursorMove` validation/schema/parser cluster, lines 695-920. The viewer exposes no such JSON command. Typed arguments/enums consumed by bound commands remain included.
- DOM/CSS: N-A; neither file owns DOM or CSS.

Normalized denominator after Gate-B callback splitting: **218 rows = CMC 156
+ CMO 62**.

##### Local target/seam codes

| Code | Owner / seam |
|---|---|
| `CMD` | New source-shaped `viewer/common/view_model/cursor_move_commands.mbt`. `view_model` already imports `cursor`; placing this code in `cursor` would create a dependency cycle. |
| `OPS` | New source-shaped `viewer/common/view_model/cursor_move_operations.mbt`, using existing `viewer/common/core/cursor_columns.mbt`. |
| `STATE` | `viewer/common/cursor/single_cursor_state.mbt` for leftover-visible-column state. |
| `INPUT` | `viewer/input.mbt` and the sibling `coreCommands.ts` keybinding inventory. |
| `MOUSE` | Existing `viewer/view_controller.mbt`, routed through the shared cursor transition/event spine. |

Reason codes: `N1` single-cursor cardinality; `N2` add/translate-cursor only; `N3` TypeScript nominal brand; `D1` unbound generic cursorMove direction; `D2` unmodeled stickyTabStops/atomic-tab option; `D3` absent view text-direction query (current view line is LTR); `D4` unbound sticky-End option; `D5` unbound expand/cancel/buffer command; `D6` word implementation belongs to `cursorWordOperations.ts`.

##### CMC ledger — `cursorMoveCommands.ts`

| ID | Source member (line) | Normalized behavior atom | Local target | Proposed terminal | Status |
|---|---|---|---|---|---|
| CMC-001 | `addCursorDown` (18-31) | Member: interleave every original cursor with one translated-down cursor; `resultLen` starts at 0. | `CMD` | N-A (N2 add-cursor only) | TODO |
| CMC-002 | `addCursorDown` (24-28) | Branch: logical line selects model `translateDown`; otherwise view `translateDown`. | `CMD` | N-A (N2 add-cursor only) | TODO |
| CMC-003 | `addCursorUp` (33-46) | Member: interleave every original cursor with one translated-up cursor; `resultLen` starts at 0. | `CMD` | N-A (N2 add-cursor only) | TODO |
| CMC-004 | `addCursorUp` (39-43) | Branch: logical line selects model `translateUp`; otherwise view `translateUp`. | `CMD` | N-A (N2 add-cursor only) | TODO |
| CMC-005 | `moveToBeginningOfLine` (48-56) | Member: map cursor states through `_moveToLineStart`, preserving selection mode. | `CMD`/`INPUT` | TESTED | TODO |
| CMC-006 | `moveToBeginningOfLine` (50-53) | Cardinality: maps all cursors, locally only the primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-007 | `_moveToLineStart` (58-72) | Member: compare view/model columns and view first-nonblank before choosing coordinate space. | `CMD` | TESTED | TODO |
| CMC-008 | `_moveToLineStart` (67-71) | Branch: non-first wrapped segment and not at view first-nonblank returns view Home; all other cases return model Home. | `CMD` | TESTED | TODO |
| CMC-009 | `_moveToLineStartByView` (74-78) | Member: return view-state `MoveOperations.moveToBeginningOfLine`. | `CMD`/`OPS` | TESTED | TODO |
| CMC-010 | `_moveToLineStartByModel` (80-84) | Member: return model-state `MoveOperations.moveToBeginningOfLine`. | `CMD`/`OPS` | TESTED | TODO |
| CMC-011 | `moveToEndOfLine` (86-94) | Member: map states through `_moveToLineEnd`, forwarding selection and sticky. | `CMD`/`INPUT` | TESTED | TODO |
| CMC-012 | `moveToEndOfLine` (88-91) | Cardinality: maps all cursors, locally only the primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-013 | `_moveToLineEnd` (96-110) | Member: compare view max and model/view remaining-column distances. | `CMD` | TESTED | TODO |
| CMC-014 | `_moveToLineEnd` (105-109) | Branch: end-of-view or final wrapped segment returns model End; otherwise view End. | `CMD` | TESTED | TODO |
| CMC-015 | `_moveToLineEndByView` (112-116) | Member: return view-state End, forwarding sticky. | `CMD`/`OPS` | TESTED | TODO |
| CMC-016 | `_moveToLineEndByModel` (118-122) | Member: return model-state End, forwarding sticky. | `CMD`/`OPS` | TESTED | TODO |
| CMC-017 | `expandLineSelection` (124-147) | Member: expand from selection start line to selection end's following line; exact line-start column 1 and leftovers 0. | `CMD` | DEFERRED (D5 command unbound) | TODO |
| CMC-018 | `expandLineSelection` (126-145) | Cardinality: maps all cursors, locally only the primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-019 | `expandLineSelection` (134-139) | Branch: at EOF use final max column; otherwise increment end line and use column 1. | `CMD` | DEFERRED (D5 command unbound) | TODO |
| CMC-020 | `moveToBeginningOfBuffer` (149-156) | Member: model-state beginning-of-buffer movement. | `CMD`/`OPS` | DEFERRED (D5 command unbound) | TODO |
| CMC-021 | `moveToBeginningOfBuffer` (151-154) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-022 | `moveToEndOfBuffer` (158-165) | Member: model-state end-of-buffer movement. | `CMD`/`OPS` | DEFERRED (D5 command unbound) | TODO |
| CMC-023 | `moveToEndOfBuffer` (160-163) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-024 | `selectAll` (167-175) | Member: anchor `(1,1)`, active `(lineCount,maxColumn)`, `Simple`, leftovers 0. | `CMD`/`MOUSE` | TESTED | TODO |
| CMC-025 | `line` (177-234) | Member: validate model position and compute new/continued whole-line selection. | `CMD`/`MOUSE` | TESTED | TODO |
| CMC-026 | `line` (179-183) | Branch: supplied view position is validated against model position; absent value converts model-to-view. | `CMD` | TESTED | TODO |
| CMC-027 | `line` (185-200) | Early-return branch: not in selection mode creates `Line` anchor from clicked line start to following-line start. | `CMD` | TESTED | TODO |
| CMC-028 | `line` (191-194) | Branch: following model line beyond EOF clamps to last line/max column. | `CMD` | TESTED | TODO |
| CMC-029 | `line` (205-210) | Early-return branch: target before anchor moves view state to target line, column 1, leftover 0. | `CMD` | TESTED | TODO |
| CMC-030 | `line` (211-225) | Early-return branch: target after anchor moves to following view line, selection true, leftover 0. | `CMD` | TESTED | TODO |
| CMC-031 | `line` (217-220) | Branch: following view line beyond EOF clamps to last view line/max column. | `CMD` | TESTED | TODO |
| CMC-032 | `line` (226-231) | Final branch: target on anchor line returns to selection-start range end. | `CMD` | TESTED | TODO |
| CMC-033 | `word` (236-239) | Member: validate the model position, then delegate the complete word-boundary/state computation to `WordOperations.word`. | existing local `word_range` behavior is selected-case regression evidence only, not a 1:1 `WordOperations` owner | DEFERRED (D6 word algorithm unscoped; selected exact cases do not close this member) | TODO |
| CMC-034 | `cancelSelection` (241-253) | Member: collapse at current view position as `Simple`, leftovers 0. | `CMD` | DEFERRED (D5 command unbound) | TODO |
| CMC-035 | `cancelSelection` (242-244) | Early return: no selection preserves both model and view state. | `CMD` | DEFERRED (D5 command unbound) | TODO |
| CMC-036 | `moveTo` (255-271) | Member: validate/convert position then move view state with selection mode, leftover 0. | `CMD`/`MOUSE` | TESTED | TODO |
| CMC-037 | `moveTo` (257-259) | Early return: selection mode with a `Word` anchor routes to the word-selection seam before ordinary move-to validation/conversion. This routing fact is scoped and tested; CMC-033 and the complete `WordOperations` algorithm remain D6. | `MOUSE` routing only | TESTED | TODO |
| CMC-038 | `moveTo` (260-262) | Early return: selection mode with `Line` anchor dispatches to `line`. | `MOUSE` | TESTED | TODO |
| CMC-039 | `moveTo` (265-269) | Branch: supplied view position validates; absent value converts model-to-view. | `CMD` | TESTED | TODO |
| CMC-040 | `simpleMove` (273-355) | Member: closed switch over `SimpleMoveDirection`, forwarding selection/value/unit. | `CMD`/`INPUT` | TESTED | TODO |
| CMC-041 | `simpleMove` Left (275-282) | Direction case: non-HalfLine returns value-column left; HalfLine is CMC-146. | `CMD` | TESTED | TODO |
| CMC-042 | `simpleMove` Right (284-291) | Direction case: non-HalfLine returns value-column right; HalfLine is CMC-147. | `CMD` | TESTED | TODO |
| CMC-043 | `simpleMove` Up WrappedLine (293-296) | Direction/unit arm returns view-line movement. | `CMD` | TESTED | TODO |
| CMC-044 | `simpleMove` Down WrappedLine (305-308) | Direction/unit arm returns view-line movement. | `CMD` | TESTED | TODO |
| CMC-045 | `simpleMove` PrevBlankLine (317-323) | Branch: WrappedLine uses view state; otherwise model state. | `CMD` | DEFERRED (D1 generic blank-line) | TODO |
| CMC-046 | `simpleMove` NextBlankLine (324-330) | Branch: WrappedLine uses view state; otherwise model state. | `CMD` | DEFERRED (D1 generic blank-line) | TODO |
| CMC-047 | `simpleMove` WrappedLineStart (331-334) | Branch returns view minimum column. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-048 | `simpleMove` WrappedLineFirstNonWhitespaceCharacter (335-338) | Branch returns view first-nonwhite column. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-049 | `simpleMove` WrappedLineColumnCenter (339-342) | Branch returns rounded view center. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-050 | `simpleMove` WrappedLineEnd (343-346) | Branch returns view max column. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-051 | `simpleMove` WrappedLineLastNonWhitespaceCharacter (347-350) | Branch returns view last-nonwhite column. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-052 | `simpleMove` default (351-352) | Early return `null` for an unrecognized direction. | `CMD` | TESTED | TODO |
| CMC-053 | `viewportMove` (357-391) | Member: convert complete view range to model and dispatch viewport placement. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-054 | `viewportMove` Top (361-366) | Branch: nth included line from top, first-nonwhite column, primary only. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-055 | `viewportMove` Bottom (367-372) | Branch: nth included line from bottom, first-nonwhite column, primary only. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-056 | `viewportMove` Center (373-378) | Branch: exact `round((startLine+endLine)/2)`, first-nonwhite, primary only. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-057 | `viewportMove` IfOutside (379-387) | Branch maps every cursor through `findPositionInViewportIfOutside`. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-058 | `viewportMove` default (388-389) | Early return `null`. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-059 | `findPositionInViewportIfOutside` (393-412) | Member: preserve column/leftover while vertically moving into complete viewport. | `CMD`/`OPS` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-060 | `findPositionInViewportIfOutside` (396-399) | Early return unchanged when `start <= line <= end - 1`; exact partial-last-line offset 1. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-061 | `findPositionInViewportIfOutside` (402-408) | Branch: below -> `end-1`; above -> start; otherwise retain current line. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-062 | `_firstLineNumberInRange` (417-425) | Member: return `min(end,start+count-1)`. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-063 | `_firstLineNumberInRange` (419-422) | Branch: range starts after line min, so skip that first line. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-064 | `_lastLineNumberInRange` (430-438) | Member: return `max(start,end-count+1)`. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-065 | `_lastLineNumberInRange` (432-435) | Branch: range starts after line min, so skip that first line. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-066 | `_moveLeft` (440-451) | Member: map visual-left through logical movement. | `CMD`/`OPS` | TESTED | TODO |
| CMC-067 | `_moveLeft` (441-450) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-068 | `_moveLeft` (442-449) | Branch: RTL swaps to logical right; non-RTL uses logical left. | `CMD` | DEFERRED (D3 RTL branch; LTR on member row) | TODO |
| CMC-069 | `_moveHalfLineLeft` (453-462) | Member: exact `round(viewLineLength/2)` then view-state left. | `CMD`/`OPS` | DEFERRED (D1 generic half-line) | TODO |
| CMC-070 | `_moveHalfLineLeft` (455-460) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-071 | `_moveRight` (464-475) | Member: map visual-right through logical movement. | `CMD`/`OPS` | TESTED | TODO |
| CMC-072 | `_moveRight` (465-474) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-073 | `_moveRight` (466-473) | Branch: RTL swaps to logical left; non-RTL uses logical right. | `CMD` | DEFERRED (D3 RTL branch; LTR on member row) | TODO |
| CMC-074 | `_moveHalfLineRight` (477-486) | Member: exact `round(viewLineLength/2)` then view-state right. | `CMD`/`OPS` | DEFERRED (D1 generic half-line) | TODO |
| CMC-075 | `_moveHalfLineRight` (479-484) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-076 | `_moveDownByViewLines` (488-495) | Member: map view states through `moveDown(linesCount)`. | `CMD`/`OPS` | TESTED | TODO |
| CMC-077 | `_moveDownByViewLines` (490-493) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-078 | `_moveDownByModelLines` (497-504) | Member: map model states through `moveDown(linesCount)`. | `CMD`/`OPS` | DEFERRED (D1 generic model-line unit) | TODO |
| CMC-079 | `_moveDownByModelLines` (499-502) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-080 | `_moveUpByViewLines` (506-513) | Member: map view states through `moveUp(linesCount)`. | `CMD`/`OPS` | TESTED | TODO |
| CMC-081 | `_moveUpByViewLines` (508-511) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-082 | `_moveUpByModelLines` (515-522) | Member: map model states through `moveUp(linesCount)`. | `CMD`/`OPS` | DEFERRED (D1 generic model-line unit) | TODO |
| CMC-083 | `_moveUpByModelLines` (517-520) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-084 | `_moveDownByFoldedLines` (524-541) | Member: compute folded target/delta and move model state. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-085 | `_moveDownByFoldedLines` (529-540) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-086 | `_moveDownByFoldedLines` (530-532) | Branch: non-extending selection starts at selection end; otherwise active position. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-087 | `_moveDownByFoldedLines` (536-538) | Early return unchanged on exact delta 0. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-088 | `_moveUpByFoldedLines` (543-559) | Member: compute folded target/delta and move model state. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-089 | `_moveUpByFoldedLines` (547-558) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-090 | `_moveUpByFoldedLines` (548-550) | Branch: non-extending selection starts at selection start; otherwise active position. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-091 | `_moveUpByFoldedLines` (554-556) | Early return unchanged on exact delta 0. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-092 | `_targetFoldedDown` (563-594) | Member: advance exactly `count` visible/folded steps; index starts 0. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-093 | `_targetFoldedDown` (567-569) | Loop: skip ranges ending before `line + 1`. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-094 | `_targetFoldedDown` (572-574) | Early return `lineCount` when already at/after EOF. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-095 | `_targetFoldedDown` (577-579) | Loop: skip ranges ending before candidate. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-096 | `_targetFoldedDown` (581-583) | Branch: candidate inside/after range start jumps to `range.end + 1`. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-097 | `_targetFoldedDown` (585-588) | Early return previous line when jump passes EOF. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-098 | `_targetFoldedUp` (598-629) | Member: retreat exactly `count` visible/folded steps; index starts `length - 1`. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-099 | `_targetFoldedUp` (602-604) | Loop: skip ranges starting after `line - 1`. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-100 | `_targetFoldedUp` (607-609) | Early return exact line 1 when already at/before BOF. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-101 | `_targetFoldedUp` (612-614) | Loop: skip ranges starting after candidate. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-102 | `_targetFoldedUp` (616-618) | Branch: candidate inside/before range end jumps to `range.start - 1`. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-103 | `_targetFoldedUp` (620-623) | Early return previous line when jump passes BOF. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-104 | `_moveToViewPosition` (631-633) | Member: view-state move to exact target with selection mode and leftover 0. | `CMD` | PORTED | TODO |
| CMC-105 | `_moveToModelPosition` (635-637) | Member: model-state move to exact target with selection mode and leftover 0. | `CMD` | PORTED | TODO |
| CMC-106 | `_moveToViewMinColumn` (639-648) | Member: map each cursor to its view-line min column. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-107 | `_moveToViewMinColumn` (641-646) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-108 | `_moveToViewFirstNonWhitespaceColumn` (650-659) | Member: map each cursor to its view first-nonwhite column. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-109 | `_moveToViewFirstNonWhitespaceColumn` (652-657) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-110 | `_moveToViewCenterColumn` (661-670) | Member: exact `round((viewMax + viewMin)/2)`. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-111 | `_moveToViewCenterColumn` (663-668) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-112 | `_moveToViewMaxColumn` (672-681) | Member: map each cursor to its view-line max column. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-113 | `_moveToViewMaxColumn` (674-679) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-114 | `_moveToViewLastNonWhitespaceColumn` (683-692) | Member: map each cursor to its view last-nonwhite column. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-115 | `_moveToViewLastNonWhitespaceColumn` (685-690) | Cardinality: maps all cursors, locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-116 | `SimpleMoveArguments` (922-927) | Declared typed argument contract consumed by bound commands. | `CMD`/`INPUT` | PORTED | TODO |
| CMC-117 | `SimpleMoveArguments.direction` (923) | Field: closed simple-move direction. | `CMD` | PORTED | TODO |
| CMC-118 | `SimpleMoveArguments.unit` (924) | Field: movement unit. | `CMD` | PORTED | TODO |
| CMC-119 | `SimpleMoveArguments.select` (925) | Field: selection-extension flag. | `CMD` | TESTED | TODO |
| CMC-120 | `SimpleMoveArguments.value` (926) | Field: movement count/page size. | `CMD` | TESTED | TODO |
| CMC-121 | `Direction` (929-948) | Declared enum contract. | `CMD` | PORTED | TODO |
| CMC-122 | `Direction.Left` (930) | Enum constant, implicit ordinal 0. | `CMD` | TESTED | TODO |
| CMC-123 | `Direction.Right` (931) | Enum constant, implicit ordinal 1. | `CMD` | TESTED | TODO |
| CMC-124 | `Direction.Up` (932) | Enum constant, implicit ordinal 2. | `CMD` | TESTED | TODO |
| CMC-125 | `Direction.Down` (933) | Enum constant, implicit ordinal 3. | `CMD` | TESTED | TODO |
| CMC-126 | `Direction.PrevBlankLine` (934) | Enum constant, implicit ordinal 4. | `CMD` | DEFERRED (D1 generic blank-line) | TODO |
| CMC-127 | `Direction.NextBlankLine` (935) | Enum constant, implicit ordinal 5. | `CMD` | DEFERRED (D1 generic blank-line) | TODO |
| CMC-128 | `Direction.WrappedLineStart` (937) | Enum constant, implicit ordinal 6. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-129 | `Direction.WrappedLineFirstNonWhitespaceCharacter` (938) | Enum constant, implicit ordinal 7. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-130 | `Direction.WrappedLineColumnCenter` (939) | Enum constant, implicit ordinal 8. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-131 | `Direction.WrappedLineEnd` (940) | Enum constant, implicit ordinal 9. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-132 | `Direction.WrappedLineLastNonWhitespaceCharacter` (941) | Enum constant, implicit ordinal 10. | `CMD` | DEFERRED (D1 generic wrapped position) | TODO |
| CMC-133 | `Direction.ViewPortTop` (943) | Enum constant, implicit ordinal 11. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-134 | `Direction.ViewPortCenter` (944) | Enum constant, implicit ordinal 12. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-135 | `Direction.ViewPortBottom` (945) | Enum constant, implicit ordinal 13. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-136 | `Direction.ViewPortIfOutside` (947) | Enum constant, implicit ordinal 14. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-137 | `SimpleMoveDirection` (950-962) | Declared exact union of 11 simple directions. | `CMD` | PORTED | TODO |
| CMC-138 | `ViewportDirection` (964-969) | Declared exact union of 4 viewport directions. | `CMD` | DEFERRED (D1 generic viewport placement) | TODO |
| CMC-139 | `Unit` (971-978) | Declared enum contract. | `CMD` | PORTED | TODO |
| CMC-140 | `Unit.None` (972) | Enum constant, implicit ordinal 0; Left/Right use it. | `CMD` | TESTED | TODO |
| CMC-141 | `Unit.Line` (973) | Enum constant, implicit ordinal 1. | `CMD` | DEFERRED (D1 generic model-line unit) | TODO |
| CMC-142 | `Unit.WrappedLine` (974) | Enum constant, implicit ordinal 2; Arrow/Page Up/Down use it. | `CMD` | TESTED | TODO |
| CMC-143 | `Unit.Character` (975) | Enum constant, implicit ordinal 3. | `CMD` | DEFERRED (D1 generic raw cursorMove) | TODO |
| CMC-144 | `Unit.HalfLine` (976) | Enum constant, implicit ordinal 4. | `CMD` | DEFERRED (D1 generic half-line) | TODO |
| CMC-145 | `Unit.FoldedLine` (977) | Enum constant, implicit ordinal 5. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-146 | `simpleMove` Left HalfLine arm (276-278) | Independently deferred sub-branch inside otherwise-required Left case. | `CMD` | DEFERRED (D1 generic half-line) | TODO |
| CMC-147 | `simpleMove` Right HalfLine arm (285-287) | Independently deferred sub-branch inside otherwise-required Right case. | `CMD` | DEFERRED (D1 generic half-line) | TODO |
| CMC-148 | `simpleMove` Up FoldedLine arm (297-299) | Independently deferred folded-model movement. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-149 | `simpleMove` Up other-unit arm (300-302) | Independently deferred model-line movement. | `CMD` | DEFERRED (D1 generic model-line unit) | TODO |
| CMC-150 | `simpleMove` Down FoldedLine arm (309-311) | Independently deferred folded-model movement. | `CMD` | DEFERRED (D1 generic folded-line) | TODO |
| CMC-151 | `simpleMove` Down other-unit arm (312-314) | Independently deferred model-line movement. | `CMD` | DEFERRED (D1 generic model-line unit) | TODO |
| CMC-152 | `simpleMove` PrevBlankLine view callback (319) | Source-owned callback/cardinality: the WrappedLine arm maps every cursor through the view-state previous-blank-line operation; locally only the primary exists. | `CMD` | N-A (N1 single-cursor cardinality; branch behavior remains CMC-045/D1) | TODO |
| CMC-153 | `simpleMove` NextBlankLine view callback (326) | Source-owned callback/cardinality: the WrappedLine arm maps every cursor through the view-state next-blank-line operation; locally only the primary exists. | `CMD` | N-A (N1 single-cursor cardinality; branch behavior remains CMC-046/D1) | TODO |
| CMC-154 | `viewportMove` IfOutside (382-385) | Cardinality: branch loops all cursors; locally only primary exists. | `CMD` | N-A (N1 single cursor) | TODO |
| CMC-155 | `simpleMove` PrevBlankLine model callback (321) | Source-owned callback/cardinality: the non-WrappedLine arm maps every cursor through the model-state previous-blank-line operation; locally only the primary exists. | `CMD` | N-A (N1 single-cursor cardinality; branch behavior remains CMC-045/D1) | TODO |
| CMC-156 | `simpleMove` NextBlankLine model callback (328) | Source-owned callback/cardinality: the non-WrappedLine arm maps every cursor through the model-state next-blank-line operation; locally only the primary exists. | `CMD` | N-A (N1 single-cursor cardinality; branch behavior remains CMC-046/D1) | TODO |

##### CMO ledger — `cursorMoveOperations.ts`

| ID | Source member (line) | Normalized behavior atom | Local target | Proposed terminal | Status |
|---|---|---|---|---|---|
| CMO-001 | `_cursorPositionBrand` (16) | Field initialized `undefined`; TS nominal-brand only. | `OPS` | N-A (N3 MoonBit nominal type) | TODO |
| CMO-002 | `CursorPosition.lineNumber` (18) | Readonly line field. | `OPS` | PORTED | TODO |
| CMO-003 | `CursorPosition.column` (19) | Readonly column field. | `OPS` | PORTED | TODO |
| CMO-004 | `CursorPosition.leftoverVisibleColumns` (20) | Readonly sticky visible-column remainder. | `OPS`/`STATE` | TESTED | TODO |
| CMO-005 | `CursorPosition.constructor` (22-26) | Member assigns all three arguments without transformation. | `OPS` | PORTED | TODO |
| CMO-006 | `leftPosition` (30-39) | Member: same-line previous UTF-16 character; previous-line max; or unchanged origin. | `OPS` | TESTED | TODO |
| CMO-007 | `leftPosition` (31-32) | Early return: column above line min moves by `-prevCharLength(content,column-1)`. | `OPS` | TESTED | TODO |
| CMO-008 | `leftPosition` (33-35) | Early return: line above 1 crosses to `(line-1, previous maxColumn)`. | `OPS` | TESTED | TODO |
| CMO-009 | `leftPosition` (36-37) | Final edge branch returns unchanged at document origin. | `OPS` | TESTED | TODO |
| CMO-010 | `leftPositionAtomicSoftTabs` (41-51) | Member: atomic indent movement with ordinary-left fallback. | `OPS` | DEFERRED (D2 option absent) | TODO |
| CMO-011 | `leftPositionAtomicSoftTabs` (42-49) | Branch: only probe atomic movement at/before indent column. | `OPS` | DEFERRED (D2 option absent) | TODO |
| CMO-012 | `leftPositionAtomicSoftTabs` (46-48) | Early return when result is not `-1` and `new+1 >= min`; target is `new+1`. | `OPS` | DEFERRED (D2 option absent) | TODO |
| CMO-013 | `left` (53-58) | Member: configured logical left and `CursorPosition(..., leftover=0)`. | `OPS` | TESTED | TODO |
| CMO-014 | `left` (54-56) | Branch: stickyTabStops selects atomic helper; false selects ordinary left. | `OPS` | DEFERRED (D2 true arm; false on member row) | TODO |
| CMO-015 | `moveLeft` (64-87) | Member: pre-offset by `-(noOfColumns-1)`, clip before normalize(Left), then one left step and leftover 0. | `OPS` | TESTED | TODO |
| CMO-016 | `moveLeft` (68-84) | Branch: non-extending selection collapses to selection start; otherwise computes movement. | `OPS` | TESTED | TODO |
| CMO-017 | `clipPositionColumn` (92-98) | Member: preserve line and clip column to line min/max. | `OPS` | TESTED | TODO |
| CMO-018 | `clipRange` (100-108) | Member: return in-range value unchanged. | `OPS` | PORTED | TODO |
| CMO-019 | `clipRange` (101-103) | Early return min below lower bound. | `OPS` | TESTED | TODO |
| CMO-020 | `clipRange` (104-106) | Early return max above upper bound. | `OPS` | TESTED | TODO |
| CMO-021 | `rightPosition` (110-118) | Member: advance next UTF-16 character, cross to next-line min, or remain at EOF. | `OPS` | TESTED | TODO |
| CMO-022 | `rightPosition` (111-112) | Branch: before max add `nextCharLength(content,column-1)`. | `OPS` | TESTED | TODO |
| CMO-023 | `rightPosition` (113-116) | Branch: at line max and before final line, increment line and reset to min. | `OPS` | TESTED | TODO |
| CMO-024 | `rightPositionAtomicSoftTabs` (120-129) | Member: accepts inert `indentSize`, probes atomic movement using `tabSize` only, and otherwise falls back to ordinary right movement. | `OPS` | DEFERRED (D2 option absent) | TODO |
| CMO-025 | `rightPositionAtomicSoftTabs` (121-127) | Branch: only probe atomic movement before indent column. | `OPS` | DEFERRED (D2 option absent) | TODO |
| CMO-026 | `rightPositionAtomicSoftTabs` (124-126) | Early return for result not exact sentinel `-1`, target `new+1`. | `OPS` | DEFERRED (D2 option absent) | TODO |
| CMO-027 | `right` (131-136) | Member: configured logical right and `CursorPosition(..., leftover=0)`. | `OPS` | TESTED | TODO |
| CMO-028 | `right` (132-134) | Branch: `stickyTabStops` selects the atomic helper and forwards `tabSize` plus inert `indentSize`; false selects ordinary right. | `OPS` | DEFERRED (D2 true arm; false on member row) | TODO |
| CMO-029 | `moveRight` (138-155) | Member: pre-offset by `noOfColumns-1`, clip/normalize(Right), one right step, leftover 0. | `OPS` | TESTED | TODO |
| CMO-030 | `moveRight` (142-152) | Branch: non-extending selection collapses to selection end; otherwise computes movement. | `OPS` | TESTED | TODO |
| CMO-031 | `vertical` (157-197) | Member: preserve desired visible column using tab size and leftover, then normalize and return. | `OPS`/`STATE` | TESTED | TODO |
| CMO-032 | `vertical` (165-181) | Branch chain: below BOF clamps line 1; after EOF clamps last line; in-range converts desired visible column. | `OPS` | TESTED | TODO |
| CMO-033 | `vertical` BOF edge flag (167-171) | Branch: allow-edge chooses min column; false chooses `min(maxColumn,oldColumn)`. | `OPS` | TESTED | TODO |
| CMO-034 | `vertical` EOF edge flag (174-178) | Branch: allow-edge chooses max column; false chooses `min(maxColumn,oldColumn)`. | `OPS` | TESTED | TODO |
| CMO-035 | `vertical` (183-187) | Branch: if already at directional document edge reset leftover to 0; else compute visible-column residual. | `OPS`/`STATE` | TESTED | TODO |
| CMO-036 | `vertical` (189-195) | Branch: supplied affinity normalizes and adjusts leftover by `oldColumn-newColumn`. | `OPS`/`STATE` | TESTED | TODO |
| CMO-037 | `down` (199-201) | Member: vertical to `line+count` with `RightOfInjectedText`. | `OPS` | TESTED | TODO |
| CMO-038 | `moveDown` (203-227) | Member: down movement with retry-normalization loop; return computed leftover. | `OPS`/`STATE` | TESTED | TODO |
| CMO-039 | `moveDown` (207-214) | Branch: non-extending selection starts from selection end; otherwise active position. | `OPS` | TESTED | TODO |
| CMO-040 | `moveDown` (218-224) | Material loop/magic: retry `down(line+i)` while `i++ < 10` and before line count. | `OPS` | TESTED | TODO |
| CMO-041 | `moveDown` (220-223) | Early break when normalized probe line advances beyond base line. | `OPS` | TESTED | TODO |
| CMO-042 | `translateDown` (229-242) | Member: translate selection start and active by exact 1 with edge false, rebuild `Simple` state. | `OPS` | N-A (N2 add-cursor only) | TODO |
| CMO-043 | `up` (244-246) | Member: vertical to `line-count` with `LeftOfInjectedText`. | `OPS` | TESTED | TODO |
| CMO-044 | `moveUp` (248-264) | Member: one configured upward movement and preserve computed leftover. | `OPS`/`STATE` | TESTED | TODO |
| CMO-045 | `moveUp` (252-259) | Branch: non-extending selection starts from selection start; otherwise active position. | `OPS` | TESTED | TODO |
| CMO-046 | `translateUp` (266-280) | Member: translate selection start and active by exact 1 with edge false, rebuild `Simple` state. | `OPS` | N-A (N2 add-cursor only) | TODO |
| CMO-047 | `_isBlankLine` (282-288) | Member: nonzero first-nonwhite is false. | `OPS` | DEFERRED (D1 generic blank-line) | TODO |
| CMO-048 | `_isBlankLine` (283-286) | Early return true for exact blank sentinel 0. | `OPS` | DEFERRED (D1 generic blank-line) | TODO |
| CMO-049 | `moveToPrevBlankLine` (290-304) | Member: initialize active line and return at line min, leftover 0. | `OPS` | DEFERRED (D1 generic blank-line) | TODO |
| CMO-050 | `moveToPrevBlankLine` (294-296) | Loop: leave current run of blank lines while line > 1. | `OPS` | DEFERRED (D1 generic blank-line) | TODO |
| CMO-051 | `moveToPrevBlankLine` (299-301) | Loop: scan previous nonblank run to blank line while line > 1. | `OPS` | DEFERRED (D1 generic blank-line) | TODO |
| CMO-052 | `moveToNextBlankLine` (306-321) | Member: initialize active line and return at line min, leftover 0. | `OPS` | DEFERRED (D1 generic blank-line) | TODO |
| CMO-053 | `moveToNextBlankLine` (311-313) | Loop: leave current run of blank lines while before line count. | `OPS` | DEFERRED (D1 generic blank-line) | TODO |
| CMO-054 | `moveToNextBlankLine` (316-318) | Loop: scan next nonblank run to blank line while before line count. | `OPS` | DEFERRED (D1 generic blank-line) | TODO |
| CMO-055 | `moveToBeginningOfLine` (323-338) | Member: active line/min/first-nonblank, then move with leftover 0. | `OPS` | TESTED | TODO |
| CMO-056 | `moveToBeginningOfLine` (326) | Branch-like sentinel fallback: first-nonwhite 0 becomes min column. | `OPS` | TESTED | TODO |
| CMO-057 | `moveToBeginningOfLine` (331-335) | Branch: already at first-nonblank toggles to min; otherwise first-nonblank. | `OPS` | TESTED | TODO |
| CMO-058 | `moveToEndOfLine` (340-344) | Member: move to active line max with selection flag. | `OPS` | TESTED | TODO |
| CMO-059 | `moveToEndOfLine` (343) | Branch: sticky leftover is `MAX_SAFE_SMALL_INTEGER-maxColumn`; false is 0. | `OPS`/`STATE` | DEFERRED (D4 sticky arm; ordinary End on member row) | TODO |
| CMO-060 | `moveToBeginningOfBuffer` (346-348) | Member: exact `(1,1)`, leftover 0. | `OPS` | DEFERRED (D5 command unbound) | TODO |
| CMO-061 | `moveToEndOfBuffer` (350-355) | Member: final line/max column, leftover 0. | `OPS` | DEFERRED (D5 command unbound) | TODO |
| CMO-062 | `vertical` (160-162) | Branch: when target is above current, edge means exact first position `(1,1)`; otherwise exact final position. | `OPS` | TESTED | TODO |

##### Explicit excluded siblings

| Source sibling | Scope disposition |
|---|---|
| `cursorMoveCommands.ts:695-920` | Closed generic JSON command cluster excluded from denominator; no local `cursorMove` JSON API. |
| `cursorDeleteOperations.ts`, `cursorTypeOperations.ts`, paste/composition command units | Whole editable mutation siblings excluded by readonly scope. Their calls *to* `MoveOperations.right` do not pull deletion into this movement denominator. |
| `cursorAtomicMoveOperations.ts` | Whole helper deferred with D2 call-site rows; inventory it before adding `stickyTabStops`. |
| `cursorWordOperations.ts` | Word algorithm is a distinct source unit; only this file's validate/delegate adapter is CMC-033. |
| `coreCommands.ts` CreateCursor/LastCursor/column-select clusters | Multicursor/column selection; sibling core-command audit must assign explicit N-A rows. This ledger already accounts for `addCursor*`, `translate*`, and array cardinality. |

##### Branch-derived test matrix

- Left/Right: collapsed vs selected, select false/true, same-line vs BOF/EOF crossing, ASCII vs surrogate pair, injected-text normalization, movement value 1 and >1, LTR. RTL is D3.
- Vertical Arrow/Page: up/down, select false/true, collapsed vs selected, wrapped continuation, first/last position vs first/last line non-edge column, shorter/equal/longer target widths, tabs, leftover carry/reset, injected-text affinity, count 1/page count, exact down retry cap 10.
- Home: first wrapped segment vs continuation; at first nonwhite vs elsewhere; blank/empty sentinel 0; indentation; selection false/true.
- End: wrapped non-final/final segment; already at view max; remaining-column equality; selection false/true; sticky false. Sticky true is D4.
- Move-to/line/word: supplied/absent view position, simple collapse/extend, Word/Line kind dispatch, before/after/equal anchor, EOF line selection, select-all.
- Clip: below/equal/inside/above min/max.
- Harness: wrap off/on, tab sizes 2/4, injected text, short/tall page sizes, JS/native common tests, browser keydown/default prevention at root integration.

##### Closing reread and counts

- CMC whole file read: 980 lines; all 42 `CursorMoveCommands` methods and every in-scope typed field/constant are represented.
- CMO whole file read: 356 lines; all 4 fields, constructor, and 24 methods are represented.
- Prefix totals: **CMC 156**, **CMO 62**, total **218**.
- Planned terminal totals: **TESTED 77**, **PORTED 12**, **DEFERRED 97**, **N-A 32**. Per prefix: CMC `41/8/78/29`; CMO `36/4/19/3` in `TESTED/PORTED/DEFERRED/N-A` order.

#### Cursor browser/public/event inventory (read-only)

Oracle: VS Code `b18492a288de038fbc7643aae6de8247029d11bd` (the checked-out `vscode/` submodule was verified at this exact commit).

Assigned source units were read from line 1 through EOF:

- `vscode/src/vs/editor/browser/coreCommands.ts` (2178 lines)
- `vscode/src/vs/editor/browser/view/viewController.ts` (441 lines)
- `vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts` (2559 lines)
- `vscode/src/vs/editor/common/viewModelEventDispatcher.ts` (591 lines)
- `vscode/src/vs/editor/common/viewModel/viewModelImpl.ts` (1472 lines)

Counting rule: one row per declared scoped member/field, independently
behavior-changing branch or early return, magic constant, nested callback, or
command/keybinding registration. A registration with one disposition remains
one row. When its required primary executable registration and its
alternate-platform or command-metadata facts have different dispositions,
each disposition-homogeneous part receives its own row. Straight-line
statements that only establish the named member's order stay in that member
row. Excluded branches inside a complete scoped method remain rows. Whole
sibling clusters outside the Phase-0 boundary are named below but are not
silently added to the denominator.

All Gate-A statuses are `TODO`. `Proposed terminal` is a Gate-B recommendation, not an implementation claim.

##### Phase-0 boundaries after whole-file reread

###### CORE — `coreCommands.ts`

Included: `CORE_WEIGHT`; `CoreEditorCommand`; `NavigationCommandRevealType`; the
complete mouse-consumed `MoveTo`/`MoveToSelect`, column-selection,
create/last-cursor, word/line/select-all/set-selection clusters; the complete
arrows/PageUp/PageDown/Home/End/line-start/line-end/top/bottom command
implementations and registrations; generic `CursorMove`;
cancel/remove-secondary siblings; and column-mode override registrations. The
complete `EditorScroll_` parser/arithmetic, `EditorScroll` plus all eight
scroll command objects (`:1308-1629`), `RevealLine_` and complete `RevealLine`
command (`:1830-1879`), `EditorOrNativeTextInputCommand`,
`CoreEditingCommands`, and editor-handler registration tail are sibling
clusters outside this child (scrolling, reveal-only, native-input, or editing
ownership). Retired draft IDs CORE-126–134 and CORE-167 named those clusters
with umbrella rows; they are no longer denominator rows and are never reused.

###### VC — `viewController.ts`

Included: the complete `IMouseDispatchData`; constructor state needed by mouse dispatch; `setSelection`; `_validateViewColumn`; both modifier helpers; both double-click block helpers; complete `dispatchMouse`; and every command/conversion adapter it calls through `_selectAll`. `ICommandDelegate`, paste/type/composition/cut forwarding, and raw key/mouse user-input emitters are input/edit/event-surface siblings outside this cursor-transition cluster.

###### CEW — `codeEditorWidget.ts`

Included in this child's denominator: public get/set position/selection(s) methods only. The frozen lifecycle child is inherited source authority for the shared delivery queue (`viewer-model-lifecycle-ownership-parity.md` CEW-001), cursor emitters/aliases (CEW-015/016), and the complete `viewModel.onEvent` switch including max-count and cursor payload/fire order (CEW-123 through CEW-139, especially CEW-130/131). Those atoms are intentionally not duplicated below; this child must still audit/strengthen the local CEW-131 behavior and its tests. Constructor/configuration, model lifecycle, decorations, widgets, focus, clipboard/editing, rendering, context keys, and theming are sibling plans.

###### VED — `viewModelEventDispatcher.ts`

Included in the inventory: the complete generic dispatcher/collector fields
and methods, the `CursorStateChangedEvent` union arm/kind, and complete
`CursorStateChangedEvent`. This child implements only the outgoing emitter,
coalescing queue, and cursor event class. Generic view-handler, nested
collector, and view-event-queue ownership is explicitly deferred to the
render-invalidation child. Every non-cursor outgoing union arm/kind and event
class body remains owned by lifecycle, geometry, invalidation, zones,
tokenization, or configuration children.

###### VMI — `viewModelImpl.ts`

Included: event-dispatcher/cursor ownership construction; cursor-bearing content-event handoff; complete public cursor read/write/reveal region; and transaction/collector helpers. Configuration, line mapping internals, decoration, hidden-area/zone, rendering/copy, viewport, and editing implementations are sibling clusters; their cursor call boundaries remain rows where they occur in a complete included method.

##### Abbreviated local targets

- `NAV`: source-shaped movement in `viewer/common/view_model/cursor_move_operations.mbt` and `cursor_move_commands.mbt`, plus the root command adapter.
- `REG`: `viewer/editor_extensions.mbt` plus a new cursor registration unit and `viewer/input.mbt`.
- `MOUSE`: `viewer/view_controller.mbt`.
- `API`: `viewer/selection.mbt`, `viewer/public_read_api.mbt`, and `viewer/viewer.mbt`.
- `SPINE`: shared transition/event collector work across `viewer/common/cursor/cursors_controller.mbt`, `viewer/common/view_model/view_model.mbt`, `viewer/selection.mbt`, `viewer/view_controller.mbt`, and `viewer/attach_model.mbt`.

Proposed terminals mean: `TESTED` = required source behavior should land with branch evidence; `PORTED` = contract/plumbing with indirect tests is acceptable; `DEFERRED` = real absent surface outside this child's implementation boundary; `N-A` = impossible/unobservable under the approved single-cursor readonly product boundary.

##### CORE excluded sibling registry (not denominator rows)

| Source lines | Complete excluded sibling ownership |
|---|---|
| `coreCommands.ts:51-235,1308-1629` | `EditorScroll_`, `EditorScrollCommandOptions`, `EditorScrollImpl`, `EditorScroll`, and all eight `Scroll*` command objects; future scroll child. |
| `coreCommands.ts:237-303,1830-1879` | `RevealLine_`, `RevealLineCommandOptions`, and the complete anonymous `RevealLine` command; reveal/API child. |

Draft umbrella IDs CORE-126–134 and CORE-167 are retired and excluded from
the denominator; they are never reused. Active CORE IDs are unique and occupy
`CORE-001–125`, `CORE-135–166`, and `CORE-168–196`.

##### CORE ledger

| ID | Source member (file:line) | Arithmetic / transition | Local target | Proposed terminal | Status |
|---|---|---|---|---|---|
| CORE-001 | coreCommands.ts:36 | `CORE_WEIGHT` is exactly `KeybindingWeight.EditorCore`. | REG | PORTED | TODO |
| CORE-002 | coreCommands.ts:48 | `CoreEditorCommand.runCoreEditorCommand` is the abstract core-command member. | REG | PORTED | TODO |
| CORE-003 | coreCommands.ts:39-44 | `runEditorCommand` reads `_getViewModel`; no view is an early return because there are no cursors. | REG | TESTED | TODO |
| CORE-004 | coreCommands.ts:45 | Successful dispatch passes the logical-OR fallback `args` or `{}` to `runCoreEditorCommand`. | REG | TESTED | TODO |
| CORE-005 | coreCommands.ts:353-358 | `NavigationCommandRevealType.Regular` is exactly `0`. | NAV | PORTED | TODO |
| CORE-006 | coreCommands.ts:359-362 | `NavigationCommandRevealType.Minimal` is exactly `1`. | NAV | PORTED | TODO |
| CORE-007 | coreCommands.ts:363-366 | `NavigationCommandRevealType.None` is exactly `2`. | NAV | PORTED | TODO |
| CORE-008 | coreCommands.ts:370-372 | `BaseCommandOptions.source` accepts `'mouse'`, `'keyboard'`, or an arbitrary string. | SPINE | PORTED | TODO |
| CORE-009 | coreCommands.ts:374-375 | `MoveCommandOptions.position` is the required model position. | NAV | PORTED | TODO |
| CORE-010 | coreCommands.ts:376 | `MoveCommandOptions.viewPosition` is the optional already-known view position. | NAV | PORTED | TODO |
| CORE-011 | coreCommands.ts:377 | `MoveCommandOptions.revealType` carries the reveal policy. | NAV | PORTED | TODO |
| CORE-012 | coreCommands.ts:382 | `BaseMoveToCommand._inSelectionMode` field. | NAV | PORTED | TODO |
| CORE-013 | coreCommands.ts:384-387 | Constructor retains `opts.inSelectionMode`. | NAV | PORTED | TODO |
| CORE-014 | coreCommands.ts:389-392 | `BaseMoveToCommand.runCoreEditorCommand` returns before stack/cursor work when `position` is absent. | NAV | TESTED | TODO |
| CORE-015 | coreCommands.ts:393-400 | Move-to pushes a model stack element, then calls `setCursorStates(source, Explicit, [moveTo(primary,inSelectionMode,position,viewPosition)])`. | NAV + SPINE | TESTED | TODO |
| CORE-016 | coreCommands.ts:401-403 | Reveal runs only when state changed and reveal type is not `None`; it uses `revealAllCursors(source,true,true)`. | NAV | TESTED | TODO |
| CORE-017 | coreCommands.ts:407-411 | `MoveTo`: ID `_moveTo`, selection mode false, precondition undefined. | NAV | TESTED | TODO |
| CORE-018 | coreCommands.ts:413-417 | `MoveToSelect`: ID `_moveToSelect`, selection mode true, precondition undefined. | NAV | TESTED | TODO |
| CORE-019 | coreCommands.ts:419-422 | `ColumnSelectCommand.runCoreEditorCommand` pushes a stack element and obtains one result from primary state plus prior column data. | — | N-A (column/multi-cursor) | TODO |
| CORE-020 | coreCommands.ts:423-426 | A null column-select result is the invalid-argument early return. | — | N-A (column/multi-cursor) | TODO |
| CORE-021 | coreCommands.ts:427 | Column selection maps every result view state through `CursorState.fromViewState` and sets reason `Explicit`. | — | N-A (column/multi-cursor) | TODO |
| CORE-022 | coreCommands.ts:428-434 | It persists `isReal=true` and the exact from/to view line and visual-column result fields. | — | N-A (column/multi-cursor) | TODO |
| CORE-023 | coreCommands.ts:435-439 | Reversed results reveal the top-most cursor; other results reveal the bottom-most cursor. | — | N-A (column/multi-cursor) | TODO |
| CORE-024 | coreCommands.ts:442 | `_getColumnSelectResult` is the subclass callback seam. | — | N-A (column/multi-cursor) | TODO |
| CORE-025 | coreCommands.ts:447 | `ColumnSelectCommandOptions.position`. | — | N-A (column/multi-cursor) | TODO |
| CORE-026 | coreCommands.ts:448 | `ColumnSelectCommandOptions.viewPosition`. | — | N-A (column/multi-cursor) | TODO |
| CORE-027 | coreCommands.ts:449 | `ColumnSelectCommandOptions.mouseColumn`. | — | N-A (column/multi-cursor) | TODO |
| CORE-028 | coreCommands.ts:450 | `ColumnSelectCommandOptions.doColumnSelect`. | — | N-A (column/multi-cursor) | TODO |
| CORE-029 | coreCommands.ts:453 | Exported `ColumnSelect` constant registers the anonymous command. | — | N-A (column/multi-cursor) | TODO |
| CORE-030 | coreCommands.ts:454-459 | Anonymous constructor sets ID `columnSelect` and undefined precondition. | — | N-A (column/multi-cursor) | TODO |
| CORE-031 | coreCommands.ts:461-464 | Missing position, viewPosition, or mouseColumn returns null before validation. | — | N-A (column/multi-cursor) | TODO |
| CORE-032 | coreCommands.ts:465-467 | The model position is validated first; view position is then validated using that model position. | — | N-A (column/multi-cursor) | TODO |
| CORE-033 | coreCommands.ts:469 | `doColumnSelect` keeps prior origin line; otherwise origin line is the validated clicked view line. | — | N-A (column/multi-cursor) | TODO |
| CORE-034 | coreCommands.ts:470-471 | Prior origin visual column is kept in continuation mode; otherwise both mouse visual columns are `mouseColumn - 1`. | — | N-A (column/multi-cursor) | TODO |
| CORE-035 | coreCommands.ts:475 | Exported `CursorColumnSelectLeft` constant registers the anonymous command. | — | N-A (column/multi-cursor) | TODO |
| CORE-036 | coreCommands.ts:476-487 | Constructor sets ID, undefined precondition, core weight, text-input-focus, CtrlCmd+Shift+Alt+Left, Linux primary `0`. | — | N-A (column/multi-cursor) | TODO |
| CORE-037 | coreCommands.ts:489-491 | Left callback delegates to `ColumnSelection.columnSelectLeft`. | — | N-A (column/multi-cursor) | TODO |
| CORE-038 | coreCommands.ts:494 | Exported `CursorColumnSelectRight` constant registers the anonymous command. | — | N-A (column/multi-cursor) | TODO |
| CORE-039 | coreCommands.ts:495-506 | Constructor sets the analogous exact Right chord and Linux primary `0`. | — | N-A (column/multi-cursor) | TODO |
| CORE-040 | coreCommands.ts:508-510 | Right callback delegates to `ColumnSelection.columnSelectRight`. | — | N-A (column/multi-cursor) | TODO |
| CORE-041 | coreCommands.ts:515 | `ColumnSelectUpCommand._isPaged` field. | — | N-A (column/multi-cursor) | TODO |
| CORE-042 | coreCommands.ts:517-520 | Constructor retains `opts.isPaged`. | — | N-A (column/multi-cursor) | TODO |
| CORE-043 | coreCommands.ts:522-524 | Result callback delegates `_isPaged` to `columnSelectUp`. | — | N-A (column/multi-cursor) | TODO |
| CORE-044 | coreCommands.ts:527-537 | `CursorColumnSelectUp`: `isPaged=false`, ID, core weight, focus, CtrlCmd+Shift+Alt+Up, Linux `0`. | — | N-A (column/multi-cursor) | TODO |
| CORE-045 | coreCommands.ts:539-549 | `CursorColumnSelectPageUp`: `isPaged=true`, ID, core weight, focus, CtrlCmd+Shift+Alt+PageUp, Linux `0`. | — | N-A (column/multi-cursor) | TODO |
| CORE-046 | coreCommands.ts:553 | `ColumnSelectDownCommand._isPaged` field. | — | N-A (column/multi-cursor) | TODO |
| CORE-047 | coreCommands.ts:555-558 | Constructor retains `opts.isPaged`. | — | N-A (column/multi-cursor) | TODO |
| CORE-048 | coreCommands.ts:560-562 | Result callback delegates `_isPaged` to `columnSelectDown`. | — | N-A (column/multi-cursor) | TODO |
| CORE-049 | coreCommands.ts:565-575 | `CursorColumnSelectDown`: `isPaged=false`, ID, core weight, focus, CtrlCmd+Shift+Alt+Down, Linux `0`. | — | N-A (column/multi-cursor) | TODO |
| CORE-050 | coreCommands.ts:577-587 | `CursorColumnSelectPageDown`: `isPaged=true`, ID, core weight, focus, CtrlCmd+Shift+Alt+PageDown, Linux `0`. | — | N-A (column/multi-cursor) | TODO |
| CORE-051 | coreCommands.ts:589-596 | `CursorMoveImpl` registers ID `cursorMove`, undefined precondition, and exact `CursorMove_.metadata`. | REG | DEFERRED (general command API) | TODO |
| CORE-052 | coreCommands.ts:598-603 | `CursorMoveImpl.runCoreEditorCommand` parses raw args and returns on illegal/null parse. | NAV | DEFERRED (general command API) | TODO |
| CORE-053 | coreCommands.ts:607-610 | `noHistory=true` overrides the supplied source with `TextEditorSelectionSource.PROGRAMMATIC`. | SPINE | DEFERRED (navigation history source) | TODO |
| CORE-054 | coreCommands.ts:611-616 | Generic cursor move pushes a stack element, sets all cursor states with `Explicit`, and delegates `_move`. | NAV + SPINE | DEFERRED (general command API/multi-cursor) | TODO |
| CORE-055 | coreCommands.ts:617 | Generic cursor move always reveals all cursors with horizontal reveal true after setting. | NAV | DEFERRED (general command API) | TODO |
| CORE-056 | coreCommands.ts:620-636 | `_move` passes `select`, `value`, unit and the Left/Right/Up/Down/PrevBlank/NextBlank/wrapped-line direction family to `simpleMove`. | NAV | DEFERRED (directions beyond required keys) | TODO |
| CORE-057 | coreCommands.ts:638-642 | Viewport Top/Bottom/Center/IfOutside directions delegate to `viewportMove`. | — | DEFERRED (viewport command API) | TODO |
| CORE-058 | coreCommands.ts:643-645 | Unknown generic direction returns null. | NAV | DEFERRED (general command API) | TODO |
| CORE-059 | coreCommands.ts:649 | `CursorMove` registers the `CursorMoveImpl` instance. | REG | DEFERRED (general command API) | TODO |
| CORE-060 | coreCommands.ts:651-653 | Page-size marker is the exact magic value `-1`. | NAV | TESTED | TODO |
| CORE-061 | coreCommands.ts:655-657 | Per-invocation cursor-move options optionally supply `pageSize`; CORE-064 owns the source's truthy-or-fallback semantics. | NAV | TESTED | TODO |
| CORE-062 | coreCommands.ts:661 | `_staticArgs` field retains one `SimpleMoveArguments` object. | NAV | PORTED | TODO |
| CORE-063 | coreCommands.ts:663-666 | Constructor stores `opts.args`. | NAV | PORTED | TODO |
| CORE-064 | coreCommands.ts:668-678 | Only static value `-1` is replaced. A truthy `dynamicArgs.pageSize` wins; `undefined` and exact `0` fall back to `cursorConfig.pageSize`. Direction, unit, and select are copied unchanged. | NAV | TESTED | TODO |
| CORE-065 | coreCommands.ts:680-685 | Key movement pushes a stack element, then sets all states with supplied source, `Explicit`, and `simpleMove`. | NAV + SPINE | TESTED | TODO |
| CORE-066 | coreCommands.ts:686 | Key movement reveals all cursors with horizontal reveal true after setting. | NAV | TESTED | TODO |
| CORE-067 | coreCommands.ts:690-702,704-705 | `cursorLeft`: Left/None/select=false/value=1; ID, undefined precondition, core weight, text-input-focus, and required primary Left. | REG + NAV | TESTED | TODO |
| CORE-068 | coreCommands.ts:707-721 | `cursorLeftSelect`: Left/None/select=true/value=1; core weight/focus; Shift+Left. | REG + NAV | TESTED | TODO |
| CORE-069 | coreCommands.ts:723-735,737-738 | `cursorRight`: Right/None/select=false/value=1; ID, undefined precondition, core weight, text-input-focus, and required primary Right. | REG + NAV | TESTED | TODO |
| CORE-070 | coreCommands.ts:740-754 | `cursorRightSelect`: Right/None/true/1; core weight/focus; Shift+Right. | REG + NAV | TESTED | TODO |
| CORE-071 | coreCommands.ts:756-768,770-771 | `cursorUp`: Up/WrappedLine/select=false/value=1; ID, core weight, text-input-focus, and required primary Up. | REG + NAV | TESTED | TODO |
| CORE-072 | coreCommands.ts:773-784,789-790 | `cursorUpSelect`: Up/WrappedLine/select=true/value=1; ID, core weight, text-input-focus, and required primary Shift+Up. | REG + NAV | TESTED | TODO |
| CORE-073 | coreCommands.ts:792-806 | `cursorPageUp`: Up/WrappedLine/false/`-1`; core weight/focus; PageUp. | REG + NAV | TESTED | TODO |
| CORE-074 | coreCommands.ts:808-822 | `cursorPageUpSelect`: Up/WrappedLine/true/`-1`; core weight/focus; Shift+PageUp. | REG + NAV | TESTED | TODO |
| CORE-075 | coreCommands.ts:824-836,838-839 | `cursorDown`: Down/WrappedLine/select=false/value=1; ID, core weight, text-input-focus, and required primary Down. | REG + NAV | TESTED | TODO |
| CORE-076 | coreCommands.ts:841-852,857-858 | `cursorDownSelect`: Down/WrappedLine/select=true/value=1; ID, core weight, text-input-focus, and required primary Shift+Down. | REG + NAV | TESTED | TODO |
| CORE-077 | coreCommands.ts:860-874 | `cursorPageDown`: Down/WrappedLine/false/`-1`; core weight/focus; PageDown. | REG + NAV | TESTED | TODO |
| CORE-078 | coreCommands.ts:876-890 | `cursorPageDownSelect`: Down/WrappedLine/true/`-1`; core weight/focus; Shift+PageDown. | REG + NAV | TESTED | TODO |
| CORE-079 | coreCommands.ts:892-894 | `CreateCursorCommandOptions.wholeLine` is optional. | — | N-A (multi-cursor) | TODO |
| CORE-080 | coreCommands.ts:896 | Exported `CreateCursor` constant registers the anonymous command. | — | N-A (multi-cursor) | TODO |
| CORE-081 | coreCommands.ts:897-902 | Constructor sets ID `createCursor` and undefined precondition. | — | N-A (multi-cursor) | TODO |
| CORE-082 | coreCommands.ts:904-906 | Its run method returns when position is absent. | — | N-A (multi-cursor) | TODO |
| CORE-083 | coreCommands.ts:908-913 | `wholeLine` chooses `line(primary,false,position,viewPosition)`; otherwise `moveTo(primary,false,...)`. | — | N-A (multi-cursor) | TODO |
| CORE-084 | coreCommands.ts:915-918 | Existing states are read and cursor-removal/toggle search runs only with more than one state. | — | N-A (multi-cursor) | TODO |
| CORE-085 | coreCommands.ts:919-931 | A candidate must be contained by both present model and present view selection; either failed containment continues. | — | N-A (multi-cursor) | TODO |
| CORE-086 | coreCommands.ts:933-943 | A matching cursor is spliced, then stack-push/set `Explicit` occurs and returns immediately. | — | N-A (multi-cursor) | TODO |
| CORE-087 | coreCommands.ts:946-955 | With no removable match, append new state, push stack, and set states with supplied source/`Explicit`. | — | N-A (multi-cursor) | TODO |
| CORE-088 | coreCommands.ts:958 | Exported `LastCursorMoveToSelect` constant registers the anonymous command. | — | N-A (multi-cursor) | TODO |
| CORE-089 | coreCommands.ts:959-964 | Constructor sets ID `_lastCursorMoveToSelect` and undefined precondition. | — | N-A (multi-cursor) | TODO |
| CORE-090 | coreCommands.ts:966-969 | Its run method returns when position is absent. | — | N-A (multi-cursor) | TODO |
| CORE-091 | coreCommands.ts:970-975 | It copies all states and replaces exactly `lastAddedCursorIndex` with selection-mode `moveTo`. | — | N-A (multi-cursor) | TODO |
| CORE-092 | coreCommands.ts:976-981 | Last-cursor move pushes a stack element then sets copied states with supplied source/`Explicit`. | — | N-A (multi-cursor) | TODO |
| CORE-093 | coreCommands.ts:987 | `HomeCommand._inSelectionMode` field. | NAV | PORTED | TODO |
| CORE-094 | coreCommands.ts:989-992 | Constructor retains `opts.inSelectionMode`. | NAV | PORTED | TODO |
| CORE-095 | coreCommands.ts:994-1002 | Home pushes stack, calls `moveToBeginningOfLine` for every cursor with selection mode, then reveals all horizontally. | NAV + SPINE | TESTED | TODO |
| CORE-096 | coreCommands.ts:1005-1012,1014-1015 | `cursorHome`: selection=false; ID, undefined precondition, core weight, text-input-focus, and required primary Home. | REG + NAV | TESTED | TODO |
| CORE-097 | coreCommands.ts:1017-1024,1026-1027 | `cursorHomeSelect`: selection=true; ID, core weight, text-input-focus, and required primary Shift+Home. | REG + NAV | TESTED | TODO |
| CORE-098 | coreCommands.ts:1031 | `LineStartCommand._inSelectionMode` field. | NAV | PORTED | TODO |
| CORE-099 | coreCommands.ts:1033-1036 | Constructor retains `opts.inSelectionMode`. | NAV | PORTED | TODO |
| CORE-100 | coreCommands.ts:1038-1046 | Line-start pushes stack, sets `Explicit` from `_exec`, then reveals all horizontally. | NAV + SPINE | TESTED | TODO |
| CORE-101 | coreCommands.ts:1048-1056 | `_exec` preserves each cursor model line, moves to column `1`, and resets leftover visible columns to `0`. | NAV | TESTED | TODO |
| CORE-102 | coreCommands.ts:1059-1069 | `cursorLineStart`: false; ID; core weight/focus; generic primary `0`; mac WinCtrl+A. | REG + NAV | DEFERRED (mac-only line-start binding outside approved 16 primary bindings) | TODO |
| CORE-103 | coreCommands.ts:1071-1081 | `cursorLineStartSelect`: true; generic primary `0`; mac WinCtrl+Shift+A. | REG + NAV | DEFERRED (mac-only line-start binding outside approved 16 primary bindings) | TODO |
| CORE-104 | coreCommands.ts:1083-1085 | `EndCommandOptions.sticky` is optional. | NAV | PORTED | TODO |
| CORE-105 | coreCommands.ts:1089 | `EndCommand._inSelectionMode` field. | NAV | PORTED | TODO |
| CORE-106 | coreCommands.ts:1091-1094 | Constructor retains `opts.inSelectionMode`. | NAV | PORTED | TODO |
| CORE-107 | coreCommands.ts:1096-1104 | End pushes stack, calls `moveToEndOfLine` with `args.sticky` logical-OR false, then reveals all horizontally. | NAV + SPINE | TESTED | TODO |
| CORE-108 | coreCommands.ts:1107-1115,1117 | `cursorEnd`: selection=false; ID, static sticky=false, core weight, text-input-focus, and required primary End. | REG + NAV | TESTED | TODO |
| CORE-109 | coreCommands.ts:1136-1144,1146 | `cursorEndSelect`: selection=true; ID, static sticky=false, core weight, text-input-focus, and required primary Shift+End. | REG + NAV | TESTED | TODO |
| CORE-110 | coreCommands.ts:1167 | `LineEndCommand._inSelectionMode` field. | NAV | PORTED | TODO |
| CORE-111 | coreCommands.ts:1169-1172 | Constructor retains `opts.inSelectionMode`. | NAV | PORTED | TODO |
| CORE-112 | coreCommands.ts:1174-1182 | Line-end pushes stack, sets `Explicit` from `_exec`, then reveals all horizontally. | NAV + SPINE | TESTED | TODO |
| CORE-113 | coreCommands.ts:1184-1193 | `_exec` reads each cursor model line's exact max column and moves there with leftover visible columns `0`. | NAV | TESTED | TODO |
| CORE-114 | coreCommands.ts:1196-1206 | `cursorLineEnd`: false; ID; core weight/focus; generic primary `0`; mac WinCtrl+E. | REG + NAV | DEFERRED (mac-only line-end binding outside approved 16 primary bindings) | TODO |
| CORE-115 | coreCommands.ts:1208-1218 | `cursorLineEndSelect`: true; generic primary `0`; mac WinCtrl+Shift+E. | REG + NAV | DEFERRED (mac-only line-end binding outside approved 16 primary bindings) | TODO |
| CORE-116 | coreCommands.ts:1222 | `TopCommand._inSelectionMode` field. | NAV | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-117 | coreCommands.ts:1224-1227 | Constructor retains `opts.inSelectionMode`. | NAV | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-118 | coreCommands.ts:1229-1237 | Top pushes stack, calls `moveToBeginningOfBuffer`, then reveals all horizontally. | NAV + SPINE | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-119 | coreCommands.ts:1240-1250 | `cursorTop`: false; core weight/focus; CtrlCmd+Home; mac CtrlCmd+Up. | REG + NAV | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-120 | coreCommands.ts:1252-1262 | `cursorTopSelect`: true; CtrlCmd+Shift+Home; mac CtrlCmd+Shift+Up. | REG + NAV | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-121 | coreCommands.ts:1266 | `BottomCommand._inSelectionMode` field. | NAV | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-122 | coreCommands.ts:1268-1271 | Constructor retains `opts.inSelectionMode`. | NAV | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-123 | coreCommands.ts:1273-1281 | Bottom pushes stack, calls `moveToEndOfBuffer`, then reveals all horizontally. | NAV + SPINE | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-124 | coreCommands.ts:1284-1294 | `cursorBottom`: false; core weight/focus; CtrlCmd+End; mac CtrlCmd+Down. | REG + NAV | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-125 | coreCommands.ts:1296-1306 | `cursorBottomSelect`: true; CtrlCmd+Shift+End; mac CtrlCmd+Shift+Down. | REG + NAV | DEFERRED (Ctrl/Cmd buffer command outside bound keys) | TODO |
| CORE-135 | coreCommands.ts:1633 | `WordCommand._inSelectionMode` field. | NAV | PORTED | TODO |
| CORE-136 | coreCommands.ts:1635-1638 | Constructor retains `opts.inSelectionMode`. | NAV | PORTED | TODO |
| CORE-137 | coreCommands.ts:1640-1643 | Word command returns when position is absent. | NAV | TESTED | TODO |
| CORE-138 | coreCommands.ts:1644-1651 | It pushes stack and sets one `CursorMoveCommands.word(primary,inSelectionMode,position)` state with supplied source/`Explicit`. | NAV + SPINE | TESTED | TODO |
| CORE-139 | coreCommands.ts:1652-1654 | Word selection reveals only when reveal type is not `None`, using `(source,true,true)`. | NAV | TESTED | TODO |
| CORE-140 | coreCommands.ts:1658-1662 | `WordSelect`: false, ID `_wordSelect`, undefined precondition. | NAV | TESTED | TODO |
| CORE-141 | coreCommands.ts:1664-1668 | `WordSelectDrag`: true, ID `_wordSelectDrag`, undefined precondition. | NAV | TESTED | TODO |
| CORE-142 | coreCommands.ts:1670 | Exported `LastCursorWordSelect` constant registers the anonymous command. | — | N-A (multi-cursor) | TODO |
| CORE-143 | coreCommands.ts:1671-1676 | Constructor sets ID `lastCursorWordSelect` and undefined precondition. | — | N-A (multi-cursor) | TODO |
| CORE-144 | coreCommands.ts:1678-1681 | Its run method returns when position is absent. | — | N-A (multi-cursor) | TODO |
| CORE-145 | coreCommands.ts:1682-1688 | It targets last-added state and uses that state's current `hasSelection()` as selection mode. | — | N-A (multi-cursor) | TODO |
| CORE-146 | coreCommands.ts:1689-1695 | It pushes stack then sets copied states with supplied source/`Explicit`. | — | N-A (multi-cursor) | TODO |
| CORE-147 | coreCommands.ts:1699 | `LineCommand._inSelectionMode` field. | NAV | PORTED | TODO |
| CORE-148 | coreCommands.ts:1701-1704 | Constructor retains `opts.inSelectionMode`. | NAV | PORTED | TODO |
| CORE-149 | coreCommands.ts:1706-1709 | Line command returns when position is absent. | NAV | TESTED | TODO |
| CORE-150 | coreCommands.ts:1710-1717 | It pushes stack and sets one `line(primary,inSelectionMode,position,viewPosition)` state with supplied source/`Explicit`. | NAV + SPINE | TESTED | TODO |
| CORE-151 | coreCommands.ts:1718-1720 | Line selection reveals only when reveal type is not `None`, using `(source,false,true)`. | NAV | TESTED | TODO |
| CORE-152 | coreCommands.ts:1724-1728 | `LineSelect`: false, ID `_lineSelect`, undefined precondition. | NAV | TESTED | TODO |
| CORE-153 | coreCommands.ts:1730-1734 | `LineSelectDrag`: true, ID `_lineSelectDrag`, undefined precondition. | NAV | TESTED | TODO |
| CORE-154 | coreCommands.ts:1737 | `LastCursorLineCommand._inSelectionMode` field. | — | N-A (multi-cursor) | TODO |
| CORE-155 | coreCommands.ts:1739-1742 | Constructor retains `opts.inSelectionMode`. | — | N-A (multi-cursor) | TODO |
| CORE-156 | coreCommands.ts:1744-1747 | Last-cursor line command returns when position is absent. | — | N-A (multi-cursor) | TODO |
| CORE-157 | coreCommands.ts:1748-1753 | It replaces last-added state with `line(...,inSelectionMode,position,viewPosition)`. | — | N-A (multi-cursor) | TODO |
| CORE-158 | coreCommands.ts:1754-1759 | Last-cursor line command pushes stack then sets copied states with supplied source/`Explicit`. | — | N-A (multi-cursor) | TODO |
| CORE-159 | coreCommands.ts:1763-1767 | `LastCursorLineSelect`: false, ID `lastCursorLineSelect`, undefined precondition. | — | N-A (multi-cursor) | TODO |
| CORE-160 | coreCommands.ts:1769-1773 | `LastCursorLineSelectDrag`: true, ID `lastCursorLineSelectDrag`, undefined precondition. | — | N-A (multi-cursor) | TODO |
| CORE-161 | coreCommands.ts:1775 | Exported `CancelSelection` constant registers the anonymous command. | REG + NAV | DEFERRED (outside required key set) | TODO |
| CORE-162 | coreCommands.ts:1776-1787 | Constructor sets ID `cancelSelection`, nonempty-selection precondition, core weight/focus, Escape and Shift+Escape. | REG + NAV | DEFERRED (outside required key set) | TODO |
| CORE-163 | coreCommands.ts:1789-1799 | Cancel pushes stack, replaces with `cancelSelection(primary)` under `Explicit`, then reveals horizontally. | NAV + SPINE | DEFERRED (outside required key set) | TODO |
| CORE-164 | coreCommands.ts:1802 | Exported `RemoveSecondaryCursors` constant registers the anonymous command. | — | N-A (single cursor) | TODO |
| CORE-165 | coreCommands.ts:1803-1814 | Constructor sets multiple-selection precondition, weight `CORE_WEIGHT + 1`, focus, Escape and Shift+Escape. | — | N-A (single cursor) | TODO |
| CORE-166 | coreCommands.ts:1816-1827 | It keeps only primary, reveals, then announces exact status `Removed secondary cursors`. | — | N-A (single cursor) | TODO |
| CORE-168 | coreCommands.ts:1881 | Exported `SelectAll` constant owns the anonymous editor/native command. | REG | PORTED | TODO |
| CORE-169 | coreCommands.ts:1882-1884 | Constructor registers it through the editor-or-native SelectAll multi-command. | REG | PORTED | TODO |
| CORE-170 | coreCommands.ts:1885-1892 | Native DOM SelectAll has a Firefox focus+select special case, then `execCommand('selectAll')`. | — | N-A (editor-root command path does not use DOM input selection) | TODO |
| CORE-171 | coreCommands.ts:1893-1899 | Editor SelectAll reads the view model, returns without one, then delegates the core command. | REG | TESTED | TODO |
| CORE-172 | coreCommands.ts:1901-1909 | Core SelectAll pushes stack then sets one `selectAll(primary)` state with reason `Explicit`. | NAV + SPINE | TESTED | TODO |
| CORE-173 | coreCommands.ts:1903-1905 | Core SelectAll hard-codes source `'keyboard'` (the mouse caller's args are ignored). | SPINE | TESTED | TODO |
| CORE-174 | coreCommands.ts:1913-1915 | `SetSelectionCommandOptions.selection` is required and retains base source. | NAV | PORTED | TODO |
| CORE-175 | coreCommands.ts:1917 | Exported `SetSelection` constant registers the anonymous command. | REG | PORTED | TODO |
| CORE-176 | coreCommands.ts:1918-1923 | Constructor sets ID `setSelection` and undefined precondition. | REG | PORTED | TODO |
| CORE-177 | coreCommands.ts:1925-1928 | Missing `selection` returns before stack/state work. | NAV | TESTED | TODO |
| CORE-178 | coreCommands.ts:1929-1936 | It pushes stack then sets one `CursorState.fromModelSelection` with supplied source and `Explicit`. | NAV + SPINE | TESTED | TODO |
| CORE-179 | coreCommands.ts:1941-1944 | Column-mode override condition is `textInputFocus && columnSelection`. | — | N-A (column selection) | TODO |
| CORE-180 | coreCommands.ts:1945-1951 | Override helper registers ID/key with that condition and exact weight `CORE_WEIGHT + 1`. | — | N-A (column selection) | TODO |
| CORE-181 | coreCommands.ts:1954 | Shift+Left overrides to `CursorColumnSelectLeft`. | — | N-A (column selection) | TODO |
| CORE-182 | coreCommands.ts:1955 | Shift+Right overrides to `CursorColumnSelectRight`. | — | N-A (column selection) | TODO |
| CORE-183 | coreCommands.ts:1956 | Shift+Up overrides to `CursorColumnSelectUp`. | — | N-A (column selection) | TODO |
| CORE-184 | coreCommands.ts:1957 | Shift+PageUp overrides to `CursorColumnSelectPageUp`. | — | N-A (column selection) | TODO |
| CORE-185 | coreCommands.ts:1958 | Shift+Down overrides to `CursorColumnSelectDown`. | — | N-A (column selection) | TODO |
| CORE-186 | coreCommands.ts:1959 | Shift+PageDown overrides to `CursorColumnSelectPageDown`. | — | N-A (column selection) | TODO |
| CORE-187 | coreCommands.ts:703 | `cursorLeft` mac override repeats primary Left and adds secondary WinCtrl+B. | REG | DEFERRED (alternate-platform surface outside approved 16 primary bindings) | TODO |
| CORE-188 | coreCommands.ts:736 | `cursorRight` mac override repeats primary Right and adds secondary WinCtrl+F. | REG | DEFERRED (alternate-platform surface outside approved 16 primary bindings) | TODO |
| CORE-189 | coreCommands.ts:769 | `cursorUp` mac override repeats primary Up and adds secondary WinCtrl+P. | REG | DEFERRED (alternate-platform surface outside approved 16 primary bindings) | TODO |
| CORE-190 | coreCommands.ts:785-788 | `cursorUpSelect` adds generic secondary CtrlCmd+Shift+Up and explicit mac/Linux primary Shift+Up overrides. | REG | DEFERRED (alternate-platform surface outside approved 16 primary bindings) | TODO |
| CORE-191 | coreCommands.ts:837 | `cursorDown` mac override repeats primary Down and adds secondary WinCtrl+N. | REG | DEFERRED (alternate-platform surface outside approved 16 primary bindings) | TODO |
| CORE-192 | coreCommands.ts:853-856 | `cursorDownSelect` adds generic secondary CtrlCmd+Shift+Down and explicit mac/Linux primary Shift+Down overrides. | REG | DEFERRED (alternate-platform surface outside approved 16 primary bindings) | TODO |
| CORE-193 | coreCommands.ts:1013 | `cursorHome` mac override repeats primary Home and adds secondary CtrlCmd+Left. | REG | DEFERRED (alternate-platform surface outside approved 16 primary bindings) | TODO |
| CORE-194 | coreCommands.ts:1025 | `cursorHomeSelect` mac override repeats primary Shift+Home and adds secondary CtrlCmd+Shift+Left. | REG | DEFERRED (alternate-platform surface outside approved 16 primary bindings) | TODO |
| CORE-195 | coreCommands.ts:1116,1118-1133 | `cursorEnd` mac secondary CtrlCmd+Right plus `Go to End` command metadata and sticky boolean schema/default false. | REG | DEFERRED (alternate-platform/command-metadata surface outside approved 16 primary bindings) | TODO |
| CORE-196 | coreCommands.ts:1145,1147-1162 | `cursorEndSelect` mac secondary CtrlCmd+Shift+Right plus `Select to End` metadata and sticky boolean schema/default false. | REG | DEFERRED (alternate-platform/command-metadata surface outside approved 16 primary bindings) | TODO |

##### VC ledger

| ID | Source member (file:line) | Arithmetic / transition | Local target | Proposed terminal | Status |
|---|---|---|---|---|---|
| VC-001 | viewController.ts:22 | `IMouseDispatchData.position` is the validated view position. | MOUSE | TESTED | TODO |
| VC-002 | viewController.ts:23-26 | `mouseColumn` preserves desired visual column when the text position was clamped. | MOUSE | TESTED | TODO |
| VC-003 | viewController.ts:27 | `revealType` is retained per gesture. | MOUSE | TESTED | TODO |
| VC-004 | viewController.ts:28 | `startedOnLineNumbers` switches to whole-line semantics. | MOUSE | TESTED | TODO |
| VC-005 | viewController.ts:30 | `inSelectionMode` distinguishes initial gesture from extension/drag. | MOUSE | TESTED | TODO |
| VC-006 | viewController.ts:31 | `mouseDownCount` selects click granularity. | MOUSE | TESTED | TODO |
| VC-007 | viewController.ts:32 | `altKey` participates in configured multi/column selection. | MOUSE | TESTED | TODO |
| VC-008 | viewController.ts:33 | `ctrlKey` participates in configured multi/non-multi modifiers. | MOUSE | TESTED | TODO |
| VC-009 | viewController.ts:34 | `metaKey` participates in configured multi/non-multi modifiers. | MOUSE | TESTED | TODO |
| VC-010 | viewController.ts:35 | `shiftKey` selects column continuation inside the multi-cursor arm. | MOUSE | N-A (column selection branch) | TODO |
| VC-011 | viewController.ts:37 | `leftButton` is retained even though `dispatchMouse` itself does not branch on it. | MOUSE | PORTED | TODO |
| VC-012 | viewController.ts:38 | `middleButton` owns the first dispatch branch. | MOUSE | TESTED | TODO |
| VC-013 | viewController.ts:39 | `onInjectedText` suppresses double-click selection. | MOUSE | TESTED | TODO |
| VC-014 | viewController.ts:53 | Mouse dispatch owns the configuration reference. | MOUSE | PORTED | TODO |
| VC-015 | viewController.ts:54 | Mouse dispatch owns the viewModel reference. | MOUSE | PORTED | TODO |
| VC-016 | viewController.ts:58-68 | Constructor retains configuration/viewModel (user-input/delegate siblings excluded). | MOUSE | PORTED | TODO |
| VC-017 | viewController.ts:94-99 | `setSelection` routes through `CoreNavigationCommands.SetSelection` with source exactly `keyboard`. | MOUSE + SPINE | TESTED | TODO |
| VC-018 | viewController.ts:101-107 | `_validateViewColumn` reads per-line minimum; below-min returns a position clamped to that minimum, otherwise returns input unchanged. | MOUSE | TESTED | TODO |
| VC-019 | viewController.ts:109-112 | `_hasMulticursorModifier`: option `altKey` returns `data.altKey`. | MOUSE | TESTED | TODO |
| VC-020 | viewController.ts:113-114 | Configured `ctrlKey` returns `data.ctrlKey`. | — | DEFERRED (multiCursorModifier option absent) | TODO |
| VC-021 | viewController.ts:115-116 | Configured `metaKey` returns `data.metaKey`. | — | DEFERRED (multiCursorModifier option absent) | TODO |
| VC-022 | viewController.ts:117-119 | Unknown configured modifier returns false. | — | DEFERRED (multiCursorModifier option absent) | TODO |
| VC-023 | viewController.ts:122-125 | `_hasNonMulticursorModifier`: with multi=`altKey`, ctrl or meta is non-multi. | — | N-A (only gates excluded multi-cursor arm) | TODO |
| VC-024 | viewController.ts:126-127 | With multi=`ctrlKey`, alt or meta is non-multi. | — | N-A (only gates excluded multi-cursor arm) | TODO |
| VC-025 | viewController.ts:128-129 | With multi=`metaKey`, ctrl or alt is non-multi. | — | N-A (only gates excluded multi-cursor arm) | TODO |
| VC-026 | viewController.ts:130-132 | Unknown configured modifier yields no non-multi modifier. | — | N-A (only gates excluded multi-cursor arm) | TODO |
| VC-027 | viewController.ts:140-147 | Bracket helper first tries `column > 1`, matching at `column-1`; exact opening-end equality selects opening end through closing start. | — | DEFERRED (doubleClickSelectsBlock/bracket service) | TODO |
| VC-028 | viewController.ts:149-155 | It next tries when column is at/before line max; exact closing-start equality yields the same interior selection. | — | DEFERRED (doubleClickSelectsBlock/bracket service) | TODO |
| VC-029 | viewController.ts:157 | No matching bracket returns undefined. | — | DEFERRED (doubleClickSelectsBlock/bracket service) | TODO |
| VC-030 | viewController.ts:165-175 | String helper demands accurate tokens; cheap lines are force-tokenized, expensive inaccurate lines return undefined. | — | DEFERRED (doubleClickSelectsBlock/token service) | TODO |
| VC-031 | viewController.ts:178-189 | It expands left/right across the complete contiguous run of `StandardTokenType.String` tokens. | — | DEFERRED (doubleClickSelectsBlock/token service) | TODO |
| VC-032 | viewController.ts:191-196 | Click must be exactly `tokenStart + 2` (after opener) or `tokenEnd` (before closer), otherwise return. | — | DEFERRED (doubleClickSelectsBlock/token service) | TODO |
| VC-033 | viewController.ts:198-203 | Opening delimiter must be exactly double quote, single quote, or backtick. | — | DEFERRED (doubleClickSelectsBlock/token service) | TODO |
| VC-034 | viewController.ts:204-206 | Closing character at `tokenEnd - 1` must equal the opening delimiter. | — | DEFERRED (doubleClickSelectsBlock/token service) | TODO |
| VC-035 | viewController.ts:208-212 | Interior substring containing RTL causes an early undefined return. | — | DEFERRED (doubleClickSelectsBlock/token service) | TODO |
| VC-036 | viewController.ts:214 | Valid quoted content selects columns `tokenStart + 2` through `tokenEnd`. | — | DEFERRED (doubleClickSelectsBlock/token service) | TODO |
| VC-037 | viewController.ts:217-221 | `dispatchMouse` reads selectionClipboard, columnSelection, and scrollOnMiddleClick once before its ordered branch chain. | MOUSE | PORTED | TODO |
| VC-038 | viewController.ts:219 | Selection clipboard is active only on Linux and when the option is enabled. | — | N-A (middle-selection clipboard absent) | TODO |
| VC-039 | viewController.ts:222-227 | Middle button enters the special arm only when selection clipboard is off; scroll-on-middle is contribution-owned no-op here, otherwise column-select. | MOUSE | N-A (middle scroll/column select) | TODO |
| VC-040 | viewController.ts:228-235 | Gutter + multi modifier selects/extends last cursor when dragging, otherwise creates a whole-line cursor. | — | N-A (multi-cursor) | TODO |
| VC-041 | viewController.ts:236-242 | Gutter single-cursor path uses line-select-drag in selection mode, otherwise fresh line-select. | MOUSE + SPINE | TESTED | TODO |
| VC-042 | viewController.ts:243-244 | `mouseDownCount >= 4` selects all before triple/double/single branches. | MOUSE + SPINE | TESTED | TODO |
| VC-043 | viewController.ts:245-251 | Triple-click + multi modifier routes drag to last-cursor-line-drag and initial to last-cursor-line. | — | N-A (multi-cursor) | TODO |
| VC-044 | viewController.ts:252-258 | Triple-click single-cursor routes drag to line-select-drag and initial to line-select. | MOUSE + SPINE | TESTED | TODO |
| VC-045 | viewController.ts:259-260 | Double-click does nothing at all when `onInjectedText` is true. | MOUSE | TESTED | TODO |
| VC-046 | viewController.ts:261-263 | Double-click + multi modifier routes to last-cursor word select. | — | N-A (multi-cursor) | TODO |
| VC-047 | viewController.ts:264-266 | Double-click in selection mode routes to word-select-drag. | MOUSE + SPINE | TESTED | TODO |
| VC-048 | viewController.ts:267-272 | Fresh double-click optionally probes bracket first, then string, only when `doubleClickSelectsBlock`. | — | DEFERRED (option/services absent) | TODO |
| VC-049 | viewController.ts:273-277 | A found block selection routes through `_select`; no block falls back to `_wordSelect`. | MOUSE + SPINE | TESTED | TODO |
| VC-050 | viewController.ts:281-294 | Single-click multi arm runs only with no non-multi modifier; Shift column-selects, drag extends last cursor, otherwise creates cursor. | — | N-A (multi/column cursor) | TODO |
| VC-051 | viewController.ts:295-299 | Single-cursor selection mode with Alt routes to column select. | — | N-A (column selection) | TODO |
| VC-052 | viewController.ts:300-302 | Without Alt, configured global columnSelection still routes to column select. | — | N-A (column selection) | TODO |
| VC-053 | viewController.ts:303-304 | Ordinary selection-mode gesture routes to `_moveToSelect`. | MOUSE + SPINE | TESTED | TODO |
| VC-054 | viewController.ts:306-308 | Ordinary non-selection gesture routes to `moveTo`. | MOUSE + SPINE | TESTED | TODO |
| VC-055 | viewController.ts:313-320 | `_usualArgs` validates view column, fixes source to `mouse`, converts model position, retains view position, and preserves reveal type in that order. | MOUSE | TESTED | TODO |
| VC-056 | viewController.ts:323-325 | `moveTo` invokes the registered MoveTo core command with `_usualArgs`. | MOUSE + NAV | TESTED | TODO |
| VC-057 | viewController.ts:327-329 | `_moveToSelect` invokes MoveToSelect with `_usualArgs`. | MOUSE + NAV | TESTED | TODO |
| VC-058 | viewController.ts:331-340 | `_columnSelect` validates, fixes source `mouse`, converts model/view positions, and forwards mouseColumn/doColumnSelect. | — | N-A (column selection) | TODO |
| VC-059 | viewController.ts:342-350 | `_createCursor` validates, fixes source `mouse`, converts positions, and forwards wholeLine. | — | N-A (multi-cursor) | TODO |
| VC-060 | viewController.ts:352-354 | `_lastCursorMoveToSelect` invokes its core command with `_usualArgs`. | — | N-A (multi-cursor) | TODO |
| VC-061 | viewController.ts:356-358 | `_wordSelect` invokes WordSelect with `_usualArgs`. | MOUSE + NAV | TESTED | TODO |
| VC-062 | viewController.ts:360-362 | `_wordSelectDrag` invokes WordSelectDrag with `_usualArgs`. | MOUSE + NAV | TESTED | TODO |
| VC-063 | viewController.ts:364-366 | `_lastCursorWordSelect` invokes its core command with `_usualArgs`. | — | N-A (multi-cursor) | TODO |
| VC-064 | viewController.ts:368-370 | `_lineSelect` invokes LineSelect with `_usualArgs`. | MOUSE + NAV | TESTED | TODO |
| VC-065 | viewController.ts:372-374 | `_lineSelectDrag` invokes LineSelectDrag with `_usualArgs`. | MOUSE + NAV | TESTED | TODO |
| VC-066 | viewController.ts:376-378 | `_lastCursorLineSelect` invokes its core command with `_usualArgs`. | — | N-A (multi-cursor) | TODO |
| VC-067 | viewController.ts:380-382 | `_lastCursorLineSelectDrag` invokes its core command with `_usualArgs`. | — | N-A (multi-cursor) | TODO |
| VC-068 | viewController.ts:384-386 | `_select` routes one model selection through SetSelection with source exactly `mouse`. | MOUSE + SPINE | TESTED | TODO |
| VC-069 | viewController.ts:388-390 | `_selectAll` calls core SelectAll with a nominal `{source:'mouse'}` argument (the source core body ignores it). | MOUSE + SPINE | TESTED | TODO |
| VC-070 | viewController.ts:394-396 | `_convertViewToModelPosition` delegates to the active coordinates converter. | MOUSE | TESTED | TODO |

##### CEW inherited source authority (not denominator rows)

| Source lines | Frozen owner | Required cursor-child audit |
|---|---|---|
| codeEditorWidget.ts:78 | lifecycle CEW-001 | Preserve one coherent synchronous/local ordering seam or record delivery-queue deviation. |
| codeEditorWidget.ts:117-121 | lifecycle CEW-015/016 | Reuse existing public cursor emitters; do not create duplicate event surfaces. |
| codeEditorWidget.ts:1791-1885 | lifecycle CEW-123..139 | Keep the complete switch ownership frozen in lifecycle. |
| codeEditorWidget.ts:1812-1833 | lifecycle CEW-130 | Single-cursor max-count warning remains N-A. |
| codeEditorWidget.ts:1835-1860 | lifecycle CEW-131 | Strengthen tests/implementation so positions are derived first, position fires before selection, primary/secondary/version/old/source/reason fields are coherent for API, mouse, keyboard, and flush. |

##### CEW ledger

| ID | Source member (file:line) | Arithmetic / transition | Local target | Proposed terminal | Status |
|---|---|---|---|---|---|
| CEW-001 | codeEditorWidget.ts:663-668 | `getPosition`: no model returns null; otherwise delegate to `viewModel.getPosition()`. | API | TESTED | TODO |
| CEW-002 | codeEditorWidget.ts:670 | `setPosition` source defaults exactly to `api`. | API + SPINE | TESTED | TODO |
| CEW-003 | codeEditorWidget.ts:671-673 | `setPosition` returns without a model. | API | TESTED | TODO |
| CEW-004 | codeEditorWidget.ts:674-676 | A non-`IPosition` argument throws exact `Error('Invalid arguments')`. | API | DEFERRED (typed MoonBit argument cannot be malformed) | TODO |
| CEW-005 | codeEditorWidget.ts:677-682 | It forwards one collapsed selection: all four selection-start/position line/column fields equal the input, preserving source. | API + SPINE | TESTED | TODO |
| CEW-006 | codeEditorWidget.ts:783-788 | `getSelection`: no model null; otherwise delegate primary model selection. | API | TESTED | TODO |
| CEW-007 | codeEditorWidget.ts:790-795 | `getSelections`: no model null; otherwise delegate all model selections. | API | TESTED | TODO |
| CEW-008 | codeEditorWidget.ts:797 | `setSelection(IRange,source?)` overload is accepted. | API | N-A (one typed Selection API) | TODO |
| CEW-009 | codeEditorWidget.ts:798 | `setSelection(Range,source?)` overload is accepted. | API | N-A (one typed Selection API) | TODO |
| CEW-010 | codeEditorWidget.ts:799 | `setSelection(ISelection,source?)` overload is accepted. | API | N-A (one typed Selection API) | TODO |
| CEW-011 | codeEditorWidget.ts:800 | `setSelection(Selection,source?)` overload is accepted. | API | TESTED | TODO |
| CEW-012 | codeEditorWidget.ts:801 | Unknown implementation signature exists for overload dispatch. | API | N-A (MoonBit static typing) | TODO |
| CEW-013 | codeEditorWidget.ts:802-805 | Implementation source defaults `api` and independently recognizes selection and range shapes. | API | TESTED | TODO |
| CEW-014 | codeEditorWidget.ts:806-808 | A value matching neither shape throws exact invalid-arguments error. | API | N-A (MoonBit static typing) | TODO |
| CEW-015 | codeEditorWidget.ts:810-812 | Selection-shaped input is sent unchanged to `_setSelectionImpl`. | API | TESTED | TODO |
| CEW-016 | codeEditorWidget.ts:812-820 | Range-shaped input becomes a forward selection: start maps to selectionStart, end maps to position. | API | N-A (callers explicitly construct Selection) | TODO |
| CEW-017 | codeEditorWidget.ts:824-827 | `_setSelectionImpl` returns without a model. | API | TESTED | TODO |
| CEW-018 | codeEditorWidget.ts:828-830 | It constructs a concrete Selection preserving anchor/active direction, then forwards one selection plus source. | API + SPINE | TESTED | TODO |
| CEW-019 | codeEditorWidget.ts:948 | `setSelections` defaults source `api` and reason `CursorChangeReason.NotSet`. | API + SPINE | TESTED | TODO |
| CEW-020 | codeEditorWidget.ts:949-951 | `setSelections` returns without a model. | API | TESTED | TODO |
| CEW-021 | codeEditorWidget.ts:952-954 | Null or empty ranges throw invalid arguments. | API | DEFERRED (typed non-null; empty currently no-op rather than throw) | TODO |
| CEW-022 | codeEditorWidget.ts:955-959 | Every array element is validated as a selection; first invalid element throws. | API | N-A (typed array) | TODO |
| CEW-023 | codeEditorWidget.ts:960 | Source forwards the complete validated `ranges` array, source, and reason unchanged. Under the approved single-cursor Viewer seam, `ranges[0]`, source, and reason forward unchanged while `ranges[1..]` are intentionally dropped; preservation of secondaries is the row-local single-cursor deviation. | API + SPINE | TESTED | TODO |

##### VED excluded sibling registry (not denominator rows)

| Source lines | Excluded sibling ownership |
|---|---|
| viewModelEventDispatcher.ts:177-183,185-193,196-202,204-212 | Non-cursor union arms/kinds: lifecycle/focus, geometry/scroll, zones/hidden areas, readonly editing, invalidation/decorations, model/language/content/options/tokens/font children. |
| viewModelEventDispatcher.ts:214-386,446-591 | Non-cursor event class fields/constructors/no-op/merge bodies owned by those same children. |

##### VED ledger

| ID | Source member (file:line) | Arithmetic / transition | Local target | Proposed terminal | Status |
|---|---|---|---|---|---|
| VED-001 | viewModelEventDispatcher.ts:17 | `_onEvent` is a registered emitter of the outgoing union. | SPINE | PORTED | TODO |
| VED-002 | viewModelEventDispatcher.ts:18 | `onEvent` is the public alias of `_onEvent.event`. | SPINE | PORTED | TODO |
| VED-003 | viewModelEventDispatcher.ts:20 | `_eventHandlers` owns ordered view-event handlers. | SPINE | DEFERRED (generic view-event dispatcher owned by render-invalidation child) | TODO |
| VED-004 | viewModelEventDispatcher.ts:21 | `_viewEventQueue` is null or an ordered event array. | SPINE | DEFERRED (generic view-event dispatcher owned by render-invalidation child) | TODO |
| VED-005 | viewModelEventDispatcher.ts:22 | `_isConsumingViewEventQueue` is the reentrancy gate. | SPINE | DEFERRED (generic view-event dispatcher owned by render-invalidation child) | TODO |
| VED-006 | viewModelEventDispatcher.ts:23 | `_collector` is the current nested transaction collector or null. | SPINE | DEFERRED (generic view-event dispatcher owned by render-invalidation child) | TODO |
| VED-007 | viewModelEventDispatcher.ts:24 | `_collectorCnt` tracks nested begin/end depth. | SPINE | DEFERRED (generic view-event dispatcher owned by render-invalidation child) | TODO |
| VED-008 | viewModelEventDispatcher.ts:25 | `_outgoingEvents` owns the pending/coalesced outgoing queue. | SPINE | PORTED | TODO |
| VED-009 | viewModelEventDispatcher.ts:27-35 | Constructor initializes handlers/outgoing to empty, queue/collector null, consuming false, and depth zero. | SPINE | DEFERRED (generic view-event dispatcher owned by render-invalidation child) | TODO |
| VED-010 | viewModelEventDispatcher.ts:37-40 | `emitOutgoingEvent` adds/merges first, then attempts to drain. | SPINE | TESTED | TODO |
| VED-011 | viewModelEventDispatcher.ts:42-45 | `_addOutgoingEvent` scans pending events in order and calls `attemptToMerge` only on the same kind. | SPINE | TESTED | TODO |
| VED-012 | viewModelEventDispatcher.ts:45-48 | A truthy merge replaces that existing queue slot and returns immediately. | SPINE | TESTED | TODO |
| VED-013 | viewModelEventDispatcher.ts:50-52 | No merge appends the event at queue tail. | SPINE | TESTED | TODO |
| VED-014 | viewModelEventDispatcher.ts:54-55 | `_emitOutgoingEvents` drains while the queue is nonempty. | SPINE | TESTED | TODO |
| VED-015 | viewModelEventDispatcher.ts:56-59 | Active collector or active view-event consumption postpones outgoing delivery without removing the head. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-016 | viewModelEventDispatcher.ts:60 | Delivery shifts the oldest event (FIFO). | SPINE | TESTED | TODO |
| VED-017 | viewModelEventDispatcher.ts:61-63 | `isNoOp()` events are discarded and draining continues. | SPINE | TESTED | TODO |
| VED-018 | viewModelEventDispatcher.ts:64 | Non-no-op event fires through `_onEvent`. | SPINE | TESTED | TODO |
| VED-019 | viewModelEventDispatcher.ts:68-73 | `addViewEventHandler` scans for identical handler and warns on duplicate without preventing registration. | SPINE | DEFERRED (no generic handler registry needed) | TODO |
| VED-020 | viewModelEventDispatcher.ts:74 | Handler is appended after duplicate scan. | SPINE | DEFERRED (no generic handler registry needed) | TODO |
| VED-021 | viewModelEventDispatcher.ts:77-84 | `removeViewEventHandler` removes the first identical handler and breaks; missing handler is a no-op. | SPINE | DEFERRED (no generic handler registry needed) | TODO |
| VED-022 | viewModelEventDispatcher.ts:86-87 | `beginEmitViewEvents` increments depth first. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-023 | viewModelEventDispatcher.ts:88-90 | Exactly depth `1` creates the shared collector. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-024 | viewModelEventDispatcher.ts:91 | Every nested begin returns the same non-null collector. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-025 | viewModelEventDispatcher.ts:94-96 | `endEmitViewEvents` decrements depth; only transition to zero flushes the collector. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-026 | viewModelEventDispatcher.ts:97-99 | Outgoing and view arrays are captured, then `_collector` is nulled before any callback. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-027 | viewModelEventDispatcher.ts:101-103 | Collected outgoing events are added/merged in collector order. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-028 | viewModelEventDispatcher.ts:105-107 | Nonempty collected view events are emitted before the final outgoing drain. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-029 | viewModelEventDispatcher.ts:109 | `_emitOutgoingEvents` runs after the outermost view-event emission (and after every nested end no-op). | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-030 | viewModelEventDispatcher.ts:112-119 | `emitSingleViewEvent` begins, queues one view event, and ends in `finally`. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-031 | viewModelEventDispatcher.ts:121-126 | `_emitMany` concatenates onto an existing reentrant queue; otherwise installs the array directly. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-032 | viewModelEventDispatcher.ts:128-130 | Queue consumption starts only when it is not already consuming. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-033 | viewModelEventDispatcher.ts:133-140 | `_consumeViewEventQueue` sets consuming true, drains, and restores false in `finally`. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-034 | viewModelEventDispatcher.ts:142-147 | `_doConsumeQueue` snapshots the current queue and clears the field before invoking handlers, allowing reentrant events to form a later batch. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-035 | viewModelEventDispatcher.ts:148-149 | It clones the handler list before callbacks so handlers may remove themselves. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-036 | viewModelEventDispatcher.ts:150-152 | Every cloned handler receives the entire batch in registration order. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-037 | viewModelEventDispatcher.ts:159 | `ViewModelEventsCollector.viewEvents` field. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-038 | viewModelEventDispatcher.ts:160 | `ViewModelEventsCollector.outgoingEvents` field. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-039 | viewModelEventDispatcher.ts:162-165 | Collector constructor initializes both arrays empty. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-040 | viewModelEventDispatcher.ts:167-169 | `emitViewEvent` appends one view event. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-041 | viewModelEventDispatcher.ts:171-173 | `emitOutgoingEvent` appends one outgoing event. | SPINE | DEFERRED (generic view-event collector owned by render-invalidation child) | TODO |
| VED-042 | viewModelEventDispatcher.ts:184 | `CursorStateChangedEvent` is the cursor arm of `OutgoingViewModelEvent`. | SPINE | PORTED | TODO |
| VED-043 | viewModelEventDispatcher.ts:203 | `OutgoingViewModelEventKind.CursorStateChanged` is the eighth const-enum arm and therefore has exact numeric value `7`; the MoonBit semantic variant has no numeric ABI. | SPINE | TESTED | TODO |
| VED-044 | viewModelEventDispatcher.ts:389 | `CursorStateChangedEvent.kind` is `CursorStateChanged`. | SPINE | PORTED | TODO |
| VED-045 | viewModelEventDispatcher.ts:391 | `oldSelections` is nullable. | SPINE | PORTED | TODO |
| VED-046 | viewModelEventDispatcher.ts:392 | `selections` is the new ordered selection array. | SPINE | PORTED | TODO |
| VED-047 | viewModelEventDispatcher.ts:393 | `oldModelVersionId` field. | SPINE | PORTED | TODO |
| VED-048 | viewModelEventDispatcher.ts:394 | `modelVersionId` field. | SPINE | PORTED | TODO |
| VED-049 | viewModelEventDispatcher.ts:395 | `source` field. | SPINE | PORTED | TODO |
| VED-050 | viewModelEventDispatcher.ts:396 | `reason` field. | SPINE | PORTED | TODO |
| VED-051 | viewModelEventDispatcher.ts:397 | `reachedMaxCursorCount` field. | — | N-A (single cursor) | TODO |
| VED-052 | viewModelEventDispatcher.ts:399-407 | Constructor retains all seven payload inputs without transformation. | SPINE | PORTED | TODO |
| VED-053 | viewModelEventDispatcher.ts:409-412 | `_selectionsAreEqual`: both null is true. | SPINE | TESTED | TODO |
| VED-054 | viewModelEventDispatcher.ts:413-415 | Exactly one null is false. | SPINE | TESTED | TODO |
| VED-055 | viewModelEventDispatcher.ts:416-420 | Different lengths are false. | SPINE | TESTED | TODO |
| VED-056 | viewModelEventDispatcher.ts:421-425 | Any index whose `equalsSelection` is false returns false immediately. | SPINE | TESTED | TODO |
| VED-057 | viewModelEventDispatcher.ts:426 | Equal arrays return true. | SPINE | TESTED | TODO |
| VED-058 | viewModelEventDispatcher.ts:429-434 | Cursor event is no-op only when selections are equal *and* old/new model version IDs are equal. | SPINE | TESTED | TODO |
| VED-059 | viewModelEventDispatcher.ts:436-439 | Merge rejects a different event kind with null. | SPINE | TESTED | TODO |
| VED-060 | viewModelEventDispatcher.ts:440-442 | Merge preserves earliest old selections/version, takes latest new selections/version/source/reason, and ORs reached-max flags. | SPINE | TESTED | TODO |

##### VMI excluded sibling registry (not denominator rows)

| Source lines | Excluded sibling ownership |
|---|---|
| viewModelImpl.ts:49-318,471-1146 | Identity/configuration/focus/line mapping/model sibling events/decorations/hidden areas/viewport/render/copy clusters. Cursor construction seams at :56-57,65,86-87,124 are carved into the denominator below. |
| viewModelImpl.ts:319-457 | Projection/layout handling for content/injected text; cursor receives the already-processed event through the separately scoped `emitContentChangeEvent`. |
| viewModelImpl.ts:1195-1229 | Readonly-edit and editing/composition/type/paste/cut/execute implementations. |
| viewModelImpl.ts:1252-1260,1281-1472 | Whitespace/zones, normalization, and helper classes/functions. |

##### VMI ledger

| ID | Source member (file:line) | Arithmetic / transition | Local target | Proposed terminal | Status |
|---|---|---|---|---|---|
| VMI-001 | viewModelImpl.ts:56 | `_eventDispatcher` owns generic view/outgoing event delivery; the local cursor child ports its outgoing-only half while generic view delivery remains deferred. | outgoing-only cursor event dispatcher | PORTED | TODO |
| VMI-002 | viewModelImpl.ts:57 | `onEvent` exposes the dispatcher's outgoing event; locally the ViewModel exposes the cursor-outgoing event alias. | outgoing-only cursor event alias | PORTED | TODO |
| VMI-003 | viewModelImpl.ts:65 | `_cursor` owns the cursor controller. | SPINE | PORTED | TODO |
| VMI-004 | viewModelImpl.ts:86-87 | Constructor creates the outgoing dispatcher first, then aliases its event; generic view-event state is deferred with VED-003–007/009. | SPINE | PORTED | TODO |
| VMI-005 | viewModelImpl.ts:122-124 | Coordinates converter is created before the cursor controller receives model/view/converter/config. | SPINE | PORTED | TODO |
| VMI-006 | viewModelImpl.ts:462-469 | `emitContentChangeEvent` runs inside one `_emitViewEvent` collector transaction. The local cursor child preserves the observable content-before-cursor order through its FIFO seam but does not port this generic collector bracket. | render-invalidation collector owner | DEFERRED (generic collector owned by render-invalidation child) | TODO |
| VMI-007 | viewModelImpl.ts:464-466 | Internal model-content events enqueue public `ModelContentChangedEvent` first; injected-text events skip this outgoing event. | SPINE | TESTED | TODO |
| VMI-008 | viewModelImpl.ts:467 | The cursor receives both content and injected-text event forms after the public-content enqueue. | SPINE | TESTED | TODO |
| VMI-009 | viewModelImpl.ts:1149-1151 | `getPrimaryCursorState` delegates to cursor primary state. | NAV + API | PORTED | TODO |
| VMI-010 | viewModelImpl.ts:1152-1154 | `getLastAddedCursorIndex` delegates to the collection. | — | N-A (single cursor) | TODO |
| VMI-011 | viewModelImpl.ts:1155-1157 | `getCursorStates` delegates the ordered cursor-state array. | NAV | TESTED | TODO |
| VMI-012 | viewModelImpl.ts:1158-1160 | `setCursorStates` runs `cursor.setStates(collector,source,reason,states)` transactionally and returns its changed boolean. | SPINE | TESTED | TODO |
| VMI-013 | viewModelImpl.ts:1161-1163 | `getCursorColumnSelectData` delegates prior column-selection data. | — | N-A (column selection) | TODO |
| VMI-014 | viewModelImpl.ts:1164-1166 | `getCursorAutoClosedCharacters` delegates auto-close ranges. | — | N-A (readonly editing state) | TODO |
| VMI-015 | viewModelImpl.ts:1167-1169 | `setCursorColumnSelectData` delegates the exact payload. | — | N-A (column selection) | TODO |
| VMI-016 | viewModelImpl.ts:1170-1172 | `getPrevEditOperationType` delegates editing history. | — | N-A (readonly editing state) | TODO |
| VMI-017 | viewModelImpl.ts:1173-1175 | `setPrevEditOperationType` delegates editing history. | — | N-A (readonly editing state) | TODO |
| VMI-018 | viewModelImpl.ts:1176-1178 | `getSelection` delegates the primary model selection. | API | TESTED | TODO |
| VMI-019 | viewModelImpl.ts:1179-1181 | `getSelections` delegates all model selections in order. | API | TESTED | TODO |
| VMI-020 | viewModelImpl.ts:1182-1184 | `getPosition` returns primary cursor model-state position. | API | TESTED | TODO |
| VMI-021 | viewModelImpl.ts:1185-1187 | Source defaults reason to `NotSet` and transactionally delegates source, the complete selections array, and reason unchanged. The local seam delegates source, `selections[0]`, and reason unchanged; preservation of `selections[1..]` is the same approved single-cursor deviation as CEW-023. | API + SPINE | TESTED | TODO |
| VMI-022 | viewModelImpl.ts:1188-1190 | `saveCursorState` delegates collection serialization. | — | DEFERRED (view-state sibling) | TODO |
| VMI-023 | viewModelImpl.ts:1191-1193 | `restoreCursorState` delegates inside one view-event transaction. | — | DEFERRED (view-state sibling) | TODO |
| VMI-024 | viewModelImpl.ts:1230-1232 | `revealAllCursors` defaults minimal=false and delegates `Simple`, requested horizontal flag, and `ScrollType.Smooth` inside a collector. | NAV | TESTED | TODO |
| VMI-025 | viewModelImpl.ts:1233-1235 | `revealPrimaryCursor` uses the same defaults/constants for primary only. | NAV | DEFERRED (no current caller) | TODO |
| VMI-026 | viewModelImpl.ts:1236-1240 | `revealTopMostCursor` builds a collapsed range at top-most view position and emits reveal request `(source,false,range,null,Simple,true,Smooth)`. | — | N-A (column/multi-cursor) | TODO |
| VMI-027 | viewModelImpl.ts:1241-1245 | `revealBottomMostCursor` analogously uses bottom-most view position and the same fixed reveal arguments. | — | N-A (column/multi-cursor) | TODO |
| VMI-028 | viewModelImpl.ts:1246-1248 | `revealRange` emits `(source,false,viewRange,null,verticalType,revealHorizontal,scrollType)` transactionally. | NAV | PORTED | TODO |
| VMI-029 | viewModelImpl.ts:1262-1266 | `_withViewEventsCollector` first enters transactional target `batchChanges`, then delegates to `_emitViewEvent`. | render-invalidation collector owner | DEFERRED (generic collector owned by render-invalidation child) | TODO |
| VMI-030 | viewModelImpl.ts:1268-1271 | `_emitViewEvent` begins one dispatcher collector before invoking the callback and returns callback result. | render-invalidation collector owner | DEFERRED (generic collector owned by render-invalidation child) | TODO |
| VMI-031 | viewModelImpl.ts:1272-1274 | Dispatcher end runs in `finally`, including callback failure/early return. | render-invalidation collector owner | DEFERRED (generic collector owned by render-invalidation child) | TODO |
| VMI-032 | viewModelImpl.ts:1277-1279 | `batchEvents` uses `_withViewEventsCollector` and ignores the callback's Unit result. | render-invalidation collector owner | DEFERRED (generic collector owned by render-invalidation child) | TODO |

##### Normalized-count audit

- `CORE`: 186 rows.
- `VC`: 70 rows.
- `CEW`: 23 rows (plus inherited lifecycle authority, not duplicated).
- `VED`: 60 rows (outgoing queue plus cursor class scoped here; generic view collection deferred row-locally).
- `VMI`: 32 rows (only cursor ownership/handoff/public cursor region/collector helpers).
- Assigned-source subtotal: **371 rows**.
- Proposed terminals: **121 TESTED + 55 PORTED + 90 DEFERRED + 105 N-A = 371**.
- Every table row is still Gate-A `TODO`.

The normalization reread specifically split fields from constructors, named-class constructors from methods, anonymous command constants from their constructors/callbacks, overload signatures, interface properties, behavior branches/early returns, magic `-1`/`0`/`1`/`2` values, nested collector callbacks, and each command/keybinding registration. Allocation/delegate/return bookkeeping remains on the owning method row. No known scoped atom remains collapsed. Explicitly excluded whole sibling methods/classes are listed in the boundary/exclusion registries rather than represented by synthetic aggregate rows.

##### Current-local audit and recommended ownership

1. `viewer/input.mbt:97-137` currently resolves contribution bindings, then maps PageUp/PageDown/Home/End/Up/Down to viewport scrolling. It has no Left/Right path, ignores Shift in the fallback (so Shift navigation also scrolls), and has no cursor command IDs. Replace that fallback with the required 16 cursor key variants; retain distinct scroll command IDs as out-of-scope registrations, never as cursor-key fallbacks.
2. `viewer/editor_extensions.mbt` keybinding rules have only key/alt/ctrl_cmd/shift and resolve by array order. They carry no weight, context expression, platform override, static command args, or source. The cursor registration target must either add those source-shaped facts or record exact seam deviations. In particular, hover-focused EditorContrib bindings must continue to beat EditorCore cursor bindings.
3. `viewer/view_controller.mbt` already mirrors most single-cursor `dispatchMouse` branch order, but every command mutates the controller directly and only schedules render. Mouse click/drag/double/triple/gutter/select-all therefore bypass public cursor events. Route every live single-cursor branch through the same transition spine as API and keyboard.
4. `viewer/selection.mbt` currently owns an API-only event implementation: hard-coded source `api`, reason `Explicit`, host metadata `model.version`, direct position-then-selection fire, and a model-state-only equality gate. Source public API defaults are source `api`, reason `NotSet`, and the model's internal content version; this must become a caller-parameterized shared transition, not per-path event code.
5. `viewer/common/cursor/cursors_controller.mbt` resets the cursor on Flush but emits/returns no change facts. `viewer/common/view_model/view_model.mbt::emit_content_change_event` invokes it after projection processing, and `viewer/attach_model.mbt` later re-fires public model content. Preserve source ordering: view cursor update first; outgoing ModelContent before outgoing CursorState; CEW relay position before selection. Flush uses source `model`, reason `ContentFlush`, old selections exactly null/`None`, and old model version `0` because source deliberately passes `oldState=null`; the new version is the internal `get_version_id()`.
6. The local public cursor payload already has position/selection/source/reason/version fields, but `old_selections` must change from `Array[Selection]` to `Array[Selection]?` for source parity: emit `None` on Flush and `Some([old_primary_selection])` on ordinary single-cursor transitions. Every secondary array remains `[]`, and `reachedMaxCursorCount` is N-A; do not substitute host version metadata.
7. A minimum coherent target is: the controller transition returns one
   `CursorStateChange` fact; the ViewModel's outgoing-only cursor dispatcher
   coalesces/delivers it; and the root Viewer places it in one reentrancy-safe
   FIFO before converting each fact atomically to position then selection.
   Flush facts wait behind the model-content barrier, while ordinary API,
   keyboard, and mouse facts drain immediately. Do not add four independent
   event-fire sites or a singular pending-flush slot.

##### Required branch/configuration matrix derived from these rows

###### Commands and keybindings

- Exact keys: Left, Right, Up, Down, PageUp, PageDown, Home, End crossed with Shift false/true (16 required cases).
- `pageSize`: exact marker `-1`; omitted and exact-zero dynamic values fall back to configuration, while a positive value overrides; short and tall viewport page sizes.
- Home/End: leading indentation, all-whitespace line, empty line, wrapped first/continuation line, already-at-target no-op, beginning/end document boundaries; End sticky false (sticky true remains an explicit test if retained).
- Left/Right: within a line, cross line boundary, document boundaries, surrogate/grapheme-valid positions within the approved cursor capability.
- Context: model present/absent; editor root focused; hover unfocused/focused so higher-weight hover bindings keep precedence; plain key versus Alt/CtrlCmd chords; platform primary/secondary overrides where implemented.
- Assert handled boolean and browser preventDefault/stopPropagation only for a winning command.

###### Mouse dispatch

- startedOnLineNumbers false/true × inSelectionMode false/true.
- click count 1, 2, 3, 4, and >4; double-click injected text false/true.
- default multi modifier absent/present and non-multi modifier absent/present; all multi/column outcomes assert the approved N-A no-mutation behavior.
- middle button with selection clipboard/scroll-on-middle/column options according to terminal disposition.
- ordinary click, drag, word select/drag, line select/drag, gutter line select, select-all; block-select option disabled and enabled if the deferred helper is ever ported.
- View position below min column versus valid; wrapped/folded/injected conversion; reveal Regular/Minimal/None where locally represented.

###### Transition and outgoing events

- Origin path: public setPosition, setSelection, setSelections; keyboard each command; mouse each live branch; model Flush.
- State axes: collapsed/nonempty, forward/backward, exact-state no-op/changed, same internal version/changed internal version, no model, wrapped view/model mapping.
- API expects source `api`, reason `NotSet`; keyboard navigation source `keyboard`, reason `Explicit`; mouse source `mouse`, reason `Explicit`; Flush source `model`, reason `ContentFlush`.
- SelectAll keeps the source's surprising hard-coded `keyboard` source even when reached through four-click mouse dispatch, unless explicitly recorded as a deviation.
- One accepted transition sends view cursor state first, then public cursor position, then public cursor selection. Flush outgoing order is model-content event, cursor-position event, cursor-selection event after the view update.
- Position payload: primary position and empty secondaries. Selection payload: primary selection, empty secondaries, internal current version, `None` old selections on Flush or `Some([old primary])` otherwise, old version, source, reason.
- Exact same state/version emits nothing. Flush emits because its source passes null old state even when old/new cursor are both origin. Multi-cursor reached-max is impossible.

###### Outgoing dispatcher and Viewer delivery FIFO

- Same-kind merge with adjacent and interleaved other kinds preserves the
  first queue slot; different kind does not merge; FIFO remains stable.
- Cursor selection equality: both null, one null, length mismatch,
  first/middle/last mismatch, all equal; same/different model version.
- Cursor merge: earliest old selection/version, latest new
  selection/version/source/reason, reached-max OR.
- Reentrant position/selection listeners append a later transition without
  interleaving its pair; the outer drain continues until the FIFO is empty.
- Reentrant `set_value` while a model-content listener runs cannot overwrite a
  pending flush. Every content event precedes the queued cursor facts, and
  every cursor fact retains FIFO order and one adjacent position/selection
  pair.
- Generic view-handler registration, nested collector depth, handler cloning,
  and view-event reentrancy are not cursor-child tests; VED-003–007/009/015 and
  VED-019–041 plus VMI-006/029–032 defer them to the render-invalidation child.

### Gate B target topology for review

1. **Movement owners.** Port the source-shaped movement functions into
   `viewer/common/view_model/cursor_move_operations.mbt` and
   `cursor_move_commands.mbt`. This is the narrow dependency seam: the local
   ViewModel already imports `viewer/common/cursor`, so view-model-dependent
   movement cannot live in the cursor package without a cycle. Preserve source
   control flow and constants inside that seam.
2. **One transition contract.** `CursorsController` validates/derives the
   model and view sides, snapshots the internal model version and old full
   cursor state, applies the new state, and returns one optional
   `CursorStateChange`. The ViewModel adapts a changed result to one outgoing
   cursor event. API, mouse, keyboard, and Flush all use this contract.
3. **Outgoing dispatcher owner.** Add the DOM-free outgoing-only port in
   `viewer/common/view_model/cursor_event_dispatcher.mbt`. It owns the emitter,
   same-kind coalescing queue, FIFO/no-op drain, and complete cursor event class
   represented by VED-001/002/008/010–014/016–018/042–060. ViewModel owns the
   dispatcher and exposes its cursor-event alias. The generic view-handler,
   nested collector, and view-event-queue half is deferred to the
   render-invalidation child at its row-local VED/VMI statuses.
4. **Reentrant delivery and Flush ordering.** The root Viewer subscribes to
   the ViewModel's cursor event and owns one FIFO plus an `is_draining` gate.
   Ordinary API/mouse/keyboard events enqueue and drain immediately. A Flush
   event enqueues source `model`, reason `ContentFlush`,
   `old_selections=None`, and old version `0` without draining. The later model
   content listener schedules the updated view, fires model-content, then
   drains. Reentrant cursor or `set_value` callbacks append to the same FIFO;
   no event can overwrite another, and each item fires position then selection
   as an adjacent pair after the view state was committed.
5. **Validation seam.** Model-driven transitions validate with `TextModel` and
   derive view state through the existing converter. View-driven movement is
   normalized in the ViewModel package before entering `CursorsController`,
   because the cursor package cannot import its owner without a cycle. Live
   mutation callers supply exactly one coordinate side, and the constructor's
   fixed origin pair is built directly. Source `ensureValidState` supplies both
   sides through COL-009 → ONE-015 → ONE-028; line-mapping revalidation does so
   independently through CUR-012 → `setStates` → ONE-016/021/028. Those rows
   defer the absent cross-validation surface. Local mapping changes
   continue their existing model-side reprojection as an ordinary reduced-seam
   test, not as source-parity evidence. Do not invent unledgered
   `validateViewRange`/`validateViewPosition` behavior.
6. **Versions, sources, and reasons.** Payload versions come only from
   `TextModel.get_version_id()`. API setters default source `api` and reason
   `NotSet`; keyboard defaults source `keyboard` and reason `Explicit`;
   pointer commands use source `mouse` and reason `Explicit`. A null,
   absent, or empty transition source falls back to exact `keyboard`.
   `old_selections` becomes `Array[Selection]?`; secondary arrays stay empty.
7. **Bound key surface.** Register the 16 primary Left/Right/Up/Down,
   PageUp/PageDown, Home/End × Shift false/true commands through the existing
   keybinding registry. A model is the command precondition. A winning command
   remains handled at document boundaries and reveals the resulting cursor;
   absent model and unmatched Alt/CtrlCmd chords fall through to the browser.
   Existing contribution-first registration order is the explicit local seam
   for source weights/context expressions: hover bindings retain precedence,
   and root keydown itself establishes text-input focus. CORE-187–196 and
   mac-only CORE-102/103/114/115 record the unimplemented alternate bindings.
8. **Approved deferral boundaries proposed to Gate B.** Atomic sticky-tab
   movement awaits an inventory of `cursorAtomicMoveOperations.ts`; visual RTL
   arrow swapping awaits a real ViewModel text-direction contract; generic JSON
   cursorMove, folded/blank-line/viewport commands, Ctrl/Cmd buffer Top/Bottom,
   multi-cursor, column selection, block double-click, editable operations, and
   platform-only alternate chords, generic view-event collection, the
   token-aware `WordOperations` algorithm, and dual-side view validation remain
   row-local DEFERRED or N-A. Ordinary LTR, sticky-false navigation and every
   required P1 event path are not deferred.
9. **Inherited relay authority.** The lifecycle child's CEW-001, CEW-015/016,
   and CEW-123–139 rows remain frozen. This child strengthens their local
   behavioral evidence but does not create duplicate source rows.

### Combined mechanical audit

- Pinned Oracle: `b18492a288de038fbc7643aae6de8247029d11bd`.
- Source rows: **802**; every active prefix ID is unique and every working
  status is `TODO`. CUR/COL/ONE/CCM/CEV/CMC/CMO/VC/CEW/VED/VMI are contiguous;
  CORE has the explicitly retired non-denominator IDs recorded above.
- Proposed map: **334 TESTED + 71 PORTED + 216 DEFERRED + 181 N-A = 802**.
- Current-MoonBit gaps and inherited lifecycle authority are recorded outside
  the denominator.
- The three source reports were normalized independently, then reconciled under
  the same atom rule. Their read-only evidence hashes are
  `f321b159…5246b`, `4eca345…bc84`, and `d8ec69b…c9074`.
- This inventory milestone changes only this child plan and its parent status;
  no product/test file changed and no runtime test was run.

Mechanical commands after assembly:

```sh
rg -c '^\| (CUR|COL|ONE|CCM|CEV|CMC|CMO|CORE|VC|CEW|VED|VMI)-[0-9]{3} \|' \
  docs/exec-plans/viewer-cursor-input-events-parity.md
# 802
rg '^\| (CUR|COL|ONE|CCM|CEV|CMC|CMO|CORE|VC|CEW|VED|VMI)-[0-9]{3} \|' \
  docs/exec-plans/viewer-cursor-input-events-parity.md | rg -vc '\| TODO \|$'
# 0
```

### Inventory review checklist — stop gate

- [ ] Reviewer confirms the 802-row denominator and active per-prefix counts:
  CUR 68, COL 49, ONE 28, CCM 50, CEV 18, CMC 156, CMO 62, CORE 186,
  VC 70, CEW 23, VED 60, VMI 32; CORE draft IDs 126–134/167 are retired,
  outside the denominator, and never reused.
- [ ] Reviewer confirms the normalized atom rule has neither umbrella rows nor
  straight-line bookkeeping rows.
- [ ] Reviewer confirms cursor configuration dependencies, inherited lifecycle
  CEW authority, the outgoing-only VED/VMI owner, and render-invalidation
  collector deferrals are closed without duplicate source rows.
- [ ] Reviewer approves the shared transition result, ViewModel outgoing
  dispatcher, reentrancy-safe Viewer FIFO, nullable old selections,
  internal-version authority, and content-barrier drain ordering; no singular
  pending result remains.
- [ ] Reviewer confirms API `NotSet` versus gesture `Explicit`, exact source
  defaults, position-before-selection delivery, view-before-outgoing ordering,
  and no-op/version gates.
- [ ] Reviewer approves every planned DEFERRED/N-A seam, especially atomic tabs,
  visual RTL, generic/buffer commands, alternate bindings, token-aware word
  selection, the ONE-015/COL-009/CUR-012 dual-side validation dependency,
  generic view collection, and
  multi-cursor/column/block/edit paths.
- [ ] Reviewer confirms the branch/configuration matrix covers all required
  keyboard, pointer, event, reentrancy, wrap, page-size (including exact zero),
  and browser-default axes and the exact-label set is 59 + 10 = 69.
- [ ] Inventory is committed separately and independently approved; only then
  may product/test work begin.

**STOP FOR REVIEW.** This document is the fixed Phase 1–2 proposal. Gate B has
not yet authorized implementation.

## Test-Authority Corrections

- Current cursor tests primarily cover public API setters and final cursor
  state. They do not prove mouse/keyboard/flush events.
- Existing scrolling tests do not establish that editor navigation keys should
  be consumed as scroll commands.
- set_value tests that assert only the reset position must add event ordering
  and internal version facts.

### Cursor child implementation test matrix

Oracle: `vscode` at `b18492a288de038fbc7643aae6de8247029d11bd`.

Authority rule: a test copied/adapted from either named VS Code file must retain its exact upstream label, source path, and pin in a `*_reference_test.mbt`/`*_reference_wbtest.mbt` file. Viewer event-spine, DOM-key, real-pointer, focus, and default-prevention tests are ordinary integration/browser tests because no exact case for those observable seams exists in the two named sources.

Selected exact-label port set: **69 tests** — 59 from `cursor.test.ts` and 10 from `cursorMoveCommand.test.ts`. Deferred sibling clusters are listed explicitly rather than being silently omitted.

#### Recommended test ownership

| Test artifact | Role |
|---|---|
| `viewer/common/view_model/cursor_reference_wbtest.mbt` | Exact-label ports from `cursor.test.ts` for movement state, wrapping, Home/End, and low-level outgoing cursor state. White-box ownership is required because the new move operations are private in `view_model`. |
| `viewer/common/view_model/cursor_move_command_reference_wbtest.mbt` | Exact-label ports from `cursorMoveCommand.test.ts` for `simpleMove` count/unit routing. |
| `viewer/cursor_reference_wbtest.mbt` | Exact-label ports whose seam is the root Viewer facade: source propagation, public setters, selected word/line adapters, and set-value reset. Splitting the upstream file is justified by package ownership; both files must name the same source path/pin and the subset they own. |
| `viewer/cursor_transition_wbtest.mbt` | Ordinary source-derived integration matrix for public event order, internal version IDs, source/reason, keyboard/mouse/API convergence, and ContentFlush. Do not give these invented tests upstream labels. |
| `tests/browser/component/cursor_input_events.spec.js` plus a dedicated MoonBit component scenario | Real keydown/pointer/default-prevention/focus/visible-selection checks. A dedicated scenario should expose recorded public cursor events and controlled model/set-value operations. |
| `tests/browser/smoke/mouse_selection.spec.js` | Retain its existing clipboard/real-gesture checks; extend only for gesture variants that need no event recorder. |

#### Exact upstream ports: `cursor.test.ts`

Source: `vscode/src/vs/editor/test/browser/controller/cursor.test.ts`.

##### Absolute move and validation — port verbatim

| Exact upstream label | Lines | Why applicable |
|---|---:|---|
| `cursor initialized` | 149-153 | Initial collapsed origin. |
| `no move` | 157-162 | Exact-state no-op. |
| `move` | 164-169 | Plain MoveTo/click transition. |
| `move in selection mode` | 171-176 | Shift-click/drag extension. |
| `move beyond line end` | 178-183 | Model validation/clamp. |
| `move empty line` | 185-190 | Empty line exact column 1. |
| `move one char line` | 192-197 | One-character max column. |
| `selection down` | 199-204 | Multiline extension. |
| `move and then select` | 206-217 | Anchor survives forward then backward extension. |

##### Left/Right — port verbatim

| Exact upstream label | Lines | Boundary |
|---|---:|---|
| `move left on top left position` | 221-226 | BOF no-op. |
| `move left` | 228-235 | Same-line one UTF-16 step. |
| `move left with surrogate pair` | 237-244 | Do not split a surrogate pair. |
| `move left goes to previous row` | 246-253 | Line-start -> previous max column. |
| `move left selection` | 255-262 | Shift+Left across line boundary. |
| `move right on bottom right position` | 266-273 | EOF no-op. |
| `move right` | 275-282 | Same-line one UTF-16 step. |
| `move right with surrogate pair` | 284-291 | Do not split a surrogate pair. |
| `move right goes to next row` | 293-300 | Line-end -> next min column. |
| `move right selection` | 302-309 | Shift+Right across line boundary. |

##### Up/Down, tabs, visible-column residue, wrapping — port verbatim

| Exact upstream label | Lines | Matrix fact |
|---|---:|---|
| `move down` | 313-326 | Empty/short/final lines and last-position behavior. |
| `move down with selection` | 328-341 | Shift+Down through all boundaries. |
| `move down with tabs` | 343-356 | Tab-expanded visible columns. |
| `move up` | 360-371 | Shorter target line and leftover preservation. |
| `move up with selection` | 373-384 | Shift+Up anchor preservation. |
| `move up and down with tabs` | 386-404 | Round-trip visible columns across tabbed/empty lines. |
| `move up and down with end of lines starting from a long one` | 406-426 | Sticky leftover at shorter line ends. |
| `issue #44465: cursor position not correct when move` | 428-447 | First edge hit remembers leftover; second edge hit clears it. |
| `issue #144041: Cursor up/down works` | 449-498 | Wrapped-line progress with wrapping indent. |
| `issue #140195: Cursor up/down makes progress` | 500-563 | Injected text plus wrapping must not stall vertical movement. |

##### Home/End and Shift variants — port verbatim

Home labels/ranges:

| Exact upstream label | Lines |
|---|---:|
| `move to beginning of line` | 567-574 |
| `move to beginning of line from within line` | 576-584 |
| `move to beginning of line from whitespace at beginning of line` | 586-594 |
| `move to beginning of line from within line selection` | 596-604 |
| `move to beginning of line with selection multiline forward` | 606-613 |
| `move to beginning of line with selection multiline backward` | 615-622 |
| `move to beginning of line with selection single line forward` | 624-631 |
| `move to beginning of line with selection single line backward` | 633-640 |
| `issue #15401: "End" key is behaving weird when text is selected part 1` | 642-649 |
| `issue #17011: Shift+home/end now go to the end of the selection start's line, not the selection's end` | 651-658 |

End labels/ranges:

| Exact upstream label | Lines |
|---|---:|
| `move to end of line` | 662-669 |
| `move to end of line from within line` | 671-679 |
| `move to end of line from whitespace at end of line` | 681-689 |
| `move to end of line from within line selection` | 691-699 |
| `move to end of line with selection multiline forward` | 701-708 |
| `move to end of line with selection multiline backward` | 710-717 |
| `move to end of line with selection single line forward` | 719-726 |
| `move to end of line with selection single line backward` | 728-735 |
| `issue #15401: "End" key is behaving weird when text is selected part 2` | 737-744 |

These are Home/End command semantics, unlike the raw `WrappedLineStart`/`WrappedLineEnd` tests in `cursorMoveCommand.test.ts`. Preserve this distinction.

##### Selection, eventing, source, flush, and pointer-command semantics — port verbatim

The selected word cases below are conformance and event-routing evidence for
the existing local word seam. They do not make CMC-033 `TESTED`, do not
inventory `cursorWordOperations.ts`, and cannot support a whole-unit word
parity claim. Full word parity requires a separate Phase 1 inventory of that
868-line source unit.

| Exact upstream label | Lines | Owner/expectation |
|---|---:|---|
| `select all` | 830-835 | Root/view-model reference test; whole document and trailing max column. |
| `no move doesn't trigger event` | 839-848 | Equality gate. |
| `move eventing` | 850-863 | One outgoing cursor-state event with collapsed selection. |
| `move in selection mode eventing` | 865-878 | One outgoing event with ranged selection. |
| `setSelection / setPosition with source` | 1332-1363 | Root facade; exact caller source propagation. |
| `issue #33788: Wrong cursor position when double click to select a word` | 2462-2476 | Word initial/drag selection. |
| `issue #12887: Double-click highlighting separating white space` | 2478-2489 | Word boundary after whitespace. |
| `issue #23983: Calling model.setValue() resets cursor position` | 2568-2586 | Exact upstream ContentFlush state reset. Metadata/order remain ordinary tests below. |
| `issue #7100: Mouse word selection is strange when non-word character is at the end of line` | 6105-6130 | Collapsed punctuation then cross-line word drag. |
| `issue #112039: shift-continuing a double/triple-click and drag selection does not remember its starting mode` | 6132-6150 | MoveToSelect dispatches by stored Word/Line kind. |
| `issue #158236: Shift click selection does not work on line number indicator` | 6152-6170 | Gutter line-select drag. |

##### Explicit scoped SKIPPED markers

- `move to beginning of buffer*` and `move to end of buffer*`, lines 748-826: SKIPPED under current D5 command boundary (Ctrl/Cmd+Home/End not part of the bound Home/End child surface). Name every label in the reference file if this cluster is copied.
- `grapheme breaking`, lines 939-976: SKIPPED with the current cursor capability reason. The required surrogate-pair cases above still port; this broader test includes combining/variation-selector/Tamil grapheme behavior beyond the present contract.
- `Double-click on punctuation should select the character, not adjacent space`, lines 2491-2523: SKIPPED under CMC-033/D6. Its `//` token-boundary assertion requires the unscoped token-aware `cursorWordOperations.ts`; the current local seam intentionally selects one punctuation code unit.
- Editing, undo, typing, paste, composition, multicursor, and column-selection suites are outside the readonly source cluster, not omitted reference cases.

#### Exact upstream ports: `cursorMoveCommand.test.ts`

Source: `vscode/src/vs/editor/test/browser/controller/cursorMoveCommand.test.ts`.

##### Port verbatim

| Exact upstream label | Lines | Why |
|---|---:|---|
| `move left should move to left character` | 34-40 | SimpleMove Left. |
| `move left should move to left by n characters` | 42-48 | `value > 1` pre-offset/clip. |
| `move left moves to previous line` | 58-64 | Large value plus previous-line boundary. |
| `move right should move to right character` | 66-72 | SimpleMove Right. |
| `move right should move to right by n characters` | 74-80 | `value > 1`. |
| `move right moves to next line` | 90-96 | Large value plus next-line boundary. |
| `move up by cursor move command` | 226-237 | Wrapped-line count and BOF clamp. |
| `move up with selection by cursor move command` | 265-276 | Counted Shift+Up. |
| `move up and down with tabs by cursor move command` | 278-298 | Tab visible-column round trip. |
| `move up and down with end of lines starting from a long one by cursor move command` | 300-320 | Leftover-visible-column arithmetic. |

##### Explicit scoped SKIPPED markers

- `move left should move to left by half line` (50-56) and `move right should move to right by half line` (82-88): D1 HalfLine is unbound/deferred.
- Raw wrapped-position cases at 98-224: D1 generic `cursorMove`; they are not substitutes for Home/End.
- `move up by model line cursor move command` (239-250) and `move down by model line cursor move command` (252-263): D1 model-line unit.
- Viewport-placement tests 322-419, blank-line tests 422-507, and foldedLine tests 512-615: D1 generic directions. Preserve exact SKIPPED labels if their source cluster is represented.

#### PageUp/PageDown authority correction

Neither `cursor.test.ts` nor `cursorMoveCommand.test.ts` contains `PageUp`, `PageDown`, `CursorPage*`, or page-size tests. Therefore:

- do not invent an upstream/reference label for PageUp/PageDown;
- use the ported counted-up/down tests only as evidence for `simpleMove(... WrappedLine, value=pageSize)`;
- add ordinary source-derived tests for the page-size marker/dynamic fallback and keybinding dispatch.

Ordinary Page matrix:

| Axis | Cases |
|---|---|
| Direction | PageUp / PageDown |
| Selection | Shift false / true |
| Dynamic page argument | omitted / exact `0` fallback / positive override |
| Viewport | one-line/tiny, short, tall; page size recomputed from each configuration |
| Cursor position | middle, within one page of BOF/EOF, exact BOF/EOF |
| Content | normal lines, empty target, wrapped continuations |
| Assertions | exact final model/view selection, leftover column, handled=true, browser default prevented, focus retained; cursor moves rather than substituting viewport scroll |

#### Ordinary transition/event matrix (not reference-labeled)

All state-changing entry points must call the same transition helper and satisfy this table:

| Entry | Source | Reason | Old/new internal version | Event order |
|---|---|---|---|---|
| `set_position` / `set_selection` | `api` | `NotSet` | current/current | internal view state/render invalidation, position event, selection event |
| navigation keys | `keyboard` | `Explicit` | current/current | internal view state/render invalidation, position, selection |
| click/drag/double/triple/gutter | `mouse` | `Explicit` | current/current | internal view state/render invalidation, position, selection |
| SelectAll, including four-click mouse dispatch | `keyboard` | `Explicit` | current/current | internal view state/render invalidation, position, selection |
| `set_value` Flush | `model` | `ContentFlush` | exact `0` -> post-flush internal version | public model-content event, then cursor position, then cursor selection; internal view cursor state was already updated before public callbacks |

Required facts:

1. Construct a model whose host metadata `version` is deliberately different (for example 73) from `get_version_id()` (initially 1). Every cursor-selection event must use the internal ID, never host `model.version`.
2. API/keyboard/mouse events retain the same internal old/new ID because content did not change; `old_selections` contains the prior primary selection.
3. Flush increments internal version (normally 1 -> 2), reports `old_model_version_id=0` and `old_selections=None` because upstream passes `oldState=null`, source `model`, reason `ContentFlush`, position/selection `(1,1)`.
4. Flush at an already-collapsed origin still emits the cursor event pair: model version/flush reason changed even though the visible selection did not.
5. Exact-state API, key-at-hard-boundary, and repeated same-point click paths emit nothing. No-op must also avoid an extra render invalidation.
6. Each changed transition emits position before selection exactly once. A drag can produce multiple changed transitions, but each update is a coherent adjacent pair; mouseup adds no duplicate pair.
7. In each public callback, `get_position`, `get_selection`, model/view cursor state, and rendered-selection input already agree with the payload.
8. A position listener that triggers another cursor transition cannot interleave the later pair: first-position, first-selection, second-position, second-selection.
9. A model-content listener that calls `set_value` reentrantly retains both Flush cursor facts in FIFO order; no singular pending slot is overwritten.

Suggested ordinary white-box labels:

- `cursor transition metadata uses internal model version for api keyboard and mouse`
- `cursor transition fires position before selection after view state commit`
- `exact cursor state is a render and public event no-op`
- `ContentFlush emits content then position then selection with model source and internal version`
- `ContentFlush at origin still emits because the model generation changed`
- `cursor delivery FIFO keeps reentrant position and selection pairs adjacent`
- `reentrant ContentFlush retains every queued cursor fact`

#### Ordinary keyboard/browser matrix

Run real `KeyboardEvent`s against the focused `.monaco-editor.readonly-editor` root (`tabindex=0`):

| Keys | Shift=false | Shift=true | Browser facts |
|---|---|---|---|
| ArrowLeft / ArrowRight | collapse/move one valid UTF-16 character, crossing model lines | extend selection | handled events are `defaultPrevented`; focus stays on editor root |
| ArrowUp / ArrowDown | move by wrapped view line with leftover preservation | extend selection | no viewport-scroll substitution; visible caret/selection equals public events |
| PageUp / PageDown | move by computed page size | extend by page size | tiny/tall viewport configurations; clamp at boundaries |
| Home / End | indentation toggle / line or wrapped-line end | extend to same target | empty, indented, first/final wrapped segment |

Negative controls:

- an unbound key and one demonstrably unregistered modified chord (selected after checking the platform keybinding map) are not default-prevented;
- a handled navigation key remains default-prevented even when it is a hard-boundary cursor no-op;
- `document.activeElement` remains the root before and after every handled key;
- focus/blur rendering state does not flap during navigation.

#### Ordinary real-pointer/browser matrix

| Gesture | Required assertions |
|---|---|
| Single click | collapses at hit-tested position; root receives/retains focus; paired public events have mouse/Explicit. |
| Drag | anchor fixed, active follows pointer across same line, model line, and wrapped continuation; visible overlay and public selection agree. |
| Double click | selected-case word and one-code-unit punctuation selection; stored kind Word; subsequent Shift-click/drag preserves word boundaries. The `//` token-aware case remains the explicit CMC-033/D6 skip. |
| Triple click | whole logical model line including trailing newline; stored kind Line; forward/backward/equal-anchor continuation. |
| Gutter click / Shift-gutter drag | whole-line selection and `issue #158236` behavior. |
| Four clicks / select-all | `(1,1)` through final max column, visible overlay and clipboard agree; preserve the source's hard-coded `keyboard`/`Explicit` metadata even for four-click dispatch. |
| No-op click | same exact state emits no public events. |

#### Current local evidence and gaps

| Existing test | Current evidence | Still missing for this child |
|---|---|---|
| `viewer/cursor_behavior_wbtest.mbt:11-65` | MoveTo collapse/extend and model/view identity. | Arrow/Page/Home/End, sources/reasons, shared transition path. |
| `viewer/cursor_behavior_wbtest.mbt:71-121` | API set position/selection, direction, clamp, surrogate validation. | Event metadata/order and internal-vs-host version. |
| `viewer/cursor_behavior_wbtest.mbt:127-155` | Repeated identical API selection fires no public events. | Render no-op, keyboard/mouse no-op, exact payload fields/order. |
| `viewer/cursor_behavior_wbtest.mbt:163-231` | Wrapped projection/reflow. | Wrapped navigation branches and leftover columns. |
| `viewer/common/cursor/single_cursor_state_test.mbt:7-43` | Collapse, extension, backward Word anchor shape. | Vertical leftovers and source-shaped movement operations. |
| `viewer/set_value_api_wbtest.mbt:53-59` | Public set_value resets cursor to origin. | ContentFlush cursor events, metadata, order, origin-still-emits. |
| `viewer/common/view_model/set_value_flush_test.mbt:32-59` | View models update before public content callback; flush resets cursor. | Outgoing model-content -> position -> selection sequence and internal version IDs. |
| `tests/browser/smoke/mouse_selection.spec.js:21-87` | Real double, triple, and gutter click via clipboard. | Single click, Shift continuation, select-all, event payload/order/focus. |
| `tests/browser/smoke/selection_geometry.spec.js:29-250` | Real same/multiline drag and visible overlay geometry. | Public cursor event coherence/source/reason and no duplicate mouseup. |
| `tests/browser/component/viewer_api.spec.js:87-110` | Real wrapped drag and collapse click. | Event recorder and navigation keys. |
| `tests/browser/component/model_swap.spec.js:7-81` | Focus carries across model swap. | Focus retention during key/pointer navigation. |
| `tests/browser/component/scroll_animation.spec.js:18-57` | Wheel default prevention only. | No cursor-key default-prevention test exists today. |

Bottom line: the local suite already proves state basics and visible mouse selection, but currently has **zero direct keyboard-navigation cases**, **zero cursor-key default-prevention cases**, and **no ContentFlush/API/mouse/keyboard event metadata-and-order matrix**.

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
- reentrant cursor listeners and reentrant `set_value` retain FIFO order and
  adjacent position/selection pairs;
- `set_selections([primary])` forwards primary/source/reason exactly;
  `set_selections([primary, secondary])` intentionally retains only primary,
  emits empty secondary arrays, and keeps API `api`/`NotSet` metadata;
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

Gate B must explicitly approve these seam-based deviations before
implementation:

- The single-cursor public `set_selections` API keeps `ranges[0]` and drops
  `ranges[1..]`; CEW-023/VMI-021 and the ordinary matrix above make the
  observable reduction explicit. Every emitted secondary array remains `[]`.
- The local keybinding registry uses contribution-first registration order and
  the focused root keydown boundary in place of numeric `CORE_WEIGHT` and a
  stored `textInputFocus` expression. Required primary bindings are tested;
  CORE-187–196 and CORE-102/103/114/115 defer alternate/platform-only and
  command-metadata surfaces.
- This child ports only the outgoing/cursor half of
  `ViewModelEventDispatcher`; generic view handlers, nested collectors, and
  view-event queues remain with the render-invalidation child. The root
  cursor-delivery FIFO is the local content-barrier/reentrancy seam.
- Live cursor transitions supply exactly one coordinate side. ViewModel
  normalizes view inputs and TextModel validates model inputs. The fixed origin
  constructor is direct. COL-009/ONE-015 reach ONE-028 through
  `ensureValidState`; CUR-012 reaches it separately through `setStates` and
  ONE-016/021. All defer the absent source path that cross-validates
  simultaneously supplied model and view states. Local mapping reflow remains
  model-side reprojection and is not claimed as parity at ambiguous
  wrap/injected-text mappings.
- CMC-033's token-aware `WordOperations` algorithm remains unscoped. Selected
  word cases are regression/routing evidence only, and the `//` punctuation
  case is an explicit exact-label skip.
- `CursorStateChanged` is a semantic MoonBit variant; source enum value `7` is
  recorded and tested as source evidence but has no local numeric ABI.

Editable commands, multi-cursor, column selection, and middle-button behavior
remain row-local deferred/N-A boundaries.

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

### 2026-07-10 — normalized Phase 1–2 inventory milestone

- Verified the read-only Oracle at
  `b18492a288de038fbc7643aae6de8247029d11bd` and reread every closed source
  file/cluster named above.
- Fixed the source denominator at **799/799 TODO rows** under the uniform atom
  rule: CUR 68, COL 49, ONE 27, CCM 50, CEV 18, CMC 154, CMO 62, CORE 186,
  VC 70, CEW 23, VED 60, and VMI 32.
- Reconciled the proposed terminal map at 361 TESTED, 81 PORTED, 176 DEFERRED,
  and 181 N-A. Inherited lifecycle CEW rows and the current-local gap audit do
  not inflate the denominator.
- Mechanical checks found no missing/duplicate prefix ID, no non-TODO source
  status, and no Markdown whitespace error. Only this child plan and the parent
  coordination status changed; no product/test file changed and no runtime
  test was run.
- Stopped before implementation. The inventory commit and its file hash must
  be recorded by the later independent Gate B approval entry.

### 2026-07-10 — first Gate B rejection and inventory amendment

- The documentation-only inventory commit is
  `7c0a3b340333c7dcc35c12140fb53ef23849b914`; its committed child-plan
  SHA-256 is
  `d41162d2a03d4e50086630e4bb83dba69e8c8775466eec5be4967694c1198df9`.
- Three independent reviews rejected Gate B before product work. Confirmed
  defects were two collapsed `simpleMove` callbacks, out-of-scope
  scroll/reveal umbrella rows, mixed primary/alternate registration
  dispositions, an unsafe singular Flush result, generic collector rows with
  no owner, an omitted `pageSize=0` fallback, inaccurate selection/indent
  facts, absent dual-side validation, and one unimplementable token-aware exact
  word test.
- The amendment has **802/802 TODO rows**: cursor state/event 213, movement
  218, and browser/public/event 371. Its recomputed proposal is **337 TESTED,
  71 PORTED, 213 DEFERRED, and 181 N-A**.
- The target now names an outgoing-only ViewModel cursor dispatcher and a
  reentrancy-safe Viewer delivery FIFO; generic view collection stays with the
  render-invalidation child. Required bindings remain the 16 primary keys,
  while every alternate/platform fact is row-local deferred. The exact-label
  set is 59 + 10 = 69 with the token-aware `//` case explicitly skipped.
- No product/test file changed and no runtime test ran. Implementation remains
  forbidden until a fresh independent Gate B re-review approves this amended
  document and the amendment itself is committed.

### 2026-07-10 — second Gate B rejection and validation amendment

- The first amendment commit is
  `805dad49b61df087bdf27810e3b6145dec5b46e0`; its committed child-plan
  SHA-256 is
  `11d61984838e710f0bc3823051755d2920162c03c3f48e241082936822ac57fb`.
- Fresh browser/public/event and cursor-core rereads passed, but the independent
  design review rejected ONE-015/COL-009/CUR-012: source reflow passes both
  model and view state into ONE-028's `validateViewRange`/
  `validateViewPosition` branch. Model-only reprojection is not equivalent at
  ambiguous wrap/injected-text mappings.
- The second amendment keeps **802/802 TODO rows** and corrects the source
  ranges to ONE-027 `:146-152` and ONE-028 `:153-158`. ONE-015, COL-009, and
  CUR-012 now defer with their absent dual-side converter dependency. The
  recomputed map is **334 TESTED, 71 PORTED, 216 DEFERRED, and 181 N-A**.
- No product/test file changed and no runtime test ran. Product implementation
  remains forbidden until this correction is committed and a final fresh Gate
  B review passes.
