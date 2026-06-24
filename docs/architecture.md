# Architecture

The current project has two main parts.

1. `viewer`: the reusable MoonBit readonly viewer. It provides the public
   viewer API, owns the browser editor surface, and follows Monaco-shaped
   behavior where that helps readonly embedders.
2. `internal/shell`: a small reference host/backend used to see the viewer
   working against a real workspace. It illustrates one host composition, but
   it is not an external import surface and must use viewer public APIs instead
   of reaching into viewer implementation details.

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
- `viewer/common`, `viewer/view_model`, `viewer/view_layout`,
  `viewer/view_line_renderer`, and `viewer/decorations`: DOM-free viewer common
  layer for tokenized lines, render frames, projections, layout, viewport data,
  scrollbar arithmetic, hit testing, render-line HTML/character mapping, and the
  range-based decoration carrier (`viewer/decorations`, Monaco
  `vs/editor/common/model` decorations).
- `viewer/cursor`, `viewer/folding`, and `viewer/markers`: DOM-free feature
  models the viewer drives. `viewer/cursor` is the readonly cursor/selection
  state; `viewer/folding` is the folded-range set operations and fallback
  folding-range computation (Monaco `contrib/folding/`); `viewer/markers` is
  the marker store, squiggle decorations, and marker-hover lookup (Monaco's
  marker stack). The browser-side controls for these (folding gutter toggle,
  squiggle DOM) stay in `viewer`.
- `viewer/languages`: the language-feature registry (Monaco's
  `ILanguageFeaturesService` / `vs/editor/common` language features) — the
  tokenizer registry plus ordered hover, diagnostics, document-symbol,
  semantic-token, folding-range, and inlay-hint providers, with the
  process-wide `languages` value hosts register against.
- `viewer/hover`: the content-hover feature (Monaco `contrib/hover/`) —
  hover-part types, the participants (marker, inlay-hint, markdown), the free
  participant registry plus its default-participant contribution, the
  `ContentHoverComputer`, and hover rendering. Participants capture their own
  services (`HoverParticipantServices`), so the package depends on
  `viewer/languages` and `viewer/markers` but never on the `viewer` core. The
  hover *controller* — the timing state machine and its event driver — stays in
  `viewer` core, the way Monaco drives a contribution from the editor.
- `viewer/ui/scrollbar`: the custom scrollbar widget (Monaco
  `base/browser/ui/scrollbar/`). Unlike the common-layer packages it owns
  browser DOM, so it is a *browser-UI subpackage*: it may import `rabbita/dom`
  and declare narrow JS FFI, but not the shell or the rabbita TEA/vdom/command
  layers. The edge stays one-directional: `viewer -> viewer/ui/scrollbar`.
- `viewer/controller`: the browser input controller (Monaco
  `editor/browser/controller/`). A browser-UI subpackage like the scrollbar; it
  owns the pointer-input layer — mouse selection + hit test (Monaco
  `MouseDownOperation`/`mouseTarget`), scrollbar interaction, wheel, and
  drag-autoscroll — and calls back into the view through a `PointerHandlerHelper`
  (Monaco's `IPointerHandlerHelper`, built as a struct of nodes + closures), so
  the edge stays one-directional: `viewer -> viewer/controller`. The viewer core
  keeps the measurement read-phase (exposed via the helper) and the dispatch
  side (`Viewer::dispatch_mouse`, Monaco's `ViewController`).
- `base/common`: host-neutral URI identity and shared resource primitives.
- `language`: backend-neutral readonly semantic provider contracts over
  `viewer/model.TextModel`.
- `syntax` and `syntax/lang_*`: tokenization contracts and concrete
  compile-time lexers. Hosts import concrete language packages and register
  tokenizers with the viewer.
- `platform/log`: a small shared support package.

### Reference Shell

- `internal/shell/web`: generated browser entrypoint. It starts the workbench
  and should not grow application logic. Built assets still land in `web/dist`.
- `internal/shell/workbench`: the reference browser shell. It composes the
  viewer, internal file tree, syntax packages, remote protocol client, theme
  state, shell UI, and test observability.
- `internal/shell/widgets/file_tree`: explorer widget over internal
  `workspace` providers. It does not know about the viewer or transport.
- `internal/shell/remote_protocol`: MoonBit-owned packets between the
  reference workbench and reference backend.
- `internal/shell/server`: remote workspace policy and semantic feature
  routing.
- `internal/shell/server_host_native`: native filesystem, watching, process,
  socket, static serving, and LSP-process effects for the reference backend.
- `internal/shell/examples/embedded_viewer`: small non-remote embedding proof.
  It demonstrates that the viewer can run without the remote backend.

`internal/shell/workspace` defines host-side source and tree provider contracts
used by the reference shell and examples. It is not the viewer model API.

## Main Flows

### Embedding

```text
host app
  -> viewer.Viewer
  -> viewer/model.TextModel
  -> optional language providers
  -> optional tokenizer registration
```

The host creates or fetches readonly document content, converts it into a
`viewer/model.TextModel`, and installs it on the viewer. The viewer owns
rendering, scrolling, hover presentation, selection/copy, widget placement, and
lifecycle events. The host owns files, transport, persistence, reload policy,
shell chrome, and error display. The repo's workspace/tree/transport example is
internal to `internal/shell`; external embedders should provide their own host
code around the public viewer/language APIs.

Language features are provider-based. Providers may compute locally, call a
backend, or read host state. The viewer depends only on the provider contracts
and result values.

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

`internal/shell/workbench` adapts remote protocol responses into host-owned
providers and `viewer/model.TextModel` values, then calls the viewer API.
`internal/shell/server` owns remote workspace policy.
`internal/shell/server_host_native` owns native effects.

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
  `internal/shell/workspace.DocumentSnapshot` through viewer or
  language-provider APIs.
- Semantic provider contracts belong in `language`.
- Runtime language registration belongs in `viewer.languages`; concrete
  tokenizers belong in `syntax/lang_*` and are imported by host packages.
- Reference shell source/tree provider contracts belong in
  `internal/shell/workspace`.
- Reference app behavior belongs in `internal/shell/workbench` or an internal
  example package.
- Reference shell UI around the viewer belongs under `internal/shell/widgets/*`.
- Remote packet shape belongs in `internal/shell/remote_protocol`.
- Remote workspace policy belongs in `internal/shell/server`.
- Native filesystem, process, socket, and static-serving effects belong in
  `internal/shell/server_host_native`.
- Public packages must not import `moonbit-community/editor/internal/shell/*`.
- JS-only packages may declare narrowly scoped JS FFI for effects they own.
  Shared packages must remain FFI-free.
- Product code must not import from `vscode/` or `codemirror/`.

Composition stays explicit. Hosts assemble plain MoonBit traits, records,
registries, and viewer calls. There is no global dependency-injection container.

## Dependency Direction

Dependencies flow from host entrypoints toward viewer and shared domain
packages:

```text
internal/shell/web -> internal/shell/workbench
internal/shell/workbench -> base/common, viewer, viewer/model,
                            internal/shell/widgets/file_tree,
                            internal/shell/remote_protocol,
                            internal/shell/workspace, language,
                            syntax/lang_*, platform/log
viewer -> base/common, viewer/common, viewer/controller, viewer/cursor,
          viewer/folding, viewer/hover, viewer/languages, viewer/markers,
          viewer/model, viewer/ui/scrollbar, viewer/decorations,
          viewer/view_line_renderer, viewer/view_layout, viewer/view_model,
          language, syntax, platform/log

internal/shell/server_host_native/main -> internal/shell/server_host_native
internal/shell/server_host_native -> base/common, internal/shell/server,
                                     internal/shell/remote_protocol,
                                     internal/shell/workspace, language,
                                     viewer/model
internal/shell/server -> base/common, internal/shell/remote_protocol,
                         internal/shell/workspace, language, viewer/model
internal/shell/remote_protocol -> base/common, internal/shell/workspace,
                                  language
internal/shell/widgets/file_tree -> base/common, internal/shell/workspace

language -> base/common, viewer/model
internal/shell/workspace -> base/common
syntax -> base/common, viewer/model
viewer/decorations -> base/common
viewer/model -> base/common
viewer/folding -> language, viewer/model
viewer/languages -> base/common, language, platform/log, syntax,
                    viewer/folding, viewer/model
viewer/hover -> base/common, language, platform/log, syntax, viewer/common,
                viewer/decorations, viewer/languages, viewer/markers,
                viewer/model, viewer/view_model, cmark/*
viewer/markers -> base/common, language, viewer/decorations
viewer/ui/scrollbar -> viewer/view_layout, rabbita/dom
viewer/controller -> viewer/ui/scrollbar, viewer/view_layout, rabbita/dom
platform/log -> no product packages
syntax/lang_* -> syntax, viewer/model
```

`scripts/check-architecture.mbtx`, run by `just check`, enforces three import
boundaries — the ones the MoonBit toolchain cannot catch on its own:

1. No product source references the reference trees (`vscode/`, `codemirror/`).
2. Nothing outside `internal/shell/` imports `internal/shell/*`, so the reusable
   surface never depends on the reference shell.
3. `viewer/*` packages import only the Rabbita API bindings (`rabbita/dom`,
   `rabbita/js`), never the Rabbita TEA framework (`rabbita`, `rabbita/html`,
   `rabbita/cmd`, `rabbita/websocket`, …).

Everything else is left to the toolchain: MoonBit rejects package cycles, and
`supported_targets` rejects DOM-only imports into native packages. Which viewer
sub-packages stay DOM-free, and the one-directional `viewer -> sub-package`
edges, are a design discipline that follows Monaco's module seams rather than a
machine-checked rule.

## Build Targets

Browser packages use `supported_targets = "js"`. Native host packages use
`supported_targets = "native"`. Shared packages stay target-neutral.

Repository-level validation starts with `just check`.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser strings,
Monaco/CodeMirror position behavior, and default LSP positions.

The viewer mixes 0-based, 1-based, and offset coordinate spaces; read against
the Monaco oracle with this split in mind:

- **`base/common.Position` is 0-based** on both axes (line and UTF-16 column),
  where **Monaco's `Position` is 1-based**. Every Monaco invariant (`minColumn
  === 1`, etc.) shifts by one when read against this type.
- **`base/common.Range` is an offset range `[start, end)`**, not a line/column
  pair. It reuses Monaco's type name for a different concept. The line/column
  analog of Monaco's `Range` is `view_line_renderer.ViewRange`, which is
  **1-based**. `CharacterMapping` is likewise **1-based**.
- The 0-based `Position` ↔ 1-based `ViewRange` / `CharacterMapping` seams need
  explicit `±1` conversions (`start.line + 1`, `col1 - 1`). These are internally
  consistent, but the seam is a recurring off-by-one surface — keep conversions
  at the boundary where coordinate spaces meet.
