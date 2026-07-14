# Browser View Package Consolidation

Status: complete — Gate A approved and implementation validated 2026-07-14
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
headers. The complete source set is:

- complete `vscode/src/vs/editor/browser/view.ts`;
- `vscode/src/vs/editor/browser/view/{dynamicViewOverlay,renderingContext,viewLayer,viewOverlays,viewPart,viewUserInputEvents}.ts`
- all 34 TypeScript and all 18 CSS files under
  `vscode/src/vs/editor/browser/viewParts/`, including unsupported source
  units with no local counterpart.

The closed set is 59 files: 41 TypeScript / 13,623 lines and 18 CSS / 505
lines. The Gate A entrypoint records the ordered path/line/SHA manifest and its
aggregate hash.

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
been explicitly approved.**

Gate A is recorded as a four-document artifact set:

- `browser-view-package-consolidation-gate-a.md`;
- `browser-view-package-consolidation-gate-a-upstream.md`;
- `browser-view-package-consolidation-gate-a-local.md`;
- `browser-view-package-consolidation-gate-a-tests.md`.

The artifact set is documentation-only. Product implementation remains
blocked until the entrypoint and all three companions are explicitly approved.

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
2. Treat `view_layer_renderer.mbt`, all four `view_lines` production units,
   and their five test files as the single atomic Milestone-C group; moving
   the renderer first would introduce a temporary parent/child package cycle.
3. Move only the independent leaf parts that participate in neither mandatory
   atomic group.
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

1. Keep all twelve leaf CSS files at their current paths as asset-only
   directories; keep the two root view CSS files and `codicon.ttf` at their
   current paths too. The build list and emitted provenance comments therefore
   remain byte-for-byte unchanged.
2. Preserve the exact CSS concatenation/cascade order and generated output.
3. Fold the leaf READMEs into `viewer/browser/view/README.md`, retaining
   ownership, invariants, source mappings, and test commands; remove historical
   package-cycle explanations.
4. Update `docs/architecture.md` and the Monaco reference map with the new
   single-package/file-unit rule.

## Behavior and Configuration Matrix

Before exit, each axis below must end either `TESTED` or explicitly
seam-deferred in the Gate A tests companion. The structural move preserves the
companion's already reviewed gaps rather than silently upgrading them:

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

- [x] inventory rows equal scoped source members; final totals are recorded
- [x] only `viewer/browser/view/moon.pkg` remains for the scoped implementation
- [x] no product or test import references `viewer/browser/view_layer` or
      `viewer/browser/view_parts/*`
- [x] files retain source-unit names and responsibilities
- [x] no public declaration exists only to cross a deleted package boundary
- [x] DOM order, CSS output/order, event order, render results, and disposal
      behavior are unchanged
- [x] all deviations are seam-based and recorded
- [x] closing complete-source reread finds no unaccounted member
- [x] required validation is green

## Completion Record

Gate A's frozen denominator remains 59 pinned upstream files and 4,154
terminal parity rows: 1,536 `TESTED`, 143 `PORTED`, 231 `N-A`, and 2,244
`DEFERRED`. The closing reread and ledger reconciliation found no unaccounted
source member and did not change any reviewed disposition.

The implemented local denominator is:

| Kind | Final result |
|---|---:|
| Production MoonBit | 31 source-unit files / 9,331 lines / 536 declarations |
| MoonBit tests | 16 files / 118 named tests + 130 helpers = 248 declarations |
| Named-test hash | `802b390612801a787a6a21e247f55cd747877e498a8f71f63cbad31ac92052dc` |
| Production filename hash | `be2a5c4b23917cb4b28bd8752a5a5f70eff08677007ac0278b505e731ab1f8bb` |
| Target imports | 12 paths / `6d9e65b14fa8f2e680bd2aaf3eaae8579b0f7324fb78f6bf04255fa2376f8cfd` |
| Scoped package artifacts | one `moon.pkg`, one `pkg.generated.mbti`, one `README.md` |
| Generated public interface | 100 entries; no former package-seam export remains |
| CSS | 14 paths; `web/dist/style.css` is 56,378 bytes / `bcf27861211e6731f0208a756946f9d1f2110c1e8c24bc936cbe5d5d76d66599` |

The eight surviving `viewer/browser/view_parts/*` directories contain CSS
assets only. All old manifests, generated interfaces, README contracts, and
MoonBit imports are gone. Primary constructors in the target package use the
canonical `Type::Type` spelling; only the reviewed alternate factories remain.

Validation completed on 2026-07-14:

- `moon test viewer/browser/view --target js -v`: 118/118;
- `moon check --target all`, `moon info --target all`, and
  `moon ide analyze viewer/browser/view`: green;
- `just check`: architecture and formatting gates green;
- `just test`: 1,402/1,402 JS and 1,004/1,004 native tests green;
- `just build`: browser bundles, stylesheet, and native server green;
- `just test-browser`: 82/82 Playwright tests green, including the 12-cell
  pinned Monaco scroll-frame matrix;
- structural import/artifact/count/hash checks and `git diff --check`: green.

There are no behavioral deviations. The reviewed unsupported Monaco units and
configuration branches retain their Gate A `DEFERRED`/`N-A` dispositions. The
only new test seam is a JS white-box adapter in the root event-source tests,
used to assert private event payload fields without reopening the production
API. The compiler reports expected unused-private warnings for ledger-retained
members that became internal; deleting or re-exporting them would change the
approved denominator or boundary.

## Cross-Plan Coordination

Execute this plan before `viewer-public-editor-api-boundary.md`. It may retain
temporarily public widget/view-zone types needed by the root package; the API
plan decides their final public owner.

Do not execute it in parallel with another plan that edits
`viewer/moon.pkg`, `viewer/browser/view/moon.pkg`, the CSS assembly list, or
browser conformance fixtures.
