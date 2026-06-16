# Harness

The harness is designed so agents can inspect, run, and debug the project
without hidden setup.

## Layers

The harness has three layers:

1. Baseline compiler and build checks.
2. MoonBit unit tests.
3. Browser e2e smoke tests for integrated behavior that unit tests cannot
   cover.

The first two layers should stay boring: if product code changes, it should
pass the baseline and unit-test layers without warnings or errors. The e2e
layer is intentionally narrower and should record user-visible workflows, not
every DOM detail.

## Commands

- `just check`: baseline check. Runs
  `moon check --target all --warn-list +73` plus
  `scripts/check-architecture.mbtx`.
- `just build`: baseline build. Depends on `just check`, builds the browser
  bundle into `web/dist`, and builds `server_host_native/main`.
- `just test`: unit tests. Runs `moon test --target all`.
- `just test-browser`: e2e smoke tests. Builds first, starts the native server,
  and runs Playwright.
- `just dev ROOT=. PORT=5173`: build and run the native server for local
  inspection. Use `ROOT=/path/to/project` to point the viewer at a fixture or
  real MoonBit project.

Playwright targets `http://127.0.0.1:5173` by default. Set
`READONLY_EDITOR_BASE_URL=http://127.0.0.1:<port>` to run smoke tests against
an already-started server.

## What Belongs Where

- Baseline: package graph changes, host-target filtering, FFI boundaries,
  generated browser assets, and native server build health.
- Unit tests: pure package behavior, protocol round trips, workspace semantics,
  renderer model state, and cross-target logic.
- E2e smoke tests: startup, file-tree navigation, document opening, diagnostics,
  hover, scrolling, theme changes, and native server/protocol integration.

Smoke tests are inspired by VS Code/Monaco smoke tests: cover realistic
workflows and regression-prone integration points, but avoid encoding every
internal node, style, or timing detail as a public contract.

## Browser Contracts

Keep browser assertions on stable harness contracts:

- Shell readiness and active document state:
  `.editor-shell[data-status][data-theme][data-line-count][data-source-uri]`.
- Workspace navigation:
  `.workspace-sidebar` rows with `data-workspace-id`, `data-workspace-kind`,
  `aria-expanded`, and `aria-selected`.
- Readonly viewer surface:
  `.moonbit-viewer.readonly-editor`,
  `.monaco-scrollable-element.editor-scrollable`,
  `.view-line[data-line]`, and
  `[data-content-widget="hover"] .monaco-hover`.
- Scroll and conformance helpers:
  `globalThis.__readonlyEditorScrollTo(top)` for ordinary scroll assertions;
  `globalThis.__readonlyEditorConformance` and the local Monaco oracle under
  `tests/reference/monaco-hover-scrollbar/` for Monaco-specific conformance.

Browser tests should select files through the sidebar and native remote
protocol. The active file is application state, not URL state; specs should not
depend on `?uri=`, `?path=`, hashes, or history updates.

## Failure Evidence

`tests/browser/base.js` records smoke-test evidence:

- `runner.log` under `test-results/browser/...`;
- browser console messages, page errors, failed requests, and HTTP errors;
- Playwright traces and screenshots on failure.

Set `READONLY_EDITOR_TEST_VERBOSE=1` or `PW_VERBOSE=1` to mirror smoke logs to
the terminal. Runtime browser events use the `[readonly-editor]` prefix and are
diagnostic evidence, not a substitute for user-visible assertions.
