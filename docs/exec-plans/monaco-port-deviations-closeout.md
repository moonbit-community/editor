# Closing the Remaining Monaco Port Deviations

Status: **implemented** — Date: 2026-07-03 (proposed and landed the same day;
tracks A–F committed individually in plan order).
Oracle pin: `vscode` submodule at `294fb350` (2026-06-02, `heads/main`).

Landing notes against the combined exit criteria: A, B, C, D, F landed in
full (each track's inventory pasted below before its port code; state
corrections found during inventory are recorded in the pastes). E landed the
anchor rebase and every registry-blocked hover-plan row is terminal
(PORTED or DEFERRED with reason in that plan's ledger); the hover plan's
Phase 4 wrapper/focus-nav cluster remains its own open feature work — it is
not registry-blocked and not a deviation inside a ported unit (see the
Track E phase notes).

## Context

The port has reached the point where every *feature-lack* item is tracked in
its own plan and the render path, coordinate model, decoration system, and
marker pipeline are faithful ports. What remains is a set of **deviations
inside already-ported features**: places where the viewer's implementation of
a ported unit differs from the source in structure, timing, or fidelity, each
individually recorded in a plan's `## Deviations` section or an audit note but
never scheduled for closure. This plan is the schedule.

Deviations closed recently and therefore **not** in this plan:

- `@view_layout.ViewRange` duplicate → deleted, `@base_common.Range` is the
  single line/column range on both axes (`fc09b34`, 2026-07-03).
- `render_whitespace` / `render_control_characters` not plumbed → plumbed via
  `ViewerOptions` (render-whitespace-control-options port).
- Diagnostics fidelity gaps (no Hint severity, no marker tags, no zIndex, no
  `showIfCollapsed`) → closed by the marker-render + decoration-system ports.
- Comments-port fixable deviations (public mouse events, gutter-drag creation,
  `StableEditorScrollState`, ResizeObserver, vendored codicons) → `5fb4f5e`.

This plan follows `_PORT_PLAYBOOK.md`: each track that ports source behavior
starts with an inventory phase whose output is pasted back into this file, and
no track is done until its ledger reconciles against that inventory. Tracks
are ordered smallest/self-contained first; each is independently `just check`
/ `moon test --target all` green at every phase, with `just test-browser` as
the gate wherever DOM or timing changes (the view-axis lesson: unit tests
alone have missed browser-only regressions before).

**Recommended landing order: A → B → C → D → E → F.** A and B are bounded
paper-cut clusters; C is structural with zero behavior change; D is the
architectural enabler; E consumes D; F is the largest pipeline change and
touches everything injected-text, so it goes last.

Related plans this one coordinates with (and does not duplicate):
`monaco-marker-render-port.md` (its Deviations section is Track A's source),
`monaco-hover-logic-chain-port.md` (its Phase 4/5 ledgers are Track E's
denominator), `monaco-decoration-system-port.md` (its injected-text deferral
is Track F).

---

## Track A — Marker render fidelity paper cuts

### The divergences (all recorded in `monaco-marker-render-port.md` Deviations)

1. **Sync marker events, no `_merge`.** `MarkerService.did_change_markers` is a
   plain `@base_common.Emitter[Array[Uri]]` (`marker_service.mbt:245`) firing
   synchronously per `change_one`/`change_all`. Monaco's is a
   `DebounceEmitter` (`markerService.ts`, `MarkerService._onMarkerChanged`)
   with a 0-delay merge that unions the URI sets of all changes in a
   microtask window, so N diagnostic updates in one tick produce one event
   and one decoration pass.
2. **Squiggle `::before` background omitted.** `view_lines/markers.css:14-16`
   documents it: Monaco's `.squiggly-* ::before { background:
   var(--vscode-editor*-background) }` layer is not rendered.
3. **`*-border` theme tokens default to foreground.** Same file (`:5-10`):
   VS Code's `editorError-border`/`editorWarning-border`/`editorInfo-border`
   are `null` outside high-contrast themes; the viewer substitutes the
   foreground color so the border-double underline is always visible. The
   faithful behavior is a squiggly underline from the foreground token with
   the border style reserved for HC.
4. **`showUnused` / `showDeprecated` hardcoded on.** The root class string is
   static (`browser/view/view.mbt:110-116`); Monaco derives both from editor
   options (`codeEditorWidget.ts` `_editorClassName`), gating the
   `squiggly-inline-unnecessary` / `-deprecated` styling.
5. **Resource maps keyed by `uri.to_string()`.** `DoubleResourceMap` and the
   decoration services key by the serialized string rather than a
   `ResourceMap` honoring URI identity/normalization.

### Goal

Close 1–4; decide-and-document 5. After this track the marker plan's
Deviations section shrinks to the two deliberate deferrals (overview-ruler /
minimap paint — Increment H, a missing view part, out of scope here).

### Phases

1. **Inventory** the exact `DebounceEmitter`/`_merge` arithmetic from
   `markerService.ts` (member list + merge semantics) and the
   `_editorClassName` option reads; paste here.

   **Inventory (pasted 2026-07-03):**

   - **Emitter:** `MarkerService._onMarkerChanged = new MicrotaskEmitter<readonly URI[]>({ merge: MarkerService._merge })`
     (`markerService.ts:154-156`). `MicrotaskEmitter<T> extends Emitter<T>`
     (`event.ts:1594-1620`) with members `_queuedEvents: T[]` and
     `_mergeFn?: (input: T[]) => T`. `fire(event)`: if `!hasListeners()`
     return; push onto `_queuedEvents`; when the queue length transitions to
     1, `queueMicrotask(flush)`. Flush: with a merge fn,
     `super.fire(mergeFn(_queuedEvents))` (one merged event); without,
     `super.fire` per queued event (JS `forEach`, so events re-fired during
     the flush are *not* visited); then `_queuedEvents = []` (re-entrant
     fires during flush are dropped — ported as-is).
   - **Merge:** `_merge(all: (readonly URI[])[]): URI[]`
     (`markerService.ts:405-413`): union via `ResourceMap<boolean>.set` +
     `Array.from(set.keys())` — first-seen insertion order, keyed by
     `ResourceMap.defaultToKey = uri.toString()` (`map.ts:50`).
   - **Fire sites:** `changeOne` remove branch (`:185`), insert branch
     (`:198`); `installResourceFilter` install (`:210`) and dispose (`:223`);
     `changeAll` with the merged `changes` array (`:308`).
   - **`_editorClassName`:** not in `codeEditorWidget.ts` at this pin — it is
     the computed option `EditorClassName extends ComputedEditorOption`
     (`editorOptions.ts:1660-1690`): `['monaco-editor']` +
     `extraEditorClassName` (option + env) + `mouse-default`/`mouse-copy` +
     `'showUnused'` when `options.get(EditorOption.showUnused)` +
     `'showDeprecated'` likewise. Both options are `EditorBooleanOption`s
     defaulting `true` (`editorOptions.ts:6645-6653`). The dependent
     `.squiggly-inline-unnecessary { opacity }` rule is emitted by
     `codeEditorWidget.ts`'s `registerThemingParticipant` (`:2556`) under
     `.monaco-editor.showUnused`.
   - **State corrections found during inventory:** divergence 3
     (`*-border` → foreground substitution) was already closed by the marker
     plan's Increment I (runtime inline-SVG squiggle from the foreground
     tokens; the static `border-double` rules are now faithful — inert
     outside HC exactly like Monaco's `editor.css`), so Phase 3 below
     reduces to the `::before` layer. Divergence 5 is narrower than
     recorded: Monaco's own `ResourceMap` default keying *is*
     `uri.toString()`; scheme/authority normalization lives in the
     workbench `uriIdentityService`, which has no viewer counterpart.
2. **Debounced marker events.** Port the merge (union of changed URIs,
   flush on microtask) behind the existing `on_did_change_markers` surface.
   Consumers (`MarkerDecorationsService.handle_marker_change`) are already
   batch-shaped (`take:500`), so this is emitter-internal. Test: N
   `change_one` calls in one tick → one event carrying the URI union.
3. **Faithful squiggle CSS.** Add the `::before` background layer; move the
   border-double form under an HC guard and derive the default-theme
   underline from the foreground tokens, matching `editor.css:81-120`
   line-for-line. Browser spec: squiggle node computed style matches the
   non-HC form.
4. **Option-driven root classes.** `ViewerOptions.show_unused` /
   `show_deprecated` (Monaco defaults `true`), root class rebuilt from
   options; wbtest each off-state drops the class.
5. **URI keying decision.** Either port `ResourceMap`'s keying (normalize
   scheme/authority casing) or record the string keying as a keep-deviation
   with the argument (viewer URIs come from one host, pre-normalized). No
   silent status quo.

### Validation

`just check` + `moon test --target all` per phase; `just test-browser` after
Phase 3 (squiggle DOM changes) — the marker browser coverage lives in the
component suite since the conformance-suite removal.

---

## Track B — `PositionAffinity`

### The divergence

The `PositionAffinity` parameter is absent from the coordinate-conversion
surface. Both sites document it: `injected_text.mbt:97-100` ("Deliberate
deviation (no `PositionAffinity`)") and `model_line_projection.mbt:82`
("Monaco's `translateToOutputPosition` takes a `PositionAffinity`; this does
not"). Consequence: a position at an injected-text boundary (inlay hint) or
at a soft-wrap break always resolves to one fixed side, where Monaco lets the
caller choose (`Left`/`Right`/`None`/`LeftOfInjectedText`/`RightOfInjectedText`).

### Goal

Port the `PositionAffinity` enum (`position.ts`) and thread it through
`CoordinatesConverter::model_position_to_view_position` and the projection's
`translate_to_output_position` path with Monaco's default (`None`), removing
all three "deliberate deviation" doc-comments.

### Why this is bounded

- Affinity only changes behavior at injected-text boundaries and wrap breaks;
  every existing call site keeps the default and is behavior-identical.
- The projection already computes both candidate sides internally (the
  boundary snap in `injected_text.mbt` picks one); the port surfaces the
  choice rather than adding new geometry.

### Phases

1. **Inventory** `translateToOutputPosition` + `normalizePosition` affinity
   branches from `modelLineProjection.ts` / `viewModelLines.ts`; enumerate
   which of the five variants each branch consumes; paste here.

   **Inventory (pasted 2026-07-03):**

   - **Enum:** `PositionAffinity` lives in `model.ts:1455-1480` (not
     `position.ts`): `Left=0, Right=1, None=2, LeftOfInjectedText=3,
     RightOfInjectedText=4`.
   - **`translateToOutputPosition(inputOffset, affinity=None)`**
     (`modelLineProjectionData.ts:111-128`): the injection loop consumes only
     `Right` — at `inputOffset === injectionOffsets[i]` every non-`Right`
     affinity breaks (stays left of all injections anchored there); `Right`
     accumulates every touching injection's length. Then
     `offsetInInputWithInjectionsToOutputPosition` (`:130-167`) consumes only
     `Left` — the binary search treats a break offset as belonging to the
     previous output line (`(midStart, midStop]`) under `Left`, and to the
     next line (`[midStart, midStop)`) otherwise.
     `LeftOfInjectedText`/`RightOfInjectedText` behave as `None` here.
   - **`normalizeOutputPosition(outputLineIndex, outputOffset, affinity)`**
     (`:169-192`): step 1 normalizes around injections
     (`normalizeOffsetInInputWithInjectionsAroundInjections`, `:204-252`,
     consumes all five: `None` honors `cursorStops` — default `Both`, so only
     strictly-inside offsets snap, to the injection start;
     `Right`/`RightOfInjectedText` → after all touching injections at the
     same model offset; `Left`/`LeftOfInjectedText` → before them); when the
     offset changed, the output position is re-derived with the same
     affinity. Step 2 snaps wrap boundaries: `Left` at the line's min output
     offset → previous output line's max; `Right` at max → next line's min.
     `getInjectedTextAtOffset` (`:255-284`) containment is inclusive on both
     ends, first match wins.
   - **Converter surface:** `ICoordinatesConverter` (`coordinatesConverter.
     ts:22-26`): `convertModelPositionToViewPosition(pos, affinity?,
     allowZeroLineNumber?, belowHiddenRanges?)`,
     `convertModelRangeToViewRange(range, affinity?)` (affinity only affects
     empty ranges). Implementations (`viewModelLines.ts`): position
     conversion defaults `None` (`:848`); range conversion defaults **`Left`**
     (`:892-901`) and converts a *non-empty* range with start=`Right`,
     end=`Left` (excludes injected text at the edges).
   - **Non-default consumers with viewer counterparts (Phase 4 targets):**
     `mouseTarget.ts:1096-1112` `doHitTest` → `viewModel.normalizePosition(
     result.position, PositionAffinity.None)` after DOM caret hit-testing
     (viewer: `Viewer::dom_refine_content_target`); `inlineDecorations.ts:
     171-177` whole-line decorations (start `Left`, end `Right`) and
     non-whole-line `convertModelRangeToViewRange(range, Right)` (viewer:
     `inline_decorations.mbt` `get_or_create_view_model_decoration`). Cursor
     move operations (`cursorMoveOperations.ts:79,148,191,220`,
     `oneCursor.ts:88,96`) have no viewer counterpart (no keyboard caret
     movement) — not adopted.
   - **Viewer geometry facts:** `ProjectedTextLine.model_to_projected_columns`
     is first-write-wins, so a boundary model column already resolves left of
     its injections (≡ Monaco non-`Right`), and
     `view_line_index_for_projected_column`'s `column < end_offset` already
     resolves a break offset to the next segment (≡ Monaco non-`Left`) — the
     current fixed behavior is exactly affinity `None`; the port surfaces the
     other sides.
   - **MoonBit constraint:** trait methods accept optional parameters but not
     defaults, so the trait signature is `affinity? : @model.PositionAffinity`
     (absent ⇒ the Monaco default of that member: `None` for positions,
     `Left` for ranges).
2. **Enum + default plumbing.** Add the parameter (optional, default `None`)
   to the converter trait and projection; no caller changes.
3. **Branch port + tests.** Port the affinity branches; wbtest matrix:
   {position at inlay-hint start, at wrap break, mid-token} ×
   {Left, Right, LeftOfInjectedText, RightOfInjectedText}.
4. **Adopt at the consumers that need it.** Monaco passes non-default
   affinity from cursor/hit-testing/reveal paths; adopt only where the
   viewer has the corresponding path (hit-testing at a wrap break), cite
   each adoption to its source line.

### Validation

Headless only through Phase 3; `just test-browser` after Phase 4 (hit-testing
behavior at wrap boundaries can shift by one position).

---

## Track C — Unfold the view-part structure (decorations, currentLineHighlight)

### The divergence

Monaco has one directory per view part (`viewParts/decorations`,
`viewParts/currentLineHighlight`, …). The viewer renders both **inside the
`selections` package**: `view_parts/selections/decorations_overlay.mbt` (the
`.cdr` piece renderer) and `view_parts/selections/current_line_highlight.mbt`
+ their CSS live there, sequenced by the shared `ContentViewOverlays` render
in `browser/view/view_part.mbt`. Behavior is ported; the package structure is
not, which breaks the dir-mirror rule ("viewer/{common,browser,contrib}
mirrors Monaco at directory granularity") and makes the parts' source units
hard to diff-review.

### Goal

`view_parts/decorations` and `view_parts/current_line_highlight` become
sibling packages mirroring Monaco's layout, each owning its `.mbt` + CSS;
`selections` shrinks back to `SelectionsOverlay`. **Zero behavior change** —
DOM piece order inside `.view-overlays` (current-line → selection →
decorations, Monaco `view.ts` overlay registration order) is pinned before
and after.

### Why this is bounded / the known constraint

The `ViewPart` trait impls for the overlay parts already live in
`browser/view/view_part.mbt`, not in the part packages (the recorded cycle
workaround — see the selections `README.md` and the foreign-method rule:
methods on a type must live in its package, so the *shared shell* stays in
`browser/view`). The move relocates the piece-computation + DOM-write
functions and CSS only; the shell keeps orchestrating. If the extraction
would require re-exporting types across three packages just to preserve the
shell, stop and record why (the avoid-facade-ceremony rule) — the goal is
mirror fidelity, not ceremony.

### Phases

1. Move `decorations_overlay.mbt` (+ wbtest, `decorations.css`) to
   `view_parts/decorations`; update `browser/view` imports and the
   `scripts/build-web.mbtx` css_sources list.
2. Same for `current_line_highlight.mbt` (+ css).
3. Regenerate `.mbti`; `just test-browser` full — the overlay DOM shape and
   order must be byte-identical (assert via the existing selection-geometry
   and decoration component specs).

---

## Track D — Editor contribution & command registry (the enabler)

### The divergence

Monaco instantiates editor features through a registry:
`registerEditorContribution` / `EditorContributionRegistry` collects
contribution ctors, `CodeEditorWidget` instantiates them per editor, and
`EditorCommand` / `registerEditorCommand` + `KeybindingsRegistry` bind
commands/keys by id (`editorExtensions.ts`). The viewer hardwires every
feature: hover, folding, comments, zones are wired by hand-written root glue
(`viewer/comments_host.mbt`, `controller_host.mbt`, `view_zones_host.mbt`,
`folding_controls.mbt`, subscriptions in `viewer.mbt`), and key dispatch is
inline (the hover scroll cluster dispatches from `handle_hover_keydown`
directly — hover plan Deviation 4/13 lineage). This is the recorded
"controller-contribution-registry inversion" blocking hover Phase 5's real
actions (`hoverActionIds`, `showContentHover`/`hideHover`,
`ShowOrFocusHoverAction`).

### Goal

A minimal faithful registry: contribution registration (id + ctor closure +
instantiation at `Viewer` construction, dispose on `set_model`/dispose) and a
command registry (id → run closure + keybinding table consulted by the
viewer's keyboard owner). Enough that a feature registers itself and hover's
Phase 5 command rows become portable — not a full DI/services port.

### The MoonBit constraint (scope honestly)

The foreign-method rule means `Viewer::` glue cannot leave the root package,
and there is no service collection / decorator DI to port 1:1. The registry
therefore inverts **dispatch and lifecycle** (who instantiates, who routes
commands/keys), not **file placement** — the `*_host.mbt` files become
contribution ctors registered with the registry instead of ad-hoc wiring, but
they stay in the root package. Record this as the track's structural
deviation up front.

### Phases

1. **Inventory** `editorExtensions.ts`'s registration surface (the
   `EditorContributionInstantiation` modes included — `Eager`/`BeforeFirstInteraction`/
   `AfterFirstRender`/`Lazy`) and which modes the viewer's four features
   actually need; paste here. Expect most to be `Eager`; defer the lazy modes
   with a reason if nothing consumes them.

   **Inventory (pasted 2026-07-03):**

   - **Registration surface:** `registerEditorContribution(id, ctor,
     instantiation)` → `EditorContributionRegistry.INSTANCE`
     (`editorExtensions.ts:552-554`, class `:592+`);
     `registerEditorCommand` (`:528-531`). `Command` (`:104-183`): id,
     precondition, kbOpts; `register()` writes
     `KeybindingsRegistry.registerKeybindingRule` rows with `when = kbExpr
     AND precondition` plus a `CommandsRegistry` handler. `EditorCommand`
     (`:270+`): `runEditorCommand(accessor, editor, args)`;
     `bindToContribution` binds a command to a contribution via a
     controller getter. `CodeEditorWidget` instantiates the registered
     contributions per editor (`codeEditorWidget.ts:344`
     `this._contributions.initialize(...)`,
     `codeEditorContributions.ts`) and disposes them with the editor —
     `setModel` does **not** re-create contributions (this plan's phase
     text saying "dispose on `set_model`" was wrong; the port follows the
     source: dispose with the editor only).
   - **Instantiation modes** (`:34-65`): `Eager`, `AfterFirstRender`,
     `BeforeFirstInteraction`, `Eventually`, `Lazy`. The features at this
     pin: folding `Eager` (`folding.ts:1246` — "uses saveViewState"),
     content hover `BeforeFirstInteraction` (`hoverContribution.ts:22`),
     comments `AfterFirstRender`
     (`commentsEditorContribution.ts:34`). The viewer has no idle
     scheduler, interaction tracker, or on-demand `getContribution`, so
     every mode instantiates eagerly (documented on the enum); the
     deferred modes exist only so registrations can carry the source's
     declared mode.
   - **Scope correction — view zones are not a contribution.** Monaco's
     view zones are `ICodeEditor.changeViewZones` editor API
     (`codeEditorWidget.ts`), not a `registerEditorContribution` feature;
     the viewer's `view_zones_host.mbt` is the faithful placement already.
     The registry therefore carries the three real contributions (hover,
     folding, comments); zones stay editor API.
   - **Command consumers to re-land (Phase 3):** the hover scroll cluster
     (`hoverActions.ts`): `editor.action.scrollUpHover` (ArrowUp),
     `scrollDownHover` (ArrowDown), `scrollLeftHover`/`scrollRightHover`
     (Arrow Left/Right), `pageUpHover` (PageUp, secondary Alt+ArrowUp),
     `pageDownHover` (PageDown, secondary Alt+ArrowDown), `goToTopHover`
     (Home, secondary CtrlCmd+ArrowUp), `goToBottomHover` (End, secondary
     CtrlCmd+ArrowDown) — all preconditioned on
     `EditorContextKeys.hoverFocused` — and `editor.action.hideHover`
     (Escape, `hoverVisible`). Ids from `hoverActionIds.ts`.
   - **Structural deviation (up front):** the foreign-method rule keeps
     `Viewer::` glue in the root package and there is no DI/services
     collection, so the registry inverts dispatch + lifecycle only; the
     `*_host.mbt` files stay in the root package as the registered ctors,
     and preconditions are live predicates over the `Viewer` instead of
     `ContextKeyExpression`s.
2. **Contribution registry.** Ctor closures keyed by id; `Viewer` constructor
   iterates the registry; hover/folding/comments/zones registered through it;
   the hand-wiring order is preserved (registration order = today's
   construction order).
3. **Command + keybinding registry.** `EditorCommand` port (id, precondition
   closure, run); the keyboard owner consults the keybinding table before its
   built-ins; hover's inline scroll-cluster dispatch re-lands as registered
   commands with Monaco's ids (closing hover-plan Deviation 13's registry
   caveat).
4. **Exit check.** No feature is wired outside the registry; `just
   test-browser` full (hover keyboard specs prove the re-dispatch).

---

## Track E — Hover closeout (anchor space + registry-dependent rows)

### The divergences

1. **Offset-anchored internals.** `HoverAnchor` is
   `{ start, end, offset, injected_text_index, line : Int }` in document
   offsets (`contrib/hover/hover_controller.mbt:35-43`); Monaco's
   `HoverRangeAnchor` carries a `Range`. Recorded as a pre-existing deviation
   during the range migration (stage 3b-i) and left in place; the boundaries
   convert via `TextSnapshot::range_of`/`offset_range_of`. Every new hover row
   ported since has had to convert at its edges.
2. **The open `monaco-hover-logic-chain-port.md` ledger rows** that were
   blocked on Track D or deferred to their consumer: Phase 4 wrapper fan-out
   (`shows_or_will_show`, `find_anchor_candidates`, `_getHoverContext`),
   focus-index navigation, `hoverHighlight` decoration option row, Phase 5
   real status-bar actions + `hoverActionIds`/`hoverContribution` command
   registration, `setMinimumDimensions` (sash consumer).

### Goal

Rebase `HoverAnchor`/`HoverPart` spans to `Range` (deleting the two boundary
converters), then burn down the blocked hover-plan rows using Track D's
registry. **This track's denominator is the hover plan's own ledgers** — work
is recorded there; this plan only sequences it and owns the anchor-space
migration (which the hover plan classified out of its scope).

### Why the anchor rebase is bounded

The offset⇄Range conversion already exists at exactly two seams
(`MarkerHoverParticipant`, the `hoverHighlight` decoration); moving the
conversion outward to the pixel-placement site (the one true offset consumer:
content-widget x-positioning) inverts a small, known set. The reconciliation
wbtests (`hover_reconciliation_wbtest.mbt`) pin the compat semantics
(`same model line` adoption) and survive re-typing since they already reason
in lines.

### Phases

1. Inventory the offset-typed hover surface (`HoverPart.range : OffsetRange`,
   anchor construction in the input seam, geometry consumers); paste here.

   **Inventory (pasted 2026-07-03):**

   - **Offset-typed surface (before):** `HoverAnchor { start, end, offset,
     injected_text_index, line }` (`hover_controller.mbt:35-43`),
     `HoverView.range`/`ComputedHover.range`/`HoverPart` variant ranges
     (`OffsetRange`), `HoverComputeContext.anchor_range`+`offset`,
     `EditorContext.view_to_model_offset`+`offset_to_model_line`,
     `HoverWidgetView.anchor_offset`, `token_anchor_for_target → (Int, Int,
     Int)`, and the root's `view_position_to_model_offset` /
     `offset_to_model_line` helpers. `hover_widget_geometry.mbt` already
     reasoned in `Range`/`Position`.
   - **The two boundary converters deleted:** `MarkerHoverParticipant`
     (`snapshot.range_of(anchor)` on the way in,
     `snapshot.offset_range_of(marker range)` on the way out) and the
     markdown participant's `offset_range_of(hover.range)`; the
     `hoverHighlight` decoration's `snapshot.range_of(hover.range)`.
   - **The one offset consumer kept:** content-widget pixel placement
     (`content_widgets.mbt` `line_col_for_offset`), now fed through the new
     `ViewContext.model_position_to_offset` closure (the model-snapshot
     boundary) — offsets no longer exist anywhere else in the hover chain.
   - **Provider-query correction found while rebasing:** Monaco queries
     hover providers at `anchor.range.getStartPosition()`, but Monaco's
     anchor range is the *mouse position*; the viewer's anchor is the
     hovered token's span (recorded deviation), so the query keeps the
     span's midpoint as the pointer stand-in (the offset-anchored code's
     `(start+end)/2`) — querying the span start regressed the wrapped-hover
     browser spec (a string token's start is outside the provider's word
     range).
   - **`isValidForHoverAnchor`** now transcribes the source's column-only
     comparison (markdown/marker participants) instead of offset
     containment.
2. Rebase types to `Range`; keep pixel placement converting at its boundary;
   hover browser suite green (`hover_rendering.spec.js` + scrollbar specs).
   **DONE (2026-07-03)** — the browser hover coverage now lives in
   `viewer_api.spec.js` + the smoke hover spec (the standalone hover specs
   left with the conformance suite); both green.
3. Land the Track-D-unblocked Phase 5 rows (commands, real status bar) — 
   update the hover plan's ledger statuses, not this file.
   **DONE (2026-07-03)** — the scroll cluster, `hideHover`, and the
   `hoverActionIds` ids are PORTED (Track D); the status-bar `run` dispatch
   is terminal-DEFERRED in the hover ledger (its targets are the
   gotoError/codeAction contribs, out of scope below);
   `ShowOrFocusHoverAction` is terminal-DEFERRED (multi-chord keybinding +
   Phase 4 focus cluster).
4. Land the remaining Phase 4 wrapper/focus-nav rows per the hover plan.
   Phases 6 (verbosity) and 7 (glyph hover) remain feature work tracked
   there, not deviations — out of scope here.
   **Status (2026-07-03):** the `hoverHighlight` decoration row is PORTED
   (`Range`-native since the anchor rebase). The wrapper fan-out /
   focus-nav cluster (`shows_or_will_show`, `find_anchor_candidates`,
   `_getHoverContext`, `focus*`) is *not registry-blocked* — it is the
   hover plan's own Phase 4 structural feature work and stays open there
   (every row carries an explicit status); nothing in it is a deviation
   inside a ported unit, which is this plan's scope.

---

## Track F — Injected text into decoration storage

### The divergence

Monaco models injected text (inlay hints' rendering vehicle) as **decoration
options** (`ModelDecorationOptions.before/after` → `injectedTextOptions`)
stored in the interval tree; the view model derives per-line injected text
from decorations (`viewModelLines` `getInjectedTextAt` /
`onDecorationsChanged`). The viewer runs a **parallel path**: inlay hints are
converted by `injected_text_from_inlay_hints` and threaded through dedicated
`ViewModel` constructors (`view_model.mbt:538,571`,
`with_injected_text` / `with_options_folding_and_inlay_hints`), bypassing the
decoration store entirely. This was the decoration-system plan's one
explicitly deferred storage item ("injected-text-in-storage").

### Goal

Injected text lives in `DecorationsTrees` like every other decoration: inlay
hints become `delta_decorations` calls with `after` injected-text options; the
projection reads injected text from the model's decorations; the dedicated
constructors and the `Array[InjectedText]` plumbing are deleted. This closes
the last split-brain between the decoration store and the render pipeline.

### Why last

It touches the `ViewModel` construction surface (four ctors), the projection
(`bucket_injected_text`, `model_line_projection`), the inlay-hint provider
glue, and invalidation (injected-text changes must flow through
`ViewDecorationsChanged` + a lines-changed signal, Monaco
`onDidChangeDecorations` → `handleModelDecorationsChanged`). Tracks A–E do
not depend on it; anything that lands before it shrinks its diff.

### Phases

1. **Inventory** `textModel`'s injected-text decoration handling +
   `viewModelLines.ts` `getInjectedTextAt`/`createLineBreaksComputer` seams
   (which events re-run the line-breaks computer); paste here.

   **Inventory (pasted 2026-07-03):**

   - **Storage:** `isNodeInjectedText` over `isOptionsInjectedText`
     (`!!options.after || !!options.before`) routes nodes into
     `_injectedTextDecorationsTree`; `getInjectedTextInInterval` /
     `getAllInjectedText` filter `showIfCollapsed || !range.isEmpty()`.
     `LineInjectedText.fromDecorations` (`textModelEvents.ts`): `before` at
     the range start (order 0), `after` at the range end (order 1), sorted
     by line, column, order.
   - **Invalidation:** Monaco collects affected lines per changed
     injected-text decoration (`recordLineAffectedByInjectedText` inside
     `handleBeforeFireDecorationsChangedEvent`) and fires
     `onDidChangeContentOrInjectedText`, which re-runs the line-breaks
     computer for exactly those lines. **Viewer deviation (recorded on the
     emitter and event):** a single `affects_injected_text` flag on
     `ModelDecorationsChangedEvent`; the viewer's subscription rebuilds the
     whole projection (the granularity it already uses for wrap-width
     changes). The plan's "re-renders the affected lines only" wbtest
     became add/remove/move correctness tests
     (`inlay_hints_host_wbtest.mbt`) plus this documented granularity
     deviation.
   - **Producer:** `inlayHintsController.ts` `_updateHintsDecorators`
     writes `{ range: fromPositions(position), options: { showIfCollapsed:
     true, after: { content, inlineClassName, attachedData } } }` — ported
     as `inlay_hints_host.mbt` (`attachedData` reduced to the hint's
     source index, which the projection threads into hit-testing/hover
     lookup). The raw `Array[InlayHint]` stays on the `Viewer` for hover
     tooltips only.
   - **Deleted (same commit, no dual pipeline):**
     `ViewModel::with_options_and_inlay_hints`,
     `with_options_folding_and_inlay_hints`,
     `ViewModelLinesFromModelAsIs::with_injected_text`,
     `with_folding_model_and_injected_text`,
     `injected_text_from_inlay_hints`, `InjectedText::from_inlay_hint`,
     and the hint-based `bucket_injected_text`.
2. **Storage.** `Decoration` gains the `after`/`before` injected-text options
   subset; `DecorationsTrees` queries expose injected text per line range
   (Monaco `getInjectedTextInInterval`).
3. **Producer swap.** Inlay-hint glue writes decorations; the parallel
   `Array[InjectedText]` path is deleted the same commit (no dual pipeline —
   the no-backcompat rule).
4. **Invalidation.** Injected-text decoration deltas trigger the projection
   rebuild exactly where content changes do today; wbtest: hint add/remove/move
   re-renders the affected lines only.
5. **Gate.** Full `just test-browser` — the inlay-hint scenario, whitespace
   fragmentation around injected text, and folding × hints interactions are
   the risk surface.

---

## Deviations that stay (documented keeps — re-affirmed by this plan)

| Deviation | Where recorded | Why it stays |
|---|---|---|
| `OffsetRange` ctor normalizes instead of throwing `BugIndicatingError` | `base/common/text.mbt:118-125` doc | readonly viewer avoids panics; swap is a no-op for valid input |
| Marker stores keyed by `uri.to_string()` (Track A item 5 — decided KEEP) | marker plan Deviations | identical to `ResourceMap.defaultToKey` (`map.ts:50`); normalization is the workbench `uriIdentityService`'s custom `toKey`, unused by `markerService.ts` |
| `MicrotaskEmitter` scheduler injected, inline default (Track A) | marker plan Deviations | Monaco hardcodes `queueMicrotask`; `base/common` also compiles native — the js host injects the real microtask |
| `renderValidationDecorations` defaults `On` (Monaco: `editable`) | decoration plan Deviations | the viewer is always readonly; Monaco's default would hide all squiggles |
| Single cursor; no `setSelections` multi-cursor | read-API plan Deviations | deliberate product scope |
| Uniform line height; reduced `EditorLayoutInfo`; no EOL/BOM getters | read-API plan Deviations | single-font readonly viewer; EOL/BOM belong to `ITextModel`, not the `IEditor` subset |
| Closure seams where Monaco uses inheritance (ZoneWidget host, hover participant DI) | comments + hover plans | MoonBit has no subclassing; seams are the recorded pattern |
| `CommentService` in `viewer/common/comments` (Monaco: workbench contrib) | comments plan | check-architecture forbids host imports of `contrib/**` |
| View-addressed zone anchors; folding markers in the number band; zone arrow as a div; no replies/resolve/reactions | comments plan | repo-wide seam / user-approved scope cuts |
| `ViewZone.anchor_line` clamps `[0, line_count]` | arch-divergence-closeout Track A | numerically Monaco's `afterLineNumber`; the "fix" would clip above-first-line zones |
| Sync tokenization (no `RangePriorityQueueImpl` background retokenization); per-token embedded language ids unplumbed | arch-divergence-closeout | explicitly deferred by request, conformance-only |

## Explicitly out of scope (missing features, tracked elsewhere)

Overview-ruler/minimap painting (marker plan Increment H); indentGuides
overlay (would finally wire the dormant
`common/model/guides_text_model_part.mbt`, which stays quarantined-with-tests
until then); scrollDecoration, glyphMargin, marginDecorations, rulers,
blockDecorations view parts; find widget, wordHighlighter, bracketMatching,
links, gotoError, smartSelect, stickyScroll, unicodeHighlighter contribs;
hover Phases 6–7; hover sashes/resize.

## Combined exit criteria

- **A:** marker plan Deviations reduced to Increment H; marker events merge;
  squiggle CSS faithful incl. HC split; `showUnused`/`showDeprecated` are
  options; URI keying decided and documented.
- **B:** `PositionAffinity` exists with Monaco's variants and defaults; the
  three "deliberate deviation" comments are gone; boundary matrix tested.
- **C:** `view_parts/{decorations,current_line_highlight}` exist as packages;
  `selections` contains only `SelectionsOverlay`; overlay DOM byte-identical.
- **D:** all four features instantiate through the contribution registry;
  commands/keybindings route through the command registry; the
  file-placement deviation is documented.
- **E:** `HoverAnchor` is `Range`-based with pixel conversion at one boundary;
  every hover-plan row blocked on the registry is terminal (`PASS` or
  `DEFERRED` with reason) in that plan's ledger.
- **F:** injected text is decoration storage; the parallel inlay-hint
  constructors and `Array[InjectedText]` plumbing are deleted; full browser
  suite green.
- Each track's inventory pasted into this file before its port code; every
  new non-source-cited line appears in a Deviations note (playbook Phase 3).

## Addendum (2026-07-03): `CommentService` re-homed — one "stays" row superseded

`docs/exec-plans/viewer-import-rule-monaco-alignment.md` aligned the
external-consumer import rule with VS Code's workbench rules (three consumer
classes; `internal/shell/**` and `tests/**` may now import
`viewer/contrib/**` directly) and moved `CommentService` — with its
thread-changed and mutation events — from `viewer/common/comments` to
`viewer/contrib/comments`. The thread/comment types stay in
`viewer/common/comments` (Monaco's `editor/common/languages.ts` filing).

This supersedes the "Deviations that stay" row *"`CommentService` in
`viewer/common/comments` (Monaco: workbench contrib)"*: its justification
("check-architecture forbids host imports of `contrib/**`") no longer holds.
The residual deviation is re-justified — the service sits in
`viewer/contrib/comments` rather than shell-side because comments ship as a
reusable viewer feature (product scope, user decision of 2026-07-03), not
because the import rule forces it; within the tree we own, the filing now
mirrors Monaco's feature-owns-its-service shape.
