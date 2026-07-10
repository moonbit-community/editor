# Agent Notes

## Start Here

- Architecture and dependency rules: `docs/architecture.md`
- Package contracts: the owning package's `README.md` and
  `pkg.generated.mbti`
- Commands and test-layer selection: `docs/harness.md`
- Required checks and conformance-test rules: `docs/quality.md`
- Style: `docs/styles.md`
- Future cross-package plans: `docs/exec-plans/README.md`
- Monaco/CodeMirror source maps: `docs/references/{monaco,codemirror}.md`

Implemented execution plans are history, not current contracts.

## 1:1 Ports

Follow `docs/exec-plans/_PORT_PLAYBOOK.md` for every Monaco/VS Code or
CodeMirror port. The non-negotiables are:

1. Inventory the whole named source unit—public/private members, constants,
   behavior-changing branches, and owned DOM/CSS—then stop for review.
2. Give every inventory member a parity-ledger row ending in
   `PORTED`/`TESTED`/`PASS`/`DEFERRED (reason)`/`N-A (reason)`; absence is a bug.
3. Preserve source control flow, ordering, early returns, and constants. Cite
   every logic line or list it under `Deviations` with a real seam-based reason.
4. Derive tests from source branches and run the behavior-variable matrix across
   configurations. Green repository checks alone do not establish 1:1 parity.

## Version Control

- Commit each coherent, validated milestone without waiting to be asked.
- Do not rewrite, squash, amend, reset, or revert history without approval.
