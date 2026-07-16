# Architecture

This repository contains a reusable MoonBit readonly viewer and a reference
host/backend:

- `viewer` is the js-only public editor facade and browser surface.
- `internal/shell` is the demo, development, and end-to-end host. It is not an
  external import surface.

For exact APIs use the owning package's `pkg.generated.mbti`; for exact
dependencies use `moon.pkg`. Completed-plan summaries live in
`docs/exec-plans/HISTORY.md`; they are historical evidence, not current
architecture.

Monaco/VS Code is the primary behavioral reference and a source of tested
algorithmic and ownership patterns. It is not a required type, class, package,
or inheritance template: local representation follows MoonBit capabilities,
lifetime boundaries, and dependency direction. CodeMirror is secondary.
`vscode/` and `codemirror/` are pinned research trees only; product code never
imports them and public names remain MoonBit-owned.

## Runtime Shape

```text
host document
  -> viewer/common/model.TextModel
  -> viewer/common/view_model.ViewModel
  -> viewer/common/view_layout.ViewLayout
  -> viewer/browser/view.View
  -> DOM
```

`Viewer` keeps cross-domain ordering at the root and delegates private state to
five concrete owners: `EditorConfigurationState`, `ViewerModelSlot`,
`ViewerMount`, `EditorContributions`, and `CursorEventDelivery`.
`ViewerModelSlot.current` is the one nullable `ModelData`; its optional
`ModelBrowserData` pairs a real `View` with its retained mouse handler and
view-scoped render/reveal facts.

Headless means `ViewerMount::Headless`: there is no caller host, placeholder,
browser `View`, DOM focus state, or root animation frame. A headless Viewer may
still have a model and `ViewModel`, represented only by
`ModelData.browser=None`; on supported construction paths, a mounted model
always has `Some(ModelBrowserData)`. This is distinct from a mounted Viewer with
no model, which owns and paints one complete placeholder pair. Mounting is
one-way; disposal removes Viewer-owned DOM and clears mounted
placeholder/frame/focus state, but retains the caller's host for container
lookup.

The host owns files, transport, persistence, reload policy, shell chrome, and
error presentation. The viewer owns readonly rendering, selection, scrolling,
widgets, language-feature presentation, and editor events.

## Package Tiers

### Shared foundations

- `base/common`: URI/path, positions/ranges, events, and disposables.
- `base/browser`: canonical browser runtime and DOM primitives, mouse events,
  and global pointer-move monitoring.
- `language`: backend-neutral diagnostic, hover, location, and symbol provider
  contracts.
- `syntax` and `syntax/lang_*`: stateful line-tokenization contracts and
  concrete compile-time lexers.
- `platform/log`: host-neutral logging.

### Viewer common tier

`viewer/common/**` is DOM-free and multi-target:

- `model`: immutable text snapshots, model identity, decorations, and the
  complete model-owned tokenization cluster. Its shared live model state,
  stores, queues, backends, attached-view aggregation, and scheduling machinery
  are package-private.
- `services` and `tokens`: language-id encoding and compact line tokens.
- `editor_api`: the single owner of public cursor/model/scroll event values and
  editor-option enums shared by root, cursor, layout, view-model, and browser
  consumers.
- `agent_feedback_api` and `quick_diff_api`: host-facing DTO/callback handles;
  concrete feature implementations remain contributions below their callers.
- `languages` and `markers`: runtime provider registration and
  diagnostics-to-decoration flow. Their opaque `LanguageHandle`,
  `MarkerServiceHandle`, and `MarkerDecorationsHandle` expose only the reviewed
  Viewer capability floor while hosts retain the concrete registries/stores.
- `core`, `cursor`, `config`: coordinates, selection/cursor state, and editor
  configuration values.
- `view_model`: injected text, wrapping/folding projection, model/view
  conversion, and concrete inline/model decoration resolution.
- `view_layout`: scrolling, viewport, zones, and view-line rendering data.
- `diff`: line diff contracts used by quick diff.
- the root `viewer/common` package is a small compatibility surface for line
  HTML helpers.

Common code never imports browser or contribution packages.

### Viewer browser tier

The root `viewer`, `viewer/browser/**`, and `viewer/ui/scrollbar` are js-only:

- `viewer` is the opaque public facade, the Monaco `CodeEditorWidget` and
  `editor.api.ts` role. Public browser construction is only `Viewer::create`;
  `ViewerOptions`, `ViewerServices`, and `ViewerViewState` expose no public
  layout. Root generated interfaces may reference browser contracts and common
  capability handles, never private view or contribution implementations.
- `viewer/browser` owns canonical editor mouse events, target kinds, DOM
  coordinates, the mutable live ViewZone descriptor/opaque accessor contract, and
  the opaque unmanaged overlay-widget handle.
- `viewer/browser/testing` is a JS-only Viewer-id-keyed workbench/browser-test
  registry. Root publishes callback-backed build/render/hover facts downward;
  the package never imports root Viewer and is not an external API.
- `viewer/browser/config` measures fonts and browser geometry.
- `viewer/browser/controller` owns hit testing, mouse selection, drag
  scrolling, and scrollbar input.
- `viewer/browser/view` is one package owning the DOM tree, render/event
  ordering, recycler, content/overlay widgets, current-line and model
  decorations, margin, selections, cursor, virtualized lines, zones, and the
  scrollbar view part. Its focused `.mbt` files preserve source-unit
  responsibilities; they are not package or namespace boundaries.
- `viewer/browser/view_parts/*` contains CSS assets at their stable build
  paths. These asset-only directories have no MoonBit package or executable
  ownership.
- `viewer/ui/scrollbar` owns custom scrollbar DOM and pointer behavior; its
  arithmetic lives in `viewer/common/view_layout`.

`viewer/browser/view` owns closed event/render handle enums, rendering
contexts, concrete view parts, and their lifecycle wiring. Files in that
directory share private declarations as one compilation unit. Root
`viewer/*.mbt` contains `Viewer::` glue because foreign methods must live with
`Viewer`.

### Contributions

Contributions depend on editor common/browser layers; editor common never
depends on them.

- `viewer/contrib/hover` is the DOM-free state/computation layer;
  `hover/browser` owns its widget and browser controller.
- `viewer/contrib/agent_feedback` owns concrete feedback storage/service
  projection; host DTOs and the callback handle live in
  `viewer/common/agent_feedback_api`, while `agent_feedback/browser` owns input
  and bubble widgets.
- `viewer/contrib/quick_diff/common` owns baseline state and diff contracts;
  its public host handle lives in `viewer/common/quick_diff_api`, and
  `quick_diff/browser` produces gutter decorations.
- `viewer/contrib/folding/browser` currently owns the complete js-only folding
  implementation, including ranges, hidden areas, decorations, and controller.

The root editor registry has two distinct ownership layers. Its process-wide
contribution-description table contains constructors only; the adjacent command
and keybinding tables likewise contain no per-Viewer state.
`Viewer.contributions` is an `EditorContributions` owner whose `instances` map
is the sole lookup table for that Viewer's five concrete contribution entries;
feature packages do not keep second maps keyed by editor id. Root `Viewer::`
helpers recover typed controllers by matching both the fixed id and central
entry variant, mirroring Monaco's typed view over
`CodeEditorContributions._instances`.

Contribution construction is two-phase: reject a duplicate id before side
effects, construct the bare controller, insert the actual entry, then install
listeners and run initial synchronization. The content-hover entry's
`ContentHoverContributionState` owns its controller, lazy widget and logical
widget view, and timeout/async launch policy across model swaps. During
disposal, the complete map remains installed while entry behavior tears down;
the owner then becomes non-lookuppable, and retained hover browser resources
are released at their later root cleanup slot before the map is cleared.
Declared instantiation modes are retained for source parity, but all modes
currently instantiate eagerly.

This central ownership rule supersedes the feature-local instance tables from
the earlier ownership-divergence work. The completed migration is summarized in
`docs/exec-plans/HISTORY.md`; full review artifacts remain in Git history.

## Reference Shell

The direct embedding proof is:

```text
internal/shell/examples/embedded_viewer
  -> viewer
  -> viewer/common/{model,languages,editor_api,capability APIs}
```

The full reference app is:

```text
internal/shell/web
  -> internal/shell/workbench
     -> viewer
     -> internal/shell/widgets/file_tree
     -> internal/shell/remote_protocol

internal/shell/server_host_native/main
  -> internal/shell/server_host_native
  -> internal/shell/server
  -> internal/shell/{remote_protocol,workspace}
  -> language + viewer/common/model
```

- `workspace` defines host-side source paths, document snapshots, filesystem,
  and tree-provider contracts. Its `DocumentSnapshot` is not the editor model.
- `remote_protocol` is the reference app's versioned WebSocket JSON protocol,
  not LSP.
- `server` validates/caches documents and routes file and language requests.
- `server_host_native` provides filesystem/watch/HTTP/WebSocket effects and the
  current `moon ide hover`/`moon check` backend.
- `workbench` adapts protocol payloads into `TextModel`, language providers,
  markers, the file tree, theme, and harness events.

## Dependency Rules

`scripts/check-architecture.mbtx`, target checks, and MoonBit cycle checks
enforce these rules:

- Product code does not import `vscode/` or `codemirror/`.
- Only `internal/shell/**` imports `internal/shell/*` packages.
- `viewer/common/**` and non-browser contribution packages stay multi-target;
  `viewer/browser/**`, contribution `browser/**` packages, and root `viewer`
  stay js-only.
- Viewer packages may use `rabbita/dom` and `rabbita/js`, not Rabbita's TEA
  framework packages. The reference shell owns the app framework.
- Browser helper packages do not import the parent `viewer` facade.
- `viewer/common/**` does not import `viewer/contrib/**`.
- The root generated interface cannot expose private view/testing packages,
  contribution implementations, concrete services, duplicate option/cursor
  enums, public option/service/state layouts, or headless/debug/test helpers.
- Workbench-tier packages (`internal/shell/**`, except examples, and `tests/**`)
  may import viewer internals. External-host stand-ins may import only root
  `viewer` and `viewer/common/**`; the embedded example is the positive
  compile/runtime proof, and an excluded manifest fixture self-tests rejection
  of testing/contribution imports.
- Concrete `syntax/lang_*` packages are selected by hosts, examples, or tests,
  not by the reusable viewer core.

## Coordinates

- `Position`, `Range`, and `LineRange` use 1-based UTF-16 line/column values.
- `OffsetRange` is a 0-based half-open UTF-16 span.
- `TextSnapshot` owns offset/position conversion.
- Keep conversions at model/view, protocol, and DOM boundaries; do not pass an
  unlabelled integer between coordinate spaces.
