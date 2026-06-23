# Monaco Reference Map

Monaco/VS Code is the primary reference for this project. Use it for readonly
viewer behavior, API shape, rendering roles, widget behavior, and conformance
tests. Copy roles and observable behavior, not runtime code, services, or
package names.

The VS Code submodule contains Monaco's editor implementation under
`vscode/src/vs/editor`. Useful areas:

- `vscode/src/vs/base/common/uri.ts`: URI identity; local owner is
  `base/common.Uri`.
- `vscode/src/vs/editor/common/core`: `Position`, `Range`, offset/range helpers;
  local owner is `base/common`.
- `vscode/src/vs/editor/common/model`: text model, tokens, decorations, interval
  tree; local readonly text owner is `viewer/model`.
- `vscode/src/vs/monaco.d.ts`: public standalone editor/model APIs are
  model-based. Monaco exposes `editor.getModel(...)`, editor
  `getModel()` / `setModel(ITextModel | null)`, model-change events, and
  language providers such as hover providers whose callbacks receive an
  `ITextModel`. The local equivalent target is `viewer/model.TextModel` at the
  viewer and language-provider boundary; the internal shell's
  `workspace.DocumentSnapshot` is only a host/source-provider payload.
- `vscode/src/vs/editor/common/languages`: language registrations and tokenization.
  Local public registration is `@viewer.languages.*`: `set_tokens_provider`
  mirrors `monaco.languages.setTokensProvider`, while
  `register_hover_provider`, `register_diagnostics_provider`,
  `register_document_symbol_provider`,
  `register_document_semantic_tokens_provider`,
  `register_folding_range_provider`, and `register_inlay_hints_provider` cover
  this viewer's readonly semantic provider seams.
- `vscode/src/vs/editor/common/tokenizationRegistry.ts`: the
  `TokenizationRegistry` this repo's `Languages` facade uses for the same
  role — support registered per language id, looked up at render time, plain
  fallback on a miss.
- `vscode/src/vs/editor/common/languages.ts` (~lines 123-174):
  `ITokenizationSupport` and `IState` — the line-at-a-time tokenization
  contract with carried state and equality-based convergence that
  `syntax.LineTokenizer`/`TokenizerState` mirror.
- `vscode/src/vs/editor/standalone/common/monarch/`: the Monarch grammar
  compiler and interpreter (~1.9k lines). This repo keeps Monarch's
  state-machine structure (state stack, push/pop, keyword cases) but
  writes grammars as MoonBit `lexmatch` rules compiled at build time, so
  the `monarchCompile.ts` half has no equivalent here. Monaco's
  `basic-languages` grammar corpus lives in the external monaco-editor
  repository (not checked in); `codemirror/mode/` legacy stream modes are
  checked in as a second porting reference.
- `vscode/src/vs/editor/common/viewModel`: editor view model concepts.
- `vscode/src/vs/editor/browser/view`: DOM rendering layers and viewport rendering.
- Selection geometry (DOM-as-source-of-truth):
  `vscode/src/vs/editor/browser/controller/mouseTarget.ts`
  (`MouseTargetFactory.doHitTest` via `caretRangeFromPoint`/
  `caretPositionFromPoint`, bridged to a model column through the line's
  `CharacterMapping`),
  `vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts` +
  `rangeUtil.ts` (`getVisibleRangesForRange` /
  `RangeUtil.readHorizontalRanges` measuring DOM client rects),
  `vscode/src/vs/editor/browser/viewParts/selections/selections.ts`
  (`SelectionsOverlay`), and
  `vscode/src/vs/editor/browser/view/renderingContext.ts`
  (`RenderingContext.linesVisibleRangesForRange`). Local owners:
  `viewer/hit_test_dom.mbt`, `viewer/selection_measure.mbt`, the
  `measure_line_selection` seam on `ViewContext`, and the selection overlay in
  `viewer/view_overlays.mbt`; the column-to-DOM bridge is
  `viewer/view_line_renderer.CharacterMapping`. Implemented per
  `docs/exec-plans/monaco-faithful-selection-hit-testing.md`.
- `vscode/src/vs/base/browser/ui/scrollbar` and
  `vscode/src/vs/base/browser/ui/hover`: scrollbar, hover widget, and
  scrollable-element behavior exercised by the local conformance oracle.
- `vscode/src/vs/editor/contrib/hover`, `links`, `semanticTokens`, `find`:
  readonly feature references. A feature reference does not imply that the
  local viewer currently exposes that whole Monaco feature.

The hover/scrollbar conformance oracle lives in
`tests/reference/monaco-hover-scrollbar/`, with the Playwright comparison in
`tests/browser/conformance/monaco_hover_scrollbar.spec.js`. The fixture
transcribes the pinned Monaco DOM, CSS, and geometry constants for local
testing; product code still must not import from the VS Code submodule.

Use these as design references only. Do not import from them in product code.
When Monaco and current local docs disagree, treat current local docs as the
product boundary and Monaco as the source to research before changing it.
