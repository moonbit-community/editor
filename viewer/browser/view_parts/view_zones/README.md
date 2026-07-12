# viewer/browser/view_parts/view_zones

The browser-side port of Monaco's `viewParts/viewZones/viewZones.ts`.
`ViewZone` is the retained mutable delegate; `ViewZoneChangeAccessor` adds it
under a generated whitespace ID, removes it, or rereads its mutable mapping and
height through `layout_zone`. The per-model `ViewZones` owner computes hidden
area and height facts, mounts caller-owned content and margin nodes without
replacing their class/style/content, safely reports host callback failures, and
renders ID-bearing viewport whitespace with the source visibility/offscreen and
width rules.

The merged local Margin owner remains the viewport-fixed clipping node used by
the frozen overlay implementation. Its `.margin-view-zones` child therefore
carries Monaco Margin's `bigNumbersDelta - scrollTop` parent offset; individual
margin-zone nodes still receive exactly the same top/height/display writes as
their content peers.

The public host seam is `Viewer::change_view_zones` with
`ViewZoneChangeAccessor`; the root package owns only the public constructor,
model/View guard, internal-before-outgoing event order, and unconditional render
schedule. Zone registration itself belongs to this per-model ViewPart. Its
`ViewPart` implementation lives in `viewer/browser/view`; this package is
JS-only.
