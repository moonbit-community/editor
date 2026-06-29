# Quality Gates

Current docs and package READMEs are part of the product contract. Keep them
short, current, and aligned with code changes. High-level docs should describe
ownership and boundaries; package details should stay in package READMEs or
source. Historical execution plans should not override current architecture
docs.

## Required Checks

```sh
just check
just test
just build
just test-browser
```

## Conformance ports

Faithful 1:1 ports of Monaco/VS Code's own unit tests are kept as reference
conformance suites and must follow these conventions (see
`docs/exec-plans/monaco-test-conformance-port.md`):

1. **Naming.** A port lives in a file suffixed `*_reference_test.mbt` (or
   `*_reference_wbtest.mbt` for white-box) in the owning package, separating
   conformance ports from local tests.
2. **Traceability.** Preserve Monaco's original `test(...)` / `suite(...)` names
   and bug IDs verbatim as the case label string (e.g. `"Bug 9827"`,
   `"issue #3462"`) so a reviewer can diff a suite line-for-line against its
   `.ts` source.
3. **Header pointer.** Each reference file starts with a comment naming the exact
   vscode source path it ports and the submodule commit it was taken from.
4. **Un-portable cases.** A case needing DI/services, async, or DOM
   `client-rect` measurement is not silently dropped: adapt it to our seam, or
   leave an explicit `// SKIPPED (covered by Playwright tests/): ...` marker
   naming the harness test that covers it. "Skipped" never means "untested."
5. **One reference file per vscode source file** wherever practical, to keep the
   mapping one-to-one.

## Guardrails

- Public MoonBit package dependencies stay centered on the reusable viewer
  surface. Reference host dependencies live under `internal/shell` and flow
  toward shared domain packages:
  `internal/shell/web -> internal/shell/workbench -> viewer`, optional
  internal widgets, and protocol;
  `internal/shell/server_host_native/main -> internal/shell/server_host_native -> internal/shell/server`.
- Product code must not import from `codemirror/` or `vscode/`.
- Public packages must not import `moonbit-community/editor/internal/shell/*`.
- `viewer/*` packages use only the Rabbita API bindings (`rabbita/dom`,
  `rabbita/js`), never the Rabbita TEA framework (`rabbita`, `rabbita/html`,
  `rabbita/cmd`, `rabbita/websocket`).
- Packages that only run on one host target may declare that host's FFI.
  Packages shared across targets must not declare FFI.
- `codemirror/` and `vscode/` are references only.
- `internal/shell/workbench`, `internal/shell/web`, `internal/shell/server`,
  and `internal/shell/server_host_native` are the reference shell/backend
  stack. They must not become required by the reusable viewer.
