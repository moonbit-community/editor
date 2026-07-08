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
- `viewer/common/model`: readonly `TextModel` and `TextSnapshot` plus model
  decorations (interval-tree storage backing `TextModel::delta_decorations`).
  This is the editor model identity used by viewer and language-provider APIs.
- `viewer/common/view_model`, `viewer/common/view_layout` (with the view-line
  renderer merged in), and `viewer/common/core`: DOM-free rendering, projection,
  layout, geometry, and cursor-column logic.
- `viewer/common/cursor`, `viewer/common/markers`, `viewer/common/comments`,
  and `viewer/common/languages`: focused DOM-free feature packages used by the
  viewer. `comments` holds the comment thread/comment data model only —
  Monaco's `editor/common/languages.ts` filing; the `CommentService` lives
  with its feature in `viewer/contrib/comments` (Monaco's
  `workbench/contrib/comments/browser/commentService.ts` shape).
- `viewer/contrib/folding`, `viewer/contrib/hover`, and
  `viewer/contrib/comments`: the DOM-free *models* of Monaco contributions
  (`editor/contrib/{folding,hover}/browser` and
  `workbench/contrib/comments/browser` in Monaco, which has no native target).
  They stay **multi-target** so the native check keeps enforcing DOM-freeness;
  js-only DOM controllers/widgets live in `viewer/contrib/<feature>/browser`
  (populated for `comments` and `zone_widget`). `common` code never imports
  these (the folding indent fallback was inverted into the folding controller
  so the tier flows `contrib -> common`, not the reverse).
- `viewer/common`: a shrinking residual of the former grab-bag (`line_html`,
  `mouse_target`). The DOM-free hit-testing value types and algorithm stay
  here (not in the js-only `viewer/browser/controller`) because the
  multi-target `viewer/contrib/hover` depends on `MouseTarget` directly.
- `viewer/browser/controller` and `viewer/ui/scrollbar`: browser-UI
  subpackages. They may use narrow browser bindings but do not import the
  parent `viewer` package.
- `viewer/browser/view` and `viewer/browser/view_parts/*` (`content_widgets`,
  `current_line_highlight`, `decorations`, `editor_scrollbar`, `margin`,
  `overlay_widgets`, `selections`, `view_cursors`, `view_lines`,
  `view_zones`): the browser view and its view parts. Every
  `impl ViewPart for X` block lives in `viewer/browser/view/view_part.mbt`,
  the trait-owning package — see its README for the orphan-rule/cycle
  reasoning. The dynamic overlays (`current_line_highlight`, `decorations`)
  render into `selections`' shared `.view-overlays` container as free
  functions, sequenced by the shell in Monaco's registration order. The flat root `viewer/*.mbt`
  files are `Viewer`-facing glue only: the foreign-method rule keeps every
  `Viewer::` method in `Viewer`'s own package.
- `viewer/common/inline_decorations`: the faithful port of Monaco's
  inline-decoration computers, kept as its own package for name-collision
  reasons (see its README). Live: `viewer/common/view_model`'s
  `ViewModelDecorations` builds on it.
- `base/common`: host-neutral URI, lifecycle, and coordinate primitives.
- `language`: backend-neutral readonly semantic provider contracts over
  `viewer/common/model.TextModel`.
- `syntax` and `syntax/lang_*`: tokenization contracts and concrete
  compile-time lexers. Hosts import concrete language packages and register them
  with the viewer.
- `platform/log`: host-neutral structured logging contracts.

## Viewer Three-Tier Mirror

The `viewer/` tree mirrors Monaco's `vs/editor/{common,browser,contrib}` at
directory granularity (one Monaco directory → one MoonBit package), staged in
`docs/exec-plans/viewer-directory-mirror.md`. The mirror is functionally
complete, with one deliberate, permanent exception — the root `viewer`
package (last bullet below). The tiers are:

- `viewer/common/**` — DOM-free logic (model, view_model, view_layout, cursor,
  languages, decorations, view-line renderer, core, tokens). Mirrors
  `editor/common/*`. **Multi-target** (`+js+native`): the no-DOM rule is enforced
  by the native build, not by convention.
- `viewer/browser/**` — DOM-owning view and view parts (`view_parts/*`) and
  the input controller. Mirrors `editor/browser/*`. **js-only**
  (`supported_targets = "js"`).
- `viewer/contrib/<feature>/` — the DOM-free *model* of a Monaco contribution
  (`folding`, `hover`, `comments`). **Multi-target**, like the common tier.
  Divergence from Monaco (which files these under `contrib/*/browser` because
  it has no native target): the viewer hoists the DOM-free logic up so the
  native check keeps enforcing DOM-freeness.
- `viewer/contrib/<feature>/browser/**` — the js-only DOM half of a contribution
  (controllers/widgets). Mirrors `editor/contrib/*/browser`. **js-only**.
  Populated for `zone_widget` (the `zoneWidget.ts` port: spacer view zone +
  overlay widget) and `comments` (the thread widget over it). Not populated
  for `hover`: the DOM-free hover state machine already covers it (see above);
  the only DOM-touching hover code is `content_widgets` and the root package's
  dispatch glue.
- root `viewer` — the one deliberate exception to directory-granularity: it
  holds the top-level `Viewer`/`ViewerOptions`/public read-API implementation
  directly (Monaco's `editor/browser/widget/codeEditor/` role) and doubles as
  the public entry point, the analog of `vs/editor/editor.api.ts`. There is no
  `export.mbt` facade (Decision D2-REVERSED,
  `docs/exec-plans/viewer-directory-mirror.md`); `viewer/pkg.generated.mbti`
  is the reviewable public-API contract, generated from the real code. Stays
  js-only because it owns DOM.

`scripts/check-architecture.mbtx` enforces the tier invariants (the
MoonBit-toolchain-uncatchable half): every `viewer/browser/**` and
`viewer/contrib/*/browser/**` package declares `supported_targets = "js"`; no
`viewer/common/**` or `viewer/contrib/<feature>/` (non-`browser`) package does
(the DOM-free tiers stay multi-target). The `common → browser` direction is
caught by `moon check --target all` itself: a multi-target package importing a
js-only one fails the native build. Likewise `viewer/common/**` never imports
`viewer/contrib/**` (Monaco: editor core cannot import contribs), enforced by
the package-cycle checker and that same target discipline.

Imports into the viewer tree follow VS Code's consumer classes
(`vscode/eslint.config.js`, `code-import-patterns`):

- **Workbench tier** — `internal/shell/**` (except `internal/shell/examples/**`)
  and `tests/**` may import any viewer package: `internal/shell` consumes
  viewer internals the way VS Code's workbench consumes `vs/editor/**`
  (`eslint.config.js:1735`).
- **External hosts** — `internal/shell/examples/**` and every other product
  package (`web`, `app`, future hosts) import only the root `viewer` package
  and `viewer/common/**`: the analog of `monaco-editor` npm consumers behind
  `editor.api.ts` (`eslint.config.js:1723`). Native/headless consumers (the
  shell server hosts) import `viewer/common/**` directly, since the js-only
  root package cannot link on native.
  `internal/shell/examples/embedded_viewer` imports only `viewer`,
  `viewer/common/languages`, and `viewer/common/model` — it is the named proof
  that the public facade suffices for embedding.

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
- `internal/shell/server_host_native`: native filesystem, watch, socket, and
  static-serving effects, plus the `moon` command backend for hover
  (`moon ide hover`) and diagnostics (`moon check`).
- `internal/shell/examples/embedded_viewer`: non-remote embedding proof.

## Core Flows

### Embedding

```text
host app
  -> viewer.Viewer
  -> viewer/common/model.TextModel
  -> optional viewer/common/languages registrations
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
providers and `viewer/common/model.TextModel` values before calling viewer APIs. The
backend stack exists to exercise the viewer, not to define the reusable viewer
surface.

### Rendering

```text
viewer/common/model.TextModel
  -> viewer/common/view_model
  -> viewer/common/view_layout   (view-line renderer merged in)
  -> viewer/browser/view (DOM)
```

DOM-free text, projection, layout, viewport, scrollbar, and hit-test state live
in the viewer common-layer packages. Browser DOM, CSS, measurement, native
events, custom scrollbars, and widget DOM live in `viewer` or its browser-UI
subpackages.

## Placement Rules

- Public readonly editor behavior belongs in `viewer`.
- Editor text identity belongs in `viewer/common/model`; do not expose
  `internal/shell/workspace.DocumentSnapshot` through viewer or provider APIs.
- DOM-free model, layout, viewport, render-line, and decoration logic belongs in
  the focused `viewer/*` common-layer packages.
- Browser input and browser widget helpers may live in browser-UI subpackages
  such as `viewer/browser/controller` and `viewer/ui/scrollbar`.
- Semantic provider contracts belong in `language`; runtime provider
  registration belongs in `viewer/common/languages`.
- Concrete tokenizers belong in `syntax/lang_*` and are imported only by
  composition layers.
- Reference app behavior belongs under `internal/shell`.
- Composition stays explicit. Hosts assemble traits, records, registries, and
  viewer calls; there is no global dependency-injection container.

Controller access: Monaco hosts reach a contribution's controller via
`FoldingController.get(editor)` — `editor.getContribution<T>(id)`
(`codeEditorWidget.ts`), a TypeScript downcast. MoonBit cannot downcast a
trait object, so the faithful rendering is an instance table owned by each
contrib package: a `Map[String, Controller]` keyed by `editor_id` (the
WeakMap analog), populated by the feature's contribution ctor and cleared by
its dispose, with hosts calling `@<feature>.get(viewer.get_id())`. The
pattern has three real consumers: `ContentHoverController`
(`viewer/contrib/hover/browser` — the mirror package for
`editor/contrib/hover/browser`, js-only), the two agent-feedback
contributions (`viewer/contrib/agent_feedback/browser`), and
`InlayHintsController` (root package, next to its `inlay_hints_host.mbt`
glue — the mirror has no `contrib/inlay_hints` package yet). Per-feature
state lives on those controller instances; the `Viewer::` glue methods keep
the dispatch role (the foreign-method rule pins them to the root package)
and read/write state through the instance.

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
- `viewer/common/**` never imports `viewer/contrib/**` (Monaco: editor core
  cannot import contribs).
- `internal/shell/**` (except `internal/shell/examples/**`) and `tests/**` are
  workbench-tier consumers: they may import any viewer package, including
  `viewer/browser/**` and `viewer/contrib/**`, the way VS Code's workbench
  consumes `vs/editor/**`. Every other non-`viewer` package — including the
  embedding examples — imports only the root `viewer` package and
  `viewer/common/**` (see the Viewer Three-Tier Mirror section).
- Concrete `syntax/lang_*` packages are imported by hosts, examples, and tests,
  not by the reusable viewer core.

`scripts/check-architecture.mbtx`, run by `just check`, enforces the guardrails
the MoonBit toolchain cannot catch directly: no reference-tree imports, no
outside-shell imports of `internal/shell/*`, no Rabbita framework imports
from `viewer/*` packages, the three-tier target invariants (browser-tier
packages js-only, common-tier packages multi-target), and the viewer consumer
classes (workbench-tier shell/tests import viewer internals freely;
external-host stand-ins only the root `viewer` package and `viewer/common/**`
— see the Viewer Three-Tier Mirror section).

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
- `viewer/common/model.TextSnapshot` owns conversion between offsets and
  line/column positions/ranges.
- `moon ide hover --output-json` and `moon check --output-json` locations are
  1-based line/column with exclusive end columns and map directly onto `Range`.

Keep conversions at the boundary where coordinate spaces meet. Code that needs
offset spans should say `OffsetRange`; code that models editor positions should
use the Monaco-style line/column types.
