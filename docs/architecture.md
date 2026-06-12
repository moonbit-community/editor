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
- Backend-agnostic renderer: MoonBit packages that own the Monaco-shaped
  render IR — a per-version tokenized document (`TokenizedDocument`, the
  `TextModel` tokens role), per-line bucketed feature data
  (`FrameSource`), viewport-scoped render frames (`build_frame`, the
  `ViewportData` role), and pure line-HTML emission (`render_line_html`,
  the `viewLineRenderer` role) — plus the backend-neutral scroll and
  layout model (`Scrollable`, the uniform-height `LinesLayout`,
  `ViewLayout`, `ScrollbarState`) and the pure editor geometry backends
  share: mouse hit-testing (`MouseTarget`/`ViewMetrics`/`hit_test`) and
  line-window math (`visible_window`) for viewport virtualization.
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
- Language packages: `syntax/lang_*` (`lang_moonbit`, `lang_json`,
  `lang_javascript`), one compile-time `lexmatch` lexer per language
  behind the `syntax.LineTokenizer` contract, composed by import only.
- Remote server packages: `remote_protocol`, `server`, and
  `server_host_native`.
- Render packages: `renderer` and `renderer/browser` (the embeddable
  viewer-core library, the `vs/editor` role).
- Optional widgets: `widgets/file_tree` (the provider-backed explorer tree).
- The shipped app shell: `workbench` (the `vs/workbench` role) composes the
  viewer, the tree widget, and the remote protocol client.
- Browser host packages: `dom` and `web`.
- Embedding proof: `examples/embedded_viewer` mounts the viewer and the tree
  against in-memory providers with no server or websocket.

Read the package-local `README.md` before changing package behavior. Those files
record each package's owned responsibilities, dependency limits, and local test
notes.

## Dependency Direction

The dependency graph should flow from host entrypoints toward shared domain
packages:

```text
web -> workbench
workbench
  -> renderer/browser, widgets/file_tree
  -> remote_protocol, dom, workspace, language
  -> syntax/lang_* (registers tokenizers at startup)
renderer/browser
  -> renderer
  -> dom
  -> workspace, language, syntax, decorations
  (rabbita: only the dom bindings and js helpers — never the TEA core,
   the vdom, or the command scheduler; checker-enforced)
widgets/file_tree -> workspace

server_host_native -> server -> remote_protocol
server -> workspace, language

renderer -> core, syntax, decorations, language
workspace -> core
language -> core, workspace
syntax/decorations -> core
syntax/lang_* -> core, syntax

examples/embedded_viewer
  -> renderer/browser, widgets/file_tree, workspace, syntax/lang_*
```

`view` is a compatibility render model kept separate from the active
`renderer` path.

## Dependency Rules

- Composition over configuration: there is no `show_sidebar` flag anywhere.
  Excluding the tree means not importing the widget package (the Monaco
  cut: `vs/editor` ships without the explorer because the workbench sits in
  a layer above it). Only `workbench` composes the viewer, the widget, and
  the transport.
- `renderer/browser` is the viewer-core library and must not import
  `remote_protocol`, `websocket`, `workbench`, or `widgets/*`; it meets its
  hosts at the `workspace` traits (`DocumentSource`) and the `language`
  provider registry.
- `widgets/file_tree` must not import `remote_protocol` or
  `renderer/browser`; it is built only against `workspace`
  (`WorkspaceTreeProvider`).
- Grammars are compile-time code, not runtime data: a language is a
  `syntax/lang_*` package whose rules are `lexmatch` arms compiled to a
  tagged DFA at build time (Monarch's structure without its runtime
  JS-regex engine; there is deliberately no `setMonarchTokensProvider`
  equivalent). `syntax/lang_*` may import only `core` and `syntax`, and
  only `workbench` and `examples/*` may import a `syntax/lang_*`
  package — they register lexers through the viewer's
  `register_tokenizer`, and unregistered language ids fall back to the
  plain tokenizer. Semantic tokens from `language` providers remain the
  accuracy tier overlaid on top.
- These import rules are enforced by `scripts/check-architecture.mbtx`
  (run as part of `just check`).
- Shared renderer packages may import `core`, `syntax`, `decorations`,
  `workspace`, `language`, and `view`.
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
  hover lookup, diagnostics, and watches must not
  introduce edit state.
- Workspace semantics and filesystem-provider contracts belong in MoonBit
  domain packages. Browser or native hosts provide effects behind narrow
  package boundaries.
- Remote protocol packet types, version negotiation, encoding, decoding, and
  structured errors are MoonBit-owned.
- The browser app is served by the native host from `web/dist`. The
  `workbench` package owns the Rabbita app shell, the protocol client, and
  the auto-open policy; the `renderer/browser` viewer owns document opening
  (through a `DocumentSource`), render-frame construction, hover
  resolution, and watch refreshes.
- Workspace selection is provider + widget + workbench composition: the
  server resolves one directory level per `ResolveDirectory` request
  (`WorkspaceStat`, the `IFileStat` copy: provider-minted URIs, `children:
  None` until resolved); the `widgets/file_tree` explorer renders stats
  lazily; the workbench routes the widget's open intents into the viewer
  and feeds viewer lifecycle back into the widget's `set_active`
  (autoReveal).
- Explorer behavior contract: directories start collapsed; expanding a
  directory with unresolved children resolves exactly one level and caches
  it on the node; a failed resolve renders the folder as an
  empty-with-error level and is retried on the next expand; `set_active`
  resolves and expands the ancestor chain of the active file and selects
  its row; `refresh` re-resolves from the root on (re)connect.
- Browser input routes through one shared hit test: native container
  listeners on the viewer island turn DOM events into typed editor events
  consumed by feature controllers (hover today); rendered spans carry no
  event handlers. Language features resolve through the `language`
  provider traits, implemented browser-side by a protocol client that
  correlates responses by request id.
- The viewer is an imperative view island behind a mount contract: the
  shell renders one stable host element (`.viewer-host`) and the viewer
  attaches its whole DOM subtree into it. The shell must never render
  vdom children into the host element — the island's nodes are foreign to
  the shell's diff and must stay untouched across shell updates. The
  island survives theme switches (colors cascade through CSS variables;
  there is no remount and the scroll position is preserved).
- Scrolling is split along the backend boundary: scroll semantics —
  clamping, dimensions, viewport derivation, scrollbar geometry — are
  backend-neutral model state in `renderer` (`ViewLayout` owns the single
  scroll truth; there is no DOM scroll container). The browser backend
  only captures input (wheel, scrollbar thumb drags and track jumps,
  host-routed keys) into the model and applies the model's output
  (layer transforms, recycled line nodes, scrollbar thumbs) in a
  rAF-coalesced render loop with reads before writes.
- Browser/native communication uses `remote_protocol` packets over the native
  host's `/protocol` WebSocket. The native host serializes outbound packets
  per connection so watch pushes cannot interleave with responses.
- Browser URLs are not document routes. Active file identity comes from
  MoonBit workspace/explorer state and server/protocol calls, not `?uri=`,
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
