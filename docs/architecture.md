# Architecture

The current project has two main parts.

1. `viewer`: the reusable MoonBit readonly viewer. It provides the public
   viewer API, owns the browser editor surface, and follows Monaco-shaped
   behavior where that helps readonly embedders.
2. `workbench` plus the backend shell: a small reference host used to see the
   viewer working against a real workspace. It illustrates how outer users can
   compose the viewer, and it must use viewer public APIs instead of reaching
   into viewer implementation details.

This file is the high-level map. Package-local method lists, DOM details,
tests, and invariants belong in each package README.

## References

Monaco/VS Code is the primary reference for behavior, API shape, rendering
roles, and conformance checks. Start at `docs/references/monaco.md`.

CodeMirror is a secondary reference for simpler state/view ideas. Start at
`docs/references/codemirror.md`.

Reference trees are research inputs only. Product code must not import from
`vscode/` or `codemirror/`, and local public names should stay MoonBit-owned.

## Current Truth

Use current architecture docs, package READMEs, and tests for active behavior.
Execution plans in `docs/exec-plans/` are implementation records. Once a plan
has landed or been superseded, it is historical evidence, not an active
contract.

## Package Roles

### Viewer

- `viewer`: public browser-backed readonly viewer facade. It owns DOM creation,
  CSS-facing editor structure, input capture, scrollbars, widgets, feature
  controllers, typed lifecycle events, and Monaco-shaped APIs such as model
  installation and language registration.
- `viewer/model`: readonly `TextModel` and `TextSnapshot`, the model identity
  used by viewer and language-provider APIs.
- `viewer/core`: UTF-16 position/range primitives for editor internals.
- `viewer/common`, `viewer/view_model`, `viewer/view_layout`, and
  `viewer/view_line_renderer`: DOM-free viewer common layer for tokenized
  lines, render frames, projections, layout, viewport data, scrollbar
  arithmetic, hit testing, and render-line HTML/character mapping.
- `language`: backend-neutral readonly semantic provider contracts over
  `viewer/model.TextModel`.
- `syntax` and `syntax/lang_*`: tokenization contracts and concrete
  compile-time lexers. Hosts import concrete language packages and register
  tokenizers with the viewer.
- `decorations` and `platform/log`: small shared support packages.

### Reference Shell

- `web`: generated browser entrypoint. It starts the workbench and should not
  grow application logic.
- `workbench`: the reference browser shell. It composes the viewer, optional
  file tree, syntax packages, remote protocol client, theme state, shell UI,
  and test observability.
- `widgets/file_tree`: optional explorer widget over `workspace` providers. It
  does not know about the viewer or transport.
- `remote_protocol`: MoonBit-owned packets between the reference workbench and
  reference backend.
- `server`: remote workspace policy and semantic feature routing.
- `server_host_native`: native filesystem, watching, process, socket, static
  serving, and LSP-process effects for the reference backend.
- `examples/embedded_viewer`: small non-remote embedding proof. It demonstrates
  that the viewer can run without `workbench`, `remote_protocol`, `server`, or
  `server_host_native`.

`workspace` defines host-side source and tree provider contracts used by the
reference shell and examples. It is not the viewer model API.

`view` is a compatibility render model outside the active viewer path.

## Main Flows

### Embedding

```text
host app
  -> viewer.Viewer
  -> viewer/model.TextModel
  -> optional language providers
  -> optional tokenizer registration
  -> optional host-owned workspace/tree/transport
```

The host creates or fetches readonly document content, converts it into a
`viewer/model.TextModel`, and installs it on the viewer. The viewer owns
rendering, scrolling, hover presentation, selection/copy, widget placement, and
lifecycle events. The host owns files, transport, persistence, reload policy,
shell chrome, and error display.

Language features are provider-based. Providers may compute locally, call a
backend, or read host state. The viewer depends only on the provider contracts
and result values.

### Reference Workbench

```text
web -> workbench -> viewer
                 -> widgets/file_tree
                 -> remote_protocol

server_host_native/main -> server_host_native -> server
                                           -> remote_protocol
                                           -> workspace
                                           -> language
```

`workbench` adapts remote protocol responses into host-owned providers and
`viewer/model.TextModel` values, then calls the viewer API. `server` owns
remote workspace policy. `server_host_native` owns native effects.

This stack exists for development, demos, and end-to-end validation. It should
not become a dependency of the reusable viewer.

### Rendering

```text
viewer/model.TextModel
  -> viewer/view_model
  -> viewer/view_layout
  -> viewer/view_line_renderer
  -> viewer DOM view
```

DOM-free text, projection, layout, viewport, scrollbar, and hit-test state live
in the viewer common-layer packages. Browser DOM, CSS, measurement, native
events, custom scrollbars, and widget DOM live in `viewer`.

## Placement Rules

- Public viewer behavior belongs in `viewer`.
- Pure DOM-free editor model, layout, viewport, and render-line logic belongs in
  the focused `viewer/*` common-layer packages.
- Editor text identity belongs in `viewer/model`; do not expose
  `workspace.DocumentSnapshot` through viewer or language-provider APIs.
- Host source/tree provider contracts belong in `workspace`.
- Semantic provider contracts belong in `language`.
- Runtime language registration belongs in `viewer.languages`; concrete
  tokenizers belong in `syntax/lang_*` and are imported by host packages.
- Optional reusable UI around the viewer belongs under `widgets/*`.
- Reference app behavior belongs in `workbench` or an example package.
- Remote packet shape belongs in `remote_protocol`.
- Remote workspace policy belongs in `server`.
- Native filesystem, process, socket, and static-serving effects belong in
  `server_host_native`.
- JS-only packages may declare narrowly scoped JS FFI for effects they own.
  Shared packages must remain FFI-free.
- Product code must not import from `vscode/` or `codemirror/`.

Composition stays explicit. Hosts assemble plain MoonBit traits, records,
registries, and viewer calls. There is no global dependency-injection container.

## Dependency Direction

Dependencies flow from host entrypoints toward viewer and shared domain
packages:

```text
web -> workbench
workbench -> base/common, viewer, viewer/model, widgets/file_tree,
             remote_protocol, workspace, language, syntax/lang_*,
             platform/log
viewer -> base/common, viewer/common, viewer/core, viewer/model,
          viewer/view_line_renderer, viewer/view_layout, viewer/view_model,
          language, syntax, decorations, platform/log

server_host_native/main -> server_host_native
server_host_native -> base/common, server, remote_protocol, workspace,
                      language, viewer/model
server -> base/common, remote_protocol, workspace, language, viewer/model
remote_protocol -> base/common, workspace, language
widgets/file_tree -> base/common, workspace

language -> base/common, viewer/model
workspace -> base/common
syntax -> base/common, viewer/model
decorations -> base/common
viewer/model -> base/common, viewer/core
platform/log -> no product packages
syntax/lang_* -> syntax, viewer/core, viewer/model
```

`scripts/check-architecture.mbtx`, run by `just check`, enforces the most
important import boundaries.

## Build Targets

Browser packages use `supported_targets = "js"`. Native host packages use
`supported_targets = "native"`. Shared packages stay target-neutral.

Repository-level validation starts with `just check`.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser strings,
Monaco/CodeMirror position behavior, and default LSP positions.
