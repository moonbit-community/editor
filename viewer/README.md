# viewer

The reusable readonly viewer package and the public entry point. It plays
Monaco's `editor/browser/widget/codeEditor` role: the `Viewer` facade, its
options and services, and the `Viewer::`-facing glue around the browser view.
`viewer/pkg.generated.mbti` is the reviewable public-API contract; this README
covers ownership and rules, not the API list.

The public `Viewer::` API is a strict readonly subset of Monaco's
`IEditor`/`ICodeEditor`: every `pub fn Viewer::*` maps 1:1 to a member of
those interfaces. Host-facing feature capabilities beyond that subset (the
comment store, feature controllers, contribution internals) are reached by
importing the owning feature package — `viewer/contrib/<feature>` or
`viewer/common/<feature>` — the way VS Code's workbench imports
`vs/editor/**`; the `Viewer::` surface never grows to carry them (consumer
classes: `docs/architecture.md`, Viewer Three-Tier Mirror).

It ships without explorer chrome, transport, persistence, file watching, or
reload policy. Hosts provide readonly `viewer/common/model.TextModel` values
and call the viewer API. The reference `internal/shell/workbench` is one host;
it is not part of this package or the public import surface.

## Embedding

- Construct with `Viewer::Viewer(...)` (unattached) or `Viewer::create(host, ...)`;
  `attach(host)` mounts into one stable host element the host never renders
  children into afterwards; `set_model` installs caller-owned readonly model
  state. `dispose()` releases viewer-owned subscriptions and DOM; it never owns
  source lifecycle (files, watches).
- Typed subscriptions report model changes, frame builds, render results,
  diagnostics, hover resolution, scroll, and disposal.
- Hosts register tokenizers and semantic providers with the
  `viewer/common/languages` registry — the process-wide default, or an isolated
  `Languages` value passed through `ViewerServices::new(languages~)`.
  `ViewerServices` owns per-viewer service objects (markers, hover
  participants, logging).

## Responsibilities

- Own `Viewer` lifecycle, options, services, and every `Viewer::` method.
  MoonBit cannot define methods on a foreign type, so the `Viewer`-facing glue
  for input, hit-testing, reveal, view zones, folding controls, hover
  dispatch, and decorations lives here even though the mechanisms live in
  `viewer/browser/*`, `viewer/contrib/*`, and `viewer/common/*`.
- Drive the render pipeline and keep async feature results fresh (current
  model URI + version checks before applying provider answers):

  ```text
  viewer/common/model.TextModel
    -> viewer/common/view_model
    -> viewer/common/view_layout
    -> viewer/browser/view (DOM)
  ```

- Keep viewer-owned styles next to the part that owns the corresponding DOM;
  `scripts/build-web.mbtx` assembles them into the served `/style.css`.
- Keep syntax and semantic features provider-based: the viewer consumes
  registered providers and never imports concrete `syntax/lang_*` packages or
  backend transports.

Current readonly behavior: rendering, syntax highlighting, diagnostics as
markers, hover, folding, inlay hints, selection/copy, scrolling, decorations,
and view zones. Go-to-definition and find-references are not current viewer
behavior.

## Boundaries

- Exact imports live in `moon.pkg`. The stable rules: browser effects come only
  from `rabbita/dom` / `rabbita/js` (never the Rabbita TEA/vdom/command
  layers); no `internal/shell/*` packages, websocket transports, or concrete
  `syntax/lang_*` packages.
- js-only (`supported_targets = "js"`): this package owns DOM. DOM-free logic
  belongs in `viewer/common/**` or `viewer/contrib/<feature>/`.
- Must not pass render-frame JSON to JavaScript for DOM rendering.

## Checks

- `test_viewer_wbtest.mbt` is the headless viewer harness (`with_test_viewer`)
  for behavior expressible as positions, ranges, line strings, or frames — see
  `docs/harness.md`. Feature logic is tested in its owning package; real
  browser behavior in `tests/browser/`.
- Run `just check` for the repository-level guardrail.
