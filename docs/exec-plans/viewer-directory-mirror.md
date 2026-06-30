# Viewer ↔ Monaco Directory-Structure Mirror (platform tiers)

Status: planned — Date: 2026-06-30.

Refactor (no behavior change). Mirror Monaco's `vs/editor` directory tree as
MoonBit packages **at directory granularity** under three tiers —
`viewer/common`, `viewer/browser`, `viewer/contrib` — exactly as Monaco splits
`editor/{common,browser,contrib}` (one Monaco directory → one MoonBit package;
each `.ts` → a `.mbt` inside that package). Use `supported_targets` to make the
`common` (DOM-free) vs `browser` (DOM) split a build-time invariant rather than
a convention, and reduce the root `viewer/` package to a single `export.mbt`
facade that curates the public API (the analog of Monaco's
`vs/editor/editor.api.ts`).

Three payoffs:

1. **Enforcement.** The module is `+js+native` and `just check` runs
   `moon check --target all`. A `common`-tier package therefore *cannot* import
   a `browser`-tier (`supported_targets = "js"`) package — the native check
   fails. "Pure logic must not touch the DOM" becomes compiler-enforced.
2. **Completeness checking.** When our tree mirrors `vscode/src/vs/editor`
   dir-for-dir across all three tiers, a directory diff against the reference is
   a mechanical port-coverage checklist for the *whole* editor module (the
   `_PORT_PLAYBOOK.md` "own the denominator" rule, applied to structure).
3. **A single public-API contract.** Everything real lives under
   `common/`/`browser/`/`contrib/`; the root `viewer/` package holds only
   `export.mbt`, which re-exports the intended surface. `viewer/pkg.generated.mbti`
   then *is* the public API — every API change is a one-file diff at review time.

Why directory granularity (not file → package): MoonBit allows cycles *between
files in the same package* but forbids *cross-package* cycles. Monaco's
`vs/editor` has 20 file-level import cycles (132 files; largest 35 files / 6
dirs) that TS tolerates (type erasure + ESM live bindings) — file→package would
turn every one into a hard build error. Directory→package absorbs the 12
intra-directory cycles (31 files) for free; only cross-directory cycles need
real work. See "Cycle backlog" below.

---

## Mapping (the denominator)

`viewer/` ≈ `vs/editor`. Current state:

- `viewer/<feature>/` packages (`model`, `view_model`, `view_layout`, `cursor`,
  `languages`, `decorations`, `folding`, `markers`, `inline_decorations`,
  `view_line_renderer`, `hover`) = flattened `editor/common/*`, already DOM-free
  and multi-target. **Re-tiered under `viewer/common/`** (Decision D1).
- `viewer/common/` today is itself a grab-bag (`cursor_columns`, `line_html`,
  `mouse_target`, render helpers) whose files map to *different* Monaco dirs —
  e.g. `mouse_target.mbt` → `editor/browser/controller/mouseTarget.ts`
  (**browser**, not common!), `cursor_columns` → `common/core/`, `line_html`/
  render → `common/viewLayout/`. Re-tiering **redistributes this bag by each
  file's cited source path**, not a folder rename.
- `viewer/*.mbt` root files = flattened `editor/browser/*` (+ two
  `editor/contrib/*/browser` features), all in one `supported_targets = "js"`
  god-package. **This is what the refactor carves up.**
- After the refactor the root `viewer/` package contains only `export.mbt` (+ its
  `pkg.generated.mbti`): a js-only facade re-exporting the public surface.

### Target: common tier (`viewer/common/*`, multi-target)

Re-home the existing flat packages to mirror `editor/common/*`:
`model` → `common/model`, `view_model` → `common/view_model` (Monaco
`viewModel`), `view_layout` → `common/view_layout` (`viewLayout`), `cursor` →
`common/cursor`, `languages` → `common/languages`, `decorations` →
`common/model` decorations, `view_line_renderer` → `common/view_layout`
renderer, plus `common/core`, `common/tokens`, `common/services` for the
redistributed grab-bag files. **Phase 0 places each file by its header
citation; do not guess.**

### Target: browser tier (`viewer/browser/*`, `supported_targets = "js"`)

Mirrors `editor/browser` + the ported `editor/contrib/*/browser`:

| target package (`viewer/…`)            | Monaco source dir                              | root files to move |
|----------------------------------------|------------------------------------------------|--------------------|
| `browser/view/`                        | `editor/browser/view/`                         | `view.mbt`, `view_context.mbt`, `view_controller.mbt`, `view_part.mbt`, `view_layer.mbt`, `view_overlays.mbt`, `rendering_context.mbt`, `render.mbt`? |
| `browser/view_parts/content_widgets/`  | `editor/browser/viewParts/contentWidgets/`     | `content_widgets.mbt` + `.css` |
| `browser/view_parts/overlay_widgets/`  | `editor/browser/viewParts/overlayWidgets/`     | `overlay_widgets.mbt` + `.css` |
| `browser/view_parts/view_zones/`       | `editor/browser/viewParts/viewZones/`          | `view_zones.mbt` + `.css` |
| `browser/view_parts/margin/`           | `editor/browser/viewParts/margin/`             | `margin.mbt` + `.css` |
| `browser/view_parts/editor_scrollbar/` | `editor/browser/viewParts/editorScrollbar/`    | `editor_scrollbar.mbt` |
| `browser/view_parts/selections/`       | `editor/browser/viewParts/selections/`         | `selection.mbt`, `selection_measure.mbt` + `.css` |
| `browser/view_parts/view_lines/`       | `editor/browser/viewParts/viewLines/`          | `view_line.mbt` + `view_lines.css` |
| `browser/widget/code_editor/`          | `editor/browser/widget/codeEditor/`            | `viewer.mbt`, `viewer_options.mbt`, `public_read_api.mbt`, `reveal.mbt` |
| `browser/controller/`                  | `editor/browser/controller/`                   | `input.mbt`, `hit_test_dom.mbt` (merge existing `viewer/controller/mouse_handler.mbt`) |
| `contrib/hover/browser/`               | `editor/contrib/hover/browser/`                | `hover_controller.mbt`, `hover_utils.mbt`, `hover_widget_geometry.mbt` (+ existing `viewer/hover/*`?) |
| `contrib/folding/browser/`             | `editor/contrib/folding/browser/`              | `folding_controls.mbt` |

`registry.mbt`, `services.mbt`, `editor_events.mbt`, `view_events.mbt`,
`render.mbt` have ambiguous homes — **Phase 0 reads each file's header
citation** (every conformance port cites its `vscode/` source path per
`docs/quality.md`) to place it; do not guess. `view_events.mbt` in particular
may be `editor/common/viewEvents.ts` (common-tier), not browser.

**Out of scope** (named, not "unseen"): `gpu/`, `viewParts/minimap`,
`overviewRuler`, `glyphMargin`, `editor/browser/widget/diffEditor`,
`editor/standalone`, and the `inlineCompletions`/`suggest`/`snippet` contribs —
none are ported, so no package is created for them. They are exactly where
Monaco's largest cross-directory cycles live (see below), which is why the
viewer's inversion cost is small.

---

## Cycle backlog (Phase 0 must produce the real list)

Monaco `vs/editor` cross-directory cycles (the ones no granularity choice
absorbs) by directory set:

- 35 files — `common/{,languages,languages/supports,tokens,viewModel}` +
  bracket-pair tree → mostly tokenization / bracket-pair colorization.
- 21 files — `contrib/inlineCompletions` + `suggest` + `snippet`. **Not ported.**
- 19 files — `common/model/{bracketPairs,pieceTree,tokens/treeSitter}`. Mostly **not ported**.
- 14 files — `browser/widget/diffEditor`. **Not ported.**
- 4 — `common/core/{edits,text}`; 4 — `common/services{,/textModelSync}`;
  2 — `common/languages{,/supports}`; 2 — `test/browser`.

Phase 0 step: intersect each SCC with the files the viewer actually ports
(its existing `.mbt` set + the files this refactor moves). The big SCCs are in
un-ported subsystems; the residual backlog is the small `common/*` ones **plus
any cycle that the carve-up newly exposes between two target browser packages**
(e.g. a content-widget ↔ view edge that was free inside the root god-package).
Break each by the patterns already in use here: extract the shared interface
into a `common`-tier package, or invert via the host/callback pattern
(`controller_host.mbt`, `browser_host.mbt`). Do this **before** moving files
(Increment B) so no move is blocked by a cycle.

---

## Decisions to confirm before code

- **D1 — Full three-tier mirror. CONFIRMED: yes.** Re-tier the flat
  `viewer/<feature>` packages under `viewer/common/*` so all of
  `editor/{common,browser,contrib}` is mirrored. Rationale: the completeness-by-
  diff methodology pays off most when the *whole* module mirrors the reference,
  and doing the common re-tier in the same epic means import paths churn once,
  not twice. (Reverses the earlier "leave common flat" lean.) Cost: the current
  `viewer/common` grab-bag must be redistributed by header citation — see Mapping.
- **D2 — `export.mbt` facade. CONFIRMED: yes.** The root `viewer/` package keeps
  only `export.mbt` — `pub typealias` for public types + thin `pub fn`/`pub let`
  wrappers for entry points (MoonBit has no `export *`, so the surface is an
  explicit hand-maintained list — intentional by design). It re-exports browser
  types, so the facade package stays `supported_targets = "js"`; native/headless
  consumers import `viewer/common/*` directly. `viewer/pkg.generated.mbti` is the
  reviewable API contract. Analog: `vs/editor/editor.api.ts`.
- **D3 — Naming.** Monaco camelCase dir → MoonBit snake_case package
  (`contentWidgets` → `content_widgets`, `viewModel` → `view_model`). Keep
  `view_parts/` as the grouping dir under `browser/` (mirrors `viewParts/`).
- **D4 — `view/` granularity.** `editor/browser/view/` is one Monaco directory →
  **one** `viewer/browser/view/` package holding all its `.mbt` files (its
  internal file cycles are then intra-package, free). Do not split per file.

---

## Increments (each ends green: `just check && just test && just test-browser`, then commit)

- **A — Guardrail + target map.** Extend `scripts/check-architecture.mbtx` with
  three rules: (1) any package under `viewer/browser/` or `viewer/contrib/*/browser/`
  **must** declare `supported_targets = "js"`; (2) any `viewer/common/*` package
  **must not** declare js-only (logic stays multi-target so the native check keeps
  enforcing the boundary); (3) external consumers (`web`, `app`, `internal/shell`)
  may import only the root `viewer` package, not `viewer/{common,browser,contrib}/**`
  — this is what makes `export.mbt` a real boundary, since MoonBit does not enforce
  package privacy (same precedent as the existing `internal/shell` import rule).
  Record the target tree in `docs/architecture.md`. No code moves yet.
- **B — Break cross-directory cycles** found in Phase 0, *in place*, keeping
  tests green. This is the only behavior-adjacent work (dependency inversions);
  isolate it so the moves that follow are pure relocation.
- **C — Re-tier the common packages** under `viewer/common/*` and redistribute
  the `viewer/common` grab-bag by header citation (`mouse_target` → `browser/controller`
  in Increment F, `cursor_columns` → `common/core`, etc.). Do this before the
  browser carve-up so the common import surface is final and the browser packages
  import their stable paths once.
- **D — Carve `browser/view/`.** Move the `editor/browser/view/*` root files into
  one package. Highest fan-in; doing it early stabilizes the import surface the
  parts depend on.
- **E — Carve `browser/view_parts/*`,** one part per increment, leaf parts first
  (fewest dependents): `view_zones` → `content_widgets` → `overlay_widgets` →
  `margin` → `editor_scrollbar` → `selections` → `view_lines`.
- **F — Carve `browser/controller/`** (`input`, `hit_test_dom`, redistributed
  `mouse_target`); fold in the existing `viewer/controller/mouse_handler.mbt`.
- **G — Carve `browser/widget/code_editor/`** (`viewer.mbt`, options,
  `public_read_api`, `reveal`). This becomes the top of the browser tier.
- **H — Carve `contrib/hover/browser/` and `contrib/folding/browser/`.**
- **I — Reduce the root to `export.mbt`.** Once every real file has moved, write
  the facade: `pub typealias`/wrappers for the intended public surface, drop the
  root's `supported_targets = "js"` only if nothing browser remains (it won't —
  the facade re-exports browser types, so it stays js). Regenerate
  `viewer/pkg.generated.mbti` and review it as the public-API contract.

### Per-increment mechanics (the MoonBit grind)

For each package carved out:

1. Create `viewer/browser/.../moon.pkg` with `supported_targets = "js"` and the
   `import { … }` list (don't forget the rabbita `dom`/`js` bindings —
   `check_viewer_rabbita_bindings` only allows those two).
2. Move the `.mbt` files **and their `_wbtest.mbt`** into the new dir.
3. Add `pub` (or `pub(all)` for types/fields, per repo style) to symbols that
   were package-private but are now used cross-package. Expect visibility churn —
   it's the bulk of the work.
4. Move the part's `.css` next to it and update `css_sources()` in
   `scripts/build-web.mbtx` (lines ~264–282). The architecture-script `.css`
   carve-out already permits the citation comment.
5. Regenerate `pkg.generated.mbti` (`moon info`) for the source and any package
   whose surface changed.
6. Update `import { … }` in every dependent `moon.pkg`.
7. Green gate + commit. One package per commit — small diffs, easy bisect.

---

## Validation / exit gate

- `viewer/{common,browser,contrib}/` mirrors `vscode/src/vs/editor/{common,browser,contrib}/`
  dir-for-dir for every *ported* unit (checklist: the mapping table above, all
  rows landed; un-ported dirs explicitly listed as out-of-scope).
- Every `viewer/browser/*` and `viewer/contrib/*/browser/*` package declares
  `supported_targets = "js"`; no `viewer/common/*` package does.
- The root `viewer/` package contains only `export.mbt`; `viewer/pkg.generated.mbti`
  is the reviewed public-API surface, and no external consumer imports a deep
  `viewer/{common,browser,contrib}/**` package.
- `moon check --target all` green ⇒ proves zero `common → browser` import leaks
  (the native build would fail otherwise). This is the real invariant.
- `just check && just test && just test-browser` green, with the **same** test
  set and assertions as before — this is a structural refactor, so any test
  delta is a red flag (pre-existing `dom_structure.spec.js:58` hover `tabindex`
  failure on `main` excepted).
- Extended `check-architecture.mbtx` green (the three Increment-A rules).

## Deferred

- Packages for un-ported subdirs (`gpu`, `minimap`, `overviewRuler`,
  `glyphMargin`, `diffEditor`, `standalone`, completions/suggest/snippet) — they
  appear only when those features are ported.
- Porting the cycle audit (currently a one-off Python script) into
  `check-architecture.mbtx` as a standing cross-package-cycle report.
