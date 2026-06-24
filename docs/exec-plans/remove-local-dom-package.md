# Remove Local `dom` Package

## Summary

Remove the local `dom` package by moving its remaining narrow JavaScript FFI
declarations into the JS-only packages that own each browser effect. This is a
focused follow-up to the Rabbita browser migration: `dom` is no longer a broad
app boundary, and its current callers are limited to `renderer/browser` and
`workbench`.

The end state is:

- no product package imports `moonbit-community/editor/dom`;
- `dom/` is deleted;
- `renderer/browser` owns viewer-only timing FFI;
- `workbench` owns reference-app, harness, storage, and protocol URL browser
  FFI;
- shared packages remain browser-FFI-free.

## Key Changes

- Move viewer runtime browser helpers into `renderer/browser`, in a small
  focused file such as `browser_host.mbt`:
  - `now_ms`
  - `set_timeout`
  - `clear_timeout`
  - update render timing, hover delay, and scrollbar hide-delay call sites to
    use package-local functions.

- Move workbench/reference-app browser helpers into `workbench`, in a focused
  file such as `browser_host.mbt`:
  - harness event installation and emission;
  - current-document exposure globals;
  - scroll, hover fixture, and conformance Playwright hooks;
  - `localStorage` theme persistence;
  - protocol WebSocket URL derivation.

- Delete the local `dom` package after all imports are gone:
  - remove `dom/README.md`, `dom/browser_host.mbt`, `dom/moon.pkg`, and
    generated interface output;
  - remove `moonbit-community/editor/dom` from `renderer/browser/moon.pkg` and
    `workbench/moon.pkg`.

- Update documentation and architecture guardrails:
  - `docs/architecture.md`: remove `dom` from the component map and dependency
    diagram; replace the placement rule with "JS-only browser packages may
    declare narrowly scoped JS FFI for effects they own; shared packages must
    remain FFI-free."
  - `renderer/browser/README.md`: replace references to `dom` timer bindings
    with package-local browser-host helpers and state that viewer-only FFI may
    live in `renderer/browser`.
  - `workbench/README.md`: remove `dom` as an allowed dependency and state that
    workbench owns harness/browser-host observability helpers.
  - `scripts/check-architecture.mbtx`: remove `dom` from allowed browser
    package imports and keep shared-package rules preventing browser FFI or
    browser packages from leaking into target-neutral packages.

## Test Plan

- Run `rg '@dom\\.|moonbit-community/editor/dom|editor/dom'` and confirm there are no
  product imports or call sites.
- Run `moon info` and verify generated public interfaces only change where
  expected because the `dom` package is gone.
- Run `just check` to validate package imports and architecture rules.
- Run `just test` for MoonBit unit coverage.
- Run `just build` to verify generated browser/native artifacts still compile.
- Run `just test-browser` to verify harness events, conformance controls, hover
  timing, scroll controls, theme persistence, and protocol URL behavior still
  work.

## Assumptions

- This is a behavior-preserving refactor; no harness global names, event
  payloads, CSS selectors, or public viewer APIs should change.
- Do not create a replacement broad package such as `browser_host` at the repo
  root.
- Do not move any JS FFI into target-neutral packages such as `renderer`,
  `workspace`, `language`, `syntax`, or `platform/log`.
- It is acceptable for both `renderer/browser` and `workbench` to declare small
  local `extern "js"` functions because both packages are JS-only
  (`supported_targets = "js"`).
