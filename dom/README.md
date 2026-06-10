# dom

JavaScript/browser host boundary.

## Responsibilities

- Declare JavaScript FFI for narrow browser host capabilities: current-document
  exposure for transports, filesystem provider hooks, remote protocol transport
  hooks, disposables, and observability.
- Convert host responses into MoonBit `workspace` contracts.
- Install dev/test fallback providers and transports without rendering editor
  DOM or owning document session state.

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
