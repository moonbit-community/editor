# Std Dedup & Monaco-Divergence Review — Findings + Fix Plan

Status: done (Step 5a deferred) — Date: 2026-06-26. Follows the close of
`monaco-test-conformance-port.md`.

Implementation: Steps 1–4 and 6 landed, plus Step 5b/5c. Step 5a (reference-shell
JSON accessor dedup) is deferred — the two copies have already diverged
(`lsp_client`'s `json_int_field` routes through a reusable `json_int_value` that
`protocol.mbt` lacks, and `lsp_client` has no `json_bool_field`), so merging
means reconciling behavior in non-product code for marginal benefit. `clamp_int`
(base/common) and `clamp_double` (scrollable) are retained with comments: both
deliberately tolerate inverted bounds where std `clamp`'s `guard min <= max`
would panic. All steps verified behavior-preserving (js 416 / native 426 tests
unchanged; 45 browser tests green).

Oracle: checked-in `vscode` submodule (2026-06-02, `heads/main`).
Std pin: `moonbitlang/core` at the toolchain in use (`moon 0.1.20260618`).

A post-conformance sweep of the product packages (`base/common`, `viewer/*`,
`syntax/*`, `language`) plus `internal/shell`, focused on two axes the
conformance plan did not police:

1. **Divergence** from Monaco's logic / structure / source layout.
2. **Code smells** — helpers duplicated across files, and helpers that
   reinvent `moonbitlang/core`.

Findings are tagged **Reinvent** (a std method already exists), **Dup** (same
logic copied across files that could share one definition), or **Divergence**
(structural drift from Monaco). Tags are independent of severity; the fix plan
at the bottom orders by leverage × safety.

The conformance ports themselves are faithful and their *documented* deviations
are honest — these findings are about helper sprawl that accumulated *around*
the ports, plus one structural observation about what the suite does and does
not exercise.

## Findings

### A. Std reinvention — `moonbitlang/core` already has these — **Reinvent**

`builtin/int.mbt` / `builtin/double.mbt` expose `Int::min`, `Int::max`,
`Int::clamp(min~, max~)`, `Double::abs`, `Double::clamp(min~, max~)`, and
`Int::is_leading_surrogate` / `Int::is_trailing_surrogate`. The codebase
reimplements all of them, several many times over:

| Helper | Copies / uses | Locations (def) | Std replacement |
|---|---|---|---|
| `min_int` / `max_int` | **5 defs each**, ~16 files use them | `base/common/monaco_range.mbt:400/409`, `viewer/int_math.mbt:5/14`, `viewer/inline_decorations/inline_decorations.mbt:588/597`, `viewer/view_layout/lines_layout.mbt:1010/1019`, `viewer/view_model/render_frame.mbt:325/334` | `a.min(b)` / `a.max(b)` |
| `clamp_int` | 2 | `base/common/text.mbt:335` (pub), `viewer/inline_decorations/inline_decorations.mbt:606` | `v.clamp(min~, max~)` |
| `clamp_double` | 2 | `viewer/view_layout/scrollable.mbt:164`, `viewer/controller/mouse_handler.mbt:390` | `v.clamp(min~, max~)` |
| `abs_double` | 2 (byte-identical) | `viewer/view_overlays.mbt:473`, `viewer/controller/mouse_handler.mbt:234` | `v.abs()` |

`viewer/int_math.mbt`'s own comment justifies the duplication ("the common layer
is acyclic and these are trivial") — but that only held *before* the std method
was reachable. `Int::min`/`max`/`clamp` need no import and break no acyclicity.

**Caution before a blind clamp sweep:** std `Int::clamp` / `Double::clamp` have
`guard min <= max` — they **panic** on inverted bounds. The local
`clamp_double` (`scrollable.mbt:164`) instead returns `low` when `high < low`.
Confirm no call site can pass inverted bounds before swapping, or the swap turns
a silent clamp into an abort. `min_int`/`max_int`/`abs_double` carry no such
hazard.

### B. Centralized helpers that were never adopted — **Dup** / **Divergence**

`base/common/strings.mbt` was added (conformance Phase 3/4) as the faithful home
for Monaco's `strings.ts` helpers — but the pre-existing private copies were
never retired:

- `is_high_surrogate` — `base/common/strings.mbt:7` (pub) **+**
  `viewer/common/cursor_columns.mbt:18`,
  `viewer/view_line_renderer/line_decorations.mbt:245`, `syntax/plain.mbt:125`
- `is_low_surrogate` — pub **+** `cursor_columns.mbt:23`, `syntax/plain.mbt:130`
- `is_full_width_character` — pub **+** `cursor_columns.mbt:54`,
  `viewer/view_line_renderer/render_line_renderer.mbt:1026`
- `contains_rtl` — `base/common/strings.mbt:23` (pub) **+**
  `viewer/view_model/view_line_data.mbt:129` (**byte-identical**)

`view_line_renderer`, `view_model`, and `syntax` already import `@base_common`,
so those copies delete-and-delegate today. `viewer/common` (cursor_columns) is
the lone package not importing `base/common`; adding the import is cheap and
creates no cycle (base/common imports nothing from viewer). This is also a
*faithfulness* win — Monaco's `cursorColumns.ts` and `renderLine` import these
from `strings.ts` rather than re-deriving them, so delegating matches the source
structure. (`base/common`'s public `is_high/low_surrogate` may itself wrap std
`Int::is_leading/trailing_surrogate`, keeping the faithful Monaco names.)

Related near-dup in the same file: `render_line_renderer.mbt` carries local
`first_non_whitespace_index_of` / `last_non_whitespace_index_of` (:1034/:1045)
and `contains_rtl_in` (:1058), overlapping `base/common/strings.mbt`'s
`first/last_non_whitespace_index` and `contains_rtl`. They differ only by a
`StringView` + explicit-`len` / start-end signature; Monaco's `renderLine` calls
the shared `strings.ts` versions. Unifying on one signature removes the
near-dupes (lower priority — touches the faithful renderer).

### C. Other identical duplications — **Dup**

- **`compute_indent_level`** — identical in `viewer/model/utils.mbt:9` and
  `viewer/folding/indent_range_provider.mbt:54`. `viewer/folding` already imports
  `viewer/model`; making the model copy `pub` lets folding delegate (mirrors
  Monaco, where both consume `model/utils.ts` `computeIndentLevel`).
  `guides_text_model_part.mbt:55` *already* delegates to the model copy — folding
  is the lone holdout.
- **`build_line_starts`** — identical in `viewer/model/text_snapshot.mbt:391` and
  `internal/shell/workspace/document.mbt:284`. These straddle the product/shell
  boundary so sharing is optional, but note **both split only on `\n`** — they
  share the documented lonely-CR EOL limitation and must change together if that
  is ever fixed.
- **JSON field accessors** — `json_field` / `json_string_field` /
  `json_int_field` / `json_bool_field` / `parse_json` duplicated between
  `internal/shell/remote_protocol/protocol.mbt:1635+` and
  `internal/shell/server/lsp_client.mbt`. Both reference-shell; a shared json-util
  removes ~5 copied helpers per file. Lower priority (not product surface).
- **Lexer scaffolding** — `is_capitalized` is byte-identical between
  `syntax/lang_javascript/lexer.mbt:241` and `syntax/lang_moonbit/lexer.mbt:241`;
  `classify_word` / `normal_step` / `push_token` / `comment_step` share shape.
  The bulk of each lexer is genuinely language-specific (~238 differing lines), so
  only the truly-identical helper (`is_capitalized`) is worth lifting into
  `syntax`. Lowest priority.

### D. Conformance-only ports vs production systems — **Divergence**

The largest divergence is intentional and documented, but worth stating as a
maintenance risk: several faithful ports are **conformance-only and not consumed
by production** (verified by reference search):

- `LineTokens` / `SliceLineTokens` / `IViewLineTokens`,
  `TokenMetadata` / `MetadataConsts` (`encoded_token_attributes.mbt`), and
  `RangePriorityQueueImpl` (`text_model_tokens.mbt`) are referenced **only** by
  their own reference tests / each other. Production rendering uses the parallel
  `@syntax.Token` pipeline.
- `LinesLayout` is the faithful port, but `ViewLayout` consumes only ~5 of its
  methods through a zero-based adapter (already tracked as a deferred follow-up
  in the conformance plan and the `ViewLayout` migration note).

So the suite proves the *ported* token/layout code matches Monaco but does **not**
exercise the simplified systems production ships. That is a real gap between
"green against Monaco" and "production matches Monaco" — acceptable as a staging
strategy, but each parallel pair (faithful + simplified) can silently drift.
**No code change proposed here** beyond a one-line README cross-link in each
owning package pointing from the production type to its conformance-only twin, so
the drift risk is visible at the call site. Full reconciliation stays out of
scope (it is the deferred `ViewLayout` migration + a future token-model port).

> **Update — token half resolved by unification.** The
> `docs/exec-plans/production-line-tokens-pipeline.md` work made production
> rendering consume `LineTokens` / `TokenMetadata` / `MetadataConsts` directly
> (`TokenizedDocument` now stores one faithful `LineTokens` per line, encoded
> from the MoonBit lexers). Those types are no longer conformance-only, so this
> half of Finding D is closed by *unification* rather than the cross-link below.
> `RangePriorityQueueImpl` (background retokenization) and the `LinesLayout` /
> `ViewLayout` half remain conformance-only and deferred.

## Fix Plan

Ordered by leverage × safety. Each step is behavior-preserving and gated by
`just check` + `just test` (+ `just test-browser` where a `viewer/*` js-only
package changes).

### Step 1 — Retire `min`/`max`/`abs` reinvention (highest leverage, zero risk)

- Replace every `min_int(a, b)` / `max_int(a, b)` call with `a.min(b)` /
  `a.max(b)`; delete all 5 definition pairs and remove `viewer/int_math.mbt`.
- Replace `abs_double(x)` with `x.abs()`; delete both definitions.
- Regenerate any affected `pkg.generated.mbti` (none of these are `pub` except
  none — all private — so the `.mbti` surface is unchanged; confirm).
- No bounds hazard. Verify `--target js,native` test counts are unchanged.

### Step 2 — Retire `clamp` reinvention (low risk, one guard to check)

- Audit call sites of `clamp_int` (`text.mbt:335`,
  `inline_decorations.mbt:606`) and `clamp_double` (`scrollable.mbt:164`,
  `mouse_handler.mbt:390`) for any path that can pass `low > high`. The
  `scrollable.mbt` copy explicitly tolerates `high < low`; trace its callers
  (scroll dimensions) to prove `low <= high` or keep a normalizing wrapper.
- Where bounds are provably ordered, replace with `v.clamp(min~, max~)` and
  delete the local helper. `clamp_int` in `base/common/text.mbt` is `pub` —
  removing it changes the `.mbti`; regenerate and check no external caller.

### Step 3 — Delegate string helpers to `base/common/strings.mbt`

- Delete `is_high_surrogate` / `is_low_surrogate` / `is_full_width_character` /
  `contains_rtl` copies in `view_line_renderer`, `view_model`, `syntax`, and
  `viewer/common`; call `@base_common.*` instead.
- Add `"moonbit-community/editor/base/common" @base_common` to
  `viewer/common/moon.pkg` (cursor_columns is the only consumer lacking it). No
  cycle: base/common has no viewer deps.
- Optional: rewrite `base/common`'s `is_high/low_surrogate` bodies as thin
  wrappers over std `Int::is_leading/trailing_surrogate`, keeping the
  Monaco-faithful names as the single public definition.
- Defer the `render_line_renderer.mbt` `*_index_of` / `contains_rtl_in`
  signature-unification (Finding B tail) unless touching that file anyway.

### Step 4 — `pub` the model `compute_indent_level`; delete folding's copy

- Make `viewer/model/utils.mbt` `compute_indent_level` `pub`; regenerate the
  model `.mbti`.
- Replace `viewer/folding/indent_range_provider.mbt:54`'s copy with
  `@model.compute_indent_level`. (folding already imports `viewer/model`.)

### Step 5 — Reference-shell + lexer dedup (lower priority, optional)

- Lift the JSON field accessors into a shared `internal/shell` json-util used by
  both `remote_protocol/protocol.mbt` and `server/lsp_client.mbt`.
- Lift the byte-identical `is_capitalized` into `syntax` shared by both lexers.
- Leave `build_line_starts` duplicated unless the product/shell boundary is
  being reworked — but add a comment in each noting the shared LF-only / lonely-CR
  limitation so they stay in lockstep.

### Step 6 — README cross-links for conformance-only ports (docs only)

- In `viewer/view_model` and `viewer/view_layout` READMEs, add a one-line pointer
  from each conformance-only faithful type to the production system it shadows,
  naming the drift risk. No code change.
- Superseded for the token cluster: `LineTokens` / `TokenMetadata` /
  `MetadataConsts` are now the production token model (see the Finding D update
  above), so the `viewer/view_model` README documents them as the live path, not
  a twin. The cross-link survives only for `RangePriorityQueueImpl` and the
  `LinesLayout` / `ViewLayout` surface.

## Validation

- `just check` + `just test` (and `moon test --target js,native` where a package
  is multi-target) stay green after each step; **test counts must not change**
  (all steps are behavior-preserving).
- `just test-browser` after Step 3 (touches `view_line_renderer` / `viewer`
  rendering) and Step 2 (touches `scrollable` / `mouse_handler`).
- `moon check --warn-list "+1+2+3+6+7+29+49"` shows no new unused-symbol /
  unused-package warnings after each deletion.

## Exit Criteria

- No remaining `min_int` / `max_int` / `abs_double` definitions; `viewer/int_math.mbt`
  removed; std methods used at all call sites.
- `clamp_int` / `clamp_double` either removed in favor of `v.clamp(...)` or
  retained only where inverted-bounds tolerance is a deliberate, commented
  requirement.
- One public definition each of `is_high_surrogate` / `is_low_surrogate` /
  `is_full_width_character` / `contains_rtl` (in `base/common/strings.mbt`); no
  package-local copies.
- One `compute_indent_level` definition consumed by both `viewer/model` and
  `viewer/folding`.
- (Optional Steps 5–6 closed or explicitly deferred with a reason.)
