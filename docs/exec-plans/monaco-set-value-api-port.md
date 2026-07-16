# Monaco `setValue` (Flush Lane) 1:1 Port

Status: implemented — Date: 2026-07-10 (inventory, ledger, deviations, and
exit gate appended at the bottom).
Oracle: checked-in `vscode` submodule.

Oracle:
- `src/vs/editor/common/model/textModel.ts` (`setValue` → `_setValueFromTextBuffer`,
  `_emitContentChangedEvent`, `registerViewModel`/`unregisterViewModel`,
  `_onDidChangeContentOrInjectedText`, `DidChangeContentEmitter`, version ids,
  `equalsTextBuffer`).
- `src/vs/editor/common/textModelEvents.ts` (`ModelRawFlush`,
  `ModelRawContentChangedEvent`, `InternalModelContentChangeEvent`,
  `IModelContentChangedEvent`).
- `src/vs/editor/common/viewModel/viewModelImpl.ts` (the `Flush` branch of
  `onDidChangeContentOrInjectedText`, `emitContentChangeEvent`).
- `src/vs/editor/common/cursor/cursor.ts` (`onModelContentChanged` flush branch).
- `src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts:487` (`setValue`),
  plus `onDidChangeModelContent` re-fire.
- `src/vs/editor/common/services/modelService.ts:365-438` (`updateModel`,
  `equalsTextBuffer` early return) — **host-side precedent only**, see scope cuts.

Product code must not import from `vscode/` or `codemirror/`; the target is to
port behavior, constants, and state transitions into locally owned MoonBit.

## Problem

The viewer is user-readonly, but hosts must refresh content when the file
changes on disk. Today the only way is a full model swap: build a new
`TextModel` and call `Viewer::set_model` (`viewer/viewer.mbt:500`), which
detaches and rebuilds the entire `ModelData` — new `ViewModel`, new browser
`View` DOM subtree, full re-tokenize — and resets scroll position, folding
collapse state, and selection (`model_swap` browser scenario exercises exactly
this).

Monaco's own answer for whole-content replacement is `TextModel.setValue`: a
**Flush** — swap the buffer in place, destroy all decorations, bump the
version, and let the attached view models re-project. The same `TextModel`,
`ViewModel`, and `View` instances survive; scroll clamps instead of resetting;
feature contribs re-derive their state from content-change events. This plan
ports that flush lane and nothing more.

Context: VS Code's disk-refresh path (`ModelService.updateModel`,
`modelService.ts:365`) actually converts new content into a minimal
common-prefix/suffix **edit** so downstream stays incremental. That requires
the mutable-edit pipeline (`pushEditOperations`, raw line-level events,
interval-tree `acceptReplace`) and is deliberately **out of scope** here
(recorded below as the tier-2 follow-up); the flush lane is Monaco's `setValue`
semantics, verbatim.

## What already exists (reuse, do not rebuild)

| Need | Viewer piece | Location |
|---|---|---|
| Whole-document reprojection | `ViewModelLinesFromProjectedModel::on_model_flushed` | `viewer/common/view_model/view_model_lines_projected.mbt` |
| Flush entry on the view model | `ViewModel::on_did_change_content_or_injected_text` (injected-text form) | `viewer/common/view_model/view_model.mbt:141` |
| Viewport-cache invalidation | `ViewModelDecorations::reset` | `viewer/common/view_model/view_model_decorations.mbt` |
| Layout flush | `LinesLayout::on_flushed(line_count)` | `viewer/common/view_layout/lines_layout.mbt:271` |
| Token memo reset + change event | `TokenizationTextModelPart::reset_tokenization` (fires `did_change_tokens`) | `viewer/common/model/tokens/tokenization_text_model_part.mbt:150` |
| Token event → repaint chain | `Viewer::retokenize_current_model` subscription | `viewer/attach_model.mbt:51` |
| Fresh cursor collection | `CursorsController::new(context)` | `viewer/common/cursor/cursors_controller.mbt:14` |
| Deferred-emit emitter template | `DidChangeDecorationsEmitter` (begin/end deferred, merge) | `viewer/common/model/text_model_decorations.mbt:76` |
| "Repaint everything" view event | frame-diff `content_generation` → `ViewLinesChanged` | `viewer/browser/view/view_events.mbt:76` |
| Render scheduling | `Viewer::schedule_render` → rAF `flush_render` | `viewer/view_host.mbt:66,182` |
| Browser-test template | `model_swap` scenario | `tests/browser/moonbit/model_swap/` |

## Reference pipeline (grounded)

| Monaco file:line | Role |
|---|---|
| `textModel.ts:484-493` `setValue` | Validate, build buffer, delegate |
| `textModel.ts:514-545` `_setValueFromTextBuffer` | Swap buffer, `_increaseVersionId`, destroy all decorations (`:526-528`), clear undo stack (`:531`), emit `[ModelRawFlush]` + full-range `IModelContentChangedEvent` (`isFlush: true`) |
| `textModel.ts:495-512` `_createContentChanged2` | Public event payload shape (changes/eol/versionId/isFlush) |
| `textModel.ts:467-482` `_emitContentChangedEvent` | Order: tokenization part `handleDidChangeContent` (`:472`) → bracket pairs → font decorations → direct view-model calls (`:480`) → `_eventEmitter.fire` (`:481`) |
| `textModel.ts:262,370,739,782-784` | `_versionId` storage, init 1, getter, increment |
| `textModel.ts:303,449-455` | `_viewModels: Set<IViewModel>`, `registerViewModel`/`unregisterViewModel` |
| `textModel.ts:1652-1667` `_onDidChangeContentOrInjectedText` | **Two loops, order is load-bearing**: all view models do structural updates first, then all emit outgoing events + cursor updates |
| `textModel.ts:2698` `DidChangeContentEmitter` | Deferred emitter with fast/slow merge |
| `textModel.ts:245-247` `onDidChangeContent` | Public subscription unwraps `.contentChangedEvent` |
| `textModel.ts:457-459` `equalsTextBuffer` | Buffer equality for the host-side no-op early return (`modelService.ts:370-373`) |
| `viewModelImpl.ts:356-363` | Flush branch: `_lines.onModelFlushed()` + `ViewFlushedEvent` + `_decorations.reset()` + `viewLayout.onFlushed(lineCount)` |
| `viewModelImpl.ts:412-428` | `acceptVersionId`, `viewLayout.onHeightMaybeChanged()` |
| `viewModelImpl.ts:441-453` | `_viewportStart` invalidate + recovery — gated on `getAttachedEditorCount() >= 2` |
| `viewModelImpl.ts:462-469` `emitContentChangeEvent` | Second-loop: outgoing `ModelContentChangedEvent` + `_cursor.onModelContentChanged` |
| `viewModelImpl.ts:169,180` | View model registers/unregisters itself with the model |
| `cursor.ts:226-256` `onModelContentChanged` | Flush branch: dispose cursors, `new CursorCollection(context)` — cursor resets to origin |
| `codeEditorWidget.ts:487` `setValue` | Public widget API delegates to `model.setValue` |

## Scope cuts (deliberate omissions — record in code comments)

1. **Undo stack.** `_commandManager.clear()` (`textModel.ts:531`) has no
   counterpart; the viewer has no edit stack. N-A.
2. **`setEOL` / EOL-change lane** (`textModel.ts:547+`). Out of scope; the
   snapshot carries its own line breaks.
3. **`_viewportStart` tracked-range viewport recovery**
   (`viewModelImpl.ts:441-453`). Monaco only runs it with ≥ 2 attached editors;
   the viewer is single-editor. Scroll clamps via `LinesLayout`/`Scrollable`
   like Monaco's single-editor case.
4. **`bracketPairs.handleDidChangeContent` / `fontTokenDecorationsProvider`**
   (`textModel.ts:473-474`) — parts not ported. N-A.
5. **Tier 2 (incremental lane).** `ModelService.updateModel`-style minimal
   edits, `ModelRawLinesInserted/Deleted/LineChanged`, the two-pass
   line-breaks handler (`viewModelImpl.ts:319-438`), interval-tree
   `acceptReplace`. Not in this plan. Trigger to revisit: high-frequency
   updates on large files (streaming agent writes / log tailing), or
   decoration flicker across refreshes becomes user-visible. The event
   **types** ported in Track A keep Monaco's full raw-change shape so tier 2
   slots in without reshaping.

## Ownership boundary

- `set_value`, version ids, events, and the registered-view-model set live in
  `viewer/common/model` (Monaco: `textModel.ts`).
- The register seam needs a trait declared in the **model** package (MoonBit
  no-cycle rule; same precedent as `CoordinatesConverter` in
  `viewer/common/core`, see `coordinates_converter.mbt:9-13`). The trait
  carries exactly the two methods Monaco calls on `IViewModel`:
  `on_did_change_content_or_injected_text` and `emit_content_change_event`.
  `ViewModel` implements it in `viewer/common/view_model`.
- Public API stays a strict `ICodeEditor` subset per
  `docs/exec-plans/monaco-model-viewer-api.md` policy: `Viewer::set_value`
  (`codeEditorWidget.ts:487`) and `Viewer::on_did_change_model_content`
  (ICodeEditor `onDidChangeModelContent`) are both on the interface.

---

## Track A — TextModel: `set_value` + events

Target: `viewer/common/model/text_model.mbt`, new `text_model_events.mbt` (or
extend `decorations.mbt`'s event file layout), `text_snapshot.mbt`.

1. Add `mut version_id : Int` (init 1), `get_version_id`,
   `increase_version_id` (`textModel.ts:262,370,739,782-784`).
2. Port event types from `textModelEvents.ts`: `RawContentChangedType`,
   `ModelRawFlush` (`:233`), `ModelRawContentChangedEvent` (`:457`, incl.
   `contains_event` `:483`), `InternalModelContentChangeEvent` (`:562`), and
   the public `ModelContentChangedEvent` payload (`_createContentChanged2`
   shape, `textModel.ts:495-512`). Keep the full raw-change union shape even
   though only `Flush` is constructed — tier-2 slots in later.
3. Port `DidChangeContentEmitter` (`textModel.ts:2698`) on the
   `DidChangeDecorationsEmitter` pattern; public `on_did_change_content`
   unwraps the internal event (`:245-247`).
4. Make `snapshot`, `decorations`, `decorations_tree` mutable
   (`text_model.mbt:11,22,23`). Port `set_value` → `_set_value_from_snapshot`
   (`:484-493`, `:514-545`): capture old full range/length → swap snapshot →
   `increase_version_id` → fresh decorations `Map` + fresh `DecorationsTrees`
   (`:526-528`) → `_emit_content_changed_event`.
5. Port `_emit_content_changed_event` (`:467-482`) preserving call order:
   tokenization part first, then registered view models, then the public
   emitter.
6. `TokenizationTextModelPart::handle_did_change_content` (Monaco `:472`
   callee): on `is_flush`, replace the frozen `priv lines` array with the new
   snapshot's lines and call `reset_tokenization()` — which already fires
   `did_change_tokens` and feeds the existing
   `retokenize_current_model` chain (`attach_model.mbt:51`).
7. `TextSnapshot::equals` (`textModel.ts:457-459` → buffer `equals`); the
   no-op early return belongs to the **caller** (host), per
   `modelService.ts:370-373`.

## Track B — Register seam: model calls view models directly

Target: `viewer/common/model` (trait + set), `viewer/common/view_model`.

1. Declare the trait (name it after Monaco's `IViewModel` per naming policy)
   in the model package; `TextModel` keeps
   `view_models : Array[&Trait]` with `register_view_model` /
   `unregister_view_model` (`textModel.ts:303,449-455`).
2. Port `_onDidChangeContentOrInjectedText` (`:1652-1667`) with the two-loop
   order intact: loop 1 `on_did_change_content_or_injected_text` (structure),
   loop 2 `emit_content_change_event` (cursor + outgoing).
3. `ViewModel::with_options` registers itself (`viewModelImpl.ts:169`); add
   `ViewModel::dispose` to unregister (`:180`), called from
   `ModelData::dispose` (`viewer/viewer.mbt:144`).
4. The existing injected-text routing through the decorations listener
   (`attach_model.mbt:33-36`) is superseded by this seam for content; leave
   the decorations lane itself untouched.

## Track C — ViewModel + cursor flush handling

Target: `viewer/common/view_model/view_model.mbt`,
`viewer/common/cursor/cursors_controller.mbt`,
`viewer/common/view_layout`.

1. Extend `on_did_change_content_or_injected_text` (`view_model.mbt:141-152`)
   to the Monaco flush sequence (`viewModelImpl.ts:356-363,412-428`):
   `lines.on_model_flushed()` (exists) → `decorations.reset()` (exists) →
   **add** `view_layout.on_flushed(get_view_line_count())` (plumb through
   `ViewLayout` to `LinesLayout::on_flushed`, `lines_layout.mbt:271`) →
   `on_height_maybe_changed`.
2. `CursorsController::on_model_content_changed` (`cursor.ts:226-256`): flush
   → rebuild the cursor collection from `context` — selection resets to
   origin, exactly Monaco. Called from `ViewModel::emit_content_change_event`
   (`viewModelImpl.ts:462-469`).
3. The frame-diff `View` needs **no change**: the `content_generation` bump
   (Track D) produces `ViewLinesChanged`, whose port semantics are already
   "line content/tokens regenerated document-wide" — Monaco's
   `ViewFlushedEvent` scale.

## Track D — Viewer public API + wiring

Target: `viewer/viewer.mbt`, `viewer/attach_model.mbt`,
`viewer/editor_events.mbt`.

1. `pub fn Viewer::set_value(value : String)` → delegate to
   `model_data.model.set_value` (`codeEditorWidget.ts:487`).
2. `pub fn Viewer::on_did_change_model_content` — re-fire from the model's
   public content event, following the existing `editor_events.mbt` pattern.
3. `attach_model.mbt`: subscribe `model.on_did_change_content` →
   `content_generation += 1`, `Viewer::on_line_mapping_changed`
   (layout re-flush + `rendered_window = None`, `attach_model.mbt:204`),
   `schedule_render`.

## Track E — Consumer audit (decorations are destroyed by flush, per Monaco)

| Consumer | Today | Change |
|---|---|---|
| folding (`folding_contribution.mbt:20`) | recomputes on `on_did_change_model` only | also on `on_did_change_model_content`; collapse state preserved by the ported `FoldingModel.update` region matching |
| quick diff (`quick_diff_contribution.mbt:22`) | same | also recompute on content change |
| agent feedback (`agent_feedback_host.mbt`) | anchors are model decorations — destroyed by flush | re-apply anchors from the feedback service store on content change |
| markers | marker decorations destroyed | `marker_decorations_service` re-renders from `services.markers` on content change |
| inlay hints (`inlay_hints_host.mbt`) | injected-text decorations destroyed | re-request/re-apply on content change |

## Test matrix (Phase 4)

- Behavior-switching variables: content identical vs changed
  (`equals` early return at the host), wrap on/off, folding collapsed at
  flush time, decorations present at flush time, view zones present.
- wbtest: version increments; decorations map/tree emptied; projected view
  line count follows new content; cursor at origin after flush; two-loop
  ordering observable (listener sees updated view model);
  `TextSnapshot::equals`.
- Reference tests: `*_reference_test.mbt` parity block for the ViewModel
  flush branch (line counts, converter round-trips after `set_value`).
- Browser scenario: new `set_value` page cloned from `model_swap` —
  set new content, poll rendered text (needles must be space-free: view-line
  textContent uses nbsp), assert gutter/folding/quick-diff refresh, scroll
  clamps rather than resets. Register the page in the native server
  `static_route` list and, if it needs CSS, in `build-web.mbtx`.

## Exit gate

Per `_PORT_PLAYBOOK.md`: Phase 1 inventory (member counts for the scoped
units above) and the parity ledger are execution deliverables — build the
inventory and stop for review before writing port code. The five exit checks
apply before this plan may claim 1:1.

## Risks / watch-items

- **Two-loop order** (`textModel.ts:1652-1667`) is behavior, not style: any
  listener firing between structural update and cursor/outgoing emission sees
  a torn state. Port the order, and cover it with a wbtest.
- **Decoration destruction is the Monaco contract.** Every consumer that
  anchors state in decorations (Track E) must tolerate a full wipe. Audit
  before landing Track A, or the first `set_value` silently drops agent
  feedback anchors and marker squiggles until the next push.
- **Stale hidden-area anchors.** `ViewModelLines` holds
  `hidden_areas_decoration_ids` pointing at destroyed decorations after the
  wipe; Monaco tolerates this because `onModelFlushed` →
  `_constructLines(resetHiddenAreas=true)` delta-removes stale ids as a no-op
  (`viewModelLines.ts:122-126`). Verify the ported `delta_decorations`
  tolerates unknown ids the same way.
- **Emitter reentrancy.** `DidChangeContentEmitter` merge/deferred paths are
  exercised trivially with a flush-only lane; port them anyway (they are the
  tier-2 seam) but do not claim tested-by-use.

## Suggested commit slicing

1. `model: version id + content-changed event types + emitter` (Track A.1-3)
2. `model: set_value flush + tokenization handle_did_change_content` (A.4-7)
3. `model/view_model: registered view-model seam + two-loop dispatch` (B)
4. `view_model: flush branch + cursor reset` (C)
5. `viewer: set_value / on_did_change_model_content wiring` (D)
6. `contribs: content-change subscriptions + anchor re-apply` (E, per contrib)
7. Browser scenario + reference tests (F, alongside 4-6)

---

# Execution record (2026-07-10)

## Inventory (Phase 1)

Scoped source units, every member enumerated (the denominator):

- `textModel.ts` setValue/event cluster: `_versionId`, `_alternativeVersionId`,
  `getVersionId`, `getAlternativeVersionId`, `_increaseVersionId`,
  `_overwriteVersionId`, `_overwriteAlternativeVersionId`, `setValue`,
  `_createContentChanged2`, `_setValueFromTextBuffer`,
  `_emitContentChangedEvent`, `onDidChangeContent`, `_eventEmitter`,
  `_viewModels`, `registerViewModel`, `unregisterViewModel`,
  `equalsTextBuffer`, `getTextBuffer`, `_onDidChangeContentOrInjectedText`,
  `__isDisposing` + its emit guard, `DidChangeContentEmitter`
  (ctor/`hasListeners`/`beginDeferredEmit`/`endDeferredEmit`/`fire`), `setEOL`.
- `textModelEvents.ts`: `RawContentChangedType` (values 1-5), `ModelRawFlush`,
  `LineInjectedText`, `ModelRawLineChanged`, `ModelLineHeightChanged`,
  `ModelFontChanged`, `ModelRawLinesDeleted`, `ModelRawLinesInserted` (incl.
  `toLineNumber`/`toLineNumberPostEdit` getters), `ModelRawEOLChanged`,
  `ModelRawChange` union, `ModelRawContentChangedEvent`
  (fields/`resultingSelection`/`containsEvent`/`merge`),
  `ModelInjectedTextChangedEvent`, `IModelContentChangedEvent`,
  `ISerializedModelContentChangedEvent`, `IModelContentChange`
  (mirrorTextModel), `InternalModelContentChangeEvent`
  (`merge`/`_mergeChangeEvents`).
- `viewModelImpl.ts` flush cluster: constructor `registerViewModel` tail,
  `dispose` unregister, `onDidChangeContentOrInjectedText` (line-breaks
  two-pass, the five change branches, `acceptVersionId`, custom line heights,
  `onHeightMaybeChanged`, line-mapping branch, `_viewportStart`
  invalidate/recovery, `setModelLineCount`/`_updateConfigurationViewLineCountNow`,
  `_handleVisibleLinesChanged`), `emitContentChangeEvent`,
  `viewLayout.onFlushed`.
- `cursor.ts` `onModelContentChanged`: injected-text arm,
  `_knownModelVersionId`, `_isHandling` guard, `hadFlushEvent`,
  `_prevEditOperationType`, flush branch (dispose + fresh collection,
  `_validateAutoClosedActions`, ContentFlush state emission), non-flush arm.
- `codeEditorWidget.ts`: `setValue` (:487, with `_beginUpdate`/`_endUpdate`
  and the `_modelData` guard), `onDidChangeModelContent` re-fire.

Member count: 77 ledger rows (some inventory bullets group sibling members
that share one row; every member above has exactly one row).

## Parity Ledger (Phase 2)

| Source member (file:line) | Arithmetic/transition | MoonBit symbol | Status |
|---|---|---|---|
| `_versionId` (`textModel.ts:262,370`) | init 1 | `TextModel.version_id` | PASS (`set_value_wbtest`) |
| `getVersionId` (`:737-740`) | read | `TextModel::get_version_id` | PASS |
| `_increaseVersionId` (`:782-785`) | `+1` | `TextModel::increase_version_id` | PASS |
| `_alternativeVersionId` / `getAlternativeVersionId` (`:266,760`) | undo/redo mirror | — | N-A (no undo stack) |
| `_overwriteVersionId` / `_overwriteAlternativeVersionId` (`:787-793`) | restore path | — | N-A (no undo stack) |
| `setValue` (`:484-493`) | build buffer → flush | `TextModel::set_value` | PASS |
| null/undefined guard (`:487-489`) | `illegalArgument` | — | N-A (non-nullable `String`) |
| `_createContentChanged2` (`:495-512`) | payload shape | `TextModel::create_content_changed_2` | PASS (payload wbtest) |
| `_setValueFromTextBuffer` (`:514-545`) | old range/length → swap → bump → destroy → emit | `TextModel::set_value_from_snapshot` | PASS |
| `_bufferDisposable` swap (`:522-523`) | dispose old buffer | — | N-A (GC) |
| decoration destruction (`:526-528`) | fresh map + trees | same lines in `set_value_from_snapshot` | PASS (destruction wbtest) |
| `_commandManager.clear()` / `_trimAutoWhitespaceLines` (`:531-532`) | undo clear | — | N-A (scope cut 1) |
| `_emitContentChangedEvent` (`:467-482`) | order: tokenization → view models → emitter | `TextModel::emit_content_changed_event` | PASS (order wbtests) |
| `__isDisposing` guard (`:260-261,468-471`) | suppress during dispose | `TextModel.is_disposing` | PASS (disposing wbtest) |
| `bracketPairs`/`fontTokenDecorations` handleDidChangeContent (`:473-474`) | — | — | N-A (parts not ported, scope cut 4) |
| `resultingSelection` write (`:476-479`) | — | — | N-A (field not ported, see Deviations) |
| `tokenization.handleDidChangeContent` (`:472` callee) | flush → reset memo | `TokenizationTextModelPart::handle_did_change_content` | PASS (tokenization wbtest) |
| `onDidChangeContent` (`:245-247`) | unwrap `.contentChangedEvent` | `TextModel::on_did_change_content` | PASS |
| `_eventEmitter` (`:244`) | deferred emitter | `TextModel.event_emitter` | PASS |
| `_viewModels` (`:303`) | `Set<IViewModel>` | `TextModel.view_models : Array[&ViewModel]` | PASS |
| `registerViewModel` (`:449-451`) | add | `TextModel::register_view_model` | PASS |
| `unregisterViewModel` (`:453-455`) | delete | `TextModel::unregister_view_model` | PASS (box identity — see Deviations) |
| `equalsTextBuffer` (`:457-460`) | buffer equals | `TextModel::equals_text_snapshot` / `TextSnapshot::equals` | PASS |
| `getTextBuffer` (`:462-465`) | read | pre-existing `TextModel::snapshot` | N-A (existing surface) |
| `_onDidChangeContentOrInjectedText` (`:1652-1667`) | two loops, order load-bearing | `TextModel::on_did_change_content_or_injected_text` | PASS (two-loop wbtest) |
| `DidChangeContentEmitter` ctor (`:2698-2710`) | cnt 0 / event None | `DidChangeContentEmitter::new` | PASS |
| `hasListeners` (`:2712-2714`) | — | — | N-A (no consumer in ported slices) |
| `beginDeferredEmit` (`:2716-2718`) | `cnt+1` | `begin_deferred_emit` | TESTED (merge wbtest; tier-2 seam) |
| `endDeferredEmit` (`:2720-2730`) | `cnt-1`, fire held | `end_deferred_emit` | TESTED (merge wbtest; `resultingSelection` drop — Deviations) |
| `fire` (`:2732-2742`) | merge while deferred | `DidChangeContentEmitter::fire` | PASS (merge wbtest) |
| `setEOL` (`:547+`) | EOL lane | — | N-A (scope cut 2) |
| `RawContentChangedType` (`tme:221-227`) | const enum 1-5 | `RawContentChangedType` | PORTED (numeric values unobservable — Deviations) |
| `ModelRawFlush` (`:233`) | changeType | `ModelRawChange::ModelRawFlush` + `change_type` | PASS |
| `LineInjectedText` (`:241-302`) | injected-text lane | — | N-A (whole-reproject deviation, header of `text_model_events.mbt`) |
| `ModelRawLineChanged` (`:308-323`) | tier-2 payload | `ModelRawLineChanged(..)` | PORTED (type only; constructor is tier-2) |
| `ModelLineHeightChanged*` / `ModelFontChanged*` (`:330-374,519-557`) | — | — | N-A (features not ported) |
| `ModelRawLinesDeleted` (`:380-400`) | tier-2 payload | `ModelRawLinesDeleted(..)` | PORTED (type only) |
| `ModelRawLinesInserted` (`:406-438`) | tier-2 payload | `ModelRawLinesInserted(..)` | PORTED (type only) |
| `toLineNumber`/`toLineNumberPostEdit` getters (`:423-431`) | `from + count - 1` | — | DEFERRED (derived getters of a tier-2-only event; nothing constructs it) |
| `ModelRawEOLChanged` (`:444-446`) | tier-2 payload | `ModelRawEOLChanged` | PORTED (type only) |
| `ModelRawChange` union (`:451`) | 5-way union | `ModelRawChange` enum | PASS |
| `ModelRawContentChangedEvent` fields (`:457-481`) | versionId/undo/redo | `ModelRawContentChangedEvent` | PASS |
| `resultingSelection` (`:473,480`) | edit-lane selection | — | N-A (Deviations) |
| `containsEvent` (`:483-491`) | linear scan | `contains_event` | PASS (union wbtest) |
| `merge` (`:493-499`) | concat/b.version/or | `ModelRawContentChangedEvent::merge` | PASS (union wbtest) |
| `ModelInjectedTextChangedEvent` (`:506-513`) | injected-text lane | — | N-A (whole-reproject deviation) |
| `IModelContentChangedEvent` (`:42-85`) | public payload | `ModelContentChangedEvent` | PASS |
| `detailedReasons`/`detailedReasonsChangeLengths` (`:78-84`) | telemetry | — | N-A (edit source not ported) |
| `ISerializedModelContentChangedEvent` (`:87-124`) | worker protocol | — | N-A (no worker protocol) |
| `IModelContentChange` (mirrorTextModel) | change entry | `ModelContentChange` | PASS |
| `InternalModelContentChangeEvent` (`:562-566`) | pair | `InternalModelContentChangeEvent` | PASS |
| `merge`/`_mergeChangeEvents` (`:568-593`) | concat + eol/version from b + flags | `merge` / `merge_change_events` | PASS (deferred-merge wbtest) |
| `registerViewModel` ctor tail (`vmi:169`) | register self | `ViewModel::with_options` tail | PASS |
| `dispose` unregister (`vmi:180`) | unregister self | `ViewModel::dispose` ← `ModelData::dispose` | PASS (dispose test) |
| Flush branch (`vmi:356-363`) | lines flush → ViewFlushed → decorations reset → layout flush | `ViewModel::on_did_change_content_or_injected_text` `Some(e)` arm | PASS (`set_value_flush_test`) |
| line-breaks two-pass (`vmi:331-347`) | tier-2 feed | — | DEFERRED (tier-2; only feeds per-line branches) |
| LinesDeleted/Inserted/LineChanged/EOLChanged branches (`vmi:364-409`) | tier-2 | `_ => ()` arm | DEFERRED (tier-2; events never constructed) |
| `acceptVersionId` (`vmi:412-414`) | assertion state | — | N-A (wholesale-rebuild collection keeps none) |
| custom line heights (`vmi:349-352,417-426`) | — | — | N-A (uniform line height) |
| `onHeightMaybeChanged` (`vmi:428`) | re-derive scroll dims | `ViewLayout::on_height_maybe_changed` | PASS (scroll-clamp test) |
| line-mapping branch (`vmi:430-435`) | tier-2-only | — | N-A for flush (`hadOtherModelChange` true) |
| `_viewportStart` invalidate/recovery (`vmi:441-454`) | ≥2-editor recovery | — | N-A (scope cut 3; single-editor clamps) |
| `setModelLineCount`/`_updateConfigurationViewLineCountNow` (`vmi:443-444`) | wrap facts | Viewer content listener (`on_line_mapping_changed`) | PASS (browser scenario) |
| `_handleVisibleLinesChanged` (`vmi:456`) | attached-view protocol | — | N-A (protocol not ported) |
| `emitContentChangeEvent` (`vmi:462-469`) | outgoing + cursor | trait impl `emit_content_change_event` | PASS (outgoing seam — Deviations) |
| `viewLayout.onFlushed` | `linesLayout.onFlushed` | `ViewLayout::on_flushed` → `LinesLayout::on_flushed` | PASS |
| injected-text arm (`cursor.ts:227-242`) | setStates re-project | — | N-A (viewer re-points via `set_context`) |
| `_knownModelVersionId` (`:245`) | stale-edit guard | — | N-A (no edit application) |
| `_isHandling` guard (`:246-248`) | reentrancy | — | N-A (no edit application) |
| `hadFlushEvent` (`:250`) | `containsEvent(Flush)` | `CursorsController::on_model_content_changed` | PASS |
| `_prevEditOperationType` (`:251`) | edit memory | — | N-A (no edits) |
| flush branch (`:253-258`) | dispose + fresh collection | `self.cursor = Cursor::new()` | PASS (cursor-origin tests) |
| `_validateAutoClosedActions` / ContentFlush emission (`:257-258`) | — | — | N-A (no auto-close state; cursor events fire from interaction paths — Deviations) |
| non-flush arm (`:259-269`) | marker recovery | — | DEFERRED (tier-2 edit lane) |
| `setValue` (`cew:487-497`) | guard + delegate | `Viewer::set_value` | PASS (no-op + delegate wbtests) |
| `_beginUpdate`/`_endUpdate` (`cew:489,495`) | render batch | — | N-A (repaint coalesces on the render flush) |
| `onDidChangeModelContent` re-fire (`cew:105`) | public event | `Viewer::on_did_change_model_content` | PASS (re-fire wbtest) |

Totals: 77 rows — 46 done (39 PASS / 2 TESTED / 5 PORTED) / 4 DEFERRED /
27 N-A.

## Deviations (Phase 3)

All recorded in code comments at the cited sites; consolidated:

1. `resultingSelection` (raw event field, emitter write, `_emitContentChangedEvent`
   write): not ported — `Selection` lives above `common/model` (no-cycle), and
   the flush lane always carries `null` (only `pushEditOperations` sets it).
2. `LineInjectedText` / `ModelInjectedTextChangedEvent`: the viewer's
   injected-text lane stays the whole-document reproject through the
   decorations listener; the trait parameter is the content event alone, and
   `ViewModel::on_did_change_content_or_injected_text`'s optional-event form
   models the source union (`None` = injected-text arm).
3. `detailedReasons` / `TextModelEditSource`: editing telemetry, not ported.
4. `RawContentChangedType` numeric const-enum values (1-5) are not
   observable; identity is by constructor.
5. `unregisterViewModel` identity: MoonBit trait objects have no
   cross-coercion identity, so `ViewModel` keeps the registered box
   (`registered_view_model`) and passes the same value back at dispose.
6. `TokenizationTextModelPart::handle_did_change_content` receives extracted
   facts (new lines + `is_flush`) instead of the event — the event type lives
   above `model/tokens` (no-cycle seam).
7. `emitContentChangeEvent`'s outgoing `ModelContentChangedEvent`: the
   viewer's outgoing seam is the Viewer's `model.on_did_change_content`
   subscription (re-fired as `Viewer::on_did_change_model_content`); the view
   model has no event dispatcher.
8. Cursor `ContentFlush` state-changed emission: the viewer's cursor events
   fire from its interaction paths; a flush resets silently (single-cursor
   readonly reduction).
9. The `try/catch onUnexpectedError` per view-model call is unreachable
   (MoonBit callbacks are non-raising — same precedent as
   `change_decorations`).
10. `ViewFlushedEvent`: the frame-diff view derives the document-wide repaint
    from the Viewer-layer `content_generation` bump (established seam).

## Exit Gate (Phase 5)

- [x] rows == members; done/deferred/N-A = 46/4/27 (77 total)
- [x] every ported function reread side-by-side against
      `textModel.ts`/`textModelEvents.ts`/`viewModelImpl.ts`/`cursor.ts`/
      `codeEditorWidget.ts` for order, branches, early returns, constants
- [x] branch/configuration matrix green: content identical vs changed (both
      flush; host owns the `equals` early return — wbtested), wrap on/off,
      folding collapsed at flush (hidden-area reset + contrib recompute),
      decorations present at flush (destruction + stale-id tolerance),
      view zones present (browser suite); `just check` / `just test`
      (834 js + 670 native) / `just build` / `just test-browser` (36) all pass
- [x] all deviations recorded and justified (10, above)
- [x] closing reread of the scoped units found no unaccounted member
      (the inventory list above is the reread record)
