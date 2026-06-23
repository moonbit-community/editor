# Toward a One-to-One Monaco Port (readonly viewer)

Status: proposed — scope decisions resolved 2026-06-23; awaiting go-ahead to
implement. Date: 2026-06-23.

This plan responds to a concrete selection bug whose root cause turned out to be
structural: the viewer is "Monaco-shaped" (mirrors roles and names) but in
several subsystems it **approximates** Monaco rather than **transcribing** it,
and those subsystems are where behavior diverges. The goal here is to decide how
to make the port precisely one-to-one with Monaco (excluding editing), and to
record a subsystem-by-subsystem audit so we know the blast radius before
committing.

Nothing in this plan is implemented yet. It supersedes the geometry-only
approach in `monaco-faithful-selection-hit-testing.md` (those commits stay as
historical evidence; see [Relationship to prior work](#relationship-to-prior-work)).

## The principle: transcribe, don't approximate

"One-to-one" means, concretely:

1. **Same module decomposition.** Each Monaco class/module in the viewing path
   maps to one MoonBit package/type with the same name and the same
   responsibilities. We do not invent helpers that have no Monaco counterpart in
   the cursor/selection/hit-test/decoration paths.
2. **Same algorithms.** Port the actual control flow line-by-line (idiomatic
   MoonBit syntax is fine; algorithmic re-derivation or scope shortcuts are
   not, unless explicitly recorded as a deliberate deviation).
3. **One coordinate model.** Everything in the cursor/selection/hit-test/
   decoration path works in **`Position` (1-based line, column)** — model
   positions and view positions, bridged only by the `CoordinatesConverter`.
   Raw document offsets appear **only** at the model/clipboard boundary. This is
   the single most important rule; violating it is what produced the current
   bug.
4. **Parity is verified, not asserted.** Every ported subsystem is gated by a
   conformance oracle captured from real Monaco (the repo already does this for
   hover/scrollbar under `tests/reference/monaco-hover-scrollbar/`). Without an
   oracle, "faithful" silently drifts — which is exactly how we got here.

Scope excluded from the port:

- **Editing.** `cursorTypeOperations`, `cursorDeleteOperations`, paste/type/cut
  commands, and all model mutation. The cursor/selection/navigation machinery is
  **viewing**, not editing, and stays in scope; the model is immutable and edit
  commands are simply never registered.
- **Tokenization.** Intentionally non-Monaco: it will be rewritten on MoonBit's
  built-in regex rather than Monaco's Monarch/tokenizer state machine. It is a
  decoupled, scoped module and is out of scope for this plan.
- **Caret rendering (`viewParts/viewCursors`).** Not now. The viewer stays
  selection-only; a click updates selection state but renders no blinking caret.
  Can be added later as its own plan.
- **View zones, content widgets, overlay widgets.** Audited here (see the table)
  but deferred to a separate plan. They are not on the selection/cursor critical
  path, so they keep their current behavior for now — except for the minimum
  `ViewEventHandler` wiring the typed-view-event migration forces on every view
  part (see Phase 2).

## Exhibit A: the selection bug, fully diagnosed

Reproduced against the running viewer (`/browser-tests/component.html`), drag to
select within one line:

- The clipboard (true selection state) reads `"compone"` → the selection range
  is columns `[0,7]`, which is ~correct: selection state roughly tracks the
  pointer.
- The painted highlight is `70.5px` wide. The DOM measurement of the rendered
  text yields `0..7 → 50.6px` but `0..10 → 72.3px`. So the overlay rendered
  `measure(0, 10)` for a `[0,7]` selection — **~3 columns too wide.**

Mechanism: the forward path (pointer → column → `RenderLine::source_offset_at_column`
→ model offset → stored selection) and the backward path (model offset →
`RenderLine::view_column_at_source_offset` → column → measure) are **bespoke
offset↔column helpers that do not exist in Monaco and are not consistent
inverses on projected/wrapped view lines.** The view-model README even states
the design out loud: "render-line source mappings keep hit testing and
decorations **model-offset based**." Monaco does the opposite — it never
round-trips through raw offsets; it stays in view `Position`s via the
`CoordinatesConverter` and renders selections from `ViewLineData(minColumn,
maxColumn)` through `linesVisibleRangesForRange`. The fix is not a patch to the
helpers; it is to stop having them.

## Subsystem audit

Fidelity legend: **Faithful** (transcribed, behaves like Monaco) · **Subset**
(faithful shape, reduced scope) · **Bespoke** (works differently from Monaco) ·
**Missing** (no local equivalent).

| Subsystem | Monaco module(s) | Local | Fidelity | Divergence / risk |
| --- | --- | --- | --- | --- |
| Value types | `core/position.ts`, `core/range.ts`, `core/selection.ts` | `base/common` `Position`/`Range`; `view_model.Selection` | **Bespoke** (Selection) | `Selection` is an anchor/focus `Position` pair, not `Range` + direction (`selectionStart`/`position`). |
| Coordinate conversion | `viewModel/viewModelImpl.ts`, `viewModelLines.ts`, `coordinatesConverter` | `view_model` `CoordinatesConverter`, `ModelLineProjection`, `ViewModelLinesFromProjectedModel` | **Faithful** (core) | Solid — but bypassed by the offset helpers below. |
| Render-line access | `ViewLineData(minColumn,maxColumn)`, `viewModel.getViewLineData` | `RenderLine` + `source_offset_at_column` / `view_column_at_source_offset` / `model_line_start_offset` | **Bespoke** | **The selection bug.** Offset-centric, non-inverse on projected lines. |
| Cursor/selection state | `cursor/cursor.ts` (`CursorsController`), `cursorCollection.ts`, `oneCursor.ts`, `cursorCommon.ts` (`CursorContext`, `SingleCursorState`, `CursorColumns`) | `mut selection : Selection?` on `Viewer` | **Missing** | No cursor model, no multi-cursor, no `leftoverVisibleColumns`, no view/model selection pair. |
| Navigation commands | `coreCommands.ts` (`MoveTo`, `MoveToSelect`, `CreateCursor`, `WordSelect`, `LineSelect`), `cursorMoveOperations.ts`, `cursorMoveCommands.ts` | — | **Missing** | No word/line granularity, no shift-extend, no keyboard selection. |
| Input controller | `controller/mouseHandler.ts`, `pointerHandler.ts`, `mouseTarget.ts`, `dragScrolling.ts` | `viewer/input.mbt`, `viewer/common/mouse_target.mbt`, `viewer/hit_test_dom.mbt` | **Bespoke** | 5-variant `MouseTarget` vs ~13 `MouseTargetType`; ad-hoc listeners; no drag autoscroll; arithmetic fallback. |
| Mouse→cursor bridge | `browser/view/viewController.ts` (`dispatchMouse`) | direct mutation in `viewer/selection.mbt` | **Missing** | Mouse events mutate selection directly instead of `dispatchMouse → CoreNavigationCommands`. |
| Selection overlay | `viewParts/selections/selections.ts` on `dynamicViewOverlay.ts`/`viewOverlays.ts` | inline in `ContentViewOverlays` + `measure_line_selection` closure | **Bespoke** | Not a `DynamicViewOverlay`; no `_renderResult`/prev-frame corner styling; square rects only. |
| Caret | `viewParts/viewCursors/` | — | **Missing** | A plain click shows no caret. |
| Render/invalidation | `viewModelEventDispatcher.ts`, `viewEvents.ts`, `view.ts` viewParts | `View` + `ViewRenderChange` snapshot-diff | **Bespoke** | Coarse snapshot diffing instead of typed view events; harder to keep parts correct. |
| Decorations | `model/intervalTree.ts`, `viewModel/viewModelDecorations.ts` | `decorations` (offset/range query) | **Bespoke** | No interval tree, no sticky/stack ordering, no model→view decoration mapping. |
| View layout | `viewLayout/linesLayout.ts`, `viewLayout.ts` | `view_layout` `LinesLayout`, `ViewLayout` | **Subset** | Uniform line height only (Monaco supports variable heights + whitespaces). |
| Line rendering | `viewLineRenderer.ts`, `lineDecorations.ts`, `characterMapping` | `view_line_renderer` | **Faithful** | Close port; keep. |
| Scrollbar / scrollable | `base/browser/ui/scrollbar`, `viewParts/editorScrollbar` | `scrollable_element`, `editor_scrollbar`, `view_layout/scrollbar_state` | **Faithful** | Oracle-backed; passes the hover/scrollbar conformance suite. |
| Hover | `contrib/hover/` | `hover_controller`, `hover_participants`, `hover_render` | **Faithful** | Oracle-backed; Monaco timing/DOM. |
| View zones / widgets | `viewParts/viewZones`, `contentWidgets`, `overlayWidgets` | `view_zones`, `content_widgets`, `overlay_widgets` | **Subset/Bespoke** | Deferred to a separate plan; here they get only the Phase 2 `ViewEventHandler` wiring. |
| Tokenization | Monarch/`tokenizationRegistry` | `syntax/*` | **Out of scope** | Being rewritten on MoonBit regex by decision; not ported. |

The headline: the **model/projection, line-rendering, scrollbar, and hover**
layers are genuine ports and should be kept. The **cursor/selection/input/
overlay/decoration/invalidation** layers are where the port forked, and they
share one root cause — an **offset-centric coordinate model** where Monaco is
**view-`Position`-centric**.

## Target architecture

Port the viewing input→cursor→selection→render stack as a faithful transcription.
Monaco module → MoonBit package/owner:

- `core/selection.ts` → real `Selection` (extends `Range`, carries direction).
  Likely `viewer/core` or `base/common`.
- `cursorCommon.ts`, `cursor/oneCursor.ts`, `cursorCollection.ts`, `cursor.ts`,
  `cursorMoveOperations.ts`, `cursorMoveCommands.ts`, selection subset of
  `coreCommands.ts` → a new `viewer/cursor` package (`CursorContext`,
  `SingleCursorState`, `CursorColumns`, `Cursor`, `CursorsController`,
  `CoreNavigationCommands`).
- `viewModel.getViewLineData` / `ViewLineData(minColumn,maxColumn)` → replace the
  offset-centric `RenderLine` accessors in `viewer/view_model`; hit-test and
  selection consume view `Position`s and the existing `CoordinatesConverter`.
- `browser/controller/{mouseHandler,pointerHandler,mouseTarget,dragScrolling}.ts`
  → faithful `MouseTargetFactory` (full `MouseTargetType`) and handlers in
  `viewer` (DOM/FFI allowed there).
- `browser/view/viewController.ts` → `ViewController.dispatchMouse` in `viewer`.
- `viewParts/selections/selections.ts` + `dynamicViewOverlay.ts` +
  `viewOverlays.ts` → real `DynamicViewOverlay` base and `SelectionsOverlay`.
- `viewModelEventDispatcher.ts` + `viewEvents.ts` + `viewEventHandler.ts` →
  typed view-event dispatch and a `ViewEventHandler` base, replacing the
  `ViewRenderChange` snapshot diff. Committed scope (Phase 2), not deferred:
  every view part — including the zones/widgets left to a separate plan —
  becomes a `ViewEventHandler` so the cursor/selection stack can drive renders
  through real events rather than coarse snapshot diffing.

## Parity oracle methodology

Extend the existing `tests/reference/` + conformance-spec pattern with oracles
captured from real Monaco for the ported subsystems:

- **Mouse-target oracle:** fixed document + font + viewport; table of
  `(clientX, clientY) → { type, position }`. Local `MouseTargetFactory` must
  reproduce it.
- **Cursor-state oracle:** sequences of `dispatchMouse` inputs (click, drag,
  shift-click, double/triple-click) → expected `Selection[]` transitions.
- **Selection-rect oracle:** selection → expected rectangles, including wrapped
  lines, EOL, empty lines, and (if implemented) rounded corners. Replaces the
  current `selection_geometry.spec.js` heuristic with exact geometry.

A subsystem port is "done" only when its oracle matches. This is the mechanism
that makes "1:1" enforceable rather than aspirational.

## Phasing (full transcription; each phase gated by its oracle)

All six phases are committed scope.

1. **Coordinate model.** Introduce `Selection` (Range+direction) and replace the
   offset-centric `RenderLine` accessors with view-`Position`/`ViewLineData`
   access through the `CoordinatesConverter`. This alone fixes Exhibit A.
2. **Typed view events.** Port `viewEvents`, `ViewEventHandler`, and
   `ViewModelEventDispatcher`; convert every view part to a `ViewEventHandler`
   and retire the `ViewRenderChange` snapshot diff. Done early (not deferred) so
   the cursor/selection stack drives renders through real events. Touches all
   parts, including the zones/widgets otherwise left to a separate plan — those
   get the minimum handler wiring only.
3. **Cursor stack.** Port `CursorContext`/`SingleCursorState`/`CursorColumns`,
   `Cursor`, `CursorsController`, and the selection subset of
   `CoreNavigationCommands`/`cursorMoveOperations`, emitting view events from
   Phase 2.
4. **Mouse target + view controller.** Port `MouseTargetFactory` (full type set)
   and `ViewController.dispatchMouse`; rewire `mouseHandler`/`pointerHandler`
   (+ `dragScrolling` autoscroll) to drive the cursor stack.
5. **Selection overlay.** Re-implement `SelectionsOverlay` as a real
   `DynamicViewOverlay` / `ViewEventHandler` consuming view positions.
6. **Decorations.** Port the interval-tree decoration model and
   `ViewModelDecorations` (view-`Position`-based, replacing the offset/range
   query model).

Phases 1–5 eliminate the whole selection bug class; Phase 6 removes the last
offset-centric subsystem. Caret rendering (`viewCursors`) is intentionally not
in this plan.

## Trade-offs

- **Cost:** ~10–15 modules transcribed plus oracles — a substantial rewrite of
  the input/cursor/selection stack. The model/projection, line-renderer,
  scrollbar, and hover layers are reused as-is.
- **Payoff:** converts an open-ended bug stream into a bounded, oracle-verified
  porting task; future Monaco features map straight across; the codebase reads
  against Monaco's source.
- **Alternative (rejected):** keep patching the bespoke approximations. Exhibit A
  shows each patch is a new divergence surface (the earlier "Monaco-shaped"
  selection rework passed its own tests yet still mis-rendered).

## Relationship to prior work

The commits from `monaco-faithful-selection-hit-testing.md` (DOM caret
hit-testing + client-rect measurement on the existing offset-centric pipeline)
are a partial step: the DOM measurement seam and retained `CharacterMapping` are
reusable, but the offset-centric coordinate access they were bolted onto is what
this plan removes. Treat that plan as superseded for the selection path; do not
rewrite its history.

## Decisions (resolved 2026-06-23)

1. **Scope/sequencing:** full transcription of phases 1–6. No "phase 1 only"
   shortcut.
2. **Caret:** not now — selection-only; `viewCursors` is out of scope.
3. **Invalidation:** port typed view events now (Phase 2), not deferred.
4. **Audit depth:** view zones / content widgets / overlay widgets are tracked
   in a separate plan; here they receive only the `ViewEventHandler` wiring that
   Phase 2 requires.

## Acceptance criteria (for the eventual implementation, not this doc)

- Cursor/selection/hit-test/decoration code contains no raw-document-offset
  round-trips; all of it works in view `Position`s via the `CoordinatesConverter`.
- `Selection`, `CursorsController`, `MouseTargetFactory`, `ViewController`, and
  `SelectionsOverlay` exist as named transcriptions of their Monaco modules.
- Each ported subsystem matches its captured-from-Monaco oracle, including the
  wrapped-line selection case in Exhibit A.
- No product code imports from `vscode/`.
