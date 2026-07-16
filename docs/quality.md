# Quality Gates

Current docs and package READMEs are product contracts. Keep architecture here
and in `docs/architecture.md`, package details in package READMEs, and history in
implemented execution plans.

## Required Checks

```sh
just check
just test
just build
just test-browser
```

Run the subset relevant to each milestone; run all four before declaring a
cross-package or browser-visible implementation complete.

## Guardrails

- Product code never imports `vscode/`, `codemirror/`, or the reference shell.
- Shared packages remain FFI-free; js/native-only packages declare their target.
- Viewer packages use only Rabbita's DOM/JS bindings, not its TEA framework.
- The shell/backend remains optional to embedders.
- `just check` is authoritative for the scripted boundary rules; see
  `docs/architecture.md` for the complete dependency policy.
