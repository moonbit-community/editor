# Harness

The harness is designed so agents can inspect, run, and debug the project
without hidden setup.

## Layers

1. Baseline compiler/build checks.
2. MoonBit unit tests.
3. Browser suites split by purpose: smoke, conformance, component, and
   performance.

Baseline and unit layers should stay boring: no errors, and no new warnings.
Browser tests use Playwright for process/browser lifecycle, user gestures,
outer assertions, logging, screenshots, traces, and final pass/fail decisions.

## Commands

- `just check`: runs `moon check --target all --warn-list +73` plus
  `scripts/check-architecture.mbtx`.
- `just build`: runs `just check`, builds `web/dist` including browser-test
  assets, and builds `server_host_native/main`.
- `just test`: runs `moon test --target all`.
- `just test-browser`: builds first, starts the native server, and runs all
  default Playwright browser suites.
- `just test-browser-smoke`: user-like app workflows.
- `just test-browser-conformance`: Monaco/VS Code parity and deterministic
  geometry/control checks.
- `just test-browser-component`: MoonBit-authored browser component checks.
- `just test-browser-perf`: non-budgeted performance evidence.
- `just dev ROOT=. PORT=5173`: build and run the native server for local
  inspection. Use `ROOT=/path/to/project` to point the viewer at a fixture or
  real MoonBit project.

Playwright targets `http://127.0.0.1:5173` by default. Set
`READONLY_EDITOR_BASE_URL=http://127.0.0.1:<port>` to run browser tests against
an already-started server.

## Browser Layout

```text
tests/browser/
  README.md       browser package contracts, globals, and authoring rules
  support/        Playwright fixtures, app helpers, logger, MoonBit reporter
  smoke/          user workflows against the real app or embedded viewer
  conformance/    Monaco oracle, exact DOM/style/geometry, deterministic hooks
  component/      Playwright loaders for MoonBit browser component pages
  perf/           Playwright and MoonBit performance evidence
  fixtures/       shared browser fixture data
  moonbit/        js-target MoonBit browser-test packages
```

`scripts/build-web.mbtx` builds the MoonBit browser-test packages into
`web/dist/browser-tests/component.html` and `web/dist/browser-tests/perf.html`.
See `tests/browser/README.md` for package-level authoring rules, selectors, and
globals. Monaco-specific hover and scrollbar contracts live in
`tests/browser/conformance/README.md`.

## Suite Boundaries

- Smoke: startup, native-served assets, file-tree navigation, document opening,
  real hover through pointer interaction, scrolling by wheel/drag, theme
  changes, embedded viewer loading, and file-watch recovery. Smoke tests should
  not call deterministic state-control globals when a user path exists.
- Conformance: Monaco/VS Code parity, local oracle comparison under
  `tests/reference/monaco-hover-scrollbar`, forced hover payloads, exact
  scrollbar/hover DOM, computed style, geometry, screenshots, and synthetic
  scroll/windowing checks.
- Component: MoonBit browser pages construct the public viewer API directly and
  report compact JSON through Playwright.
- Performance: structured JSON evidence and attachments. Perf tests remain
  non-failing unless an explicit documented budget is added.

## Browser Rules

Browser tests should select files through the sidebar and native remote
protocol. The active file is application state, not URL state; specs should not
depend on `?uri=`, `?path=`, hashes, or history updates.

Smoke specs should prefer user gestures and visible outcomes. Conformance specs
may use deterministic hooks and exact DOM/style/geometry assertions when they
are checking reference parity.

The MoonBit reporter is passive. Playwright validates the report shape, attaches
the JSON, and owns the final test result.

## Failure Evidence

`tests/browser/support/test.js` records:

- `runner.log` under `test-results/browser/...`;
- browser console messages, page errors, failed requests, and HTTP errors;
- Playwright traces and screenshots on failure.

Component and perf specs attach MoonBit report JSON through
`tests/browser/support/moonbit_reporter.js`; perf specs also attach structured
timing JSON. Set `READONLY_EDITOR_TEST_VERBOSE=1` or `PW_VERBOSE=1` to mirror
logs to the terminal.
