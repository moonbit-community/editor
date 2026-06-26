# Production `LineTokens` Pipeline with MoonBit Lexers

Status: done — Date: 2026-06-26.

Implementation: all five phases landed. `token_theme.mbt` packs each
`HighlightTag` into a Monaco metadata word + an `mtk<colorId>` color map
(reusing the workbench `--vscode-token-*` vars); `line_tokens_encoder.mbt`
encodes each line's `@syntax.Token`s into a faithful `LineTokens`;
`TokenizedDocument` stores one `LineTokens` per line; production rendering
derives spans/`LinePart`s by walking `IViewLineTokens` (`spans_from_line_tokens`),
emitting `mtk<n>` classes. `HighlightTag::css_class` and the `tok-*` CSS are
removed (the lexer golden tests now label tokens by tag name via a `Show` impl).
`RenderSpan` survives as the line geometry carrier (projected/injected-text path,
mouse target, simple HTML emitter) sourced from `LineTokens`, not `@syntax.Token`
— so its struct stays (the Phase 5 "if no longer referenced" condition is unmet).
Semantic tokens keep the pragmatic post-derivation `sem-<type>` overlay.
Deferred as planned: `RangePriorityQueueImpl`, embedded-language `LanguageIdCodec`,
`ViewLayout` ↔ `LinesLayout`. Browser specs were remapped to `mtk<n>`; rerun
`just test-browser` to confirm the rendering gate.

Oracle pin: `vscode` submodule at `294fb350` (2026-06-02, `heads/main`).
Std pin: `moonbitlang/core` at the toolchain in use (`moon 0.1.20260618`).

Follows `monaco-test-conformance-port.md` (which landed the faithful
`LineTokens` / `TokenMetadata` ports) and closes Finding **D** of
`std-dedup-and-divergence-review.md` (the conformance-only-vs-production token
split). Related: `lexmatch-tokenization-registry.md` (the MoonBit lexer
contract this plan keeps unchanged).

## Goal

Make production rendering consume Monaco's ported token model instead of the
parallel simplified one, **without rewriting the syntax-highlight definitions**.
Concretely:

- Production tokens flow through the faithful `LineTokens` / `IViewLineTokens` /
  `TokenMetadata` / `MetadataConsts` cluster (`viewer/view_model/line_tokens.mbt`,
  `encoded_token_attributes.mbt`) rather than the `@syntax.Token` →
  `RenderSpan` path.
- The per-language highlighters stay **MoonBit `LineTokenizer` lexers** with
  their regex / `lexmatch` definitions (`syntax/lang_javascript`, `lang_moonbit`,
  `lang_json`). They are the `ITokenizationSupport`; only their *output
  encoding* and *storage* change.
- The already-faithful line renderer (`render_view_line2`,
  `viewer/view_line_renderer/render_line_renderer.mbt`) is reused as-is.

When this lands, the faithful token cluster is no longer conformance-only, and
the Finding D drift risk is retired by *unification* rather than by the
docs-only cross-link of `std-dedup-and-divergence-review.md` Step 6.

## Why this is bounded

The production renderer is **already** Monaco's ported `renderLine`. Only the
token model in front of it is simplified. Current production chain:

```
@syntax.Token (tag, range)                                   ── SIMPLIFIED
  → TokenizedDocument: Array[Array[@syntax.Token]]            ── SIMPLIFIED
  → spans_for_line → RenderSpan{ class_name = "tok-keyword" } ── SIMPLIFIED
  ───────────────────────────────────────────────────────────
  → view_line_data builds Array[LinePart] from spans         ── bridge
  → RenderLineInput{ line_tokens: Array[LinePart] }
  → render_view_line2()        ── FAITHFUL MONACO renderLine PORT (keep)
  → HTML
```

The target replaces the three SIMPLIFIED rows; the bridge and renderer below
the line are reused. The MoonBit lexers (`LineTokenizer.tokenize_line` →
`Array[LineToken]`, `syntax/tokenizer.mbt:13`) are untouched — this maps onto
Monaco's own decoupling, where Monarch/TextMate grammars are just one
`ITokenizationSupport` and `LineTokens` is agnostic to how the
`[endOffset, metadata]` pairs were produced.

### What is explicitly out of scope

- **`RangePriorityQueueImpl` / background tokenizer** (`text_model_tokens.mbt`)
  is orthogonal — it only schedules *incremental / async* retokenization.
  Production stays synchronous-per-version; `tokenize_document_lines` already
  records per-line entry states (`syntax/driver.mbt`) so an incremental pass
  remains a future driver-only change. This plan does **not** adopt the queue.
- **Embedded / multi-language models.** `LanguageIdCodec` stays the null-only
  placeholder (`line_tokens.mbt`); full `languagesRegistry` integration is the
  deferred Phase-4 item and not required for single-language-per-model viewing.
- The deferred `ViewLayout` ↔ `LinesLayout` reconciliation (a separate Finding D
  pair) is unrelated and stays out of scope.

## Findings the plan relies on (verified)

- `render_view_line2` consumes `RenderLineInput.line_tokens : Array[LinePart]`
  (`view_line_renderer_input.mbt:11`), where `LinePart` carries a `class_name`
  string (`line_part.mbt`). It already emits Monaco class names (`mtkw`,
  `mtkcontrol`, `mtkz`) and handles whitespace / control chars / RTL / inline
  decorations. The renderer is class-name driven and tokenizer-agnostic.
- `RenderLineInput` today is built from `RenderSpan`s in
  `viewer/view_model/view_line_data.mbt:34` (`from_view_line`), the single seam
  where the simplified token model meets the faithful renderer.
- The faithful `LineTokens` exposes the encoders this plan needs:
  `create_from_text_and_metadata(Array[(String, UInt)])`,
  `convert_to_end_offset`, `get_class_name(i)` → `mtk<fg>` (+ `mtkb`/`mtki`/
  `mtku`/`mtks`), and `get_inline_style(i, color_map)`.
- `MetadataConsts` offsets are `pub` (`METADATA_FOREGROUND_OFFSET`,
  `METADATA_FONT_STYLE_OFFSET`, `METADATA_TOKEN_TYPE_OFFSET`, …,
  `encoded_token_attributes.mbt`), so a metadata word is built as
  `(fg << FOREGROUND_OFFSET) | (fontStyle << FONT_STYLE_OFFSET) | …`.
- The richness of `@syntax.HighlightTag` (Keyword vs Type vs Function …) maps to
  the **9-bit foreground color id**, not to the 2-bit `StandardTokenType`. Only
  `Comment` / `String` / `Regexp` need to set `StandardTokenType` bits. So a
  20-variant tag set fits the metadata word with no information loss.

## Phases

Ordered so each phase is independently `just check` / `just test` green and the
old path keeps working until the final swap. Phases 1–3 add the new model behind
the existing one; Phase 4 flips the seam; Phase 5 deletes the dead path.

### Phase 1 — `HighlightTag` → metadata word + a minimal theme

The one genuinely new subsystem. `LineTokens::get_class_name` returns
`mtk<foregroundColorId>`, so production CSS must resolve `.mtk<n>` — this is
Monaco's theme color map (`TokenizationRegistry.getColorMap()` emitted as a
`<style>` block), not per-tag semantic classes.

- New `viewer/view_model` (or a small `viewer/theme`) module:
  - `tag_to_metadata(tag : @syntax.HighlightTag, font_style~, language_id~) ->
    UInt` — assigns each tag a stable foreground color id + font style + (for
    Comment/String/Regexp) a `StandardTokenType`, packed via the `MetadataConsts`
    offsets.
  - A fixed color map: `colorId → CSS color` as `Array[String]`, plus a
    generated `<style>` (`.mtk1{color:#…}` …) or use `get_inline_style` with the
    color map. Choose **class + `<style>`** to match Monaco and keep the DOM
    diffable.
- Keep the existing `HighlightTag::css_class` (`syntax/highlight.mbt:44`) for now
  — it is deleted only in Phase 5. Both can coexist.
- Unit-test the packing round-trips through `TokenMetadata::get_foreground` /
  `get_font_style` / `get_token_type` and that `get_class_name_from_metadata`
  yields the expected `mtk…` string per tag.

### Phase 2 — Encode lexer output into per-line `LineTokens`

- Add a converter from a line's `Array[@syntax.LineToken]` (line-local
  `start`/`end`/`tag`) to a `LineTokens` for that line: fill inter-token gaps
  with a default-metadata token (Monaco semantics), map each `tag` through
  `tag_to_metadata`, and build `[endOffset, metadata]` pairs via
  `create_from_text_and_metadata` / `convert_to_end_offset`.
- Site this in the driver path so it reuses the existing line sweep: extend
  `syntax/driver.mbt`'s `tokenize_document_lines`, or add a parallel
  `tokenize_document_to_line_tokens` returning `Array[LineTokens]`, keeping the
  `@syntax.Token` driver intact until Phase 5. Prefer a thin viewer-side adapter
  over `Array[LineToken]` so `syntax` need not depend on `view_model`.
- Verify against a reference: a line tokenized both ways yields identical
  `(endOffset, class_name)` per token under the Phase-1 theme.

### Phase 3 — Store `LineTokens` per line in `TokenizedDocument`

- Replace `TokenizedDocument.line_tokens : Array[Array[@syntax.Token]]`
  (`tokenized_document.mbt`) with per-line `LineTokens` (`Array[LineTokens]`, or
  the encoded `Array[UInt]` per line — closer to Monaco's `TextModel` line-token
  store and cheaper to retain). `TokenizedDocument::tokens_for_line` becomes
  `line_tokens_for_line(line) -> LineTokens`.
- `TokenizedDocument::build` (`render.mbt:23` caller) now buckets/encodes via
  Phase 2. Per-version caching is unchanged; only the stored type differs.
- Word-wrap readiness: per-line `LineTokens` slices through `SliceLineTokens`
  when a wrapped view line covers a sub-range — record this as the reason for
  per-line storage even though wrap is not in scope here.

### Phase 4 — Derive `LinePart`s from `IViewLineTokens`; flip the seam

- Replace `spans_for_line` (`render_frame.mbt:144`) and the `RenderSpan`→`LinePart`
  build in `view_line_data.mbt:34` with a derivation that walks
  `IViewLineTokens`: for `i in 0..<get_count()`, emit
  `LinePart(get_end_offset(i), get_class_name(i), …)`. This is the Monaco
  `renderLine` input shape; `render_view_line2` is unchanged.
- **Semantic tokens.** `overlay_semantic_tokens` currently splits spans and
  appends `sem-<type>` (`render_frame.mbt`). Two options:
  - *Faithful*: merge semantic tokens into `LineTokens` metadata before
    derivation (theme resolves the semantic type → fg/fontStyle, overriding the
    syntactic word), matching Monaco.
  - *Pragmatic*: keep the post-derivation span/`LinePart` overlay.
  Pick faithful if the theme work in Phase 1 already yields a `type → colorId`
  map; otherwise land pragmatic and leave a TODO. Decorations are already passed
  separately to the renderer (`view_line_data.mbt`) and need no change.
- **Re-render diffing.** `view_layer.mbt` skips re-renders by comparing
  `RenderLineInput`. Ensure the derived `LinePart` array still compares equal
  across unchanged frames (add `equals` on `LineTokens`, or keep diffing derived
  `LinePart`s — `LinePart derive(Eq)` already).

### Phase 5 — Retire the simplified token model

- Delete `spans_for_line`, the `RenderSpan` struct (`render_frame.mbt:12`) if no
  longer referenced, `TokenizedDocument`'s old `@syntax.Token` bucketing, and
  the `@syntax.Token`-returning `tokenize_document` if Phase 2 superseded it.
- Delete `HighlightTag::css_class` and the `tok-*` CSS once nothing emits those
  classes.
- `@syntax.Token` / `HighlightTag` / `LineToken` / `LineTokenizer` **stay** —
  they are the lexer contract; only their downstream `RenderSpan` adapter goes.
- Update `viewer/view_model` + `viewer/view_line_renderer` READMEs: remove the
  Finding D "conformance-only twin" note (the type is now the production path).
- `moon check --warn-list "+1+2+3+6+7+29+49"` shows no new unused-symbol /
  unused-package warnings after the deletions.

## Validation

- `just check` + `just test` (and `moon test --target js,native` for multi-target
  packages) stay green after **each** phase. Phases 1–3 add code behind the live
  path, so test counts only grow; Phase 4 is the behavior-equivalent flip and
  Phase 5 is deletion.
- Phase 4 is the rendering-behavior gate: `just test-browser` must pass, and the
  emitted HTML for a representative file (multi-tag line, leading/trailing
  whitespace, a control char, an RTL run, an inline decoration, a semantic-token
  overlap) must match the pre-flip output up to the class-name remap
  (`tok-keyword` → `mtk<n>`). Capture a before/after HTML snapshot to prove
  equivalence.
- The faithful `LineTokens` / `text_to_html_tokenizer` reference tests
  (`line_tokens_reference_wbtest.mbt`, `text_to_html_tokenizer_reference_wbtest.mbt`,
  `text_model_tokens_reference_test.mbt`) stay green throughout — they now guard
  the production path, not a twin.

## Exit Criteria

- Production rendering builds `RenderLineInput.line_tokens` by walking
  `IViewLineTokens`; no `RenderSpan`-from-`@syntax.Token` path remains.
- `TokenizedDocument` stores per-line `LineTokens` (or encoded words); the
  MoonBit `LineTokenizer` lexers are unchanged and remain the sole token source.
- A single theme/color-map module resolves `mtk<colorId>` classes; no `tok-*`
  classes are emitted.
- `LineTokens` / `TokenMetadata` / `MetadataConsts` are referenced by production
  code, not only reference tests; the Finding D token half of
  `std-dedup-and-divergence-review.md` is closed by unification (its Step 6
  cross-link for the token cluster is dropped, not added).
- `RangePriorityQueueImpl`, embedded-language `LanguageIdCodec`, and the
  `ViewLayout` ↔ `LinesLayout` reconciliation remain explicitly deferred.
