# viewer/browser/view_parts/view_lines

The virtualized text-line ViewPart, ported from Monaco's `viewLines.ts` and
`viewLine.ts`.

`ViewLines::render_text` stores one retained `ViewLine` per current half-open
`LineWindow` and reconciles them through `viewer/browser/view_layer`'s shared
`ViewLayerRenderer`: new rows use one HTML batch, invalid rows use one detached
batch, and equal render input skips replacement. Each line keeps the
`CharacterMapping` produced by the common renderer for DOM hit testing and live
selection/decoration measurements. The retained slow `RenderedViewLine`
strategy owns DOM-width and per-column pixel caches, source-shaped truncation
guards, whitespace/foreign-element facts, and RangeUtil visible-range reads.
The module-level `create_rendered_line` factory selects that normal strategy;
the approved WebKit and fast-renderer branches remain deferred.

The part receives `View`'s shared cached `.lines-content` node. After rows are
reconciled it applies layer hinting, `contain: strict`, and the sole scroll
top/left writes to that rail. Retained row layout writes use cached per-property
top/height/line-height setters. A cancel/reschedule 200ms scheduler completes
slow width sweeps when the fast pass encounters an uncached row, and the
measured maximum feeds `ViewLayout` using the source's ceil/monotonic rules.

Public reads expose the root, rendered line nodes/mappings, measured line
width, and DOM-position lookup. `DomReadingContext` shares layout reads within
a frame, while `RangeUtil` reuses and parks one DOM Range across reads.
`install_geometry_readers` installs the view-to-model line converter and model
text-direction capabilities used by multi-line `includeNewLines` queries;
converter progression and RTL newline width are owned here rather than inferred
from a rendered view-line input. The current product ViewModel emits only LTR
rendering data and therefore installs an LTR direction reader; the capability
boundary remains ready for a real model-direction producer. Raw tuple carriers
cross into `browser/view` to avoid a package cycle, where RenderingContext
constructs the source-shaped public carriers. `render_line_input_for_viewport` bridges
`ViewportData` to the common HTML renderer; exact signatures are in
`pkg.generated.mbti`.

`View::render` drives ViewLines specially before every other dirty part, as
Monaco does; its normal ViewPart prepare/render methods are unsupported. The
trait implementation lives in `viewer/browser/view`. This JS-only package
contains no root `Viewer::` methods.

Two deliberate browser seams remain: reusable ranges are created from the
first measured start node's `ownerDocument`, allowing document-local fixtures
without a global Range binding, and rendered rows retain the established
`data-line` attribute consumed by the browser conformance harness.
