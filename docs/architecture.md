# Architecture

The editor is a readonly MoonBit code viewer. The public embedding surface is
the browser viewer backend: MoonBit users import `renderer/browser`, provide
document and feature providers, attach the viewer to their own host element, and
drive it from their own shell.

This file is the high-level system map. It should stay stable and describe
where components belong. Package-local contracts, method lists, tests, and DOM
details belong in each package's `README.md`.

## References

For editor behavior and design choices, inspect the local reference sources
before inventing a local shape. Monaco/VS Code references live under `vscode/`
with editor code primarily under `vscode/src/vs/editor`; use
`docs/references/monaco.md` as the starting map. CodeMirror references live
under `codemirror/` with `docs/references/codemirror.md` as the starting map.

Reference sources are for design research only. Product code must stay
MoonBit-owned and must not import from `vscode/` or `codemirror/`.

## Component Map

The project has one primary reusable product surface and one reference host
stack around it.

- `renderer/browser`: the embeddable readonly viewer for MoonBit users and this
  repo's Monaco `editor/browser` role. It owns the browser DOM view, browser
  input, widgets such as hover, and the public viewer control API.
- `renderer`: pre-DOM common editor model state and this repo's Monaco
  `editor/common` role. It owns the readonly `ViewModel` spine, viewport data,
  line HTML, scroll/layout arithmetic, and hit testing.
- `workspace`: document identity and source/tree provider contracts. This is
  where host-neutral document and workspace semantics belong.
- `language`: language feature contracts and result types such as hover,
  diagnostics, document symbols, and semantic tokens.
- `syntax` and `syntax/lang_*`: tokenization contracts and compile-time
  language lexers.
- `decorations`, `core`, and `platform/log`: shared support packages.
- `widgets/file_tree`: optional file-tree widget. Embedders may use it, or they
  may use their own tree and call the viewer directly.
- `workbench` and `web`: the repository's browser reference app. This shell
  composes the viewer, optional tree, tokenizers, language providers, protocol
  client, theme state, and test observability.
- `remote_protocol`, `server`, and `server_host_native`: the repository's
  reference remote workspace stack. It proves one backend composition with
  filesystem access, file watching, static serving, websocket transport, and
  `moon-lsp`.
- `dom`: browser host capabilities shared by browser packages.
- `examples/embedded_viewer`: proof that the viewer can be embedded without the
  workbench, remote protocol, server, or native host.

`view` is a compatibility render model kept separate from the active
`renderer` path.

## Main Interactions

### Embedded Viewer

External MoonBit embedders should treat `renderer/browser` as the entry point:

```text
embedder shell
  -> renderer/browser.Viewer
  -> workspace.DocumentSource
  -> optional language providers
  -> optional syntax/lang_* tokenizer registration
```

The embedder supplies document content through `workspace` provider traits. The
viewer owns opening, rendering, scrolling, hover presentation, and lifecycle
notifications. The embedder owns its shell, file tree, transport, persistence,
and any backend calls it wants to make.

Language features are provider-based. A hover provider, for example, may compute
locally, call a backend, or use any other MoonBit-accessible mechanism. The
viewer only depends on the provider contract and result.

### Reference Workbench

The shipped app is one composition of the public viewer:

```text
web
  -> workbench
  -> renderer/browser
  -> widgets/file_tree
  -> remote_protocol

server_host_native/main
  -> server_host_native
  -> server
  -> remote_protocol, workspace, language
```

`workbench` adapts the remote protocol into the same provider contracts that an
external embedder would implement directly. `server` owns remote workspace
policy and language-feature routing. `server_host_native` owns native effects
such as filesystem reads, watching, process startup, sockets, and static asset
serving.

This stack is useful for development, local demos, and testing a complete remote
viewer, but it is not required for users who embed the viewer package.

### Rendering

Rendering is split by host boundary:

```text
workspace.SourceDocument
  -> renderer/view_model tokenization and ViewModel state
  -> renderer/view_layout scroll and viewport window state
  -> renderer/view_layout ViewportData
  -> renderer/view_line_renderer render-line IR
  -> renderer/browser DOM view
```

Pre-DOM rendering and geometry belong in `renderer` and its common-layer
subpackages. `renderer/view_layout` owns DOM-free scroll/layout state.
Browser-specific DOM, CSS, event capture, custom scrollbars, and widget
placement belong in `renderer/browser`. The browser `ViewLayer` applies
`@view_line_renderer.RenderLineInput` / `RenderLineOutput2` results to DOM
nodes; it does not own line HTML semantics.

### Syntax And Language Features

Syntax highlighting and semantic language features are separate:

- `syntax/lang_*` packages provide compile-time tokenizers.
- Hosts register tokenizers with the viewer.
- `language` provider traits provide semantic features such as hover and
  diagnostics.
- `renderer/browser` consumes registered tokenizers and providers without
  importing concrete `syntax/lang_*` packages or any backend transport.

## Placement Rules

Use these rules when deciding where to add a new package or feature:

- Public viewer behavior belongs in `renderer/browser` unless it is pure
  backend-neutral model logic, in which case it belongs in `renderer`.
- New host-neutral document or workspace contracts belong in `workspace`.
- New semantic language feature contracts belong in `language`.
- New concrete tokenizers belong in `syntax/lang_*` packages and are composed by
  host packages.
- Optional reusable UI around the viewer belongs under `widgets/*`.
- App-specific browser shell behavior belongs in `workbench` or a separate
  example/application package.
- Remote protocol packet shape belongs in `remote_protocol`.
- Remote workspace policy belongs in `server`; native filesystem, process,
  socket, and static-serving effects belong in `server_host_native`.
- Browser capabilities shared by browser packages belong in `dom`; one-package
  browser FFI may stay in the browser package that uses it.
- Packages shared across browser and native targets must not declare FFI.
- Product code must not import from `codemirror/` or `vscode/`; those trees are
  references only.

Composition stays explicit. There is no global dependency-injection container
and no hidden service locator. Hosts assemble plain MoonBit traits, records, and
registries.

## Dependency Direction

Dependencies should flow from host entry points toward shared domain packages:

```text
web -> workbench
workbench -> renderer/browser, widgets/file_tree, remote_protocol
renderer/browser -> renderer, workspace, language, syntax, decorations, dom
widgets/file_tree -> workspace

server_host_native/main -> server_host_native
server_host_native -> server
server -> remote_protocol, workspace, language

renderer -> core, syntax, decorations, language
workspace -> core
language -> core, workspace
syntax/decorations -> core
platform/log -> no product packages
syntax/lang_* -> syntax
```

The repository-level architecture guardrail is `scripts/check-architecture.mbtx`,
run by `just check`.

## Build Targets

The module supports both JavaScript and native targets. Browser packages declare
`supported_targets = "js"`, native host packages declare
`supported_targets = "native"`, and shared packages remain target-neutral.

Repository-level validation should use `just check`.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser JavaScript
strings, Monaco/CodeMirror position behavior, and default LSP positions.
