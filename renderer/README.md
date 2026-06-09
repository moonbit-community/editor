# renderer

Backend-agnostic render frame construction.

## Responsibilities

- Convert snapshots, syntax tokens, decorations, and provider results into
  `RenderFrame` values.
- Own viewport clamping, line/span construction, diagnostic and hover inclusion,
  and JSON serialization for render frames.
- Keep render output independent of concrete frontend hosts.

## Boundaries

- May depend on `core`, `syntax`, `decorations`, and `language`.
- Must not assume DOM nodes, browser APIs, CSS runtime behavior, native effects,
  server routing, or filesystem providers.
- Backend-specific mounting and event wiring belong in `renderer/browser`.

## Checks

- Package tests live in `render_frame_test.mbt`.
- Run `just check` for the repository-level type check.
