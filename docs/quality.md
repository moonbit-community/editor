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

- Root MoonBit package dependencies flow from host entry points toward shared
  domain packages: `web -> workbench -> viewer`, optional widgets,
  and protocol; `server_host_native/main -> server_host_native -> server`;
  common viewer/workspace/language packages stay host-neutral.
- Product code must not import from `codemirror/` or `vscode/`.
- Packages that only run on one host target may declare that host's FFI; packages shared across targets must not declare FFI. See the host-FFI rule in `architecture.md`.
- `codemirror/` and `vscode/` are references only.
- `workbench`, `web`, `server`, and `server_host_native` are the reference
  shell/backend stack. They must not become required by the reusable viewer.
