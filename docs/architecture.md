# Architecture

This repository contains a reusable MoonBit readonly viewer and a reference
host/backend:

- `viewer` is the js-only public editor facade and browser surface.
- `internal/shell` is the demo, development, and end-to-end host. It is not an
  external import surface.

For exact APIs use the owning package's `pkg.generated.mbti`; for exact
dependencies use `moon.pkg`. Implemented files under `docs/exec-plans/` are
historical evidence, not current architecture.

Monaco/VS Code is the primary behavioral and structural reference. CodeMirror
is secondary. `vscode/` and `codemirror/` are pinned research trees only;
product code never imports them and public names remain MoonBit-owned.

## Runtime Shape

```text
host document
  -> viewer/common/model.TextModel
  -> viewer/common/view_model.ViewModel
  -> viewer/common/view_layout.ViewLayout
  -> viewer/browser/view.View
  -> viewer/browser/view_parts/*
  -> DOM
```

`Viewer` owns a nullable per-model `ModelData` bundle containing the model,
view model, browser view, and swap-scoped listeners. `set_model` detaches that
bundle and creates a fresh one. With no attached DOM, the same model/view-model
pipeline remains usable by white-box tests; only the browser `View` is absent.

The host owns files, transport, persistence, reload policy, shell chrome, and
error presentation. The viewer owns readonly rendering, selection, scrolling,
widgets, language-feature presentation, and editor events.

## Package Tiers

### Shared foundations

- `base/common`: URI/path, positions/ranges, events, and disposables.
- `base/browser`: browser mouse and global pointer-move primitives.
- `language`: backend-neutral diagnostic, hover, location, symbol, and inlay
  provider contracts.
- `syntax` and `syntax/lang_*`: stateful line-tokenization contracts and
  concrete compile-time lexers.
- `platform/log`: host-neutral logging.

### Viewer common tier

`viewer/common/**` is DOM-free and multi-target:

- `model` and `model/tokens`: immutable text snapshots, model identity,
  decorations, and tokenization state.
- `services` and `tokens`: language-id encoding and compact line tokens.
- `languages` and `markers`: runtime provider registration and
  diagnostics-to-decoration flow.
- `core`, `cursor`, `config`: coordinates, selection/cursor state, and editor
  configuration values.
- `inline_decorations`, `view_model`, `view_layout`: injected text,
  wrapping/folding projection, model/view conversion, scrolling, viewport,
  zones, and view-line rendering data.
- `diff`: line diff contracts used by quick diff.
- the root `viewer/common` package is a small compatibility surface for line
  HTML helpers.

Common code never imports browser or contribution packages.

### Viewer browser tier

The root `viewer`, `viewer/browser/**`, and `viewer/ui/scrollbar` are js-only:

- `viewer` is the public facade, the Monaco `CodeEditorWidget` and
  `editor.api.ts` role. Public browser construction is `Viewer::create`.
- `viewer/browser` owns editor mouse events, target kinds, and DOM coordinates.
- `viewer/browser/config` measures fonts and browser geometry.
- `viewer/browser/controller` owns hit testing, mouse selection, drag
  scrolling, and scrollbar input.
- `viewer/browser/view` owns the DOM tree and render ordering.
- `viewer/browser/view_parts/*` owns content/overlay widgets, current-line and
  model decorations, margin, selections, cursor, virtualized lines, zones, and
  the scrollbar view part.
- `viewer/ui/scrollbar` owns custom scrollbar DOM and pointer behavior; its
  arithmetic lives in `viewer/common/view_layout`.

MoonBit's orphan rule keeps `impl ViewPart for <foreign part>` blocks in the
trait-owning `viewer/browser/view` package. Root `viewer/*.mbt` contains
`Viewer::` glue because foreign methods must live with `Viewer`.

### Contributions

Contributions depend on editor common/browser layers; editor common never
depends on them.

- `viewer/contrib/hover` is the DOM-free state/computation layer;
  `hover/browser` owns its widget and browser controller.
- `viewer/contrib/agent_feedback` owns feedback data/service projection;
  `agent_feedback/browser` owns input and bubble widgets.
- `viewer/contrib/quick_diff/common` owns baseline state and diff contracts;
  `quick_diff/browser` produces gutter decorations.
- `viewer/contrib/folding/browser` currently owns the complete js-only folding
  implementation, including ranges, hidden areas, decorations, and controller.
- inlay-hint host glue currently lives in the root `viewer` package and
  projects hints as injected-text decorations.

The root editor registry constructs contributions once per `Viewer` and routes
their commands/keybindings. Declared instantiation modes are retained for
source parity, but all modes currently instantiate eagerly.

## Reference Shell

The direct embedding proof is:

```text
internal/shell/examples/embedded_viewer
  -> viewer
  -> viewer/common/{model,languages}
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
- Workbench-tier packages (`internal/shell/**`, except examples, and `tests/**`)
  may import viewer internals. External-host stand-ins may import only root
  `viewer` and `viewer/common/**`.
- Concrete `syntax/lang_*` packages are selected by hosts, examples, or tests,
  not by the reusable viewer core.

## Coordinates

- `Position`, `Range`, and `LineRange` use 1-based UTF-16 line/column values.
- `OffsetRange` is a 0-based half-open UTF-16 span.
- `TextSnapshot` owns offset/position conversion.
- Keep conversions at model/view, protocol, and DOM boundaries; do not pass an
  unlabelled integer between coordinate spaces.
