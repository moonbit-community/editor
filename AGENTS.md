# Agent Notes

## Project Shape

- Public product code lives at the repository root in MoonBit packages:
  `base/common`, `language`, `platform/log`, `syntax`,
  `syntax/lang_*`, `viewer`, `viewer/common`, `viewer/cursor`,
  `viewer/decorations`, `viewer/model`, `viewer/view_line_renderer`,
  `viewer/view_model`, and `viewer/view_layout`.
- Reference shell/backend code lives under `internal/shell`: `workspace`,
  `remote_protocol`, `workbench`, `web`, `widgets/file_tree`, `server`,
  `server_host_native`, and `examples/embedded_viewer`. These packages are
  not part of the external viewer API.
- The browser-backed viewer package owns DOM creation, CSS, scroll input capture and output application, and Playwright-facing observability; scroll semantics and viewport derivation are backend-neutral model state in `viewer/common` and focused `viewer/*` common-layer packages.
- MoonBit owns readonly editor model identity. The reference shell owns its
  internal workspace semantics and backend-neutral filesystem-provider
  contract.
- Packages that only run on one host target may declare that host's FFI (for example, `viewer` may declare JavaScript FFI and use `rabbita/dom`; `internal/shell/server_host_native` may declare native FFI). Packages shared across targets must not declare FFI.
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
