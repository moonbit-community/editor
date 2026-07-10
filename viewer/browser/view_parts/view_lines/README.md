# viewer/browser/view_parts/view_lines

The virtualized text-line ViewPart, ported from Monaco's `viewLines.ts` and
`viewLine.ts`.

`ViewLines::render_text` stores one retained `ViewLine` per current half-open
`LineWindow` and reconciles them through `viewer/browser/view_layer`'s shared
`ViewLayerRenderer`: new rows use one HTML batch, invalid rows use one detached
batch, and equal render input skips replacement. Each line keeps the
`CharacterMapping` produced by the common renderer for DOM hit testing and live
selection/decoration measurements.

The part receives `View`'s shared cached `.lines-content` node. After rows are
reconciled it applies layer hinting, `contain: strict`, and the sole scroll
top/left writes to that rail. Retained row layout writes use cached per-property
top/height/line-height setters.

Public reads expose the root, rendered line nodes/mappings, measured line
width, and DOM-position lookup. `DomReadingContext` shares layout reads within
a frame. `render_line_input_for_viewport` bridges `ViewportData` to the common
HTML renderer; exact signatures are in `pkg.generated.mbti`.

`View::render` drives ViewLines specially before every other dirty part, as
Monaco does; its normal ViewPart prepare/render methods are unsupported. The
trait implementation lives in `viewer/browser/view`. This JS-only package
contains no root `Viewer::` methods.
