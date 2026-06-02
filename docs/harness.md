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

## Browser Observability

The browser host logs structured events prefixed with `[readonly-editor]`:

- `moonbit:render`: source line count, token count, diagnostic count.
- `dom:mounted`: rendered line and diagnostic counts after DOM creation.

These events are intentionally stable so automated agents can diagnose render
failures from console output.
