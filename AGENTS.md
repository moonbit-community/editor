# Agent Notes

## Porting Monaco/VS Code (1:1)

When a task is to port Monaco/VS Code (or CodeMirror) behavior, follow
`docs/exec-plans/_PORT_PLAYBOOK.md`. Non-negotiables:

- **Inventory first.** Before writing port code, enumerate the *whole* source
  unit (every public + private method, constant, and behavior-switching branch)
  by reading the file — that is the denominator. Stop for review. Porting a
  hand-picked subset and calling the plan done is the #1 source of gaps.
- **Account for every member.** Each source member gets a parity-ledger row with
  a terminal status (`PORTED`/`TESTED`/`PASS`/`DEFERRED (reason)`/`N-A (reason)`).
  A member absent from the ledger is a bug in the plan; "deferred" must be an
  explicit row with a reason, never silence.
- **Copy, do not invent.** Match the source's branches, order, early returns, and
  constants. Any logic line (especially geometry/layout/timing math) that cannot
  cite a source location is a divergence and must be listed in a `Deviations`
  section with justification. Local seams (DOM/FFI/async) are expected
  deviations; invented math is not.
- **Test from the source's branches, across configs.** Each branch implies an
  input that takes it; cover the behavior-switching variables and their
  combinations, and run the harness across configurations (not one viewport).
  `just check` / `just test` / `just test-browser` green is necessary, not
  sufficient — the playbook's exit gate is what makes a port "1:1".

See `docs/quality.md` ("Conformance ports") for porting Monaco's own unit tests,
and `docs/references/monaco.md` for the source map.

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
