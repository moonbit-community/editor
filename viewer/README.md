# viewer

The reusable readonly editor facade. It plays Monaco's
`CodeEditorWidget`/`ICodeEditor` role over the packages below it; the reference
workbench, transport, files, and reload policy live under `internal/shell/`.
`pkg.generated.mbti` is the authoritative public API. This README records the
ownership and lifecycle rules that are not obvious from signatures.

## Construction and ownership

- Browser embedders call `Viewer::create(host, services~, options~)`. The host
  element must stay mounted and must not receive host-rendered children.
  `Viewer::Viewer(...)` creates an unattached/headless instance; `attach` is a
  private implementation seam, not a public two-step mounting API.
- Omitting `services` makes the Viewer create and own an internal bundle.
  Passing `services` explicitly always borrows that bundle, including a bundle
  returned by `ViewerServices::new`; this is the form for sharing languages,
  diagnostics, feedback, and quick-diff state between Viewers.
- `set_model(TextModel?)` installs a caller-owned readonly model. The same
  object is a no-op; replacing or clearing it disposes the old model-scoped
  listeners and DOM `View`, then creates a new `ViewModel` and, when mounted,
  a new `View`. Model swaps reset scroll and feature model state; use
  `save_view_state`/`restore_view_state` when the host wants persistence.
- Contributions are created once per `Viewer` and disposed with it. Their
  Monaco instantiation modes are recorded, but all modes currently instantiate
  eagerly. `dispose` is idempotent: it cancels pending render work, removes
  Viewer/View listeners and owned DOM, and never disposes the caller's model,
  host, or explicitly supplied services. For an internally created bundle it
  disposes marker decorations, markers, then agent feedback after Viewer
  teardown. `on_did_dispose` fires after model detach and owner-decoration
  cleanup, but before contribution and Viewer-lifetime disposal, matching the
  source base-store boundary.
- Each attached model stores one marker-decoration acquisition lease in its
  `ModelData`. Multiple Viewers sharing a service and model share the identity
  owner until the final lease; `set_value` refreshes that owner without
  acquiring again. Model-scoped listeners dispose before the View, and the View
  disposes before the ViewModel.
- Overlay-widget registrations belong to the Viewer and are re-added to each
  per-model View. Content widgets are an internal view-part seam; hover owns
  the current implementation.

## Public surface

The API is a readonly subset of Monaco's editor API:

- lifecycle/model/options: `create`, `set_model`, `update_options`, `layout`,
  `focus`, `dispose`;
- position, selection, scroll, reveal, geometry, and read queries;
- model decorations and `EditorDecorationsCollection`;
- view zones and null-position overlay widgets;
- model, cursor, scroll, mouse, and disposal events.

The viewer is single-cursor: secondary cursor/selection arrays are empty and
`set_selections` uses the first selection. The `debug_on_did_*` subscriptions
are harness observability, not ordinary editor events.

`ViewerServices` explicitly supplies the language registry, marker and marker-
decoration services, agent-feedback store, quick-diff store, and logger. Hosts
register tokenizers, hover, document-symbol, and inlay-hint providers through
`viewer/common/languages`; diagnostics are pushed to `services.markers`.
There is no current viewer UI for definition or references.

## Runtime pipeline

```text
TextModel (caller-owned)
  -> TokenizationTextModelPart
  -> ViewModel + ViewLayout (per model)
  -> View + ViewParts (per model, browser only)
  -> requestAnimationFrame read/measure then DOM write
```

The root package owns every `Viewer::` method and the cross-package glue for
input, reveal, widgets, folding, hover, inlay hints, quick diff, feedback, and
decorations. Feature mechanisms remain in their `viewer/common/**`,
`viewer/browser/**`, or `viewer/contrib/**` owner packages. Async results are
guarded against the current model/revision before application.

## Boundaries and checks

- JS-only: DOM access is through `rabbita/dom`/`rabbita/js`; no Rabbita
  TEA/vdom/command layer, `internal/shell/**`, backend transport, or concrete
  `syntax/lang_*` import belongs here.
- DOM-free logic belongs in `viewer/common/**` or a multi-target contribution.
  The browser renders typed state directly; do not pass render-frame JSON to
  JavaScript.
- Owner-adjacent CSS is assembled by `scripts/build-web.mbtx`.
- Use `just test` for headless/model behavior, `just test-browser` for real DOM
  input and geometry, and `just check` for architecture boundaries.
