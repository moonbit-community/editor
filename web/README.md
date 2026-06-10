# web

Browser client entrypoint for the readonly editor.

## Responsibilities

- Remain the generated MoonBit browser entrypoint.
- Start the Rabbita-backed browser app through `renderer/browser`.
- Keep application-shell ownership out of JavaScript; Vite's bootstrap only
  imports CSS and the generated MoonBit module.

## Boundaries

- May depend on the Rabbita-backed browser adapter.
- Must remain the generated browser entrypoint and avoid becoming a shared
  domain package.
- Does not declare JavaScript FFI directly; host calls go through `dom` and
  `renderer/browser`.
- Does not parse active document identity from browser URL parameters.

## Checks

- Browser harness behavior is documented in `../docs/harness.md`.
- Run `just check` for the repository-level type check.
