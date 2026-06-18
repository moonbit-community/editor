# viewer

The embeddable readonly viewer-core library — the `vs/editor` (Monaco)
role. It ships without the explorer sidebar, the protocol client, or any
shell chrome; the `workbench` package composes those in a layer above
(exclusion by composition, not a config flag).

The viewer exposes a public `Viewer` facade and delegates browser DOM rendering
to an imperative Monaco-shaped `View`: it builds and owns its whole DOM subtree
inside a host-provided stable element, and every public method is a plain call.
Hosts own document source, selection, read, watch, reload, and error policy;
they pass readonly `viewer/model.TextModel` values into the viewer when they
want a document rendered. Hosts with their own effect system (the Rabbita
workbench) wrap viewer calls in their command type.

Implementation note: the current checked-in public signatures still expose
`workspace.DocumentSnapshot` in `set_document`, events, and provider paths.
That is a temporary mismatch with the Monaco-shaped model boundary, tracked by
`../docs/exec-plans/monaco-model-viewer-api.md`.

## Embedding API

- `Viewer::Viewer(services?, options?, theme?, placeholder?)` constructs an
  unattached viewer. `services` defaults to `ViewerServices::new()`; hosts that
  install language providers, log sinks, or test fixtures pass an explicit
  service object. `options` defaults to `ViewerOptions::default()` with soft
  wrap off; when enabled, the browser derives the wrap column from measured
  viewport and glyph width while `viewer/view_model` owns the projected line
  data.
- `Viewer::attach(host)` is the mount seam: the host renders one stable
  element, keeps it mounted, and must never render its own children into
  it — the `View` nodes are foreign to any host vdom and must survive
  host re-renders untouched. While the viewer has no frame it shows the
  host-pushed `placeholder` message inside the view.
- `Viewer::create(host, ...)` constructs and attaches in one call.
- `Viewer::set_model(model, view_state?)` is the intended Monaco-shaped document
  seam: it renders caller-owned readonly editor model state. The host may build
  that model from memory, a remote protocol, a `workspace.DocumentProvider`, or
  another application source. The viewer keeps URI/version guards so async
  feature results cannot apply to a stale model.
- `Viewer::clear_model(view_state?)` clears the rendered frame. The host
  decides whether a missing, deleted, or failed source should clear the viewer,
  preserve a previous frame, or show a shell-level error.
- `Viewer::get_model()`, `save_view_state()`, and `restore_view_state()` expose
  model identity and scroll state. `ViewStatePolicy` controls whether a new
  model resets, preserves, or restores viewport state.
- `Viewer::dispose()` disposes viewer-owned event emitters. It does not close
  files, cancel provider watches, or own source lifecycle.
- `on_did_change_model`, `on_did_build_frame`, `on_did_render_model`,
  `on_did_change_diagnostics`, `on_did_resolve_hover`, `on_did_scroll`, and
  `on_did_dispose` are the intended typed event subscriptions. Each returns a
  `Disposable` for just that listener.
- `Viewer::set_theme`, `set_placeholder`, `remeasure`, and `escape` push
  host state and host-captured events in. Theme changes never remount the
  view (colors cascade through the host's CSS variables) and keep the
  scroll position.
- `Viewer::scroll_to`, `scroll_by_lines`, `scroll_by_pages`,
  `scroll_home`, and `scroll_end` are the synthetic scroll entry points
  for host-routed keyboard scrolling and harness controls; wheel and
  scrollbar input arrive through the view's shared scrollable element.
- `languages` is the default public language registry. Hosts call
  `@viewer.languages.set_tokens_provider(language_id, tokenizer)` for syntax
  highlighting and `@viewer.languages.register_*_provider(selector, provider)`
  for hover, diagnostics, document symbols, semantic tokens, folding ranges, and
  inlay hints. Token providers are one-per-language with replacement-safe
  disposal; semantic providers are ordered multi-provider registries.
- `ViewerServices` selects the `Languages` registry a viewer uses and owns
  `MarkerService`, `MarkerDecorationsService`, `HoverParticipantRegistry`, and
  `LogService`. Hosts that need isolation create `Languages::new()`, register
  providers on it, and pass it as `ViewerServices::new(languages~)`. Hover
  composition runs through marker, inlay-hint, and markdown hover participants.
  If folding providers return no ranges for a MoonBit document, the browser uses
  a conservative indentation/brace fallback.
- The viewer reports lifecycle facts through typed subscriptions
  (diagnostics status, frame built with `tokenize_ms`/`build_ms`,
  model rendered/failed with `patch_ms`, hover resolved, scroll settled,
  disposal). The host formats observability events and syncs its chrome from
  these; the viewer itself emits nothing host-visible.

## Responsibilities

- Render common viewer IR as browser DOM through the imperative `View`: a
  `.monaco-editor.readonly-editor` root, an `.overflow-guard` clip,
  `.monaco-scrollable-element.editor-scrollable` around
  `.lines-content`, `.view-lines`, `.view-overlays`, `.view-zones`,
  margin view overlays for line numbers, content-widget and
  overlay-widget slots, overflowing widget slots, and Monaco-conformant custom
  scrollbars driven by the backend-neutral `ScrollbarState` arithmetic. The
  outer viewer contract stays MoonBit-owned; the inner hover/scrollbar
  structure follows the pinned Monaco reference measured by
  `tests/browser/conformance/monaco_hover_scrollbar.spec.js`.
- Content widgets are anchored to a text position and share the text
  transform; hover is the first user and mounts in `.contentWidgets` with
  a locally owned outer content-widget wrapper whose internals are checked
  against Monaco's hover widget and `monaco-scrollable-element` scrollbar
  structure. Overlay widgets are viewport-positioned UI for future controls
  and mount in `.overlayWidgets`; overflowing variants mount outside
  `.overflow-guard` when a widget is allowed to escape the editor clip.
- Own the browser-layer role files that correspond to Monaco
  `editor/browser`: `view.mbt` owns root DOM creation, scheduling, and
  coordinated rendering; `view_part.mbt` owns stateful private part handles;
  `rendering_context.mbt` owns the shared read/prepare data and the restricted
  write context; `view_layer.mbt` owns text-line node recycling;
  `view_line.mbt` owns per-line DOM writes; `content_widgets.mbt` owns
  text-anchored widgets and hover; `overlay_widgets.mbt`, `view_overlays.mbt`,
  `view_zones.mbt`, `margin.mbt`, and `editor_scrollbar.mbt` own their stable
  role slots and private DOM state.
- Own the render loop: rAF-coalesced flushes with reads (measurement) before
  writes. `Viewer::flush_render` builds `ViewRenderInput`; `View::render`
  derives `RenderingContext`, asks stateful `ViewPartHandle`s if they should
  render from a render-change summary, prepares/renders `ViewLines` first, then
  lets zones, overlays, margin, widgets, and scrollbars prepare/write through
  `RestrictedRenderingContext`. The
  `ViewLayer` recycler consumes `viewer/view_layout.ViewportData` from
  `viewer/view_model.ViewModel`, derives
  `@view_line_renderer.RenderLineInput` for each visible line, splices
  entering/leaving line nodes, and writes `innerHTML` only when a line enters
  the viewport or its render input changed. Raw `RenderFrame` lines may still
  supply line-node classes during the compatibility period, but line HTML flows
  through `viewer/view_line_renderer`; line-number DOM is owned by the margin
  overlay part. Paint facts
  (`patch_ms`, scroll position) are reported after the flush.
- Own browser measurement for option-controlled soft wrap: the view measures
  content width and the monospace char probe, converts that to
  `ViewModelOptions`, and rebuilds the common `ViewModel` when the derived wrap
  column changes. The default no-wrap path keeps the previous horizontal scroll
  behavior.
- Own readonly folding controls: browser services collect folding ranges,
  `folding.mbt` tracks folded state for the current document, the common
  `ViewModel` hides folded model lines, and the margin folding overlay renders
  fold/unfold markers aligned with line numbers.
- Own readonly inlay hint collection and hint hover: browser services collect
  `InlayHint` provider results per document revision, the common `ViewModel`
  projects them as injected text, and the hover participant pipeline serves
  hint tooltip content without asking source hover providers for injected spans.
- Own readonly selection and copy: `selection.mbt` stores model-range selection
  state on the viewer, mouse drag updates it through shared hit testing,
  `.view-overlays` renders selection rectangles over visible source spans, and
  the copy bridge writes plain model text plus token-class rich HTML when the
  browser exposes clipboard data. Hover widgets delegate non-interactive
  mousedown back to the editor so an overlapping hover does not block source
  selection.
- Own readonly view zones: `view_zones.mbt` exposes `change_view_zones` with a
  minimal `ViewZoneChangeAccessor` for add/update/remove by id, anchor line,
  height, and DOM node. The common `ViewLayout` computes displacement;
  `.view-zones` mounts the DOM nodes, while line nodes, line numbers, folding
  markers, hover widgets, selection overlays, scrollbars, and hit testing use
  the same zone-aware offsets.
- Own scroll input through `ScrollableElementDom`: the editor and hover use
  the same Monaco wrapper, custom scrollbar nodes, wheel delta-mode
  normalization, thumb drag, centered track jump (`scrollByPage: false`), active
  slider class cleanup, scroll shadows, and visibility-class updates.
  Editor scroll writes back into `viewer/view_layout.ViewLayout`; hover
  scroll writes into its native content element. Browser reveal scroll offsets
  on editor DOM nodes are translated into `ViewLayout` deltas and reset.
- Own the editor input bridge: native `mousemove`/`mouseleave` listeners
  on the view root convert DOM events into typed `EditorEvent`s through
  the viewer common layer's shared `hit_test`, fed by layout state plus the measured
  char-probe width and the derived gutter width. Rendered spans carry no
  handlers; content and overlay widgets stay centralized so selection, hover,
  and widget input can arbitrate events in one layer.
- Own the feature controllers (`HoverController` today): each consumes
  editor events and answers with effects-as-data, span/line decorations,
  and widget views. Hover follows Monaco's timing (request at half the
  300ms delay, display gated at the full delay, loading hover at 3x);
  the delays run on package-local browser-host timer bindings and provider
  calls run through `ContentHoverComputer` with revision/token staleness guards.
  Marker hover is contributed synchronously from marker decorations; language
  hover is contributed asynchronously from markdown hover providers.
- Own the per-version render cache: caller-provided model replacements
  rebuild frames from the cached `TokenizedDocument` without re-tokenizing when
  URI and model version match, and window shifts rebuild the viewport frame from
  the cached `FrameSource` in O(window).
- Own the current editor-model identity: caller-owned `viewer/model.TextModel`
  values are the viewer and language-provider document boundary, and async
  feature results are accepted only when URI plus version still match the
  current model.

Go-to-definition and find-references were removed for now; the viewer
focuses on hover until those features can be rebuilt without their bugs.

## Boundaries

- May depend on `rabbita/dom` (WebIDL bindings) and `rabbita/js` only —
  the Rabbita TEA core, the vdom (`rabbita/html`), and the command
  scheduler (`rabbita/cmd`) are forbidden and checker-enforced; the
  viewer renders imperatively. May also depend on `base/common`, `language`,
  `platform/log`, `viewer/common`, `viewer/core`, `viewer/model`,
  `viewer/view_line_renderer`, `viewer/view_layout`, `viewer/view_model`,
  `syntax`, and `decorations`. It should not depend on `workspace`; any current
  dependency exists only to support the temporary `DocumentSnapshot` API gap.
- Must not import `remote_protocol`, `websocket`, `workbench`, or
  `widgets/*` — enforced by `scripts/check-architecture.mbtx`. Transports,
  reads, watches, reload policy, and file lifecycle stay in host packages.
- May declare narrowly scoped JavaScript FFI it owns, under the host-FFI rule in
  `../../docs/architecture.md`; browser-host timer helpers live package-local
  in `browser_host.mbt`.
- Must not import `syntax/lang_*` packages: tokenizers reach the viewer only
  through `Languages::set_tokens_provider`, so the library carries no grammar
  weight an embedder did not ask for (enforced by
  `scripts/check-architecture.mbtx`).
- The default `languages` registry is module-level for simple embedders, while
  `ViewerServices::new(languages~)` lets tests and embedded viewers select an
  isolated registry. Markers, hover participants, and log sinks remain
  per-viewer services.
- Must not pass render-frame JSON to JavaScript for DOM rendering.
- The backend-neutral `viewer/common` package must not import Rabbita or browser
  host packages.

## Checks

- Hover staleness and scheduling guards are covered by
  `hover_controller_wbtest.mbt`.
- Viewer service, marker, and hover participant orchestration is covered by
  `services_wbtest.mbt`.
- Browser component coverage verifies drag selection, copy shortcut
  observability, token-class rich HTML, wrapped-line selection, hover overlap,
  folding interaction, readonly view-zone rendering/alignment, selection across
  a zone, hover after zones, and inlay-hint exclusion from copied source.
- The embedding boundary is proven by `examples/embedded_viewer` and
  `tests/browser/smoke/embed.spec.js` (no websocket opened).
- Run `just check` for the repository-level type check.
