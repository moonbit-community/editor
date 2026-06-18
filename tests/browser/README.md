# Browser Tests

This package contains Playwright browser tests for the readonly editor. The
top-level harness map lives in `docs/harness.md`; this file owns the browser
package contracts that test authors need while editing specs.

## Layout

```text
tests/browser/
  support/        shared Playwright fixtures, app helpers, logging, reporters
  smoke/          user workflows against the real app or embedded viewer
  conformance/    Monaco/VS Code parity and deterministic DOM checks
  component/      Playwright loaders for MoonBit browser component pages
  perf/           structured performance evidence
  fixtures/       shared browser fixture data
  moonbit/        js-target MoonBit browser-test packages
```

## Stable Application Contracts

Prefer helpers from `tests/browser/support/app.js` before spelling selectors in
individual specs. When a spec needs direct assertions, keep them on these stable
application contracts:

- Shell readiness and active document state use `.editor-shell` attributes:
  `data-status`, `data-theme`, `data-line-count`, and `data-source-uri`.
- Workspace navigation uses `.workspace-sidebar` rows with
  `data-workspace-id`, `data-workspace-kind`, `aria-expanded`, and
  `aria-selected`.
- Readonly viewer rendering uses `.monaco-editor.readonly-editor` and
  `.view-line[data-line]`.

The active file is application state, not URL state. Specs should select files
through the sidebar and native remote protocol, not `?uri=`, `?path=`, hashes,
or history updates.

## Suite Rules

Smoke specs are user-like workflows. They may select stable visible targets, but
they should not call deterministic state-control globals when a real user path
exists.

Conformance specs are allowed to be precise and internal. Monaco-specific
hover, scrollbar, style, geometry, and oracle contracts are documented in
`tests/browser/conformance/README.md`.

Component specs load MoonBit-authored browser pages and validate the compact
JSON report. Perf specs collect structured timing evidence and stay
non-budgeted until a budget is explicitly documented.

## Globals

Keep globals narrow and classify them by purpose:

- Product observability: `__readonlyEditorEvent`,
  `__readonlyEditorModel`, `__readonlyEditorDocument`,
  `__readonlyEditorSource`, and
  `__readonlyEditorCopiedText`.
- Conformance/control only: `__readonlyEditorSetHover`,
  `__readonlyEditorClearHover`, `__readonlyEditorScrollTo`, and
  `__readonlyEditorConformance`.
- MoonBit browser-test reporting:
  `__readonlyEditorBrowserTestReport`.

Smoke specs should not use conformance/control globals unless there is no
realistic browser path. Conformance specs may use them when deterministic setup
or measurement is the point of the test.

## MoonBit Browser Pages

`tests/browser/moonbit/*` packages are ordinary `js` target MoonBit packages.
They are built by `scripts/build-web.mbtx` into `web/dist/browser-tests/`.

MoonBit pages report through `__readonlyEditorBrowserTestReport` using compact
payloads like:

```json
{"suite":"viewer_api","status":"passed","failures":[],"metrics":{}}
```

Playwright owns the final pass/fail result. It validates report shape, attaches
the JSON, and still checks page errors, request failures, and visible browser
state.

## Failure Evidence

`tests/browser/support/test.js` records `runner.log`, browser console messages,
page errors, failed requests, HTTP errors, traces, and screenshots on failure.
Set `READONLY_EDITOR_TEST_VERBOSE=1` or `PW_VERBOSE=1` to mirror logs to the
terminal.
