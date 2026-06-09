# dom

JavaScript/browser host boundary.

## Responsibilities

- Declare JavaScript FFI for browser document state, filesystem provider hooks,
  remote protocol transport hooks, rendering, callbacks, disposables, and
  observability.
- Convert host responses into MoonBit `workspace` contracts.
- Own DOM mounting and browser-side host effect integration.

## Boundaries

- This is the only product package that may declare JavaScript FFI.
- May depend on `workspace` and JS async support.
- Must not own backend-neutral render-frame construction, workspace policy, or
  native server behavior.
- Keep this package JS-only through `supported_targets = "js"`.

## Checks

- Browser observability expectations are documented in `../docs/harness.md`.
- Run `just check` for the repository-level type check.
