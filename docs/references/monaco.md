# Monaco Reference Map

The VS Code submodule contains Monaco's editor implementation under
`vscode/src/vs/editor`.

Useful areas:

- `vscode/src/vs/base/common/uri.ts`: URI identity; local owner is
  `base/common.Uri`.
- `vscode/src/vs/editor/common/core`: `Position`, `Range`, offset/range helpers;
  local owner is `renderer/core`.
- `vscode/src/vs/editor/common/model`: text model, tokens, decorations, interval
  tree; local readonly text owner is `renderer/model`.
- `vscode/src/vs/editor/common/languages`: language registrations and tokenization.
- `vscode/src/vs/editor/common/tokenizationRegistry.ts`: the
  `TokenizationRegistry` this repo's `syntax.TokenizerRegistry` copies —
  support registered per language id, looked up at render time, plain
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
- `vscode/src/vs/base/browser/ui/scrollbar` and
  `vscode/src/vs/base/browser/ui/hover`: scrollbar, hover widget, and
  scrollable-element constants used by
  `docs/references/monaco-hover-scrollbar-parity.md`.
- `vscode/src/vs/editor/contrib/hover`, `links`, `semanticTokens`, `find`: readonly feature references.

Use `docs/references/monaco-layer-map.md` for the current source-to-local role
ledger. It records whether a local role is exact, partial, a readonly subset,
future work, or intentionally skipped.

The hover/scrollbar conformance oracle lives in
`tests/reference/monaco-hover-scrollbar/`, with the Playwright comparison in
`tests/browser/monaco_conformance.spec.js`. The fixture transcribes the pinned
Monaco DOM, CSS, and geometry constants for local testing; product code still
must not import from the VS Code submodule.

Use these as design references only. Do not import from them in product code.
