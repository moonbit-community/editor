# Architecture

The editor is a readonly code viewer. It borrows the separations used by
CodeMirror, Monaco, and VS Code without carrying editing machinery. Product code
is written in MoonBit; platform-specific host packages are the only place where
foreign-function boundaries are allowed.

## Runtime Shape

The project is split into three runtime parts:

- MoonBit remote server core: native MoonBit packages that own workspace-root
  validation, readonly file-access policy, file-watch routing, remote protocol
  routing, and the host contract for `moon-lsp` session lifecycle.
- Backend-agnostic renderer: MoonBit packages that convert source snapshots,
  syntax, diagnostics, hover/definition data, viewport state, and theme data
  into a platform-neutral render frame.
- Render backends: MoonBit packages that map render frames to concrete hosts.
  This round only defines the browser backend.

The remote server and render backends communicate through explicit protocol and
host contracts. Server code does not import browser backend packages.
Renderer code does not import server packages or host effects.

## Package Layers

- `core`: immutable `DocumentSnapshot`, UTF-16 offsets, positions, ranges, and line indexing.
- `syntax`: whole-document lexical highlighting for the first milestone.
- `decorations`: range-based visual annotations without edit mapping.
- `workspace`: readonly source document identity, URI/path normalization, filesystem-provider contracts, language inference, and snapshot conversion.
- `language`: provider traits, provider result types, deterministic demo providers, and the readonly LSP client.
- `view`: compatibility DOM-neutral render model retained while callers move to `renderer`.
- `remote_protocol`: MoonBit package for client/server packet types, JSON encoding/decoding, protocol errors, provider-error details, and version negotiation.
- `server`: native MoonBit package for remote workspace policy, file watch sessions, provider-backed hover/definition responses, raw LSP packet routing, and remote protocol dispatch.
- `server_host_native`: narrow native host boundary for sockets, filesystem reads, file watching, timers, and process spawning.
- `renderer`: backend-agnostic render frame construction and JSON serialization.
- `renderer/browser`: browser render backend adapter for DOM mounting, callback registration, observability, and the `readonly-remote` client provider.
- `dom`: JavaScript/browser host boundary and the only package that declares JavaScript FFI.
- `web`: browser client entrypoint that wires `renderer`, `renderer/browser`, workspace loading, and language providers.

## Dependency Rules

- Shared renderer packages may import `core`, `syntax`, `decorations`,
  `workspace`, `language`, `view`, and `remote_protocol`.
- `server` may import `workspace`, `language`, and `remote_protocol`, but must
  not import renderer backend packages.
- Host-boundary packages may contain platform FFI. Domain packages must not.
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

## Remote Server

The remote server targets MoonBit native. It is responsible for:

- validating client requests against configured readonly workspace roots;
- mapping remote URIs such as `readonly-remote://workspace/src/main.mbt` to
  normalized root-relative paths;
- reading text files and rejecting directories, missing files, permission
  failures, invalid paths, and binary content with structured provider errors;
- tracking file watches and emitting change events;
- owning `moon-lsp --stdio` process/session lifecycle;
- forwarding raw LSP JSON-RPC messages while keeping request routing, lifecycle,
  cancellation, and errors in MoonBit protocol code.

The host boundary for the server should be intentionally small. Native host code
provides effects, while MoonBit server code owns routing and policy.

## Backend-Agnostic Renderer

The renderer consumes immutable source and provider state, then produces a
render frame that can be interpreted by multiple frontends. Inputs include:

- `SourceDocument` and `DocumentSnapshot`;
- syntax tokens and decorations;
- diagnostics, hover, definition, and future language-provider results;
- viewport, focus, hover, and selection-like readonly state;
- theme/style identifiers.

The render frame should describe lines, gutters, token spans, decoration ranges,
diagnostic surfaces, hover payloads, definition targets, and commands requested
from the host. It must not assume DOM nodes, CSS classes, host-specific styling
primitives, or browser APIs.

## Render Backends

Render backends translate render frames to host-specific output. This round
focuses only on the browser backend:

- Browser backend: DOM creation, CSS class mapping, scrolling, pointer/keyboard
  event binding, browser file handles, and Playwright-facing observability.

Backends should share the same renderer input and remote protocol. Adding a new
frontend later should require a new backend package, not changes to server
routing or workspace/language semantics.

## Remote Protocol

The remote protocol is MoonBit-owned. It should cover at least:

- `OpenDocument(uri)`;
- `WatchDocument(uri)`;
- `CloseDocument(uri)`;
- `Hover(uri, version, offset)`;
- `Definition(uri, version, offset)`;
- `DocumentLoaded(SourceDocument)`;
- `DocumentChanged(SourceDocument)`;
- `Diagnostics(uri, version, diagnostics)`;
- `HoverResult`;
- `DefinitionResult`;
- structured errors.

LSP payloads may remain raw JSON-RPC strings inside protocol packets, but packet
encoding, decoding, routing, and error handling belong in MoonBit.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser JavaScript
strings, Monaco/CodeMirror position behavior, and default LSP positions.
