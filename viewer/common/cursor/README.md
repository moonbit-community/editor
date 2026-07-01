# viewer/cursor

Backend-neutral cursor/selection state for the readonly viewing path. A faithful
port of Monaco's cursor stack, reduced to what a selection-only viewer needs.

## Responsibilities

- `SingleCursorState` (`cursorCommon.ts`): the cursor state on one coordinate
  space — an anchor range, a `SelectionStartKind`, and the active position —
  plus the derived oriented `Selection` and the `move`/`moved` transition.
- `CursorContext` (`cursorContext.ts`): the coordinates converter the cursor
  uses to bridge model and view positions.
- `Cursor` (`oneCursor.ts`): one cursor keeping a model-coordinate and a
  view-coordinate `SingleCursorState` in sync; setting one side derives the
  other (`set_view_state` / `set_model_state` / `reproject`).
- `CursorsController` (`cursor.ts` / `cursorCollection.ts`): owns the single
  cursor, exposes the model/view selections, and re-projects on reflow.
- `CoreNavigationCommands` (`coreCommands.ts` selection subset): `move_to`
  (collapse) and `move_to_select` (extend), the commands the pointer path drives.

## Boundaries

- Pure logic: no DOM, browser, or native FFI; builds on `js` and `native`.
- Depends only on `base/common` (positions) and `viewer/view_model` (the
  coordinates converter and `Selection`).

## Deliberate deviations from Monaco

- Single selection only (no multi-cursor).
- The immutable readonly model means no marker-tracked ranges and no
  model-validation pass in `_setState`; positions from the hit test and the
  converter are already valid and the converter clamps.
- `leftoverVisibleColumns` (sticky vertical movement) is omitted until keyboard
  navigation lands; `Word`/`Line` selection kinds are modeled but the
  drag-extend behavior for them is a follow-up.
