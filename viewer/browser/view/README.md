# viewer/browser/view

The per-model browser `View`, ported from Monaco's `editor/browser/view/`.
It owns the editor DOM subtree and coordinates the eight stateful ViewParts.
The root `Viewer` owns the View's lifetime: no View exists while no model is
attached, and a model swap destroys and replaces it.

## Render contract

`View::render(ViewContext, ViewRenderInput)` performs one Monaco-shaped frame:

1. Read the sticky dirty state accumulated by source-emitted typed
   `ViewEvent`s since the previous frame.
2. Run every dirty part's `on_before_render` writes against one prepared
   viewport before text changes.
3. Render dirty `ViewLines`, because later parts measure the fresh line DOM.
4. Recollect parts dirtied by synchronous width/scroll feedback and construct
   the post-text RenderingContext from the same viewport.
5. Run `prepare_render` for the remaining dirty parts (read/measure phase).
6. Run their `render` methods (DOM-write phase), then clear each successful
   part write.

The View owns a fixed ordered event-handler set and a source-shaped nested
collector. Whole event batches are delivered FIFO; an event emitted
reentrantly becomes a later batch and cannot interleave the current one.
Transient changes are emitted at their source, so an A→B→A sequence before a
frame is not collapsed into a final-state snapshot. The closed local event
union includes the fifteen scoped Monaco classes. Composition has no readonly
producer. Theme carries the existing `String` theme identity only to preserve
the declaration and dispatch shape; concrete theme application remains direct
CSS/root state and has no typed theme producer or ViewPart handler.

`View` constructs one 2^24px `.lines-content` rail and passes the same cached
node to `EditorScrollbar` and `ViewLines`. Vertical/horizontal scroll moves only
that rail; text rows, zones, content overlays/widgets, and cursors remain in its
coordinate space. The margin keeps its independent vertical rail.

The eight handles are ViewLines, ViewZones, content overlays, margin overlays,
ContentWidgets, ViewCursors, OverlayWidgets, and EditorScrollbar. Content
overlays register current-line highlight, selection, then decorations; margin
overlays register current-line margin, line decorations, then line numbers.
Content and margin overlays remain one dirty handle each. Their current-line
state follows the source predicates, while a sibling selection, decoration,
or retained-row consumer can still make the aggregate render when the nested
current-line predicate is false. This is harmless bounded overwork: row HTML
writes remain equality-deduplicated, no handler schedules another native
animation frame, and white-box/browser tests cover every event axis and
convergence. ViewLines width feedback can request a logical follow-up while
the current animation-frame queue is draining; the source-shaped root
scheduler drains it in that same native frame.

The root class builder appends Monaco's platform suffix independently from the
viewer-owned classes: Safari and native WebKit views use
`no-minimap-shadow enable-user-select`, other browsers use `no-user-select`,
and macOS additionally appends `mac`.

`ViewContext` supplies the measurement/conversion closures; `ViewRenderInput`
supplies the active ViewModel, layout, viewport, configuration, selection,
and zones. `RenderingContext` and
`RestrictedRenderingContext` keep read- and write-phase data separate.
Production selection geometry consumes
`RenderingContext.lines_visible_ranges_for_range`; `selection_measure.mbt`
retains the public/compatibility single-line helpers over the same ViewLines
producer. Cycle-free ViewLines tuples and a ContentWidgets capability record
are converted here into Monaco-shaped rendering carriers.
MoonBit keeps `HorizontalRange`, `FloatHorizontalRange`, and
`HorizontalPosition` fields immutable after construction; the pinned source's
mutable public fields have no mutating consumer in the scoped viewer. Optional
GPU query fallback, concatenation, and sorting remain deferred with GPU
ViewLines.

## Ownership and boundary

`View` owns the root section, overflow guard, squiggle style, and each part's
DOM container. The root `viewer` package directly reads selected `pub(all)`
fields to implement `Viewer::` methods; MoonBit's foreign-method rule keeps
that glue out of this package.

`dispose` is idempotent. It tears down ViewLines, then every remaining
ViewPart, then the View lifetime-disposable store. The local line, zone,
overlay, widget, and cursor parts own only nodes/state below the root; the
scrollbar additionally owns a cancellable hide timer. Mouse/input controllers
and root listeners enter the lifetime store through `add_disposable`.

External overflow hosting is deferred until the Viewer exposes an overflow
host option and the corresponding aggregate-focus seam; today both overflowing
widget nodes remain descendants of the ordinary View root. Edit-context
teardown is deferred until an edit-context owner and accessibility seam exist;
GPU teardown is deferred until the viewer has a GPU renderer and GPU-owned
parts.

The private `ViewPart` and `DynamicViewOverlay` implementations live here,
including implementations for foreign view-part types. This satisfies
MoonBit's orphan rule and keeps dependencies one-way:
`browser/view -> browser/view_parts/**`. This is a JS-only package; exact API
and imports are in `pkg.generated.mbti` and `moon.pkg`.
