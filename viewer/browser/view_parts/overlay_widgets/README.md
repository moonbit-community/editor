# viewer/browser/view_parts/overlay_widgets

The null-position subset of Monaco's
`viewParts/overlayWidgets/overlayWidgets.ts`. `OverlayWidgets` owns the fixed
`.overlayWidgets` and `.overflowingOverlayWidgets` containers plus an id-to-DOM
registry.

`add_widget(id, node)` mounts or replaces a self-positioning node;
`remove_widget(id)` unmounts it. The public root
`Viewer::{add,remove}_overlay_widget` API keeps registrations across model
swaps and re-adds them to each new per-model View. Monaco's preference-based
placement and `layoutOverlayWidget` machinery are not implemented, so the
ViewPart prepare/render steps remain no-ops.

The `ViewPart` implementation lives in `viewer/browser/view`. This package is
JS-only and does not import the root Viewer.
