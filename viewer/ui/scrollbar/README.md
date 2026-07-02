# viewer/ui/scrollbar

The custom scrollbar widget: a browser-UI leaf, the local analog of Monaco's
`base/browser/ui/scrollbar/`. It owns the Monaco-shaped scrollable-element DOM
shell (wrapper, content, vertical/horizontal bars and sliders, shadows) and the
custom scrollbar node geometry. Callers decide whether scroll positions are
written back into `ViewLayout` or a native content element.

## Responsibilities

- `ScrollableElementDom`: the scrollable-element DOM shell plus reveal/fade and
  drag-thumb geometry. `update_from_model` / `update_from_native_content` write
  bar and slider styles; `native_scroll_to` / `native_scroll_by` drive a native
  content element; `track` / `slider` / `desired_position_from_track` expose the
  nodes and arithmetic the input controller needs for thumb drags.
- `ScrollableElementOwner` / `ScrollbarDrag`: the owner tag and active-drag
  record the shared document-level mousemove/up handling uses to apply a drag to
  the correct scroll target.
- `normalized_wheel_delta` / `drag_coord`: wheel and pointer helpers.

The scroll-position arithmetic itself (`ScrollbarState`) lives in
`viewer/common/view_layout`; this package is the DOM and event geometry around
it.

## Boundaries

- A browser-UI subpackage: it owns browser DOM, so it may import `rabbita/dom`
  and declare narrow JS FFI (the auto-hide timer). It must not import the
  rabbita TEA/vdom/command layers, websocket transport, or any
  `internal/shell/*` package.
- May depend on `viewer/common/view_layout` (`ScrollbarState` /
  `ScrollDimensions` / `ScrollPosition`).
- Must not import the `viewer` browser core. The edge is one-directional:
  `viewer -> viewer/ui/scrollbar`. `scripts/check-architecture.mbtx` enforces
  this via `is_viewer_browser_subpackage`.
