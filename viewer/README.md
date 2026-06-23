# viewer

The reusable readonly viewer package. It is the local Monaco `editor/browser`
role: a public `Viewer` facade plus an imperative browser `View` that owns its
DOM subtree inside a host-provided stable element.

It ships without explorer chrome, transport, persistence, file watching, or
reload policy. Hosts provide readonly `viewer/model.TextModel` values and call
the viewer API. The reference `internal/shell/workbench` is one host; it is not
part of this package or the public import surface.

## Embedding API

- `Viewer::Viewer(services?, options?, theme?, placeholder?)` constructs an
  unattached viewer. `Viewer::create(host, ...)` constructs and attaches in one
  call.
- `Viewer::attach(host)` mounts into one stable host element. The host must not
  render children into that element after attach.
- `Viewer::set_model(model, view_state?)` installs caller-owned readonly model
  state. The model may come from memory, a backend, a workspace provider, or any
  other host-owned source.
- `Viewer::clear_model(view_state?)`, `get_model()`, `current_model()`,
  `save_view_state()`, and `restore_view_state()` expose model identity and
  viewport state.
- `Viewer::dispose()` releases viewer-owned subscriptions and DOM state. It
  does not close files, cancel watches, or own source lifecycle.
- `set_theme`, `set_placeholder`, `remeasure`, `escape`, and scroll methods are
  host entrypoints for state, captured keyboard input, and synthetic scrolling.
- Typed subscriptions report model changes, frame builds, render results,
  diagnostics, hover resolution, scroll, and disposal.
- `@viewer.languages.*` is the default language registry. Hosts register
  tokenizers and semantic providers there, or create an isolated `Languages`
  value and pass it through `ViewerServices::new(languages~)`.
- `ViewerServices` owns per-viewer service objects such as marker state, hover
  participants, and logging.

## Responsibilities

- Own the browser editor DOM, CSS-facing class structure, measurement, native
  input capture, custom scrollbars, content widgets, overlay widgets, hover,
  folding controls, inlay hint projection, readonly selection/copy, view zones,
  and lifecycle events.
- Keep viewer-owned styles next to the viewer part that owns the corresponding
  DOM; `scripts/build-web.mbtx` assembles those files into the served
  `/style.css`.
- Render DOM from the viewer common layer:

  ```text
  viewer/model.TextModel
    -> viewer/view_model
    -> viewer/view_layout
    -> viewer/view_line_renderer
    -> viewer View
  ```

- Keep the public/root-facing contract MoonBit-owned while using Monaco-shaped
  internal view roles where useful: view parts, line layer, margin overlays,
  content widgets, overlay widgets, zones, and editor scrollbars.
- Keep feature results fresh by checking current model URI plus version before
  applying async provider answers.
- Keep syntax and semantic features provider-based. The viewer consumes
  registered providers; it does not import concrete `syntax/lang_*` packages or
  backend transports.

Current readonly behavior includes rendering, syntax highlighting, diagnostics
as markers, hover, folding, inlay hints, selection/copy, scrolling, and view
zones. Go-to-definition and find-references are not current viewer behavior.

## Boundaries

- May depend on `rabbita/dom` and `rabbita/js` for browser effects it owns.
  It must not depend on Rabbita TEA, vdom, or command packages.
- May depend on `base/common`, `language`, `platform/log`, `viewer/common`,
  `viewer/cursor`, `viewer/model`, `viewer/view_line_renderer`,
  `viewer/view_layout`, `viewer/view_model`, `syntax`, and `decorations`.
- May depend on focused markdown-rendering packages used by hover content.
- Must not depend on `baozhiyuan/editor/internal/shell/*` packages or
  websocket transports.
- Must not import concrete `syntax/lang_*` packages.
- May declare narrowly scoped JavaScript FFI for viewer-owned browser effects.
  Shared viewer common-layer packages must remain FFI-free.
- Must not pass render-frame JSON to JavaScript for DOM rendering.

## Checks

- Hover scheduling and staleness: `hover_controller_wbtest.mbt`.
- Viewer services and hover participants: `services_wbtest.mbt`.
- Browser component tests cover public API construction, selection/copy,
  wrapping, hover overlap, folding, view zones, and inlay-hint copy behavior.
- Embedding boundary: `internal/shell/examples/embedded_viewer` and
  `tests/browser/smoke/embed.spec.js`.
- Run `just check` for the repository-level guardrail.
