# renderer

Pre-DOM common-layer render IR, readonly `ViewModel`, viewport data, and editor
geometry. This package is the MoonBit-owned parent for Monaco's
`vscode/src/vs/editor/common/*` layer.

## Responsibilities

- Own the Monaco-shaped common spine: `TokenizedDocument` (the `TextModel`
  tokens role: the snapshot plus syntax tokens bucketed per line, built
  once per document version), `FrameSource` (per-line bucketed semantic
  tokens and decorations, rebuilt per provider push), `ViewModel` (the readonly
  no-wrap common-layer facade), `ViewModelLinesFromModelAsIs` (one view line per
  model line), and `IdentityCoordinatesConverter` (model/view coordinates are
  identical until wrapping, folding, and injected text land).
- Own the pre-DOM viewport layer, matching Monaco's `ViewportData` role:
  `ViewportData` exposes 1-based inclusive visible line numbers,
  line-relative vertical offsets, `@view_line_renderer.ViewLineRenderingData`,
  and normalized line decorations derived from document/provider state.
- Own compatibility helpers `render_line_html` and `render_line_class`.
  Pure line-HTML emission belongs to the DOM-free
  `renderer/view_line_renderer` package: `RenderLineInput` becomes escaped line
  HTML plus `CharacterMapping`/`DomPosition` data.
- Depend on the backend-neutral `renderer/view_layout` package for scroll and
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

- May depend on `core`, `syntax`, `decorations`, `language`,
  `renderer/view_line_renderer`, `renderer/view_layout`, and JSON support.
- Must not assume DOM nodes, browser APIs, CSS runtime behavior, native effects,
  server routing, or filesystem providers. Layout, scrollbar, hit-test, and
  window functions are pure arithmetic over frame data and caller-measured
  metrics; `renderer/view_layout.ViewLayout` owns scroll truth as model state
  while browser backends choose how to expose that model through DOM scrollable
  elements.
- Backend-specific mounting and event wiring belong in `renderer/browser`.

## Checks

- Package tests live in `tokenized_document_test.mbt`,
  `render_frame_test.mbt`, `render_line_ir_test.mbt`, `view_model_test.mbt`,
  `line_html_test.mbt`, and `mouse_target_test.mbt`.
- Layout package tests live under `renderer/view_layout`.
- Run `just check` for the repository-level type check.
