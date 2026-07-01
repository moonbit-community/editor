# viewer/browser/view_parts/content_widgets

The content-widgets view part, ported from Monaco's
`editor/browser/viewParts/contentWidgets/contentWidgets.ts` plus the hover
content widget's DOM/geometry half from
`editor/contrib/hover/browser/contentHoverWidget.ts` — the viewer's only
content widget.

## Responsibilities

- `ContentWidgets`: the `.contentWidgets`/`.overflowingContentWidgets`
  container pair, the hover widget's DOM (`HoverWidgetDom`), dirty flag, and
  prepared render input. `pub(all)` for the same reason as
  `viewer/browser/view_parts/view_zones`'s types — its `ViewPart` trait impl
  lives in `viewer/view_part.mbt`, not here.
- `render_hover_widget` / `ensure_hover_widget`: positions, sizes, and
  (once, read-after-write) measures the hover widget, mirroring Monaco's
  `RenderedContentHover`/`ResizableContentWidget` placement logic.

## The `HoverWidgetHost`/`hover_view` inversions

This is the one view part with real cross-cutting dependencies beyond the
`ViewPart` trait, both resolved by the same host/callback pattern
`controller_host.mbt`'s `PointerHandlerHelper` already uses:

- `ContentWidgetsPrepared.hover_view : @hover.HoverWidgetView?`, not the full
  `@hover.HoverController` — the controller stays with `Viewer` (the
  foreign-method rule keeps every `Viewer::` method there), so
  `view_part.mbt`'s `prepare_render` impl resolves
  `HoverController::widget_view` before handing this package only the
  already-derived view. The same-frame re-measure pass
  (`render_hover_widget`'s recursive call) uses `HoverWidgetView::measured`
  (defined alongside `HoverWidgetView` in `viewer/contrib/hover`) instead of
  `HoverController::measured`.
- `render_hover_widget`/`ensure_hover_widget` take a `HoverWidgetHost`, not
  `ViewContext` — `ViewContext` lives in `browser/view/`, which needs
  `ContentWidgets` back for `View`'s fields and the `ViewPartHandle` enum, so
  importing it here would cycle. `view_part.mbt`'s `render` impl unpacks
  `context.view_context`'s fields into a `HoverWidgetHost` at the call
  boundary.

## Boundaries

- Does not implement the `ViewPart` trait here — see this refactor's
  cycle-backlog note in `docs/exec-plans/viewer-directory-mirror.md` and
  `viewer/browser/view_parts/view_zones/README.md`.
- A browser-tier package (`supported_targets = "js"`); may import
  `viewer/common/*`, `viewer/contrib/hover`, `viewer/ui/scrollbar`, and
  `rabbita/dom`.
