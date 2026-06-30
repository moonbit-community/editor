# Monaco `renderWhitespace` / `renderControlCharacters` Option Plumbing 1:1 Port

Status: landed (Stage 1 + Stage 2) — Date: 2026-06-30. Oracle commit: `294fb350837dbaee37b949533fead4df4e0e8971`.

Follows `_PORT_PLAYBOOK.md`. The *rendering* of whitespace glyphs and control-
character placeholders is already ported in
`viewer/view_line_renderer/render_line_renderer.mbt` (the `renderViewLine`
consumer — `apply_render_whitespace`, `extract_control_characters`, all five
`RenderWhitespace` modes, the `[U+XXXX]` placeholder path). It is **dead**: both
viewer render call sites construct `RenderLineInput` with the `from_view_line`
defaults `render_whitespace = None` / `render_control_characters = false` and
never source them from `ViewerOptions`. No embedder can turn either on. This plan
ports the **option-derivation slice** Monaco's `ViewLine` runs between editor
options and `RenderLineInput`, and threads it through the viewer's two render
paths.

## Stage split (why two stages)

The five `render_whitespace` modes fall into two classes by data dependency:

- **Content-only** — `None`, `Boundary`, `Trailing`, `All` (+ `render_control_
  characters`): a pure function of the line's own content (and, for `Trailing`,
  `continues_with_wrapped_line`). No external state, no per-line selection — a
  clean passthrough of the option value. → **Stage 1.**
- **Selection-dependent** — `Selection` (Monaco's *default*): needs per-line
  selected-column ranges, which `ViewportData` does not carry today. Requires
  threading the selection into the line-render path, a real port of the per-line
  clip/offset derivation, and re-render-on-selection-change coupling.
  → **Stage 2.**

Stage 1 is independently shippable and immediately fixes "no embedder can enable
whitespace rendering" for four of five modes plus control characters. Stage 2
lands `Selection` and flips the default to match Monaco. The default stays `None`
through Stage 1 so no stage advertises a mode that renders nothing (see Defaults).

## Scope (Phase 0)

Source unit — the `RenderLineInput`-construction slice of
`vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts#renderLine`
(lines 116–173: the `renderWhitespace` gate, the `selectionsOnLine` derivation,
and the two fields fed into the constructor) **plus** the governing `EditorOption`
registrations in `vscode/src/vs/editor/common/config/editorOptions.ts`:
`renderWhitespace` (`:6567`), `renderControlCharacters` (`:6534`), and the
`experimentalWhitespaceRendering` gate (`:6278`) referenced at `viewLine.ts:119`.

Out of scope (named siblings, explicitly **not** ported here):

- **The inline renderer itself** — `viewLineRenderer.ts` `_applyRenderWhitespace`
  / control-char handling. Already ported in `render_line_renderer.mbt`; this plan
  only *feeds* it. **Verify-only** in each exit gate (confirm the relevant modes
  are reachable once the input is non-default), not re-ported.
- **The SVG whitespace overlay** — `whitespaceRendering/` `WhitespaceOverlay`
  (`experimentalWhitespaceRendering: 'svg'`, Monaco's default path). The viewer
  has no SVG overlay; it renders whitespace inline. See Deviations.
- **High-contrast `inline-selected-text` injection** (`viewLine.ts:137-139`). The
  viewer has no high-contrast theme mode. See Deviations.
- **Font measurement of `middotWidth` / `wsmiddotWidth`** (FontInfo). See
  Deviations / Follow-ups.

## Inventory (Phase 1)  <!-- reviewed before port code -->

### Source members (the denominator)

| # | Source member (file:line) | What it is | Stage |
|---|---|---|---|
| 1 | `editorOptions.ts:6567` `renderWhitespace: register(...)` | `EditorStringEnumOption`, default `'selection'`, values `['none','boundary','selection','trailing','all']` | 1 (enum) / 2 (default flip) |
| 2 | `editorOptions.ts:6534` `renderControlCharacters: register(...)` | `EditorBooleanOption`, default `true` | 1 |
| 3 | `editorOptions.ts:6278` `experimentalWhitespaceRendering: register(...)` | `EditorStringEnumOption`, default `'svg'` | N-A (deviation) |
| 4 | `viewLine.ts:119` `experimental === 'off' ? renderWhitespace : 'none'` | the inline-vs-overlay gate | DEVIATION |
| 5 | `viewLine.ts:123` `let selectionsOnLine = null` | per-line selection offsets, lazy | 2 |
| 6 | `viewLine.ts:124` `if (isHighContrast \|\| ws === 'selection')` | gather condition | 2 |
| 7 | `viewLine.ts:126-128` intersect guard (`end<line \|\| start>line → continue`) | skip non-touching selections | 2 |
| 8 | `viewLine.ts:133-134` clamp to `min/maxColumn` on non-anchor lines | clip multi-line selection to this line | 2 |
| 9 | `viewLine.ts:136` `if (startColumn < endColumn)` | drop empty per-line range | 2 |
| 10 | `viewLine.ts:137-139` high-contrast `inline-selected-text` push | OUT | N-A |
| 11 | `viewLine.ts:140-146` push `new OffsetRange(startColumn-1, endColumn-1)` | the offsets the renderer consumes | 2 |
| 12 | `viewLine.ts:167` `renderWhitespace` → `RenderLineInput` arg 16 | thread gated value | 1 |
| 13 | `viewLine.ts:168` `options.renderControlCharacters` → arg 17 | thread the bool | 1 |
| 14 | `viewLine.ts:170` `selectionsOnLine` → arg 19 | thread per-line ranges | 2 |
| 15 | `viewLine.ts:95` force-invalidate when `input.renderWhitespace === Selection` | re-render line on selection change | 2 |

Member count (denominator): **15**. Stage 1: rows 1(enum),2,12,13. Stage 2: rows
1(default),5–9,11,14,15. N-A: 3 (`experimental`), 10 (high-contrast); row 4 is a
documented deviation.

### MoonBit plumbing surface (the seam)

Not Monaco members — the viewer wiring each ported value must traverse.

**Stage 1 (passthrough):**
- `ViewerOptions` (`viewer/viewer_options.mbt:3`) — add `render_whitespace`,
  `render_control_characters` + ctor defaults + `Eq/Debug`.
- `ViewRenderInput` (`viewer/rendering_context.mbt:3`) — carry both.
- `Viewer::render` (`viewer/view.mbt:235-252`) — source both from `self.options`.
- `ViewRenderSnapshot` / `RenderingContext` — carry through alongside `space_width`.
- `ViewLines.prepare_render` / `prepared` record / `render_text`
  (`viewer/view_layer.mbt:115-208`) — carry both into the per-line loop.
- `render_line_input_for_viewport` (`viewer/view_line.mbt:11`) — accept + pass both.
- `render_line_input_from_render_line` (`viewer/view_model/view_line_data.mbt:28`)
  + `common/line_html.mbt:15` (headless/snapshot path) — accept + pass both.

**Stage 2 (selection):**
- Thread `selection_view_range : ViewRange?` — already on `ViewRenderInput`
  (`rendering_context.mbt`, set at `view.mbt:241`, consumed by the overlay at
  `view_overlays.mbt:62`) — down into `render_line_input_for_viewport`, which
  today receives only `(viewport, index, space_width)`.
- Port the per-line clip/offset derivation (`viewLine.ts:126-146`) at that site.
  The overlay's `collect_line_selection_ranges` (`view_overlays.mbt:193`) is the
  same *shape* but emits a `ViewRange` for pixel measurement, not column
  `OffsetRange`s — parallel logic, reusable in structure, not in output type.
- Re-render coupling: the input now depends on selection; the existing
  `previous != input` check (`view_layer.mbt:190`) re-renders a changed line, but
  confirm a selection change actually changes the input for affected lines
  (Monaco's explicit `viewLine.ts:95` invalidation).

### Behavior-switching branches → test cases

- **Stage 1:** `render_whitespace ∈ {None, Boundary, Trailing, All}` (renderer
  branches at `render_line_renderer.mbt:185-191`); `render_control_characters ∈
  {true, false}` × `is_basic_ascii ∈ {true, false}` (gate at `:182`); `Trailing ×
  continues_with_wrapped_line ∈ {true,false}` (`:191`).
- **Stage 2:** `Selection` × {no selection on line, partial-line selection,
  multi-line selection clipped to `min/maxColumn`, empty per-line range dropped};
  selection-change re-render.

## Parity ledger — Stage 1 (Phase 2)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `renderWhitespace` enum (`editorOptions.ts:6567`) | 5 values | `RenderWhitespace` (exists) + `ViewerOptions.render_whitespace`, default `None` (Stage 1) | PASS |
| `renderControlCharacters` (`editorOptions.ts:6534`) | bool default `true` | `ViewerOptions.render_control_characters` default `true` | PASS |
| gate `viewLine.ts:119` | inline = `'off'` branch | viewer hardwires inline; passes `render_whitespace` straight through | DEVIATION |
| arg `renderWhitespace` `:167` | → `RenderLineInput` | `render_whitespace=` on both `from_view_line` sites | PASS |
| arg `renderControlCharacters` `:168` | → `RenderLineInput` | `render_control_characters=` on both sites | PASS |

Stage-1 reconciliation: 5 rows (4 ported, 1 deviation). `Selection` mode is
present in the enum but **inert** until Stage 2 (empty `selections_on_line` ⇒ the
renderer's `Selection` branch at `:188-191` produces nothing) — that inertness is
asserted by a Stage-1 test so the no-op is intentional, not a silent gap.

## Parity ledger — Stage 2 (Phase 2)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| default flip (`editorOptions.ts:6569`) | `'selection'` | `ViewerOptions.render_whitespace` default → `Selection` | PASS |
| `selectionsOnLine` decl `:123` | lazy `null` | local `Array[OffsetRange]` in `selections_on_line_for` (`view_line.mbt`) | PASS |
| gather-condition `:124` | `isHighContrast \|\| ws==='selection'` | `render_whitespace == Selection` (high-contrast dropped) | PASS |
| intersect guard `:126-128` | `end<line \|\| start>line → continue` | per-line filter over the threaded `selection_view_range` | PASS |
| column clamp `:133-134` | non-anchor → `min/maxColumn` | `line_data.min_column` / `line_data.max_column` on non-anchor lines | PASS |
| `startColumn < endColumn` `:136` | drop empty | `if start_column < end_column` | PASS |
| selection push `:140-146` | `OffsetRange(startColumn-1, endColumn-1)` | `OffsetRange(start_column-1, end_column-1)` | PASS |
| arg `selectionsOnLine` `:170` | → `RenderLineInput` | `selections_on_line=` on the viewport site | PASS |
| invalidate `:95` | force re-render when `ws===Selection` | `ViewLines.on_view_event(ViewCursorStateChanged)` keyed on last-rendered mode + `render_text` selection-invalidation gate; `previous != input` (`view_layer.mbt`) limits the rewrites | PASS |
| high-contrast push `:137-139` | `inline-selected-text` | — | N-A (no high-contrast) |

Stage-2 reconciliation: 10 rows (9 ported, 1 N-A).

Whole-plan reconciliation: rows = 15, members = 15. done(target) = 12, N-A = 3,
deviation = 1 (the `:119` gate). (Row 1 counts once though it spans both stages.)

## Deviations (Phase 3)  <!-- every non-source-cited line, justified -->

1. **Inline path always active (the `:119` gate hardwired to `'off'`).** Monaco
   defaults `experimentalWhitespaceRendering='svg'`, which sets
   `RenderLineInput.renderWhitespace='none'` and renders whitespace via the
   separate `WhitespaceOverlay` SVG. The viewer has **no** SVG overlay; its only
   whitespace renderer is the inline `renderViewLine` port. To reproduce default
   Monaco's *visible* behavior the viewer behaves as if
   `experimentalWhitespaceRendering: 'off'`, passing `ViewerOptions
   .render_whitespace` straight into `RenderLineInput`. Genuine host/seam
   difference (missing overlay), not a math change. (Stage 1.)
2. **No high-contrast `inline-selected-text` injection** (`:137-139`). No
   high-contrast theme mode, so `isHighContrast` is always false and the gather
   condition reduces to `render_whitespace == Selection`. N-A. (Stage 2.)
3. **`middotWidth` / `wsmiddotWidth` not font-measured.** Both stay at the
   `from_view_line` default (`space_width`), so the glyph-choice branch
   (`render_line_renderer.mbt:236-241`) deterministically picks `ch_middot`
   (`·`, U+00B7), never the word-separator middot (U+2E31). Faithful glyph choice
   needs FontInfo measurement the viewer doesn't do. Follow-up, non-blocking;
   dots still render. (Affects Stage 1 once whitespace is visible.)

Any implementation line lacking a `viewLine.ts` / `render_line_renderer.mbt`
citation must be added here or removed.

## Defaults decision

- **Stage 1 ships `render_whitespace = None`, `render_control_characters =
  true`.** `None` keeps the default output unchanged while Stage 2 is pending, so
  no stage advertises a mode (`Selection`) that renders nothing. `render_control_
  characters = true` matches Monaco and is safe — it only changes output when a
  line actually contains control characters.
- **Stage 2 flips `render_whitespace` to `Selection`** (Monaco's default).
  Combined with Deviation 1 the viewer's default visible behavior then matches a
  default Monaco editor (whitespace dots under selection). If the readonly viewer
  should stay quieter than Monaco, leave the default at `None` — a one-line
  choice, flagged because it changes default visible output.

## Test matrix (Phase 4)

**Stage 1**

- **Headless white-box** (new `*_wbtest.mbt`): assert the `RenderLineInput` from
  `render_line_input_for_viewport` and `render_line_input_from_render_line`
  carries the values from `ViewerOptions` — one case per content-only mode, plus
  `render_control_characters` on a non-ASCII line. One case asserts `Selection`
  with no threaded selection yields empty `selections_on_line` (inert no-op).
- **Renderer reachability**: extend
  `view_line_renderer/monaco_render_line_reference_test.mbt` so `Boundary` /
  `Trailing` / `All` and a control character each produce the expected `mtkw` /
  `[U+…]` spans — proves the consumer is live once fed, per branch.
- **Browser**: one DOM spec turning `render_whitespace = All` +
  `render_control_characters = true` on via `ViewerOptions`, asserting `.mtkw`
  nodes and a control-char placeholder appear. Cover `Trailing ×
  continues_with_wrapped_line` (soft-wrap on) headlessly.

**Stage 2**

- **Headless white-box**: the four `Selection` shapes (none / partial /
  multi-line-clipped / empty-drop) produce the expected `selections_on_line`
  offsets (the `-1` conversion, the `min/maxColumn` clamp, the empty-drop).
- **Browser**: `Selection`-mode case asserting dots appear only under a
  programmatic selection, and that changing the selection re-renders the affected
  lines (the `:95` / `view_layer.mbt:190` coupling).

Wire any new browser page into `scripts/build-web.mbtx` and the `static_route`
allowlist (`internal/shell/server_host_native/native_host.mbt`) — new pages 404
otherwise (see [[reveal-api-port-status]]). Run `moon test --target all` across
the matrix, not one config (the `Trailing × wrapped` and `Selection × multi-line`
cells are the likeliest to be skipped).

## Exit gate (Phase 5)

**Stage 1** — DONE (2026-06-30).

- [x] inventory reconciled (Stage-1 rows): done/deferred/N-A = 4/0/0 (+1 deviation)
- [x] both `from_view_line` sites pass `render_whitespace` / `render_control_
      characters` from `ViewerOptions`; diff-reviewed vs `viewLine.ts:119,167-168`
- [x] matrix covered (4 content modes × control-char × wrap), harness across configs
- [x] `Selection`-is-inert test present (intentional no-op, not a silent gap)
- [x] **verify-only**: re-read `render_line_renderer.mbt:182-192,415-472,475-655,
      745-924`; confirmed Boundary/Trailing/All + control-char placeholder
      reachable (corroborated by the green `view_line_renderer` conformance suite:
      `ws-4-leading`/`ws-all-middle`/`ws-trail-*`/`ws-sel-*`, `issue-116939`
      `[U+202E]`, `issue-119416` `␡`/`␀`).
- [x] deviations 1 & 3 documented; `just check` / `moon test --target all` green

Stage-1 closeout (self-audit, 2026-06-30):

- **Seam threaded** option value `ViewerOptions.{render_whitespace,
  render_control_characters}` → `flush_render` (`view.mbt`) → `ViewRenderInput`
  (`rendering_context.mbt`) → `ViewLines.prepare_render`/`ViewLinesPrepared`/
  `render_text` (`view_layer.mbt`, both recycler call sites) →
  `render_line_input_for_viewport` (`view_line.mbt`) → `from_view_line`. Headless
  path also wired: `render_line_input_from_render_line`
  (`view_model/view_line_data.mbt`) + `render_line_html` (`common/line_html.mbt`).
- **Deviation from the seam table:** `ViewRenderSnapshot`/`RenderingContext` were
  *not* given the two fields. The line layer sources them from `context.input`
  (the `ViewRenderInput`), not the snapshot; the snapshot's `space_width` exists
  only for the `font_changed` view-event diff (`view_events.mbt:91`), which has no
  analog here because any `set_options` change already bumps `content_generation`
  (`render.mbt:128`) and forces a full `ViewLinesChanged` re-render. Carrying the
  fields in the snapshot would be write-only dead state, so they were omitted —
  the value still traverses to `render_text` via the `ViewRenderInput`.
- **Defaults shipped:** `render_whitespace = None`, `render_control_characters =
  true` (Defaults decision).
- **Tests added:** `viewer/common/render_whitespace_options_test.mbt` (public
  helper passthrough: 4 content modes + control-char on a non-ASCII line +
  Selection-inert), `viewer/render_whitespace_options_wbtest.mbt` (private
  `render_line_input_for_viewport` sourced from `ViewerOptions`: defaults, 4
  modes, control-char, Selection-inert), `viewer/view_line_renderer/
  trailing_whitespace_wrap_test.mbt` (`Trailing × continues_with_wrapped_line`
  gate), `tests/browser/component/whitespace.spec.js` + the
  `tests/browser/moonbit/whitespace` scenario (DOM spec: `.mtkw` glyph spans and
  the `[U+202E]` placeholder appear with `render_whitespace=All` +
  `render_control_characters=true`). Renderer reachability itself was *verify-
  only* (already covered by the conformance suite), not re-ported.
- **Adjacent fix:** the `read_api` browser page was missing from the
  `native_host.mbt` `static_route` allowlist (pre-existing — it 404'd since the
  read-API browser test landed; same class as [[reveal-api-port-status]]'s "new
  pages 404 otherwise"). Added its three routes alongside the new `whitespace`
  ones; the full Playwright suite (43 specs) is green.

**Stage 2** — DONE (2026-06-30).

- [x] inventory reconciled (Stage-2 rows): done/deferred/N-A = 9/0/1
- [x] `selectionsOnLine` derivation diff-reviewed vs `viewLine.ts:122-149`
      (gather condition, intersect guard, column clamp, `-1` conversion, empty-drop)
- [x] selection-change re-render proven (the `:94-100` / `view_layer.mbt` coupling):
      `whitespace_selection.spec.js` drags a selection, sees dots appear, then
      moves it and sees line 1 dots removed + line 2 dots added.
- [x] matrix covered (4 `Selection` shapes), default flipped to `Selection`
- [x] deviation 2 documented; closing self-audit pasted; `moon test --target all` green

Stage-2 closeout (self-audit, 2026-06-30):

- **Derivation ported** as `selections_on_line_for` (`view_line.mbt`), a 1:1 of
  `viewLine.ts:122-149`: gather only when `render_whitespace == Selection`
  (high-contrast dropped — Deviation 2), intersect guard, `min_column`/
  `max_column` clamp on non-anchor lines, `start < end` empty-drop, and the
  `OffsetRange(start-1, end-1)` zero-based push. Fed via `selections_on_line=` on
  the viewport `from_view_line` site.
- **Selection threaded** `ViewRenderInput.selection_view_range` (already set at
  `view.mbt`, consumed by the overlay) → `ViewLines.prepare_render`/
  `ViewLinesPrepared` → `render_text` → `render_line_input_for_viewport`. Single
  selection (viewer-wide), so the Monaco `selections` loop becomes a zero-or-one
  `selection_view_range` — consistent with the overlay's
  `collect_line_selection_ranges`.
- **Re-render coupling (`viewLine.ts:94-100`):** `render_text` early-returns when
  generation and window are unchanged, so the selection mode needed an explicit
  invalidation. `ViewLines.on_view_event(ViewCursorStateChanged)` now returns
  `last_render_whitespace == Selection` (keyed on the last-rendered mode, like
  Monaco's `_renderedViewLine.input.renderWhitespace`), and `render_text` enters
  the full-rewrite branch when `selection_view_range != last_selection` in
  Selection mode; the existing `previous != input` diff limits the actual HTML
  writes to lines whose selected columns changed. `last_selection` /
  `last_render_whitespace` are tracked on `ViewLines`.
- **Default flipped** to `Selection` (`viewer_options.mbt`); regenerated the
  `viewer` `.mbti`. With no selection the mode is inert (empty per-line ranges →
  no glyphs), so the whole headless + browser suite stays green and the default
  visible output only changes once text is selected — matching a default Monaco
  editor.
- **Tests added:** `viewer/render_whitespace_selection_wbtest.mbt` (the four
  Selection shapes + the mode gate against `selections_on_line_for`),
  `tests/browser/component/whitespace_selection.spec.js` + the
  `tests/browser/moonbit/whitespace_selection` scenario (default-mode no-dots-at-
  rest, dots under a dragged selection, re-render on selection change). The
  Stage-1 default test was updated `None → Selection`. `moon test --target all`
  496 js / 458 native; full Playwright suite (44 specs) green; `just check`
  clean.

## Validation commands

`moon test --target all`; `moon check --warn-list +unnecessary_annotation`;
`moon fmt` + `moon info`; browser via `./node_modules/.bin/playwright test`
(sandbox disabled). See [[editor-validation-workflow]] for the `../moon.work`
bundle-rebuild gotcha and the `static_route` allowlist requirement.
