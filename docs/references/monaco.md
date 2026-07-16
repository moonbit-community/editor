# Monaco Reference Map

Monaco/VS Code is the primary reference for this project. Use it for readonly
viewer behavior, API shape, rendering roles, widget behavior, and conformance
tests. Copy roles and observable behavior, not runtime code, services, or
package names.

The VS Code submodule contains Monaco's editor implementation under
`vscode/src/vs/editor`.

Use these as design references only. Do not import from them in product code.
When Monaco and current local docs disagree, treat current local docs as the
product boundary and Monaco as the source to research before changing it.

## Text model and tokenization

The upstream `common/model` tree, including its `model/tokens` subdirectory,
maps to the single multi-target local `viewer/common/model` package. Member-level
parity evidence remains in frozen execution plans and source citations. The
tokenization merge used the checked-in `vscode` submodule.

## View model and inline decorations

The upstream `common/viewModel/inlineDecorations.ts`,
`viewModelDecoration.ts`, and `viewModelDecorations.ts` units map to focused
files in the single multi-target local `viewer/common/view_model` package.
The upstream `test/common/viewModel/inlineDecorations.test.ts` suite maps to
`inline_decorations_reference_wbtest.mbt` in that package. The ownership
merge and its 23-case conformance denominator use the checked-in `vscode` submodule; member-level dispositions and
terminal product-reach deferrals live in the frozen execution-plan ledger.

## Browser view and view parts

The implemented units from upstream `browser/view.ts`, `browser/view/*.ts`,
and `browser/viewParts/**/*.ts` map to focused files in the single js-only
local `viewer/browser/view` package. Unsupported pinned view-part units retain
their explicit `DEFERRED`/`N-A` rows in the execution-plan ledger:

- `browser/view.ts` maps to `view.mbt`;
- shared view machinery maps to source-shaped units such as
  `rendering_context.mbt`, `view_layer.mbt`, `view_overlays.mbt`,
  `view_part.mbt`, and `view_user_input_events.mbt`;
- each implemented `browser/viewParts/<part>/*.ts` unit maps to the
  corresponding part-named `.mbt` files in that same package, from
  `content_widgets.mbt` through `view_zones.mbt`.

These `.mbt` files preserve source-unit responsibilities for inventory,
citations, and parity review; they do not create MoonBit packages or
namespaces. The `viewer/browser/view_parts/*` directories are CSS asset paths
only, retained so the stylesheet build and provenance paths stay stable.

## Editor contribution ownership

The complete upstream
`browser/widget/codeEditor/codeEditorContributions.ts` unit, its bounded
`codeEditorWidget.ts` integration clusters, and the scoped hover, folding,
agent-feedback, and quick-diff controller lifetimes map to the root
`viewer/editor_extensions.mbt` registry plus focused root registration/host
files. The local `Viewer.contributions` map is the one per-editor instance
store, corresponding to Monaco's `CodeEditorContributions._instances`.
Feature-specific root accessors are typed matches over that central map, not
independent editor-id-keyed stores. Its closed rows are feedback input,
feedback widgets, folding, content hover, and the local quick-diff decorator.
The registered Monaco timing modes remain recorded, but the current Viewer
constructs every row eagerly. Local quick diff is the per-Viewer reduction of
the workbench controller plus decorator, not a port of
`QuickDiffEditorController`.

The ownership migration used the checked-in `vscode` submodule. Its frozen 567-row upstream
ledger, 226-row local inventory, representation proof, exact lifetime trace,
and seam-based lifecycle deviation live in the main
`docs/exec-plans/editor-contribution-single-ownership.md` plan and its sibling
`editor-contribution-single-ownership-gate-a*.md` artifacts.

## Public editor API ownership

The scoped public clusters from upstream `common/config/editorOptions.ts`,
`common/editorCommon.ts`, the complete cursor-event source unit,
`browser/editorBrowser.ts`, `browser/widget/codeEditor/codeEditorWidget.ts`,
`editor.api.ts`, `editor.main.ts`, and the generated Monaco declarations map to
these local owners:

- DOM-free cursor/model/scroll events and editor-option enums map to the single
  multi-target `viewer/common/editor_api` package.
- Public mouse, ViewZone/accessor, and unmanaged overlay-widget contracts map
  to `viewer/browser`; mutable/rendered zone and widget state remains private in
  `viewer/browser/view`.
- The opaque `Viewer`, `ViewerOptions`, `ViewerServices`, and `ViewerViewState`
  facade maps to root `viewer`. Root factories let external hosts construct the
  browser-owned zone/widget values without importing browser internals.
- Language, marker, feedback, quick-diff, and logging service seams map to
  opaque handles beside their public vocabularies. Concrete feature services
  remain caller-retained common/contribution implementations and never appear
  in the root generated interface.
- Root debug subscriptions have no public upstream/API role. Internal
  workbench/browser observability maps to the local Viewer-id-keyed
  `viewer/browser/testing` seam, while the embedded host uses the semantic
  model-change event plus a URI-guarded native animation frame.

The boundary migration uses the checked-in `vscode` submodule. Its closed 210-row local public
disposition ledger, 1,322-row upstream cluster ledger, dependency proof, and
generated-interface snapshots live in
`docs/exec-plans/viewer-public-editor-api-boundary-gate-a*.md`.
