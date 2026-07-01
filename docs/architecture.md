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
- `viewer/common/model`: readonly `TextModel` and `TextSnapshot` plus the
  decoration types (`Decoration`, `DecorationSet`, merged from the former
  `viewer/decorations`). This is the editor model identity used by viewer and
  language-provider APIs.
- `viewer/common/view_model`, `viewer/common/view_layout` (with the view-line
  renderer merged in), and `viewer/common/core`: DOM-free rendering, projection,
  layout, geometry, and cursor-column logic.
- `viewer/common/cursor`, `viewer/common/markers`, and `viewer/common/languages`:
  focused DOM-free feature packages used by the viewer.
- `viewer/contrib/folding` and `viewer/contrib/hover`: the DOM-free *models* of
  Monaco contributions (`editor/contrib/{folding,hover}/browser` in Monaco, which
  has no native target). They stay **multi-target** so the native check keeps
  enforcing DOM-freeness; the js-only DOM controllers/widgets land in
  `viewer/contrib/{folding,hover}/browser` in a later increment. `common` code
  never imports these (the folding indent fallback was inverted into the folding
  controller so the tier flows `contrib -> common`, not the reverse).
- `viewer/common`: a shrinking residual of the former grab-bag (`line_html`,
  `mouse_target`) pending the browser carve-up (`mouse_target` →
  `viewer/browser/controller`).
- `viewer/controller` and `viewer/ui/scrollbar`: browser-UI subpackages. They
  may use narrow browser bindings but do not import the parent `viewer` package.
- `viewer/common/inline_decorations`: a dedicated Monaco conformance/support
  package for inline-decoration algorithms. It is not part of the live viewer
  import chain unless a future integration explicitly wires it in.
- `base/common`: host-neutral URI, lifecycle, and coordinate primitives.
- `language`: backend-neutral readonly semantic provider contracts over
  `viewer/model.TextModel`.
- `syntax` and `syntax/lang_*`: tokenization contracts and concrete
  compile-time lexers. Hosts import concrete language packages and register them
  with the viewer.
- `platform/log`: host-neutral structured logging contracts.

## Viewer Three-Tier Mirror (target structure)

The `viewer/` tree is migrating to mirror Monaco's `vs/editor/{common,browser,contrib}`
at directory granularity (one Monaco directory → one MoonBit package). The
migration is staged in `docs/exec-plans/viewer-directory-mirror.md`; the flat
`viewer/<feature>` packages and the root `viewer/*.mbt` god-package above are the
*current* truth until each carve-up increment lands. The target tiers are:

- `viewer/common/**` — DOM-free logic (model, view_model, view_layout, cursor,
  languages, decorations, view-line renderer, core, tokens, services). Mirrors
  `editor/common/*`. **Multi-target** (`+js+native`): the no-DOM rule is enforced
  by the native build, not by convention.
- `viewer/browser/**` — DOM-owning view, view parts (`view_parts/*`), controller,
  and the `widget/code_editor` host. Mirrors `editor/browser/*`. **js-only**
  (`supported_targets = "js"`).
- `viewer/contrib/<feature>/` — the DOM-free *model* of a Monaco contribution
  (`folding`, `hover`). **Multi-target**, like the common tier. Divergence from
  Monaco (which files these under `contrib/*/browser` because it has no native
  target): the viewer hoists the DOM-free logic up so the native check keeps
  enforcing DOM-freeness.
- `viewer/contrib/<feature>/browser/**` — the js-only DOM half of a contribution
  (controllers/widgets). Mirrors `editor/contrib/*/browser`. **js-only**.
- root `viewer` — reduces to an `export.mbt` facade (the analog of
  `vs/editor/editor.api.ts`) re-exporting the public surface; `viewer/pkg.generated.mbti`
  is the reviewable public-API contract. Stays js-only because it re-exports
  browser types.

`scripts/check-architecture.mbtx` enforces the tier invariants (the
MoonBit-toolchain-uncatchable half): every `viewer/browser/**` and
`viewer/contrib/*/browser/**` package declares `supported_targets = "js"`; no
`viewer/common/**` or `viewer/contrib/<feature>/` (non-`browser`) package does
(the DOM-free tiers stay multi-target); and external consumers (the shell, web,
app, tests) import the `viewer` facade — never a `viewer/browser/**` or
`viewer/contrib/**` package directly. Native/headless consumers (the shell
server hosts) may import `viewer/common/**` directly, since the js-only facade
cannot link on native (Decision D2). The `common → browser` direction is caught
by `moon check --target all` itself: a multi-target package importing a js-only
one fails the native build.

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
viewer/common/model.TextModel
  -> viewer/common/view_model
  -> viewer/common/view_layout   (view-line renderer merged in)
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
outside-shell imports of `internal/shell/*`, no Rabbita framework imports
from `viewer/*` packages, the three-tier target invariants (browser-tier
packages js-only, common-tier packages multi-target), and no external imports of
the `viewer/browser/**` or `viewer/contrib/**` internals (see the Viewer
Three-Tier Mirror section).

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
