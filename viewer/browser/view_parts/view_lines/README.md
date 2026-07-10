# viewer/browser/view_parts/view_lines

The virtualized text-line ViewPart, ported from Monaco's `viewLines.ts` and
`viewLine.ts`.

`ViewLines::render_text` maintains parallel arrays for the current half-open
`LineWindow`: it retains intersecting line nodes, removes leaving nodes, creates
entering nodes, and rewrites a retained line only when its render input changed.
Each line keeps the `CharacterMapping` produced by the common view-line
renderer. The mapping supports DOM-to-view-position hit testing and the live
DOM measurements used by selections and decorations.

Public reads expose the root, rendered line nodes/mappings, measured line
width, and DOM-position lookup. `DomReadingContext` shares layout reads within
a frame. `render_line_input_for_viewport` bridges `ViewportData` to the common
HTML renderer; exact signatures are in `pkg.generated.mbti`.

`View::render` drives ViewLines specially before every other dirty part, as
Monaco does; its normal ViewPart prepare/render methods are unsupported. The
trait implementation lives in `viewer/browser/view`. This JS-only package
contains no root `Viewer::` methods.
