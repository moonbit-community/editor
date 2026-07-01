# viewer/markers

Backend-neutral marker model for the readonly viewing path. A port of Monaco's
marker stack (`platform/markers` + `editor/contrib/gotoError`/`message` marker
rendering), reduced to what a readonly viewer needs: diagnostics stored as
markers, mapped to render decorations and to the marker-hover lookup.

## Responsibilities

- `Marker`: a diagnostic stored by owner and resource, ready for
  marker-specific metadata. `from_diagnostic` / `to_diagnostic` bridge the
  shared `language.Diagnostic` shape.
- `MarkerService`: an in-memory marker store keyed by owner/resource pairs.
  Replaces, removes, and queries markers per resource.
- `MarkerDecorationsService`: turns markers into squiggle `decorations` for one
  resource and answers the marker-hover lookup (`markers_at`).

The browser-side presentation — the marker hover participant and the squiggle
DOM — stays in `viewer`; this package is the pure data those parts consume.

## Boundaries

- Pure logic: no DOM, browser, or native FFI; builds on `js` and `native`.
- Depends only on `base/common` (URI/range identity), `language` (diagnostics),
  and `viewer/decorations` (render decorations).
- Depends on neither the `viewer` browser package nor any other view part. The
  dependency edge is one-directional: `viewer -> viewer/markers`.
