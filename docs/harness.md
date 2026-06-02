# Harness

The harness is designed so agents can inspect, run, and debug the project
without hidden setup.

## Commands

- `npm run check`: MoonBit type check plus architecture guardrails.
- `npm run test`: MoonBit unit tests.
- `npm run build`: MoonBit web build plus Vite production build.
- `npm run test:browser`: Playwright smoke tests.
- `npm run dev`: build generated MoonBit JS and serve the browser viewer.

The npm harness uses MoonBit `.mbtx` scripts in `scripts/` for helper tasks.

## Browser Observability

The browser host logs structured events prefixed with `[readonly-editor]`:

- `moonbit:render`: source line count, token count, diagnostic count.
- `dom:mounted`: rendered line and diagnostic counts after DOM creation.

These events are intentionally stable so automated agents can diagnose render
failures from console output.
