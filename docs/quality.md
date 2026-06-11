# Quality Gates

## Required Checks

```sh
just check
just test
just build
just test-browser
```

## Guardrails

- Root MoonBit package dependencies flow from `web` to `view` to domain packages.
- Product code must not import from `codemirror/` or `vscode/`.
- Packages that only run on one host target may declare that host's FFI; packages shared across targets must not declare FFI. See the host-FFI rule in `architecture.md`.
- `codemirror/` and `vscode/` are references only.
