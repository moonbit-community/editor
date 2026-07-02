# viewer/common/markers

Backend-neutral marker model for the readonly viewing path. A port of Monaco's
marker stack (`platform/markers` + marker rendering support), reduced to what a
readonly viewer needs: diagnostics stored as markers, mapped to squiggle
decorations and to the marker-hover lookup.

## Responsibilities

- `Marker`: a diagnostic stored by owner and resource, ready for
  marker-specific metadata. `from_diagnostic` / `to_diagnostic` bridge the
  shared `language.Diagnostic` shape.
- `MarkerService`: an in-memory marker store keyed by owner/resource pairs.
  Replaces, removes, and queries markers per resource.
- `MarkerDecorationsService`: turns markers into squiggle decorations for one
  resource and answers the marker-hover lookup (`markers_at`).

The browser-side presentation — the marker hover participant and the squiggle
DOM — lives with the viewer packages; this package is the pure data those
parts consume.

## Boundaries

- Pure logic: no DOM, browser, or native FFI; builds on `js` and `native`.
- Depends only on `base/common` (URI/range identity), `language`
  (diagnostics), and `viewer/common/model` (decoration shapes).
- Depends on neither the root `viewer` package nor any view part. The
  dependency edge is one-directional: `viewer -> viewer/common/markers`.
