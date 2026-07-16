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
   behavior-changing branches, and owned DOM/CSS—then review the inventory
   before implementation.
2. Give every inventory member a parity-ledger row ending in
   `PORTED`/`TESTED`/`PASS`/`DEFERRED (reason)`/`N-A (reason)`; absence is a bug.
3. Preserve source control flow, ordering, early returns, and constants. Cite
   every logic line or list it under `Deviations` with a real seam-based reason.
4. Derive tests from source branches and run the behavior-variable matrix across
   configurations. Green repository checks alone do not establish 1:1 parity.

## Execution Plan Continuation

When the user asks to execute a checked-in plan, carry it through inventory,
review, implementation, validation, and milestone commits without pausing for
user approval. `Gate A`, `review gate`, and `STOP FOR REVIEW` are internal
quality checkpoints: produce the required artifact, review it against the plan
and current source, record the result, and continue.

Pause only when the user explicitly requests a review stop or when the gate
reveals a material choice that the plan and current repository evidence cannot
resolve without changing scope, public API, or behavior.

## Version Control

- Commit each coherent, validated milestone without waiting to be asked.
- Do not rewrite, squash, amend, reset, or revert history without approval.
