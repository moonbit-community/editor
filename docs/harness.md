# Harness

The harness exists to validate the reusable viewer through both direct
component pages and the reference workbench/backend shell. It should make
behavior inspectable without hidden setup.

## Layers

1. Baseline compiler/build checks.
2. MoonBit unit tests: DOM-free package tests (vscode's `editor/test/common`).
3. Headless viewer harness: drives a real `Viewer` + `ViewModel` +
   `CursorsController` with no DOM view, asserting on semantic state (vscode's
   `editor/test/browser/testCodeEditor.ts`). See "Headless Viewer Harness".
4. Browser suites split by purpose: smoke, conformance, component, and
   performance.

Baseline and unit layers should stay boring: no errors, and no new warnings.
Browser tests use Playwright for process/browser lifecycle, user gestures,
outer assertions, logging, screenshots, traces, and final pass/fail decisions.

## Commands

- `just check`: runs `moon check --target all --warn-list +73` plus
  `scripts/check-architecture.mbtx`.
- `just build`: runs `just check`, builds `web/dist` including browser-test
  assets, and builds `internal/shell/server_host_native/main`.
- `just test`: runs `moon test --target all`.
- `just test-browser`: builds first, starts the native server, and runs all
  default Playwright browser suites.
- `just test-browser-smoke`: user-like app workflows.
- `just test-browser-conformance`: Monaco/VS Code parity and deterministic
  geometry/control checks.
- `just test-browser-component`: MoonBit-authored browser component checks.
- `just test-browser-perf`: non-budgeted performance evidence.
- `just dev ROOT=. PORT=5173`: build and run the reference backend shell for
  local inspection. Use `ROOT=/path/to/project` to point the workbench at a
  fixture or real MoonBit project.

Playwright targets `http://127.0.0.1:5173` by default. Set
`READONLY_EDITOR_BASE_URL=http://127.0.0.1:<port>` to run browser tests against
an already-started server. The default Playwright server uses the deterministic
workspace fixture at `tests/fixtures/workspace`.

## Headless Viewer Harness

`viewer/test_viewer_wbtest.mbt` is the MoonBit analog of vscode's
`editor/test/browser/testCodeEditor.ts` (`withTestCodeEditor`). It constructs a
real `Viewer` *without* `attach()` — no DOM view, mirroring
`TestCodeEditor._createView` returning `null` — and drives the full
model/view-model/cursor pipeline over an in-memory model. `set_model` builds the
tokenized document, view model, render frame, and cursor context synchronously;
`schedule_render`/`flush_render` no-op while the view is `None`, so the semantic
state is fully populated with no `requestAnimationFrame` and no measurement.

Use `with_test_viewer(text, viewer => { ... })` and assert on semantic state:
positions, ranges, projected view lines (`coordinates_converter()`), and render
frames (`test_frame()` / `test_refresh_frame()`). `RenderFrame` is `pub(all)`
with a `ToJson` impl, so a frame can also be asserted as golden JSON. Soft wrap
and the viewport are normally measured from the DOM, so the harness exposes
`test_set_soft_wrap_column` and `test_set_viewport` to drive them headlessly.

The rule: **a behavior expressible as a position, range, line string, token
array, or frame is tested here with `with_test_viewer` (run by `just test`), not
in Playwright.** Cursor motion, soft-wrap view↔model mapping, and scroll-window
math are harness tests. Playwright is reserved for wiring (smoke) and the
conformance specs that need a real browser for DOM structure, flush,
measurement, and pointer hit-testing against the actual readonly editor.

## Browser Layout

```text
tests/browser/
  README.md       browser package contracts, globals, and authoring rules
  support/        Playwright fixtures, app helpers, logger, MoonBit reporter
  smoke/          user workflows against the real app or embedded viewer
  conformance/    exact DOM/style/geometry parity, deterministic hooks
  component/      Playwright loaders for MoonBit browser component pages
  perf/           Playwright and MoonBit performance evidence
  fixtures/       shared browser fixture data
  moonbit/        js-target MoonBit browser-test packages
```

`scripts/build-web.mbtx` assembles owner-adjacent CSS into `web/dist/style.css`
from the viewer and internal shell packages, and builds the MoonBit
browser-test packages into
`web/dist/browser-tests/component.html` and `web/dist/browser-tests/perf.html`.
See `tests/browser/README.md` for package-level authoring rules, selectors, and
globals. Monaco-specific hover and scrollbar contracts live in
`tests/browser/conformance/README.md`.

## Suite Boundaries

- Smoke: startup, native-served assets, file-tree navigation, document opening,
  real hover through pointer interaction, scrolling by wheel/drag, theme
  changes, embedded viewer loading, and file-watch recovery through the
  reference shell. Smoke tests should not call deterministic state-control
  globals when a user path exists.
- Conformance: Monaco/VS Code parity against the real readonly editor — forced
  hover payloads, exact scrollbar/hover DOM, computed style, geometry,
  screenshots, and the DOM-wiring side of scroll/windowing (only visible nodes
  mount, scrollbar, scroll-to-bottom reveal). Parity is held by porting Monaco
  logic into the viewer, not by diffing a copied reference page. The *semantic*
  windowing and view↔model projection assertions live in the headless viewer
  harness, not here.
- Component: MoonBit browser pages construct the public viewer API directly,
  without the internal workbench/backend shell, and report compact JSON through
  Playwright.
- Performance: structured JSON evidence and attachments. Perf tests remain
  non-failing unless an explicit documented budget is added.

## Browser Rules

Workbench smoke tests should select files through the sidebar and native remote
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
