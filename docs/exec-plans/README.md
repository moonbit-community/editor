# Execution Plans

Create a plan here for future work spanning packages or changing harness
behavior. It must let another engineer execute the work without rediscovery.

For Monaco/VS Code or CodeMirror ports, follow `_PORT_PLAYBOOK.md`; inventory
and ledger review precede implementation.

When the user asks to execute a plan, review gates are internal validation
checkpoints, not user-approval pauses. Complete and record each review, then
continue through implementation and validation. Pause only if the user asks for
it or the review exposes a material unresolved choice that changes scope,
public API, or behavior.

An implemented plan is immutable historical evidence, not the current
architecture contract. For later work, create a new plan or add a clearly dated
superseding addendum. Put landed ownership and behavior in
`docs/architecture.md`, package READMEs, tests, and harness docs.
