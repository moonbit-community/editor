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

`just dev` exposes a browser LSP bridge at `/__readonly_editor_lsp`. The bridge
starts `moon-lsp --stdio` by default. For absolute local file viewing, allow the
target root through Vite and optionally pin the LSP working directory:

```bash
READONLY_EDITOR_FS_ALLOW=/path/to/moonbit/project \
READONLY_EDITOR_LSP_ROOT=/path/to/moonbit/project \
just dev --port 5173
```

The command and arguments can be overridden with
`READONLY_EDITOR_LSP_COMMAND` and `READONLY_EDITOR_LSP_ARGS`.

## Browser Observability

The browser host logs structured events prefixed with `[readonly-editor]`:

- `moonbit:render`: source line count, token count, diagnostic count.
- `lsp:initialize`: LSP client initialization state for the active document.
- `lsp:diagnostics`: active document diagnostic count and version after LSP sync.
- `lsp:hover`: successful on-demand hover resolution for the active document.
- `lsp:definition`: successful on-demand definition resolution for the active document.
- `lsp:error`: transport or protocol errors that did not block readonly render.
- `dom:mounted`: rendered line and diagnostic counts after DOM creation.

These events are intentionally stable so automated agents can diagnose render
failures from console output.
