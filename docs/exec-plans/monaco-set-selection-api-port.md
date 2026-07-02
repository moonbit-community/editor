# Monaco `setPosition`/`setSelection` (Single-Selection) 1:1 Port

Status: landed — Date: 2026-07-02 (implemented 2026-07-02). Oracle commit: `294fb350837dbaee37b949533fead4df4e0e8971`.

Follows `_PORT_PLAYBOOK.md` (inventory-first; copy don't invent; exit gate).

## Problem

The viewer's cursor surface is read-only: `Viewer::get_position` / `get_selection`
/ `get_selections` (`viewer/public_read_api.mbt:195-227`) exist, but nothing lets
an embedder *set* the selection. Monaco's reveal family (`viewer/reveal.mbt`) is
confirmed to be pure scroll — it never selects — and Monaco's own features (Find,
Go to Line/Symbol, Go to Definition) compose `setSelection`/`setPosition` with
`revealRange*` as two separate calls (`findModel.ts:258-259`,
`editorNavigationQuickAccess.ts:144-146`, `goToCommands.ts:792-793`). This plan
ports the missing half of that pair: the single-selection mutators.

## Scope (Phase 0)

Source unit: the **single-selection `setPosition`/`setSelection` cluster** of
`vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts`, plus its
backing chain through `common/viewModel/viewModelImpl.ts` →
`common/cursor/cursor.ts` (`CursorsController`) → `common/cursorCommon.ts`
(`CursorState`) → `common/cursor/oneCursor.ts` (`Cursor`).

### Out of scope (named sibling clusters — explicitly **not** this port)

- **`setSelections(ranges[], source, reason)`** (cew:948-961) — the multi-cursor
  array entry point. This repo's `CursorsController` holds exactly one `Cursor`
  by deliberate design (`viewer/common/cursor/cursors_controller.mbt:3-6`:
  "Multi-cursor is a deliberate omission"). Porting the array signature without
  backing multi-cursor state would misrepresent capability — deferred until
  multi-cursor storage is a scoped goal.
- **`reachedMaxCursorCount` warning + notification prompt**
  (`cursor.ts:117-123`, `codeEditorWidget.ts:1815-1833`) — N/A, no multi-cursor,
  no notification service in the viewer.
- **`CursorChangeReason` values beyond the explicit-API-call case** (`Paste`,
  `Undo`, `Redo`, `RecoverFromMarkers`, `CompositionEnd`, arrow-key `Explicit`)
  — these are set by editing/undo/typing commands that don't exist in a readonly
  viewer. Only the "explicit external call" path is in scope.
- **Marker-tracked-range machinery** (`oneCursor.ts` `_updateTrackedRange`,
  `_selTrackedRange`) — already a documented prior deviation
  (`viewer/common/cursor/cursor.mbt:6-9`: the immutable readonly model drops
  Monaco's marker-tracking since positions never need to survive an edit).
  Not re-litigated here.
- **Reveal composition** — `setPosition`/`setSelection`/`setSelections` never
  call `revealRange*` internally in Monaco (confirmed: no such call in
  `codeEditorWidget.ts:670-961`). This port must not add one either; a caller
  wanting "select and scroll into view" composes `set_selection(...)` +
  `reveal_range(...)`, mirroring Monaco's own `gotoLocation` pattern.

## Inventory (Phase 1) — the denominator

Full member list of the scoped cluster, read at the oracle commit:

1. `setPosition(position, source='api')` — `codeEditorWidget.ts:670-682`
2. `setSelection` (5 TS overload signatures + 1 implementation) —
   `codeEditorWidget.ts:797-822`
3. `_setSelectionImpl(sel, source)` (private) — `codeEditorWidget.ts:824-830`
4. `onDidChangeCursorPosition` (Emitter decl + fire site) —
   `codeEditorWidget.ts:117-118`, `:1836-1845`
5. `onDidChangeCursorSelection` (Emitter decl + fire site) —
   `codeEditorWidget.ts:120-121`, `:1846-1857`
6. `ViewModel.setSelections(source, selections, reason)` —
   `viewModelImpl.ts:1185-1187`
7. `CursorsController.setSelections(eventsCollector, source, selections, reason)`
   — `cursor.ts:309-311`
8. `CursorsController.setStates(eventsCollector, source, reason, states)` —
   `cursor.ts:118-134`
9. `CursorsController._emitStateChangedIfNecessary(...)` (equality-gated event
   fire, excluding the `reachedMaxCursorCount` branch) — `cursor.ts:403-425`
10. `CursorState.fromModelSelection(modelSelection)` — `cursorCommon.ts:283-289`
11. `CursorState.fromModelSelections(modelSelections)` — `cursorCommon.ts:292-298`
12. `Cursor.setState(context, modelState, viewState)` — `oneCursor.ts:78-80`
13. `Cursor._validateViewState(viewModel, viewState)` (static) —
    `oneCursor.ts:91-113`
14. `Cursor._setState(context, modelState, viewState)` — `oneCursor.ts:114-157`,
    **model-state-provided branch only** (`else` at `:133-142` + the
    view-derive `if (!viewState)` branch at `:144-150`). The
    view-state-provided branch (`:118-131`) is already ported and exercised by
    `move_to`/`set_view_state` — reused, not re-ported.

Member count: **14** in-scope.

### Behavior-switching branches to cover (→ test cases)

1. **`setPosition` builds a collapsed selection** — `selectionStart == position`
   (`cew:677-681`).
2. **`setSelection` accepts anchor-preserving input** — `selectionStart` and
   `position` may be given in either order (backward selection), and the
   resulting `Selection.getDirection()` must reflect it (`cursorCommon.ts:283-289`
   → `SingleCursorState.selection()`, already ported at
   `single_cursor_state.mbt:63-72`).
3. **Position/range clamped to the model** — out-of-range line, out-of-range
   column, mid-surrogate column (`oneCursor.ts:133-141`: `validateRange` on the
   anchor, `validatePosition` on the active end).
4. **No-op when the state doesn't change** — setting the exact current selection
   fires no event (`cursor.ts:404-406`: `newState.equals(oldState)` short-circuit).
5. **Event fires when the state does change**, carrying the new model selection
   (`cursor.ts:415-421`).
6. **View state re-derived through the coordinates converter** — with word-wrap
   on, the view selection differs from the model selection
   (`oneCursor.ts:144-150`: `convertModelPositionToViewPosition`).
7. **No model attached** — mirrors every other mutator's guard
   (`codeEditorWidget.ts:671-673`: `if (!this._modelData) return`).

## Parity ledger (Phase 2)

New public methods live in `viewer/selection.mbt` (already the file owning
`Viewer`'s cursor/selection glue — `ensure_cursor`, `get_rich_text_to_copy`,
the clipboard path). No changes to `CursorsController`/`CursorContext`/`Cursor`
are needed: validation happens at the `Viewer` boundary (which holds
`self.text_model`), then the existing `set_model_cursor_state` does the
view-derive that was already ported for `move_to`'s sibling path.

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `setPosition` (cew:670) | no model → no-op; else collapsed selection `{start: position, end: position}` → routes to the selection path | `Viewer::set_position` | DONE |
| `setSelection` + `_setSelectionImpl` (cew:797-830) | no model → no-op; normalize input to `(selectionStart, position)`, validate, set | `Viewer::set_selection` | DONE |
| `ViewModel.setSelections` (vmi:1185) | pass-through to controller | inlined into `Viewer::set_selection` (no separate ViewModel-layer symbol exists in this port) | DONE |
| `CursorsController.setSelections`/`setStates` (cursor.ts:309,118-134) | snapshot old state → set new state → emit-if-changed | inlined into `Viewer::set_selection` (old-state snapshot via `controller.model_state()`) | DONE |
| `CursorState.fromModelSelection(s)` (cursorCommon.ts:283-289) | `Selection.liftSelection(s)` → `SingleCursorState(Range.fromPositions(selectionStart), Simple, 0, position, 0)` | build `SingleCursorState::new(selection.selection_start, selection.selection_start, Simple, selection.position)` directly (the readonly viewer has no `leftoverVisibleColumns`, already a standing omission — `single_cursor_state.mbt:20-22`) | DONE |
| `_validateViewState` (oneCursor.ts:91-113) | N-A for this path — only applies to the view-state-provided branch, which this port doesn't take (input is always model-coordinate) | N-A | N-A (out of branch) |
| `_setState` model-branch (oneCursor.ts:133-150) | `validateRange(selectionStart)`, `validatePosition(position)`, then derive view state via the converter | `TextSnapshot::validate_range` / `validate_position` (already ported, `text_snapshot.mbt:277-300`) + existing `CursorsController::set_model_cursor_state` (`cursors_controller.mbt:59-64`) → `Cursor::set_model_state` (`cursor.mbt:49-...`) | DONE (wiring only — both halves already existed) |
| `_emitStateChangedIfNecessary` equality gate (cursor.ts:404-406) | `newState.equals(oldState)` → skip event | compare `SingleCursorState` before/after via its `derive(Eq)` | DONE |
| `_emitStateChangedIfNecessary` event fire (cursor.ts:415-421) | fire position + selection events with the new state (source/reason/versionId dropped — see Deviations) | new `Viewer.did_change_cursor_position` / `did_change_cursor_selection` emitters, `.fire(...)` in `Viewer::set_selection` | DONE |
| `onDidChangeCursorPosition` (cew:117-118, fire :1836) | subscribe surface | `Viewer::on_did_change_cursor_position` | DONE |
| `onDidChangeCursorSelection` (cew:120-121, fire :1846) | subscribe surface | `Viewer::on_did_change_cursor_selection` | DONE |
| no-model guard (cew:671-673, 803 implicit via `_modelData`) | no-op, no event | `guard self.text_model is Some(_) else { return }` in both setters | DONE |

Member count: 14 inventory members → 11 ledger rows (3 backing members collapse
1:1 into the `Viewer::set_selection` body rather than getting a separate MoonBit
symbol, matching how the read-API port inlined thin one-line delegations).

## Deviations (Phase 3)

- **5 TS overloads collapse to 1 typed parameter.** Monaco's `setSelection`
  accepts `IRange | Range | ISelection | Selection` and runtime-normalizes them
  (`cew:797-822`, `Selection.isISelection`/`Range.isIRange` checks). MoonBit's
  `@view_model.Selection` (`selection.mbt:21-24`) already *is* the anchor+active
  shape Monaco normalizes down to, so `Viewer::set_selection` takes exactly that
  one type. A caller with a plain (non-directional) range builds
  `Selection::from_positions(range.start, range.end)` themselves — no behavior
  is lost, the overload resolution is just done by the type system instead of a
  runtime `instanceof` chain.
- **Runtime "Invalid arguments" throws are N/A.** `Position.isIPosition` /
  `Range.isIRange` / `Selection.isISelection` (`cew:673-675`, `:805-807`,
  `:952-957`) guard against malformed *JS* values reaching a loosely-typed API.
  MoonBit's typed parameters make malformed shapes a compile error, not a
  runtime one — nothing to port.
- **`source`/`reason`/`CursorChangeReason` dropped.** No caller in this repo
  distinguishes selection-change causes yet (no command service, no undo/redo
  stack touching cursor state — confirmed no `CursorChangeReason` symbol exists
  anywhere in the repo). Add a `source` parameter later if a real caller needs
  to distinguish it; inventing the plumbing now with no consumer would violate
  the no-speculative-abstraction rule.
- **`modelVersionId`/`oldModelVersionId` dropped from the fired events.** These
  track incremental edits in Monaco's mutable model; this viewer's model is
  swapped wholesale via `set_model` (a new `TextModel` object), never edited
  in place, so there is no version counter to report. Same category as the
  existing `getValue` BOM/EOL deviation in the read-API port.
  `did_change_cursor_position`/`did_change_cursor_selection` events accordingly
  carry only `position`/`selection` (no secondary arrays — see next point).
- **No `secondaryPositions`/`secondarySelections`.** Multi-cursor is out of
  scope (see above); the fired events have no secondary-cursor fields, matching
  `get_selections`' existing 1-element-array deviation
  (`public_read_api.mbt:219-221`).
- **`leftoverVisibleColumns` stays `0`/absent.** Already a standing omission for
  the whole `SingleCursorState` port (`single_cursor_state.mbt:20-22`: "no
  readonly mouse-selection role... omitted until keyboard navigation lands"),
  not reopened by this plan.

No layout/geometry/timing math is invented: validation is the existing
`TextSnapshot::validate_range`/`validate_position` (already a 1:1 port of
Monaco's `validateRange`/`validatePosition`), and view-state derivation is the
existing `Cursor::set_model_state` (already a 1:1 port of `_setState`'s
model-branch). This plan's own code is the `Viewer`-level glue: old-state
snapshot, validate, call, diff, emit.

## Test matrix (Phase 4)

Behavior-switching variables: **input order** {forward, backward-selecting} ×
**validity** {in-range, out-of-range line, out-of-range column, mid-surrogate
column} × **change** {no-op (same selection), actual change} × **word-wrap**
{off, on}.

Headless (`with_test_viewer`, extend `viewer/cursor_behavior_wbtest.mbt` — it
already hosts the semantic cursor/selection suite alongside `move_to`):

1. `set_position` collapses the selection at the given point; `get_selection()`
   reflects it immediately.
2. `set_selection` with anchor-before-active vs anchor-after-active — assert
   `Selection::direction()` is `LTR`/`RTL` respectively (covers branch 2).
3. `set_selection` with a line number past EOF, a column past line-end, and a
   column splitting a surrogate pair — assert the stored selection is the
   clamped/adjusted result, not the raw input (covers branch 3; reuse the same
   surrogate fixture `TextSnapshot::validate_position`'s own tests use).
4. Setting the exact current selection twice — assert
   `on_did_change_cursor_selection`/`on_did_change_cursor_position` fire on the
   first call and **not** on the second identical call (covers branch 4 & 5).
5. `set_selection` on a wrapped line — assert the *model* selection returned by
   `get_selection()` is unchanged while the view-coordinate selection consumed
   by the selection overlay (`Viewer::selection_view_range`,
   `viewer/selection.mbt:8-22`) differs, proving the view state was actually
   re-derived through the converter (covers branch 6).
6. No model attached — `set_position`/`set_selection` are no-ops, no event
   fires (covers branch 7).

No browser-only behavior here (no DOM measurement involved) — headless suite is
sufficient, consistent with `move_to`'s existing tests in the same file.

## Exit gate (Phase 5)

- [x] inventory reconciled (rows == members): done/deferred/N-A = 13/0/1 of 14
- [x] every ported fn diff-reviewed vs its cited source line
- [x] matrix covered (branches 1-7), `just test` green (561 js / 523 native)
- [x] deviations above confirmed accurate; no uncited geometry/validation line
- [x] closing self-audit: re-read `codeEditorWidget.ts:670-961` +
      `cursor.ts:118-134,309-425` + `oneCursor.ts:78-157`; reconciliation
      pasted here

### Reconciliation (closing self-audit, 2026-07-02)

Landed code: `viewer/selection.mbt` (`Viewer::set_position`,
`Viewer::set_selection`), `viewer/viewer.mbt` (two emitters + subscribe
methods + dispose entries), tests in `viewer/cursor_behavior_wbtest.mbt`
(6 tests covering matrix branches 1-7).

1. `setPosition` (cew:670-682) → `Viewer::set_position` — **done**
   (delegates to `set_selection` with `selectionStart == position`, the
   same route Monaco takes through `viewModel.setSelections`).
2. `setSelection` 5 overloads (cew:797-822) → `Viewer::set_selection` —
   **done** (1 typed `@view_model.Selection` parameter, per Deviations).
3. `_setSelectionImpl` (cew:824-830) → inlined into `set_selection` —
   **done** (no-model guard + normalize to anchor/active).
4. `onDidChangeCursorPosition` (cew:117-118, fire :1836-1845) →
   `Viewer::on_did_change_cursor_position` — **done** (fired first, with
   the new active position, matching Monaco's fire order).
5. `onDidChangeCursorSelection` (cew:120-121, fire :1846-1857) →
   `Viewer::on_did_change_cursor_selection` — **done** (fired second, with
   the post-set model selection).
6. `ViewModel.setSelections` (vmi:1185-1187) → inlined — **done**
   (pass-through had no separate layer to live in).
7. `CursorsController.setSelections` (cursor.ts:309-311) → inlined —
   **done** (`fromModelSelection` + `setStates` sequence in the body).
8. `CursorsController.setStates` (cursor.ts:118-134) → inlined — **done**
   (old-state snapshot via `controller.model_state()` before the set;
   multi-cursor-limit slice N/A per scope).
9. `_emitStateChangedIfNecessary` (cursor.ts:403-425) → inlined — **done**.
   Both of Monaco's gates (`CursorModelState.equals` = view+model state at
   :404-406; per-cursor `modelState.equals` at :416-419) reduce, for one
   cursor whose view state is derived deterministically from its model
   state with no version counter, to model-`SingleCursorState` equality —
   compared via `derive(Eq)`, whose fields match Monaco's
   `SingleCursorState.equals` (cursorCommon.ts:357-365, `selectionStartKind`
   included; leftover columns are the standing omission). The
   "view gets the event first" ordering (:412-414) maps to
   `schedule_render()` before the two fires, the same order
   `view_controller.mbt` uses for the mouse path.
10. `CursorState.fromModelSelection` (cursorCommon.ts:283-289) → the
    `SingleCursorState::new(anchor_start, anchor_end, Simple, position)`
    build — **done** (anchor validated as a collapsed range first, so the
    build takes the range's two endpoints).
11. `CursorState.fromModelSelections` (cursorCommon.ts:292-298) → the
    single-element collapse of the same call — **done** (array loop has no
    single-cursor residue).
12. `Cursor.setState` (oneCursor.ts:78-80) → existing
    `CursorsController::set_model_cursor_state` → `Cursor::set_model_state`
    — **done** (reused, not re-ported).
13. `_validateViewState` (oneCursor.ts:91-113) — **N/A** (view-state-provided
    branch only; this port always passes model state).
14. `_setState` model branch (oneCursor.ts:133-150) — **done**:
    `validateRange` on the anchor / `validatePosition` on the active end are
    `TextSnapshot::validate_range`/`validate_position` at the `Viewer`
    boundary (per the risk note, *before* `set_model_cursor_state`, which
    trusts its input); the view-derive at :144-150 is the existing
    `Cursor::set_model_state`. The `leftoverVisibleColumns` reset logic in
    the branch has no analog (field is a standing omission).

Post-audit notes: the `reachedMaxCursorCount` branch inside `setStates` and
`_emitStateChangedIfNecessary` was confirmed N/A-by-scope (no multi-cursor);
`_validateAutoClosedActions`/`_columnSelectData` resets inside `setStates`
touch editing machinery that does not exist in the viewer. No reveal call
was added (watch-item 3 held).

## Risks / watch-items

- **Validation must happen before `set_model_cursor_state`, not after.**
  `Cursor::set_model_state` (`cursor.mbt`) documents that it trusts its input is
  already valid (no validation, by design, for its existing hit-test/converter
  callers). A public `set_selection` that skips the `TextSnapshot::validate_*`
  step before calling it would silently accept out-of-range positions — the
  clamp only happens incidentally deep in `model_line_projection.mbt` for some
  paths, not uniformly. Do not rely on that; validate explicitly at the
  `Viewer::set_selection` boundary.
- **Equality check must compare model state, not view state.** Monaco diffs on
  `modelState.equals` (`cursor.ts:417`) so a no-op selection never fires even if
  transient view recompute would differ. Compare `SingleCursorState`'s
  model-coordinate fields, matching source.
- **Don't let this plan grow a reveal call.** Confirmed non-goal (see Scope) —
  if a future caller wants "select and reveal", that's a `gotoLocation`-style
  composition at the call site, not a change to this plan's two methods.
