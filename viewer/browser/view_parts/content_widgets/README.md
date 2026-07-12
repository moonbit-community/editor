# viewer/browser/view_parts/content_widgets

The generic content-widget layer, ported from Monaco's
`viewParts/contentWidgets/contentWidgets.ts` and the `IContentWidget`
contracts in `editorBrowser.ts`. Hover's concrete widget lives in
`viewer/contrib/hover/browser`, not in this package.

## Contract

- `ContentWidget` exposes an id, DOM node, optional model-space primary and
  secondary anchors, nullable ordered `Above`/`Below`/`Exact` preferences,
  position affinity, the `useDisplayNone` scheduling/display gate, optional
  safe `before_render` / `after_render` callbacks, and whether the node may
  overflow the editor. Because MoonBit traits cannot test whether a method is
  present, `has_before_render` / `has_after_render` are the explicit optional
  capability bits; two narrow safe-invoke helpers preserve the source's
  exception-to-fallback behavior and callback argument order.
- `ContentWidgets::add_widget` mounts a node once in either `.contentWidgets`
  or `.overflowingContentWidgets`; `remove_widget` is the only unmount path.
  `set_widget_position` retains model anchors, projects their current view
  positions through the installed live context, and invalidates cached
  dimensions. Line-mapping/changed/inserted/deleted events immediately
  reproject those retained model anchors before the part is marked dirty.
- A `LayoutInfo` configuration event refreshes each retained widget's cached
  `contentLeft`, `contentWidth`, and `maxWidth`; unrelated configuration events
  leave those caches untouched. `on_before_render_widgets` performs the
  complete max-width write pass before text rendering; the later
  `prepare_render_widgets` consumes measured ViewLines caret positions and
  per-line vertical facts, rounds DOM dimensions, and runs source-ordered
  two-pass placement. The final `render_widgets` call
  gates visibility mutations, preserves focus by parking a visible off-viewport
  widget at `top:-1000px`, and safely reports the selected coordinate.
- Every outer phase snapshots the insertion-ordered widget ids before its
  live map lookups, mirroring `Object.keys(_widgets)`. Reentrant additions wait
  for the next phase; removing the current widget is safe, while removing a
  not-yet-visited id preserves the source's missing-lookup failure.
- Overflow width and explicit page-layout scroll subtraction are scoped to each
  node's owner document and `defaultView`, including detached-document zero
  fallbacks. The external page-position helper instead falls back to the main
  window for a detached owner. Client-area lookup preserves the iOS
  `visualViewport` preference and returns a detached body's own client box.
  Fixed overflow widgets and the editor-level `allowOverflow` option remain
  deferred configuration seams. The generic affinity handoff is complete;
  hover's `shouldAppearBeforeContent` producer is a separate deferred seam.

Two structural reductions are explicit. `View::new` stamps the ContentWidgets
fingerprints after construction because importing the fingerprint owner here
would create a package cycle; the nodes are stamped before mounting or hit
testing. Supplied widget nodes remain raw Rabbita elements, so style writes do
not gain Monaco `FastDomNode`'s per-property cache. ViewPart dirty/equality
gates still preserve source write order and values, but setter-level duplicate
write suppression is not claimed.

`ContentWidgetsRenderContext` is a capability record because importing
`browser/view` would create a cycle. The `ViewPart` implementation therefore
lives in the trait-owning `viewer/browser/view` package. This package is
JS-only and contains no `Viewer::` methods.
