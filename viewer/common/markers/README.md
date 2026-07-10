# viewer/common/markers

Backend-neutral diagnostic storage and marker-to-decoration projection.

## Data flow and API

- `Marker`/`MarkerData` carry Monaco-shaped severity, tags, owner, resource, and
  range metadata. `from_diagnostic`/`to_diagnostic` bridge `language.Diagnostic`.
- `MarkerService` indexes values in both `(resource, owner)` directions. It exposes
  `change_one`/`change_all`, `set_diagnostics`, filtered `read`, removal, resource
  filters, per-severity statistics, and merged change events. Its
  `MicrotaskEmitter` flushes inline unless the caller supplies a scheduler.
- `MarkerDecorationsService::acquire_model` returns an independently idempotent
  lease keyed by `TextModel.instance_id`. The first lease owns one content watch,
  one model-dispose watch, and one `MarkerDecorations`; reacquisition only
  increments a refcount. A content flush resets and re-seeds that existing owner
  without acquiring a lease. Final ordinary release removes both identity
  indexes and decorations but never removes host-owned diagnostics.
- Distinct live models may share a URI. A secondary acquisition-ordered
  `URI -> Array[instance_id]` index fans marker changes to every identity.
  `get_marker(uri, id)` scans that order (model decoration ids carry an identity
  prefix), while `get_live_markers(uri)` returns the ordered union.
  `get_live_markers_for_model(model)` is the model-specific hover boundary.
- A real `model.on_will_dispose` event finalizes the active identity regardless
  of outstanding leases. Only that path may clear markers for `inmemory`,
  `internal`, or `vscode` resources, and only after the URI's final live identity
  is gone. Ordinary lease release and service disposal preserve `MarkerService`.
- `MarkerDecorationsService::dispose` blocks marker and outward-event ingress
  first, then releases every model watch and decoration owner, and clears its
  indexes last. The injected `MarkerService` is borrowed. The paired
  `on_model_added`/`on_model_removed` methods remain compatibility shims; new
  owners retain the disposable returned by `acquire_model`.
- Each live owner converts up to the first 500 markers for its resource into
  model decorations and applies the URI's temporary range suppressions.
- `create_decoration_range`/`create_decoration_option` preserve Monaco's empty,
  full-line, hint, severity, and tag branches. Squiggly/theme helpers produce the
  data URI and CSS presentation inputs; the DOM itself lives in browser/view code.

The upstream split is `vs/platform/markers/common/{markers,markerService}.ts` and
`vs/editor/common/services/markerDecorationsService.ts`, with the squiggle theme
mapping from `codeEditorWidget.ts`.

This package depends on `base/common`, `language`, and `viewer/common/model` only;
it has no DOM/FFI/root-viewer dependency. See `pkg.generated.mbti`; run
`moon test --target js viewer/common/markers`.
