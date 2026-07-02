# Monaco Decoration System 1:1 Port (storage → view conversion → overlay)

Status: proposed — Date: 2026-07-02. Oracle commit:
`294fb350837dbaee37b949533fead4df4e0e8971`.

The "Option A" migration from the 2026-07-02 port audit (memory:
`monaco-port-remaining-gaps-2026-07`): replace the viewer's half-ported live
decoration system with Monaco's real three-layer architecture, and promote the
already-ported-but-unwired `viewer/common/inline_decorations` package to
production. One coherent program closes four audit findings:

1. the **interval-tree storage deferral** (recorded since
   `monaco-one-to-one-port.md`; re-deferred by the marker plan's Decision D3
   *so this plan could own it*);
2. the **dead `viewer/common/inline_decorations` package** (faithful port of
   `viewModel/inlineDecorations.ts`, quarantined only because its Monaco type
   names collide with the simplified live types — deleted below);
3. the **missing `DecorationsOverlay`** (no whole-line/background decoration
   rendering path exists);
4. the **invented `DecorationKind` enum** (Monaco's decoration contract is
   open — consumers key off options/class names; the enum makes every new
   feature edit a core type).

It also converts the marker render path from whole-frame rebuild to
event-driven decoration updates, and gives hosts the single most valuable
missing public API of an embeddable readonly viewer: `delta_decorations`.

## Replacement map (local end state)

What gets **deleted**, what gets **promoted**, what stays:

| Today | End state |
|---|---|
| No storage; flat `Array[Decoration]` rebuilt per frame; markers baked into the frame source (`render.mbt:36-39`, `content_generation` bump per marker change); hover passed per render (`controller_decorations`) | `TextModel`-owned `DecorationsTrees` (Phase 2) over the Phase-1 interval tree; producers call `delta_decorations`; changes dispatch a new `ViewDecorationsChanged` view event |
| `@model.Decoration` + `DecorationKind` + `DecorationSet` (`decorations.mbt`) | `Decoration` evolves into the faithful `ModelDecorationOptions` subset (gains `is_whole_line`; **loses `kind`**); `DecorationSet`/`DecorationKind` deleted (Phase 4); `kind` consumers (`line_html.mbt:68`, `view_line_data.mbt:100,147`) rewritten to Monaco's option/class-name tests |
| Simplified `ViewModelDecoration` + eager whole-list conversion (`view_model_decorations.mbt`) | Deleted; `ViewModelDecorations` rebased on the faithful `InlineModelDecorationsComputer` with Monaco's lazy viewport cache (Phase 3) |
| `viewer/common/inline_decorations`: faithful but unwired, with bundled test doubles (`IdentityCoordinatesConverter`, mini `TextModel`, mini `ModelDecorationOptions`) | Production middle layer. Its doubles are replaced by the real `CoordinatesConverter` and the real model-tier types behind small seams; the doubles stay for its reference suite (Monaco's own test setup does the same) |
| `view_layout` `LineDecoration` + normalizer (already-faithful renderer bottom layer) | Unchanged — the migration is middle-out; `viewLines` consumes the restored `ViewModelDecoration → per-line InlineDecoration → LineDecoration` chain |
| No `DecorationsOverlay` | Ported into the `selections` package (the ContentViewOverlays merge, after current-line, before the selection pieces — Monaco registration order `view.ts:218-221`) |
| Hover highlight class `has-hover` | Monaco's `hoverHighlight` class (theme var `--vscode-editor-hoverHighlightBackground` already exists) |

## Scope (Phase 0)

| # | Source unit | Slice | Phase |
|---|---|---|---|
| 1 | `common/model/intervalTree.ts` | whole file | 1 |
| 2 | `test/common/model/intervalTree.test.ts` | whole (25 tests + invariant harness) | 1 |
| 3 | `common/model/textModel.ts` | decoration cluster: fields `:285-290`, events `:225-226,:1624`, API `:1669-1986`, `DecorationsTrees` `:2196-2353`, `cleanClassName` + options classes `:2355-2580`, `DidChangeDecorationsEmitter` `:2586-2666` | 2 |
| 4 | `test/common/model/modelDecorations.test.ts` | readonly subset (suites "Model Decorations" + "deltaDecorations"; editing suites via direct `acceptReplace` only) | 2 |
| 5 | `common/viewModel/viewModelDecorations.ts` | whole file | 3 |
| 6 | local migration: promote `inline_decorations`, delete simplified types, re-plumb producers (marker service, hover) | — | 3 |
| 7 | `browser/viewParts/decorations/decorations.ts` + `decorations.css` | whole file | 4 |
| 8 | local retirement: `DecorationKind`/`DecorationSet` + `kind` consumers | — | 4 |
| 9 | `codeEditorWidget.ts` decoration API slice (`deltaDecorations`, `getLineDecorations`, `getDecorationsInRange`, `removeDecorations`) | public `Viewer::` surface | 5 |

**Out of scope (named siblings, explicitly deferred — not "unseen"):**

- **Injected text via decoration storage** (`_injectedTextDecorationsTree`,
  `getInjectedTextDecorations`, `ModelDecorationInjectedTextOptions`,
  `getAllInjectedText`/`getInjectedTextInInterval`,
  `recordLineAffectedByInjectedText`, the `InjectedTextInlineDecorationsComputer`
  arm of the faithful package). The viewer's inlay hints use their own
  injected-text pipeline (`view_model/injected_text.mbt`); merging it into
  decoration storage is its own future port. The third tree slot is stubbed
  empty; the computer arm stays test-only.
- **Line-height / font decorations** (`lineHeight`, `fontSize`,
  `affectsFont`, `filterFontDecorations`,
  `getCustomLineHeights*`/`getFontDecorations*`,
  `_fireOnDidChangeLineHeight`/`Font`,
  `TokenizationFontDecorationProvider`) — the viewer is uniform line-height
  by recorded reduction. The `affectsFont` node bit is carried (it is baked
  into the tree's metadata layout) but never set.
- **Bracket-pair colorization** (`ColorizedBracketPairsDecorationProvider`,
  `_decorationProvider` composition in every getter) — needs
  `textModelBracketPairs.ts`, unported.
- **Block decorations** (`blockClassName`/`blockPadding`/`blockIsAfterEnd`/
  `blockDoesNotCollapse`) and `textDirection` — no consumer view part.
- **Overview-ruler / minimap / glyph-margin view parts** — stay deferred
  (marker plan Increment H). But their *query surface*
  (`getOverviewRulerDecorations`, `getAllMarginDecorations`, tree1, the
  `IsMargin` bit) is in scope: after this plan they are pure consumers.
- **`createDecorationsCollection`** (`codeEditorWidget.ts`) — sugar over
  `deltaDecorations`; deferred until a host asks.
- **Theme-object color resolution** (`ModelDecorationOverviewRulerOptions.getColor`
  / `ModelDecorationMinimapOptions.getColor` against `IColorTheme`) — the
  viewer's colors cascade via CSS custom properties (recorded theming
  design); the color fields are carried as strings.

## Deviations (anticipated; each lands with a code-site note)

1. **Readonly reach.** `acceptReplace`/`nodeAcceptEdit`/`searchForEditing`/
   `noOverlapReplace` (the edit cluster) are ported **for conformance** —
   they are pure offset math, and Monaco's gen01–gen18 + `nodeAcceptEdit`
   suites exercise the RB-tree through them — but are unreachable from
   product code (no model edits; the precedent is the `inline_decorations`
   package itself). The delta bookkeeping inside insert/delete/rotations is
   inseparable and ports verbatim; in a never-edited tree all deltas stay 0.
2. **Sync emitter.** `DidChangeDecorationsEmitter`'s deferred-emit brackets
   are ported (delta ops batch into one event), but the underlying emitter is
   the repo's sync `@base_common.Emitter` (same deviation the marker service
   recorded; no `MicrotaskEmitter`).
3. **Event sourcing.** `onDidChangeDecorations` reaches view parts as a new
   `ViewDecorationsChanged` view event pushed by the `Viewer` glue (the
   frame-snapshot event seam documented in `view_events.mbt`), not via
   Monaco's `ViewModelEventDispatcher`.
4. **Decoration id format.** Monaco ids are `${instanceId};${counter}` with a
   process-wide instance counter; the port uses a per-model counter with the
   same shape. Ids are opaque strings either way.
5. **Options subset.** `ModelDecorationOptions` ports the fields with an
   in-repo or Increment-H consumer (see Phase 2 ledger); out-of-scope fields
   are named rows, not silence. `register`/`createDynamic` collapse to one
   constructor (no options interning — Monaco's `register` exists to dedupe
   per-instance allocations, a perf memo with no behavior).
6. **Model swap semantics.** The viewer swaps whole `TextModel`s on version
   change instead of editing; decoration owners re-attach on swap (the marker
   service's `on_model_added/removed` pattern). `cachedVersionId` therefore
   only ever sees one version per tree lifetime — kept anyway (faithful, and
   it keeps the resolve/cache logic diffable against the source).
7. **Flat overlay pieces.** `DecorationsOverlay` renders absolutely
   positioned divs like the selections/current-line precedent instead of
   per-line container HTML (recorded flat-overlay deviation); the per-line
   *piece computation* is a pure transcription of `_renderWholeLine…`/
   `_renderNormal…` and unit-testable headlessly.
8. **`linesVisibleRangesForRange`** for the overlay reuses the DOM
   measurement seam (`measure_line_selection`), like the selection overlay —
   Monaco reads the same geometry from its rendered lines.

## Phase 1 — `intervalTree.ts` (whole) + its test file

New DOM-free package `viewer/common/model/interval_tree` (multi-target; the
mirror of `common/model`'s file, carved as a package so `model` can depend on
it without cycles — final placement may fold into `viewer/common/model` if no
cycle appears; decide at implementation, record the choice here).

**Placement decided (2026-07-02): folded into `viewer/common/model`**
(`interval_tree.mbt`). The node's `options` field is that package's
`Decoration`, so a carved sibling package would cycle; Monaco keeps both in
`common/model` too. Landed with `interval_tree_reference_test.mbt` (29 cases,
js+native). Implementation notes: the `ClassName` row below could not reuse
`@markers` constants (`markers` imports `model`); the three consulted
constants are defined locally like the source file does. Link fields are
`IntervalNode?` behind unwrap accessors (MoonBit cannot construct a
self-referential literal); the sentinel is bootstrapped by two-step
construction. `FORCE_OVERFLOWING_TEST` ports as an explicit forced-delta test
mode (see conformance notes below).

### Inventory (Phase 1)

Members read from the file (not memory): 3 enums + 2 delta constants, 8
metadata accessor pairs, `IntervalNode` (16 fields + 5 methods), `SENTINEL`,
`IntervalTree` (2 fields + 11 methods), 15 free functions.

### Parity ledger (Phase 1)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `ClassName` enum (:14-22) | 7 squiggly class constants | 3 consulted constants local to `interval_tree.mbt` (dependency direction forbids `@markers` reuse; other 4 live in `@markers` strings) | PASS |
| `NodeColor` (:24-27) | Black=0, Red=1 | `NodeColor` | PASS |
| `Constants` bit layout (:29-56) | color/visited/forValidation/stickiness/collapseOnReplace/isMargin/affectsFont masks+offsets in one `metadata` byte | same bit constants | PASS |
| `MIN/MAX_SAFE_DELTA` (:58-78) | ±(1<<30) SMI guard | same values | PASS |
| `getNodeColor`/`setNodeColor` (:81-88) | mask ops | accessor pair | PASS |
| `get/setNodeIsVisited` (:89-96) | mask ops | accessor pair | PASS |
| `get/setNodeIsForValidation` (:97-104) | mask ops | accessor pair | PASS |
| `get/setNodeIsInGlyphMargin` (:105-112) | mask ops | accessor pair | PASS |
| `get/setNodeAffectsFont` (:113-120) | mask ops | accessor pair (bit carried; never set — see out-of-scope) | PASS |
| `getNodeStickiness`/`_setNodeStickiness`/`setNodeStickiness` (:121-139) | mask ops | accessor pair + pub wrapper | PASS |
| `get/setCollapseOnReplaceEdit` (:129-136) | mask ops | accessor pair | PASS |
| `IntervalNode` fields (:141-164) | metadata/parent/left/right/start/end/delta/maxEnd/id/ownerId/options/cachedVersionId/cachedAbsoluteStart/cachedAbsoluteEnd/range | `IntervalNode` struct (self-referential via sentinel) | PASS |
| `IntervalNode` ctor (:166-195) | red, self-parented, delta 0, stickiness NeverGrows | `IntervalNode::new` | PASS |
| `reset` (:197-205) | reseed offsets + cached range | `::reset` | PASS |
| `setOptions` (:207-219) | derive forValidation from squiggly classNames; isMargin from glyphMarginClassName; stickiness; collapseOnReplaceEdit; affectsFont | `::set_options` | PASS |
| `setCachedOffsets` (:221-228) | version mismatch → drop cached range | `::set_cached_offsets` | PASS |
| `detach` (:230-234) | null out links | `::detach` (sentinel out) | PASS |
| `SENTINEL` (:237-241) | self-linked black node | package-level sentinel | PASS |
| `IntervalTree` fields+ctor (:243-251) | root=SENTINEL; requestNormalizeDelta | `IntervalTree` | PASS |
| `intervalSearch` (:253-258 → :775-866) | augmented-tree overlap search: maxEnd prune (b), start>end prune (a), delta accumulation, 4 include filters | `::interval_search` | PASS |
| `search` (:260-265 → :711-773) | full in-order with filters + cache offsets | `::search` | PASS |
| `collectNodesFromOwner` (:270-272 → :638-674) | in-order, ownerId match, no cached offsets | `::collect_nodes_from_owner` | PASS |
| `collectNodesPostOrder` (:277-279 → :676-709) | post-order, no cached offsets | `::collect_nodes_post_order` | PASS |
| `insert` (:281-284) | rbTreeInsert + normalize-if-necessary | `::insert` | PASS |
| `delete` (:286-289) | rbTreeDelete + normalize-if-necessary | `::delete` | PASS |
| `resolveNode` (:291-304) | walk to root summing right-child deltas | `::resolve_node` | PASS |
| `acceptReplace` (:306-333) | remove intersecting → noOverlapReplace others → nodeAcceptEdit + reinsert | `::accept_replace` | PASS (conformance-only; Deviation 1) |
| `getAllInOrder` (:335-337) | `search(0,false,false,0,false)` | `::get_all_in_order` | PASS |
| `_normalizeDeltaIfNecessary` (:339-345) | flag-gated normalizeDelta | private | PASS |
| `normalizeDelta` (:349-385) | iterative in-order visit pushing deltas into offsets | free fn | PASS |
| `MarkerMoveSemantics` (:390-394) | MarkerDefined/ForceMove/ForceStay | enum | PASS (edit cluster; conformance-only) |
| `adjustMarkerBeforeColumn` (:396-410) | <,>,ForceMove,ForceStay,stickiness order | free fn | PASS (edit cluster; conformance-only) |
| `nodeAcceptEdit` (:416-490) | stickiness split; collapseOnReplaceEdit arm; 3 moveSemantics passes; deltaColumn finish; end>=start clamp | free fn | PASS (edit cluster; conformance-only) |
| `searchForEditing` (:492-562) | overlap collect with cachedOffsets(…,0) | free fn | PASS (edit cluster; conformance-only) |
| `noOverlapReplace` (:564-632) | editDelta shift right-of-edit; delta overflow flag; maxEnd recompute on way up | free fn | PASS (edit cluster; conformance-only) |
| `rbTreeInsert` (:871-928) | CLRS insert + repair, rotations recolor | free fn | PASS |
| `treeInsert` (:930-969) | delta-relative descent, `intervalCompare` order, subtract delta at link | free fn | PASS |
| `rbTreeDelete` (:973-1155) | no-z/y-swap delete; delta hand-off in 3 shapes; maxEnd walks; RB-DELETE-FIXUP both sides | free fn | PASS |
| `leftest` (:1157-1162) | min of right subtree | free fn | PASS |
| `resetSentinel` (:1164-1169) | re-zero sentinel | free fn | PASS |
| `leftRotate`/`rightRotate` (:1173-1231) | delta transfer ±x.delta, overflow flag, maxEnd recompute both | free fns | PASS |
| `computeMaxEnd`/`recomputeMaxEnd`/`recomputeMaxEndWalkToRoot` (:1236-1270) | max of end, left.maxEnd, right.maxEnd+delta; early-out walk | free fns | PASS |
| `intervalCompare` (:1275-1280) | start-major, end-minor | free fn | PASS |

Member count (Phase 1): **41 rows**.

### Conformance (Phase 1)

Port `intervalTree.test.ts` as
`interval_tree_reference_test.mbt` (per the 2026-07-02 decision, parity lives
in MoonBit reference tests — no browser specs):

- the op-driven harness (`testIntervalTree`, ops = insert/delete/change/
  acceptReplace against an oracle array of intervals);
- `assertTreeInvariants` (:856-905): RB height rule, red-parent rule,
  delta-bounds, maxEnd consistency, in-order sortedness — run after **every**
  op like the source;
- gen01–gen18 (:274-445), `force delta overflow` (:446), the 5 Cormen
  interval-search cases (:509-556), and the `nodeAcceptEdit` table (:571+,
  ~250 assertions across stickiness × forceMoveMarkers × edit shapes).
- The `getRandomInt` fuzz loop (:173-190) ports as a seeded-PRNG test with a
  fixed seed set (deterministic in CI; note the seeds).

Landed notes (2026-07-02): all of the above are in
`interval_tree_reference_test.mbt`. Seeds are xorshift32
{11111, 22222, 33333, 44444, 55555}. The `force delta overflow` constants
(~9e14) exceed MoonBit's 32-bit `Int` and are scaled by 1e-6; the real
`normalize_delta` path is driven by a companion `accept_replace` test instead.
Because the plain suite never creates nonzero deltas (true of Monaco's run
too), the source's commented-out `FORCE_OVERFLOWING_TEST: this.delta = start`
ctor line is ported as an explicit test mode that re-runs gen01–gen18 and the
fuzz loop with forced deltas — a mutation check on the rotation delta
transfer fails only under this mode, as in the source.

## Phase 2 — `textModel.ts` decoration cluster

Lands on `viewer/common/model.TextModel` (the readonly model): a `mut`
decorations state (`DecorationsTrees` + id map + counter + emitter). The
existing `@model.Decoration` evolves into the `ModelDecorationOptions` subset;
`IModelDecoration` (id + ownerId + range + options) becomes the query result
type — this is what the faithful package's `ModelDecoration` already models.

### Inventory (Phase 2)

Fields `:225-226,:285-290`; event plumbing `:1624-1667`; public API
`:1669-1886`; private impls `:1890-2062`; `DecorationsTrees` `:2196-2353`;
`cleanClassName` `:2355`; options classes `:2359-2580`; emitter `:2586-2666`.

### Parity ledger (Phase 2)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `_onDidChangeDecorations` + `onDidChangeDecorations` (:225-226) | DidChangeDecorationsEmitter | `TextModel::on_did_change_decorations` | PASS |
| `_lastDecorationId`/`_decorations`/`_decorationsTree` (:286-288) | id counter, id→node map, trees | model fields | PASS |
| `_deltaDecorationCallCnt` re-entrancy warn (:285, :1717-1730) | warn if deltaDecorations called from the change event | ported guard (log service) | PASS |
| `_decorationProvider`/`_fontTokenDecorationsProvider` (:289-290) | bracket/font providers composed into getters | — | N-A (out of scope; getters return tree results only, noted at code site) |
| `handleBeforeFireDecorationsChangedEvent` (:1624-1634) | injected-text/line-height/font fan-out | — | DEFERRED (all three arms out of scope) |
| `_fireOnDidChangeLineHeight`/`Font` (:1636-1667) | — | — | N-A (uniform line height) |
| `changeDecorations` + `_changeDecorations` (:1669-1715) | accessor object {add,change,changeOptions,remove,delta} inside one deferred-emit bracket | `::change_decorations` with accessor struct | PASS |
| `deltaDecorations` (:1717-1776) | guard empty fast path; deferred-emit bracket around `_deltaDecorationsImpl` | `::delta_decorations` | PASS |
| `removeAllDecorationsWithOwnerId` (:1777-1789) | collectNodesFromOwner → delete + map cleanup | `::remove_all_decorations_with_owner_id` | PASS |
| `getDecorationOptions`/`getDecorationRange` (:1790-1805) | id → node → options / resolved range | `::get_decoration_options` / `::get_decoration_range` | PASS |
| `getLineDecorations` (:1806-1812) | delegates to getLinesDecorations(line,line) | `::get_line_decorations` | PASS |
| `getLinesDecorations` (:1813-1825) | clamp lines; offsets via buffer; interval query | `::get_lines_decorations` | PASS |
| `getDecorationsInRange` (:1826-1834) | validated range → `_getDecorationsInRange` | `::get_decorations_in_range` | PASS |
| `getOverviewRulerDecorations` (:1835-1838) | getAll(overviewRulerOnly=true) | `::get_overview_ruler_decorations` | PASS (query only; part deferred) |
| `getInjectedTextDecorations` (:1839-1842) | injected tree | — | DEFERRED (injected-text out of scope) |
| `getCustomLineHeights*`/`getFontDecorationsInRange` (:1843-1868) | — | — | N-A (uniform line height / no font decorations) |
| `getAllDecorations` (:1869-1875) | getAll + provider merge | `::get_all_decorations` (tree only) | PASS |
| `getAllMarginDecorations` (:1876-1879) | getAll(onlyMarginDecorations) | `::get_all_margin_decorations` | PASS (query only) |
| `_getDecorationsInRange` (:1880-1889) | offsets from buffer; getAllInInterval | private | PASS |
| `_changeDecorationImpl` (:1890-1935) | delete node → reset offsets/range → reinsert; injected/lineHeight records | private (records deferred with their features) | PASS |
| `_changeDecorationOptionsImpl` (:1936-1975) | tree1↔tree0 migration when overviewRuler-ness flips; setOptions | private | PASS |
| `_deltaDecorationsImpl` (:1976-2062) | two-pointer old/new walk; node reuse; validateRange relaxed; offsets; checkAffectedAndFire per remove/add | private | PASS |
| `DecorationsTrees` 3 trees (:2202-2218) | tree0 normal / tree1 overview-ruler / injected | 2 trees + stubbed third | PASS (injected slot DEFERRED) |
| `ensureAllNodesHaveRanges`/`_ensureNodesHaveRanges` (:2220-2232) | resolve missing ranges via host.getRangeAt | `::ensure_nodes_have_ranges` PASS; `ensureAllNodesHaveRanges` N-A (only consumer is the `_onBeforeEOLChange` edit path) | PASS/N-A |
| `getAllInInterval`/`_intervalSearch` (:2233-2245) | both trees searched, ensure ranges | `::get_all_in_interval` | PASS |
| `getInjectedTextInInterval`/`getAllInjectedText` (:2246-2263) | — | — | DEFERRED (injected-text) |
| `getFontDecorations…`/`…CustomLineHeights…` (:2252-2275) | — | — | N-A |
| `getAll`/`_search` (:2276-2326) | overviewRulerOnly → tree1 only, else both | `::get_all` | PASS |
| `getNodeRange`/`resolveNode` dispatch/`acceptReplace` (:2327-2353) | per-tree routing by node bits | `::get_node_range` etc. (acceptReplace conformance-only) | PASS |
| `cleanClassName` (:2355-2357) | `[^a-z0-9\-_]/gi → ' '` | free fn | PASS |
| `DecorationOptions` base + `ModelDecorationOverviewRulerOptions` (:2359-2405) | color/darkColor strings; position default Center; theme resolution | struct with string colors (Deviation: no theme object — CSS cascade design) | PASS |
| `ModelDecorationGlyphMarginOptions` (:2407-2416) | lane + persistLane | — | DEFERRED (glyph margin part) |
| `ModelDecorationMinimapOptions` (:2418-2451) | position + sectionHeader | carried inert (Increment-H precedent) | PASS |
| `ModelDecorationInjectedTextOptions` (:2453-2476) | — | — | DEFERRED (injected-text) |
| `ModelDecorationOptions` fields+ctor (:2478-2580) | ~35 fields; cleanClassName on all class names; stickiness default AlwaysGrows; zIndex default 0 | evolve `@model.Decoration`: port `description`, `stickiness`, `zIndex`, `className`, `hoverMessage`(kept as `message`), `isWholeLine`, `showIfCollapsed`, `collapseOnReplaceEdit`, `overviewRuler`, `minimap`, `glyphMarginClassName`, `linesDecorationsClassName`, `firstLineDecorationClassName`, `marginClassName`, `inlineClassName`, `inlineClassNameAffectsLetterSpacing`, `shouldFillLineOnLineBreak`; name every omitted field in the code-site note (block*, before/after, lineNumber*, hideIn*Tokens, font*, textDirection) | PASS |
| `register`/`createDynamic`/`EMPTY` (:2481-2489) | interning memo | single constructor (Deviation 5) | PASS |
| `DidChangeDecorationsEmitter` (:2586-2666): begin/endDeferredEmit, `checkAffectedAndFire`, `fire`, `_shouldFireDeferred` | batch depth counter; affects flags (minimap/overview) accumulated; one event per bracket | `DecorationsChangedEmitter` over `@base_common.Emitter` (Deviation 2); injected/lineHeight/font record fns DEFERRED/N-A with their features; `hasListeners` N-A (no consumer) | PASS |
| `_getTrackedRange`/`_setTrackedRange`/`TRACKED_RANGE_OPTIONS` (:1741-1776) | editing-cursor tracked-range internals | — | N-A (no consumer in the readonly viewer) |
| `DecorationsTrees.collectNodesPostOrder` (:2335-2340) | post-order collect | — | N-A (only consumer is TextModel.dispose) |

Member count (Phase 2): **33 rows**.

### Conformance (Phase 2)

`model_decorations_reference_test.mbt` (extends the existing file): the
"Editor Model - Model Decorations" suite (readonly rows — decoration CRUD via
`changeDecorations`/`deltaDecorations`, range/options queries, event firing)
and the full "deltaDecorations" suite (`modelDecorations.test.ts:1124+`). The
"Decorations and editing" suites (insert/delete/replace × collapsed ×
stickiness) reach the port only through direct `IntervalTree::accept_replace`
(no `applyEdits` on a readonly model) — they are covered by the Phase-1
`nodeAcceptEdit` table + gen tests; record the mapping in the test header.

Landed notes (2026-07-02): the reference file was rewritten against the real
storage (its interim `DecorationSet` adaptations are gone); the mapping for
the `applyEdits` suites is recorded in its header. `issue #41492`
(collapseOnReplaceEdit) is ported as a white-box case driving
`accept_replace` at the offset level, in `text_model_decorations_wbtest.mbt`
together with matrix companions (emitter brackets + `fire`, delta id-reuse
semantics, search filters incl. tree1 routing, options normalization, the
tree0↔tree1 `changeDecorationOptions` migration, and the re-entrancy warn
through `@log.LogService` — `TextModel::TextModel` gained an optional
`log_service` parameter for it). The legacy `Decoration.range`/`kind` fields
stay alive through this phase (old render path untouched, per the commit
slicing); `DeltaDecoration` is the faithful (range, options) input pair.

## Phase 3 — `viewModelDecorations.ts` (whole) + promotion of `inline_decorations` + producer re-plumbing

### Inventory (Phase 3)

`viewModelDecorations.ts` members: fields+ctor (:18-37),
`_clearCachedModelDecorationsResolver` (:39), `dispose` (:44), `reset` (:49),
`onModelDecorationsChanged` (:54), `onLineMappingChanged` (:59),
`getMinimapDecorationsInRange` (:65), `getDecorationsViewportData` (:69),
`getDecorationsOnLine` (:79). Local migration steps are inventoried as
explicit rows (they are deletions/wirings, not ports).

### Parity ledger (Phase 3)

| Source member / migration step | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| ctor context closure (:31-34) | `getModelDecorations` = linesCollection.getDecorationsInRange(viewRange→model, editorId, filterValidation, filterFont, …) | context struct closing over the real model + converter | PASS |
| `_cachedModelDecorationsResolver`+ViewRange (:24-25,:39-42) | one-entry cache keyed by exact view range | cache fields | PASS |
| `dispose`/`reset` (:44-52) | computer reset + cache clear | `::reset` | PASS |
| `onModelDecorationsChanged` (:54-57) | computer + cache invalidate | `::on_model_decorations_changed` | PASS |
| `onLineMappingChanged` (:59-63) | computer + cache invalidate | `::on_line_mapping_changed` | PASS |
| `getMinimapDecorationsInRange` (:65-67) | computer.getDecorations(range, true, false) | — | DEFERRED (minimap part) |
| `getDecorationsViewportData` (:69-77) | cache-valid check → computer.getDecorations(viewRange,false,false) | `::get_decorations_viewport_data` | PASS |
| `getDecorationsOnLine` (:79-82) | line min/max column range | `::get_decorations_on_line` | PASS |
| `filterValidationDecorations` gate (editorOptions) | `renderValidationDecorations` option: on/off/editable (editable → readOnly ⇒ filter) | option default `editable`: readonly viewer ⇒ filter **on** unless overridden — port the option | PASS |
| Migration: swap `inline_decorations` doubles | `IdentityCoordinatesConverter` → real `CoordinatesConverter` trait; mini `TextModel`/`ModelDecorationOptions` → model-tier types | seam interfaces in the package; doubles remain for its reference suite | PASS |
| Migration: delete simplified `ViewModelDecoration` (`view_model_decorations.mbt`) + eager conversion | replaced by computer + cache | deletion | PASS |
| Migration: restore `ViewModelDecoration → per-line InlineDecoration → LineDecoration` chain in `viewLines` prepare | today `to_view_decorations` short-circuits to renderer types | rewire `view_line_data.mbt` inputs | PASS |
| Migration: marker producer | `marker_decorations_service` keeps its `_markerDecorations` per-model state but stores via `change_decorations` accessor (Monaco `markerDecorationsService.ts` `_handleMarkerChange` shape); frame-bake at `render.mbt:36-39` deleted; no `content_generation` bump for marker changes | re-plumb | PASS |
| Migration: hover producer | `controller_decorations()` (hover highlight) → a hover-owned decoration collection (`delta_decorations` on show/hide); class `has-hover` → `hoverHighlight` + CSS update | re-plumb | PASS |
| Migration: `ViewDecorationsChanged` view event | model `onDidChangeDecorations` → viewer glue pushes typed event; parts return dirty (viewLines: true — inline decorations; DecorationsOverlay: true; others false) | new `ViewEvent` variant (Deviation 3) | PASS |

Member count (Phase 3): **15 rows** (9 source + 6 migration).

Landed notes (2026-07-02):

- **Seam shape.** The promoted `inline_decorations` computer is generic over
  three seams (`InlineDecorationsModel`, `CoordinatesConverter`,
  `InlineDecorationOptions[O]`); the real impls for `@model.TextModel` /
  `@model.Decoration` live in the package, the view-model converter implements
  the converter trait in `view_model` (type's package), and the suite keeps
  Monaco's doubles inside its reference test. `@model.Decoration` still
  carries no `before/afterContentClassName`/`affectsFont` — those computer
  arms are exercised by the suite's doubles only (deviation noted in the
  package header).
- **Missing-members fix.** The computer gained the source's
  `onModelDecorationsChanged`/`onLineMappingChanged` (absent from the
  original quarantined port).
- **`viewModelLines.getDecorationsInRange`** (`:923`) is ported alongside
  (fast path + hidden-line splitting + sort/dedupe) as the context closure's
  target; `ViewModelLines::is_model_line_hidden` answers visibility.
- **Render chain.** `viewport_data_from_view_model` resolves the viewport
  collection via `get_decorations_viewport_data` and clips per line with the
  `LineDecoration.filter` port (`line_decorations_filter`); a clearly-marked
  TRANSITIONAL block still renders `className` decorations as line-internal
  spans (with `showIfCollapsed` 1ch widening) until the Phase-4
  `DecorationsOverlay` takes them over.
- **Producers.** `MarkerDecorations` stores through
  `model.delta_decorations` (ownerId 0), `get_markers` resolves ranges from
  storage, and `decorations_for_resource` (the frame bake) is deleted; the
  hover highlight is a hover-owned `delta_decorations` collection synced at
  flush (`sync_hover_decorations`, ownerId = the viewer's editor id) with
  class `hoverHighlight` (CSS updated).
- **Event.** `ViewDecorationsChanged` is sourced from a
  `decorations_generation` counter the `Viewer` bumps per model
  `onDidChangeDecorations` (Deviation 3); `ViewLines` returns dirty for it
  and its recycler rewrites when the generation moved. Marker changes no
  longer bump `content_generation` (the old marker→`render_feature_update`
  subscription now only refreshes the public diagnostics-count event).
- **Option.** `renderValidationDecorations` is ported at the view-model tier
  with Monaco's `Editable` default; `ViewerOptions` defaults it to `On` — a
  recorded product deviation, because `Editable` hides validation squiggles
  in readonly editors and the viewer's diagnostics rendering is a shipped
  feature.
- **Pulled forward from Phase 4.** The dead `kind == CurrentLine` consumers
  (`line_html.mbt:68` line-class merge, `view_line_data.mbt:100,147`) were
  deleted with the seam rewire (no producer existed); `render_line_class`
  now returns the constant `view-line`.

## Phase 4 — `decorations.ts` `DecorationsOverlay` (whole) + `DecorationKind` retirement

Rendered into the `selections` package (ContentViewOverlays merge), after the
current-line pieces and before the selection pieces — Monaco's registration
order (`view.ts:218-221`: CurrentLine, Selections, IndentGuides, Decorations;
indent guides unported, so Decorations lands between current-line and
selections only if Monaco's z-order demands it — **read the registration
order again at implementation and mirror it exactly**; Monaco's order is
CurrentLine < Selections < Decorations).

### Inventory (Phase 4)

13 members: fields+ctor (:17-29), dispose (:31), 8 event handlers (:39-64),
`prepareRender` (:67-113), `_renderWholeLineDecorations` (:115-139),
`_renderNormalDecorations` (:141-184), `_renderNormalDecoration` (:186-228),
`render` (:230-239). Plus `decorations.css` and the local retirement rows.

### Parity ledger (Phase 4)

| Source member / step (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| ctor/fields (:17-29) | typicalHalfwidthCharacterWidth from fontInfo | prepared `space_width` (existing seam) | PASS |
| event handlers (:39-64) | config/decorations/flush/lines/scroll(top‖width)/zones → dirty | ContentViewOverlays event map already covers; add `ViewDecorationsChanged` | PASS |
| `prepareRender` filter+sort (:67-113) | keep className only; sort zIndex → className → range-starts | pure fn + wbtest | PASS |
| `_renderWholeLineDecorations` (:115-139) | `<div class="cdr {className}" left:0;width:100%>` per visible line in range | pure piece builder | PASS |
| `_renderNormalDecorations` merge loop (:141-184) | showIfCollapsed end-column-1 pullback (:160-162); same-class touching-range merge (:164-168); flush prev | pure fn + wbtest per branch | PASS |
| `_renderNormalDecoration` (:186-228) | linesVisibleRangesForRange; collapsed-range widening to half-width centered (:199-208); shouldFillLineOnLineBreak → width:100% (:211,219) | measured via `measure_line_selection` seam (Deviation 8) | PASS |
| `render` (:230-239) | per-line lookup | flat pieces appended between current-line and selection groups | PASS |
| `decorations.css` | `.cdr { position:absolute; }` | `decorations.css` in selections pkg + css_sources | PASS |
| Retirement: `DecorationKind` + `DecorationSet` deleted (`decorations.mbt`) | consumers moved to options tests | deletion | PASS |
| Retirement: `kind == CurrentLine` consumers (`line_html.mbt:68`, `view_line_data.mbt:100,147`) | dead since the current-line overlay landed 2026-07-02 — verify no producer, then delete | deletion | PASS |
| Retirement: `view_model_decorations.mbt:81` kind copy | gone with the simplified type (Phase 3) | — | PASS |
| Theme CSS: `hoverHighlight`, `rangeHighlight` classes | `--vscode-editor-hoverHighlightBackground` / `-rangeHighlightBackground` already in `theme.css` | static rules for the stock classNames | PASS |

Member count (Phase 4): **12 rows**.

Landed notes (2026-07-02): `decorations_overlay.mbt` in the `selections`
package, registered in the `ContentViewOverlays` merge after the current-line
and selection pieces (re-read `view.ts:218-221` at implementation as
instructed: the order is CurrentLine, Selections, [IndentGuides — unported],
Decorations — decorations render last). The piece computation
(`compute_decoration_overlay_pieces`) is pure and covered by 7 wbtests with
an injected fake measurement (filter/sort, whole-line clamping, same-class
touching merge, `showIfCollapsed` endColumn-1 pullback, collapsed centered
half-width widening incl. JS `Math.round` half-up semantics,
`shouldFillLineOnLineBreak`, different-class no-merge). The measurement seam
gained `measure_line_decorations` (`keep_empty=true`, so collapsed ranges
yield their caret rect — Deviation 8). `typicalHalfwidthCharacterWidth` is
the prepared `space_width` (existing seam). The `className === 'findMatch'`
argument of `linesVisibleRangesForRange` is dropped (no find feature).
Retirements executed: `DecorationKind`, `DecorationSet`, and `Decoration`'s
legacy `range`/`kind` fields deleted (`Decoration` is now exactly the
`ModelDecorationOptions` subset; `create_decoration_option` matches Monaco's
marker-only signature); the Phase-3 TRANSITIONAL className line-span block
deleted — `className` decorations render only through the overlay. Exit-gate
grep confirms no decoration `kind` remains. `rangeHighlight` static rule
added in `decorations.css`; `hoverHighlight` lives in `hover.css` (Phase 3).

## Phase 5 — public `Viewer::` decoration API (`codeEditorWidget.ts` slice)

| Source member | Behavior | MoonBit symbol | Status |
|---|---|---|---|
| `deltaDecorations(old, new)` | model delta with the editor's ownerId | `Viewer::delta_decorations` | TODO |
| `removeDecorations(ids)` | delta to empty | `Viewer::remove_decorations` | TODO |
| `getLineDecorations(line)` | model query with ownerId + filterOutValidation per option | `Viewer::get_line_decorations` | TODO |
| `getDecorationsInRange(range)` | same, range | `Viewer::get_decorations_in_range` | TODO |
| `createDecorationsCollection` | sugar collection | — | DEFERRED (until a host asks) |
| headless-harness proof | `delta_decorations` from a host → decorations queryable + render input carries them | `viewer/test_viewer_wbtest.mbt` cases | TODO |

## Test matrix (Phase 4 of the playbook)

Behavior-switching variables, each with a case that takes it:

- **Tree ops:** insert/delete/change interleavings (gen01–gen18), delta
  overflow (force-normalize), duplicate/equal intervals (`intervalCompare`
  tiebreak), empty tree fast paths.
- **Search filters:** ownerId {0, match, mismatch} × filterOutValidation
  {on/off × squiggly-vs-plain className} × onlyMarginDecorations ×
  overviewRulerOnly (tree1 routing).
- **Delta semantics:** old-id reuse vs fresh node; unknown old ids skipped;
  empty-old/empty-new fast path; re-entrancy warn; one event per
  deferred-emit bracket covering N ops.
- **Options normalization:** cleanClassName strips illegal chars; stickiness
  default; zIndex default; tree1 migration when `overviewRuler` appears/
  disappears via `changeDecorationOptions`.
- **Viewport conversion:** cache hit (same view range) vs miss; model↔view
  conversion around folded ranges (line-mapping change invalidates);
  `filterValidationDecorations` on/off.
- **Overlay rendering:** isWholeLine spanning partially-visible ranges;
  same-class touching merge; showIfCollapsed pullback at endColumn=1;
  collapsed-range half-width widening; shouldFillLineOnLineBreak; zIndex/
  className sort stability. All as pure-piece wbtests (no browser DOM pins,
  per the 2026-07-02 conformance-suite decision); end-to-end behavior via
  the headless harness; visual sanity manually or via smoke if a real-pointer
  flow exists.

## Exit gate (Phase 5 of the playbook)

- [ ] inventory reconciled (rows == members) per phase; report done/deferred/N-A
- [ ] every ported fn diff-reviewed side-by-side vs source
- [ ] matrix covered; `moon test --target all` green; headless harness cases green
- [ ] deviations documented at code sites (1–8 above)
- [ ] replacement map executed: `DecorationKind`/`DecorationSet`/simplified
      `ViewModelDecoration`/frame-baked marker path all deleted; grep proves
      no `kind` field remains
- [ ] closing self-audit pasted here

## Suggested commit slicing

1. Phase 1 tree + reference suite (pure; no product wiring).
2. Phase 2 model storage + emitter + options evolution + reference suite
   (product still renders via the old path — storage is written but unread).
3. Phase 3a `inline_decorations` promotion + `ViewModelDecorations` rebase
   behind the existing render-input seam (old and new agree on markers+hover).
4. Phase 3b producer re-plumb + `ViewDecorationsChanged` event + delete the
   frame-bake and simplified types.
5. Phase 4 DecorationsOverlay + kind retirement + CSS.
6. Phase 5 public API + headless-harness proof + docs/memory updates.

Each slice lands `just check` + `moon test --target all` green; per
AGENTS.md, commit per slice.
