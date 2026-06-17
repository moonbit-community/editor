# Agent Notes

## Project Shape

- Product code lives at the repository root in MoonBit packages: `base/common`, `syntax`, `decorations`, `workspace`, `language`, `view`, `remote_protocol`, `server`, `server_host_native`, `renderer/core`, `renderer/model`, `renderer`, `renderer/browser`, `dom`, and `web`.
- The browser backend owns DOM creation, CSS, scroll input capture and output application, and Playwright-facing observability; scroll semantics and viewport derivation are backend-neutral model state in `renderer`.
- MoonBit owns workspace semantics, readonly editor model identity, and the backend-neutral filesystem-provider contract.
- Packages that only run on one host target may declare that host's FFI (for example, `dom` and `renderer/browser` may declare JavaScript FFI; `server_host_native` may declare native FFI). Packages shared across targets must not declare FFI.
- `codemirror/` and `vscode/` are reference-only submodules. Do not import product code from either tree.
- The editor is a readonly viewer.

## Documentation Map

- Global architecture, dependency direction, and cross-package boundaries: `docs/architecture.md`
- Local package contracts: each product package's `README.md`
- Harness commands and browser observability events: `docs/harness.md`
- Required checks and guardrails: `docs/quality.md`
- Develop style notes: `docs/styles.md`
- Future multi-package or harness-affecting plans: `docs/exec-plans/README.md`
- Source fixture for viewer/browser flows: `tests/fixtures/workspace`
- CodeMirror reference map: `docs/references/codemirror.md`
- Monaco/VS Code reference map: `docs/references/monaco.md`

## Version Control

- Commit regularly without waiting for an explicit user request.
- For multi-step implementation plans, create a focused commit after each coherent milestone once relevant checks pass.
- Do not leave a large implementation as one final commit unless the user explicitly requests a single commit.
- Never rewrite, squash, amend, reset, or revert history without explicit user approval.
