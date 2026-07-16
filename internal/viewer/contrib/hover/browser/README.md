# internal/viewer/contrib/hover/browser

The JS-only content-hover browser implementation. It owns mouse-target event
reduction, anchor discovery, the concrete hover controller, DOM rendering and
geometry, and the persistent scrollable content widget. The root Viewer owns
the controller lifetime, timers, provider execution, decorations, and widget
mounting.

DOM-free hover state, participants, reconciliation, and HTML rendering live in
`internal/viewer/contrib/hover`. Browser view and scrollbar dependencies are
the internal packages under `internal/viewer/**`. The emitted stylesheet
remains at `viewer/contrib/hover/hover.css`.

Exact callable types are in `pkg.generated.mbti`. Run focused tests with:

```sh
moon test internal/viewer/contrib/hover/browser --target js
```
