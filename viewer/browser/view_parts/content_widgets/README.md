# viewer/browser/view_parts/content_widgets

The generic content-widget layer, ported from Monaco's
`viewParts/contentWidgets/contentWidgets.ts` and the `IContentWidget`
contracts in `editorBrowser.ts`. Hover's concrete widget lives in
`viewer/contrib/hover/browser`, not in this package.

## Contract

- `ContentWidget` exposes an id, DOM node, optional model-space primary and
  secondary anchors, ordered `Above`/`Below`/`Exact` preferences, and whether
  the node may overflow the editor.
- `ContentWidgets::add_widget` mounts a node once in either `.contentWidgets`
  or `.overflowingContentWidgets`; `remove_widget` is the only unmount path.
  `set_widget_position` retains model anchors, projects their current view
  positions through the installed live context, and invalidates cached
  dimensions. Line-mapping/changed/inserted/deleted events immediately
  reproject those retained model anchors before the part is marked dirty.
- A `LayoutInfo` configuration event refreshes each retained widget's cached
  `contentLeft`, `contentWidth`, and `maxWidth`; unrelated configuration events
  leave those caches untouched. `prepare_render_widgets` consumes the retained
  view positions, measures the box, and chooses a placement. The later
  `render_widgets` call writes position and visibility. Hiding changes
  `display`/`visibility` but does not unmount the node, keeping subtrees stable.
- The current left anchor uses the measured monospace character width. Monaco
  asks ViewLines for an exact visible range; this is the documented geometry
  seam until that measurement is exposed here.

`ContentWidgetsRenderContext` is a capability record because importing
`browser/view` would create a cycle. The `ViewPart` implementation therefore
lives in the trait-owning `viewer/browser/view` package. This package is
JS-only and contains no `Viewer::` methods.
