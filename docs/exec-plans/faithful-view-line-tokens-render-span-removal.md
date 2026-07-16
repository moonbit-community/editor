# Faithful `ViewLineData` Tokens — Delete `RenderSpan`

Status: completed — Date: 2026-06-26.

> **Completion note.** Implemented across all four phases. `RenderSpan` and the
> projected-span machinery are gone; a `RenderLine` now carries
> `tokens : &IViewLineTokens` (Monaco's `ViewLineData.tokens`) plus
> `injected_inline_decorations`. Projected/injected lines are built by
> `LineTokens::with_inserted` + `slice_and_inflate`; injected-text (inlay-hint)
> classes are inline decorations, so the token stream carries only syntactic
> `mtk<colorId>` metadata (the injected token now renders
> `mtk1 inlay-hint inlay-hint-type`, one class richer than the prior
> span overlay and exactly Monaco's DOM). The `LinePart` bridge, rich copy,
> hit-testing (`span_index` → `token_index`), the standalone HTML emitter, and the
> frame JSON (`"spans"` → `"tokens"`) all read `IViewLineTokens`; the per-column
> maps stay the geometry source. `RenderLine`/`RenderFrame` drop `derive(Debug)`
> (a trait-object field), the only API deviation from the field-name plan.
> Validated: `just check` (0 errors), `moon test --target all`
> (424 js + 434 native, 0 failures), and the full browser suite
> (component/smoke/conformance/perf) green.

Oracle: checked-in `vscode` submodule (2026-06-02, `heads/main`).
Std pin: `moonbitlang/core` at the toolchain in use (`moon 0.1.20260618`).

Follows `production-line-tokens-pipeline.md`, which made production rendering
consume the faithful `LineTokens` token model but left `RenderSpan` in place as a
geometry/projection carrier (its Phase 5 "delete `RenderSpan` if no longer
referenced" condition was unmet). This plan removes `RenderSpan` by adopting
Monaco's `ViewLineData` shape end-to-end.

## Goal

Make a rendered view line carry **`tokens : LineTokens` + inline decorations**
(Monaco's `ViewLineData`) instead of `spans : Array[RenderSpan]`, and delete the
`RenderSpan` struct. Concretely:

- The projected/injected-text/wrap path produces a view line's tokens by
  `base.with_inserted(injected)` then `slice_and_inflate(start, end, delta)` —
  Monaco's `getLineTokensWithInjections` + `_getViewLineData`
  (`modelLineProjection.ts`). The already-ported `with_inserted` / `InsertedToken`
  / `slice_and_inflate` / `SliceLineTokens` (`line_tokens.mbt`) are the tools.
- Injected-text (inlay-hint) **classes** become **inline decorations**, not
  token metadata or span class strings — Monaco's
  `InjectedTextInlineDecorationsComputer` (`inlineDecorations.ts`). The token
  stream then carries only syntactic metadata (`mtk<colorId>`). (Semantic tokens
  were removed entirely, so there is no longer a `sem-<type>` overlay to fold in
  — see the note below.)
- Every `RenderSpan` consumer (the `LinePart` bridge, rich-copy HTML, mouse
  hit-testing, the standalone HTML emitter, the frame JSON) reads `IViewLineTokens`
  instead. The faithful renderer (`render_view_line2`) is unchanged.

When this lands, `RenderSpan`, `spans_from_line_tokens`, and the
`ProjectedLinePart`→span machinery are gone; the view line's token stream is the
single source of styled segments, matching Monaco exactly.

> **Note — semantic tokens removed.** An earlier change deleted the semantic-token
> pipeline (LSP `semanticTokens/full`, the remote protocol messages, the
> `SemanticTokensProvider` trait, the viewer overlay, and the `sem-*` CSS), so
> `overlay_semantic_tokens` / `slice_span` / `semantic_token_class` no longer
> exist. This plan therefore only has to relocate **injected-text** classes;
> there is no semantic overlay to convert.

## Monaco architecture (the target shape)

`ModelLineProjection.getViewLinesData` (`modelLineProjection.ts:160`) builds each
view line as:

```
lineTokens          = model.tokenization.getLineTokens(modelLineNumber)
lineWithInjections  = getLineTokensWithInjections(lineTokens, opts, offsets)   // withInserted
lineInlineDecos     = new InjectedTextInlineDecorationsComputer(...).getInlineDecorations(...)
// per output (wrapped) line:
tokens              = lineWithInjections.sliceAndInflate(startOff, endOff, deltaStart)
return new ViewLineData(lineContent, …, tokens, inlineDecorations)
```

- `getLineTokensWithInjections` (`textModel.ts:2135`) is exactly
  `tokens.withInserted([{ offset, text, tokenMetadata }])`, where injected text
  with no per-token info uses `LineTokens.defaultTokenMetadata`.
- `InjectedTextInlineDecorationsComputer.getInlineDecorations`
  (`inlineDecorations.ts:213`) emits an `InlineDecoration(range, inlineClassName,
  type)` per injected run that has an `inlineClassName` — i.e. the inlay-hint
  color is a **decoration**, never a token color.
- `ViewLineData` holds `tokens: IViewLineTokens` and
  `inlineDecorations: SingleLineInlineDecoration[] | null`; `renderViewLine`
  turns the tokens into `LinePart`s and the inline decorations into part-class
  merges. There is no per-line "span" type anywhere in this path.

The viewer is one step short of this: it already renders through the ported
`renderLine` and stores faithful `LineTokens`, but inserts a `RenderSpan` layer
to (a) carry injected-text/semantic class strings and (b) hold the
source-offset/injected-index geometry the projection slices.

## Why this is bounded

- The faithful primitives already exist and are conformance-tested:
  `LineTokens::with_inserted` / `InsertedToken` / `slice_and_inflate` /
  `SliceLineTokens` (`line_tokens.mbt`, `line_tokens_reference_wbtest.mbt`).
- `RenderLine` already carries the per-column projection maps
  (`model_columns`, `injected_text_indices`) and the helpers
  (`model_column_at_column`, `source_offset_at_column`,
  `injected_text_index_at_column`) that the consumers need for geometry — so
  removing `RenderSpan.source_start/source_end/injected_text_index` loses no
  information; those facts move to (or already live in) the per-column maps.
- The inline-decoration pipeline already exists end-to-end
  (`inline_decorations_for_line` / `line_decorations_for_line` →
  `RenderLineInput.line_decorations`), so injected-text and semantic classes
  have a faithful home with no new renderer work.

### Out of scope (unchanged from the prior plan)

- **Soft word wrap.** `slice_and_inflate` is the wrap tool, but production stays
  no-wrap; the slice is the whole line (`slice_and_inflate(0, len, 0)`). This
  plan wires the slice seam without enabling wrap.
- `RangePriorityQueueImpl` / background retokenization, embedded-language
  `LanguageIdCodec`, and the `ViewLayout` ↔ `LinesLayout` reconciliation stay
  deferred.
- `PositionAffinity`: `ProjectedTextLine` keeps its table-based, affinity-free
  coordinate maps (the readonly viewer has no caret); only the token production
  changes.

## Findings the plan relies on (verified)

- `RenderSpan` (`render_frame.mbt:12`) carries three things a `LineTokens` token
  does not: `source_start`/`source_end` (model-offset mapping),
  `injected_text_index`, and an arbitrary `class_name`. Current consumers:
  - **LinePart bridge** — `line_parts_from_render_line` (`view_line_data.mbt:43`)
    maps each span to `LinePart(span.end, span.class_name, …)`.
  - **Projected path** — `projected_render_spans` / `append_source_projected_spans`
    / `append_sliced_projected_spans` (`view_model_lines_projected.mbt`) slice the
    base line's spans by source offsets and emit `InjectedSegment` spans carrying
    the inlay class (`ProjectedLinePart` in `injected_text.mbt`).
  - **Rich copy** — `append_rich_copy_line_segments` (`selection.mbt:185`) walks
    spans, skips injected (`injected_text_index >= 0`), maps `source_start/end`
    to model offsets, writes `class_name`.
  - **Hit-testing** — `span_index_at_column` (`mouse_target.mbt:161`) and
    `span_anchor_for_target` (`input.mbt:161`) index `line.spans[span_index]`.
  - **Standalone HTML** — `render_source_line_html` / the simple emitter
    (`common/line_html.mbt:33`) writes `span.class_name` + escaped span text.
  - **Frame JSON** — `span_json` / `line_json` (`render_frame.mbt`) and
    `RenderLine::span_text`.
- The renderer's `LineDecoration`/`InlineDecoration` (`view_line_renderer`) merge
  classes onto the line parts they cover, so a token under a `sem-<type>` /
  `inlay-hint` inline decoration renders as `mtk<n> sem-<type>` — same DOM the
  span overlay produces today, and CSS order keeps the overlay winning.
- Injected-text offsets are 0-based model columns sorted ascending
  (`bucket_injected_text`, `normalize_injected_text`), exactly `with_inserted`'s
  precondition.

## Phases

Ordered so each phase is independently `just check` / `just test` green; the
`RenderSpan` layer stays live until the final consumer is flipped, then the
struct is deleted.

### Phase 1 — Injected-text classes become inline decorations

Move the injected-text class off `RenderSpan` onto the inline decoration
pipeline, so the token stream needs only syntactic metadata.

- Add an injected-text inline-decoration computer mirroring
  `InjectedTextInlineDecorationsComputer`: from a projected line's
  `InjectedSegment` parts, emit `InlineDecoration(OffsetRange(start, end),
  class_name)` over the projected (view-local) columns. Feed these into
  `view_line_rendering_data_from_render_line` alongside the existing
  `inline_decorations_for_line` output.
- Validation: the rendered HTML for a line with an inlay hint is byte-identical
  before/after (snapshot in `view_model_test` / `line_html_test`).
  `just test-browser` inlay specs stay green.

### Phase 2 — `RenderLine` carries `tokens : LineTokens`

Add the faithful token stream to `RenderLine` next to `spans` (expand/contract).

- `render_model_line` (`view_model.mbt`): set `tokens =
  tokenized.line_tokens_for_line(line_index)` (already the span source via
  `spans_from_line_tokens`).
- Projected path (`view_model_lines_projected.mbt`): build the view line's tokens
  the Monaco way —
  `base = tokenized.line_tokens_for_line(model_line)`,
  `with_inj = base.with_inserted(injected_tokens)` where each `InsertedToken` is
  `{ offset: model_column, text: injected_text, token_metadata:
  default_token_metadata() }`, then
  `tokens = with_inj.slice_and_inflate(segment_start, segment_end, delta)` (no
  wrap ⇒ `slice_and_inflate(0, len, 0)`). The `ProjectedTextLine` column maps are
  unchanged and still drive coordinate conversion.
- Keep `spans` populated this phase (still the live render input). Add an
  invariant test: walking `line.tokens` reproduces `line.spans` boundaries +
  classes (the `spans_from_line_tokens` equivalence, now from the stored tokens),
  and `with_inserted`/`slice_and_inflate` reproduce the projected text
  (`tokens.get_line_content() == line.text`).

### Phase 3 — Flip every consumer to `IViewLineTokens`

Switch each reader from `line.spans` to `line.tokens`, using the per-column maps
for geometry.

- **LinePart bridge** (`view_line_data.mbt`): `line_parts_from_render_line` walks
  `line.tokens` — `for i in 0..<get_count(): LinePart(get_end_offset(i),
  get_class_name(i), contains_rtl=…)`. This is Monaco's `renderViewLine` token
  loop. (Eq-based re-render diffing in `view_layer.mbt` still compares the
  derived `LinePart` array; add `LineTokens::equals` if a cheaper compare is
  wanted.)
- **Rich copy** (`selection.mbt`): walk `line.tokens`; for token `i` use
  `line.source_offset_at_column(start/end)` for the model range and
  `line.injected_text_index_at_column(start)` to skip injected runs; emit
  `get_class_name(i)` + the sliced text. Drops all `source_start/end` use.
- **Hit-testing** (`mouse_target.mbt` / `input.mbt`): `span_index` →
  `token_index`; `span_index_at_column` →
  `line.tokens.find_token_index_at_offset(column)`; anchor start/end from
  `get_start_offset` / `get_end_offset`. `MouseTarget` carries a token index.
- **Standalone HTML** (`common/line_html.mbt`): the simple emitter walks
  `line.tokens` (`get_class_name` + sliced text), matching the already-faithful
  `tokenize_to_string` (`text_to_html_tokenizer.mbt`) — consider delegating to it.
- **Frame JSON** (`render_frame.mbt`): replace the `"spans"` array with a
  `"tokens"` array (`{ endOffset, className, text }`); update
  `render_frame_test` / `tokenized_document_test` / `view_model_test` snapshots.

### Phase 4 — Delete `RenderSpan` and the span machinery

- Remove `RenderSpan` (`render_frame.mbt:12`), `RenderLine.spans`,
  `RenderLine::span_text`, `span_json`, `spans_from_line_tokens`, and the
  projected-span helpers (`projected_render_spans`,
  `append_source_projected_spans`, `append_sliced_projected_spans`).
  `ProjectedLinePart::InjectedSegment` keeps
  only what Phase 1's decoration computer needs (or is reduced to a parts list
  consumed there).
- `moon check --warn-list "+1+2+3+6+7+29+49"` shows no new unused-symbol
  warnings.
- Update `viewer/view_model` + `viewer/common` READMEs: `RenderLine` carries
  `tokens` (Monaco `ViewLineData`), no span type remains.

## Validation

- `just check` + `just test` (and `moon test --target js,native` for the
  multi-target packages) stay green after **each** phase. Phases 1–2 add behind
  the live path; Phase 3 flips consumers one at a time; Phase 4 deletes.
- `just test-browser` is the behavior gate (Phases 1 and 3 touch rendered DOM):
  the emitted HTML for a representative file — multi-tag line, an inlay hint, an
  RTL run, leading/trailing whitespace, a model inline decoration — must match
  the pre-change output byte-for-byte. Capture a before/after snapshot to prove
  equivalence.
- The faithful reference tests (`line_tokens_reference_wbtest`,
  `text_to_html_tokenizer_reference_wbtest`) stay green; `with_inserted` /
  `slice_and_inflate` are now exercised by production, not only the suite.

## Exit Criteria

- A rendered view line exposes `tokens : LineTokens` + inline decorations; no
  `RenderSpan` type exists and nothing slices spans.
- Injected-text classes are inline decorations; the token stream carries only
  syntactic `mtk<colorId>` metadata.
- Projected/injected view lines are produced by `with_inserted` +
  `slice_and_inflate` (Monaco's `getViewLinesData`); `LinePart`s come straight
  from `IViewLineTokens`.
- Rich copy, hit-testing, the standalone HTML emitter, and the frame JSON all
  read `IViewLineTokens`; the per-column maps (`model_columns`,
  `injected_text_indices`) remain the geometry source.
- Soft word wrap, `RangePriorityQueueImpl`, embedded `LanguageIdCodec`, and
  `ViewLayout` ↔ `LinesLayout` remain explicitly deferred.
