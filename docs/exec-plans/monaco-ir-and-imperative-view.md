# Monaco IR Stack and Imperative View for the Browser Viewer

Status: proposed (2026-06-12).

## Goal

Converge the viewer on Monaco's render architecture, copied at design level
from the reference submodule:

1. Monaco's IR stack: a per-version tokenized document (line-bucketed
   tokens, the `TextModel` tokens role), viewport-scoped render frames (the
   `ViewportData` role), and pure line-HTML emission (the
   `viewLineRenderer` role).
2. Scroll and layout as backend-neutral data: `Scrollable`, a
   uniform-height `LinesLayout`, and a `ViewLayout` that derives viewports.
   Scroll state is owned by the model (synthetic scrolling), not by a DOM
   scroll container.
3. An imperative browser view island: a `ViewLayer`-style line recycler,
   a separate margin layer, custom scrollbars, and a rAF render loop with
   read/write phase discipline. The viewer drops Rabbita's TEA core and
   vdom; the workbench shell stays Rabbita and embeds the island behind a
   stable host element.

The editor stays readonly. Protocol packets, server routing, workspace and
language semantics, the sidebar, and the workbench chrome do not change.

## Motivation (measured 2026-06-12)

`tests/browser/perf.spec.js` on the generated 10k-line fixture:
`buildMs ~ 320-348ms` (frame build) vs `patchMs ~ 4-6ms` (DOM patch of the
~57 windowed lines). The DOM layer is already cheap and bounded; the
pipeline is whole-document and quadratic. Separately, the viewer core
escapes the TEA framework in five places (module `Ref` cell cache and
invalidation, in-place `entry.surface`/`entry.window` mutation, document
watch lifecycle, scroll-hook property marker, scroll restore after theme
remounts), and scroll events cannot even be delivered through Rabbita's
typed events. Monaco's split — pure IR feeding an imperative view —
removes both problem classes at once.

## Current State (verified against source)

- `renderer/browser/render.mbt:37` re-tokenizes the whole document on every
  render, including every diagnostics/symbols/semantic-tokens push;
  `render.mbt:50` builds the frame for `0..line_count`.
- `renderer/render_frame.mbt:110`: `spans_for_line` scans the full token
  array per line — O(lines x tokens), ~200M intersection checks on the perf
  fixture. `overlay_semantic_tokens` scans all semantic tokens per span.
  `RenderSpan` copies every token's text via `.to_owned()`.
- Windowing is view-time only: the code cell renders `window.start..end`
  out of the full-document frame with spacer divs and native scroll
  (`code_cell.mbt`), with overscan 20 and hysteresis
  (`renderer/view_window.mbt`).
- `ViewMetrics` (`renderer/browser/input.mbt:24-33`) already carries
  `scroll_top`, `viewport_height`, and an empty `view_zones` slot — the
  hit-test geometry is already shaped for a layout model.
- `tests/browser/scroll.spec.js:28,41` drives scrolling by assigning
  `viewer.scrollTop`; harness events are `moonbit:render` (`buildMs`) and
  `dom:mounted` (`patchMs`, windowed `renderedLines`).
- `rabbita/dom` is a standalone WebIDL binding package (verified in
  `.mooncakes/moonbit-community/rabbita/dom`): `create_element`,
  `set_inner_html`, `insert_before`, `remove_child`, `add_event_listener`,
  `request_animation_frame`, scroll getters/setters,
  `get_bounding_client_rect`. `add_event_listener` takes no options bag
  (spike 2). Dropping the TEA core does not require rebinding the DOM.

## Reference Map (design-only; no imports from `vscode/`)

- `vscode/src/vs/editor/common/tokens/lineTokens.ts` — line-bucketed token
  store (we keep class-name tags instead of packed metadata).
- `vscode/src/vs/editor/common/viewLayout/viewLinesViewportData.ts` —
  `ViewportData`, the viewport-scoped frame.
- `vscode/src/vs/editor/common/viewLayout/viewLineRenderer.ts` —
  `RenderLineInput` -> HTML string, pure and DOM-free.
- `vscode/src/vs/base/common/scrollable.ts` (~520 lines) — scroll state,
  clamping, change events.
- `vscode/src/vs/editor/common/viewLayout/linesLayout.ts` (~910 lines) —
  line layout; we implement the uniform-height subset of its interface.
- `vscode/src/vs/editor/common/viewLayout/viewLayout.ts` — combines the
  two into viewport derivation.
- `vscode/src/vs/editor/browser/view/viewLayer.ts` —
  `RenderedLinesCollection`/`VisibleLinesCollection`, the line recycler.
- `vscode/src/vs/editor/browser/viewParts/viewLines/` — line DOM, batched
  innerHTML writes.
- `vscode/src/vs/editor/browser/view.ts` — layer construction and the
  rAF render loop with `prepareRender` (reads) / `render` (writes) phases.
- `vscode/src/vs/base/browser/ui/scrollbar/` — `ScrollableElement`,
  `ScrollbarState` arithmetic, vertical/horizontal scrollbars.

## Phase 1 — IR: Tokenized Document and Viewport-Scoped Frames

Rabbita stays untouched this phase.

1. Add `TokenizedDocument` to `renderer`: built once per document version,
   tokens bucketed per line (single forward sweep over the sorted token
   array). Semantic tokens and diagnostic decorations get the same
   per-line bucketing when they arrive.
2. Cache it in the viewer keyed by (uri, version); provider pushes rebuild
   frames from the cache instead of re-tokenizing (`render.mbt:37`).
3. `build_frame` consumes line buckets and builds only the requested
   window — O(window), not O(document). The frame becomes the
   `ViewportData` role. Window shifts rebuild the frame from the cache
   instead of slicing a whole-document `lines` array.
4. `RenderSpan` drops its owned `text` field (start/end/class only); the
   view slices `line.text` at emission time.
5. `hit_test` and hover-anchor lookup consume the viewport-scoped frame
   (the mouse is always inside the viewport).
6. Harness: `moonbit:render` gains `tokenizeMs`; `buildMs` becomes the
   window build. Document in `docs/harness.md`.

Validation: unit tests for bucketing, sweep, and window builds; all browser
specs pass; perf evidence on the 10k fixture recorded before/after
(target: `buildMs` from ~340ms to low single-digit ms; pushes no longer
re-tokenize).

## Phase 2 — Backend-Neutral Scroll and Layout Model

Pure MoonBit in `renderer`; not wired to the browser yet (exactly one
scroll-truth owner at all times — the DOM until phase 3 flips it).

1. Port `Scrollable`: dimensions, clamped `scroll_top`/`scroll_left`,
   change facts as data. No smooth-scroll animation yet (cut list).
2. Port the uniform-height subset of `LinesLayout` behind Monaco's
   interface shape: `vertical_offset_for_line`, `line_at_vertical_offset`,
   total height, and view-zone slots that feed
   `ViewMetrics.view_zones` (implementation deferred).
3. Port `ViewLayout`: `Scrollable` + `LinesLayout` -> viewport
   (start/end line, window origin, overscan, hysteresis), absorbing
   `visible_window`/`window_needs_update` semantics.

Validation: `moon test --target all`; parity tests against current
window/hysteresis behavior; clamp and derivation tests.

## Phase 3 — Imperative View Island

1. Mount seam: the workbench renders one stable host element; the viewer
   attaches into it imperatively. `Viewer` keeps `on_notification` and its
   public surface, but methods become plain calls; the workbench wraps
   them in `custom_cmd`. `renderer/browser` drops `rabbita` and
   `rabbita/html` imports, keeping `rabbita/dom` and `rabbita/js`.
   `examples/embedded_viewer` adapts to the same API.
2. DOM layers, keeping every harness class and `data-*` contract:
   `.code-viewer` becomes the `overflow: hidden` island root containing a
   margin layer (gutter column, vertical translate only — fixes gutter
   loss under horizontal scroll), a lines-content layer translated by
   `window_origin - scroll_top`, line nodes absolutely positioned at
   window-relative tops with explicit 18px height (removes the
   empty-line `" "` hack and the browser max-height ceiling), the hover
   widget layer, and scrollbar elements.
3. Port `renderViewLine` into `renderer` as a pure function:
   `RenderLine` + decorations -> escaped HTML string via a string
   builder. Monospace + UTF-16 columns mean `CharacterMapping` is not
   needed; `hit_test` arithmetic stays the column source.
4. Port the `ViewLayer` recycler: track the rendered line range, splice
   entering/leaving line nodes, `set_inner_html` only on entering lines,
   all flushed in a rAF-coalesced render loop with reads before writes.
5. Port `ScrollableElement`: wheel listener (spike 2), simplified delta
   normalization, vertical + horizontal scrollbars (thumb drag, track
   page jumps) driven by `ScrollbarState` arithmetic, `Scrollable` as the
   single scroll truth. The island always consumes wheel events
   (Monaco's default; revisit chaining for embeds later).
6. Input: native `mousemove`/`mouseleave` listeners on the island;
   metrics come from `ViewLayout` instead of DOM scroll reads (char-probe
   measurement stays). PgUp/PgDn/Home/End/arrow scrolling routes through
   the workbench key handling (as Escape does today) into viewer scroll
   methods.
7. Hover: the controller state machine stays; timers move from Rabbita
   commands to `dom` bindings; the widget renders in a content-widget
   layer positioned from layout data.
8. Harness: the workbench installs a scroll control
   (`__readonlyEditorScrollTo(top)`) and a `view:scroll` event;
   `dom:mounted`/`patchMs` is measured around the recycler flush;
   `scroll.spec.js` migrates from `scrollTop` assignment to the control.
   Other specs survive on stable selectors.

Validation: all browser specs including migrated scroll specs; perf
evidence; manual smoke of wheel, scrollbar drag, keyboard scrolling,
hover-after-scroll, theme switch (scroll position must survive — no
remount), and the embed example.

## Phase 4 — Contracts and Docs

1. `docs/architecture.md`: replace the embedded-cell contract with the
   island mount contract (the shell must never render vdom children into
   the host element); reword the scrolling split (semantics
   backend-neutral, input capture and output application browser-side);
   update the dependency graph.
2. `AGENTS.md` browser-backend sentence; `docs/harness.md` observability
   and scroll control; `renderer/README.md` and
   `renderer/browser/README.md` responsibilities.
3. `scripts/check-architecture.mbtx`: forbid `rabbita` core and
   `rabbita/html` imports in `renderer/browser`.

## Cut List (non-goals of this plan)

Editing, cursors, IME/edit-context, selection-as-overlay; minimap; view
zone rendering (layout slots only); variable line heights and the
whitespace heightmap; smooth-scroll animation; GPU rendering; the full
`MouseWheelClassifier`; find; the accessibility textarea. The sidebar
keeps native scrolling.

## Cross-Cutting Decisions

- Copy design, not code: `vscode/` stays reference-only; everything is
  reimplemented in MoonBit under our names. Harness selectors and CSS
  class names stay ours; Monaco role names appear only in README notes.
- Exactly one scroll-truth owner at any commit: the DOM through phase 2,
  `Scrollable` from phase 3. Never both.
- Missing browser capabilities (e.g. `addEventListener` options) are added
  as FFI in the `dom` package, per the FFI placement rule.
- Phase order 1 -> 2 -> 3 -> 4. Phases 1-2 are independently valuable and
  land even if phase 3 is deferred. Every phase lands green on
  `just check`, `just test`, `just test-browser`, with `buildMs`/`patchMs`
  evidence recorded in the PR description.

## Spikes (before Phase 3 lands)

1. Rabbita opaque host: confirm the shell diff leaves foreign children of
   a stable rendered element untouched across shell updates (throwaway
   probe in `web`). This is the island's load-bearing assumption.
2. Wheel listener: confirm `preventDefault` works through
   `@rdom.add_event_listener` for element-level wheel in Chrome, Safari,
   and Firefox; otherwise add an FFI overload with `{ passive: false }`.
3. `set_inner_html` throughput from MoonBit strings for a ~100-line splice
   (JS-backend strings should marshal for free; verify).
4. `ScrollbarState` arithmetic port with unit tests against hand-computed
   cases before any DOM work.

## Exit Criteria

- 10k fixture: document open `tokenizeMs + buildMs` under ~10ms (baseline
  ~340ms); provider pushes rebuild without re-tokenizing; wheel and
  scrollbar scrubbing hold 60fps in a recorded trace; interaction
  re-renders stay under the documented ~2ms budget.
- All browser specs green, scroll specs driven through the harness scroll
  control.
- `renderer/browser` has no `rabbita` core/vdom imports
  (checker-enforced); the workbench shell is unchanged for users; theme
  switching preserves scroll position.
- Hover after scroll, the embed example, and the explorer flows behave as
  today.
- `docs/architecture.md`, `docs/harness.md`, `AGENTS.md`, and package
  READMEs match the implementation.
