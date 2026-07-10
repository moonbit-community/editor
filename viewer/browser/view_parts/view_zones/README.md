# viewer/browser/view_parts/view_zones

The DOM half of Monaco's `viewParts/viewZones/viewZones.ts`.
`BrowserViewZone` carries an id, anchor line, pixel height, node, and optional
top/height callbacks. `ViewZones::render_view_zones` reads each zone's layout
whitespace from the current `ViewportData`, mounts and positions visible nodes,
detaches offscreen nodes, and reports an offscreen top to callback-driven
followers.

The public host seam is `Viewer::change_view_zones` with
`ViewZoneChangeAccessor`; that glue and the Viewer-owned zone registrations live
in the root `viewer` package. The per-model `ViewZones` object owns only the
container/rendering side. Its `ViewPart` implementation lives in
`viewer/browser/view`; this package is JS-only.
