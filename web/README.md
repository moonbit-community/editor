# web

Browser client entrypoint for the readonly editor.

## Responsibilities

- Remain the generated MoonBit browser entrypoint.
- Start the Rabbita-backed browser app through `workbench`.
- Keep application-shell ownership out of JavaScript; the native server serves
  `web/dist/index.html`, `/style.css`, and `/editor.mjs`.

## Boundaries

- May depend on `workbench` only; composition of the viewer, tree, and
  transport lives there.
- Must remain the generated browser entrypoint and avoid becoming a shared
  domain package.
- Does not declare JavaScript FFI directly; host calls go through `dom` and
  the packages `workbench` composes.
- Does not parse active document identity from browser URL parameters.

## Checks

- Browser harness behavior is documented in `../docs/harness.md`.
- Run `just check` for the repository-level type check.
