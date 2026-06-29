# Architecture

This repository has two main parts:

1. `viewer`: the reusable MoonBit readonly viewer. It owns the public viewer API
   and the browser editor surface.
2. `internal/shell`: a reference host/backend used for development, demos, and
   end-to-end validation. It is not an external import surface.

This file is the high-level map. Exact type lists, algorithms, DOM details, and
test cases belong in the relevant package README and source files.

## Current Truth

Use current architecture docs, package READMEs, `moon.pkg` manifests, and tests
for active behavior. Execution plans in `docs/exec-plans/` are historical once
implemented or superseded; do not treat old package names or intermediate steps
there as current contracts.

## References

Monaco/VS Code is the primary reference for behavior, API shape, rendering
roles, and conformance checks. Start at `docs/references/monaco.md`.

CodeMirror is a secondary reference for simpler state/view ideas. Start at
`docs/references/codemirror.md`.

Reference trees are research inputs only. Product code must not import from
`vscode/` or `codemirror/`, and local public names should stay MoonBit-owned.

## Product Package Map

- `viewer`: public browser-backed readonly viewer facade. It owns DOM creation,
  CSS-facing editor structure, browser input capture, widgets, lifecycle events,
  and model installation.
- `viewer/model`: readonly `TextModel` and `TextSnapshot`. This is the editor
  model identity used by viewer and language-provider APIs.
- `viewer/view_model`, `viewer/view_layout`, `viewer/view_line_renderer`,
  `viewer/common`, and `viewer/decorations`: DOM-free rendering, projection,
  layout, geometry, and decoration logic.
- `viewer/cursor`, `viewer/folding`, `viewer/markers`, `viewer/languages`, and
  `viewer/hover`: focused feature packages used by the viewer.
- `viewer/controller` and `viewer/ui/scrollbar`: browser-UI subpackages. They
  may use narrow browser bindings but do not import the parent `viewer` package.
- `viewer/inline_decorations`: a dedicated Monaco conformance/support package
  for inline-decoration algorithms. It is not part of the live viewer import
  chain unless a future integration explicitly wires it in.
- `base/common`: host-neutral URI, lifecycle, and coordinate primitives.
- `language`: backend-neutral readonly semantic provider contracts over
  `viewer/model.TextModel`.
- `syntax` and `syntax/lang_*`: tokenization contracts and concrete
  compile-time lexers. Hosts import concrete language packages and register them
  with the viewer.
- `platform/log`: host-neutral structured logging contracts.

## Reference Shell Map

- `internal/shell/web`: generated browser entrypoint for the reference shell.
- `internal/shell/workbench`: browser shell composition around the viewer,
  file-tree widget, protocol client, language registration, theme state, and
  harness observability.
- `internal/shell/widgets/file_tree`: explorer widget over internal workspace
  providers.
- `internal/shell/workspace`: host-side source, document, filesystem, and tree
  provider contracts. It is not the viewer model API.
- `internal/shell/remote_protocol`: packets between the reference browser shell
  and reference backend.
- `internal/shell/server`: reference backend policy and semantic feature routing.
- `internal/shell/server_host_native`: native filesystem, watch, process,
  socket, static-serving, and LSP-process effects.
- `internal/shell/examples/embedded_viewer`: non-remote embedding proof.

## Core Flows

### Embedding

```text
host app
  -> viewer.Viewer
  -> viewer/model.TextModel
  -> optional viewer/languages registrations
```

The host owns files, transport, persistence, reload policy, shell chrome, and
error display. The viewer owns readonly editor rendering, scrolling, selection,
widgets, hover presentation, and lifecycle events.

Hosts may compute language features locally, call a backend, or read host state.
The viewer depends only on provider contracts and result values.

### Reference Workbench

```text
internal/shell/web -> internal/shell/workbench -> viewer
                                           -> internal/shell/widgets/file_tree
                                           -> internal/shell/remote_protocol

internal/shell/server_host_native/main
  -> internal/shell/server_host_native -> internal/shell/server
                                      -> internal/shell/remote_protocol
                                      -> internal/shell/workspace
                                      -> language
```

The workbench adapts internal workspace/protocol payloads into host-owned
providers and `viewer/model.TextModel` values before calling viewer APIs. The
backend stack exists to exercise the viewer, not to define the reusable viewer
surface.

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
events, custom scrollbars, and widget DOM live in `viewer` or its browser-UI
subpackages.

## Placement Rules

- Public readonly editor behavior belongs in `viewer`.
- Editor text identity belongs in `viewer/model`; do not expose
  `internal/shell/workspace.DocumentSnapshot` through viewer or provider APIs.
- DOM-free model, layout, viewport, render-line, and decoration logic belongs in
  the focused `viewer/*` common-layer packages.
- Browser input and browser widget helpers may live in browser-UI subpackages
  such as `viewer/controller` and `viewer/ui/scrollbar`.
- Semantic provider contracts belong in `language`; runtime provider
  registration belongs in `viewer/languages`.
- Concrete tokenizers belong in `syntax/lang_*` and are imported only by
  composition layers.
- Reference app behavior belongs under `internal/shell`.
- Composition stays explicit. Hosts assemble traits, records, registries, and
  viewer calls; there is no global dependency-injection container.

## Dependency Rules

Read exact dependencies from `moon.pkg` manifests. The stable architectural
rules are:

- Product packages must not import `moonbit-community/editor/internal/shell/*`.
- Product code must not import from `vscode/` or `codemirror/`.
- `internal/shell/*` packages may depend on product packages, but product
  packages must not depend on the reference shell.
- Shared packages must stay FFI-free. Packages that only run on one host target
  may declare that host's FFI.
- `viewer/*` packages may use only the Rabbita API bindings (`rabbita/dom`,
  `rabbita/js`), not the Rabbita TEA framework packages.
- Browser-UI viewer subpackages do not import the parent `viewer` package; the
  edge stays one-directional from `viewer` to those helpers.
- Concrete `syntax/lang_*` packages are imported by hosts, examples, and tests,
  not by the reusable viewer core.

`scripts/check-architecture.mbtx`, run by `just check`, enforces the guardrails
the MoonBit toolchain cannot catch directly: no reference-tree imports, no
outside-shell imports of `internal/shell/*`, and no Rabbita framework imports
from `viewer/*` packages.

## Build Targets

Browser packages use `supported_targets = "js"`. Native host packages use
`supported_targets = "native"`. Shared packages stay target-neutral.

Repository-level validation starts with `just check`.

## Position And Range Convention

Offsets and columns are UTF-16 code units.

- `base/common.Position`, `Range`, and `LineRange` follow Monaco's line/column
  convention: line numbers and columns are 1-based.
- `base/common.OffsetRange` is a half-open 0-based UTF-16 offset span
  `[start, end_exclusive)`.
- `viewer/model.TextSnapshot` owns conversion between offsets and line/column
  positions/ranges.
- LSP wire positions are 0-based and convert at the shell/backend boundary.

Keep conversions at the boundary where coordinate spaces meet. Code that needs
offset spans should say `OffsetRange`; code that models editor positions should
use the Monaco-style line/column types.
