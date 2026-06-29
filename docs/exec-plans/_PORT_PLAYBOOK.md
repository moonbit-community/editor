# 1:1 Port Playbook

How to write — and finish — an execution plan that ports Monaco/VS Code (or
CodeMirror) behavior so that "done" actually means a faithful 1:1 port, not a
faithful port of the slice someone happened to look at.

This is a meta-plan: a template plus the rules every `monaco-*-port.md` must
follow. It exists because past "1:1 port" plans still shipped gaps and bugs.
The root cause was always the same: the plan owned a *numerator* (the methods it
chose to port) and called it a fraction. A real port must own the
**denominator** — the entire surface of the named source unit.

Reference map: `docs/references/monaco.md`. Conformance-test conventions:
`docs/quality.md` ("Conformance ports") and
`docs/exec-plans/monaco-test-conformance-port.md`. Submodules `vscode/` and
`codemirror/` are reference-only; never import from them.

## Why ports leak (the failure modes to design against)

Diagnosed from real regressions (e.g. the hover horizontal-clipping bug: the
plan ported the *vertical* available-space methods and marked them `PASS`, while
the *horizontal* counterparts `_findMaximumRenderingWidth` /
`_setHoverWidgetMaxDimensions` were never in the ledger, and `shift_left` was
hand-invented).

1. **Selective porting framed as complete.** A subset is ported faithfully, the
   plan is declared done. Un-ported members are *unseen*, not deferred. No step
   ever enumerated the source's full surface, so completeness was uncheckable.
2. **Homegrown logic masquerading as a port.** Invented geometry/layout/timing
   math reintroduces the exact bugs the source already solved. Nothing flagged
   "this line has no source citation."
3. **Tests prove the slice, not parity.** `TESTED` meant "the thing I built
   passes the test I wrote for it" — circular — and ran at one configuration.
   Bugs on the orthogonal axis / at boundary conditions survive.
4. **Symptom-driven scope.** Scope is set by one observed symptom; the fix
   covers that symptom's axis and leaves the rest broken.
5. **"1:1 port" never operationalized.** With no definition of done, the model
   optimizes for the stated symptom + green tests, which it can always satisfy
   without being complete.

The fix is to remove the two kinds of discretion that let this happen: discretion
over **scope** (enumerate the denominator) and over **correctness criteria**
(tie every "done" to a source diff + a boundary test), and to **forbid
invention**.

## Protocol (every port plan follows these phases in order)

### Phase 0 — Scope by source unit, not by symptom

State the port as a closed set of source files/classes, e.g. "port
`contentHoverWidget.ts` + `resizableContentWidget.ts` (whole files)". If you
scope smaller, scope to a complete *method cluster* and name the sibling
clusters that are explicitly **out**. The plan title names the source unit, not
the bug.

### Phase 1 — Inventory (the denominator), before any port code

Produce, *by reading the source files* (not from memory), the complete member
list of the scoped unit:

- every method (public **and** private), getter, and static;
- every constant / magic number / enum value;
- every behavior-switching branch and early-return inside ported methods
  (each implies an input that takes it — these become test cases);
- every CSS property / custom property / class name and DOM attribute the unit
  sets, if it owns DOM.

This inventory is a reviewable deliverable. Completeness later becomes
arithmetic: `count(ledger rows) == count(inventory members)`. Stop here for
review before writing port code — the inventory is where "unseen" gaps are
caught.

> Aid: list a TypeScript file's members with
> `grep -nE '^\s*(private|public|protected|static|get |set )?\s*[_a-zA-Z]+\s*\(' vscode/<path>`
> and reconcile by hand. The grep is a starting net, not the authority — read
> the file.

### Phase 2 — Parity ledger (one row per inventory member)

Use the table format from `monaco-hover-logic-chain-port.md`. Every member from
Phase 1 gets exactly one row, and every row resolves to one status — never
absent:

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|

- **Source ref** is filled by reading the file (line numbers + the actual
  arithmetic/branch), not recalled.
- **Status** ∈ `TODO` / `PORTED` (code matches source) / `TESTED`
  (whitebox/oracle/browser proof exists) / `PASS` (proof green) /
  `DEFERRED (reason)` / `N-A (reason)`. A member with no work and no reason is a
  bug in the plan, not an omission.
- No row is `PASS` without a linked test whose failure would specifically catch
  a regression in *that* row, at its boundary conditions.

### Phase 3 — Port by copying structure; never invent

Match the source's control flow, branch order, early returns, and constants.
**Any logic line not traceable to a source location is a divergence** and must
appear in a `## Deviations` section with justification (a genuine
host/seam difference, not "I thought this was simpler"). If you cannot cite the
source line, you are inventing — stop and find the source behavior. Local seams
(DOM/FFI, async, services) are expected deviations; *layout/geometry/timing math
is not*.

### Phase 4 — Tests derived from the source's branches

- For each behavior-switching branch in Phase 1, add a case that takes it.
- List the **behavior-switching variables** explicitly and cover their
  combinations, not one happy path. (Hover example: viewport width, anchor near
  each edge, scroll offset, content shape tall/wide/both — the missing
  narrow-width × wide-content cell was the bug.)
- Run the verification harness across that matrix, not a single configuration —
  single-config green is the dominant source of false confidence.
- Where a Monaco unit test exists, prefer porting it per `docs/quality.md`
  "Conformance ports".

### Phase 5 — Exit gate (a plan is not "done" until all pass)

1. **Inventory reconciled:** every Phase-1 member has a ledger row with a
   terminal status; report the `done / deferred / N-A` counts.
2. **Diff review:** every ported function read side-by-side against its source;
   branch order, constants, early returns confirmed present.
3. **Matrix coverage:** every behavior-switching variable/combination has a
   test; harness run across configurations.
4. **Deviations documented:** every non-source-cited line is listed and
   justified.
5. **Closing self-audit:** re-read the source unit and confirm each member is
   present + behavior-matching; paste the reconciliation into the plan.

"`just check` / `just test` / `just test-browser` green" is **necessary, not
sufficient** — it gates merge, the exit gate gates "1:1".

## Plan skeleton (copy into the new `monaco-<unit>-port.md`)

```markdown
# Monaco <unit> 1:1 Port
Status: proposed — Date: <YYYY-MM-DD>. Oracle commit: <vscode submodule sha>.

## Scope (Phase 0)
Source unit (whole): vscode/<file>.ts [+ siblings]. Out of scope: <clusters>.

## Inventory (Phase 1)   <!-- reviewed before port code -->
- Methods: <list public+private>
- Constants: <list>
- Branches to cover: <list>
- DOM/CSS owned: <list, if any>
Member count: N.

## Parity ledger (Phase 2)   <!-- N rows, every member accounted for -->
| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|

## Deviations (Phase 3)   <!-- every non-source-cited line, justified -->

## Test matrix (Phase 4)
Behavior-switching variables: <list>. Cases cover: <combinations>.

## Exit gate (Phase 5)
- [ ] inventory reconciled (rows == members): done/deferred/N-A = _/_/_
- [ ] every ported fn diff-reviewed vs source
- [ ] matrix covered, harness run across configs
- [ ] deviations documented
- [ ] closing self-audit pasted
```

## Anti-pattern checklist (reject a plan that does any of these)

- Lists "the methods to port" without first enumerating the whole source unit.
- Has a ledger row marked `PASS`/`TESTED` with no linked test, or a test at one
  config only.
- Contains geometry/layout/timing logic with no source citation and no
  `Deviations` entry.
- Scopes by symptom ("fix truncated hover") instead of by source unit.
- Treats absence of a member as "deferred" — deferral must be an explicit row
  with a reason.
