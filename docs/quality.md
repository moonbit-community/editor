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
- Only the `dom` package may declare JavaScript FFI.
- `codemirror/` and `vscode/` are references only.
- v1 remains readonly: no edit transactions, undo/redo, IME, piece tables, or change mapping.
