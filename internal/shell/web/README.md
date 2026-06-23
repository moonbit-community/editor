# internal/shell/web

Generated browser entrypoint for the reference workbench.

## Responsibilities

- Remain the generated MoonBit browser entrypoint.
- Start the Rabbita-backed reference shell through `workbench`.
- Keep application-shell ownership out of JavaScript; the native server serves
  `web/dist/index.html`, `/style.css`, and `/editor.mjs`.
- Treat `/style.css` as a generated asset assembled from owner-adjacent CSS
  files by `scripts/build-web.mbtx`.

## Boundaries

- May depend on `internal/shell/workbench` only; composition of the viewer,
  tree, and transport lives there.
- Must remain the generated browser entrypoint and avoid becoming a shared
  domain package.
- Does not declare JavaScript FFI directly; browser host calls go through
  `workbench` and the packages it composes, especially `viewer` and
  Rabbita browser bindings.
- Does not parse active document identity from browser URL parameters.

## Checks

- Browser harness behavior is documented in `../../../docs/harness.md`.
- Run `just check` for the repository-level type check.
