# Quality Gates

Current docs and package READMEs are part of the product contract. Keep them
short, current, and aligned with code changes. Historical execution plans should
not override the current architecture docs.

## Required Checks

```sh
just check
just test
just build
just test-browser
```

## Guardrails

- Public MoonBit package dependencies stay centered on the reusable viewer
  surface. Reference host dependencies live under `internal/shell` and flow
  toward shared domain packages:
  `internal/shell/web -> internal/shell/workbench -> viewer`, optional
  internal widgets, and protocol;
  `internal/shell/server_host_native/main -> internal/shell/server_host_native -> internal/shell/server`.
- Product code must not import from `codemirror/` or `vscode/`.
- Public packages must not import `moonbit-community/editor/internal/shell/*`.
- `viewer/*` packages use only the Rabbita API bindings (`rabbita/dom`,
  `rabbita/js`), never the Rabbita TEA framework (`rabbita`, `rabbita/html`,
  `rabbita/cmd`, `rabbita/websocket`).
- Packages that only run on one host target may declare that host's FFI; packages shared across targets must not declare FFI. See the host-FFI rule in `architecture.md`.
- `codemirror/` and `vscode/` are references only.
- `internal/shell/workbench`, `internal/shell/web`, `internal/shell/server`,
  and `internal/shell/server_host_native` are the reference shell/backend
  stack. They must not become required by the reusable viewer.
