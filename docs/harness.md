# Harness

Use the lowest layer that can observe the behavior. Browser tests are for DOM,
pointer, browser-layout, and full-shell behavior—not for state that a MoonBit
test can assert directly.

## Commands

```sh
just check                   # check all targets, format, architecture guards
just test                    # all MoonBit tests
just build                   # check + browser assets + native server
just test-browser            # all Playwright suites
just test-browser-smoke      # reference app and user workflows
just test-browser-component  # direct Viewer component pages
just test-browser-perf       # non-budgeted performance evidence
just dev ROOT=. PORT=5173    # build and run the reference app
```

Playwright defaults to `http://127.0.0.1:5173` and the deterministic
`tests/fixtures/workspace`. Set `READONLY_EDITOR_BASE_URL` to target an already
running server.

## Test Layers

### MoonBit package tests

Use ordinary tests for DOM-free algorithms and `*_reference_test.mbt` /
`*_reference_wbtest.mbt` for traceable Monaco conformance ports. See
`docs/quality.md` for the reference-test contract.

### Headless Viewer tests

`viewer/test_viewer_wbtest.mbt` constructs a real, unattached `Viewer`, installs
a `TextModel`, and exercises its synchronous model/view-model/cursor/layout
state. No browser `View`, DOM measurement, or animation frame is created.

Useful white-box seams are:

- `with_test_viewer`
- `test_view_model` and `test_cursor`
- `test_window`
- `test_set_soft_wrap_column`
- `test_set_viewport`

Use this layer for positions, selections, wrapping, model/view conversion,
visible windows, scroll/reveal math, decoration inputs, and contribution state.

### Browser suites

```text
tests/browser/
  smoke/       real workbench/embed workflows and real pointer input
  component/   direct public-Viewer scenarios reported as compact JSON
  perf/        timing evidence; non-failing unless a budget is documented
  moonbit/     js-target scenario packages
  support/     Playwright fixtures, logging, and reporters
```

`scripts/build-web.mbtx` builds the reference app, embed page, and MoonBit
scenario bundles, then assembles owner-adjacent CSS and codicons under
`web/dist`.

## Browser Rules

- Smoke tests use the sidebar and remote protocol when testing the workbench;
  the active file is application state, not a URL query/hash.
- Prefer real gestures and visible outcomes. Use deterministic test globals only
  when no user path exists.
- Use Playwright for caret-API hit testing, measured selection/widget geometry,
  browser event wiring, server/file-watch integration, and screenshots/traces.
- Monaco parity comes from source-faithful code plus ported conformance tests,
  not browser DOM snapshots against Monaco.
- The MoonBit reporter only emits data; Playwright validates the report and
  owns pass/fail.

## Failure Evidence

`tests/browser/support/test.js` records `runner.log`, console/page/request
failures, traces, and screenshots under `test-results/browser/**`. Component and
perf suites also attach their JSON reports. Set
`READONLY_EDITOR_TEST_VERBOSE=1` or `PW_VERBOSE=1` to mirror logs to the terminal.

Package globals, selectors, and scenario-authoring details live in
`tests/browser/README.md`.
