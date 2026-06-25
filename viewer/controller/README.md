# viewer/controller

The browser input controller — the local analog of Monaco's
`editor/browser/controller/`. It owns the DOM listener wiring for pointer input
and never reaches into the concrete view; it calls back through a narrow
`PointerHandlerHelper`, the analog of Monaco's `IPointerHandlerHelper`.

## How this mirrors Monaco

Monaco's `MouseHandler` takes `(ViewContext, ViewController, IPointerHandlerHelper)`
and the `View` hands it the object literal `_createPointerHandlerHelper()` returns
— DOM nodes as fields, view-dependent operations as closures. The faithful
MoonBit translation keeps that shape:

- `PointerHandlerHelper` is a **struct of nodes + closures** (not an interface
  implemented by a class), built by the viewer in `hook_view_input` where the
  view is in scope — the same idiom `viewer.ViewContext` already uses.
- `MouseHandler` owns the active scrollbar-thumb drag (Monaco's
  `MouseDownOperation`/drag state) and the listener wiring.

The dispatch side (Monaco's `ViewController`, our `Viewer::dispatch_mouse`) stays
in the viewer core — Monaco likewise keeps `viewController.ts` under `view/`, not
`controller/`.

## Scope

This package holds the browser pointer-input layer:

- **Mouse selection + hit test** (Monaco `MouseDownOperation` + `mouseTarget.ts`):
  `handle_mouse_move`/`handle_mouse_down`, multi-click gating, drag-select, and
  drag-autoscroll. `MouseHandler` owns the `MouseDownState`-equivalent fields.
- **Scroll / scrollbar interaction** (Monaco `ScrollableElement` pointer input):
  scrollbar thumb/track drags, reveal-on-hover, editor wheel, and the
  browser-driven reveal bridge.

What stays in the viewer core: the *measurement* read-phase (`view_metrics`,
`gutter_width`, glyph probe) — exposed to the controller through the helper —
and the *dispatch* side (`Viewer::dispatch_mouse`, Monaco's `ViewController`),
which the controller feeds via a `MouseDispatch` intent.

## Boundaries

- A browser-UI subpackage: it owns browser DOM, so it may import `rabbita/dom`
  and declare JS FFI, but not the shell, the rabbita TEA/vdom/command layers, or
  the `viewer` core. The edge is one-directional: `viewer -> viewer/controller`
  (`scripts/check-architecture.mbtx`, `is_viewer_browser_subpackage`).
- May depend on `base/common`, `viewer/common`, `viewer/view_model`,
  `viewer/ui/scrollbar`, and `viewer/view_layout`.
