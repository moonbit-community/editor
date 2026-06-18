# platform/log

Host-neutral structured logging contracts.

## Responsibilities

- Define `LogLevel`, `LogEntry`, `Logger`, and `LogService`.
- Provide null, memory, and multiplex logger sinks.
- Keep logging best-effort: logger methods are `noraise` so diagnostics do not
  fail viewer or backend workflows.

## Boundaries

- Must not depend on viewer, workbench, server, browser, native, transport, or
  workspace packages.
- Hosts decide where log entries go. This package only defines the shared
  structure and filtering facade.

## Checks

- Package tests live in `log_test.mbt`.
- Run `just check` for the repository-level guardrail.
