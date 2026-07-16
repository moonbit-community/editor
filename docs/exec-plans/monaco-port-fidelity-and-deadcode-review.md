# Monaco Port Fidelity & Dead-Code Review

Status: proposed — Date: 2026-06-23.

A read-only audit (no behavior changes) of the now-complete 6-phase one-to-one
Monaco port (`monaco-one-to-one-port.md`, all phases landed per the commit log).
It answers two questions and produces a catalog of findings; it does **not**
apply fixes. Remediation, if any, is a separate plan.

1. **Fidelity** — where does ported code diverge in *logic or style* from the
   Monaco source it claims to transcribe, and is each divergence a **documented
   deliberate deviation** or an **undocumented drift**?
2. **Dead weight** — what code, exports, and package dependencies became
   unreachable once the port replaced the bespoke pipeline (the `RenderLine`
   offset helpers, `mut selection` on `Viewer`, the `ViewRenderChange`
   snapshot-diff, the pre-cursor-stack selection mutation)?

## Why this is tractable

- The **`vscode` submodule is vendored locally** (`vscode/src/vs/editor/...`).
  Every "is this faithful?" question is answerable by side-by-side comparison
  against the real oracle rather than from memory. Product code still must not
  import from it (`scripts/check-architecture.mbtx`); it is a reference only.
- `monaco-one-to-one-port.md` already ships a subsystem → Monaco-module mapping
  table (its "Subsystem audit") and explicit acceptance criteria. This review is
  the act of checking the code against that table and those criteria.
- The progress notes record the **known deferred deviations** — the full
  13-variant `MouseTargetType` (Phase 4), the previous-frame corner cache
  (Phase 5), and interval-tree decoration storage (Phase 6). The review confirms
  those are the *only* deviations and that each is recorded where the code lives.

## A live lead (found while scoping this plan)

The port's acceptance criteria state: "Cursor/selection/hit-test/decoration code
contains no raw-document-offset round-trips; all of it works in view `Position`s
via the `CoordinatesConverter`." Yet the bespoke `RenderLine` offset helpers the
port set out to remove are still defined `pub` in
`viewer/view_model/render_frame.mbt` and still called on the live paths:

- `viewer/selection.mbt:121,122,147` — `model_line_start_offset`,
  `source_offset_at_column`
- `viewer/input.mbt:685` — `model_line_start_offset`
- `viewer/hit_test_dom.mbt:118` — `source_offset_at_column`
- `viewer/common/mouse_target.mbt:115,136,145` — `source_offset_at_column`
- `viewer/content_widgets.mbt:496,497,499` — `source_offset_at_column`,
  `view_column_at_source_offset`
- `viewer/view_model/view_model_lines_projected.mbt:139` — `source_offset_at_column`

Each call is either a legitimate model/clipboard boundary, an
acceptance-criteria violation, or dead code (e.g. if `selection.mbt` is no longer
wired in after the cursor stack replaced it). Resolving this thread is the
natural seam between the two workstreams below.

## Workstream A — Fidelity audit (mismatched logic/style)

Walk each row of the port doc's audit table, comparing the local owner against
its `vscode/...` counterpart.

| Step | Method |
| --- | --- |
| A1 | Use the checked-in Monaco source files per subsystem (the audit table and `docs/references/monaco.md` give the paths). Record exact source paths and line ranges so findings are reproducible. |
| A2 | For each `Faithful`/`Subset` row (coordinate conversion, line renderer, scrollbar, hover, view layout, view-model lines), diff control flow against Monaco. Flag algorithmic re-derivations, renamed/merged responsibilities, and helpers with **no Monaco counterpart** on the cursor/selection/hit-test/decoration path (the port's rule #1). |
| A3 | For each module ported in this effort (`viewer/core` `Selection`, `viewer/cursor/*`, `viewer/view_controller.mbt`, `viewer/view_events.mbt`, `view_overlays.mbt` `SelectionsOverlay`, `view_model/view_model_decorations.mbt`, `view_line_data.mbt`), verify the class/method decomposition, names, and algorithm match Monaco. |
| A4 | **Coordinate-model invariant** (the port's most important rule). Triage the offset round-trips listed in "A live lead" above: legitimate boundary, dead code (hand to Workstream B), or acceptance-criteria violation. |
| A5 | Confirm the three known deviations are present **and documented at the code site** (README/comment), not silently divergent. Anything diverging that is not on that list is a `Drift`. |
| A6 | **Style** pass: naming and the 1-based/0-based column seam (a past selection bug per the selection-rework notes), `ViewEventHandler` shapes, and file/type granularity vs Monaco modules. |

## Workstream B — Unused code & packages

| Step | Method |
| --- | --- |
| B1 | **Compiler-driven first pass.** `moon check` with the dead-code warnings enabled: `+1`/`+2` unused fn/var, `+3` unused type, `+6` unused constructor, `+7` unused field, `+29` **unused package**, `+49` pub def absent from the `.mbti`. Catches within-package dead code and unused deps directly. (Run `moon update` first in a fresh shell; viewer is `--target js`.) |
| B2 | **Cross-package public dead code.** `moon check` cannot flag a `pub` fn unused by *other* packages. For each export in the `pkg.generated.mbti` files, grep the repo for `@pkg.symbol`; zero non-test hits → candidate dead export. Prioritize what the port superseded. |
| B3 | **Port-superseded suspects** (targeted): `viewer/selection.mbt` (replaced by the cursor stack — still wired in, or orphaned?); the offset-helper trio on `RenderLine` (still `pub`; dead public surface if only tests call them); `ViewRenderChange` remnants (only a comment remains in `view_events.mbt` — confirm the struct is fully gone); pre-cursor-stack selection mutation. |
| B4 | **Unused dependencies.** Per `moon.pkg`, cross-check declared `import` entries against actual `@pkg` references. The `package_imports` parser in `scripts/check-architecture.mbtx` already extracts the import list — reuse it. |
| B5 | Classify each finding: safe to delete / keep (intentional API surface) / mark test-only. **No deletions in this review** — catalog only. |

## Deliverable

A findings report under `docs/exec-plans/` (or a review note). Every finding is
tagged and cited `local_file:line` ↔ `vscode/src/vs/...:line`:

- **Faithful** — transcribed, matches Monaco.
- **Deviation-documented** — differs by recorded decision; cite where.
- **Drift** — differs with no recorded decision (the actionable bucket).
- **Dead** — unreachable after the port; with a delete/keep recommendation.

Close with a short ranked list of follow-up fixes (likely: drop the dead offset
helpers, document or remove the remaining offset round-trips, delete an orphaned
`selection.mbt` if unwired).

## Sequencing & effort

1. **Setup** (small): use the checked-in submodule, draft the report skeleton from
   the audit table, run the B1 compiler pass to seed Workstream B.
2. **Per-subsystem fidelity** (bulk): A2/A3 row by row — start with the in-port
   modules (cursor, selection, overlay, decorations, view-controller,
   view-events) where divergence was expected, then re-confirm the "keep as-is"
   rows have not drifted.
3. **Invariant + dead-code sweep** (focused): A4 and all of B together — they
   share the offset-helper investigation.
4. **Report + recommendations.**

## Validation

The review changes no behavior, so the only gate is that throwaway probes leave
the repo building clean: `just check` / `just test` (`moon update` first in a
fresh shell; viewer tests are `--target js`). Browser-bundle rebuild caveats
matter only if findings are later acted on.

## Out of scope

Tokenization (`syntax/*`, intentionally non-Monaco), caret rendering
(`viewParts/viewCursors`, deliberately absent), and applying any fix. This
produces the catalog; remediation is a separate plan.
