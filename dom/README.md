# dom

JavaScript/browser host boundary.

## Responsibilities

- Declare JavaScript FFI for narrow browser host capabilities shared by the
  browser app: protocol URL derivation, current-document exposure,
  observability event emission, and best-effort `localStorage` persistence
  (`storage_get_item` / `storage_set_item`).
- Install the `__readonlyEditorEvent` observability hook consumed by the
  browser test harness.

## Boundaries

- JS-only package (`supported_targets = "js"`); may declare JavaScript FFI
  under the host-FFI rule in `../docs/architecture.md`.
- Has no product package dependencies.
- Must not own backend-neutral render-frame construction, workspace policy, or
  native server behavior.
- Must not expose broad render/session callback globals such as
  `__readonlyEditorMount` or `__readonlyEditorRender`.

## Checks

- Browser observability expectations are documented in `../docs/harness.md`.
- Run `just check` for the repository-level type check.
