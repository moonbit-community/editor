# Browser Remote Renderer Plan

## Goal

Move the readonly editor toward a MoonBit-first web/remote architecture for the
browser frontend:

- a MoonBit native remote server;
- a backend-agnostic MoonBit renderer;
- a MoonBit browser render backend.

This plan only covers the browser render backend.

## Target Shape

Packages to introduce or evolve:

- `remote_protocol`: MoonBit packet types, JSON encoding/decoding, protocol
  errors, and protocol-version negotiation.
- `server`: native MoonBit main package for remote document service, watch
  sessions, LSP session lifecycle, and request routing.
- `server_host_native`: narrow native host boundary for sockets, file reads,
  file watching, timers, and process spawning.
- `renderer`: backend-agnostic render state and render-frame construction.
- `renderer/browser`: browser render backend that maps render frames to DOM/CSS,
  browser input events, scrolling, and observability.
- `web`: browser client entrypoint that wires `remote_protocol`,
  `renderer/browser`, and the remote-backed provider.

Keep existing domain packages (`core`, `syntax`, `decorations`, `workspace`,
`language`) target-neutral.

## Build Metadata

Use supported-target metadata instead of a module preferred target:

- `moon.mod`: `supported_targets = "+js+native"` and no `preferred_target`.
- Browser packages: `supported_targets = "js"`.
- Native server packages: `supported_targets = "native"`.
- Shared packages: inherit the module support set.

All repository-wide build/check commands in this plan should pass `--target all`
so Moon builds each package for its declared supported targets.

## Protocol

Use a MoonBit-owned remote protocol. Initial packets:

- client requests: `OpenDocument`, `WatchDocument`, `CloseDocument`, `Hover`,
  `Definition`;
- server responses/events: `DocumentLoaded`, `DocumentChanged`, `Diagnostics`,
  `HoverResult`, `DefinitionResult`, `Error`.

Remote documents use `readonly-remote://workspace/<root-relative-path>`. The
server validates and maps this URI to the configured readonly workspace root.

LSP messages may be carried as raw JSON-RPC strings inside protocol packets, but
packet routing, cancellation, lifecycle, and error handling belong in MoonBit.

## Steps

1. Add `remote_protocol` with pure MoonBit encode/decode tests.
2. Add `server` core logic with fake host tests for URI validation, file read
   error mapping, watch event routing, and LSP packet routing.
3. Add `server_host_native` with the smallest native host surface needed by
   `server`.
4. Extract the current DOM-neutral `view` output into a clearer
   backend-agnostic `renderer` frame model.
5. Move browser DOM/CSS/event mapping into `renderer/browser`.
6. Replace browser-side ad hoc provider wiring with a MoonBit remote client
   provider using `remote_protocol`.
7. Move the current Vite `moon-lsp --stdio` bridge behavior into the MoonBit
   native server.
8. Keep Vite as a browser dev harness only: static serving and Playwright entry,
   not remote editor semantics.

## Validation

Required checks for each implementation slice:

- `moon check --target all` for repository-wide target filtering.
- `moon build --target all` after build metadata or package graph changes.
- `moon check --target native server server_host_native` for server slices.
- `moon check --target js web renderer/browser` for browser slices.
- `moon test` for pure protocol, renderer, workspace, and language tests.
- `just build` after browser wiring changes.
- `just test-browser` for end-to-end browser behavior.

Browser smoke coverage should include:

- opening `readonly-remote://workspace/docs/fixtures/project/src/main.mbt`;
- rendering syntax and diagnostics;
- hover and definition requests through the remote server;
- watched file refresh after the server reports a change;
- structured missing/permission/invalid-path states.

## Guardrails

- `server` must not import `renderer/browser`, `web`, or browser host packages.
- `renderer` must not import `server` or host-boundary packages.
- Only host-boundary packages may declare FFI.
- Product code must not import from `codemirror/` or `vscode/`.
