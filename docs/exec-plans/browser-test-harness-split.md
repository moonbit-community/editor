# Browser Test Harness Split

Status: implemented.
Date: 2026-06-16

## Summary

Refactor the browser test harness so it matches the way we want to reason about
quality:

1. Baseline checks stay compiler/build focused: `moon check` and `moon build`
   without warnings or errors.
2. Unit tests stay MoonBit focused: `moon test`.
3. Browser tests split into smoke, conformance, component, and performance
   suites instead of one flat e2e bucket.

The browser harness should copy the useful part of VS Code's structure:
Playwright owns browser/process lifecycle, logging, screenshots, traces,
external user gestures, outer assertions, and the final test result. Test code
talks through a small automation layer.

This project can also have MoonBit-authored browser tests where that gives
better coverage of the viewer public API or more repeatable performance
scenarios. In those cases, MoonBit owns the in-page scenario and API-level
assertions, then reports structured observations back to Playwright. Playwright
still asserts user-visible behavior, report validity, budgets when they exist,
and failure evidence. This hybrid model gives us both: VS Code-style smoke
tests and MoonBit-authored browser checks without turning smoke into a pile of
test-control globals.

Do not update `docs/harness.md` ahead of the implementation. Once this plan is
implemented, update `docs/harness.md` to describe the real directories,
commands, browser contracts, and remaining test-only globals that actually
exist.

## Current State

Browser tests currently live flat under `tests/browser`:

```text
tests/browser/
  base.js
  logger.js
  embed.spec.js
  hover.spec.js
  monaco_conformance.spec.js
  perf.spec.js
  scroll.spec.js
  viewer.spec.js
  workbench.spec.js
  fixtures/
```

`playwright.config.js` points `testDir` at `tests/browser`, starts
`just dev ROOT=docs/fixtures/project PORT=<port>`, and retains traces and
screenshots on failure.

The current suite mixes several different purposes:

- user-visible workflows such as startup, explorer navigation, hover, scrolling,
  theme changes, and embedded viewer loading;
- Monaco/VS Code parity checks through `monaco_conformance.spec.js`;
- a non-failing performance probe in `perf.spec.js`;
- repeated local helpers for opening workspace files and reading browser events;
- Playwright calls to test-only globals such as
  `__readonlyEditorSetHover`, `__readonlyEditorScrollTo`, and
  `__readonlyEditorConformance`.

That shape works, but it makes smoke tests carry too much deterministic control
logic. It also makes it unclear which assertions are user workflow coverage,
which are exact reference conformance, and which are evidence gathering.

## VS Code Pattern To Copy

Use VS Code as a structural reference, not as product code:

- launch the app in a test mode;
- centralize logging, screenshots, traces, polling, and app helpers;
- expose one explicit browser automation surface only for tests;
- keep smoke tests readable by moving low-level selectors and waiting into
  shared helpers.

VS Code exposes `window.driver` only when `--enable-smoke-test-driver` is set.
It does not use a single global result object for smoke tests. Its test results
come from the outer Mocha/Playwright runner.

Our MoonBit-authored browser pages add one extra need: if a scenario or
assertion runs inside MoonBit-compiled JS, Playwright needs a reporting channel
to collect the result. That channel should be passive and narrow, not a new
family of product-control globals.

## Target Layout

Move toward this layout:

```text
tests/browser/
  support/
    test.js
    logger.js
    app.js
    moonbit_reporter.js
  smoke/
    viewer.spec.js
    workbench.spec.js
    hover.spec.js
    scroll.spec.js
    embed.spec.js
  conformance/
    monaco_hover_scrollbar.spec.js
  component/
    viewer_api.spec.js
  perf/
    viewer_render.spec.js
  fixtures/
    monaco_conformance_payloads.js
  moonbit/
    support/
      moon.pkg
      assert.mbt
      browser_reporter.mbt
      fixtures.mbt
    component/
      moon.pkg
      main.mbt
      viewer_api_test.mbt
    perf/
      moon.pkg
      main.mbt
      render_perf_test.mbt
```

`tests/browser/moonbit/*` packages must be ordinary `js` target MoonBit
packages. They should be included by `moon check --target all` so the browser
test logic does not silently drift from product APIs.

The exact file names may change during implementation, but the boundaries must
remain:

- `support`: Playwright fixtures, logging, app wrappers, and report collection;
- `smoke`: user-like workflows against the real app;
- `conformance`: reference-backed Monaco/VS Code parity;
- `component`: MoonBit-authored browser tests of public viewer APIs, with
  Playwright validating and reporting the result;
- `perf`: MoonBit-authored scenarios plus Playwright-authored assertions,
  evidence collection, and optional budgets.

## Reporting Channel

Do not add `globalThis.__moonbitBrowserTestResult = {...}` as a broad product
global.

Add one test-only reporting path for MoonBit browser test pages:

- Playwright installs a reporter before navigation, for example a function named
  `globalThis.__readonlyEditorBrowserTestReport`.
- The MoonBit test package has one JS FFI in
  `tests/browser/moonbit/support/browser_reporter.mbt`.
- The FFI sends a compact JSON payload to the Playwright reporter when present
  and also logs a console line prefixed with `[readonly-editor-browser-test]`.
- Playwright treats that payload as one input to the outer browser test. The
  outer spec fails if any MoonBit assertion failed, if the report is malformed or
  missing, or if Playwright-authored assertions fail.

The payload should be stable and small:

```json
{
  "suite": "viewer_api",
  "status": "passed",
  "failures": [],
  "metrics": {}
}
```

This is not a smoke-test driver. It is a result channel for pages whose in-page
scenario or API assertions ran in MoonBit. Smoke and perf specs may still have
Playwright-authored assertions around visible behavior, page errors, report
shape, traces, screenshots, and budgets.

Avoid duplicating the same expectation in both places. MoonBit should assert the
API/model invariant it is uniquely positioned to see; Playwright should assert
the browser-visible consequence and own the final pass/fail decision.

## Suite Boundaries

### Smoke

Smoke tests are user-like workflows. They may use Playwright actions and stable
DOM contracts, but should not call direct state-control globals unless there is
no realistic user path.

Keep smoke coverage for:

- app startup and ready state;
- workspace tree expansion and file opening;
- readonly viewer rendering;
- hover through pointer/focus behavior;
- editor scrolling through wheel/keyboard/pointer paths;
- diagnostics visibility;
- theme changes;
- embedded viewer loading.

Smoke tests should not compare Monaco internals, force hover payloads, or drive
scroll position through `__readonlyEditorScrollTo` when a real wheel or pointer
action can cover the workflow.

Smoke tests can still consume structured browser events emitted by MoonBit
product code. If a smoke workflow also needs a MoonBit-authored invariant, keep
it passive: the app reports observations, and Playwright asserts both the
observation and the visible state. Do not add state-control FFIs only to make
smoke easier to script.

### Conformance

Conformance tests are allowed to be precise and internal. They compare this
viewer to pinned Monaco/VS Code behavior or to a local oracle.

Keep here:

- `tests/reference/monaco-hover-scrollbar/`;
- `__readonlyEditorConformance`;
- exact DOM subtree checks;
- computed style checks;
- geometry checks;
- scrollbar/hover interaction parity;
- screenshots as supporting evidence.

Conformance can keep narrow test-only hooks because the point is deterministic
reference comparison, not user workflow coverage.

### Component

Component tests are browser-executed MoonBit tests. They should construct the
viewer through public APIs and verify the API contract from MoonBit.

Use component tests for:

- creating a readonly viewer with fixture documents;
- opening/changing documents through public viewer services;
- receiving viewer notifications;
- registering hover/diagnostic providers;
- verifying rendered readonly DOM state through browser DOM APIs available to
  the MoonBit JS target;
- exercising API edge cases that are awkward to drive through the full
  workbench.

The outer Playwright spec should only load the component test page, collect the
MoonBit report, attach useful diagnostics, and fail on reported failures.

### Performance

Performance tests are evidence and trend recording first. They should not become
hard gates until the repo has stable baselines.

Record:

- document open/render timings for small and large fixtures;
- tokenization/build/patch timings from structured browser events;
- scroll frame timing or settle time for large documents;
- hover show/update timing for small and large hover payloads;
- sample count, warmup count, best, median, p95, and worst.

Performance tests should deliberately use both layers:

- MoonBit owns repeatable in-page scenarios, API-level timing marks, render
  samples, and scenario-specific invariants.
- Playwright owns browser setup, user-level timing when needed, console/page
  error checks, trace/screenshot/JSON attachments, report-shape assertions, and
  hard budgets once documented.

The MoonBit perf page should own the scenario loop where it is testing public
viewer API behavior. Playwright should attach JSON metrics and traces and may
assert budgets or regressions once the repo has stable baselines.

## Implementation Phases

### Phase 1: Centralize Playwright Support

- Move `tests/browser/base.js` and `tests/browser/logger.js` into
  `tests/browser/support/`.
- Add `tests/browser/support/app.js` for common app operations:
  `gotoApp`, `waitForReady`, `workspaceItem`, `openWorkspaceFile`,
  `collectReadonlyEvents`, and stable hover/scroll helpers.
- Update existing specs to import from `support/`.
- Keep behavior unchanged in this phase.

Exit criteria:

- `just test-browser` still passes.
- No test has changed purpose yet; only imports and shared helpers moved.

### Phase 2: Split Existing Specs By Purpose

- Move user workflow specs to `tests/browser/smoke/`.
- Move Monaco parity spec to `tests/browser/conformance/`.
- Move performance probe to `tests/browser/perf/`.
- Keep shared fixtures under `tests/browser/fixtures/`.
- Update `playwright.config.js` only as needed so `just test-browser` still runs
  all browser suites by default.

Expected moves:

- `viewer.spec.js`, `workbench.spec.js`, `embed.spec.js` -> `smoke/`.
- User-path portions of `hover.spec.js` and `scroll.spec.js` -> `smoke/`.
- Forced payload or exact measurement portions of hover/scroll tests ->
  `conformance/` or `component/`.
- `monaco_conformance.spec.js` -> `conformance/`.
- `perf.spec.js` -> `perf/`.

Exit criteria:

- The directory names communicate the purpose of each browser test.
- Smoke tests no longer depend on `__readonlyEditorConformance`.
- `just test-browser` still passes.

### Phase 3: Add MoonBit Browser Test Reporter

- Add `tests/browser/moonbit/support` as a JS-only MoonBit package.
- Add a tiny assertion helper that accumulates failures instead of aborting the
  page before it can report diagnostics.
- Add `browser_reporter.mbt` with the single JS FFI reporting seam.
- Add `tests/browser/support/moonbit_reporter.js` to install the Playwright
  reporter, wait for the result, parse console fallback lines, and attach the
  JSON report.
- Do not put this reporter in product packages such as `dom` or
  `renderer/browser`.

Exit criteria:

- A minimal MoonBit browser test page reports pass/fail to Playwright.
- `moon check --target all` checks the MoonBit browser test support package.
- There is one reporting seam, not multiple feature-specific test globals.
- Playwright remains the final authority for the browser test result.

### Phase 4: Add MoonBit Component Tests

- Add `tests/browser/moonbit/component` as a JS main package.
- Build it into a static browser-test asset, for example under
  `web/dist/browser-tests/component.mjs`.
- Add a minimal HTML page that loads the component bundle and `style.css`.
- Add `tests/browser/component/viewer_api.spec.js` that opens the page and
  asserts the MoonBit report.
- Port API-level viewer assertions from Playwright or add new assertions where
  Playwright currently cannot test the public MoonBit API directly.

Prefer public viewer/workbench APIs. If a test needs a private detail, first ask
whether it belongs in a MoonBit unit test or conformance test instead.

Exit criteria:

- At least one meaningful viewer public API flow is tested from MoonBit in the
  browser.
- Playwright is the loader/reporter and may assert report shape, page errors,
  visible readiness, and attachments for that component test.
- Existing smoke coverage is not weakened.

### Phase 5: Add MoonBit Performance Scenarios

- Add `tests/browser/moonbit/perf` as a JS main package.
- Move repeatable performance scenario control into MoonBit where it uses public
  viewer APIs.
- Keep Playwright responsible for page setup, trace/screenshot attachment, and
  storing metrics in `test-results/browser`.
- Keep Playwright assertions for report shape, browser errors, visible readiness,
  and documented budgets.
- Replace the stale comment in `tests/browser/perf.spec.js` that refers to a
  harness budget that no longer exists.
- Keep perf non-failing unless an explicit budget is added and documented.

Exit criteria:

- Perf output is structured JSON, not only terminal text.
- Reports include samples and summary statistics.
- `just test-browser` can run perf evidence without making CI flaky.

### Phase 6: Reduce Existing Test Globals

Audit every browser global used by tests:

- `__readonlyEditorEvent`
- `__readonlyEditorDocument`
- `__readonlyEditorSource`
- `__readonlyEditorCopiedText`
- `__readonlyEditorSetHover`
- `__readonlyEditorClearHover`
- `__readonlyEditorScrollTo`
- `__readonlyEditorConformance`
- the new `__readonlyEditorBrowserTestReport` reporter

Classify each as:

- product observability;
- conformance-only control;
- component/perf reporting;
- obsolete.

Then remove or narrow obsolete globals. In particular:

- smoke tests should stop using `__readonlyEditorSetHover`,
  `__readonlyEditorScrollTo`, and `__readonlyEditorConformance` unless no
  user-like path can cover the behavior;
- conformance can keep `__readonlyEditorConformance`;
- component/perf should use only the single reporter seam for MoonBit in-page
  results, while Playwright keeps its own outer assertions.

Exit criteria:

- The test-control surface is smaller and documented.
- No new feature-specific MoonBit JS FFI is added for smoke.

### Phase 7: Update Harness Documentation

Only after the code and tests above exist, update `docs/harness.md` to describe
the real harness:

- baseline commands and no-warning expectation;
- unit-test command;
- browser suite split: smoke, conformance, component, performance;
- actual `just` commands or Playwright filters that exist after the refactor;
- which suites run by default in `just test-browser`;
- which globals are observability, conformance-only, or test-result reporting;
- where logs, traces, screenshots, and perf JSON are written;
- the rule that smoke tests are user-like and should not grow deterministic
  control FFIs.

Do not document future commands that were not added. The harness document should
describe the shipped state after the implementation, not this plan.

## Command Shape

The implementation may choose exact command names, but the intended shape is:

```sh
just test-browser              # all browser suites that are stable by default
just test-browser-smoke        # user workflows
just test-browser-conformance  # Monaco/VS Code parity
just test-browser-component    # MoonBit browser component tests
just test-browser-perf         # performance evidence
```

If adding separate `just` recipes is too much for the first pass, use Playwright
project names or path filters and document the exact commands in
`docs/harness.md` after they exist.

## Validation

Run these before marking the plan implemented:

```sh
just check
just test
just build
just test-browser
git diff --check
```

Also run focused browser commands for each suite if separate commands were
added.

For documentation-only intermediate commits, `git diff --check` is sufficient.
For implementation commits, do not skip the full validation unless there is a
clear local blocker recorded in the handoff.

## Completion Criteria

This plan is complete when:

- browser specs are split by purpose;
- common Playwright helpers live under `tests/browser/support`;
- smoke tests are user-like and avoid conformance/control globals;
- Monaco parity tests live under `tests/browser/conformance`;
- at least one browser-executed MoonBit component test reports through the
  single reporter seam;
- performance evidence is structured, produced by MoonBit where appropriate, and
  asserted/attached by Playwright;
- obsolete test globals are removed or documented as intentionally retained;
- `docs/harness.md` matches the implemented harness exactly;
- validation passes.

## Non-Goals

- Do not rewrite the entire browser runner in MoonBit in this plan. Playwright
  remains the process/browser lifecycle runner, matching VS Code's practical
  shape.
- Do not import from `vscode/` or `codemirror/` product code.
- Do not turn smoke tests into exact Monaco conformance tests.
- Do not add many MoonBit JS FFIs to control product internals from smoke.
- Do not add hard performance budgets until baseline data is stable and the
  budget is documented.
