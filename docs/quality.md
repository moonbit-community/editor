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

## Conformance Ports

Ports of Monaco/VS Code tests follow
`docs/exec-plans/_PORT_PLAYBOOK.md` and these file rules:

1. Name files `*_reference_test.mbt` or `*_reference_wbtest.mbt` in the owning
   package.
2. Preserve upstream suite/test labels and bug IDs verbatim.
3. Start each file with the exact upstream path and pinned submodule commit.
4. Adapt service/async/DOM seams or leave an explicit `SKIPPED` marker naming
   the test that covers the case; never silently omit it.
5. Keep one reference file per upstream source file where practical.

## Guardrails

- Product code never imports `vscode/`, `codemirror/`, or the reference shell.
- Shared packages remain FFI-free; js/native-only packages declare their target.
- Viewer packages use only Rabbita's DOM/JS bindings, not its TEA framework.
- The shell/backend remains optional to embedders.
- `just check` is authoritative for the scripted boundary rules; see
  `docs/architecture.md` for the complete dependency policy.
