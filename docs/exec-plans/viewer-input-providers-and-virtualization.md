# Viewer Input Bridge, Provider-Backed Features, and Virtualized Rendering

Status: proposed (2026-06-11).

## Goal

Restructure the browser viewer around four borrowed ideas:

1. VS Code's editor event system: one shared hit test that turns browser
   events into typed editor events, consumed by feature controllers instead
   of per-span DOM handlers.
2. VS Code's provider model: language features resolved through the existing
   `@language` provider traits over the live protocol, with request
   correlation.
3. Rabbita's performance primitives: keyed children and child-cell slot
   skipping, so re-render cost is proportional to what changed.
4. Viewport virtualization driven by tracked scroll state.

The editor stays readonly. No protocol packet shapes change. No URL routing
is introduced.

## Current State (verified against source)

- Every rendered span attaches 4+ closures (`view_span` in
  `renderer/browser/app.mbt`); hover, definition, and references logic is
  inlined in the view. The full document renders as DOM regardless of size
  (`render_document` passes `{start_line: 0, end_line: line_count}`).
- Protocol responses are matched only by frame version, not request id; two
  in-flight requests of the same kind can cross.
- Semantic tokens are fetched and stored but never affect rendered spans.
- Rabbita (verified in `.mooncakes/moonbit-community/rabbita`):
  - diffs vnode trees and patches attributes/text/styles individually;
    listeners attach once with handler-ref swapping
    (`internal/runtime/vdom.mbt`, `diff_props`);
  - `Map[String, Html]` children are keyed and reused across updates;
  - a child `Cell` embeds as a `Slot` vnode; the parent diff skips a slot
    whose cell instance is unchanged (`diff_node`, Slot branch) — a
    memoization boundary;
  - a *new* cell instance remounts its subtree, so cell instances must be
    cached and reused.
- Browser specs depend on `.definition-candidate`, `data-line`,
  `data-workspace-id`, shell `data-*` attributes, and real mouse gestures.
  None depend on per-span `data-start`/`data-end`.

## Phase 1 — Editor Input Bridge

Mirror Monaco's `MouseTargetFactory`, hit-testing against our render data
(the `RenderFrame`) instead of the DOM.

Steps:

1. Add `renderer/mouse_target.mbt` (backend-neutral, pure):
   - `MouseTargetKind`: `GutterLineNumbers`, `ContentText`, `ContentEmpty`,
     `BelowContent`, `Outside`.
   - `MouseTarget`: kind, line number, column, document offset, span index.
   - `ViewZone`: `(anchor_line, height_px)` for inline widgets that displace
     lines (the references peek).
   - `hit_test(frame, metrics, x, y) -> MouseTarget` where `metrics` carries
     content origin, scroll top, line height, char width, gutter width, and
     active view zones. Pure arithmetic; unit-tested without a browser.
2. Track `ViewMetrics` in the browser model: `scroll_top` from an
   `on_scroll` handler on `.code-viewer`; viewer height and char width
   measured once after mount via an `after_render` command (fall back to the
   current `ch`/constant assumptions); line height stays the shared
   constant.
3. Replace per-span handlers with one set of container handlers on
   `.code-viewer`: `mousemove`, `mouseleave`, `click`, `contextmenu`
   (prevent default). Handlers dispatch
   `EditorMouseMoved/Down/ContextMenu(x, y, modifiers)`; update resolves a
   `MouseTarget` and routes a typed editor event.
4. Overlay widgets (hover widget, peek widget) stop propagation of
   `mousemove`/`click` so container hit-testing never misfires beneath them
   (Monaco's "target is widget" branch).
5. Spans lose all handlers, `tabindex`, and hover data attributes; they
   render as text + class only. Keyboard F12/Shift+F12 move to the global
   key subscription and act on the last mouse target (replaces per-span
   focus navigation; closest analog of VS Code commands acting at the
   cursor).
6. Keep `.definition-candidate` and `data-line` so existing specs and
   reveal logic keep working.

Validation: new `hit_test` unit tests (gutter/text/empty/below-content,
scrolled, with view zones); all browser specs pass unchanged.

## Phase 2 — Feature Controllers

The contribution model, Elm-shaped: editor events = messages, contributions
= sub-update functions.

Steps:

1. Define `EditorEvent` and split feature state out of `BrowserAppModel`
   into controller structs in `renderer/browser`:
   - `HoverController`: anchor, token, resolved view, measured placement.
   - `DefinitionController`: goto modifier, active definition,
     pending reveal.
   - `ReferencesController`: peek state, anchor offset.
2. Each controller exposes `update(event_or_msg, self) -> (Cmd, Self)`,
   `decorations(frame) -> Array[@decorations.Decoration]` (producing
   `has-hover`, `goto-definition-link`, `range-highlight`,
   `definition-candidate` classes), and `widgets(frame, metrics)` (floating
   widget for hover, view zone for peek).
3. App update fans every editor event to controllers in a fixed order;
   the view merges controller decorations when building span classes and
   inserts controller widgets generically. `view_span`/`view_line` carry no
   feature knowledge.

Validation: browser specs unchanged; controller updates become unit-testable
(pure state transitions).

## Phase 3 — Provider-Backed Language Features

Use the `@language` traits the server already implements, now on the browser
side over the live socket.

Steps:

1. Add a protocol client in `renderer/browser`: unique request ids
   (prefix + counter), a pending table `id -> resolver`, and
   `request(packet) -> async ServerPacket`. The websocket `Message` branch
   resolves pending ids first and falls through to push events
   (`DocumentChanged`, `WorkspaceListed`, push diagnostics) otherwise. Keep
   the frame-version guard at result handling in addition to id matching.
2. Implement `@language.HoverProvider`, `DefinitionProvider`,
   `ReferencesProvider`, `DiagnosticsProvider`, `DocumentSymbolProvider`,
   and `SemanticTokensProvider` backed by the protocol client. Hold them in
   a small registry struct (ordered list per feature, one entry today;
   extension point for more).
3. Controllers request features through provider commands and stop sending
   raw packets.
4. Render semantic tokens: overlay semantic token classes onto syntax token
   classes in `renderer` span construction (semantic wins on overlap). This
   makes the fetched data visible for the first time.
5. Port Monaco's hover timing into `HoverController`: provider request at
   half the 300ms delay, display gated at the full delay, loading state at
   3x if the provider has not answered.

Validation: language browser specs pass; add a spec asserting semantic
token classes appear; protocol-client correlation gets unit tests
(in-flight crossing, stale version dropped).

## Phase 4 — Rabbita Performance Structure

Make re-render cost proportional to the change.

Steps:

1. Move the code surface into its own `cell_with_emit` child cell embedded
   via `Cell::view()` in the shell view. The cell owns scroll/window state
   and the rendered window; its instance is cached in a module `Ref`
   (precedent: `browser_dispatch`) and recreated only when document
   version or theme changes (remount acceptable at that frequency).
   Decoration/hover-class updates are pushed into the cell through its
   dispatcher `Ref`; shell-only updates (sidebar, status, topbar) no longer
   touch line subtrees at all (slot skip).
2. Render lines as keyed children (`Map[String, Html]` keyed by absolute
   line number) so window shifts reuse line DOM.
3. Instrument: extend the `moonbit:render` payload with build/patch
   durations; add a generated large fixture (~10k lines) and a
   non-failing perf spec that logs timings. Document the budget:
   interaction re-render under ~2ms, scroll at 60fps.

Validation: specs pass; timings logged on small and large fixtures before
and after, recorded in the PR description.

## Phase 5 — Viewport Virtualization and Scroll

Steps:

1. Keep building the full `RenderFrame` once per document version (it is
   the hit-test source and line store); windowing happens at view time.
2. Pure window function: `visible_window(scroll_top, viewport_h,
   line_height, line_count, overscan) -> (start, end)` with ~20 lines of
   overscan and hysteresis (re-render only when the window shifts by more
   than half the overscan), so native scrolling stays untouched between
   window updates.
3. The code cell renders only windowed lines; `.code-lines` keeps total
   height (`line_count * line_height`) with a top spacer (or translateY)
   so the scrollbar and `reveal_line_cmd` (which sets `scrollTop`) work
   unchanged. Gutter stays per-line.
4. The peek view zone renders inside the window and feeds `hit_test`
   metrics; lines below the anchor shift as today.
5. Harness updates: `dom:mounted.renderedLines` becomes the windowed count
   (document in `docs/harness.md`); the shell `data-line-count` attribute
   stays the document total. Add specs: scroll to the bottom of the large
   fixture asserts last line present and first line absent; hover after
   scrolling resolves the correct token.

Validation: all specs incl. new scroll specs; manual smoke of wheel/drag
scrolling, reveal on cross-file definition, peek displacement near window
edges.

## Cross-Cutting Decisions

- `renderer` gains `MouseTarget`/`hit_test`/window math as pure data and
  functions; it stays free of DOM types per the dependency rules.
- Phase order: 1 -> 2 -> 3 -> 4 -> 5. Phase 3 and 4 are independent of each
  other and may swap or interleave. Each phase lands green on
  `just check`, `just test`, `just test-browser`.
- Per-span keyboard focus is removed in favor of last-mouse-target
  commands; noted as an accessibility behavior change in the PR.
- Module-level `Ref` registries (dispatcher, pending requests, cell cache)
  stay inside `renderer/browser`.

## Spikes (before Phase 1 lands)

- Confirm reading `scrollTop` from Rabbita's `on_scroll` event target (or
  fall back to a `query_selector` read in the handler command).
- Confirm `stop_propagation` availability on Rabbita `@dom.MouseEvent`.
- Confirm `cell_with_emit` child-cell dispatch from a module `Ref` behaves
  under the slot-skip path (small throwaway probe in `web`).

## Exit Criteria

- Hover, go-to-definition, and references behave as today (specs prove it),
  driven by editor events and providers.
- Semantic tokens visibly affect highlighting.
- A 10k-line document scrolls smoothly with windowed DOM, and logged
  interaction re-render timings meet the documented budget.
- `docs/architecture.md` (renderer responsibilities, browser backend
  contracts), package READMEs, and `docs/harness.md` updated to match.
