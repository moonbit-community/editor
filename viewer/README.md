# viewer

The reusable readonly editor facade. It plays Monaco's
`CodeEditorWidget`/`ICodeEditor` role over the packages below it; the reference
workbench, transport, files, and reload policy live under `internal/shell/`.
`pkg.generated.mbti` is the authoritative public API. This README records the
ownership and lifecycle rules that are not obvious from signatures.

## Construction and ownership

- Browser embedders call `Viewer::create(host, services~, options~)`. The host
  element must stay mounted and must not receive host-rendered children.
  This is the only public construction path. The package keeps a private
  headless constructor for white-box tests; there is no public two-step mounting
  API. `get_container_dom_node` returns the original non-null host before and
  after disposal, while `get_dom_node` is nullable when no model/view exists.
- Omitting `services` makes the Viewer create and own an internal bundle.
  Passing `services` explicitly always borrows that bundle, including a bundle
  returned by `ViewerServices::new`; this is the form for sharing languages,
  diagnostics, feedback, and quick-diff state between Viewers.
- `set_model(TextModel?)` installs a caller-owned readonly model. The same
  object is a no-op; replacing or clearing it disposes the old model-scoped
  listeners, detaches the exact model-owned attached-view handle, and then
  disposes the DOM `View` and `ViewModel`. Attachment acquires the handle before
  ViewModel construction and, in a browser host, offers the shared idle/timer
  scheduler to the model. It then creates a new `ViewModel` and, when mounted,
  a new `View`. Model swaps reset scroll and feature model state; use
  `save_view_state`/`restore_view_state` when the host wants persistence.
- Contributions are created once per `Viewer` and disposed with it.
  `Viewer.contributions` is their only instance map: each private central entry
  owns one concrete hover, folding, feedback-input, feedback-widget, or
  quick-diff state value plus its root listeners. Feature packages keep no
  editor-id-keyed instance table. Construction rejects duplicate ids before
  side effects, inserts the bare typed entry before synchronous initialization,
  and then installs listeners. Their Monaco instantiation modes are recorded,
  but all modes currently instantiate eagerly. During disposal the complete
  map stays installed for ordered callbacks. Entries tear down input, widgets,
  folding, hover, then quick diff directly from their stored payloads; each
  retires typed lookup exactly once, and only then is the map cleared. The
  registry, contribution variants, instantiation modes, and lookup helpers are
  package-private. `dispose` is idempotent: it cancels pending render work, removes
  Viewer/View listeners and owned DOM, and never disposes the caller's model,
  host, or explicitly supplied services. For an internally created bundle it
  disposes marker decorations, markers, then agent feedback after Viewer
  teardown. `on_did_dispose` fires after model detach and owner-decoration
  cleanup, but before contribution and Viewer-lifetime disposal, matching the
  source base-store boundary, while every central entry is still reachable.
- Each attached model stores one marker-decoration acquisition lease and one
  exact attached-view handle in its `ModelData`. Multiple Viewers sharing a
  service and model share the identity owner until the final lease and maintain
  an aggregate attached count; `set_value` refreshes that owner without
  acquiring again. Model-scoped listeners dispose before model detachment, the
  View disposes next, and the ViewModel disposes last.
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

Canonical public event values and editor-option enums are owned by
`viewer/common/editor_api`; the root facade consumes those types directly and
does not provide compatibility aliases.

`update_options` accepts and replaces one complete typed `ViewerOptions`
snapshot. It is intentionally not Monaco's JavaScript partial-object merge:
the representation is opaque, and callers changing one field derive a new
snapshot with a reviewed builder such as
`viewer.get_options().with_render_whitespace(All)`. The public read floor is
limited to `soft_wrap()` and `line_height()`; internal packages derive the rest.
An equal complete snapshot is a strict no-op. A changed snapshot computes
option-specific facts once and delivers the resulting mapping, decoration, and
configuration view events as one ordered batch before scheduling the frame.
The readonly product keeps its approved
`render_validation_decorations=On` default; `Editable` still filters validation
decorations because readonly is a fixed product fact.

The viewer is single-cursor: secondary cursor/selection arrays are empty and
`set_selections` uses the first selection. The primary Left/Right/Up/Down,
PageUp/PageDown, Home, and End bindings (with Shift variants) move the cursor;
a winning binding remains handled at a document boundary. Pointer click/drag,
word, line, gutter, and select-all gestures use source-shaped command objects
registered under their source IDs and the same transition path. Their
runtime-partial argument shapes return before mutation when required
position/selection data is absent; the readonly model has no undo stack, so
Monaco's cursor-command `pushStackElement` calls have no local state to update.
Alternate platform bindings, editable commands, multi-cursor, and column
selection are outside the readonly surface. Build/render/hover telemetry is not
part of the public Viewer API; the internal workbench and browser scenarios use
the Viewer-id-keyed `viewer/browser/testing` seam.

Cursor payload versions are `TextModel.get_version_id()`, never the caller's
host metadata version. `set_position`/`set_selection` accept an optional
source, while `set_selections` accepts optional source and reason; their
defaults are `api`/`NotSet`. Keyboard and ordinary pointer gestures emit
`keyboard` or `mouse` with `Explicit`;
four-click SelectAll deliberately keeps source `keyboard`. `set_value` resets
the cursor to `(1,1)` and emits source `model`/reason `ContentFlush`, old version
`0`, and `old_selections=None`, even when the visible cursor was already at the
origin. State is committed and rendering is scheduled before public cursor
callbacks. Delivery is FIFO and reentrancy-safe: ordinary transitions fire
position then selection as an adjacent pair, while flush delivery is model
content, position, then selection.

Cursor-command reveals keep the committed view coordinate. Keyboard commands
request non-minimal Smooth reveal; pointer MoveTo/Word/Line commands use the
same Smooth request with `minimalReveal=true` after their `None` gate, so a
target already at the viewport edge gains no extra vertical or horizontal
padding. Smooth requests of at most one line downgrade to immediate, and the
`smooth_scrolling=false` default also commits them immediately.

`ViewerServices` is an opaque capability aggregate. Its constructor accepts a
`LanguageHandle`, one closed marker source (`MarkerStore` or `Decorations`), an
`AgentFeedbackHandle`, a `QuickDiffHandle`, and a `LogHandle`; concrete service
fields cannot be recovered through the facade. Hosts retain concrete language,
marker, feedback, quick-diff, and logging backings when they need to register
providers, publish diagnostics, mutate feature state, or inspect telemetry.
Omitted capabilities create bundle-owned defaults. `ViewerServices::dispose`
is idempotent and releases only those defaults, in marker-decoration,
marker-store, then feedback order; supplied handles and captured backings remain
caller-owned. A Viewer disposes only a bundle it created implicitly. There is
no current viewer UI for definition or references.

## Runtime pipeline

```text
TextModel (caller-owned)
  -> TokenizationTextModelPart
  -> ViewModel + ViewLayout + cursor outgoing dispatcher (per model)
  -> typed ViewEvent FIFO -> View + ViewParts (per model, browser only)
  -> requestAnimationFrame read/measure then DOM write
```

The root package owns every `Viewer::` method and the cross-package glue for
input, reveal, widgets, folding, hover, quick diff, feedback, and
decorations. Feature mechanisms remain in their `viewer/common/**`,
`viewer/browser/**`, or `viewer/contrib/**` owner packages. Each hover request
captures the physical `TextModel`, its internal content version, a
Viewer-lifetime monotonic generation, and a caller-owned cancellation token.
Replacement, content invalidation, detach, model disposal, and Viewer disposal
cancel before retiring the request; only a stamp that is still fully current
may mutate decorations, hover state, rendering, or resolution events. Hover
mouse/async/sync/loading delays are clearable owned handles with a generation
guard retained for dispatch races.

Grammar tokenization is demand-driven. Initial attach/build telemetry and token
change telemetry read the passive store only. ViewModel scroll/content changes
publish unstable visible ranges, while initial setup and
`restore_view_state(Some(...))` publish one stabilized range after the restored
scroll is committed. The browser scheduler selects one native-idle or 15 ms
timeout fallback implementation, exposes cancellable idle/zero/delay handles,
and lets the model backend bound and cancel background work. The root consumes
the ViewModel's typed outgoing token event only after the browser ViewEvent has
been delivered; it does not subscribe directly to TextModel token events.

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
