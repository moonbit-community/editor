# Harness

The harness is designed so agents can inspect, run, and debug the project
without hidden setup.

## Commands

- `just check`: MoonBit type check.
- `just test`: MoonBit unit tests.
- `just build`: MoonBit web build plus Vite production build.
- `just test-browser`: Playwright smoke tests.
- `just dev`: build generated MoonBit JS and serve the browser viewer with Vite's static dev host.

The `justfile` harness uses `.mbtx` scripts in `scripts/` for helper tasks.

`just dev` serves the browser viewer and installs a semantic remote protocol
fallback for local/demo documents. For absolute local file viewing, allow the
target root through Vite:

```bash
READONLY_EDITOR_FS_ALLOW=/path/to/moonbit/project \
just dev --port 5173
```

## Browser Selectors

The browser app preserves stable DOM contracts for Playwright and agent
inspection:

- `.editor-shell` exposes `data-status`, `data-line-count`, and
  `data-source-uri`.
- `.workspace-sidebar` renders file and folder controls with
  `data-workspace-id`, `data-workspace-kind`, `aria-expanded`, and
  `aria-selected`.
- `.code-line`, `.gutter`, `.code`, token spans, diagnostics, hover data, and
  definition target attributes keep the same class and `data-*` contracts used
  by browser smoke tests.

Sidebar selection is app state only. Selecting or expanding workspace entries
must not change `window.location.href`.

## Browser Observability

The browser host logs structured events prefixed with `[readonly-editor]`:

- `moonbit:render`: source line count, token count, diagnostic count.
- `language:diagnostics`: active document diagnostic count and version after
  semantic provider sync.
- `language:hover`: successful on-demand hover resolution for the active
  document.
- `language:definition`: successful on-demand definition resolution for the
  active document.
- `language:error`: provider or protocol errors that did not block readonly
  render.
- `dom:mounted`: rendered line and diagnostic counts after DOM creation.

These events are intentionally stable so automated agents can diagnose render
failures from console output.
