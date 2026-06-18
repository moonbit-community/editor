# viewer/common

Line HTML compatibility helpers and shared editor geometry. This package is the
MoonBit-owned common facade for Monaco's `vscode/src/vs/editor/common/*`
layer.

## Responsibilities

- Depend on the `viewer/view_model` package for the Monaco-shaped common
  spine: `TokenizedDocument`, `FrameSource`, `RenderFrame`, `ViewModel`,
  `ViewModelLinesFromModelAsIs`, and `IdentityCoordinatesConverter`.
- Depend on `viewer/core` for UTF-16 coordinate primitives and
  `viewer/model` for readonly text snapshots used by tests and frame source
  construction.
- Depend on the `viewer/view_layout` package for the pre-DOM viewport layer:
  `ViewportData` exposes 1-based inclusive visible line numbers, line-relative
  vertical offsets, `@view_line_renderer.ViewLineRenderingData`, and normalized
  line decorations derived from document/provider state.
- Own compatibility helpers `render_line_html` and `render_line_class`.
  Pure line-HTML emission belongs to the DOM-free
  `viewer/view_line_renderer` package: `RenderLineInput` becomes escaped line
  HTML plus `CharacterMapping`/`DomPosition` data.
- Depend on the backend-neutral `viewer/view_layout` package for scroll and
  layout model state: `Scrollable` (clamped scroll state answering
  `ScrollChange` facts), the uniform-height `LinesLayout` (with view-zone
  slots; displacement deferred), `ViewLayout` (viewport derivation absorbing
  `visible_window` and `window_needs_update` semantics), and `ScrollbarState`
  (thumb geometry, drags, and track jumps as pure arithmetic).
- Own the pure editor geometry shared by backends: mouse hit-testing
  (`MouseTargetKind`/`MouseTarget`/`ViewMetrics`/`hit_test`) resolved against
  render frames plus `@view_layout.ViewZone` layout data.
- Keep render output independent of concrete frontend hosts.

## Boundaries

- May depend on `decorations`, `viewer/core`, `viewer/model`,
  `viewer/view_line_renderer`, `viewer/view_layout`, and
  `viewer/view_model`.
- Must not assume DOM nodes, browser APIs, CSS runtime behavior, native effects,
  server routing, or filesystem providers. Layout, scrollbar, hit-test, and
  window functions are pure arithmetic over frame data and caller-measured
  metrics; `viewer/view_layout.ViewLayout` owns scroll truth as model state
  while browser backends choose how to expose that model through DOM scrollable
  elements.
- Backend-specific mounting and event wiring belong in `viewer`.

## Checks

- Package tests live in `render_line_ir_test.mbt`, `line_html_test.mbt`,
  `mouse_target_test.mbt`, and `view_model_viewport_test.mbt`.
- View-model package tests live under `viewer/view_model`.
- Layout package tests live under `viewer/view_layout`.
- Run `just check` for the repository-level type check.
