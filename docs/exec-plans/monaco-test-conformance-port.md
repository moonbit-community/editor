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
semanticTokens*}`, `minimapCharRenderer`. These test editing, input, DI
services, or subsystems this viewer does not have.

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
| `common/core/lineTokens.test.ts` | 7 | `viewer/view_model` (tokens) | partial | Full |

### Text model

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/model/textModel.test.ts` | 40 | `viewer/model` | partial (4) | Readonly-subset |
| `common/model/model.line.test.ts` | 53 | `viewer/model` | partial | Readonly-subset |
| `common/model/model.test.ts` | 32 | `viewer/model` | partial | Readonly-subset |
| `common/model/textModelWithTokens.test.ts` | 30 | `viewer/view_model` | partial | Readonly-subset |
| `common/model/textModelTokens.test.ts` | 2 | `viewer/view_model` | none | Full |
| `common/model/modelDecorations.test.ts` | 100 | `viewer/decorations` | partial (1) | Readonly-subset |
| `common/model/intervalTree.test.ts` | 25 | `viewer/decorations` | none | Deferred (interval-tree storage follow-up) |
| `common/model/textModelSearch.test.ts` | 42 | — | none | Conditional (find/search feature) |

### View layout / line rendering

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/viewLayout/viewLineRenderer.test.ts` | 72 | `viewer/view_line_renderer` | partial (reference port subset) | Full (finish the port) |
| `common/viewLayout/lineDecorations.test.ts` | 5 | `viewer/view_line_renderer` | done (reference) | Full ✓ |
| `common/viewLayout/linesLayout.test.ts` | 12 | `viewer/view_layout` | partial (9) | Full |
| `common/viewLayout/lineHeights.test.ts` | 38 | `viewer/view_layout` | none | Conditional (variable line heights) |
| `common/viewModel/prefixSumComputer.test.ts` | 48 | `viewer/view_layout` | done (reference, 48) ✓ | Full ✓ |

### View model / decorations

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/viewModel/inlineDecorations.test.ts` | 23 | `viewer/view_model` | partial | Readonly-subset |
| `browser/viewModel/viewModelImpl.test.ts` | 29 | `viewer/view_model` | partial (12) | Readonly-subset |
| `browser/viewModel/viewModelDecorations.test.ts` | 3 | `viewer/view_model` | partial | Full |
| `browser/viewModel/modelLineProjection.test.ts` | 6 | `viewer/view_model` | none | Conditional (word-wrap) |
| `browser/view/viewController.test.ts` | 17 | `viewer/controller` | none | Readonly-subset |

### Languages / tokenization

| vscode source | vscode tests | Local owner | Local status | Scope |
|---|---:|---|---|---|
| `common/services/languagesRegistry.test.ts` | 14 | `viewer/languages` | partial (2) | Readonly-subset |
| `common/modes/supports/tokenization.test.ts` | 16 | `syntax` | partial | Readonly-subset |
| `common/modes/textToHtmlTokenizer.test.ts` | 5 | `viewer/common` (line html) | partial (2) | Full |

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
| `contrib/hover/test/browser/hoverUtils.test.ts` | 29 | `viewer/hover` | none | Readonly-subset |
| `contrib/hover/test/browser/contentHover.test.ts` | 2 | `viewer/hover` | partial (5) | Readonly-subset |

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
  **Remaining:** the render-coupled cluster — `Diagnostic` + `Marker` + `Hover`
  + `Decoration` → `Range` (step 3b; `hover_at`/marker queries become
  position-keyed, `to_view_decoration` simplifies; `SemanticToken` and syntax
  tokens stay `OffsetRange`); then the browser suite (step 4).
- **Phase 1 deferred, with reasons:**
  - `foldingModel` (17) / `hiddenRangeModel` (1): require a full editor
    decoration-tracking model (`changeDecorations`/`deltaDecorations`/
    `getAllDecorations`/`getDecorationRange`) that does not exist as a test
    seam yet. The `viewer/folding` zero-coverage exit criterion is already met
    by the 34 cases above.

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

### Phase 2 — Render / view-line completeness

- Finish the `viewLineRenderer` port to all 72 cases in
  `viewer/view_line_renderer` (current reference file is a subset).
- `linesLayout` (12) → `viewer/view_layout`.
- `inlineDecorations` (23), `viewModelDecorations` (3) → `viewer/view_model`.

### Phase 3 — Text model + decorations (readonly subset)

- `textModelTokens` (2), `lineTokens` (7), `textModelWithTokens` readonly cases
  → `viewer/view_model`.
- `textModel` / `model.line` / `model.test` readonly cases → `viewer/model`;
  drop every mutate/undo case and list the dropped names in the file header.
- `modelDecorations` readonly subset → `viewer/decorations`.

### Phase 4 — Languages / tokenization

- `languagesRegistry` (14) → `viewer/languages`.
- `tokenization` supports (16) → `syntax`.
- `textToHtmlTokenizer` (5) → `viewer/common`.

### Phase 5 — Hover + controller (readonly subset)

- `hoverUtils` (29), `contentHover` (2) → `viewer/hover`.
- `viewController` readonly dispatch cases (17, minus editing/cursor-command
  dispatch) → `viewer/controller` (currently zero coverage).

### Deferred (tracked, not scheduled here)

- `intervalTree` (25) — port alongside the interval-tree decoration storage
  follow-up.
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

- Every **Full** and **Readonly-subset** row above has a `*_reference_test.mbt`
  in its owning package, green, with case-count parity (net of documented
  skips).
- This matrix is kept current: when a row is completed its Local status is
  updated here; when a Conditional/Deferred precondition lands, the row is
  rescheduled into a phase.
- `viewer/folding` and `viewer/controller` no longer have zero conformance
  coverage.
