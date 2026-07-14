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
tokenization merge used oracle commit
`b18492a288de038fbc7643aae6de8247029d11bd`.

## View model and inline decorations

The upstream `common/viewModel/inlineDecorations.ts`,
`viewModelDecoration.ts`, and `viewModelDecorations.ts` units map to focused
files in the single multi-target local `viewer/common/view_model` package.
The upstream `test/common/viewModel/inlineDecorations.test.ts` suite maps to
`inline_decorations_reference_wbtest.mbt` in that package. The ownership
merge and its 23-case conformance denominator use oracle commit
`b18492a288de038fbc7643aae6de8247029d11bd`; member-level dispositions and
terminal product-reach deferrals live in the frozen execution-plan ledger.
