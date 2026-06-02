# Monaco Reference Map

The VS Code submodule contains Monaco's editor implementation under
`vscode/src/vs/editor`.

Useful areas:

- `vscode/src/vs/editor/common/core`: `Position`, `Range`, offset/range helpers.
- `vscode/src/vs/editor/common/model`: text model, tokens, decorations, interval tree.
- `vscode/src/vs/editor/common/languages`: language registrations and tokenization.
- `vscode/src/vs/editor/common/viewModel`: editor view model concepts.
- `vscode/src/vs/editor/browser/view`: DOM rendering layers and viewport rendering.
- `vscode/src/vs/editor/contrib/hover`, `links`, `semanticTokens`, `find`: readonly feature references.

Use these as design references only. Do not import from them in product code.
