# renderer

Backend-agnostic render IR, scroll/layout model, and editor geometry.

## Responsibilities

- Own the Monaco-shaped render IR: `TokenizedDocument` (the `TextModel`
  tokens role: the snapshot plus syntax tokens bucketed per line, built
  once per document version), `FrameSource` (per-line bucketed semantic
  tokens and decorations, rebuilt per provider push), and `build_frame`
  (the `ViewportData` role: viewport-scoped frames built in O(window)
  from the buckets). `RenderSpan` carries columns and classes only;
  views slice the owning line's text (`RenderLine::span_text`).
- Own pure line-HTML emission (`render_line_html`/`render_line_class`,
  the `viewLineRenderer` role): a `RenderLine` plus controller
  decorations become the escaped inner HTML of one line node, DOM-free.
- Own the backend-neutral scroll and layout model: `Scrollable` (clamped
  scroll state answering `ScrollChange` facts), the uniform-height
  `LinesLayout` (with view-zone slots; displacement deferred),
  `ViewLayout` (viewport derivation absorbing `visible_window` and
  `window_needs_update` semantics), and `ScrollbarState` (thumb
  geometry, drags, and track jumps as pure arithmetic).
- Own the pure editor geometry shared by backends: mouse hit-testing
  (`MouseTargetKind`/`MouseTarget`/`ViewZone`/`ViewMetrics`/`hit_test`)
  resolved against render frames, and viewport-window math
  (`LineWindow`/`visible_window`/`window_needs_update`) for line
  virtualization with overscan and hysteresis.
- Keep render output independent of concrete frontend hosts.

## Boundaries

- May depend on `core`, `syntax`, `decorations`, `language`, and JSON support.
- Must not assume DOM nodes, browser APIs, CSS runtime behavior, native effects,
  server routing, or filesystem providers. Layout, scrollbar, hit-test, and
  window functions are pure arithmetic over frame data and caller-measured
  metrics; `ViewLayout` owns scroll truth as model state, never a DOM
  scroll container.
- Backend-specific mounting and event wiring belong in `renderer/browser`.

## Checks

- Package tests live in `tokenized_document_test.mbt`,
  `render_frame_test.mbt`, `line_html_test.mbt`, `mouse_target_test.mbt`,
  `view_window_test.mbt`, `view_layout_test.mbt`, and
  `scrollbar_state_test.mbt`.
- Run `just check` for the repository-level type check.
