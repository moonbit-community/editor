# Browser Tests

Playwright coverage for behavior that needs a real browser. The complete
harness split and commands live in `docs/harness.md`; this file contains only
browser-suite authoring contracts.

## Suites

```text
support/    Playwright fixtures, app helpers, logging, reporter
smoke/      user workflows against the workbench or embedded viewer
component/  loaders/assertions for direct MoonBit Viewer pages
perf/       structured, currently non-budgeted timing evidence
moonbit/    js-target MoonBit scenario packages
```

- Smoke tests prefer real gestures and visible outcomes. Use helpers from
  `support/app.js`; do not call deterministic state-control globals when a
  user path exists. Workbench files are selected through the sidebar and
  remote protocol—the active document is not URL state.
- Component pages construct the public Viewer directly and report compact JSON
  through `__readonlyEditorBrowserTestReport`. Playwright validates the report,
  browser/page/request errors, and visible state and owns final pass/fail.
- Perf tests attach structured evidence but do not fail on a timing budget
  unless one is explicitly documented.
- Monaco parity belongs in ported MoonBit unit/reference tests, not browser DOM
  snapshot comparison.

## Stable selectors and observability

- Shell: `.editor-shell` with `data-status`, `data-theme`, `data-line-count`,
  and `data-source-uri`.
- Tree rows: `.workspace-sidebar [data-workspace-id]` with
  `data-workspace-kind`, `aria-expanded`, and `aria-selected`.
- Viewer: `.monaco-editor.readonly-editor` and `.view-line[data-line]`.
- Product observability: `__readonlyEditorEvent`, `__readonlyEditorModel`,
  `__readonlyEditorDocument`, `__readonlyEditorSource`,
  `__readonlyEditorCopiedText`, and `__readonlyEditorCopiedHtml`.
- Reporter callback: `__readonlyEditorBrowserTestReport`; the Playwright
  reporter stores received payloads in `__readonlyEditorBrowserTestReports`.

MoonBit scenarios are built by `scripts/build-web.mbtx` into
`web/dist/browser-tests/`. A report has the shape
`{"suite":"viewer_api","status":"passed","failures":[],"metrics":{}}`.

`support/test.js` captures runner logs, console/page/request/HTTP failures,
traces, and failure screenshots. Set `READONLY_EDITOR_TEST_VERBOSE=1` or
`PW_VERBOSE=1` to mirror logs to the terminal.
