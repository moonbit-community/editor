# Viewer ↔ Monaco Directory-Structure Mirror (platform tiers)

Status: in progress (A, B, C, E (7/7), D landed on branch
`viewer-directory-mirror`; F–I remain) — Date: 2026-07-01.

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

Mirrors `editor/browser` + the ported `editor/contrib/*/browser`. **Phase 0
correction (Increment B):** the guessed mapping below undercounted how much
root content is `Viewer::` glue. MoonBit forbids defining a method on a
foreign type ([[moonbit-foreign-method-rule]]), so every `Viewer::` method
must live in `Viewer`'s own package — there is no `browser/controller/` or
`contrib/folding/browser/` *package* in the end, because the files guessed for
them turned out to be 100% `Viewer::` glue with no other consumer. Confirmed
by reading each file's actual content (not just its filename), per files:

| target package (`viewer/…`)            | Monaco source dir                              | root files that actually move here |
|----------------------------------------|------------------------------------------------|--------------------|
| `browser/view/`                        | `editor/browser/view/`                         | `view.mbt` (minus `Viewer::` glue → `view_host.mbt`), `view_context.mbt`, `view_part.mbt` (incl. every `impl ViewPart for X with ...` block — see cycle-backlog fix pattern below), `rendering_context.mbt`, `view_events.mbt`, `selection_measure.mbt` (defines `View::` methods — foreign-method rule keeps it out of a separate `selections` package) |
| `browser/view_parts/content_widgets/`  | `editor/browser/viewParts/contentWidgets/`     | `content_widgets.mbt` (minus `Viewer::handle_hover_keydown` → `view_host.mbt`, minus its `impl ViewPart` block → `view_part.mbt`) + `.css` |
| `browser/view_parts/overlay_widgets/`  | `editor/browser/viewParts/overlayWidgets/`     | `overlay_widgets.mbt` (minus its `impl ViewPart` block) + `.css` |
| `browser/view_parts/view_zones/`       | `editor/browser/viewParts/viewZones/`          | `view_zones.mbt` (minus `ViewZoneChangeAccessor` + `Viewer::` glue → `view_zones_host.mbt`, minus its `impl ViewPart` block) + `.css` |
| `browser/view_parts/margin/`           | `editor/browser/viewParts/margin/`             | `margin.mbt` (minus its `impl ViewPart` block) + `.css` |
| `browser/view_parts/editor_scrollbar/` | `editor/browser/viewParts/editorScrollbar/`    | `editor_scrollbar.mbt` (minus its `impl ViewPart` block) |
| `browser/view_parts/view_lines/`       | `editor/browser/viewParts/viewLines/`          | **Phase 0 correction:** `view_layer.mbt` (defines `ViewLines`, the actual recycler/view-part — the original guess placed this in `browser/view/`, wrong) + `view_line.mbt` (its per-line render helper) + `view_lines.css`, both minus their `impl ViewPart` block |
| `browser/view_parts/selections/`       | `editor/browser/viewParts/selections/`         | **Phase 0 correction:** `view_overlays.mbt` (defines `ContentViewOverlays`, styled by `selections.css`+`view_overlays.css` — this is Monaco's `SelectionsOverlay`/`ContentViewOverlays` merged into one concrete type; `selection.mbt`/`selection_measure.mbt` do **not** go here, see reclassification below), minus its `impl ViewPart` block |
| `browser/widget/code_editor/`          | `editor/browser/widget/codeEditor/`            | `viewer.mbt`, `viewer_options.mbt`, `public_read_api.mbt`, `reveal.mbt`, `view_host.mbt`, `view_zones_host.mbt`, plus the reclassified files below |
| `contrib/hover/browser/`               | `editor/contrib/hover/browser/`                | `hover_controller.mbt` (now also holds `EditorEvent`/`EditorContext`), `hover_utils.mbt`, `hover_widget_geometry.mbt` |
| existing `viewer/controller/`, renamed `browser/controller/` | `editor/browser/controller/`   | just the existing `mouse_handler.mbt` — `input.mbt`/`hit_test_dom.mbt` do **not** merge in (see reclassified below) |

**Reclassified to `browser/widget/code_editor/` (not their guessed target)** —
each of these is 100% `Viewer::` methods (plus tiny pure helpers used only by
that glue), so the foreign-method rule leaves no other place for them to live:
`input.mbt` (guessed `browser/controller/`), `hit_test_dom.mbt` (guessed
`browser/controller/`), `selection.mbt` (guessed `browser/view_parts/selections/`
by filename — its actual content is cursor dispatch + clipboard copy, not the
selection-overlay *renderer*; that's `view_overlays.mbt`, see the corrected
table above), `view_controller.mbt` (guessed `browser/view/` per Monaco's
directory, but `Viewer` isn't part of `editor/browser/view/`'s Monaco content),
`folding_controls.mbt` (guessed `contrib/folding/browser/` — same fate as
hover's controller glue, see below), `render.mbt` and `registry.mbt` (were
already ambiguous; both are `Viewer::` model-attach orchestration).

`services.mbt` (`ViewerServices`, DOM-free) → `common/services` (multi-target;
`Viewer`'s `services` field, browser-tier, imports it one-directionally, which
is always fine).

**`contrib/folding/browser/` does not end up existing as a package.** Its only
candidate content (`folding_controls.mbt`) is pure `Viewer::` glue, same as
`editor_events.mbt`'s hover-controller glue — Monaco's `FoldingController`
equivalent is inseparable from `Viewer` in this port. Only the DOM-free folding
*model* (already landed in Increment C at `viewer/contrib/folding`) is a real
separate package.

**Out of scope** (named, not "unseen"): `gpu/`, `viewParts/minimap`,
`overviewRuler`, `glyphMargin`, `editor/browser/widget/diffEditor`,
`editor/standalone`, and the `inlineCompletions`/`suggest`/`snippet` contribs —
none are ported, so no package is created for them. They are exactly where
Monaco's largest cross-directory cycles live (see below), which is why the
viewer's inversion cost is small.

---

## Cycle backlog (Phase 0's real list, found by reading root file content)

Monaco `vs/editor` cross-directory cycles in the un-ported subsystems (no
granularity choice absorbs these, but they're out of scope — see above):
35 files in `common/{,languages,languages/supports,tokens,viewModel}` +
bracket-pair tree; 21 in `contrib/inlineCompletions`+`suggest`+`snippet`; 19 in
`common/model/{bracketPairs,pieceTree,tokens/treeSitter}`; 14 in
`browser/widget/diffEditor`; a handful of small ones in `common/core/{edits,text}`,
`common/services{,/textModelSync}`, `common/languages{,/supports}`, `test/browser`.

**The real, in-scope backlog** — found by reading every root file's actual
content against the target-package map above, not by guessing from Monaco's
directory names — was three genuine cross-package cycles, all fixed in
Increment B:

1. **`Viewer` ↔ `browser/view/`.** `ViewContext::new(viewer: Viewer, view: View)`
   and `View::render(self, viewer: Viewer, input)` both referenced `Viewer`
   directly from files that must live in `browser/view/` (a different package
   from `Viewer`'s). Fix: `ViewContext` is now `pub(all)` and built by
   `Viewer::build_view_context` in `view_host.mbt` (Viewer's package);
   `View::render` takes the pre-built `ViewContext` instead of `Viewer`.
2. **`EditorEvent`/`EditorContext` ↔ `HoverController`.** `HoverController::on_event`
   (destined for `contrib/hover/browser/`) takes these two types as parameters;
   they were defined in `editor_events.mbt` alongside `Viewer`'s dispatch glue
   (destined for `browser/widget/code_editor/`). Fix: moved the type
   definitions into `hover_controller.mbt` (now `pub(all)`) since
   `contrib/hover/browser/` is downstream of `browser/widget/code_editor/`
   anyway (`Viewer.hover : HoverController`); the glue that *constructs* them
   (`Viewer::editor_context`, `Viewer::dispatch_editor_event`, etc.) stays put
   and just references the relocated types.
3. **`ViewZoneChangeAccessor` ↔ `browser/view_parts/view_zones/`.** Same shape
   as #1: a public struct holding a `viewer : Viewer` field, defined in
   `view_zones.mbt` (destined for `browser/view_parts/view_zones/`). Fix: moved
   the accessor + its 4 `Viewer::` methods to `view_zones_host.mbt`; made
   `BrowserViewZone` `pub(all)` since `Viewer.view_zones : Array[BrowserViewZone]`
   and the host glue now construct/read it across the future package boundary.

**A fourth cycle exists, and it forces Increment D and E to swap order.**
Every `viewParts/*` file's `impl ViewPart for X with fn ...(self, context:
RenderingContext) ...` blocks reference `RenderingContext`/
`RestrictedRenderingContext`/`ViewEvent` (owned by `browser/view/`, via the
`ViewPart` trait), while `browser/view/` needs the concrete part types (`View`
struct fields, the `ViewPartHandle` enum, `View::build()`'s 7 constructor
calls) — bidirectional if the impl blocks stay in each view-part's own file.
**Fix:** MoonBit's orphan rule permits implementing a trait for a foreign type
from the package that owns the *trait*; so every `impl ViewPart for X with
...` block moves into `view_part.mbt` (`browser/view/`) — only the
struct/constructor/DOM-render logic moves to each `view_parts/*` package.
This makes `browser/view/ → view_parts/*` one-directional (view/ needs the
concrete types; view_parts/* needs nothing back), acyclic — **but only if
all 7 `view_parts/*` packages already exist as separate packages before
`browser/view/` is carved**, since `view_part.mbt`'s `ViewPartHandle` enum
and `View::build()` reference all 7 concrete types at once. Carving
`browser/view/` (D) before the parts (E) would make the still-undivided root
`viewer` package and the new `browser/view/` package import each other — a
real cycle, not just an anti-pattern. **So Increment E must run before D**,
each part leaving its `impl ViewPart` block behind in the root's
`view_part.mbt` until D finally carves it out last, once all 7 parts (plus
`selections` and `view_lines`, per the corrected mapping above) are already
independent packages.

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
- **E — Carve `browser/view_parts/*` first** (order swapped from the original
  plan — see the cycle-backlog's 4th finding: `view_part.mbt`'s
  `ViewPartHandle` enum needs all 7 concrete types, so carving `browser/view/`
  before the parts exist as separate packages is a real cycle, not just an
  anti-pattern), one part per increment, leaf parts first (fewest dependents):
  `view_zones` → `content_widgets` → `overlay_widgets` → `margin` →
  `editor_scrollbar` → `view_lines` (`view_layer.mbt`+`view_line.mbt`) →
  `selections` (`view_overlays.mbt`). For each part, apply the ViewPart-trait
  fix: leave its `impl ViewPart for X with fn ...` block behind in the root's
  `view_part.mbt` (it moves to `browser/view/` only in D, below); move only
  the struct/constructor/DOM-render logic + its `.css`.
- **D — Carve `browser/view/` last**, once all 7 parts above are already
  separate packages. Move `view.mbt`, `view_context.mbt`, `view_part.mbt`
  (now also holding all 7 `impl ViewPart` blocks moved out of the parts in E),
  `rendering_context.mbt`, `view_events.mbt`, `selection_measure.mbt` into one
  package (`view_controller.mbt` does *not* move here — reclassified to G).
- **F — Rename `viewer/controller/` to `browser/controller/`.** Just the
  existing `mouse_handler.mbt`/`mouse_target` content — `input.mbt` and
  `hit_test_dom.mbt` do not merge in (reclassified to G in Phase 0).
- **G — Carve `browser/widget/code_editor/`.** The largest increment post-Phase-0:
  `viewer.mbt`, `viewer_options.mbt`, `public_read_api.mbt`, `reveal.mbt`,
  `view_host.mbt`, `view_zones_host.mbt`, plus the reclassified `input.mbt`,
  `hit_test_dom.mbt`, `selection.mbt`, `view_controller.mbt`, `folding_controls.mbt`,
  `render.mbt`, `registry.mbt`, and the `Viewer`-glue remainder of
  `editor_events.mbt`. This becomes the top of the browser tier.
- **H — Carve `contrib/hover/browser/`** (`hover_controller.mbt` incl.
  `EditorEvent`/`EditorContext`, `hover_utils.mbt`, `hover_widget_geometry.mbt`).
  No `contrib/folding/browser/` — see Phase 0's finding above.
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
