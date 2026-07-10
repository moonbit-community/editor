# viewer/common/cursor

Backend-neutral single-cursor state for the readonly viewer.

## Flow and API

- `SingleCursorState` holds an anchor range, `SelectionStartKind`, and active
  1-based UTF-16 position; `selection`, `has_selection`, and `moved` derive the
  oriented `viewer/common/core.Selection`.
- `CursorContext` wraps `core.CoordinatesConverter` for model/view conversion.
- `Cursor` keeps model- and view-coordinate states synchronized. Its public
  mutation is `set_model_state`; view-driven mutation stays behind the controller.
- `CursorsController` owns one cursor, exposes model/view selections, accepts
  view-coordinate `move_to`, and reprojects the existing model selection when
  `set_context` installs a converter after wrapping/folding/injected-text changes.
- Free `move_to` and `move_to_select` functions are the pointer-driven subset of
  Monaco's `CoreNavigationCommands`.

Upstream sources are `cursorCommon.ts`, `cursorContext.ts`, `oneCursor.ts`,
`cursor.ts`/`cursorCollection.ts`, and the selection part of `coreCommands.ts`.

## Deliberate reductions

There is one selection only. The immutable model needs no marker-tracked cursor
ranges or edit validation. Sticky vertical movement (`leftoverVisibleColumns`) is
absent; `Word` and `Line` anchor kinds are represented, but their drag-extension
behavior is not implemented.

The package depends only on `base/common` and `viewer/common/core`; it has no
view-model, DOM, or FFI dependency. See `pkg.generated.mbti` for the complete API
and run `moon test --target js viewer/common/cursor`.
