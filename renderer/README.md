# renderer

Backend-agnostic render frame construction and editor geometry.

## Responsibilities

- Convert snapshots, syntax tokens, decorations, and provider results into
  `RenderFrame` values.
- Own viewport clamping, line/span construction, diagnostic and hover
  inclusion, semantic-token overlay (spans split at token boundaries with
  `sem-<type>` classes that win over syntax classes), and JSON serialization
  for render frames.
- Own the pure editor geometry shared by backends: mouse hit-testing
  (`MouseTargetKind`/`MouseTarget`/`ViewZone`/`ViewMetrics`/`hit_test`)
  resolved against render frames, and viewport-window math
  (`LineWindow`/`visible_window`/`window_needs_update`) for line
  virtualization with overscan and hysteresis.
- Keep render output independent of concrete frontend hosts.

## Boundaries

- May depend on `core`, `syntax`, `decorations`, and `language`.
- Must not assume DOM nodes, browser APIs, CSS runtime behavior, native effects,
  server routing, or filesystem providers. Hit-test and window functions are
  pure arithmetic over frame data and caller-measured metrics.
- Backend-specific mounting and event wiring belong in `renderer/browser`.

## Checks

- Package tests live in `render_frame_test.mbt`, `mouse_target_test.mbt`,
  and `view_window_test.mbt`.
- Run `just check` for the repository-level type check.
