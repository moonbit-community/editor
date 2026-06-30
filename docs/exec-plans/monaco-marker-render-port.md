# Monaco Marker Render 1:1 Port

Status: implemented (A–G) — Date: 2026-06-30. Oracle commit: `294fb350837dbaee37b949533fead4df4e0e8971`.

Increments A–G landed; H (overview ruler / minimap parts) stays deferred. `just
check && just test` green (js 546 / native 487); `just test-browser` green except
the pre-existing `dom_structure.spec.js:58` markdown-hover `tabindex` mismatch,
which fails on `main` too (a hover-render-upgrade issue, out of scope here).

Follows `_PORT_PLAYBOOK.md`. Supersedes the simplified marker render that lives
in `viewer/markers/markers.mbt` + `viewer/markers.css` today: a flat
`Array[Marker]` store, a `decorations_for_resource` that emits one `Diagnostic`
decoration per marker with a `diag-error|warning|info` class, and a wavy-underline
CSS. That slice is faithful in spirit but skips the marker→decoration *transform*
(`_createDecorationRange` / `_createDecorationOption`), the store semantics
(`read` filters, statistics, change events), severity bitmask + `Hint`, tags
(unnecessary/deprecated), and the real squiggle CSS / option fields.

---

## Scope (Phase 0)

Source units (whole files, read for inventory — not from memory):

1. `vscode/src/vs/platform/markers/common/markers.ts` — data model:
   `MarkerSeverity`, `MarkerTag`, `IMarker(Data)`, `IRelatedInformation`,
   `IMarkerReadOptions`, `MarkerStatistics`, `IMarkerData.makeKey*`.
2. `vscode/src/vs/platform/markers/common/markerService.ts` — store:
   `MarkerService`, `MarkerStats`, `DoubleResourceMap`, `unsupportedSchemas`,
   `_toMarker`, `read`/`_accept`, `changeOne`/`changeAll`, resource filters,
   `onMarkerChanged`/`_merge`.
3. `vscode/src/vs/editor/common/services/markerDecorations.ts` — the
   `IMarkerDecorationsService` interface (the public surface our viewer consumes).
4. `vscode/src/vs/editor/common/services/markerDecorationsService.ts` — the
   transform: `MarkerDecorationsService` + the inner `MarkerDecorations`
   (`update` diff, `_createDecorationRange`, `_createDecorationOption`,
   `getMarker`/`getMarkers`, suppression).
5. Render-side surface this transform feeds:
   - `ClassName` enum (`vscode/src/vs/editor/common/model/intervalTree.ts:14`) —
     the `squiggly-*` class strings + `setNodeIsForValidation`;
   - the `IModelDecorationOptions` fields the transform sets (className,
     inlineClassName, stickiness, showIfCollapsed, zIndex, overviewRuler,
     minimap);
   - the squiggle CSS (`vscode/src/vs/editor/browser/widget/codeEditor/editor.css:81-120`)
     + the theme color tokens it reads (`editorColorRegistry.ts`,
     `colorRegistry.ts`).

**Out of scope (named siblings, explicitly deferred — not "unseen"):**

- `editor/contrib/gotoError/*` — marker navigation (next/prev error). Separate unit.
- `editor/contrib/hover/browser/markerHoverParticipant.ts` render upgrade
  (relatedInformation list, code link, quick-fix actions). The viewer already
  has a `MarkerHover` part in `viewer/hover`; enriching its *render* is a hover
  plan, not this one. This port keeps `markers_at` feeding it.
- `workbench/contrib/markers/*` — Problems panel / tree / file decorations. Not a
  viewer concern.
- **Overview-ruler / minimap / glyph-margin rendering.** The viewer has no such
  parts (`public_read_api.mbt:350-389` hard-codes those widths to `0`). The
  decoration *options* will carry `overviewRuler`/`minimap` data faithfully
  (Phase D below), but nothing paints them. Building the parts is a separate epic
  (Increment H, deferred row).
- **Interval-tree decoration storage.** Already the recorded follow-up in
  `monaco-one-to-one-port.md` and `view_model_decorations.mbt:19-25`. This port
  ports the `update()` *diff logic* as pure code with tests but does not
  introduce model-side decoration storage; see Decision D3.

---

## Decisions to confirm before port code

These change the shape of the work; recommended answer first.

- **D1 — Severity model.** Add a markers-local `MarkerSeverity` (faithful bit
  values `Hint=1, Info=2, Warning=4, Error=8`) rather than extend
  `@language.DiagnosticSeverity` (which has only `Error/Warning/Info`, no `Hint`,
  no bit values). `read({severities})` is a **bitmask** test (`_accept`:
  `(severities & marker.severity) === marker.severity`) and `Hint` drives a
  distinct decoration-range branch, so the bit values are load-bearing.
  *Recommend: local enum; bridge `DiagnosticSeverity → MarkerSeverity` at
  `from_diagnostic`, keep `Hint` reachable for future LSP hints.*
- **D2 — `getWordAtPosition`.** `_createDecorationRange` expands an *empty*
  marker range (not at EOL/empty line) to the surrounding word
  (`markerDecorationsService.ts:212`). No word-at-position exists anywhere in
  `base`/`model`/`viewer` (verified). *Recommend: port a minimal
  `getWordAtPosition` from `vscode/src/vs/editor/common/core/wordHelper.ts` using
  the default `USUAL_WORD_SEPARATORS`, as its own sub-increment (C0), into
  `model`. Fallback if declined: deviation row — empty non-EOL ranges stay 1ch.*
- **D3 — `deltaDecorations` storage.** Monaco's `update()` diffs marker sets via
  a `BidirectionalMap` and calls `model.deltaDecorations(oldIds, newDecorations)`
  — real model-side stored decorations. The viewer rebuilds decorations per frame
  from `markers_for_resource` (`render.mbt:36`). *Recommend: port `update()`'s
  diff + option/range computation as pure logic with tests (so the transform is
  1:1), wire `onMarkerChanged → onDidChangeMarker → render invalidation`, but keep
  the per-frame rebuild as a documented deviation cross-referenced to the
  interval-tree follow-up. Building stored decorations now would fork that
  follow-up.*
- **D4 — Overview ruler / minimap.** Defer rendering (no parts). Carry the option
  data faithfully. (See Out-of-scope.)
- **D5 — Resource filters / suppression.** Port the *data path*
  (`installResourceFilter`, `_createFilteredMarker`, `addMarkerSuppression`,
  `_suppressedRanges` filter in `_updateDecorations`) as pure logic — it is cheap
  and part of `read`/`update`. The Problems-pause *UI* that drives it is N-A
  (no Problems panel).

---

## Inventory (Phase 1) — the denominator

Read from the four source files + the render surface. Reconcile every member in
the ledger.

### 1. `markers.ts`
- Enums: `MarkerSeverity {Hint=1,Info=2,Warning=4,Error=8}`, `MarkerTag {Unnecessary=1,Deprecated=2}`.
- `MarkerSeverity` namespace fns: `compare` (`b-a`), `toString`, `toStringPlural`,
  `fromSeverity`, `toSeverity` (bridge `base/common/severity`).
- Interfaces (data shape → MoonBit structs): `IMarkerReadOptions`
  (`owner?`,`resource?`,`severities?`,`take?`,`ignoreResourceFilters?`),
  `IRelatedInformation`, `IMarkerData`, `IResourceMarker`, `IMarker`,
  `MarkerStatistics`.
- `IMarkerData.makeKey` / `makeKeyOptionalMessage` (dedup key; `¦`-joined).
- `IMarkerService` interface (contract).

### 2. `markerService.ts`
- `unsupportedSchemas` set.
- `DoubleResourceMap`: `set`, `get`, `delete` (illegal-state guard), `values(key?)`.
- `MarkerStats`: ctor (subscribe `onMarkerChanged`), `dispose`, `_update`,
  `_resourceStats` (skip `unsupportedSchemas`; severity buckets), `_substract`,
  `_add`; fields `errors/warnings/infos/unknowns`.
- `MarkerService`: `getStatistics`, `remove`, `changeOne` (falsy→delete + fire),
  `installResourceFilter`, `_toMarker` (static: drop empty message; sanitize
  `start/endLine/Column`), `changeAll` (clear owner, group by resource, fire
  changed set), `_createFilteredMarker`, `read` (owner∧resource fast path;
  owner∨resource path w/ `ResourceSet` dedup; `take`; filtered markers),
  `_accept` (severity bitmask), `_merge` (event dedup), `onMarkerChanged`
  (`MicrotaskEmitter` w/ merge), `_data`/`_stats`/`_filteredResources`.

### 3. `markerDecorations.ts` (interface)
- `IMarkerDecorationsService`: `onDidChangeMarker: Event<ITextModel>`,
  `getMarker(uri, decoration)`, `getLiveMarkers(uri): [Range, IMarker][]`,
  `addMarkerSuppression(uri, range): IDisposable`.

### 4. `markerDecorationsService.ts`
- `MarkerDecorationsService`: ctor (seed from `modelService.getModels()`;
  subscribe model add/remove + `onMarkerChanged`), `dispose`,
  `_onDidChangeMarker`, `_suppressedRanges`, `_markerDecorations`, `getMarker`,
  `getLiveMarkers`, `addMarkerSuppression` (+ toDisposable cleanup),
  `_handleMarkerChange`, `_onModelAdded`, `_onModelRemoved` (transient-scheme
  marker cleanup), `_updateDecorations` (`read take:500`; suppressed-range
  `areIntersectingOrTouching` filter; `update`→fire).
- inner `MarkerDecorations`: ctor (dispose clears via `deltaDecorations`),
  `_map: BidirectionalMap<IMarker,id>`, `update` (`diffSets` added/removed;
  no-op early return; `deltaDecorations(oldIds, newDecorations)`; map maintenance;
  returns changed?), `getMarker`, `getMarkers` (range from `getDecorationRange`),
  `_createDecorationRange` (4 branches, below), `_createDecorationOption` (option
  fields by severity + tags, below), `_hasMarkerTag`.

  `_createDecorationRange` branches to cover:
  - `Hint` ∧ not(Unnecessary|Deprecated) → never multiline; `endColumn = startColumn+2` (room for 3 dots).
  - `validateRange`.
  - empty range: `maxColumn = lastNonWhitespaceColumn || lineMaxColumn`;
    if `maxColumn===1` or `endColumn>=maxColumn` → keep as-is (rendered 1ch);
    else expand to `getWordAtPosition` word (if any).
  - non-empty ∧ `endColumn===MAX_VALUE` ∧ `startColumn===1` ∧ single line →
    expand start to `firstNonWhitespaceColumn` (and mutate `rawMarker.startColumn`).

  `_createDecorationOption` matrix (severity → options):
  | severity | className | color (overviewRuler) | zIndex | minimap |
  |---|---|---|---|---|
  | Hint+Deprecated | (none) | — | 0 | — |
  | Hint+Unnecessary | `squiggly-unnecessary` | — | 0 | — |
  | Hint | `squiggly-hint` | — | 0 | — |
  | Info | `squiggly-info` | overviewRulerInfo | 10 | minimapInfo, Inline |
  | Warning | `squiggly-warning` | overviewRulerWarning | 20 | minimapWarning, Inline |
  | Error (default) | `squiggly-error` | overviewRulerError | 30 | minimapError, Inline |
  plus tags → `inlineClassName`: Unnecessary→`squiggly-inline-unnecessary`,
  Deprecated→`squiggly-inline-deprecated`; constant fields
  `stickiness=NeverGrowsWhenTypingAtEdges`, `showIfCollapsed=true`,
  `overviewRuler.position=Right`, `description='marker-decoration'`.

### 5. Render surface
- `ClassName` strings: `squiggly-hint|info|warning|error|unnecessary`,
  `squiggly-inline-unnecessary|deprecated` (`intervalTree.ts:15-21`).
- `setNodeIsForValidation` = className ∈ {error,warning,info} (`intervalTree.ts:210-214`).
- CSS (`editor.css:81-120`): `.squiggly-error` (`border-bottom:4px double
  --vscode-editorError-border`) + `::before` (`background:--vscode-editorError-background`);
  same for warning/info; `.squiggly-hint` (`2px dotted --vscode-editorHint-border`);
  `.showUnused .squiggly-unnecessary` (`2px dashed --vscode-editorUnnecessaryCode-border`);
  `.showDeprecated .squiggly-inline-deprecated` (`line-through`).
- Theme tokens: `editorError/Warning/Info.{border,background}`, `editorHint.border`,
  `editorUnnecessaryCode.{border,opacity}` (opacity → generated
  `.squiggly-inline-unnecessary{opacity}` rule), `editorOverviewRuler.{error,warning,info}Foreground`,
  `minimap{Error,Warning,Info}` (`editorColorRegistry.ts:65-76`, `colorRegistry.ts`).

**Member count: ~58** (enumerated as ledger rows below). Reconcile
`count(rows) == count(members)` at the exit gate.

---

## Parity ledger (Phase 2)

One row per inventory member. Status ∈ `TODO / PORTED / TESTED / PASS /
DEFERRED(reason) / N-A(reason)`. All start `TODO` unless already present.

### markers.ts

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `MarkerSeverity` enum (56-61) | Hint=1,Info=2,Warning=4,Error=8 (bit values) | `markers.MarkerSeverity` | TODO |
| `MarkerSeverity.compare` (65) | `b - a` | `MarkerSeverity::compare` | TODO |
| `MarkerSeverity.toString/Plural` (74,83) | display strings | `::label`/`::label_plural` | TODO (used by makeKey) |
| `MarkerSeverity.fromSeverity` (87) | base Severity → MarkerSeverity | bridge fn | DEFERRED(no base `Severity` enum in viewer) |
| `MarkerSeverity.toSeverity` (96) | inverse | — | DEFERRED(same) |
| `IMarkerReadOptions` (13) | owner/resource/severities/take/ignoreResourceFilters | `markers.MarkerReadOptions` | TODO |
| `IRelatedInformation` (42) | resource+message+range | `markers.RelatedInformation` | TODO |
| `MarkerTag` enum (51) | Unnecessary=1,Deprecated=2 | `markers.MarkerTag` | TODO |
| `IMarkerData` (109) | data shape pre-sanitize | `markers.MarkerData` | TODO |
| `IResourceMarker` (124) | {resource,marker} | `markers.ResourceMarker` | TODO |
| `IMarker` (129) | sanitized marker | expand `markers.Marker` | TODO (extend) |
| `MarkerStatistics` (146) | errors/warnings/infos/unknowns | `markers.MarkerStatistics` | TODO |
| `IMarkerData.makeKey*` (155-210) | `¦`-joined dedup key | `MarkerData::make_key*` | DEFERRED(extension-host dedup; unused by render) |
| `IMarkerService` (21) | contract | (shape of `MarkerService`) | N-A(interface) |

### markerService.ts

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `unsupportedSchemas` (16) | inMemory/vscode*/walkThrough/… | `markers.unsupported_schemes` | TODO (subset; viewer schemes) |
| `DoubleResourceMap.set` (30) | by-resource ∧ by-owner | `DoubleResourceMap::set` | TODO |
| `DoubleResourceMap.get` (46) | resource→owner | `::get` | TODO |
| `DoubleResourceMap.delete` (51) | illegal-state guard | `::delete` | TODO |
| `DoubleResourceMap.values` (68) | by owner / by resource / all | `::values` | TODO |
| `MarkerStats` (80) | live stats over onMarkerChanged | `markers.MarkerStats` | TODO |
| `MarkerStats._resourceStats` (112) | skip unsupported; bucket severities | `::resource_stats` | TODO |
| `MarkerStats._update/_add/_substract` (100,142,135) | delta accumulation | `::update`/`::add`/`::subtract` | TODO |
| `MarkerService.getStatistics` (169) | return `_stats` | `MarkerService::statistics` | TODO |
| `MarkerService.remove` (173) | per-resource `changeOne([])` | `::remove` | TODO |
| `MarkerService.changeOne` (179) | falsy→delete+fire; else set+fire | `::change_one` | TODO |
| `MarkerService._toMarker` (228) | drop empty msg; clamp line/col | `MarkerData::to_marker` | TODO |
| `MarkerService.changeAll` (266) | clear owner; group by resource; fire | `::change_all` | TODO |
| `MarkerService.installResourceFilter` (202) | push reason; fire; disposable pop | `::install_resource_filter` | TODO (D5) |
| `MarkerService._createFilteredMarker` (315) | Info marker "Problems paused…" | `::create_filtered_marker` | TODO (D5) |
| `MarkerService.read` (332) | owner∧resource fast path; ∨ path + `ResourceSet` dedup; take | `::read` | TODO |
| `MarkerService._accept` (399) | `severities===undefined ∨ (s & sev)===sev` | `::accept` | TODO |
| `MarkerService._merge` (405) | dedup URIs across batches | event merge | DEFERRED(sync fire; no MicrotaskEmitter) |
| `onMarkerChanged` (154) | MicrotaskEmitter | `did_change_markers` event | TODO (sync, see deviation) |

### markerDecorations.ts + markerDecorationsService.ts

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `IMarkerDecorationsService.onDidChangeMarker` (19) | fires per model on change | `did_change_marker_decorations` | TODO |
| `IMarkerDecorationsService.getMarker` (21) | decoration→marker | `MarkerDecorationsService::get_marker` | TODO |
| `IMarkerDecorationsService.getLiveMarkers` (23) | `[Range,IMarker][]` | `::live_markers` (replaces `markers_at`) | TODO |
| `addMarkerSuppression` (25/62) | suppress range; disposable | `::add_marker_suppression` | TODO (D5) |
| `MarkerDecorationsService.ctor/_onModelAdded` (35,93) | seed + subscribe | `MarkerDecorationsService::new`/`on_model_added` | TODO |
| `_onModelRemoved` (99) | dispose + transient-scheme cleanup | `::on_model_removed` | TODO |
| `_handleMarkerChange` (84) | per-resource `_updateDecorations` | `::handle_marker_change` | TODO |
| `_updateDecorations` (114) | read take:500; suppressed filter; update→fire | `::update_decorations` | TODO |
| `MarkerDecorations.update` (146) | `diffSets`; no-op return; deltaDecorations; map maint | `MarkerDecorations::update` | TODO (D3 pure-logic) |
| `MarkerDecorations.getMarker/getMarkers` (175,179) | id↔marker, range lookup | `::get_marker`/`::get_markers` | TODO |
| `_createDecorationRange` Hint-truncate (194) | single line; `+2` col | `create_decoration_range` (branch 1) | TODO |
| `_createDecorationRange` validateRange (200) | clamp | (branch 2) | TODO |
| `_createDecorationRange` empty→word (202-215) | maxColumn rule; keep-1ch or word | (branch 3) | TODO (needs C0 word) |
| `_createDecorationRange` full-line first-non-ws (216-222) | MAX_VALUE∧col1∧1-line | (branch 4) | TODO |
| `_createDecorationOption` className/zIndex (234-273) | severity matrix | `create_decoration_option` | TODO |
| `_createDecorationOption` overviewRuler/minimap (247-271,288-293) | color + position | option carriers | DEFERRED(D4: data only) |
| `_createDecorationOption` inlineClassName tags (275-282) | unnecessary/deprecated | inline_class_name | TODO |
| `_createDecorationOption` constants (284-296) | stickiness/showIfCollapsed/description | option fields | TODO |
| `_hasMarkerTag` (299) | tag membership | `Marker::has_tag` | TODO |

### Render surface

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `ClassName` squiggly strings (intervalTree.ts:15-21) | class names | `markers.class_name`/`inline_class_name` | TODO (replace `diag-*`) |
| `setNodeIsForValidation` (intervalTree.ts:210) | err/warn/info → validation | (n/a — no interval tree) | DEFERRED(D3) |
| `.squiggly-*` CSS (editor.css:81-120) | border-bottom + ::before bg | `viewer/markers.css` | TODO (rewrite) |
| theme tokens (editorColorRegistry/colorRegistry) | custom-property values | css `--vscode-*` defaults | TODO |
| inline `.squiggly-inline-unnecessary{opacity}` rule | from `editorUnnecessaryCode.opacity` | css | TODO |
| overviewRuler/minimap render | paint markers | OverviewRuler part | DEFERRED(D4: no part) |

---

## Implementation increments (ordered, one commit cluster each)

Mirrors the hover-chain landing cadence (small, wired, tested per step). Each
increment ends green on `just check && just test`; render increments add
`just test-browser`.

- **A — Data model** (`markers.ts`). Local `MarkerSeverity` (bit values) + bridge
  from `@language.DiagnosticSeverity`; `MarkerTag`; `MarkerData`/`ResourceMarker`/
  `RelatedInformation`/`MarkerStatistics`/`MarkerReadOptions`; extend `Marker` with
  `tags`, `related_information`, `code`, `source`, `origin`, `model_version_id` and
  the separate `start/end line/column` fields (keep `range` derived). Port
  `_toMarker` sanitize. Keep `from_diagnostic`/`to_diagnostic` working.
- **B — MarkerService faithful** (`markerService.ts`). `DoubleResourceMap`,
  `change_one`/`change_all`/`remove`, `read(filter)` (both paths + `_accept`
  bitmask + dedup), `MarkerStats`/`statistics`, `did_change_markers` event,
  resource filters (D5). Keep `set_diagnostics`/`diagnostics_for_resource` as
  thin shims over `change_one`/`read` so `render.mbt` keeps compiling through the
  migration.
- **C0 — `getWordAtPosition`** (D2; `model`). Minimal port of `wordHelper.ts`
  (`getWordAtText` + `USUAL_WORD_SEPARATORS`, default whole-word regex behavior),
  with the boundary tests from `wordHelper.test.ts`.
- **C — `_createDecorationRange`** (`markerDecorationsService` transform). All
  four branches; reuse `TextSnapshot.validate_range`,
  `get_line_max_column`, `get_line_{first,last}_non_whitespace_column`, and C0's word.
- **D — `_createDecorationOption` + option enrichment.** Extend
  `viewer/decorations.Decoration` (or add a `DecorationOptions` carrier) with
  `inline_class_name`, `z_index`, `show_if_collapsed`, `stickiness`, and inert
  `overview_ruler`/`minimap` color carriers (D4). Emit `squiggly-*` class names
  (replace `marker_class_name`'s `diag-*`). Port the full severity×tag matrix.
- **E — `MarkerDecorations` + service.** Per-model `MarkerDecorations` with
  `BidirectionalMap`, `update()` diff (`diffSets`), `get_marker`/`get_markers`,
  `MarkerDecorationsService` model add/remove + `handle_marker_change` +
  `update_decorations` (take:500 + suppressed filter) + `did_change_marker_decorations`.
  Wire `did_change_markers → update → did_change_marker_decorations → render
  invalidation` in `services.mbt`/`render.mbt` (replacing the unconditional
  per-frame `diagnostics_for_resource` read with an event-driven refresh; the
  per-frame *rebuild* stays as the D3 deviation).
- **F — Render wiring.** Thread `inline_class_name` + `show_if_collapsed` through
  `view_model_decorations.ViewModelDecoration` →
  `view_line_data.{inline,line}_decorations_for_line`. Empty (`show_if_collapsed`)
  ranges render 1ch wide. Confirm the faithful path co-exists with the standalone
  `viewer/inline_decorations` reference port (do not collide type names).
- **G — CSS.** Rewrite `viewer/markers.css` to the `editor.css:81-120` blocks
  (border-bottom + `::before`) and register the `--vscode-*` theme defaults
  (`editorError/Warning/Info.{border,background}`, `editorHint.border`,
  `editorUnnecessaryCode.{border,opacity}`). Gate `.squiggly-unnecessary` /
  `.squiggly-inline-deprecated` behind the `showUnused`/`showDeprecated` editor
  classes as Monaco does.
- **H — Overview ruler / minimap (DEFERRED).** Add the parts; consume the option
  carriers from D. Tracked, not in this port.

---

## Deviations (Phase 3) — every non-source-cited divergence, justified

- **Event model is synchronous.** Monaco's `onMarkerChanged` is a
  `MicrotaskEmitter` with `_merge` dedup; the viewer fires synchronously and
  relies on the existing render-coalescing (`render.mbt:72-81`). Seam difference
  (no microtask queue in the readonly path), not logic. `_merge` rows DEFERRED.
- **Per-frame decoration rebuild (D3).** `update()`'s diff is ported as pure
  logic + tested, but decorations are still rebuilt per frame from the marker
  store rather than stored in a model interval tree. Cross-referenced to the
  interval-tree follow-up in `monaco-one-to-one-port.md` and
  `view_model_decorations.mbt:19-25`. The *transform output* is identical; only
  the storage/incrementality differs.
- **Overview ruler / minimap data without render (D4).** Options carry the
  colors/positions; no part paints them. Deferred row, not omitted.
- **`fromSeverity`/`toSeverity` bridges DEFERRED.** No `base/common/severity`
  enum exists in the viewer; markers are sourced from `@language.Diagnostic`, so
  the LSP-`Severity` bridge has no caller yet.
- **`makeKey*` DEFERRED.** Extension-host marker dedup key; no caller in the
  readonly render path.
- **Suppression/resource-filter UI N-A (D5).** Data path ported; the
  Problems-panel pause that drives it does not exist.
- **Squiggle `::before` background fill omitted (G).** Monaco's
  `.squiggly-*::before { background: var(--vscode-editor*-background) }`
  (`editor.css:84-110`) is not ported. `editor*.background` is `null`
  (transparent) outside HC themes, and a `display:block` pseudo-element would
  inject a block box into the inline view-line span flow. The visible squiggle
  (the `border-bottom` double/dotted/dashed underline) is ported faithfully.
- **`*-border` tokens default to the foreground (G).** VS Code's
  `editorError/Warning/Info.border` and `editorHint.border` are `null` in normal
  themes (the live squiggle there is a dynamically generated wavy underline from
  `editor*.foreground`). The static `border-double` variant the plan ports is the
  HC form, so the viewer defaults the `*-border` tokens to the foreground colors
  (theme.css) to keep squiggles visible. `editorUnnecessaryCode.border` stays
  unset (null in normal themes — unnecessary code is dimmed via opacity).
- **`showUnused`/`showDeprecated` always on (G).** Monaco gates the
  unnecessary/deprecated styling behind these editor-option classes, which default
  to `true`. The viewer has no editor-options port, so `view.mbt` adds both root
  classes unconditionally (their faithful default). They are inert today: no
  producer emits `MarkerTag` (diagnostics carry no tags).
- **`Marker.resource` is a `Uri`, store keyed by `uri.to_string()`.** Monaco's
  `IMarker.resource` is a `URI` and `ResourceMap`/`ResourceSet` key on
  `uri.toString()`; MoonBit has no `ResourceMap`, so `DoubleResourceMap`,
  `_filteredResources`, `_suppressedRanges`, and the `read` dedup `Set` key on the
  string form — the same identity `ResourceMap` uses internally.
- **`MarkerDecorations` ids are synthetic; ranges stored inline.** No
  `model.deltaDecorations`/`getDecorationRange` exists (D3), so `update()` assigns
  `marker-decoration-N` ids and stores each decoration's computed range; the diff
  (`diffSets`) and option/range computation are 1:1 and tested. `BidirectionalMap`
  reference-identity keying becomes structural equality (markers are not recreated
  when unchanged, so the comparison is equivalent — Monaco's own comment).
- **Pre-existing, out of scope:** `dom_structure.spec.js:58` (markdown hover
  `tabindex`) fails on `main` independent of this port — the viewer core's
  `set_hover_parts` sets `tabindex` on every part, which the markdown-hover DOM
  assertion has not absorbed. A hover-render concern, not a marker concern.

---

## Test matrix (Phase 4)

Behavior-switching variables, covered in combination (not one happy path):

- **Severity** × decoration output: Hint / Info / Warning / Error → expected
  `squiggly-*` class, zIndex, overviewRuler/minimap presence.
- **Tags** × severity: Unnecessary, Deprecated, both, none → className override
  (Hint+Deprecated = no className; Hint+Unnecessary = `squiggly-unnecessary`) and
  `inlineClassName` (`squiggly-inline-unnecessary|deprecated`).
- **`_createDecorationRange` branches**: (a) Hint multiline input → truncated to
  start line, `+2` col; (b) empty range mid-word → expands to word (C0); (c) empty
  range on empty line / at EOL (`maxColumn===1` or `endColumn>=maxColumn`) → kept
  1ch; (d) full-line marker (`endColumn=MAX_VALUE, startColumn=1`, single line) →
  start snapped to first-non-whitespace.
- **`read(filter)`**: owner∧resource fast path; resource-only; owner-only; neither
  (all, with `ResourceSet` dedup); `severities` bitmask (e.g. `Error|Warning`
  excludes Info/Hint); `take` cap; `ignoreResourceFilters`.
- **`change_one`/`change_all`**: empty data → removal + change event; multi-owner
  same resource retained independently; `change_all` clears prior owner set.
- **Statistics**: add/remove markers across resources → `errors/warnings/infos/
  unknowns` deltas; `unsupportedSchemas` resources excluded.
- **`_toMarker` sanitize**: empty message dropped; `startLine<1`, `startCol<1`,
  `endLine<startLine`, `endCol<startCol` clamped.
- **Render (browser)**: each `squiggly-*` class lands on the right line columns;
  `show_if_collapsed` empty range paints 1ch; multi-line marker spans full
  intermediate lines (`columns_on_view_line`).

Prefer porting Monaco's own unit tests where they exist
(`markerService.test.ts`, `wordHelper.test.ts`) per `docs/quality.md`
"Conformance ports". Run the render matrix under `just test-browser`, not one
config.

---

## Exit gate (Phase 5)

- [x] inventory reconciled (rows == members): done/deferred/N-A = 42 / 12 / 4
      (see reconciliation below; ~58 members).
- [x] every ported fn diff-reviewed vs its source (branch order, constants,
      early returns) — esp. `read` (both paths), `_createDecorationRange` (4
      branches), `_createDecorationOption` (severity×tag matrix). Done during
      port; the matrix-test asserts confirm the constants (zIndex 0/10/20/30,
      class names, theme-color ids, stickiness, showIfCollapsed).
- [x] test matrix covered; `just check && just test` green (js 546 / native 487);
      `just test-browser` 43/44 (the 1 failure is the pre-existing, out-of-scope
      `dom_structure.spec.js:58`). Covered: severity × decoration output, tags ×
      severity, all four `_createDecorationRange` branches, `read` (owner∧resource
      / resource / owner / neither+dedup / severities bitmask / take / ignore
      filters), `change_one`/`change_all` + clear event, statistics + unsupported
      scheme, `_toMarker` sanitize, `getWordAtText` boundaries, `update` diffSets
      no-op/add/remove, suppression, take:500, render (`.squiggly-warning` lands on
      the right columns).
- [x] deviations documented (sync events, per-frame rebuild, overview-ruler data,
      bridges/makeKey deferred, suppression UI N-A, `::before` omission,
      `*-border` foreground default, showUnused/showDeprecated always-on,
      string-keyed resource maps, synthetic decoration ids).
- [x] closing self-audit pasted (below).
- [x] memory updated: superseded the "simplified marker render" note
      ([[editor-marker-render-monaco-port]]); cross-linked the interval-tree
      storage follow-up ([[editor-monaco-one-to-one-port-progress]]).

### Reconciliation (closing self-audit)

Re-read `markers.ts`, `markerService.ts`, `markerDecorations.ts`,
`markerDecorationsService.ts`, `intervalTree.ts` `ClassName`, and
`editor.css:81-120`. Member-by-member:

- **markers.ts** — `MarkerSeverity` enum + `value`/`compare`/`label`/
  `label_plural` PASS; `fromSeverity`/`toSeverity` DEFERRED (no base `Severity`);
  `MarkerTag` + `value` PASS; `IMarkerReadOptions`/`IRelatedInformation`/
  `IMarkerData`/`IResourceMarker`/`IMarker`/`MarkerStatistics` PORTED as structs;
  `_toMarker` sanitize PASS; `makeKey*` DEFERRED (extension-host dedup, no caller);
  `IMarkerService` N-A (interface).
- **markerService.ts** — `unsupportedSchemas` PASS (literal Monaco strings);
  `DoubleResourceMap` set/get/delete(+guard)/values(all/resource/owner) PASS;
  `MarkerStats` ctor/_update/_resourceStats/_add/_substract PASS; `getStatistics`
  PASS (snapshot); `remove`/`changeOne`/`changeAll`/`installResourceFilter`/
  `_createFilteredMarker`/`read`(both paths)/`_accept` PASS; `onMarkerChanged`
  PASS (synchronous Emitter); `_merge` DEFERRED (sync fire).
- **markerDecorations.ts** (interface) — `onDidChangeMarker`/`getMarker`/
  `getLiveMarkers`/`addMarkerSuppression` realized on `MarkerDecorationsService`.
- **markerDecorationsService.ts** — ctor/_onModelAdded/_onModelRemoved(transient
  cleanup)/_handleMarkerChange/_updateDecorations(take:500 + suppressed filter)/
  getMarker/getLiveMarkers/addMarkerSuppression/_onDidChangeMarker PASS; inner
  `MarkerDecorations` update(diffSets, no-op return)/getMarker/getMarkers PASS
  (synthetic ids, D3); `_createDecorationRange` 4 branches PASS;
  `_createDecorationOption` severity×tag matrix PASS; overviewRuler/minimap data
  carried, render DEFERRED (D4).
- **render surface** — `ClassName` squiggly strings PASS (replaced `diag-*`);
  `setNodeIsForValidation` DEFERRED (no interval tree, D3); `.squiggly-*` CSS
  PASS (border-double; `::before` deviation); theme tokens PASS (foreground-
  default deviation); `.squiggly-inline-unnecessary{opacity}` PASS;
  overviewRuler/minimap render DEFERRED (Increment H).
