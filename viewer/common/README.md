# viewer/common

A shrinking residual of the former common grab-bag. What remains here is the
code with no better-focused `viewer/common/*` subpackage yet:

- `line_html.mbt`: compatibility helpers `render_line_html` /
  `render_line_class` over the view-line renderer in
  `viewer/common/view_layout`.
- `mouse_target.mbt`: the DOM-free mouse hit-testing value types and algorithm
  (`MouseTargetType`, `MouseTarget`, `ViewMetrics`, `hit_test`), resolved
  against render frames plus view-zone layout data. A `MouseTarget` carries
  the hit line's `token_index` into its `IViewLineTokens` (Monaco's
  `LineTokens.findTokenIndexAtOffset`), not a per-line span index. These stay
  here (not in the js-only `viewer/browser/controller`) because the
  multi-target `viewer/contrib/hover` depends on `MouseTarget` directly.

## Boundaries

- May depend on `viewer/common/view_layout` and `viewer/common/view_model`
  (tests also use `language`, `viewer/common/model`, and `syntax` for
  fixtures).
- Must not assume DOM nodes, browser APIs, CSS runtime behavior, native
  effects, server routing, or filesystem providers; hit-testing is pure
  arithmetic over frame data and caller-measured metrics.
- Must not declare FFI; builds on `js` and `native`.
