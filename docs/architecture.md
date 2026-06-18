# Architecture

The editor is a readonly MoonBit code viewer. The public embedding surface is
`viewer`: MoonBit users create or fetch readonly editor models, attach the
viewer to their own host element, and drive rendering, selection, reload, and
error policy from their own shell.

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

- `viewer`: the embeddable readonly viewer for MoonBit users and this
  repo's Monaco `editor/browser` role. It owns the browser DOM view, browser
  input, widgets such as hover, and the public viewer control API.
- `viewer/common`: pre-DOM common editor model state and this repo's Monaco
  `editor/common` role. It owns the readonly `ViewModel` spine, viewport data,
  line HTML, scroll/layout arithmetic, and hit testing.
- `base/common`: low-level URI identity, lifecycle helpers, and editor
  coordinate primitives shared by workspace, language, viewer, protocol,
  server, and widgets.
- `viewer/core`: UTF-16 coordinate primitives used by viewer internals while
  public host contracts use `base/common`.
- `viewer/model`: readonly editor text ownership and this repo's Monaco
  `ITextModel`/`TextModel` role. Public viewer and language-provider APIs
  should depend on `TextModel` or `TextSnapshot`, not workspace source payloads.
- `workspace`: host-side source/tree provider contracts, source payloads, and
  document watch notifications. It does not own viewer text models or depend on
  viewer packages; using a provider is one host composition option, not a
  viewer-core requirement. Host packages adapt workspace payloads into
  `viewer/model.TextModel` before calling viewer APIs.
- `language`: language feature contracts and result types such as hover,
  diagnostics, document symbols, and semantic tokens.
- `syntax` and `syntax/lang_*`: tokenization contracts and compile-time
  language lexers.
- `decorations` and `platform/log`: shared support packages.
- `widgets/file_tree`: optional file-tree widget. Embedders may use it, or they
  may use their own tree and call the viewer directly.
- `workbench` and `web`: the repository's browser reference app. This shell
  composes the viewer, optional tree, tokenizers, language providers, protocol
  client, theme state, and test observability.
- `remote_protocol`, `server`, and `server_host_native`: the repository's
  reference remote workspace stack. It proves one backend composition with
  filesystem access, file watching, static serving, websocket transport, and
  `moon-lsp`.
- `examples/embedded_viewer`: proof that the viewer can be embedded without the
  workbench, remote protocol, server, or native host.

`view` is a compatibility render model kept separate from the active
`viewer` path.

## Main Interactions

### Embedded Viewer

External MoonBit embedders should treat `viewer` as the entry point:

```text
embedder shell
  -> viewer.Viewer
  -> viewer/model.TextModel
  -> optional workspace.DocumentProvider owned by the shell
  -> optional language providers
  -> optional syntax/lang_* tokenizer registration
```

The embedder supplies document content by creating or reusing a readonly
`viewer/model.TextModel` and installing it on the viewer. It may derive that
model from memory, a remote service, a `workspace.DocumentProvider`, or any
other source it owns. The viewer owns rendering, scrolling, hover presentation,
and lifecycle notifications. The embedder owns its shell, file tree, transport,
persistence, source watches, reload policy, and error display.

Implementation note: the current checked-in viewer API still exposes
`workspace.DocumentSnapshot` in several public signatures. That is a temporary
API mismatch, not the intended architecture; the correction is tracked in
`docs/exec-plans/monaco-model-viewer-api.md`.

Language features are provider-based. A hover provider, for example, may compute
locally, call a backend, or use any other MoonBit-accessible mechanism. The
viewer only depends on the provider contract and result.

### Reference Workbench

The shipped app is one composition of the public viewer:

```text
web
  -> workbench
  -> viewer
  -> widgets/file_tree
  -> remote_protocol

server_host_native/main
  -> server_host_native
  -> server
  -> remote_protocol, workspace, language
```

`workbench` adapts the remote protocol into host-owned provider contracts, then
converts loaded source payloads into viewer text models before calling the
viewer. `server` owns remote workspace policy and language-feature routing.
`server_host_native` owns native effects such as filesystem reads, watching,
process startup, sockets, and static asset serving.

This stack is useful for development, local demos, and testing a complete remote
viewer, but it is not required for users who embed the viewer package.

### Rendering

Rendering is split by host boundary:

```text
viewer/model.TextModel / TextSnapshot
  -> viewer/view_model tokenization and ViewModel state
  -> viewer/view_layout scroll and viewport window state
  -> viewer/view_layout ViewportData
  -> viewer/view_line_renderer render-line IR
  -> viewer DOM view
```

Pre-DOM rendering and geometry belong in `viewer/common` and its focused
common-layer subpackages. `viewer/view_layout` owns DOM-free scroll/layout state.
Browser-specific DOM, CSS, event capture, custom scrollbars, and widget
placement belong in `viewer`. The browser `ViewLayer` applies
`@view_line_renderer.RenderLineInput` / `RenderLineOutput2` results to DOM
nodes; it does not own line HTML semantics.

### Syntax And Language Features

Syntax highlighting and semantic language features are separate:

- `syntax/lang_*` packages provide compile-time tokenizers.
- `language` provider traits provide semantic features such as hover and
  diagnostics.
- Hosts register tokenizers and semantic providers through
  `@viewer.languages.*`, or through an isolated `Languages` registry selected by
  `ViewerServices::new(languages~)`.
- `viewer` consumes registered tokenizers and providers without importing
  concrete `syntax/lang_*` packages or any backend transport.

## Placement Rules

Use these rules when deciding where to add a new package or feature:

- Public viewer behavior belongs in `viewer` unless it is pure
  backend-neutral model logic, in which case it belongs in `viewer/common` or a
  focused `viewer/*` common-layer package.
- New host-neutral source or workspace-provider contracts belong in `workspace`.
- New editor text model contracts belong in `viewer/model`; do not expose
  workspace payload types from viewer or language-provider public APIs.
- New semantic language feature contracts belong in `language`.
- New concrete tokenizers belong in `syntax/lang_*` packages and are composed by
  host packages.
- Runtime language registration belongs in `viewer.languages`; `language` owns
  contracts, not live viewer registries.
- Optional reusable UI around the viewer belongs under `widgets/*`.
- App-specific browser shell behavior belongs in `workbench` or a separate
  example/application package.
- Remote protocol packet shape belongs in `remote_protocol`.
- Remote workspace policy belongs in `server`; native filesystem, process,
  socket, and static-serving effects belong in `server_host_native`.
- JS-only browser packages may declare narrowly scoped JS FFI for effects they
  own; shared packages must remain FFI-free.
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
workbench -> viewer, widgets/file_tree, remote_protocol, syntax/lang_*
viewer -> viewer/common, viewer/core, viewer/model,
          viewer/view_line_renderer, viewer/view_layout, viewer/view_model,
          language, syntax, decorations, platform/log
widgets/file_tree -> workspace

server_host_native/main -> server_host_native
server_host_native -> server
server -> remote_protocol, workspace, language

viewer/common -> viewer/view_line_renderer, viewer/view_layout,
                 viewer/view_model, decorations
viewer/view_layout -> viewer/view_model, viewer/view_line_renderer,
                        viewer/core, viewer/model, syntax, decorations,
                        language
viewer/view_model -> viewer/view_line_renderer, viewer/core,
                       viewer/model, syntax, decorations, language
viewer/view_line_renderer -> viewer/core, syntax
workspace -> base/common
language -> base/common, viewer/model
syntax -> base/common, viewer/model
decorations -> base/common
viewer/model -> base/common, viewer/core
remote_protocol/server/workbench/widgets -> base/common, workspace, language
platform/log -> no product packages
syntax/lang_* -> syntax, viewer/core, viewer/model
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
