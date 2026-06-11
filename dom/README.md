# dom

JavaScript/browser host boundary.

## Responsibilities

- Declare JavaScript FFI for narrow browser host capabilities: protocol URL
  derivation, current-document exposure, filesystem provider hooks, disposables,
  observability, and best-effort `localStorage` persistence
  (`storage_get_item` / `storage_set_item`).
- Convert host responses into MoonBit `workspace` contracts.
- Install browser filesystem fallback providers without rendering editor DOM,
  owning document session state, or fabricating remote protocol responses.

## Boundaries

- This is the only product package that may declare JavaScript FFI.
- May depend on `workspace` and JS async support.
- Must not own backend-neutral render-frame construction, workspace policy, or
  native server behavior.
- Must not expose broad render/session callback globals such as
  `__readonlyEditorMount` or `__readonlyEditorRender`.
- Keep this package JS-only through `supported_targets = "js"`.

## Checks

- Browser observability expectations are documented in `../docs/harness.md`.
- Run `just check` for the repository-level type check.
