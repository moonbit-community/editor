# viewer/browser/view_layer

The shared Monaco `ViewLayerRenderer` recycler used by text lines and overlay
rows. It preserves the source's no-overlap reset, overlap layout, before/after
insert/remove order, one batched new-row HTML write, and one detached invalid-
row batch. Row-specific render state remains in the owning view-part package
and reaches the renderer through typed callbacks.

This package is JS-only and imports only the DOM binding plus
`viewer/common/view_layout`; it never imports a concrete view part or the root
viewer facade.
