# renderer/browser

The embeddable readonly viewer-core library — the `vs/editor` (Monaco)
role. It ships without the explorer sidebar, the protocol client, or any
shell chrome; the `workbench` package composes those in a layer above
(exclusion by composition, not a config flag).

The viewer is an imperative view island: it builds and owns its whole
DOM subtree inside a host-provided stable element, and every public
method is a plain call. Hosts with their own effect system (the Rabbita
workbench) wrap the calls in their command type.

## Embedding API

- `Viewer::Viewer(source, on_notification~, theme?, placeholder?)`
  constructs the viewer against any `&@workspace.DocumentSource`. The
  in-memory backend in `examples/embedded_viewer` plus the remote one in
  `workbench` are the two reference implementations; implementing
  `DocumentSource` is the entire integration surface for a custom backend.
- `Viewer::attach(host)` is the mount seam: the host renders one stable
  element, keeps it mounted, and must never render its own children into
  it — the island's nodes are foreign to any host vdom and must survive
  host re-renders untouched. While the viewer has no frame it shows the
  host-pushed `placeholder` message inside the island.
- `Viewer::open(uri)` owns the full document-switch choreography: closing
  the previous document and its watch, subscribing the new watch, opening
  through the source, and resetting scroll only when the (uri, version)
  identity actually rotated — embedders cannot get the sequencing wrong.
- `Viewer::set_theme`, `set_placeholder`, `remeasure`, and `escape` push
  host state and host-captured events in. Theme changes never remount the
  island (colors cascade through the host's CSS variables) and keep the
  scroll position.
- `Viewer::scroll_to`, `scroll_by_lines`, `scroll_by_pages`,
  `scroll_home`, and `scroll_end` are the synthetic scroll entry points
  for host-routed keyboard scrolling and harness controls; wheel and
  scrollbar input arrive through the island's shared scrollable element.
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
  (diagnostics status, frame built with `tokenize_ms`/`build_ms`,
  document rendered/failed with `patch_ms`, hover resolved, scroll
  settled). The host formats observability events and syncs its chrome
  from these; the viewer itself emits nothing host-visible.

## Responsibilities

- Render `renderer` IR as browser DOM through the imperative island: a
  `.moonbit-viewer.readonly-editor` root, an `.overflow-guard` clip,
  `.monaco-scrollable-element.editor-scrollable` around
  `.lines-content`, `.view-lines`, `.view-overlays`, `.view-zones`,
  margin view overlays for line numbers, content-widget and
  overlay-widget slots, overflowing widget slots, and Monaco-shaped custom
  scrollbars driven by the backend-neutral `ScrollbarState` arithmetic.
- Content widgets are anchored to a text position and share the text
  transform; hover is the first user and mounts in `.contentWidgets` with
  a locally owned outer content-widget wrapper whose internals intentionally
  mirror Monaco's hover widget and `monaco-scrollable-element` scrollbar
  structure. Overlay widgets are viewport-positioned UI for future controls
  and mount in `.overlayWidgets`; overflowing variants mount outside
  `.overflow-guard` when a widget is allowed to escape the editor clip.
- Own the render loop: rAF-coalesced flushes with reads (measurement)
  before writes, a `ViewLayer`-style recycler that splices
  entering/leaving line nodes and writes `innerHTML` only on entering
  lines (a changed content generation rewrites the window), and paint
  facts (`patch_ms`, scroll position) reported after the flush.
- Own scroll input through `ScrollableElementDom`: the editor and hover use
  the same Monaco-shaped wrapper, custom scrollbar nodes, wheel delta-mode
  normalization, thumb drag, track page-jump, and visibility-class updates.
  Editor scroll writes back into `renderer.ViewLayout`; hover scroll writes
  into its native content element. Browser reveal scroll offsets on editor
  DOM nodes are translated into `ViewLayout` deltas and reset.
- Own the editor input bridge: native `mousemove`/`mouseleave` listeners
  on the island root convert DOM events into typed `EditorEvent`s through
  the renderer's shared `hit_test`, fed by layout state plus the measured
  char-probe width and the derived gutter width. Rendered spans carry no
  handlers; content and overlay widgets swallow events under them.
- Own the feature controllers (`HoverController` today): each consumes
  editor events and answers with effects-as-data, span/line decorations,
  and widget views. Hover follows Monaco's timing (request at half the
  300ms delay, display gated at the full delay, loading hover at 3x);
  the delays run on `dom` timer bindings and provider calls run through
  `@js.async_run` with version/token staleness guards.
- Own the per-version render cache: provider pushes rebuild frames from
  the cached `TokenizedDocument` without re-tokenizing, and window
  shifts rebuild the viewport frame from the cached `FrameSource` in
  O(window).

Go-to-definition and find-references were removed for now; the viewer
focuses on hover until those features can be rebuilt without their bugs.

## Boundaries

- May depend on `rabbita/dom` (WebIDL bindings) and `rabbita/js` only —
  the Rabbita TEA core, the vdom (`rabbita/html`), and the command
  scheduler (`rabbita/cmd`) are forbidden and checker-enforced; the
  viewer renders imperatively. May also depend on `dom`, `workspace`,
  `language`, `renderer`, `syntax`, and `decorations`.
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
- Module-level registries (the provider registry, the tokenizer
  registry) stay inside this package; per-viewer state lives on the
  `Viewer` instance.
- Must not pass render-frame JSON to JavaScript for DOM rendering.
- The backend-neutral `renderer` package must not import Rabbita or browser
  host packages.

## Checks

- Hover staleness and scheduling guards are covered by
  `hover_controller_wbtest.mbt`.
- The embedding boundary is proven by `examples/embedded_viewer` and
  `tests/browser/embed.spec.js` (no websocket opened).
- Run `just check` for the repository-level type check.
