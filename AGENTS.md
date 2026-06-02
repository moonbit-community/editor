# Agent Notes

## Project Shape

- Product code lives at the repository root in MoonBit packages: `core`, `syntax`, `decorations`, `workspace`, `language`, `view`, `dom`, and `web`.
- The browser host owns DOM creation, CSS, scrolling, file read/watch effects, and Playwright-facing observability.
- MoonBit owns workspace semantics and readonly document identity.
- Only the `dom` package may declare JavaScript FFI.
- `codemirror/` and `vscode/` are reference-only submodules. Do not import product code from either tree.
- The editor is a readonly viewer.

## Documentation Map

- Architecture overview and package boundaries: `docs/architecture.md`
- Harness commands and browser observability events: `docs/harness.md`
- Required checks and guardrails: `docs/quality.md`
- Develop style notes: `docs/styles.md`
- Future multi-package or harness-affecting plans: `docs/exec-plans/README.md`
- Demo source fixture for viewer/browser flows: `docs/fixtures/demo.mbt`
- CodeMirror reference map: `docs/references/codemirror.md`
- Monaco/VS Code reference map: `docs/references/monaco.md`

## Version Control

- Commit regularly to save work in meaningful steps.
- Keep commits focused around one coherent change and use messages that describe the behavior or decision being saved.
- Run the most relevant local checks before committing when the change can affect behavior.
