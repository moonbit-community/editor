# Closing the Remaining Monaco Architecture Divergences

Status: **All three tracks landed** (2026-06-28; `just check` / `moon test
--target all` (js 433 / native 443) / `just test-browser` (44 specs) all green).
Track A was resumed from its deferred Phase 1 inventory and completed; the
view-line-number axis is now 1-based end to end. Date: 2026-06-28.

Landed summary:
- **Track A** — the view-line-number axis is 1-based throughout (`LineWindow`,
  `FrameViewport`, `ViewLayout`'s public surface, hit-testing). `ViewLayout`
  calls `LinesLayout` directly with no `± 1`; the zero-based-adapter doc-comment
  is gone; `ViewZone.anchor_line` is documented as Monaco's `afterLineNumber`
  (it was already numerically equal, so the clamp stays `[0, line_count]` — the
  plan's `[1, line_count + 1]` would have clipped an above-first-line zone; the
  remaining model-line-vs-view-line gap against Monaco's `IViewZone` is recorded
  in `docs/notes/view-zone-afterlinenumber-divergence.md`). The
  `ViewportData` start/end stay numerically identical (already 1-based
  inclusive), so the only residual conversion is the half-open↔inclusive shift
  at the `ViewportData`/`viewport_window` boundary, documented inline. Four
  frame-line index sites shared the `line_number - 1 - frame.viewport.start_line`
  pattern (`mouse_target.rendered_line`, `input.token_anchor_for_target`,
  `view_layer.window_index`, plus the `hover_render` mini-frame's `start_line:0`)
  and were the source of a hover/selection regression caught by `just
  test-browser`; all four were flipped to the 1-based form.
- **Track B** — `LanguageIdCodec` is now a real string↔numeric registry seeded
  with the built-in languages and shared per document; `TokenizedDocument::build`
  registers the model language and packs its numeric id into every token
  (gaps/blank lines included). Phases 1–3 done; Phase 4 (per-token language id on
  `@syntax.LineToken`/`Token`) stays deferred — it is labelled a "(Deferred
  extension)" and would touch ~54 construction sites with no embedded-grammar
  consumer, while the metadata word + `SliceLineTokens::get_language_id` are
  already per-token-capable.
- **Track C** — soft wrap supports `wrappingIndent` (`None`/`Same`/`Indent`/
  `DeepIndent`, default `Same`); continuation lines indent under the model line,
  the option is plumbed `ViewerOptions → ViewModelOptions → LineBreaksComputer`,
  and a faithful `monospace_line_breaks_computer_reference_wbtest` pins the break
  + indent computation. The browser scenario asserts the continuation's DOM left
  offset.

Oracle: checked-in `vscode` submodule (2026-06-02, `heads/main`).
Std pin: `moonbitlang/core` at the toolchain in use (`moon 0.1.20260618`).

Follows `production-line-tokens-pipeline.md` and
`faithful-view-line-tokens-render-span-removal.md`, which made production
rendering consume Monaco's faithful `LineTokens` / `ViewLineData` model and
deleted `RenderSpan`. After that work the **render path itself** matches Monaco;
the divergences that remain live in the systems that feed and position it. This
plan closes three of the four items left open by Finding **D** of
`std-dedup-and-divergence-review.md`:

- **Track A** — the `ViewLayout` zero-based adapter over the 1-based `LinesLayout`.
- **Track B** — the null-only `LanguageIdCodec` placeholder.
- **Track C** — soft word wrap (built behind `soft_wrap`, but several
  divergences from Monaco remain).

The fourth item — `RangePriorityQueueImpl` / background (incremental, async)
retokenization — stays **out of scope** here by request; production remains
synchronous-per-version and the faithful queue stays conformance-only.

The three tracks are independent and each is independently `just check` /
`just test` green at every phase. **Recommended landing order: B → C → A.** B is
the smallest and fully self-contained; C is bounded and only lightly touches
coordinates; A is the largest (a coordinate-space rebase) and is best done last,
coordinated with the pending `Position` 1-based rebase tracked in
`range-system-monaco-migration`.

---

## Track A — Remove the `ViewLayout` zero-based adapter (1-based view-line rebase)

### The divergence

`viewer/view_layout/lines_layout.mbt` is the faithful 1-based port of Monaco's
`LinesLayout`. `viewer/view_layout/view_layout.mbt` wraps it as a **zero-based
adapter**: the viewer addresses view lines with 0-based indices and translates
at every boundary —

- `vertical_offset_for_line(line)` → `get_vertical_offset_for_line_number(line + 1)`
  (`view_layout.mbt:142-143`);
- `line_at_vertical_offset(offset)` → `get_line_number_at_or_after_vertical_offset(...) - 1`
  (`view_layout.mbt:156-159`);
- view zones map `ViewZone { anchor_line }` (0-based) onto whitespaces as
  `afterLineNumber = anchor_line` (`view_layout.mbt:34-39`, doc at `:8-14`).

Monaco has **no such adapter**: its entire view layer is 1-based, so `ViewLayout`
and `LinesLayout` share one coordinate space. The `± 1` translation is pure
impedance matching that exists only because the viewer's view-line-number axis is
0-based. This is also the layout half of the broader `Position` 1-based rebase
already tracked as pending in `range-system-monaco-migration`.

### Goal

Rebase the **view-line-number axis** to 1-based (Monaco's view coordinate space)
so `ViewLayout` calls `LinesLayout` directly with no `± 1`, view zones carry
Monaco's `afterLineNumber` semantics, and the adapter doc-comment is deleted.
This is the column-axis-independent half of the `Position` rebase; the column
(1-based) rebase can follow separately.

### Why this is bounded

- `LinesLayout` is already the target type and already 1-based — nothing under
  the adapter changes. Only the ~8 `ViewLayout` public methods and their callers
  flip.
- The 0-based axis is small and enumerable: `LineWindow { start, end }`, the
  frame's per-line `line_number`s, the render window translation in
  `viewer/render.mbt` / `view_layer.mbt`, and hit-testing's view-line lookups.
- The viewer is read-only, so there is no caret/selection arithmetic that has to
  flip in lockstep — only addressing and layout geometry.

### Out of scope

- The **column** axis (1-based `Position.column`) rebase — its own tracked
  migration; this track touches only the line-number axis.
- Any `LinesLayout` behavior change (it is already faithful).

### Findings the plan relies on (verified)

- The adapter's only real work is the `± 1` line translation and the
  `afterLineNumber = anchor_line` zone mapping; everything else in
  `view_layout.mbt` is already coordinate-neutral (scroll, dimensions, content
  width).
- `LinesLayout` exposes exactly the 1-based surface needed:
  `get_vertical_offset_for_line_number` (`lines_layout.mbt:569`),
  `get_line_number_at_or_after_vertical_offset` (`:664`),
  `get_vertical_offset_for_whitespace_index` (`:838`),
  `get_lines_total_height` (`:493`), `change_whitespace` (`:276`).
- `normalized_view_zones` already clamps `anchor_line` into `[0, line_count]`
  (`view_layout.mbt:320-337`); only the clamp range and the `afterLineNumber`
  mapping shift by one.

### Phases

**All phases complete (2026-06-28).** Phases 2–5 were implemented together
(the data types, `ViewLayout`, the `ViewportData` seams, and the viewer
consumers are too tightly coupled to land in separately-green slices), then
validated as one change: `just check` + `moon test --target all` green, and the
hover/selection regression surfaced only by `just test-browser` was traced to
the four index sites named in the Track A landed summary.

1. **Inventory the 0-based view-line-number boundaries.** Grep every consumer of
   `LineWindow`, `ViewLayout::*_for_line`, frame `line_number`, and view-line
   hit-testing; record which are addressing (flip) vs geometry (already neutral).
   Land as a doc note in this file — no code change.

   **Inventory result (2026-06-28).** The 0-based view-line axis is larger than
   the other two tracks and spans three packages, coupled at `render.mbt:51-55`
   where the 0-based `LineWindow` feeds directly into the 0-based `FrameViewport`
   (`view_model.render_frame({ start_line: window.start, end_line: window.end })`):

   - **`view_layout` (addressing — flip):**
     - `LineWindow { start, end }` (`view_window.mbt:3`, 0-based half-open).
     - Standalone `visible_window` / `window_needs_update` (`view_window.mbt:16,45`)
       + `view_window_test.mbt` (start/end numeric assertions).
     - `ViewLayout::vertical_offset_for_line` (`:138`, `+1`),
       `line_at_vertical_offset` (`:149`, `-1`/`max(0)`),
       `relative_vertical_offset_for_line` (`:201`), `visible_window` (`:252`),
       `window_origin` (`:299`), `view_zone_viewport_data` (`:176`).
     - View zones: `ViewZone.anchor_line` (0-based) →
       `afterLineNumber = anchor_line` (`build_lines` `:34-39`),
       `normalized_view_zones` clamp `[0, line_count]` (`:320-337`).
     - `view_layout_test.mbt` (~50 numeric line/offset assertions).
   - **`view_model` (addressing — flip):** `FrameViewport { start_line, end_line }`
     (0-based, `render_frame.mbt`); `ViewModel::render_frame` clamps 0-based and
     calls `render_line(line + 1)` (`view_model.mbt:672-685`). `RenderLine.line_number`
     is **already 1-based** (so it does *not* shift); the frame JSON `viewport`
     `startLine`/`endLine` *do* shift — update `render_frame_test` snapshots and the
     `tokenized_document_test` `viewport`/`line_number` expectations.
   - **`viewer` (addressing — flip):** `render.mbt:51-55` (window→frame),
     `view.mbt:61` (`frame_window`), `view.mbt:299-301` (`window_needs_update`),
     `view_line.mbt:5` (`viewport_window` `start_line_number - 1`),
     `rendering_context.mbt:70` (`window_origin`), `content_widgets.mbt:207`
     (`relative_vertical_offset_for_line`).
   - **Geometry (already coordinate-neutral — no change):** scroll position /
     dimensions / content width on `ViewLayout`; `ViewportData.start_line_number` /
     `end_line_number` are *already* 1-based (the `from_view_model` `start_line + 1`
     / `viewport_window` `- 1` seam is the second 0↔1 translation, alongside the
     `LinesLayout` `± 1`).

   The recommended decomposition keeps `LineWindow` **1-based half-open**
   (`{ start, end }` covering 1-based lines `start..end-1`): both fields shift `+1`
   from today, loops stay `start..<end`, and `from_view_model` collapses to
   `start_line_number = window.start`. The two seams (`LinesLayout ± 1` and
   `ViewportData ∓ 1`) both vanish; the lone remaining 0↔1 conversion, if any, is
   the external/browser view-zone anchor API at the outermost boundary.
2. **Flip `ViewLayout`'s public surface to 1-based.** Change
   `vertical_offset_for_line`, `line_at_vertical_offset`,
   `relative_vertical_offset_for_line`, `visible_window`, `window_origin`, and
   the zone helpers to take/return 1-based line numbers and drop the `± 1`.
   Update the immediate callers in `view_layout` so the package stays green in
   isolation.
3. **Rebase `LineWindow` + frame line numbers.** Make the render window and the
   per-line `line_number` in the frame 1-based; update `viewer/render.mbt` /
   `view_layer.mbt` window translation and the render loop. The frame JSON line
   numbers shift by one — update the frame/render snapshots.
4. **Rebase view-line hit-testing** to 1-based line numbers (the column lookups
   are unchanged).
5. **Delete the adapter.** Remove the `± 1` translations and the zero-based
   adapter doc-comment; view zones expose Monaco's `afterLineNumber` directly
   (`normalized_view_zones` clamps into `[1, line_count + 1]`). The single 0↔1
   translation, if any external/browser API still supplies 0-based anchors, lives
   only at that outermost boundary, documented as the lone seam.

### Track A validation

- `just check` + `just test` green after each phase; `just test-browser` after
  Phases 3–5 (rendered line positions / view zones move through the layout).
- A before/after vertical-offset snapshot for a representative document (with a
  view zone) is identical up to the 1-based renumbering.

---

## Track B — Real `LanguageIdCodec` registry (retire the null-only placeholder)

### The divergence

`LanguageIdCodec` registers only the null language at id 0
(`viewer/view_model/line_tokens.mbt:26-45`, `new()` → `["null"]` at `:31-33`).
The metadata word reserves 8 bits for a language id
(`METADATA_LANGUAGEID_MASK = 0xFF`, `encoded_token_attributes.mbt:58/79/102`),
but production always packs `0`: `tag_to_metadata(language_id? = 0)`
(`token_theme.mbt:99-104`) is called from the encoder with the default
(`line_tokens_encoder.mbt`, `line_tokens_from_syntax_tokens`), and
`TokenizedDocument::build` hands every line a fresh `LanguageIdCodec::new()`
(`tokenized_document.mbt:27`, `:51`). So `LineTokens::get_language_id(i)`
(`line_tokens.mbt:310-315`) can only ever answer `"null"`.

Monaco's `LanguageIdCodec` maps numeric ids ↔ string ids via a
`languagesRegistry`, the metadata word's low 8 bits carry a **real** numeric id,
and a tokenizer can emit tokens tagged with a *different* language id — the
foundation for embedded languages (CSS-in-HTML, etc.).

### Goal

Replace the null-only codec with a real registry keyed off the `language`
package's existing string `LanguageId` (already used in services, e.g.
`LanguageId("moonbit")` in `viewer_api_scenario.mbt:124`), so each model's tokens
pack the model's numeric language id and `get_language_id(i)` decodes the real
string. This makes the metadata word's language field meaningful and lays the
single-codec foundation embedded languages need.

### Why this is bounded

- The metadata layout, the packing site (`tag_to_metadata`), and the decode site
  (`get_language_id`) already exist and already route through the 8-bit field —
  only the *values* are stuck at 0 and the codec is per-line-fresh.
- `language`'s string `LanguageId` is the natural registry key; no new identity
  type is introduced.
- Single-language-per-model (today's reality — `syntax/driver.mbt:7,20-28`
  tokenizes a whole document with one `&LineTokenizer`) needs only one numeric id
  threaded through; the per-token embedded-language path is an additive,
  explicitly-deferred extension.

### Out of scope

- Authoring an actual embedded grammar / nested `TokenizationSupport`
  (Monaco's `nestedLanguageTokenization`). This track makes the *pipeline* carry
  per-token language ids; producing real sub-language runs is a future
  tokenizer-only change.
- `TokenizationRegistry` (language → support lookup) beyond what single-language
  selection already does.

### Findings the plan relies on (verified)

- `tag_to_metadata` already accepts and packs `language_id`
  (`token_theme.mbt:99-104`); production passes the default `0`.
- `LineTokens` already stores a `LanguageIdCodec` and `get_language_id`
  already decodes through it (`line_tokens.mbt:73, 310-315`) — but each
  `LineTokens` gets an independent `LanguageIdCodec::new()` rather than a shared
  registry.
- The lexer contract is single-language: `tokenize_document_lines` takes one
  `tokenizer : &LineTokenizer` (`syntax/driver.mbt:7,20-28`); a `LineToken`
  carries no language id, so per-token languages need a contract extension
  (Phase 4 only).

### Phases

1. **Make `LanguageIdCodec` a real registry.** Add `encode_language_id(String)
   -> Int` (allocates stable ids, `null = 0`) alongside the existing
   `decode_language_id`. Seed it from the `language` package's registered
   languages (moonbit, javascript, json). Update the deviation note in
   `line_tokens.mbt:16-17`.
2. **Thread the model's language id into encoding.** `TokenizedDocument::build`
   takes the document's `LanguageId`, encodes it once via a single shared codec,
   and `line_tokens_from_syntax_tokens` / `tag_to_metadata` pack that numeric id
   instead of `0`. Every `LineTokens` for the document shares the one codec
   instance (drop the per-line `LanguageIdCodec::new()`).
3. **Verify decode round-trips.** A unit test: a model tagged `moonbit` yields
   `get_language_id(i) == "moonbit"` for every token, and the packed metadata's
   low 8 bits equal `encode_language_id("moonbit")`. The `mtk<fg>` class and
   rendered HTML are **unchanged** (language id does not affect foreground/style).
4. **(Deferred extension) Per-token language id.** Extend `LineToken` to carry an
   optional language id (default = the model's), let the encoder pack per-token
   ids, so an embedded-language tokenizer can emit sub-language runs and
   `SliceLineTokens::get_language_id` reports them. No grammar authored here —
   the pipeline becomes capable; enabling a real embedded language is future work.

### Track B validation

- `just check` + `just test` green after each phase; Phase 3 adds tests only.
- The faithful `line_tokens_reference_wbtest` / `text_to_html_tokenizer_reference_wbtest`
  stay green: rendered classes and HTML are byte-identical (the language field is
  presentation-neutral).
- `just test-browser` confirms no DOM change.

---

## Track C — Finish soft word wrap (close the remaining divergences)

### Current state (honest)

Word wrap is **already wired behind `ViewerOptions(soft_wrap=true)`** (default
off): a faithful monospace `LineBreaksComputer`
(`monospace_line_breaks_computer.mbt`, the break-class algorithm ported from
`monospaceLineBreaksComputer.ts`), `ModelLineProjection`, projected view lines
(`ViewModelLinesFromProjectedModel`), per-segment token slicing
(`view_model_lines_projected.mbt:162`, `slice_and_inflate(start, end, 0)`), and
content-width-driven wrap-column recomputation
(`viewer_options.mbt:26`, `render.mbt:151`, `input.mbt:87`). One browser scenario
exercises it end-to-end with a view zone (`viewer_api_scenario.mbt:135`).

So this track is **finishing**, not building. The remaining divergences from
Monaco are:

1. **No `wrappingIndent`.** `slice_and_inflate`'s `delta_offset` is hardcoded `0`
   (`view_model_lines_projected.mbt:162`) and `ModelLineProjectionSegment`
   (`model_line_projection_data.mbt:3-11`) has no wrapped-indent field, so every
   continuation line renders flush-left. Monaco computes `wrappedTextIndentLength`
   from a `WrappingIndent` setting (None / Same / Indent / DeepIndent) and passes
   it as `deltaStart`, indenting continuation lines under the first.
2. **No `WrappingIndent` option.** `ViewerOptions` exposes only the on/off
   `soft_wrap` (`viewer_options.mbt:4`); there is no indent mode.
3. **Thin conformance coverage.** Wrap is smoke-tested by one scenario; there is
   no faithful reference test against the pinned `monospaceLineBreaksComputer`
   outputs like the other `*_reference_wbtest`s.

### Goal

Bring wrap to Monaco fidelity: support `wrappingIndent` (the visible gap today),
expose it as an option, and pin the break/segment computation with a faithful
conformance test — without changing the already-faithful break algorithm.

### Why this is bounded

- The break algorithm, projection, projected view lines, and per-segment slicing
  already exist and are correct for `WrappingIndent.None`. Only the **indent**
  dimension is missing, and `slice_and_inflate` already takes the `delta_offset`
  that carries it — the value is just always `0`.
- The layout already treats each projected view line as one fixed-height row
  (`view_model.line_count()` is the projected count, `render.mbt:148`), which is
  correct for monospace wrap; no layout change is required beyond Track A's
  coordinate consistency.

### Out of scope

- Variable-height / proportional-font wrap (the viewer is monospace).
- Enabling wrap by default — it stays an opt-in option.

### Findings the plan relies on (verified)

- `slice_and_inflate(start_offset, end_offset, delta_offset)` already inflates
  token offsets by `delta_offset` (`line_tokens.mbt:192-199`, `SliceLineTokens`
  `get_end_offset` adds it at `:458-466`) — the wrapping-indent plumbing is
  present and unused.
- `ModelLineProjectionSegment` carries `start_visible_column` and
  `continues_with_wrapped_line` (`model_line_projection_data.mbt:9-10`) but no
  wrapped-indent length — the one field to add.
- Content width already clamps to viewport when wrapped via `max_view_line_length`
  (`render.mbt:151-155`), so no horizontal scroll appears for wrapped lines.

### Phases

1. **Add `wrappingIndent` to the projection.** Compute a per-model-line
   `wrapped_text_indent_length` (leading-whitespace visible columns, bounded by
   the wrap column, per the chosen mode), store it on
   `ModelLineProjectionSegment`, and in `render_projected_line` prepend the indent
   as leading whitespace and pass it as `slice_and_inflate`'s `delta_offset` for
   continuation segments (the first segment keeps `delta = 0`). Mirror Monaco's
   `createLineBreaks` + `_getViewLineData`.
2. **Expose the option.** Add `wrapping_indent : WrappingIndent` to
   `ViewerOptions` (default `Same`, Monaco's default) and plumb it through
   `view_model_options` → `LineBreaksComputer`.
3. **Faithful conformance test.** Add a `*_reference_wbtest` pinning
   `LineBreaksComputer` segment boundaries **and** wrapped-indent lengths against
   `monospaceLineBreaksComputer.ts` for representative lines (deep/shallow indent,
   ideographic break, tab indent), in the style of the existing token reference
   tests.
4. **Browser gate.** Extend the existing `soft_wrap=true` scenario to assert the
   continuation line's indent (DOM left offset), proving the indent renders.

### Track C validation

- `just check` + `just test` (and `moon test --target js,native` for the
  multi-target packages) green after each phase; Phase 3 adds tests only.
- `just test-browser` is the gate (Phases 1 and 4 change wrapped DOM): a wrapped
  representative file's emitted HTML matches Monaco's up to class-name remap, and
  continuation lines carry the expected indent.

---

## Combined Exit Criteria

- **Track A:** `ViewLayout` calls `LinesLayout` in its native 1-based space with
  no `± 1` translation; the zero-based-adapter doc-comment is gone; the
  view-line-number axis is 1-based through `LineWindow`, the frame, and
  hit-testing. Any residual 0↔1 conversion exists only at the outermost
  external API boundary and is documented as the lone seam.
- **Track B:** `LanguageIdCodec` is a real string↔numeric registry shared per
  document; production tokens pack the model's numeric language id;
  `get_language_id(i)` decodes the real language. Rendered HTML is unchanged.
  Per-token (embedded) language ids are plumbed but no embedded grammar is
  shipped.
- **Track C:** soft wrap supports `wrappingIndent` (continuation lines indent),
  the mode is a `ViewerOptions` setting, and a faithful conformance test pins the
  break + indent computation against the pinned `monospaceLineBreaksComputer`.
- `RangePriorityQueueImpl` / background retokenization remains explicitly
  deferred and conformance-only (out of scope by request).
- After all three land, the only Finding **D** item still open is the async
  retokenization queue; the layout, language-codec, and word-wrap divergences are
  closed.
