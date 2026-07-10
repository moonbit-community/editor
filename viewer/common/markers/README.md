# viewer/common/markers

Backend-neutral diagnostic storage and marker-to-decoration projection.

## Data flow and API

- `Marker`/`MarkerData` carry Monaco-shaped severity, tags, owner, resource, and
  range metadata. `from_diagnostic`/`to_diagnostic` bridge `language.Diagnostic`.
- `MarkerService` indexes values in both `(resource, owner)` directions. It exposes
  `change_one`/`change_all`, `set_diagnostics`, filtered `read`, removal, resource
  filters, per-severity statistics, and merged change events. Its
  `MicrotaskEmitter` flushes inline unless the caller supplies a scheduler.
- `MarkerDecorationsService` registers live `TextModel`s, converts up to the first
  500 markers per resource into model decorations, supports temporary range
  suppression, and exposes `get_marker` plus `get_live_markers` for hover. It must
  receive matching `on_model_added`/`on_model_removed` calls from the viewer.
- `create_decoration_range`/`create_decoration_option` preserve Monaco's empty,
  full-line, hint, severity, and tag branches. Squiggly/theme helpers produce the
  data URI and CSS presentation inputs; the DOM itself lives in browser/view code.

The upstream split is `vs/platform/markers/common/{markers,markerService}.ts` and
`vs/editor/common/services/markerDecorationsService.ts`, with the squiggle theme
mapping from `codeEditorWidget.ts`.

This package depends on `base/common`, `language`, and `viewer/common/model` only;
it has no DOM/FFI/root-viewer dependency. See `pkg.generated.mbti`; run
`moon test --target js viewer/common/markers`.
