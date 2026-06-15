# Architecture

The editor is a readonly code viewer. It borrows useful separations from
CodeMirror, Monaco, and VS Code without importing their product code or carrying
editing machinery. Product code is written in MoonBit; platform-specific host
packages are the only place where foreign-function boundaries are allowed.

This file is the high-level system map. Package-local implementation contracts
live in each product package's `README.md`; read those before changing package
behavior.

## Architectural Shape

The repository uses service-oriented boundaries, not a VS Code-style dependency
injection container. MoonBit does not give this project TypeScript-style
decorators, reflection, or constructor metadata, so services are expressed as
plain MoonBit traits, records, registries, and explicit package composition.

The current rule is:

- use traits for host or provider boundaries;
- use service records for per-viewer state and registries;
- use composition roots to assemble concrete implementations;
- avoid a global service locator or stringly typed injector until there is a
  concrete lifecycle problem that explicit construction cannot handle.

This gives the project the important parts of a service architecture - narrow
interfaces, replaceable implementations, and clear ownership - without copying
VS Code's TypeScript DI machinery.

## Runtime Entry Points

The project has three active runtime entry points:

- `server_host_native/main`: native executable. It serves `web/dist`, owns native
  filesystem/process/socket effects, starts `moon-lsp --stdio`, and bridges the
  `/protocol` WebSocket into `server.RemoteServer`.
- `web`: browser entry point for the shipped app. It imports `workbench` only.
- `examples/embedded_viewer`: browser embedding proof. It mounts the viewer and
  optional file tree against in-memory providers with no server or websocket.

The main runtime path is:

```text
server_host_native/main
  -> server_host_native
  -> server
  -> remote_protocol, workspace, language

web
  -> workbench
  -> renderer/browser, widgets/file_tree, remote_protocol
  -> workspace, language, platform/log, dom, syntax/lang_*
```

## Service And Provider Boundaries

These are the real import points. New code should extend one of these seams
before adding cross-package imports.

| Boundary | Owner | Import point | Concrete implementations |
| --- | --- | --- | --- |
| Document loading and watches | `workspace` | `DocumentSource` | `workbench.RemoteDocumentSource`, `examples/embedded_viewer` memory workspace |
| Workspace tree | `workspace` | `WorkspaceTreeProvider`, `WorkspaceStat` | `workbench.RemoteWorkspaceTreeProvider`, `examples/embedded_viewer` memory workspace |
| Language features | `language` | provider traits for hover, diagnostics, symbols, semantic tokens | `workbench.RemoteLanguageClient`, server-backed providers, tests |
| Viewer feature state | `renderer/browser` | `ViewerServices` | per-viewer service record built by the host |
| Tokenization | `renderer/browser` + `syntax` | `register_tokenizer(language_id, tokenizer)` | composition roots importing `syntax/lang_*` packages |
| Runtime logging | `platform/log` | `LogService` | workbench harness sink, tests, future hosts |
| Native effects for server policy | `server` | `ServerHost`, `LspTransport` | `server_host_native` |
| Browser/native packets | `remote_protocol` | client/server packet types and codecs | `workbench` client, `server` dispatcher |

Important consequences:

- `renderer/browser` integrates through `DocumentSource`, `ViewerServices`, and
  `register_tokenizer`. It must not know about websockets or the remote protocol.
- `widgets/file_tree` integrates through `WorkspaceTreeProvider`. It must not
  know about the viewer or the transport.
- `workbench` is the shipped-app composition root. It is the only package that
  composes viewer, tree, remote protocol client, tokenizers, language providers,
  logging, and browser harness observability.
- `server` owns remote workspace policy and semantic routing. Native effects
  stay behind `ServerHost` and `LspTransport`.

## Package Map

The repository root contains MoonBit packages. Files inside a package are only
organizational; package boundaries are the directories with `moon.pkg`.

- Shared domain packages: `core`, `syntax`, `decorations`, `workspace`,
  `language`, and `view`.
- Shared platform packages: `platform/log`, an FFI-free runtime logging API
  used by shared viewer code and concretized by composition layers.
- Language packages: `syntax/lang_*` (`lang_moonbit`, `lang_json`,
  `lang_javascript`), one compile-time `lexmatch` lexer per language behind the
  `syntax.LineTokenizer` contract, composed by import only.
- Remote server packages: `remote_protocol`, `server`, and
  `server_host_native`.
- Render packages: `renderer` and `renderer/browser`.
- Optional widgets: `widgets/file_tree`.
- Shipped app shell: `workbench`.
- Browser host packages: `dom` and `web`.
- Embedding proof: `examples/embedded_viewer`.

`view` is a compatibility render model kept separate from the active
`renderer` path.

## Dependency Direction

The dependency graph should flow from host entry points toward shared domain
packages:

```text
web -> workbench
workbench
  -> renderer/browser, widgets/file_tree
  -> remote_protocol, dom, workspace, language, platform/log
  -> syntax/lang_* (registers tokenizers at startup)

renderer/browser
  -> renderer
  -> dom
  -> workspace, language, syntax, decorations, platform/log
  (rabbita: only the dom bindings and js helpers; never the TEA core,
   vdom, or command scheduler)

widgets/file_tree -> workspace

server_host_native/main -> server_host_native
server_host_native -> server -> remote_protocol
server -> workspace, language

renderer -> core, syntax, decorations, language
workspace -> core
language -> core, workspace
syntax/decorations -> core
platform/log -> (no product packages)
syntax/lang_* -> core, syntax

examples/embedded_viewer
  -> renderer/browser, widgets/file_tree, workspace, syntax/lang_*
```

## Dependency Rules

- Composition over configuration: there is no `show_sidebar` flag. Excluding
  the explorer means not importing `widgets/file_tree`; including it means the
  composition root wires the widget to the viewer.
- `renderer/browser` is the embeddable viewer-core library, the `vs/editor`
  role. It must not import `remote_protocol`, `websocket`, `workbench`, or
  `widgets/*`.
- `widgets/file_tree` is an optional explorer widget. It must not import
  `remote_protocol` or `renderer/browser`.
- `workbench` is the shipped app shell, the `vs/workbench` role. It may import
  the viewer, tree widget, protocol, tokenizer packages, and browser host
  packages because composition is its job.
- Grammars are compile-time code, not runtime data. A language is a
  `syntax/lang_*` package whose rules are `lexmatch` arms compiled to a tagged
  DFA at build time. There is deliberately no `setMonarchTokensProvider`
  equivalent.
- `syntax/lang_*` may import only `core` and `syntax`. Only composition roots
  such as `workbench` and `examples/*` may import `syntax/lang_*`; they register
  tokenizers through `renderer/browser.register_tokenizer`.
- Shared renderer packages may import `core`, `syntax`, `decorations`,
  `workspace`, `language`, and `view`.
- `server` may import `workspace`, `language`, and `remote_protocol`, but must
  not import renderer backend packages.
- Packages that only run on one host target may declare that host's FFI. Browser
  packages such as `dom` and `renderer/browser` may declare JavaScript FFI.
  Native packages such as `server_host_native` may declare native FFI. Shared
  packages must not declare FFI.
- Browser-specific code must stay out of `core`, `syntax`, `decorations`,
  `workspace`, `language`, `view`, `renderer`, `remote_protocol`, and `server`.
- Product code must not import from `codemirror/` or `vscode/`; those trees are
  reference-only submodules.

These import rules are enforced by `scripts/check-architecture.mbtx`, which runs
as part of `just check`.

## Rendering And Viewer Contracts

- The editor is readonly. Document identity, source loading, rendering, hover
  lookup, diagnostics, watches, and scrolling must not introduce edit state.
- `renderer` owns backend-neutral editor model state: Monaco-shaped render IR,
  pure line HTML, viewport frame construction, scroll arithmetic, line layout,
  hit testing, and visible-window math.
- `renderer/browser` owns the concrete browser island: DOM creation, CSS
  classes, native input capture, hover controller behavior, widget mounting,
  custom scrollbars, render-loop scheduling, and browser observability.
- The viewer is an imperative DOM island. The host renders one stable mount
  element (`.viewer-host`) and the viewer attaches its whole DOM subtree into it.
  The host must never render vdom children into that element.
- The browser island's DOM is Monaco-shaped but locally owned:
  `.moonbit-viewer.readonly-editor` contains an `.overflow-guard`, margin view
  overlays, a `.monaco-scrollable-element.editor-scrollable` around
  `.lines-content`, `.view-lines`, `.view-overlays`, `.view-zones`,
  content-widget and overlay-widget slots, overflowing widget slots, and
  Monaco-shaped custom scrollbar nodes. This is a product DOM contract, not an
  import of Monaco CSS or services.
- Scrolling is split along the backend boundary. Scroll semantics - clamping,
  dimensions, viewport derivation, and scrollbar geometry - are backend-neutral
  model state in `renderer`. The browser backend exposes that model through
  `ScrollableElementDom` and applies the model's output to DOM in a
  rAF-coalesced render loop.
- Browser-originated DOM scroll offsets are reveal deltas folded back into
  `ViewLayout`; they are not a second editor scroll source.
- Browser input routes through one shared hit test. Native container listeners
  on the viewer island turn DOM events into typed editor events consumed by
  feature controllers. Rendered spans carry no event handlers.
- Feature controllers consume editor events and services. Hover currently
  composes synchronous marker hover with asynchronous markdown language hover
  through `HoverParticipantRegistry`.

## Workspace And Protocol Contracts

- Workspace semantics and filesystem-provider contracts belong in MoonBit domain
  packages. Browser or native hosts provide effects behind narrow package
  boundaries.
- Remote protocol packet types, version negotiation, encoding, decoding, and
  structured errors are MoonBit-owned.
- Browser/native communication uses `remote_protocol` packets over the native
  host's `/protocol` WebSocket. The native host serializes outbound packets per
  connection so watch pushes cannot interleave with responses.
- The browser app is served by the native host from `web/dist`.
- Browser URLs are not document routes. Active file identity comes from MoonBit
  workspace/explorer state and server/protocol calls, not `?uri=`, `?path=`,
  hashes, or history updates.
- Workspace selection is provider + widget + workbench composition: the server
  resolves one directory level per `ResolveDirectory` request; the explorer
  renders stats lazily; the workbench routes open intents into the viewer and
  feeds viewer lifecycle back into the widget's `set_active` behavior.
- Explorer behavior contract: directories start collapsed; expanding an
  unresolved directory resolves exactly one level and caches it on the node; a
  failed resolve renders an empty-with-error level and is retried on next
  expand; `set_active` resolves and expands ancestors; `refresh` re-resolves
  from the root on reconnect.
- LSP client behavior targets Language Server Protocol 3.17:
  `https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/`.
  LSP stays behind the host-server provider boundary and is not part of the
  browser protocol.

## Runtime Observability

- The viewer reports lifecycle facts through `ViewerNotification`; the host
  formats those into harness events and chrome updates.
- Runtime provider and participant failures are reported through
  `platform/log.LogService`. Shared packages only depend on the FFI-free logging
  API; composition layers install concrete sinks.
- In the shipped app, `workbench` installs the browser harness sink that turns
  warning/error log entries into the existing `language:error` observability
  event.

## Build Targets

The module should not declare a `preferred_target`. Hybrid builds should rely on
supported-target metadata and explicit command targets:

- `moon.mod` declares `supported_targets = "+js+native"`.
- Browser packages such as `web` and the browser host/render backend declare
  `supported_targets = "js"`.
- Native server packages such as `server`, `server_host_native`, and
  `server_host_native/main` declare `supported_targets = "native"`.
- Shared packages omit package-level `supported_targets` and inherit the module
  support set.

Repository-level validation should use `moon check --target all` and
`moon build --target all`. Package-local checks may use explicit `--target js`
or `--target native`.

## Extension Rule

Adding another frontend should require a new backend or composition package, not
changes to server routing or workspace/language semantics. Adding another host
should provide concrete implementations for the existing provider/service seams
before adding new ones.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser JavaScript
strings, Monaco/CodeMirror position behavior, and default LSP positions.
