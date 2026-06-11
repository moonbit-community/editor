# Architecture

The editor is a readonly code viewer. It borrows the separations used by
CodeMirror, Monaco, and VS Code without carrying editing machinery. Product code
is written in MoonBit; platform-specific host packages are the only place where
foreign-function boundaries are allowed.

This file is the high-level system map. Package-local implementation contracts
live in each product package's `README.md`.

## Runtime Shape

The project is split into three runtime parts:

- MoonBit remote server core: native MoonBit packages that own workspace-root
  validation, readonly file-access policy, file-watch routing, remote protocol
  routing, and the host contract for `moon-lsp` session lifecycle.
- Backend-agnostic renderer: MoonBit packages that convert source snapshots,
  syntax, diagnostics, hover/definition data, viewport state, and theme data
  into a platform-neutral render frame, plus the pure editor geometry that
  backends share: mouse hit-testing (`MouseTarget`/`ViewMetrics`/`hit_test`)
  and line-window math (`visible_window`) for viewport virtualization.
- Render backends: MoonBit packages that map render frames to concrete hosts.
  This round only defines the browser backend.

The remote server and render backends communicate through explicit protocol and
host contracts. Server code does not import browser backend packages.
Renderer code does not import server packages or host effects.

## Package Map

The repository root contains MoonBit packages. Files inside a package are only
organizational; package boundaries are the directories with `moon.pkg`.

- Shared domain packages: `core`, `syntax`, `decorations`, `workspace`,
  `language`, and `view`.
- Remote server packages: `remote_protocol`, `server`, and
  `server_host_native`.
- Render packages: `renderer` and `renderer/browser`.
- Browser host packages: `dom` and `web`.

Read the package-local `README.md` before changing package behavior. Those files
record each package's owned responsibilities, dependency limits, and local test
notes.

## Dependency Direction

The dependency graph should flow from host entrypoints toward shared domain
packages:

```text
web
  -> renderer/browser
renderer/browser
  -> renderer
  -> dom
  -> workspace, language, syntax, decorations, remote_protocol

server_host_native -> server -> remote_protocol
server -> workspace, language

renderer -> core, syntax, decorations, language
workspace -> core
language -> core, workspace
syntax/decorations -> core
```

`view` is a compatibility render model kept separate from the active
`renderer` path.

## Dependency Rules

- Shared renderer packages may import `core`, `syntax`, `decorations`,
  `workspace`, `language`, `view`, and `remote_protocol`.
- `server` may import `workspace`, `language`, and `remote_protocol`, but must
  not import renderer backend packages.
- Packages that only run on one host target may declare that host's FFI: a
  browser-only package such as `dom` or `renderer/browser` may declare
  JavaScript FFI, and a native-only package such as `server_host_native` may
  declare native FFI. Declare FFI in the package that uses it; `dom` holds
  only browser capabilities shared across browser packages. Packages shared
  across targets must not declare FFI.
- Browser-specific code must stay out of `core`, `syntax`, `decorations`,
  `workspace`, `language`, `view`, `renderer`, `remote_protocol`, and `server`.
- Product code must not import from `codemirror/` or `vscode/`; those trees are
  reference-only submodules.

## Build Targets

The module should not declare a `preferred_target`. Hybrid builds should rely on
supported-target metadata and explicit command targets:

- `moon.mod` declares `supported_targets = "+js+native"`.
- Browser packages such as `web` and the browser host/render backend declare
  `supported_targets = "js"`.
- Native server packages such as `server` and `server_host_native` declare
  `supported_targets = "native"`.
- Shared packages omit package-level `supported_targets` and inherit the module
  support set.

Repository-level validation should use `moon check --target all` and
`moon build --target all`. Package-local checks may use explicit `--target js`
or `--target native`.

## System Contracts

- The editor is readonly. Document identity, source loading, rendering,
  hover/definition/references lookup, diagnostics, and watches must not
  introduce edit state.
- Workspace semantics and filesystem-provider contracts belong in MoonBit
  domain packages. Browser or native hosts provide effects behind narrow
  package boundaries.
- Remote protocol packet types, version negotiation, encoding, decoding, and
  structured errors are MoonBit-owned.
- The browser app is served by the native host from `web/dist`. Generated
  MoonBit code owns the Rabbita app, document/session updates, workspace
  selection, render-frame construction, hover/definition/references
  resolution, and watch refreshes.
- Browser input routes through one shared hit test: container handlers on
  the code viewer turn DOM events into typed editor events consumed by
  feature controllers (hover, definition, references); rendered spans carry
  no event handlers. Language features resolve through the `language`
  provider traits, implemented browser-side by a protocol client that
  correlates responses by request id.
- The code surface is an embedded Rabbita child cell with keyed line
  children that renders only a windowed slice of the frame; shell updates
  that do not change the surface skip its subtree entirely.
- Browser/native communication uses `remote_protocol` packets over the native
  host's `/protocol` WebSocket. The native host serializes outbound packets
  per connection so watch pushes cannot interleave with responses.
- Browser URLs are not document routes. Active file identity comes from
  MoonBit workspace/sidebar state and server/protocol calls, not `?uri=`,
  `?path=`, hashes, or history updates.
- LSP client behavior targets the official Language Server Protocol 3.17
  specification:
  `https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/`.
  LSP stays behind the host-server provider boundary and is not part of the
  browser protocol.
- Render frames are backend-neutral. Browser DOM nodes, CSS details, event
  wiring, session display, and observability belong to the browser backend and
  host boundary.
- Adding another frontend should require a new backend package, not changes to
  server routing or workspace/language semantics.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser JavaScript
strings, Monaco/CodeMirror position behavior, and default LSP positions.
