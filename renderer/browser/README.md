# renderer/browser

Browser render backend adapter.

## Responsibilities

- Bridge backend-neutral `renderer.RenderFrame` values to the browser host.
- Register render, load, watch, hover, and definition callbacks.
- Adapt browser filesystem, LSP, and remote protocol transports into MoonBit
  provider contracts.
- Emit browser observability events such as `moonbit:render`.

## Boundaries

- May depend on `dom`, `workspace`, `language`, `remote_protocol`, `renderer`,
  and JS async support.
- Must keep JavaScript FFI declarations in `dom`; this package calls the host
  boundary but does not declare it.
- Browser-only behavior stays here or in `dom`, not in shared renderer or
  domain packages.

## Checks

- Browser observability expectations are documented in `../../docs/harness.md`.
- Run `just check` for the repository-level type check.
