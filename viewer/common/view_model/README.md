# viewer/common/view_model

Long-lived, DOM-free projection from a `TextModel` to renderable view lines.

## Pipeline and API

`ViewModel` owns the model, projected line collection, single cursor,
`ViewLayout`, decoration resolver, coordinate converter, and per-source hidden-area
sets. It is created once when a model attaches and updated in place.

```text
model line + grammar tokens + injected-text decorations
  -> ProjectedTextLine
  -> soft-wrap ModelLineProjection segments
  -> hidden-area filtering
  -> ViewLineData + model/view coordinate conversion
  -> viewport_data_from_view_model -> view_layout.ViewportData
```

- `ViewModelLinesFromProjectedModel` is always used. With wrapping disabled each
  line has a cheap identity projection; there is no separate
  `ViewModelLinesFromModelAsIs` implementation. Models above the tokenization
  safety thresholds remain on this projected collection and render default
  tokens; collection fallback belongs to the separate large-file plan.
- Injected text is projected before line breaking, so its width affects wrapping;
  source mappings, tokens, and decorations remain anchored to model offsets.
- Viewport construction uses one `get_view_lines_data` batch and a parallel
  needed mask. Each needed projected model line performs one passive token-store
  read; unneeded lines and content/length-only queries perform none, and no view
  read invokes the lexer.
- Configuration or injected-text/content flushes reproject affected state at the
  current whole-model granularity, invalidate decoration caches, and reproject the
  cursor from model coordinates. Incremental edit events are not part of the
  readonly contract.
- Cursor mutation has one source/reason-aware transition path. Model-side states
  validate through `TextModel`; view-side states clamp/normalize in this package
  and retain their authoritative projected position. Left/Right move by UTF-16
  scalar boundaries, Up/Down/Page move across wrapped view lines with visible-
  column residues, and Home/End choose the source model/view branch. Word/Line
  pointer continuation dispatches from the stored anchor kind. Source-shaped
  MoveTo and Line entries accept a required model position plus an optional
  already-known view position: absent converts model-to-view; supplied is kept
  only when its normalized view-to-model result matches the validated model
  position.
- `CursorMoveDirection` retains the source's full 15-member `Direction` enum;
  `SimpleMoveDirection` is its exact 11-member simple-move union, and
  `CursorMoveUnit` is the exact six-member `Unit` contract. Unscoped
  blank/wrapped-position and viewport directions, vertical model/folded units,
  and Left/Right HalfLine return without mutation at their explicit deferred
  branches.
- `CursorEventDispatcher` is the outgoing-only half of Monaco's
  `ViewModelEventDispatcher`: its heterogeneous queue carries cursor-state,
  ViewZones-changed, and model-token facts. Cursor selection/version no-ops are
  filtered and queued cursor events can coalesce; model-token wrappers retain
  the identical source event, are never no-ops, and never merge. The dispatcher
  recursively drains reentrant outgoing facts and
  uses separate source-shaped listener-delivery state so a nested fire first
  finishes the remaining listeners for the current value. The nested value is
  then delivered before the initiating callback resumes. The root Viewer FIFO
  separately keeps public event pairs adjacent. It exposes
  `on_cursor_state_changed`, `on_view_zones_changed`, and
  `on_model_tokens_changed`; `ViewModel::dispose` disposes all emitters and
  clears pending outgoing facts and listener-
  delivery state. Generic browser View handlers, mixed view/outgoing
  collectors, and the editor-wide cross-event delivery queue remain outside
  this reduced common owner.
- Left/Right movement is surrogate-pair safe and otherwise advances one
  Unicode code point at a time. Full grapheme-cluster movement and the matching
  grapheme-segmented visible-column arithmetic remain deferred.
- `set_hidden_areas` merges ranges by source, updates line/layout/decorations/
  cursor, and preserves the top visible model line when folding changes above
  the viewport. Two optional owner continuations bridge the browser-package
  cycle without moving ViewEvents into this common package: the unchanged gate
  runs before `with_event_batch`; on a changed mapping,
  `on_line_mapping_changed` wraps the cursor continuation so the root appends
  Flushed/Mapping/Decorations, cursor, layout, and recovery-scroll facts in
  source order. Headless callers omit both continuations.
- A ViewModel may borrow the exact attached-view handle owned by its root
  `ModelData`. Vertical scroll and content remapping publish current model
  visible ranges as unstable; initial setup and explicit view-state restore
  publish the stabilized state. Hidden model ranges are removed in order.
  Model token events are converted through the current projection, delivered
  synchronously to the browser ViewEvent callback, and only then enqueued as
  the original outgoing model event. The listener never forces tokenization.
- `ViewModelDecorations` converts model ranges through
  `viewer/common/inline_decorations` and resolves only the requested viewport.

There are no `FrameSource`, `FrameViewport`, `RenderLine`, or `RenderFrame` APIs;
browser code consumes `ViewModel` plus `view_layout.ViewportData`. Selection/copy
helpers belong to `viewer/common/core` and the root `viewer`, not this package.

The upstream map is the pinned `src/vs/editor/common/viewModel/` files
`viewModelImpl.ts`, `viewModelLines.ts`, `modelLineProjection.ts`,
`monospaceLineBreaksComputer.ts`, and `viewModelDecorations.ts`, plus
`viewLayout/viewLinesViewportData.ts`.
This package must remain multi-target and FFI-free, with no root-viewer, browser,
server, transport, workspace, or host dependency. See `pkg.generated.mbti`; run
`moon test --target js viewer/common/view_model` and
`moon test --target native viewer/common/view_model`.
