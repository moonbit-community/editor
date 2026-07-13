# viewer/browser/view_parts/content_widgets

The generic content-widget layer, ported from Monaco's
`viewParts/contentWidgets/contentWidgets.ts` and the `IContentWidget`
contracts in `editorBrowser.ts`. Hover's concrete widget lives in
`viewer/contrib/hover/browser`, not in this package.

## Contract

- `ContentWidgetHandle` exposes live id, DOM-node, and position getter
  closures; the `allowEditorOverflow`, `useDisplayNone`, and
  `suppressMouseDown` values; and independently optional `before_render` /
  `after_render` callbacks. The record preserves the source's value-level
  optional members without mandatory `has_*` methods. Two narrow safe-invoke
  helpers preserve the source's exception-to-fallback behavior and callback
  argument order. The content-widget layer owns the `suppressMouseDown`
  lookup/default; forwarding that query through the controller remains an
  input-boundary seam.
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
not gain Monaco `FastDomNode`'s per-property cache. Lifecycle dirty/equality
gates still preserve source write order and values, but setter-level duplicate
write suppression is not claimed.

`ContentWidgetsRenderContext` is a capability record because importing
`browser/view` would create a cycle. The narrow lifecycle adapter therefore
lives at the private rendering-context boundary in `viewer/browser/view`.
This package is JS-only and contains no `Viewer::` methods.
