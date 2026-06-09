# web

Browser client entrypoint for the readonly editor.

## Responsibilities

- Register browser callbacks for render, load, watch, hover, and definition
  flows.
- Build the current `SourceDocument`, run syntax highlighting and provider
  synchronization, create render frames, and mount them through the browser
  backend.
- Select local browser providers or `readonly-remote` providers based on URI
  scheme.
- Emit language diagnostics, hover, definition, and error observability
  events for harness inspection.

## Boundaries

- May depend on browser, renderer, workspace, language, syntax, decorations,
  DOM, and JS async packages.
- Must remain the JS entrypoint and avoid becoming a shared domain package.
- Does not declare JavaScript FFI directly; host calls go through `dom` and
  `renderer/browser`.

## Checks

- Browser harness behavior is documented in `../docs/harness.md`.
- Run `just check` for the repository-level type check.
