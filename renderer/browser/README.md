# renderer/browser

The embeddable readonly viewer-core library — the `vs/editor` (Monaco)
role. It ships without the explorer sidebar, the protocol client, or any
shell chrome; the `workbench` package composes those in a layer above
(exclusion by composition, not a config flag).

## Embedding API

- `Viewer::Viewer(source, on_notification~, theme?, placeholder?)`
  constructs the viewer against any `&@workspace.DocumentSource`. The
  in-memory backend in `examples/embedded_viewer` plus the remote one in
  `workbench` are the two reference implementations; implementing
  `DocumentSource` is the entire integration surface for a custom backend.
- `Viewer::view()` embeds the viewer as a Rabbita child cell. Keep it
  mounted: Rabbita only steps mounted cells, so the viewer renders a
  host-pushed `placeholder` message while it has no frame instead of being
  swapped out.
- `Viewer::open(uri)` owns the full document-switch choreography: closing
  the previous document and its watch, invalidating the code cell,
  subscribing the new watch, opening through the source, and resetting
  scroll on remount — embedders cannot get the sequencing wrong.
- `Viewer::set_theme`, `set_placeholder`, `remeasure`, and `escape` push
  host state and host-captured events in.
- `Viewer::push_diagnostics`/`push_symbols`/`push_semantic_tokens` accept
  unsolicited feature data (for example server-initiated pushes the host
  routes in).
- `register_hover_provider` (and the diagnostics/symbols/semantic-tokens
  equivalents) add `language` providers to the registry; it starts empty
  and the host registers what it has at startup.
- `register_tokenizer(language_id, tokenizer)` adds a
  `syntax.LineTokenizer` to the tokenization registry (the Monaco
  `TokenizationRegistry` role). Languages are compile-time packages
  (`syntax/lang_*`) the host composes in by import — the workbench and
  `examples/embedded_viewer` register `lang_moonbit` and friends at
  startup; documents whose `language_id` has no registered tokenizer
  render through the generic plain fallback.
- The viewer reports lifecycle facts through `ViewerNotification`
  (diagnostics status, frame built, document rendered/failed, hover
  resolved). The host formats observability events and syncs its chrome
  from these; the viewer itself emits nothing host-visible.

## Responsibilities

- Render backend-neutral `renderer.RenderFrame` values as browser HTML.
- Own the editor input bridge: one container handler set on the code viewer
  converts DOM events into typed `EditorEvent`s through the renderer's
  shared `hit_test`, fed by tracked view metrics (scroll offset, measured
  viewer height, char-probe width, gutter width). Rendered spans carry no
  handlers; overlay widgets swallow events under them.
- Own the feature controllers (`HoverController` today): each consumes
  editor events and answers with commands, span/line decorations, and
  widgets. Hover follows Monaco's timing (request at half the 300ms delay,
  display gated at the full delay, loading hover at 3x).
- Own the embedded code-surface cell: a cached Rabbita child cell with
  Map-keyed line children that renders only the visible line window between
  height-preserving spacers; the viewer pushes frame/surface/window updates
  into it only when they change, so other updates skip line subtrees.

Go-to-definition and find-references were removed for now; the viewer
focuses on hover until those features can be rebuilt without their bugs.

## Boundaries

- May depend on Rabbita public packages (except `websocket`), `dom`,
  `workspace`, `language`, `renderer`, `syntax`, and `decorations`.
- Must not import `remote_protocol`, `websocket`, `workbench`, or
  `widgets/*` — enforced by `scripts/check-architecture.mbtx`. Transports
  live behind the `DocumentSource` trait and the provider registry.
- May declare JavaScript FFI it alone uses, under the host-FFI rule in
  `../../docs/architecture.md`; browser capabilities shared with other
  browser packages belong in `dom`.
- Must not import `syntax/lang_*` packages: languages reach the viewer
  only through `register_tokenizer`, so the library carries no grammar
  weight an embedder did not ask for (enforced by
  `scripts/check-architecture.mbtx`).
- Module-level `Ref` registries (the code-cell cache, the active document
  watch, the provider registry, the tokenizer registry) stay inside this
  package.
- Must not pass render-frame JSON to JavaScript for DOM rendering.
- The backend-neutral `renderer` package must not import Rabbita or browser
  host packages.

## Checks

- Hover staleness guards are covered by `hover_controller_wbtest.mbt`.
- The embedding boundary is proven by `examples/embedded_viewer` and
  `tests/browser/embed.spec.js` (no websocket opened).
- Run `just check` for the repository-level type check.
