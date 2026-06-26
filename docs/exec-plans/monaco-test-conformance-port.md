# Monaco Test Conformance Port Plan

## Goal

Prove the "copy Monaco's logic" port is complete and correct by porting
Monaco/VS Code's own unit tests as **reference conformance suites**, validating
local behavior against Monaco's expectations rather than our own assumptions.

This is a deliberately *scoped* port: this project is a **readonly viewer**, so
roughly half of Monaco's editor test corpus (editing, undo/redo, edit commands,
bracket-pair colorizer, GPU, diffing) tests behavior we do not implement and is
out of scope. The plan ports the in-scope subset, in priority order, and tracks
coverage in the matrix below.

Baseline at time of writing: **139 tests, all green** (`moon test`).

## Status: COMPLETE (Phase 5 deferred)

Phases 0–4 are done. This plan is **closed as complete** with Phase 5 (hover +
controller) **deferred by decision** — it is not part of this plan's completion.

Final state, all green on `moon test --target {js,native}`: **416 js / 426
native** (baseline was 139). Every in-scope **Full** and **Readonly-subset** row
is ported with case-count parity (net of documented skips), or its remainder is
explicitly deferred behind a named follow-up (interval-tree decoration storage,
EOL/lonely-CR modeling, bracket matching, word-wrap, variable line heights,
find/search). Four files queued in earlier phases were reclassified **out of
scope** after triage — `languagesRegistry` (14) and `tokenization`/`TokenTheme`
(16), plus the already-listed `viewModelDecorations` and folding-model rows
remain deferred.

**Outstanding, intentionally not closed:** the `viewer/controller` zero-coverage
exit criterion — it would be met by the deferred Phase 5 `viewController` port.
When Phase 5 is scheduled, reopen the hover/controller rows below.

## Scope Rule

A vscode test file is **in scope** only if it exercises behavior the readonly
viewer actually implements. Each in-scope file is further classified:

- **Full** — every case is readonly-relevant; port the whole file.
- **Readonly-subset** — port only the cases that do not mutate the model or
  depend on editing/cursor-command APIs; record which cases were dropped.
- **Conditional** — in scope only if/when an optional feature lands (word-wrap
  line projection, find/search, variable line heights, syntax folding provider).
- **Deferred** — in scope but blocked on a known follow-up (e.g. interval-tree
  decoration storage).

Explicitly **out of scope** (do not port): `editableTextModel*`, `editStack`,
`modelEditOperation`, `textChange`, `commands/*`, `controller/{cursor,
cursorMoveCommand,textAreaInput,textAreaState}`, `model/bracketPairColorizer/*`,
`gpu/*`, `diff/*`, `node/diffing/*`, `services/{modelService,languageService,
languagesRegistry,semanticTokens*}`, `minimapCharRenderer`. These test editing,
input, DI services, or subsystems this viewer does not have.

`services/languagesRegistry` was reclassified out of scope after triage (it had
been queued for Phase 4): it is the language-**definition** / file-association +
language-picker metadata registry (`_registerLanguages` with extensions /
aliases / mimetypes / filenames / configuration; `getLanguageName` /
`getMimeType` / `getExtensions` / …), the backing store of the already-excluded
`languageService`. The readonly viewer is handed a language-id string and
implements none of that surface — its `Languages` type is a *feature-provider*
registry (hover / diagnostics / symbols / tokens by id), a different thing.
Porting would mean inventing a registry nothing in the viewer consumes.

`common/languages/supports/tokenization` (the `TokenTheme` suite) was likewise
reclassified out of scope after triage (it had been queued for Phase 4): all 16
cases test Monaco's TextMate token-**theme** resolver — `ColorMap` (id
allocation), `ParsedTokenThemeRule`, `ThemeTrieElement`/`Rule`, `parseTokenTheme`,
`TokenTheme._match` (scope-name → trie → fontStyle + foreground + background).
The viewer implements none of it: it colors via a `color_map : Array[String]` +
`mtk<fg>` classes + hand-rolled tokenizers (`lang_javascript`/`lang_json`/
`lang_moonbit`), not TextMate scopes + themes. The prior matrix "partial" was a
mis-attribution. Pure self-contained logic, so portable as conformance-only if
the viewer ever adopts TextMate grammars — but nothing consumes it today.

## Conventions

These codify the pattern already established by
`viewer/view_line_renderer/monaco_render_line_reference_test.mbt`:

1. **Naming.** A faithful 1:1 port lives in a file suffixed
   `*_reference_test.mbt` (or `*_reference_wbtest.mbt` for white-box) in the
   owning package. This visibly separates conformance ports from our own tests.
2. **Traceability.** Preserve Monaco's original `test(...)` / `suite(...)` names
   and bug IDs verbatim as the case label string (e.g. `"Bug 9827"`,
   `"issue #3462"`), so a reviewer can diff a suite line-for-line against its
   `.ts` source.
3. **Header pointer.** Each reference file starts with a `///|` doc comment
   naming the exact vscode source path it ports and the commit/submodule it was
   taken from.
4. **Un-portable cases.** A case that needs DI/services, async, or DOM
   `client-rect` measurement is not silently dropped: either adapt it to our
   seam, or leave an explicit `// SKIPPED (covered by Playwright tests/): ...`
   marker naming the harness test that covers it. "Skipped" must never mean
   "untested."
5. **One reference file per vscode source file** wherever practical, to keep the
   mapping one-to-one.

## Coverage Matrix (triage)

`vscode tests` = `test(...)` blocks in the source. `Local` = current owning
package status. Counts are from the pinned `vscode/` submodule.

### Core / geometry

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/core/range.test.ts` | 9 | `base/common` (Range) | done (reference, 9) ✓ | Full ✓ |
| `common/core/lineRange.test.ts` | 4 | `base/common` | done (reference, 4) ✓ | Full ✓ |
| `common/core/cursorColumns.test.ts` | 5 | `viewer/common` | done (reference, 5) ✓ | Full ✓ |
| `common/core/characterClassifier.test.ts` | 1 | `base/common` | done (reference, 1) ✓ | Full ✓ |
| `common/core/lineTokens.test.ts` | 7 | `viewer/view_model` (tokens) | done (reference, 7) ✓ | Full ✓ |

### Text model

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/model/textModel.test.ts` | 40 | `viewer/model` | done (reference, 10 in scope; 18 out-of-scope dropped, 5 JS-only skipped, 7 deferred) ✓ | Readonly-subset ✓ |
| `common/model/model.line.test.ts` | 53 | `viewer/model` | done (reference, 1 in scope; 52 editing/tokenizer dropped) ✓ | Readonly-subset ✓ |
| `common/model/model.test.ts` | 32 | `viewer/model` | done (reference, 5 in scope; 25 editing/DI dropped, 2 deferred) ✓ | Readonly-subset ✓ |
| `common/model/textModelWithTokens.test.ts` | 29 | `viewer/model` (guides) | done (reference, 18 indent-guide) ✓; bracket-matching 11 deferred | Readonly-subset |
| `common/model/textModelTokens.test.ts` | 2 | `viewer/view_model` | done (reference, 2) ✓ | Full ✓ |
| `common/model/modelDecorations.test.ts` | 100 | `viewer/decorations` | done (reference, 5 query in scope; 95 deferred → interval-tree) ✓ | Readonly-subset ✓ |
| `common/model/intervalTree.test.ts` | 25 | `viewer/decorations` | none | Deferred (interval-tree storage follow-up) |
| `common/model/textModelSearch.test.ts` | 42 | — | none | Conditional (find/search feature) |

### View layout / line rendering

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/viewLayout/viewLineRenderer.test.ts` | 72 | `viewer/view_line_renderer` | done (reference, 72; exact HTML+mapping) ✓ | Full ✓ |
| `common/viewLayout/lineDecorations.test.ts` | 5 | `viewer/view_line_renderer` | done (reference) | Full ✓ |
| `common/viewLayout/linesLayout.test.ts` | 12 | `viewer/view_layout` | done (reference, 12) ✓ | Full ✓ |
| `common/viewLayout/lineHeights.test.ts` | 38 | `viewer/view_layout` | none | Conditional (variable line heights) |
| `common/viewModel/prefixSumComputer.test.ts` | 48 | `viewer/view_layout` | done (reference, 48) ✓ | Full ✓ |

### View model / decorations

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/viewModel/inlineDecorations.test.ts` | 23 | `viewer/inline_decorations` | done (reference, 23) ✓ | Full ✓ |
| `browser/viewModel/viewModelImpl.test.ts` | 29 | `viewer/view_model` | partial (12) | Readonly-subset |
| `browser/viewModel/viewModelDecorations.test.ts` | 3 | `viewer/view_model` | deferred (integration) | Deferred (word-wrap + editing addDecoration harness) |
| `browser/viewModel/modelLineProjection.test.ts` | 6 | `viewer/view_model` | none | Conditional (word-wrap) |
| `browser/view/viewController.test.ts` | 17 | `viewer/controller` | none (deferred — Phase 5) | Readonly-subset |

### Languages / tokenization

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/services/languagesRegistry.test.ts` | 14 | — | out of scope (services language-definition registry; not implemented) | Out of scope |
| `common/modes/supports/tokenization.test.ts` | 16 | — | out of scope (TextMate `TokenTheme` resolver; not implemented) | Out of scope |
| `common/modes/textToHtmlTokenizer.test.ts` | 5 | `viewer/view_model` | done (reference, 5) ✓ | Full ✓ |

### Folding (contrib)

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `contrib/folding/test/browser/foldingModel.test.ts` | 17 | `viewer/folding`,`viewer/view_model` | deferred (decoration model) | Full |
| `contrib/folding/test/browser/indentRangeProvider.test.ts` | 26 | `viewer/folding` | done (reference, 26) ✓ | Full ✓ |
| `contrib/folding/test/browser/foldingRanges.test.ts` | 7 | `viewer/folding` | done (reference, 7) ✓ | Full ✓ |
| `contrib/folding/test/browser/hiddenRangeModel.test.ts` | 1 | `viewer/folding` | deferred (FoldingModel) | Full |
| `contrib/folding/test/browser/indentFold.test.ts` | 1 | `viewer/folding` | done (reference, 1) ✓ | Full ✓ |
| `contrib/folding/test/browser/syntaxFold.test.ts` | 1 | `viewer/folding` | none | Conditional (syntax folding provider) |

### Hover (contrib)

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `contrib/hover/test/browser/hoverUtils.test.ts` | 29 | `viewer/hover` | none (deferred — Phase 5) | Readonly-subset |
| `contrib/hover/test/browser/contentHover.test.ts` | 2 | `viewer/hover` | partial (5) (deferred — Phase 5) | Readonly-subset |

## Progress log

Phase 0 and the bulk of Phase 1 are landed (all green on `--target all`):

- **Phase 0** — `docs/quality.md` "Conformance ports" section added; existing
  view-line reference suite given a source/commit header.
- **Phase 1 done** — `prefixSumComputer` (48, `viewer/view_layout`),
  `foldingRanges` (7), `indentRangeProvider` (26), `indentFold` (1)
  (`viewer/folding`), `cursorColumns` (5, `viewer/common`),
  `characterClassifier` (1, `base/common`). Supporting Monaco subsystems were
  ported to back these: `PrefixSumComputer`/`ConstantTimePrefixSumComputer`,
  `FoldingRegions`/`FoldRange`/`FoldSource`, `RangesCollector`/`computeRanges`,
  `CursorColumns`, `CharacterClassifier`/`CharacterSet`.
- **Range-system migration (stage 1 done).** The viewer's home-grown offset
  `Range` was renamed to `OffsetRange` (Monaco's own name for it) across all
  consumers, and Monaco's line/column `Range`, `LineRange`, `LineRangeSet` were
  ported 1:1 into `base/common` with their conformance suites (`range` 9,
  `lineRange` 4). `Range` reuses the existing `Position` struct as its
  line/column holder.
- **Range-system migration (stage 2, step 1 done — Position rebase).** `Position`
  was rebased to Monaco's 1-based convention on both axes: field `line` →
  `line_number`, columns one-based, plus Monaco's `Position` methods (`with_`,
  `delta`, `equals`, `is_before`/`is_before_or_equal`, `compare`, `clone`,
  `to_string`) with a local `position_test.mbt` (vscode has no standalone
  `position.test.ts` at the pinned commit — `Position` is covered indirectly by
  `range.test.ts`). The ~17 consumers (snapshots, projection converter,
  injected-text bucketing, cursor/selection, view_controller word/line select,
  mouse hit-testing, view-model decoration adapters) were re-plumbed; the
  snapshot `position_at_offset`/`offset_at_position` and the LSP wire
  (`parse_lsp_position`/`lsp_position_json`, semantic-tokens decode) are the
  ±1 boundaries. All green on `--target all` (250 js / 260 native). The
  cursor/selection comparison helpers now delegate to the ported `Position`
  methods. Browser fixtures audited: the JS conformance fixtures address lines
  via the unchanged 1-based `data-line` attribute, so only the MoonBit inlay-hint
  fixture position was shifted; `just test-browser` was not run in this
  environment.
- **Range-system migration (stage 2, step 2 done — OffsetRange API).**
  `OffsetRange` aligned 1:1 to Monaco's `OffsetRange`: field `end` →
  `end_exclusive`, `contains_offset` → `contains`, plus the full method set
  (`length`, `contains_range`, `intersects`/`intersects_or_touches`, `join`,
  `intersect`/`intersection_length`, `is_before`/`is_after`, `delta`/
  `delta_start`/`delta_end`, `equals`, `to_string`, and the
  `from_to`/`of_length`/`of_start_and_length`/`empty_at`/`try_create`
  constructors), with a local `offset_range_test.mbt` (no upstream
  `offsetRange.test.ts` at the pinned commit). Deviation recorded: the
  constructor normalizes inverted input instead of throwing. Consumers
  re-plumbed (`.end` → `.end_exclusive` across snapshots, render-frame span
  building, tokenized-document, markers, decorations, hover, selection
  clipboard, syntax lexers, remote protocol); ad-hoc union/min-max range code
  now delegates to `join`. JSON wire keys kept as `"end"` (sourced from
  `end_exclusive`) to avoid churn. All green (260 js / 270 native).
- **Range-system migration (stage 2, step 3a done — Location/DocumentSymbol).**
  Moved the shell-display provider types `Location.range` and
  `DocumentSymbol.range` (plus the protocol `ReferenceItem.range`) from
  `OffsetRange` to line/column `Range`. These never touch the viewer's
  offset-based render/marker/hover machinery, so they're isolated. New
  a `parse_lsp_range` that lifts an LSP range straight to a line/column `Range`
  (no offset round-trip) and `range_json`/`parse_range` wire helpers (line/column
  keys) back them; the offset variants are renamed `offset_range_json`/
  `parse_offset_range` (and `parse_lsp_offset_range`) for the still-offset types,
  so the unqualified name always means the canonical `Range`. `server.mbt`'s
  go-to-def display now reads `location.range`'s
  line/column directly (drops the `position_at_offset` step), and
  `definition_at` is position-keyed. All green (260 js / 270 native).
- **Range-system migration (stage 2, step 3b-i done — Diagnostic/Marker/
  Decoration).** Moved `Diagnostic.range`, `Marker.range`, and `Decoration.range`
  to line/column `Range`. LSP `parse_diagnostic` now uses `parse_lsp_range`
  (no offset round-trip); the protocol diagnostic uses `range_json`/`parse_range`.
  `to_view_decoration` collapses to a single model-`Range` → view-range
  projection (the `snapshot` field/round-trip dropped from `ViewModelDecorations`).
  `markers_at` and `DecorationSet::between`/`at_position` are now `Range`/
  `Position`-keyed. The hover widget machinery stays offset-based internally
  (it anchors by offset for pixel placement, a pre-existing deviation); the two
  hover boundaries convert via new `TextSnapshot::range_of`/`offset_range_of`
  (the `MarkerHoverParticipant` query/parts, and the `HoverHighlight`
  decoration). `SemanticToken` + syntax tokens stay `OffsetRange`. All green
  (260 js / 270 native).
- **Range-system migration (stage 2, step 3b-ii done — Hover; step 3 complete).**
  `Hover.range` → line/column `Range`; `ProviderResult::hover_at` is
  position-keyed. LSP `parse_hover_result`/`fallback_hover_range` build `Range`
  hovers (and the now-dead `parse_lsp_offset_range` was removed — `parse_lsp_range`
  is the only LSP range parser); the protocol/render-frame hover uses
  `range_json`/`parse_range`. The `MarkdownHoverParticipant` converts the
  provider `Range` hover to an offset span for the offset-based widget via
  `offset_range_of`. With this, **`SemanticToken` is the only `OffsetRange`-typed
  provider result left** (render-coupled, as in Monaco); the protocol's offset
  `offset_range_json`/`parse_offset_range` now serve only it. All green (260 js /
  270 native). **Remaining:** the browser suite (step 4); the interval-tree
  decoration-storage follow-up is still open and unaffected.
- **Phase 1 deferred, with reasons:**
  - `foldingModel` (17) / `hiddenRangeModel` (1): require a full editor
    decoration-tracking model (`changeDecorations`/`deltaDecorations`/
    `getAllDecorations`/`getDecorationRange`) that does not exist as a test
    seam yet. The `viewer/folding` zero-coverage exit criterion is already met
    by the 34 cases above.
- **Phase 2, step 1 done — `viewLineRenderer` (72), faithful port.** First
  landed as a 72-label reference over the pre-existing readonly *subset*
  renderer (exact where it matched, structural + `DEVIATION:` elsewhere, 4
  SKIPPED findings). Triage surfaced 11 divergences from Monaco — including a
  latent **crash** (`issue-20624`: a fixed 50-unit token split landing
  mid-surrogate raised) and a wrong `CharacterMapping.charIndex` on tabs (used
  by DOM hit-testing). Per user direction, `render_line_renderer.mbt` was then
  **rewritten as a faithful 1:1 port** of Monaco's `renderViewLine`/
  `_renderLine` and the full resolve pipeline (`transformAndRemoveOverflowing`,
  `_applyRenderWhitespace`, `_applyInlineDecorations`, `splitLargeTokens` with
  `onlyAtSpaces`, `splitLeadingWhitespaceFromRTL`, `extractControlCharacters`),
  porting `strings.isFullWidthCharacter`/`containsRTL` and the control-char
  table. Along the way three real bugs were fixed: the surrogate-split crash
  (now resolved by the faithful `onlyAtSpaces` split), `charIndex` tab/
  whitespace displacement (DOM-offset counting), and `LineDecoration.compare`
  using MoonBit's length-first `String::compare` instead of JS lexicographic
  order. The row is now **Full ✓**: all 72 cases assert Monaco's exact inner
  HTML (`__snapshots__/*.0.html`) and inflated `CharacterMapping`
  (`*.1.snap`), with no skips. The **sole** remaining deviation is the
  `view-line-content` line wrapper (load-bearing for the browser's
  `querySelector`/CSS), recorded in the package README. Production rendering now
  matches Monaco (spaces→`U+00A0`, tab→nbsp expansion, literal `"` in text,
  empty-line inner `<span></span>`); the three `viewer/common` line-HTML tests
  were updated to suit. The Playwright suite caught one regression — hover code
  blocks reused the editor renderer and its non-breaking spaces stopped wrapping
  — fixed by adding `render_source_line_html` (Monaco's `_tokenizeToString`
  role: class spans with breakable spaces) and pointing the hover at it. Green
  on `--target all` (328 js / 338 native) and `just test-browser` (45 passed).
- **Phase 2, step 2 done — `linesLayout` (12, faithful migration) +
  `inlineDecorations` (23).**
  - **`linesLayout` (12).** Production's `LinesLayout` was a home-grown
    *different design* (zero-based, view-zone/anchor based, no whitespace ids,
    no padding, no line insert/delete). Per user direction it was **replaced
    with a faithful 1:1 port** of Monaco's `linesLayout.ts` (`EditorWhitespace`,
    1-based line numbers, id/ordinal whitespaces, `changeWhitespace` accessor +
    pending-changes commit, `onLinesDeleted`/`onLinesInserted`, prefix-sum cache,
    `getLinesViewportData`/`getWhitespaceViewportData`/`getWhitespaceAt
    VerticalOffset`, binary searches, `singleLetterHash` ids). `ViewLayout` was
    rewritten as a thin **zero-based view-zone adapter** over it (maps
    `ViewZone{anchor_line,height_px}` → whitespace `afterLineNumber=anchor_line`;
    zero-based `L` ↔ 1-based `L+1`), preserving its full public surface so the
    render path (`render.mbt`, `view.mbt`, `content_widgets.mbt`,
    `view_lines_viewport_data.mbt`, `rendering_context.mbt`, `input.mbt`,
    `view_zones.mbt`) is untouched. The existing 9 `view_layout_test.mbt` cases
    (re-pointed at `ViewLayout`) are the regression net that confirms behavior
    was preserved. `lines_layout_reference_test.mbt` ports all 12
    `linesLayout.test.ts` cases against the production `LinesLayout`. **Deviation:**
    variable line heights (`LineHeightsManager` / the out-of-scope Conditional
    `lineHeights.test.ts` row) are dropped — uniform `default_line_height`; every
    upstream case uses empty `customLineHeightData` (`[]`), so it matches exactly.
    **Scope limit (tracked follow-up below):** the migration swapped the engine
    but kept the viewer's vocabulary at the `ViewLayout` boundary, so production
    consumes only ~5 of the faithful methods (`get_vertical_offset_for_line_number`,
    `get_line_number_at_or_after_vertical_offset`, `get_lines_total_height`,
    `get_vertical_offset_for_whitespace_index`, `change_whitespace`); Monaco's
    richer surface (`getLinesViewportData`'s centered/completelyVisible lines,
    `getWhitespace{ViewportData,AtVerticalOffset}`, padding,
    `onLinesDeleted`/`onLinesInserted`) is conformance-tested but **not consumed**
    by the render path — the zero-based `ViewLayout` adapter still owns that
    behavior.
  - **`inlineDecorations` (23).** Faithful 1:1 port of `inlineDecorations.ts`
    (`InlineDecoration`/`InlineDecorationType`, `InlineModelDecorationsComputer`
    with the `ViewModelDecoration` id-cache + before/after/affectsFont handling,
    `InjectedTextInlineDecorationsComputer`) plus the minimal collaborators its
    suite needs (`ViewModelDecoration` + `isModelDecorationVisible`,
    `IdentityCoordinatesConverter`, a `createTextModel`-style `TextModel`). Landed
    in a **dedicated `viewer/inline_decorations` package** (not `viewer/view_model`)
    because Monaco declares `InlineDecorationType` in this file and its
    `ViewModelDecoration`/`InlineDecoration` names collide with the existing
    simplified view-model pipeline; the dedicated package keeps the faithful names
    and depends only on `base/common`. `inline_decorations_reference_test.mbt`
    ports all 23 cases. **Deviations (unused by the suite):**
    `is_model_decoration_visible` always `true` (no comment/string-token
    tokenization seam); `TextModel` line lengths use `String::length()` over a
    `\n`-split model. Green on `--target all` (363 js / 373 native);
    `just test-browser` not run in this environment (the `ViewLayout` public
    surface is unchanged and the 9-case regression net is green).
- **Phase 2, step 3 (`viewModelDecorations`, 3) — deferred, with reasons.** This
  is a browser integration test: 2 of 3 cases use `wordWrap:'wordWrapColumn'`
  (the Conditional word-wrap row) and all three use the editing
  `model.changeDecorations`/`addDecoration` API plus a full `testViewModel`
  harness and before/after content decorations the local viewport path does not
  yet emit. Its core decoration→viewport logic is now covered by the
  `InlineModelDecorationsComputer` port above; the remaining integration
  assertions need the view-model viewport wiring + a `testViewModel`-style
  harness, tracked as a follow-up (see Deferred).
- **Phase 3, step 1 done — `lineTokens` (7) + `textModelTokens` (2).** Started
  the readonly-subset text-model phase with the two **Full**-scope, pure-logic
  token files (no readonly triage needed), in `viewer/view_model`.
  - **`lineTokens` (7).** Faithful 1:1 port of `lineTokens.ts` (`LineTokens` +
    `SliceLineTokens` behind a shared `IViewLineTokens` trait, the static
    `findIndexInTokensArray`/`createEmpty`/`createFromTextAndMetadata`/
    `convertToEndOffset`, `withInserted`, `inflate`/`sliceAndInflate`) backed by
    a faithful `encodedTokenAttributes.ts` port (`MetadataConsts` bit layout, the
    `FontStyle`/`ColorId`/`StandardTokenType` enums, `TokenMetadata` decoders).
    The flat binary token store is an `Array[UInt]` mirroring Monaco's
    `Uint32Array` (even = end offset, odd = metadata word; the background field
    needs the top byte, hence `UInt`). The local viewer's render path still uses
    its own `@syntax.Token`-based tokens, so this port is conformance-only for
    now. The suite is white-box (`*_reference_wbtest.mbt`) because the test calls
    trait-impl methods on the concrete type and the `substr` helper directly.
    **Deviations** (none exercised by the suite): the `IViewLineTokens` trait
    omits `equals`/`languageIdCodec`; `getTokensInRange`/`toString` (the unported
    `TokenArray` family) are omitted; the constructor skips Monaco's soft
    length-mismatch warning; `LanguageIdCodec` is a minimal placeholder (null
    language at id 0) to be unified with the Phase 4 `languagesRegistry` port;
    `with_inserted` guards an unreachable past-end metadata read.
  - **`textModelTokens` (2).** Faithful 1:1 port of `RangePriorityQueueImpl`
    (`min`/`removeMin`/`delete`/`addRange`/`addRangeAndResize`/`getRanges`) plus
    the `OffsetRange.addRange` static it builds on, added to `base/common`. The
    readonly viewer does not run Monaco's background tokenizer, so this is a
    conformance-only port of the queue. Green on `--target all` (372 js / 382
    native); `pkg.generated.mbti` regenerated.
- **Phase 3, step 2 done — `textModelWithTokens` indent-guide subset (18).**
  `textModelWithTokens.test.ts` splits into two halves: bracket matching and
  indent guides. The **18 indent-guide cases** (the `TextModel.getLineIndentGuide`
  suite, including its `tweaks` and `issue #...` cases) are the readonly,
  pure-logic subset — a faithful port of `GuidesTextModelPart`'s
  `getActiveIndentGuide` / `getLinesIndentGuides` /
  `_getIndentLevelForWhitespaceLine` (plus `utils.ts` `computeIndentLevel`)
  landed in **`viewer/model`** (not `viewer/view_model`), since it is
  `model.guides` — a `TextModel` part operating purely on snapshot lines; it
  wraps the existing `TextSnapshot`. `guides_text_model_part_reference_test.mbt`
  ports all 18 against it. **Deviations:** the bracket-guide methods
  (`getLinesBracketGuides`, `getVisibleColumnFromPosition`) are omitted (they
  need the bracket-pair + language-configuration infrastructure that is out of
  scope); `off_side`/`tab_size`/`indent_size` are fields rather than read from a
  language config / `model.getOptions()` (the viewer has neither yet) — the
  upstream test languages register no folding rules so `off_side` is `false`, and
  `tab_size` uses Monaco's default 4. **The 11 bracket-matching cases** (the
  `TextModelWithTokens*` and regression suites, exercising
  `model.bracketPairs.{matchBracket,findPrevBracket,findNextBracket}`) are
  **deferred** behind that same bracket-pair infrastructure and recorded as an
  explicit `SKIPPED` block in the reference file header (see Deferred). Green on
  `--target all` (390 js / 400 native).
- **Phase 3, step 3 started — `model.line` (1 in scope of 53).** Triage of
  `model.line.test.ts` surfaced a finding: despite the "Readonly-subset" label,
  the file has **no meaningful readonly subset**. Its 52 `ModelLinesTokens` cases
  all route through `testApplyEdits` → `model.applyEdits(...)` (insert/delete/
  replace/split/append — model mutation) *and* assert on
  `model.tokenization.getLineTokens(...)`, Monaco's background tokenizer
  (`ManualTokenizationSupport` + `TokenizationRegistry`) — two subsystems the
  readonly viewer does not implement; they are double-disqualified. The **sole**
  in-scope case is `getIndentLevel` (the `ModelLine - getIndentLevel` suite,
  testing `model/utils.ts` `computeIndentLevel`). Ported as a white-box
  `model_line_reference_wbtest.mbt` in `viewer/model`, with all 52 dropped case
  names enumerated in the file header (per Convention 4). Along the way the
  `model/utils.ts` `computeIndentLevel` helper was extracted as a faithful free
  `compute_indent_level(line, tab_size)` (new `utils.mbt`); the
  `GuidesTextModelPart` indent-level method, previously an inline copy of the
  same scan, now delegates to it (removing the duplication; mirrors Monaco's
  `_computeIndentLevel` → `computeIndentLevel`). Private helper, so
  `pkg.generated.mbti` is unchanged. Green on `--target js,native` (53/53 model
  package, both targets). **Remaining in step 3:** `model.test.ts` (32) and
  `textModel.test.ts` (40), which carry the file's real readonly subsets
  (value/offset/position queries, EOL, line metadata).
- **Phase 3, step 3 cont. — `model.test` (5 in scope of 32).** Triage: 23
  `Editor Model - Model` editing/eventing cases and 2 `Editor Model - Words` DI
  cases dropped; 7 readonly reads in scope. 5 are pure, low-risk reads, ported
  here against `TextSnapshot`: `model getValue` (both suites), `getValueInRange`,
  `getValueLengthInRange`, `model lines`. Backed by three new faithful read
  methods — `get_value` / `get_value_in_range` / `get_value_length_in_range` —
  that join `line_text` with `\n` (Monaco's default LF EOL); they add no storage
  or line-table change, so no offset/render risk. (`model lines` already matched
  the existing `line_count()`: ` ` is not a line break.) White-box
  `model_reference_wbtest.mbt`; `pkg.generated.mbti` regenerated (3 pub methods).
  Green on `--target js,native` (58/58 model package). **Two readonly cases
  deferred** (see Deferred): `Bug 13333` (lonely-CR line-table change = a
  production behavior change) and `Get word at position` (needs Monaco's
  `wordHelper` regex). **Remaining in step 3:** `textModel.test.ts` (40).
- **Phase 3, step 3 done — `textModel.test` (10 in scope of 40).** Triage found
  the file dominated by subsystems the readonly viewer does not model — model
  options, EOL preference, indentation guessing, streaming snapshot/BOM — so 18
  of 40 are out of scope, plus 5 JS-only (NaN/float/undefined, not representable
  with integer `Position`/`Range`) and 7 deferred (the same EOL/lonely-CR gap as
  `model.test`). The clean readonly subset (10) is ported here against
  `TextSnapshot`: `validatePosition` (integer asserts; 4 float asserts skipped),
  `validatePosition`/`validateRange around high-low surrogate pairs 1` and `2`,
  `modifyPosition`, `getLineFirstNonWhitespaceColumn`,
  `getLineLastNonWhitespaceColumn`, and `mightContainRTL` (nope/yes). Backed by a
  faithful port of Monaco's surrogate-aware `_validatePosition`/`validateRange`
  (position snaps *before* a split pair; range expands *outward*),
  `modifyPosition` (relaxed-validate + offset round-trip), the
  first/last-non-whitespace-column accessors, and `mightContainRTL` — all new
  pure-read `TextSnapshot` methods (additive, no storage/line-table change, no
  offset/render risk). The shared `is_high_surrogate`/`contains_rtl`/
  `first_non_whitespace_index`/`last_non_whitespace_index` primitives were added
  to a new `base/common/strings.mbt` (Monaco's `base/common/strings.ts` home;
  `contains_rtl` reuses the viewer's existing simplified BMP-range port).
  White-box `text_model_reference_wbtest.mbt`; `pkg.generated.mbti` regenerated
  for both packages. Green on `--target js,native` (full suite 406 js / 416
  native). **With this, Phase 3 step 3 is complete** (`model.line` 1,
  `model.test` 5, `textModel` 10). The deferred EOL/lonely-CR and word-helper
  items carry over (see Deferred).
- **Phase 3, step 4 done — `modelDecorations` (5 query in scope of 100).**
  Triage found the file built end-to-end on Monaco's mutable, id-based,
  edit-tracking decoration model (`deltaDecorations`→ids, `changeDecorations`/
  `addDecoration`/`removeDecoration`, `getDecorationRange(id)`, stickiness,
  `onDidChangeDecorations`), so 95 of 100 are blocked on the interval-tree
  decoration-storage follow-up — it is the consumer-level sibling of the
  deferred `intervalTree` (25). The 5 pure-query cases map to the viewer's
  immutable `DecorationSet` seam and are ported (a documented adaptation per
  Convention 4: `addDecoration`/`deltaDecorations` → `from_array`,
  `getLineDecorations(n)` → `between(Range(n,1,n,BIG))`, `getDecorationsInRange`
  → `between`): `single character decoration`, `line decoration`, `full line
  decoration`, `multiple line decoration`, and `issue #16922` (the 10-decoration
  `getDecorationsInRange` point query → `[x1,x2,x3,x4]`). Black-box
  `model_decorations_reference_test.mbt`; no production change (query-only), so
  `pkg.generated.mbti` is unchanged. Green on `--target js,native` (full suite
  411 js / 421 native). The 95 editing/id-model cases are deferred (see
  Deferred). **With this, Phase 3 is complete** — every text-model/decoration
  readonly-subset row is ported or has its remainder explicitly deferred.
- **Phase 4, step 1 done — `textToHtmlTokenizer` (5, Full).** Faithful 1:1 ports
  of `tokenizeLineToHTML` (tab expansion, `&#160;` space-collapsing, partial
  `startOffset`/`endOffset` ranges incl. the `#263387` width-through-skipped-tabs
  fix and the `#35954` leading-space handling) and `_tokenizeToString` (class
  spans inside `<div class="monaco-tokenized-source">`, `<br/>`-joined lines),
  landed in `viewer/view_model` co-located with the ported `LineTokens` (Monaco's
  own home), backed by the ported `IViewLineTokens` + `TokenMetadata` metadata
  helpers. `_tokenizeToString`'s `IReducedTokenizationSupport` is adapted to a
  stateless `(String) -> Array[UInt]` closure seam (matching the suite's stateless
  `Mode`). `is_full_width_character` and `escape` (Monaco `strings.ts`) added to
  the shared `base/common/strings.mbt`. White-box
  `text_to_html_tokenizer_reference_wbtest.mbt`; `pkg.generated.mbti` regenerated
  for `base/common` and `view_model`. Green on `--target js,native` (full suite
  416 js / 426 native).

## Phased Steps

Ordered by value-per-effort: highest first is pure logic with zero current
coverage and no DOM/editing dependency.

### Phase 0 — Conventions + harness

- Add a short "Conformance ports" section to `docs/quality.md` referencing the
  five Conventions above so the pattern is enforced in review.
- Confirm the existing reference suite's header comment names its vscode source;
  retrofit if missing. No behavior change.

### Phase 1 — Pure-logic gaps (folding + core utilities)

Highest priority: `viewer/folding` has reference suites in vscode but only 2
local cases (under `view_model`), and these are DOM-free pure logic.

- `indentRangeProvider` (26), `foldingRanges` (7), `foldingModel` (17),
  `hiddenRangeModel` (1), `indentFold` (1) → `viewer/folding`.
- `range` (9), `lineRange` (4), `cursorColumns` (5), `characterClassifier` (1)
  → `base/common` / `viewer/common`.
- `prefixSumComputer` (48) → `viewer/view_layout`.

### Phase 2 — Render / view-line completeness — done ✓

- Finish the `viewLineRenderer` port to all 72 cases in
  `viewer/view_line_renderer` (current reference file is a subset). **Done.**
- `linesLayout` (12) → `viewer/view_layout`. **Done** (faithful migration:
  production `LinesLayout` replaced by Monaco's port; `ViewLayout` is now a
  zero-based view-zone adapter over it).
- `inlineDecorations` (23) → `viewer/inline_decorations` (dedicated package, to
  avoid `ViewModelDecoration`/`InlineDecoration` name collisions). **Done.**
- `viewModelDecorations` (3) → deferred (browser integration; 2/3 cases need
  word-wrap + the editing `addDecoration` harness — see Deferred). Its core
  logic is covered by the `inlineDecorations` `InlineModelDecorationsComputer`.

### Phase 3 — Text model + decorations (readonly subset)

- `textModelTokens` (2), `lineTokens` (7) → `viewer/view_model`. **Done** (the
  two Full-scope, pure-logic token files; faithful `LineTokens`/
  `SliceLineTokens` + `RangePriorityQueueImpl` ports — see progress log).
- `textModelWithTokens` indent-guide cases (18) → `viewer/model` (`model.guides`).
  **Done.** The 11 bracket-matching cases are deferred (need bracket-pair +
  language-configuration infrastructure — see Deferred).
- `textModel` / `model.line` / `model.test` readonly cases → `viewer/model`;
  drop every mutate/undo case and list the dropped names in the file header.
  - `model.line` (53) **done**: triage found only 1 readonly case
    (`getIndentLevel`); the other 52 (`ModelLinesTokens`) are editing +
    background-tokenizer and dropped (see progress log). `computeIndentLevel`
    extracted to `utils.mbt`; guides part delegates to it.
  - `model.test` (32) **done**: 5 readonly reads ported (`get_value`,
    `get_value_in_range`, `get_value_length_in_range` added to `TextSnapshot`);
    25 editing/DI dropped; 2 deferred (lonely-CR `Bug 13333`, `Get word at
    position`).
  - `textModel` (40) **done**: 10 readonly cases ported (surrogate-aware
    `validate_position`/`validate_range`, `modify_position`, first/last
    non-whitespace column, `might_contain_rtl` added to `TextSnapshot`; shared
    string primitives to `base/common/strings.mbt`); 18 out of scope, 5 JS-only
    skipped, 7 deferred (EOL/lonely-CR + the `fromString` buffer suite).
  - **Phase 3 step 3 complete.**
- `modelDecorations` readonly subset → `viewer/decorations`. **Done** (step 4):
  5 pure-query cases ported against `DecorationSet`; the 95 id-model/edit-tracking
  cases are deferred behind the interval-tree decoration-storage follow-up.
  **Phase 3 complete.**

### Phase 4 — Languages / tokenization

**Phase 4 complete:** of the three queued files, only `textToHtmlTokenizer` (5)
exercises behavior the readonly viewer implements and is ported; `languagesRegistry`
(14) and `tokenization`/`TokenTheme` (16) were reclassified out of scope after
triage (neither subsystem is implemented; both are recorded in the out-of-scope
note at the top).

- ~~`languagesRegistry` (14) → `viewer/languages`~~ **reclassified out of scope**
  (triage): a `common/services` language-definition / file-association registry
  the readonly viewer does not implement (handed a language id), sibling of the
  excluded `languageService`. The prior matrix "partial (2)" was a
  mis-attribution — those local cases test the viewer's *feature-provider*
  registry, not this file. See the out-of-scope note at the top.
- ~~`tokenization` supports (16) → `syntax`~~ **reclassified out of scope**
  (triage): the `TokenTheme` TextMate scope→trie→metadata resolver, which the
  viewer does not implement (it colors via a `color_map` array + `mtk` classes +
  hand-rolled tokenizers). Pure logic, so portable as conformance-only if the
  viewer ever adopts TextMate grammars. See the out-of-scope note at the top.
- `textToHtmlTokenizer` (5) → `viewer/view_model`. **Done** (step 1): faithful
  ports of `tokenizeLineToHTML` and `_tokenizeToString` co-located with the
  ported `LineTokens` (Monaco's home), backed by the shared
  `is_full_width_character`/`escape` added to `base/common/strings.mbt`. Home
  moved from the matrix's `viewer/common` to `viewer/view_model` (where
  `LineTokens` lives); the 2 prior `viewer/common` line-html tests are the
  production `render_source_line_html` (RenderLine) path, not ports of this file.

### Phase 5 — Hover + controller (readonly subset) — DEFERRED

**Not done; deferred by decision when this plan was closed.** These rows remain
in scope (readonly behavior the viewer implements) and are the natural reopening
point: porting `viewController` is what satisfies the still-outstanding
`viewer/controller` zero-coverage exit criterion.

- `hoverUtils` (29), `contentHover` (2) → `viewer/hover`.
- `viewController` readonly dispatch cases (17, minus editing/cursor-command
  dispatch) → `viewer/controller` (currently zero coverage).

### Deferred (tracked, not scheduled here)

- **`ViewLayout` deeper migration (drop the zero-based adapter).** `LinesLayout`
  is now Monaco's faithful port, but `ViewLayout` still presents a zero-based
  view-zone facade and consumes only a subset of it (see Phase 2 step 2). The
  follow-up is to make `ViewLayout` and the render path speak Monaco's
  vocabulary directly — 1-based line numbers, consuming `getLinesViewportData`
  (centered/completelyVisible lines, `relativeVerticalOffset`), padding, and the
  `getWhitespace*` viewport APIs — and retire the adapter. This touches the
  scroll/render path (`render.mbt`, `view.mbt`, `content_widgets.mbt`,
  `view_lines_viewport_data.mbt`, `rendering_context.mbt`) and carries real
  behavior risk, so it is deliberately separated from the test-conformance port;
  the 9 `view_layout_test.mbt` cases are the behavior contract it must preserve.
- `textModelWithTokens` bracket-matching cases (11) — the `TextModelWithTokens*`
  and regression suites exercise
  `model.bracketPairs.{matchBracket,findPrevBracket,findNextBracket}`, which need
  the bracket-pair scanner + language-configuration (bracket definitions) +
  tokenization (to skip brackets inside comments/strings) infrastructure the
  readonly viewer does not implement (sibling to the out-of-scope bracket-pair
  colorizer). Port if/when bracket matching lands. The indent-guide half of the
  same file is already done (Phase 3 step 2).
- `model.test.ts` lonely-CR + word cases (2) — `Bug 13333: Model should line
  break on lonely CR too` needs the `TextSnapshot` line-start table to break on
  a lonely `\r` (today it splits only on `\n`); that changes the production line
  table and every offset the render/marker path derives from it, so it is a
  scoped production change (sibling to the `ViewLayout` migration), not a test
  port. `Get word at position` needs a port of Monaco's `core/wordHelper.ts`
  `getWordAtText` + the default word regexp (the viewer has no regex engine);
  group it with the Phase 5 controller word-select work. The other 5 readonly
  cases of the file are done (Phase 3 step 3).
- `textModel.test.ts` EOL/buffer cases (7) — `getValueLengthInRange` (its CRLF
  model expects `\r\n`-counted lengths) and `getValueLengthInRange different EOL`
  (`EndOfLinePreference`) need the snapshot to model a per-model EOL rather than
  always normalizing to `\n`; the whole `TextModelData.fromString` suite (5 —
  `one line text`, `multiline text`, `Non Basic ASCII 1`, `containsRTL 1/2`)
  needs `createTextBuffer`'s EOL guessing + lonely-CR splitting + `getEOL`/
  `getLinesContent` buffer shape. Same EOL/lonely-CR gap as `Bug 13333` above;
  port together when the snapshot grows EOL modeling. The other 10 readonly cases
  of the file are done (Phase 3 step 3). (The 18 out-of-scope options/indentation
  /streaming/DI cases and 5 JS-only NaN/float cases are not deferred — they are
  permanently out of scope and recorded in the reference file header.)
- `intervalTree` (25) — port alongside the interval-tree decoration storage
  follow-up.
- `modelDecorations.test.ts` id-model/edit-tracking cases (95) — everything
  beyond the 5 pure-query cases (Phase 3 step 4) needs Monaco's mutable, id-based
  decoration model: `deltaDecorations`→ids, `changeDecorations`/`addDecoration`/
  `removeDecoration`/`changeDecoration`, `getDecorationRange(id)`/
  `getDecorationOptions(id)`, `getAllDecorations`, `TrackedRangeStickiness`,
  `onDidChangeDecorations`, and decoration-range tracking through `applyEdits`
  (the whole `Decorations and editing` insert/delete/replace matrix). Port
  alongside the interval-tree decoration-storage follow-up (this file is its
  consumer-level conformance suite; `intervalTree` (25) is the storage layer).
- `viewModelDecorations` (3) — browser integration capstone. Core
  decoration→viewport logic is already covered by
  `InlineModelDecorationsComputer` (`viewer/inline_decorations`); the remaining
  work is wiring that computer into the view-model viewport rendering path (so
  before/after/letter-spacing decorations emit) plus a `testViewModel`-style
  harness with a decoration-mutation seam. 2 of 3 cases also need word-wrap.
- `modelLineProjection` (6) / `viewModelImpl` wrapping cases — only when
  word-wrap lands.
- `textModelSearch` (42) — only when a find/search feature lands.
- `lineHeights` (38) — only if variable line heights are supported.

## Validation

- `moon test` (and `moon test --target all` where packages are multi-target)
  stays green after each phase.
- Each ported file's case count and labels match the vscode source minus any
  documented `SKIPPED` / dropped-editing cases.
- A divergence found while porting is a finding: fix the port to match Monaco,
  or, if Monaco's behavior is intentionally not replicated (readonly), record
  the deviation in the file header and the owning package README.

## Exit Criteria

Status at closure (Phases 0–4; Phase 5 deferred):

- ✅ Every in-scope **Full** and **Readonly-subset** row **except the deferred
  Phase 5 hover/controller rows** has a `*_reference_test.mbt` in its owning
  package, green, with case-count parity (net of documented skips/deferrals).
- ✅ This matrix is kept current: each completed row's Local status is updated
  here, out-of-scope reclassifications are recorded, and every Conditional/
  Deferred row names its blocking follow-up.
- ✅ `viewer/folding` no longer has zero conformance coverage.
- ⏳ **`viewer/controller` still has zero conformance coverage** — the one
  criterion left open, satisfied by the deferred Phase 5 `viewController` port.
