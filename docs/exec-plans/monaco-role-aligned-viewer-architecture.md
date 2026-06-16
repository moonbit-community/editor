# Monaco Role-Aligned Viewer Architecture

Status: implemented.
Date: 2026-06-16

Implementation note, 2026-06-16: the initial architecture alignment slices have
landed: the Monaco layer map exists, the common render-line IR has been split
into role-named files and promoted into `renderer/view_line_renderer`, a
readonly identity `ViewModel` spine feeds current viewport rendering, and the
browser view island has been split into Monaco browser role files. A later
Phase 6 slice promoted pure layout and scroll state into `renderer/view_layout`,
and another promoted tokenized source, render-frame, and readonly `ViewModel`
state into `renderer/view_model`; `ViewportData` now lives in
`renderer/view_layout`. A Phase 7 slice now adds common-layer projected view
lines, monospace line-break projection, projected coordinate conversion,
option-controlled browser soft wrap, and a component browser test that verifies
wrapped view-line rendering and line-number alignment. Follow-up Phase 7 slices
cover wrapped hover, diagnostics, scroll positioning, direct hit-test coverage,
and Monaco-style classifier-backed word breaks in the readonly no-injected-text
path. Remaining Phase 7 deltas are tied to later features, especially wrapped
indentation; accessibility follow-up remains pending as a dedicated design area.

Implementation note, 2026-06-16, Phase 8: folding now has language-level
`FoldingRange`, `FoldingRangeKind`, and `FoldingRangeProvider` contracts; a
pure `renderer/view_model` `FoldingModel` that normalizes folded ranges and
derives merged `HiddenRange` spans; hidden-area projection in
`ViewModelLines`; browser provider collection with a MoonBit indentation
fallback; margin fold/unfold markers; and optional remote protocol transport
through server/workbench providers. Remaining Phase 8 follow-up is mostly
hardening: richer nested-marker behavior, stronger scroll-height browser
coverage, and native backend folding providers beyond the local fallback.

Implementation note, 2026-06-16, Phase 9: inlay hints now have language-level
`InlayHint`, `InlayHintKind`, and `InlayHintsProvider` contracts plus optional
remote transport through `remote_protocol`, `server`, and `workbench`.
`renderer/view_model` represents hints as `InjectedText` and projects them
before line breaking, with render-line source mappings preserving model offsets
for hit testing and decorations. `renderer/browser` collects providers, renders
hint spans through the normal line renderer, and contributes hint tooltip hover
content through the hover participant pipeline. Browser component coverage now
exercises hint rendering, hover, wrapping, folding, and selection/copy together.
Phase 10 copy excludes injected hint labels through the model-backed selection
range and visible source-span rich-copy path.

Implementation note, 2026-06-16, Phase 11: view zones now displace readonly
view lines through `renderer/view_layout.LinesLayout`, `ViewLayout`, and
`ViewportData.view_zones`. `renderer/browser` exposes a minimal
`ViewZoneChangeAccessor` with add/update/remove operations over DOM nodes,
mounts them in `.view-zones`, and positions lines, line numbers, folding
markers, selection overlays, hover content widgets, scrollbars, and hit testing
from the zone-aware layout. Component browser coverage registers an internal
fixture zone and exercises zone rendering, line alignment, hover after zones,
and selection/copy across a zone.

## Goal

Refactor the readonly viewer so its internal module roles and names line up with
Monaco's `editor/common` and `editor/browser` architecture. This is a source-map
and maintainability plan: future work should be able to open a Monaco file,
find the corresponding MoonBit file or type, and understand whether the local
implementation is exact, partial, a readonly subset, or intentionally skipped.

The target architecture is:

```text
vscode/src/vs/editor/common/*   -> renderer/*
vscode/src/vs/editor/browser/*  -> renderer/browser/*
```

`renderer` remains the MoonBit-owned package family that plays Monaco's
common-layer role. `renderer/browser` remains the MoonBit-owned package family
that plays Monaco's browser-layer role. The viewer remains readonly.

This plan supersedes none of the implemented Monaco plans. Do not rewrite
`monaco-ir-and-imperative-view.md`, `monaco-shaped-dom-rendering.md`, or
`monaco-render-line-ir-layer.md`; treat them as historical evidence and make
this plan the follow-up architecture alignment work.

## Design Rules

- Copy Monaco's role map and naming where the local role is the same.
- Do not import or generate product code from `vscode/` or `codemirror/`.
- Do not copy Monaco's dependency injection, command service, extension host,
  workbench services, editable cursor stack, IME/edit context, minimap, or
  overview ruler as part of this plan.
- Prefer Monaco role names directly for internal APIs, file names, DOM
  structure, and tests when this plan changes a surface. Do not preserve old
  local names just for compatibility.
- Prefer Monaco structural DOM names, including root and container names, when
  they make source comparison or conformance clearer. MoonBit product naming
  should remain only where it is not part of the Monaco role structure. Update
  docs, tests, examples, and harness selectors with every DOM naming change.
- Treat MoonBit packages as compilation and dependency boundaries, not as a
  namespace for every Monaco file. Split files first, then promote stable
  subsystem boundaries into `renderer/*` and `renderer/browser/*` packages when
  that makes the dependency graph clearer.
- Keep common-layer packages DOM-free and FFI-free. Browser-layer packages may
  use JavaScript FFI only when they own browser-specific effects. No common
  package may import `dom`, `web`, or any `renderer/browser/*` package.
- Preserve current readonly behavior first, then implement the Monaco features
  that materially improve readonly UX: soft wrap, folding, inlay hints,
  selection/copy parity, and view zones. Accessibility is the only high-impact
  Monaco gap that this plan records and defers instead of implementing.
- Each phase may break old internal APIs, selectors, harness names, and
  docs/tests. The requirement is to migrate every caller, update documentation,
  and keep the resulting Monaco-shaped behavior correct.

## Current State

- `renderer` already owns much of Monaco's common-layer shape: tokenized
  document buckets, viewport-scoped `RenderFrame`, `ViewportData`,
  `ViewLineRenderingData`, `RenderLineInput`, `LineDecoration`,
  `LineDecorationsNormalizer`, `CharacterMapping`, `ViewLayout`,
  `LinesLayout`, `Scrollable`, `ScrollbarState`, and hit testing.
- `renderer/browser` already owns much of Monaco's browser-layer shape: an
  imperative root island, Monaco-shaped DOM containers, a ViewLayer-style line
  recycler, content/overlay widget slots, custom editor and hover scrollbars,
  hover controller behavior, browser input, and rAF-coalesced flushing.
- The remaining problem is not that the viewer lacks a Monaco-like split. The
  problem is that the split is unevenly named and documented. Several Monaco
  roles are compressed into large local files such as `render_line_ir.mbt` and
  `island.mbt`, which makes future source-led parity work harder.

## Reference Map

Use these Monaco files as the initial correspondence set:

```text
vscode/src/vs/editor/common/core/range.ts
vscode/src/vs/editor/common/core/position.ts
vscode/src/vs/editor/common/tokens/lineTokens.ts
vscode/src/vs/editor/common/viewModel.ts
vscode/src/vs/editor/common/viewModel/viewModelImpl.ts
vscode/src/vs/editor/common/viewModel/viewModelLines.ts
vscode/src/vs/editor/common/viewModel/modelLineProjection.ts
vscode/src/vs/editor/common/modelLineProjectionData.ts
vscode/src/vs/editor/common/viewModel/monospaceLineBreaksComputer.ts
vscode/src/vs/editor/common/coordinatesConverter.ts
vscode/src/vs/editor/common/viewModel/inlineDecorations.ts
vscode/src/vs/editor/common/viewLayout/lineDecorations.ts
vscode/src/vs/editor/common/viewLayout/viewLinesViewportData.ts
vscode/src/vs/editor/common/viewLayout/viewLineRenderer.ts
vscode/src/vs/editor/common/viewLayout/linesLayout.ts
vscode/src/vs/editor/common/viewLayout/viewLayout.ts
vscode/src/vs/editor/browser/view.ts
vscode/src/vs/editor/browser/view/viewLayer.ts
vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts
vscode/src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts
vscode/src/vs/editor/browser/viewParts/overlayWidgets/overlayWidgets.ts
vscode/src/vs/editor/browser/viewParts/viewZones/viewZones.ts
vscode/src/vs/editor/browser/viewParts/viewOverlays/viewOverlays.ts
vscode/src/vs/editor/browser/viewParts/margin/margin.ts
vscode/src/vs/base/browser/ui/scrollbar/scrollableElement.ts
vscode/src/vs/editor/contrib/hover/browser/contentHoverWidget.ts
vscode/src/vs/editor/contrib/folding/browser/foldingModel.ts
vscode/src/vs/editor/contrib/folding/browser/hiddenRangeModel.ts
vscode/src/vs/editor/contrib/folding/browser/foldingRanges.ts
vscode/src/vs/editor/contrib/inlayHints/browser/inlayHints.ts
vscode/src/vs/editor/contrib/inlayHints/browser/inlayHintsController.ts
vscode/src/vs/editor/browser/controller/editContext/clipboardUtils.ts
vscode/src/vs/editor/contrib/clipboard/browser/clipboard.ts
vscode/src/vs/editor/browser/viewParts/selections/selections.ts
```

The implementation may add rows when it discovers more directly relevant
Monaco files. Each added row must be source-led and tied to a local role.

## Phase 1: Monaco Layer Map Ledger

Create `docs/references/monaco-layer-map.md` before moving code.

The ledger must contain one row per Monaco role with these columns:

```text
Monaco source
Monaco role
Local package/file/type
Local status
Readonly decision
UX impact if partial or skipped
Notes
```

Allowed `Local status` values:

- `exact`: same role and substantially same data contract.
- `partial`: same role but missing behavior that matters to Monaco parity.
- `readonly-subset`: same role but intentionally smaller because the viewer is
  readonly.
- `future`: role is wanted but not implemented yet.
- `skipped`: role is intentionally out of scope.

Initial decisions to record:

- `Range` / `Position`: local equivalents live in `core`; keep existing package
  placement but map the role.
- `ViewLineRenderingData`, `RenderLineInput`, `LineDecoration`,
  `LineDecorationsNormalizer`, `CharacterMapping`: already implemented; map as
  `exact` or `partial` based on current behavior.
- `ViewModelLinesFromModelAsIs` and `CoordinatesConverter`: `future` before
  Phase 3.
- `ViewModelLinesFromProjectedModel`, soft wrapping, hidden areas, injected
  text, view zones, selection/copy, folding, and inlay hints: `future` before
  their implementation phases, high UX impact for Monaco-quality readonly
  behavior.
- Accessibility model, editable cursor, IME/text area, minimap, and overview
  ruler: `skipped` for this plan.

Exit criteria:

- The ledger links every implemented Monaco-shaped local role to a Monaco source
  path.
- Every partial/skipped row has a UX impact statement.
- The ledger clearly distinguishes "not implemented yet" from "intentionally
  not part of the readonly viewer."

## Phase 2: Common-Layer File and Name Alignment

Refactor `renderer` files so internal names follow Monaco common-layer roles.
This phase must be behavior-preserving.

Split the current render-line IR into smaller role-shaped modules:

```text
renderer/render_line_ir.mbt
  -> renderer/view_layout/view_lines_viewport_data.mbt
  -> renderer/view_line_renderer/line_part.mbt
  -> renderer/view_line_renderer/inline_decorations.mbt
  -> renderer/view_line_renderer/line_decorations.mbt
  -> renderer/view_line_renderer/view_line_rendering_data.mbt
  -> renderer/view_line_renderer/view_line_renderer_input.mbt
  -> renderer/view_line_renderer/character_mapping.mbt
  -> renderer/view_line_renderer/render_line_renderer.mbt
```

Use the Monaco-shaped package surface directly:

- `ViewportData`
- `ViewLineRenderingData`
- `RenderLineInput`
- `RenderLineOutput`
- `RenderLineOutput2`
- `LinePart`
- `InlineDecoration`
- `InlineDecorationType`
- `LineDecoration`
- `LineDecorationsNormalizer`
- `CharacterMapping`
- `DomPosition`
- `ForeignElementType`
- `render_view_line`
- `render_view_line2`

Replace old compatibility surfaces instead of preserving them:

- `RenderFrame`
- `RenderLine`
- `render_line_html`
- `render_line_class`

These names may remain only if the Monaco layer map says they are still the
correct local role. If they are only local legacy names, migrate their callers
to the role-aligned APIs and remove them in the same phase.

Implementation requirements:

- Move code mechanically first; avoid behavior edits in the same commit.
- Keep tests and snapshots passing before adding new concepts.
- Update package README text to say `renderer` is the Monaco `editor/common`
  role for this viewer.
- Keep `renderer` DOM-free and FFI-free.
- Update all imports, tests, docs, and harness references to the new names.
- Temporary aliases are allowed inside a single reviewable commit only if they
  are removed before the phase is marked complete.

Exit criteria:

- Renderer test output and browser output remain semantically equivalent, with
  test expectations updated to the new Monaco-aligned names.
- The file layout makes it obvious where to compare Monaco's
  `viewLineRenderer.ts`, `lineDecorations.ts`, `inlineDecorations.ts`, and
  `viewLinesViewportData.ts`.
- No product package imports from `vscode/` or `codemirror/`.

## Phase 3: Readonly ViewModel Spine

Add a readonly version of Monaco's common `ViewModel` spine. This phase adds
structure for future Monaco parity but should still preserve visible behavior.

Add these internal roles in the common layer. They may start in `renderer`
during this phase and move to `renderer/view_model` or `renderer/view_layout`
in Phase 6:

- `ViewModel`
- `ViewModelLines`
- `ViewModelLinesFromModelAsIs`
- `IdentityCoordinatesConverter`
- `CoordinatesConverter` trait or equivalent interface
- `ViewModelDecorations` placeholder or minimal readonly collection adapter

Initial behavior:

- Use `ViewModelLinesFromModelAsIs` only.
- There is one view line per document line.
- No soft wrapping.
- No hidden areas.
- No injected text.
- Identity coordinate conversion maps model line/column to the same view
  line/column.
- `ViewportData` should be obtained from `ViewModel` plus `ViewLayout`.
  After Phase 6, `ViewportData` belongs with `renderer/view_layout`.

Data flow target:

```text
DocumentSnapshot / TokenizedDocument / ProviderResult
  -> ViewModel
  -> ViewModelLinesFromModelAsIs
  -> ViewLayout
  -> ViewportData
  -> ViewLineRenderingData
  -> RenderLineInput
```

Migration requirements:

- Migrate viewer rendering to exercise the new `ViewModel` path directly.
- Do not add wrapping, folding, inlay hints, or selection rendering in this
  phase.
- Rename public or internal viewer APIs when Monaco role alignment requires it,
  then update all callers, examples, docs, and tests in the same phase.

Exit criteria:

- Unit tests prove identity model/view coordinate conversion.
- Unit tests prove `ViewModelLinesFromModelAsIs` returns the same content,
  columns, and token line parts as the previous direct frame path.
- The Monaco layer ledger marks these roles as `readonly-subset` rather than
  `future`.
- No stale direct-render-frame browser path remains solely for compatibility.

## Phase 4: ViewportData Backing Migration

Move the primary pre-DOM viewport path toward the new `ViewModel` spine.

Implementation requirements:

- `ViewportData` should mirror Monaco's role more closely:
  - expose 1-based inclusive start/end view line numbers;
  - expose relative vertical offsets;
  - expose visible range;
  - expose `big_numbers_delta`, initially `0`;
  - provide access to `ViewLineRenderingData` by line number;
  - provide access to decorations in the viewport.
- Keep the implementation ready to move to `renderer/view_layout` in Phase 6.
- Keep current O(window) behavior for large documents.
- Keep `TokenizedDocument` and provider buckets so provider pushes do not
  re-tokenize.
- Remove direct `RenderFrame` consumers unless the layer map identifies a
  remaining Monaco-equivalent role for them.

Exit criteria:

- The browser line renderer consumes `ViewportData` and `RenderLineInput` from
  the new common spine.
- After Phase 6, this means `ViewportData` from `renderer/view_layout` and
  `RenderLineInput` from `renderer/view_line_renderer`.
- Existing render-frame JSON or old local helpers are no longer the browser
  line-rendering path.
- Performance tests continue to show window-bounded rendering.

## Phase 5: Browser-Layer Role Extraction

Refactor `renderer/browser` so files and internal types follow Monaco browser
roles. This phase should preserve readonly behavior, but it does not need to
preserve old local APIs, selectors, file names, or harness names.

Target browser roles:

```text
renderer/browser/view.mbt
renderer/browser/view_layer.mbt
renderer/browser/view_line.mbt
renderer/browser/content_widgets.mbt
renderer/browser/overlay_widgets.mbt
renderer/browser/view_zones.mbt
renderer/browser/view_overlays.mbt
renderer/browser/margin.mbt
renderer/browser/scrollable_element.mbt
renderer/browser/hover_controller.mbt
```

Role ownership:

- `View` owns root DOM creation, render scheduling, read/write flush order,
  source state, and high-level layout application.
- `ViewLayer` owns rendered line and gutter node collections, entering/leaving
  line splices, and line retention.
- `ViewLine` owns per-line `RenderLineInput` construction, equality comparison,
  line HTML generation, `data-line`, top/height style, and direction attributes
  when supported.
- `ContentWidgets` owns text-anchored widgets. Hover is the first content
  widget.
- `OverlayWidgets` owns viewport-positioned widgets. It may remain mostly empty
  but must provide a stable role slot.
- `ViewZones` owns DOM slots for line-displacing widgets. This phase may keep
  the role slot minimal; Phase 11 implements real layout displacement and DOM
  application.
- `ViewOverlays` and `Margin` own non-text visual layers where they already
  exist or where current behavior can be moved without risk.
- `ScrollableElementDom` remains the shared editor/hover scrollable element and
  keeps Monaco-conformant scrollbar behavior.

Migration requirements:

- Rename or reshape `Viewer` methods, scroll methods, theme methods, feature
  provider plumbing, and notifications if the Monaco role alignment calls for
  it.
- Update every workbench/example caller in the same phase.
- Update harness controls, observability payloads, and selectors to the new
  Monaco-shaped names in `docs/harness.md` and browser tests.
- Keep DOM node count proportional to the rendered window.
- Do not introduce a Monaco contribution system or dependency-injection layer.

Exit criteria:

- `renderer/browser/island.mbt` is gone or reduced to a non-public bridge that
  is not referenced by docs, tests, or new code.
- The file names make the Monaco browser source comparison direct.
- Browser tests prove retained line nodes and limited `innerHTML` rewrites still
  work.

## Phase 6: Package Boundary Promotion

Promote the role-shaped files from Phases 2 through 5 into MoonBit packages
where Monaco's subsystem boundary is also a useful MoonBit dependency boundary.
This phase is still behavior-preserving. It should make the package graph match
the common vs browser ownership model without creating one package per Monaco
file.

Start with these candidate packages, adjusting only if the Phase 1 ledger shows
a clearer local boundary:

```text
renderer/view_line_renderer
renderer/view_model
renderer/view_layout
renderer/browser/view
renderer/browser/widgets
renderer/browser/scrollbar
```

Role ownership:

- `renderer/view_line_renderer` owns `LinePart`, `InlineDecoration`,
  `LineDecoration`, `LineDecorationsNormalizer`, `ViewLineRenderingData`,
  `RenderLineInput`, `RenderLineOutput`, `CharacterMapping`, and
  `render_view_line*`. It stays pure common-layer code: string/class/span data
  is allowed, DOM and browser FFI are not.
- `renderer/view_model` owns `ViewModel`, `ViewModelLines*`,
  `ModelLineProjection*`, `CoordinatesConverter`, hidden areas, injected text,
  and model/view range conversion as they are added in later phases.
- `renderer/view_layout` owns `ViewLayout`, `LinesLayout`, viewport window
  derivation, scroll state, line vertical offsets, `ViewportData`, and
  whitespace/view-zone layout data.
- `renderer/browser/view` owns browser `View`, `ViewLayer`, `ViewLine`,
  `ViewZones`, `ViewOverlays`, `Margin`, render scheduling, DOM lifecycle, and
  read/write flush ordering.
- `renderer/browser/widgets` owns browser content widgets, overlay widgets, and
  hover widget placement if the dependency split remains clean.
- `renderer/browser/scrollbar` owns DOM-backed `ScrollableElement` behavior.
  Pure scrollbar state used by common layout should stay in
  `renderer/view_layout` or another common package, not in the browser package.

Do not split these into separate packages unless a later dependency problem
proves it is necessary:

- `LinePart`
- `CharacterMapping`
- `InlineDecoration`
- `LineDecoration`
- `DomPosition`
- individual widget kinds
- individual Monaco source files that are just files, not subsystems

Migration requirements:

- Add `moon.pkg` files for every promoted package and update imports in all
  callers, tests, examples, and docs in the same phase.
- Keep common package imports one-way: `renderer/view_line_renderer`,
  `renderer/view_model`, and `renderer/view_layout` may depend on existing
  common packages such as `core`, `syntax`, `decorations`, `language`, and
  `workspace` as needed, but they must not depend on browser packages, `dom`,
  or `web`.
- Keep browser package imports one-way: browser packages may depend on common
  packages and `dom`, but common packages may not depend on browser packages.
- Keep product imports MoonBit-owned. No package may import or generate code
  from `vscode/` or `codemirror/`.
- Update `scripts/check-architecture.mbtx` so it knows the new package graph
  and rejects common-to-browser back edges.
- Update `renderer/README.md`, `renderer/browser/README.md`, and any new
  package README files to explain package ownership and import direction.
- Remove old package-level compatibility shims. Because this plan does not
  require compatibility with previous internal APIs, migrate all callers to the
  new package paths directly.

Exit criteria:

- `moon.pkg` imports express the same common/browser boundary as the Monaco role
  map.
- `scripts/check-architecture.mbtx` passes and would fail for a common package
  importing browser-only code.
- Package names make source-led comparison easier without producing tiny
  packages for individual data types.
- The visible readonly viewer behavior is unchanged from Phase 5.

## Phase 7: Projected View Lines and Soft Wrap

Implement Monaco's projected view-line role for readonly documents. This is the
first feature phase after the architecture extraction because wrapping changes
line identity, vertical layout, hit testing, hover anchoring, and copy
semantics.

Common-layer roles to add or complete:

- `ViewModelLinesFromProjectedModel`
- `ModelLineProjection`
- `ModelLineProjectionData`
- `LineBreaksComputer`
- full `CoordinatesConverter` for model/view round trips

Implementation requirements:

- Keep `ViewModelLinesFromModelAsIs` as the no-wrap fast path.
- Add a wrap mode controlled by viewer options, defaulting to off for behavior
  preservation unless a caller enables it.
- The browser measures viewport width, glyph metrics, tab size, and font
  changes. `renderer` owns the projected-line data and coordinate conversion.
- Start with Monaco's monospace line-break model: wrapping is based on measured
  columns and tab expansion, not browser-native word wrapping.
- Recompute projections when document content, viewport width, tab size, font
  metrics, hidden areas, or injected text changes.
- `ViewportData` and `ViewLayout` operate in view-line coordinates once wrapping
  is enabled.
- Hit testing, hover anchor lookup, line numbers, diagnostics, semantic tokens,
  and `CharacterMapping` must map projected view positions back to model
  positions.
- Wrapped continuation lines should use Monaco-compatible
  `continues_with_wrapped_line`, `min_column`, `max_column`,
  `start_visible_column`, and `faux_indent_length` data.

Tests:

- Unit tests for one model line producing one, two, and many view lines.
- Unit tests for model-to-view and view-to-model conversion at wrap boundaries.
- Unit tests for tabs, full-width characters, and long MoonBit lines.
- Browser tests for wrapped long lines, hover on wrapped continuations,
  diagnostics on wrapped text, scroll position, and line-number alignment.

Exit criteria:

- Soft wrap can be enabled without breaking the default no-wrap viewer.
- Wrapped view lines render through the same `ViewportData` ->
  `RenderLineInput` path as unwrapped lines.
- Hover, diagnostics, and hit testing resolve model offsets correctly on wrapped
  lines.

## Phase 8: Hidden Areas and Folding

Implement readonly folding on top of the projected view-line and coordinate
conversion model. Folding should hide model ranges, update view-line projection,
and expose Monaco-shaped margin controls.

Common and language roles to add:

- `FoldingRange`
- `FoldingRangeKind`
- `FoldingRangeProvider`
- `FoldingModel`
- `HiddenRangeModel`
- hidden-area support in `ViewModelLines`

Implementation requirements:

- Add `FoldingRange` and `FoldingRangeProvider` to `language`.
- Add provider registration and collection in `renderer/browser` services.
- Extend `remote_protocol`, `server`, and `workbench` with optional folding
  range transport. If the backend cannot supply folding ranges, the provider
  returns an empty list and the viewer uses a local indentation-based fallback
  for MoonBit documents.
- Store folded ranges as hidden areas in `ViewModelLines`; hidden model lines
  should produce no view lines.
- Folding must preserve document offsets and model ranges; it only changes the
  view projection.
- Add margin folding markers for foldable ranges and folded ranges. Clicking a
  marker toggles the folded state.
- Recompute viewport, scroll height, line numbers, hit testing, diagnostics,
  hover anchoring, and selection after fold changes.
- Folding state is per document URI/version identity. A document content change
  may clear invalid folded ranges but should preserve still-valid folds where
  possible.

Tests:

- Unit tests for folding range normalization, nested ranges, overlapping ranges,
  invalid ranges, and hidden-area projection.
- Unit tests for coordinate conversion across hidden areas.
- Browser tests for fold/unfold by margin marker, scroll height changes,
  diagnostics before/after folds, hover around folded boundaries, and wrapped
  lines inside/outside folded ranges.

Exit criteria:

- Folded ranges hide content from the view without mutating the document.
- Fold markers render in the margin and stay aligned with line numbers.
- View/model coordinate conversion remains correct across hidden areas.

## Phase 9: Injected Text and Inlay Hints

Implement Monaco-shaped injected text, then build readonly inlay hints on top of
that path. Inlay hints should be rendered as projected view content, not as
ad-hoc browser overlays.

Common and language roles to add:

- `InjectedText`
- injected-text support in `ModelLineProjection`
- `InlayHint`
- `InlayHintKind`
- `InlayHintsProvider`
- injected-text inline decorations

Implementation requirements:

- Add `InlayHint` and `InlayHintsProvider` to `language`.
- Add provider registration and collection in `renderer/browser` services.
- Extend `remote_protocol`, `server`, and `workbench` with optional inlay-hint
  transport. If the backend cannot supply hints, the provider returns an empty
  list and the viewer simply renders no hints.
- Represent inlay hints as injected text attached to a model position with a
  label, kind, padding flags, and optional tooltip/hover content.
- Projection must include injected text before line breaking so wrap positions
  include hint width.
- `RenderLineInput` receives tokens and inline decorations that distinguish
  source text from injected text.
- Hit testing should report model positions and indicate injected-text hits so
  hover can show hint tooltips without treating hint text as editable source.
- Plain text copy should exclude injected text by default. Rich HTML copy may
  include inlay hint spans only if a dedicated option enables it.
- Inlay hints should update when providers push new results, document content
  changes, wrapping changes, or folding changes.

Tests:

- Unit tests for injected text before/after a position and at line boundaries.
- Unit tests for line breaking with injected text.
- Unit tests for model/view conversion through injected text.
- Browser tests for hint rendering, hover over a hint, wrapping with hints,
  folding around hints, and copying source text without hint labels.

Exit criteria:

- Inlay hints render through the same projected-line and render-line path as
  source text.
- Hints participate in wrapping and hit testing but do not corrupt model offsets.
- Copying selected source excludes hint labels unless explicitly configured
  otherwise.

Implementation note, 2026-06-16: the first two exit criteria are implemented.
Plain-text copy exclusion is carried by Phase 10, where readonly selection/copy
is introduced.

## Phase 10: Selection and Copy Parity

Implement readonly selection and copy behavior with Monaco-shaped model/view
range conversion. This is not an editable cursor or IME phase.

Common and browser roles to add:

- `Selection`
- view selections mapped to model ranges
- selection overlay rendering
- `get_plain_text_to_copy`
- `get_rich_text_to_copy`
- browser copy bridge

Implementation requirements:

- Support mouse drag selection in the editor content area.
- Store selection as model ranges, with view ranges derived through
  `CoordinatesConverter`.
- Render selected text through a browser selection view part, not by mutating
  token spans directly.
- Selection must work across wrapped lines, folded hidden areas, and injected
  text.
- Copy plain text from model ranges using document text, respecting line endings
  and excluding injected text/inlay hints by default.
- Copy rich HTML with token classes for selected visible source text when the
  browser clipboard supports HTML.
- If a selection crosses folded content, copy the model text represented by the
  selected model range. Hidden folded text is included only when the selection
  range logically spans it; clicking a folded placeholder alone does not select
  hidden text.
- Keep editable cursor, keyboard text input, IME, and accessibility textarea out
  of scope.

Tests:

- Unit tests for selected view ranges converting to model ranges across wraps,
  folds, and injected text.
- Unit tests for plain text and rich HTML copy output.
- Browser tests for drag selection, copy shortcut, copied text observability,
  wrapped selections, folded selections, and inlay-hint exclusion.

Exit criteria:

- Users can select and copy readonly source reliably.
- Copy output is source-faithful by default.
- Selection rendering does not break hover, scroll, or line recycling.

Implementation note, 2026-06-16: readonly drag selection is implemented as
model-owned `Selection` state plus browser overlay rectangles in
`.view-overlays`. Copy writes `text/plain` from the selected
`DocumentSnapshot` range, so injected inlay-hint labels are excluded and folded
model text is included only when the selected range spans it. The browser copy
bridge writes `text/html` from visible render-frame source spans with token
classes when a frame is available, falling back to escaped model text. The
component browser test covers drag selection after an overlapping hover, copy
shortcut observability, token-class rich HTML, wrapped lines, folding around the
same fixture, and inlay-hint exclusion.

## Phase 11: View Zones

Implement Monaco-shaped view zones as real line-displacing layout entries. View
zones are required for peek-like panels, code-lens-style blocks, and future
inline readonly UI.

Common and browser roles to complete:

- `IEditorWhitespace`-like layout data in `LinesLayout`
- `IViewWhitespaceViewportData`-like viewport data
- `ViewZone`
- `ViewZoneChangeAccessor`
- browser `ViewZones`

Implementation requirements:

- `LinesLayout` must account for view-zone height when computing content height,
  line vertical offsets, viewport windows, and hit testing.
- `ViewportData` must expose whitespace/view-zone viewport data.
- Browser `ViewZones` must mount zone DOM nodes in `.view-zones`, position them
  between lines, and update them during the read/write render cycle.
- Content widgets, overlay widgets, line numbers, current-line/selection
  overlays, scrollbars, and hover placement must account for zone displacement.
- Provide a minimal public/internal API to add, update, and remove readonly view
  zones by id, anchor line, height, and DOM/content renderer.
- Add one internal fixture view zone for tests; do not build a full peek UI in
  this phase.

Tests:

- Unit tests for `LinesLayout` offsets with multiple zones, zero-height zones,
  zones at top/bottom, and zone removal.
- Unit tests for viewport derivation and hit testing around zone boundaries.
- Browser tests for zone rendering, scroll height changes, line alignment,
  hover after zones, selection across zones, and line recycling with zones.

Exit criteria:

- View zones displace lines and participate in layout as Monaco view whitespaces
  do.
- The browser has a stable `.view-zones` implementation for future peek-like
  features.
- Existing hover, scrollbars, wrapping, folding, inlay hints, and selection keep
  working when zones are present.

Implementation note, 2026-06-16: implemented by the common zone-aware
`LinesLayout` and browser `ViewZoneChangeAccessor` described above. This phase
does not add a peek UI; the test fixture uses a small readonly DOM zone.

## Phase 12: Accessibility Deferred Ledger

Update `docs/references/monaco-layer-map.md` with the remaining accessibility
gap. This phase does not implement Monaco's accessibility textarea, screen
reader simple model, or ARIA-rich interaction model.

Required ledger decision:

- Accessibility model: `skipped` in this plan, high UX impact, requires a
  dedicated follow-up plan.

The ledger should explain that this plan improves readonly visual and source
interaction parity, but it does not claim Monaco accessibility parity.

Exit criteria:

- Accessibility is not hidden under generic "future work."
- The final docs explicitly say that accessibility parity remains a separate
  high-priority design area.

Implementation note, 2026-06-16: the Monaco layer map records the accessibility
model as skipped for this plan with high UX impact and a dedicated follow-up
requirement.

## Phase 13: Documentation and Harness Updates

Update living docs after implementation lands:

- `docs/architecture.md`
  - Describe `renderer/*` as the Monaco common-layer package family and
    `renderer/browser/*` as the Monaco browser-layer package family.
  - Replace "backend-neutral for future TUI" language with "pre-DOM common
    layer, browser DOM layer."
- `renderer/README.md`
  - Document the common-layer package family, import direction, render-line
    roles, layout roles, and the readonly `ViewModel` spine.
- `renderer/browser/README.md`
  - Document the browser-layer package family, `View`, `ViewLayer`, `ViewLine`,
    widget slots, scrollable element, and browser-only ownership.
- New package README files, if created
  - Explain why each package is a dependency boundary rather than only a Monaco
    filename mirror.
- `docs/harness.md`
  - Update selectors, harness controls, observability payloads, and examples to
    the new Monaco-shaped names.
- `docs/references/monaco.md`
  - Link to the new Monaco layer map.

Documentation must distinguish:

- exact Monaco role correspondence;
- readonly subsets;
- browser conformance areas;
- intentionally skipped editable/editor-platform machinery.

## Validation

Run these checks before marking the plan implemented:

```sh
moon check --target all
moon test --target js renderer
moon test --target native renderer
moon test --target js renderer/view_line_renderer
moon test --target js renderer/view_model
moon test --target js renderer/view_layout
moon test --target js renderer/browser/view
moon test --target js renderer/browser/widgets
moon test --target js renderer/browser/scrollbar
just check
just test
just test-browser-conformance
just test-browser
```

If browser file extraction is broad, also run a live smoke check against the
standard fixture app:

```sh
just dev ROOT=/Users/baozhiyuan/Workspace/moonbit-project/simple PORT=5173
```

Then verify in the browser that the readonly viewer opens MoonBit files, scrolls,
keeps hover behavior, renders diagnostics, and keeps Monaco-conformant hover and
scrollbar behavior.

Feature-specific validation must also cover:

- enabling and disabling soft wrap;
- fold and unfold from the margin;
- inlay hint rendering and hover;
- drag selection and clipboard copy;
- a test view zone that displaces lines;
- combinations of wrap, fold, hints, selection, zones, hover, and diagnostics.

## Acceptance Criteria

- A Monaco layer map exists and is useful as the first stop for source-led
  future work.
- Internal local names line up with Monaco common/browser roles where the roles
  match.
- Stable subsystem boundaries are promoted to MoonBit packages under
  `renderer/*` and `renderer/browser/*`; tiny data roles remain files instead
  of becoming one-type packages.
- The architecture guard understands the promoted package graph and prevents
  common-layer packages from importing browser-only packages or DOM effects.
- All old local APIs, selectors, docs, tests, and examples touched by the
  refactor are migrated to the Monaco-aligned names; no compatibility shim is
  left solely for old names.
- Current readonly rendering, scrolling, diagnostics, hover, and conformance
  behavior are preserved.
- The primary browser line-rendering path flows through the role-aligned common
  spine and `RenderLineInput`.
- Soft wrap, folding, inlay hints, selection/copy parity, and view zones are
  implemented as readonly Monaco-role-aligned features.
- Accessibility remains the only high-impact Monaco UX gap intentionally
  deferred by this plan, and it is tracked with a readonly decision and UX
  impact.
- Implemented historical exec plans remain unchanged.

## Risks

- A pure rename can become too large to review. Keep file splitting,
  common-spine introduction, browser extraction, and package promotion in
  separate commits.
- Package splitting can create churn without architectural value. Promote only
  subsystem boundaries that reduce dependency ambiguity; keep individual data
  roles as files inside a package.
- Package promotion can create import cycles. Update `moon.pkg` files and
  `scripts/check-architecture.mbtx` in the same phase, and keep common packages
  free of browser, DOM, and FFI imports.
- Monaco names can leak into public product identity. This plan accepts that
  changed internal/public viewer surfaces may use Monaco role names, but package
  imports must still stay MoonBit-owned and must not import Monaco runtime code.
- ViewModel scaffolding can accidentally imply feature support before the
  relevant phase lands. Mark wrap, folding, injected text, selection, and view
  zones as `future` only until their phases are implemented, and keep tests on
  the identity/no-wrap path until Phase 7 changes that default.
- Browser extraction can accidentally rewrite line DOM too often. Preserve
  `RenderLineInput` equality checks and add browser assertions for node
  retention and limited HTML rewrites.
- Feature phases can interact badly with one another. Validate combinations in
  browser tests instead of testing wrap, fold, hints, selection, and zones only
  in isolation.
