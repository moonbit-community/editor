# Execution Plans

Keep future implementation plans here when a feature spans multiple packages or
changes harness behavior. Plans should be short enough for another engineer or
agent to execute without re-discovering context.

Execution plans are not the current architecture map. Active behavior and
ownership live in `docs/architecture.md`, package READMEs, and tests.

For any plan that ports Monaco/VS Code (or CodeMirror) behavior, follow
`_PORT_PLAYBOOK.md` — it gives the inventory-first protocol, parity-ledger
format, "copy don't invent" rule, and the exit gate that make "1:1 port"
verifiable rather than aspirational.

## Implemented Plans

After an execution plan has been implemented, treat it as historical evidence.
Do not rewrite its original goals, protocol, steps, validation, or exit
criteria to match later design changes.

For follow-up work, create a new execution plan or add a clearly dated
superseding addendum that links back to the implemented plan. Living
architecture updates belong in `docs/architecture.md`, package READMEs, and
harness documentation once the follow-up implementation lands.
