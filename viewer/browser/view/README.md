# viewer/browser/view

The per-model browser `View`, ported from Monaco's `editor/browser/view/`.
It owns the editor DOM subtree and coordinates the eight stateful ViewParts.
The root `Viewer` owns the View's lifetime: no View exists while no model is
attached, and a model swap destroys and replaces it.

## Render contract

`View::render(ViewContext, ViewRenderInput)` performs one Monaco-shaped frame:

1. Diff the current render snapshot from the previous one into typed
   `ViewEvent`s and offer them to every part.
2. Render dirty `ViewLines` first, because later parts measure live line DOM.
3. Run `prepare_render` for the remaining dirty parts (read/measure phase).
4. Run their `render` methods (DOM-write phase), then retain the snapshot.

The eight handles are ViewLines, ViewZones, content overlays, margin overlays,
ContentWidgets, ViewCursors, OverlayWidgets, and EditorScrollbar. Content
overlays register current-line highlight, selection, then decorations; margin
overlays register current-line margin, line decorations, then line numbers.

`ViewContext` supplies the measurement/conversion closures; `ViewRenderInput`
supplies the active ViewModel, layout, viewport, configuration, selection,
zones, and generations. `RenderingContext` and
`RestrictedRenderingContext` keep read- and write-phase data separate.
Selection and decoration geometry is measured from the current line DOM in
`selection_measure.mbt`.

## Ownership and boundary

`View` owns the root section, overflow guard, squiggle style, and each part's
DOM container. The root `viewer` package directly reads selected `pub(all)`
fields to implement `Viewer::` methods; MoonBit's foreign-method rule keeps
that glue out of this package.

The private `ViewPart` and `DynamicViewOverlay` implementations live here,
including implementations for foreign view-part types. This satisfies
MoonBit's orphan rule and keeps dependencies one-way:
`browser/view -> browser/view_parts/**`. This is a JS-only package; exact API
and imports are in `pkg.generated.mbti` and `moon.pkg`.
