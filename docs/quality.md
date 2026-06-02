# Quality Gates

## Required Checks

```sh
npm run check
npm run test
npm run build
npm run test:browser
```

## Guardrails

- Root MoonBit package dependencies flow from `web` to `view` to domain packages.
- Product code must not import from `codemirror/` or `vscode/`.
- `codemirror/` and `vscode/` are references only.
- v1 remains readonly: no edit transactions, undo/redo, IME, piece tables, or change mapping.
