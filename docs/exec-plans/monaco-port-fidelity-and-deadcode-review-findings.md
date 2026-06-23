# Monaco Port Fidelity & Dead-Code Review — Findings

Status: in progress — Date: 2026-06-23. Companion to the plan in
`monaco-port-fidelity-and-deadcode-review.md`.

Oracle pin: `vscode` submodule at `294fb350` (2026-06-02, `heads/main`).

Findings are tagged **Faithful** / **Deviation-documented** / **Drift** /
**Dead**. `Drift` = diverges with no recorded decision (actionable);
`Dead` = unreachable after the port.

## Setup & B1 (compiler dead-code pass) — done

- `moon update` then a forced clean `moon check --target js viewer
  --warn-list "+1+2+3+6+7+29+49"` (unused fn/var/type/constructor/field,
  **unused package**, pub-not-in-mbti) → **no warnings**. No within-package
  dead code or unused package dependencies under that set. This only covers
  symbols the compiler can prove unused; it cannot see `pub` symbols dead only
  across packages — hence the B2 pass below.

## Offset-helper thread (A4 + B3) — done

The port's acceptance criterion #1: cursor/selection/hit-test/decoration code
must contain no raw-document-offset round-trips. Status of the `RenderLine`
offset helpers (`source_offset_at_column`, `model_line_start_offset`,
`view_column_at_source_offset`, defined `pub` in
`viewer/view_model/render_frame.mbt:80-136`):

- **Faithful — selection/cursor path is offset-free.** Pointer →
  `input.mbt:171` builds `Position(refined.line_number - 1, refined.column)` (a
  **view position**, not the offset) → `dispatch_mouse` (`view_controller.mbt`)
  → `CursorContext::view_to_model` via the `CoordinatesConverter`. The cursor
  holds the selection in view + model `Position`s; the overlay reads
  `get_view_selection()` (`selection.mbt:8-24`). Exhibit A's fix holds; no
  offset appears anywhere on the selection critical path.

- **Faithful — clipboard copy.** `selection.mbt:121-122,147`
  (`rich_text_to_copy_from_frame` / `append_rich_copy_line_segments`) use the
  offset helpers, but this is the clipboard boundary, which the port's rule #3
  explicitly permits ("raw document offsets appear only at the model/clipboard
  boundary").

- **Drift (borderline) — hit-test eagerly computes a bespoke offset for the
  hover anchor.** `hit_test` (`common/mouse_target.mbt:115,136,145`) and
  `dom_refine_content_target` (`hit_test_dom.mbt:118`) populate
  `MouseTarget.offset` via `RenderLine::source_offset_at_column` on **every**
  hit test. That offset is **not** read by selection — it is consumed only by
  the hover anchor path: `span_anchor_for_target` (`input.mbt:669-687`, uses
  `model_line_start_offset`) → `hover_controller.mbt:91`, plus
  `registry.mbt:18,29` and `hover_participants.mbt:123`. Monaco's `MouseTarget`
  carries a view `Position`/`Range`, and the hover resolves a model position
  through the view model — not a bespoke `RenderLine` offset helper (the helper
  has no Monaco counterpart; the original audit already labels these `Bespoke`).
  This is an offset round-trip on the hit-test path that criterion #1 nominally
  forbids. **Recommendation:** either record it as a deliberate hover-anchor
  boundary exception, or convert the hover anchor through the
  `CoordinatesConverter` like Monaco.

- **Out-of-scope subsystems still using the helpers** (not selection path):
  `content_widgets.mbt:496-499` (`line_col_for_offset` for the hover-copy
  widget) and `view_model_lines_projected.mbt:139` (internal projection). Both
  belong to subsystems the port doc defers (content widgets) or to the view
  model's own internals; flagged for completeness, not as criterion-#1
  violations.

**B3 conclusion:** the offset-helper trio is **not dead** — it is load-bearing
for clipboard, hover anchoring, content widgets, and projection. The plan's
"dead public surface" hypothesis for these helpers is **refuted**.

## B2 (cross-package dead public surface) — cursor package done

Scanned every `pub` symbol in `viewer/cursor/*` for references outside the
package (and outside tests):

- **Dead — `CursorsController::has_selection`** (`cursors_controller.mbt:84-86`).
  No caller anywhere — not in the viewer, the shell, or tests. It wrapped
  `SingleCursorState::has_selection`, which *is* live (`cursors_controller.mbt:85`,
  and the state test). `moon` did not flag it because it is `pub`.
  **Resolved (2026-06-23):** deleted.

- **Over-exposed `pub` (used only within the package, minor):**
  `Cursor::set_view_state` (caller: `cursors_controller.mbt:42`),
  `Cursor::reproject` (caller: `cursors_controller.mbt:27`),
  `SingleCursorState::selection_start_is_empty` (callers within
  `single_cursor_state.mbt`). **Resolved (2026-06-23):** `pub` dropped (the
  cursor package emits no `.mbti`, so this is pure internal hygiene).

Validation: `just check` (0 errors; architecture passes), `moon test --target
js viewer` 16/16. No new warnings — confirms the now-private fns are still used
internally and the deleted method had no callers. The pre-existing `+73`
`unnecessary_annotation` warnings (`input.mbt`, `view_controller.mbt`,
`single_cursor_state_test.mbt`) are unrelated to this change.

## A3 — in-port module fidelity (done; oracle `294fb350`)

Diffed each port-introduced module against its Monaco source.

- **`Selection`** (`view_model/selection.mbt` vs `core/selection.ts`) —
  **Faithful (idiomatic).** Monaco's `Selection extends Range` with four scalar
  fields; the local type composes two `Position`s (`selection_start`,
  `position`) and derives `start`/`end`/`direction` lazily. `getDirection`
  (LTR iff `selection_start == start`), `getPosition`, `getSelectionStart` all
  match. *Minor Drift (module decomposition, rule #1):* the local `Selection`
  also carries clipboard/offset methods (`normalized_range`, `from_offsets`,
  `get_plain_text_to_copy`, `get_rich_text_to_copy`) that Monaco keeps out of
  `core/selection.ts` (clipboard lives in the controller layer); and it lives in
  `viewer/view_model`, not the `viewer/core` the plan named. The offset use is
  at the clipboard boundary (rule #3-OK), but the *placement* of those methods
  on the geometry type diverges. Note: the plan's audit table still labels this
  row "Bespoke" — that reflects the pre-port state and is now stale.

- **`SingleCursorState`** (`cursor/single_cursor_state.mbt` vs
  `cursorCommon.ts`) — **Faithful**, with a **documented** omission.
  `_computeSelection`, `move`/`moved`, and `hasSelection` match Monaco
  line-for-line (`not_before_or_equal` == `!isBeforeOrEqual`, etc.). Monaco's
  `selectionStart: Range` is split into `selection_start_start`/`_end`.
  `leftoverVisibleColumns` / `selectionStartLeftoverVisibleColumns` are omitted
  and the omission is documented at the code site (no readonly-mouse role until
  keyboard nav lands).

- **`SelectionsOverlay` corner enrichment** (`view_overlays.mbt`
  `enrich_visible_ranges_with_style` vs `selections.ts`
  `_enrichVisibleRangesWithStyle`) — **Faithful (line-for-line).** All four
  FLAT/INTERN branch predicates match exactly (`abs(curLeft-prevLeft)<eps` →
  FLAT; `curLeft>prevLeft` → INTERN; the right-edge `prevLeft<curRight<prevRight`
  test; the below-line mirror). Two minor points: `epsilon = space_width/4`
  stands in for Monaco's `typicalHalfwidthCharacterWidth/4` (equivalent in
  monospace), and the **previous-frame corner cache is omitted** — the
  documented Phase 5 deferral, a cross-frame repaint optimization that does not
  change single-frame output (boundary lines stay `Extern`, as in Monaco's
  null-previousFrame path).

- **`ViewModelDecorations`** (`view_model/view_model_decorations.mbt` vs
  `viewModelDecorations.ts`) — **Faithful conversion, documented storage
  deviation.** `to_view_decoration` converts once (offset → model `Position` at
  the boundary → `model_range_to_view_range`), no render-time offset round-trip;
  `columns_on_view_line` is the per-line `linesVisibleRangesForRange` clip.
  Deviation: local converts the **whole flat decoration list eagerly** at
  construction, where Monaco does a **lazy, viewport-scoped, interval-tree-backed,
  cached** `getDecorationsViewportData`. This is the plan's recorded "remaining
  follow-up." *Minor doc gap:* the deviation is tracked in the plan/memory but
  **not noted at the code site** — recommend a one-line pointer in the
  `ViewModelDecorations` doc comment.

- **Typed view events** (`view_events.mbt` / `view_part.mbt` `ViewEventHandler`
  vs `viewEvents.ts` / `viewEventHandler.ts`) — **Subset, deviations
  documented.** The dispatch contract (typed event → each part reports dirtiness
  → accumulate `should_render`) is faithful. The event set is 7 of Monaco's 18
  (composition/focus/theme/language + fine-grained line insert/delete have no
  readonly counterpart), and events are *sourced* by frame-snapshot diffing
  rather than incremental emission — both documented at the code site. *Minor
  staleness:* the header comment predicts a "direct emission path for
  `ViewCursorStateChanged`," but it is still snapshot-derived
  (`view_events.mbt:81-83`).

## A5 — known-deviation documentation check (done)

- **13-variant `MouseTargetType` → 5** — documented at `common/mouse_target.mbt:1-10`
  and `view_controller.mbt:14-19` (omitted `dispatchMouse` branches). ✓
- **Previous-frame corner cache** — documented at `view_overlays.mbt:143-144,258`. ✓
- **Interval-tree decoration storage** — tracked in the plan/memory but **not at
  the code site** (`view_model_decorations.mbt`). ✗ minor gap (see A3 above).

## B4 — unused package imports (done)

The compiler's `unused_package` warning (#29) is clean across `moon check
--target all` — **no unused package dependencies** anywhere in product code.
(This is stronger than the manual `moon.pkg`-vs-`@pkg` scan the plan proposed,
and supersedes it.)

## A2 — coordinate conversion core (done)

`CoordinatesConverter` / `ModelLineProjection` / `ProjectedTextLine`
(`view_model/model_line_projection.mbt`, `injected_text.mbt`,
`view_model_lines_projected.mbt`) vs `coordinatesConverter.ts` /
`viewModelLines.ts` / `modelLineProjectionData.ts`:

- **Interface — Faithful.** The `CoordinatesConverter` trait
  (`model_position_to_view_position`, `view_position_to_model_position`,
  `model_range_to_view_range`, `view_range_to_model_range`) mirrors Monaco's
  `ICoordinatesConverter`; range conversion is the start/end position pair.
- **Inner column mapping — Drift (algorithmic re-derivation, rule #2).**
  Monaco's `ModelLineProjectionData` maps columns with offset arithmetic +
  binary search (`translateToInputOffset` / `translateToOutputPosition` /
  `offsetInInputWithInjectionsToOutputPosition`), parameterized by
  `PositionAffinity`. The local `ProjectedTextLine` instead precomputes
  per-column lookup tables (`model_to_projected_columns`, `model_columns`) and
  does O(1) `.get()`. Same result for the tested cases, different algorithm —
  and **`PositionAffinity` is absent**, so injected-text / wrap-boundary
  affinity (which side of an inlay hint a position resolves to) is not modeled.
  Reduced scope; test-covered by `view_model_test.mbt`. Recommend recording it
  as a deliberate deviation (it is not currently noted as one).

## A6 — coordinate-convention seam (done)

Systemic style divergence from Monaco (not a bug, but a recurring off-by-one
surface and a reading hazard against the oracle):

- **`base/common.Position` is 0-based** (line + UTF-16 column); **Monaco's
  `Position` is 1-based** on both axes. Every Monaco invariant read against the
  port (`minColumn === 1`, etc.) must be mentally shifted.
- **`base/common.Range` is an offset range `[start, end)`**, not a line/column
  pair. It reuses Monaco's type name for a different concept; the line/column
  analog of Monaco's `Range` is `view_line_renderer.ViewRange`, which is
  **1-based**.
- The 0-based `Position` ↔ 1-based `ViewRange` / 1-based `CharacterMapping`
  seams require `±1` conversions (`start.line + 1`, `col1 - 1`). The
  selection-rework notes already record one past bug at exactly this seam, so
  the convention split is a live cost. Not actionable as a fix (the conversions
  are internally consistent), but worth a single coordinate-conventions note in
  `docs/architecture.md` so the 0-based/1-based/offset split is stated once.

## B2 — remaining packages (done)

Scanned every `pub fn` in `viewer/core`, `viewer/model`, and `view` for
references outside the defining package (excluding tests): **no dead exports**.
`CursorsController::has_selection` (now fixed) was the only dead public function
found in the whole review. (Type/field/constructor dead code is already covered
by the clean B1 compiler pass.)

## Status: review complete

All planned workstreams executed. Lowest-risk rows accepted as-is without a
fresh line-by-line diff because they are oracle-gated or known close ports:
`view_line_renderer` (audit: close port), scrollbar/scrollable and hover
(oracle-backed by `tests/reference/monaco-hover-scrollbar/`), view layout
(audit: `Subset`, uniform line height — a documented reduction).

### Actionable items (all non-behavioral / small)

1. **Hover-anchor offset round-trip** on the hit-test path (`Drift`) — decide:
   document as a hover-boundary exception, or route the anchor through the
   `CoordinatesConverter`.
2. **`Selection` clipboard methods** (`normalized_range`, `get_*_to_copy`,
   `from_offsets`) live on the geometry type — Monaco keeps clipboard in the
   controller (module-decomposition `Drift`).
3. **`PositionAffinity` absent** from the projection (reduced scope) — record as
   a deliberate deviation if intended.
4. **Code-site notes for two tracked deviations**: interval-tree decoration
   storage (`view_model_decorations.mbt`) and the eager-flat conversion.
5. **Stale doc lines**: the plan's audit-table "Bespoke (Selection)" row (now
   faithful) and the `view_events.mbt` "direct emission path" comment.
6. **Architecture note**: state the 0-based `Position` / 1-based `ViewRange` /
   offset-`Range` convention split once (A6).

Already fixed in this pass: dead `CursorsController::has_selection` deleted;
three over-exposed `pub` cursor symbols made private.
