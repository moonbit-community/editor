# renderer/browser

Browser render backend adapter.

## Responsibilities

- Mount the Rabbita browser app and render backend-neutral
  `renderer.RenderFrame` values as browser HTML.
- Own browser view state for the readonly shell, workspace sidebar selection,
  active frame, hover tooltip, definition target, and session status.
- Register render, load, watch, hover, and definition callbacks.
- Adapt browser filesystem and semantic remote protocol transports into
  MoonBit provider contracts.
- Emit browser observability events such as `moonbit:render` and `dom:mounted`.

## Boundaries

- May depend on Rabbita public packages, `dom`, `workspace`, `language`,
  `remote_protocol`, `renderer`, and JS async support.
- Must keep JavaScript FFI declarations in `dom`; this package calls the host
  boundary but does not declare it.
- Browser-only behavior stays here or in `dom`, not in shared renderer or
  domain packages.
- Must not expose a raw browser LSP transport.
- The backend-neutral `renderer` package must not import Rabbita or browser
  host packages.

## Checks

- Browser observability expectations are documented in `../../docs/harness.md`.
- Run `just check` for the repository-level type check.
