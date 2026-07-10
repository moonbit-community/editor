# 1:1 Port Playbook

Use this protocol for Monaco/VS Code or CodeMirror ports. A port is complete
only when it accounts for the whole named source unit, not merely the code
needed for one observed symptom.

Reference maps: `docs/references/{monaco,codemirror}.md`. Reference-test rules:
`docs/quality.md`. Reference trees are read-only research inputs.

## Phase 0: Close the Scope

Name complete source files/classes. A smaller scope must be a complete method
cluster and explicitly name excluded sibling clusters. Scope by source unit,
not bug symptom. Record the pinned source commit.

## Phase 1: Inventory the Denominator

Read every scoped source file and enumerate:

- every public/private method, getter, setter, and static member;
- every constant, enum value, and magic number;
- every behavior-changing branch and early return;
- every owned DOM attribute, class, CSS property, and custom property.

The inventory is a review deliverable. Record its member count and stop for
review before writing port code. A search such as
`rg -n '<member-pattern>' vscode/<path>` is only a discovery aid; reading the
whole source unit is authoritative.

## Phase 2: Build the Parity Ledger

Give every inventory member exactly one row:

| Source member (file:line) | Arithmetic/transition | MoonBit symbol | Status |
|---|---|---|---|

Use `TODO` while working. A completed row ends in `PORTED`, `TESTED`, `PASS`,
`DEFERRED (reason)`, or `N-A (reason)`. Absence is not deferral. No row is
`PASS` without a linked test that would fail for a regression in that row,
including its boundary cases.

## Phase 3: Copy Structure, Do Not Invent

Preserve control flow, branch order, early returns, constants, geometry,
layout, and timing arithmetic. Cite the source location for each logic line.

List every uncited line in `## Deviations` with a concrete reason. DOM/FFI,
async, service, and type-system seams can justify a deviation; convenience or
locally invented math cannot. If a line cannot be traced or justified, stop and
research the source behavior.

## Phase 4: Derive Tests from Branches

- Give every behavior-changing branch an input that takes it.
- List all behavior-switching variables and cover their meaningful
  combinations, boundaries, and orthogonal axes.
- Run the harness across configurations such as viewport, content shape,
  options, platform, or target where they affect behavior.
- Prefer porting the corresponding upstream unit tests under the conformance
  rules in `docs/quality.md`.

One passing happy path proves neither the source branches nor 1:1 parity.

## Phase 5: Exit Gate

A plan may claim 1:1 only after all five checks pass:

1. Inventory count equals ledger-row count; report
   `done / deferred / N-A` totals.
2. Every ported function has been reread side-by-side with the source for
   order, branches, early returns, and constants.
3. Every behavior-variable combination has test evidence across the required
   configurations.
4. Every non-source-cited line is recorded and justified under `Deviations`.
5. A closing reread of the complete source unit finds no unaccounted member.

Repository checks (`just check`, `just test`, `just test-browser`) are necessary
merge gates; this reconciliation is the additional 1:1 gate.

## Plan Template

```markdown
# <Source Unit> 1:1 Port

Status: proposed
Date: <YYYY-MM-DD>
Oracle commit: <submodule SHA>

## Scope (Phase 0)

Whole source unit: `vscode/<path>` [+ siblings].
Explicitly out of scope: <complete sibling clusters>.

## Inventory (Phase 1)

- Members: <all public/private/static/getter/setter members>
- Constants: <all constants/enums/magic numbers>
- Branches: <all behavior-changing branches and early returns>
- DOM/CSS: <all owned attributes/classes/properties, or N-A>
- Member count: N

Review gate: stop here before implementation.

## Parity Ledger (Phase 2)

| Source member (file:line) | Arithmetic/transition | MoonBit symbol | Status |
|---|---|---|---|

## Deviations (Phase 3)

<Every uncited logic line and its seam-based reason, or None.>

## Test Matrix (Phase 4)

- Behavior-switching variables: <list>
- Combinations and boundaries: <list>
- Harness/configurations: <list>

## Exit Gate (Phase 5)

- [ ] rows == members; done/deferred/N-A = _/_/_
- [ ] every ported function diff-reviewed against the source
- [ ] branch/configuration matrix covered and green
- [ ] all deviations recorded and justified
- [ ] closing whole-source reread pasted below
```
