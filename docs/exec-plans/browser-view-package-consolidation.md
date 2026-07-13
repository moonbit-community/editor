# Browser View Package Consolidation

Status: proposed; no implementation has started
Date: 2026-07-13
Oracle commit: `vscode` submodule at
`b18492a288de038fbc7643aae6de8247029d11bd`

## Goal

Collapse the implementation-only browser view package fan-out into one
MoonBit package, `viewer/browser/view`, while preserving Monaco source-unit
boundaries as individual `.mbt` files.

The current package split makes types public because another MoonBit package
must see them, not because they are product contracts. The target removes
those package-cycle adapters and makes `View`, its render contexts, its view
parts, and its recycler one ownership unit, matching Monaco's
`editor/browser/view` + `editor/browser/viewParts` runtime ownership more
closely.

This is a structural refactor. It must not change rendering behavior, DOM
order, CSS cascade, event order, geometry, scheduling, or disposal order.

## Current Denominator

Production MoonBit lines at the 2026-07-13 audit:

| Local package group | Lines | Current role |
|---|---:|---|
| `viewer/browser/view` | 3,187 | `View`, contexts, event dispatch, lifecycle adapters |
| `viewer/browser/view_layer` | 359 | shared `ViewLayerRenderer` recycler |
| `viewer/browser/view_parts/*` | 5,777 | concrete view parts and owned DOM/CSS |
| Target package total | 9,323 | below the repository's 10k package target |

The current `viewer/browser/view/moon.pkg` imports every leaf view-part
package. Leaf packages then expose handles, tuples, mutable render state, and
adapter methods back to `browser/view`. Comments such as the ones in
`view_parts/view_lines/view_lines.mbt` and `browser/view/rendering_context.mbt`
explicitly identify the package-cycle seams.

The local denominator is every production, test, README, CSS, and `moon.pkg`
file under:

- `viewer/browser/view/`
- `viewer/browser/view_layer/`
- `viewer/browser/view_parts/`

## Phase 0: Pinned Source Scope

Before moving code, inventory every upstream file named by the scoped local
headers. The minimum source set is:

- `vscode/src/vs/editor/browser/view/{dynamicViewOverlay,renderingContext,viewLayer,viewOverlays,viewPart,viewUserInputEvents}.ts`
- all represented source units under
  `vscode/src/vs/editor/browser/viewParts/`, including content widgets,
  current-line highlight, decorations, editor scrollbar, line numbers, lines
  decorations, margin, overlay widgets, selections, view cursors, view lines,
  and view zones
- every upstream CSS file owned by those source units

Source files with no local counterpart, such as an unsupported glyph-margin
or ruler unit, still receive an explicit `DEFERRED (reason)` or `N-A (reason)`
row. Directory discovery is not a substitute for reading the complete files.

Explicitly out of scope:

- adding unsupported Monaco view parts;
- changing render algorithms or filling behavior gaps;
- moving public editor/browser contracts such as widget interfaces; the
  public-API-boundary plan owns those contracts;
- controller, mouse-handler, model, view-model, or layout ownership changes;
- changing the generated `web/dist/style.css` delivery contract.

## Gate A: Inventory and Review Stop

Produce these review artifacts before any file move:

1. A source-member ledger covering every scoped upstream public/private
   member, constant, branch, early return, DOM node, class, style, and custom
   property.
2. A local-symbol ledger covering every declaration in the three local
   package groups, including declarations currently public only for
   cross-package access.
3. A caller matrix from `moon ide find-references`, separated into:
   - root `viewer` callers;
   - browser controller callers;
   - other view-part callers;
   - tests and browser scenarios;
   - genuine external consumers.
4. A CSS assembly-order inventory from the build script through
   `web/dist/style.css`.
5. A list of filename collisions that flattening would create and their
   source-shaped resolved names.

Every upstream member gets a parity-ledger row ending in `PORTED`, `TESTED`,
`PASS`, `DEFERRED (reason)`, or `N-A (reason)`. Record the member count.

**Review gate: stop here. Do not move code until the inventory and ledger have
been reviewed.**

## Target Layout

There is one `viewer/browser/view/moon.pkg`. Source units remain separate
files in that package:

- core: `view.mbt`, `view_context.mbt`, `rendering_context.mbt`,
  `view_event_dispatcher.mbt`, `view_part.mbt`, `view_overlays.mbt`,
  `view_user_input_events.mbt`;
- recycler: `view_layer.mbt`;
- parts: `content_widgets.mbt`, `current_line_highlight.mbt`,
  `decorations.mbt`, `editor_scrollbar.mbt`, `line_numbers.mbt`,
  `lines_decorations.mbt`, `margin.mbt`, `overlay_widgets.mbt`,
  `selections.mbt`, `view_cursors.mbt`, `view_lines.mbt`, `view_line.mbt`,
  `view_zones.mbt`, and their focused helper files;
- tests remain beside the source unit they exercise, with unique names.

The target deliberately uses files for organization and packages for real
dependency boundaries. It does not recreate the old subpackages with wrapper
files or re-exports.

## Milestone B: Establish the Union Package

1. Build the union import list in `viewer/browser/view/moon.pkg`; keep
   `supported_targets = "js"`.
2. Move `view_layer_renderer.mbt` first and update its callers.
3. Move leaf parts that do not depend on another leaf part.
4. After each move, update package-qualified names to unqualified/private
   names where ownership is now local.
5. Move the associated white-box tests in the same milestone as their source.

Gate after each coherent move:

- `moon check --target js`
- the moved unit's MoonBit tests
- `just check`

Commit each green leaf group. Do not leave a temporary compatibility package
after all callers have moved.

## Milestone C: Collapse the Coupled View Parts

Move the dependency-heavy units in this order:

1. current-line highlight, line numbers, lines decorations, and margin;
2. dynamic content/margin overlays;
3. content and overlay widgets;
4. view cursors and selections;
5. view lines, view line, range/DOM-reading helpers, and the recycler;
6. view zones;
7. the remaining lifecycle adapters in `browser/view`.

For each group:

- preserve source control flow and event ordering;
- replace tuple/context unpacking that existed only to cross a package with
  the source-shaped context or direct private method;
- move a method onto its owning type when the old free function existed only
  because MoonBit forbids foreign methods;
- retain a seam only when DOM/FFI or a real dependency direction requires it,
  and record it in `Deviations`.

No logic rewrite is allowed inside the relocation commit. If the source reread
finds a behavior gap, record it and create a separate follow-up plan.

## Milestone D: Remove Package-Boundary Artifacts

After all code is in one package:

1. Run `moon ide analyze viewer/browser/view` and inspect every zero-use or
   test-only declaration.
2. Make lifecycle handles, render carriers, fingerprints, cached render data,
   and helper methods private unless a caller inventory proves otherwise.
3. Remove aliases and adapters that only translated between the former
   packages.
4. Replace primary `Type::new` constructors touched by this refactor with
   `Type::Type` when `new` is not a distinct alternate construction path.
5. Delete the old `view_layer` and `view_parts/*` package manifests and
   generated interfaces.
6. Update root/browser manifests and architecture checks so no old import path
   remains.

The API diff from `moon info` is an intended result: package-seam APIs should
disappear. Observable viewer APIs must not change in this plan.

## Milestone E: CSS and Documentation

1. Move CSS next to the owning flattened source unit or keep its source-shaped
   filename in a dedicated view CSS directory, depending on the build
   inventory decision.
2. Preserve the exact CSS concatenation/cascade order and generated output.
3. Fold the leaf READMEs into `viewer/browser/view/README.md`, retaining
   ownership, invariants, source mappings, and test commands; remove historical
   package-cycle explanations.
4. Update `docs/architecture.md` and the Monaco reference map with the new
   single-package/file-unit rule.

## Behavior and Configuration Matrix

The existing tests must cover at least these axes before exit:

- no model / attached model / model swap / dispose;
- empty viewport / normal viewport / scrolled viewport;
- wrapped and unwrapped lines;
- content and margin overlays independently dirty;
- selections, cursors, decorations, widgets, and view zones present/absent;
- smooth scrolling enabled/disabled;
- viewport width/height and horizontal-scroll changes;
- DOM node order, transform ownership, CSS classes, and stale-node recycling.

Required validation:

- `moon check --target all`
- `just check`
- `just test`
- `just build`
- `just test-browser`
- relevant Monaco differential/conformance suites

## Exit Criteria

- [ ] inventory rows equal scoped source members; final totals are recorded
- [ ] only `viewer/browser/view/moon.pkg` remains for the scoped implementation
- [ ] no product or test import references `viewer/browser/view_layer` or
      `viewer/browser/view_parts/*`
- [ ] files retain source-unit names and responsibilities
- [ ] no public declaration exists only to cross a deleted package boundary
- [ ] DOM order, CSS output/order, event order, render results, and disposal
      behavior are unchanged
- [ ] all deviations are seam-based and recorded
- [ ] closing complete-source reread finds no unaccounted member
- [ ] required validation is green

## Cross-Plan Coordination

Execute this plan before `viewer-public-editor-api-boundary.md`. It may retain
temporarily public widget/view-zone types needed by the root package; the API
plan decides their final public owner.

Do not execute it in parallel with another plan that edits
`viewer/moon.pkg`, `viewer/browser/view/moon.pkg`, the CSS assembly list, or
browser conformance fixtures.
