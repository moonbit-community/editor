# viewer/ui/scrollbar

The browser-UI leaf corresponding to Monaco's
`base/browser/ui/scrollbar/`. It supplies the shared custom scrollbar used by
the editor and the hover widget; callers decide whether a new position updates
`ViewLayout` or a natively scrolling content element.

## Contract

- `ScrollableElementDom` owns the wrapper/content nodes, horizontal and
  vertical tracks/sliders, shadows, reveal/fade state, and two
  `ScrollbarState` values.
- `update_from_model` paints editor scroll dimensions/position;
  `update_from_native_content` reads a native scrolling element.
  `native_scroll_to`/`native_scroll_by` drive the latter.
- `track`, `slider`, `state`, `desired_position_from_track`, and drag/reveal
  methods expose the geometry needed by `viewer/browser/controller`.
- `StandardWheelEvent` and `mouse_wheel_scroll_deltas` normalize wheel input;
  `ScrollableElementOwner` and `ScrollbarDrag` let the controller distinguish
  editor and hover drags.

Scroll-position arithmetic remains in `viewer/common/view_layout`; this package
owns DOM and interaction geometry only. It is JS-only, may use narrow Rabbita
DOM/JS bindings, and must not import root `viewer`, browser view/controller,
Rabbita TEA/vdom/command, transport, or `internal/shell/**`.
