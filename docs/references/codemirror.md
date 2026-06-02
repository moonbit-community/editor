# CodeMirror Reference Map

CodeMirror was hydrated with:

```sh
cd codemirror
node bin/cm.js install
```

Useful packages for this project:

- `codemirror/state`: immutable state and text abstractions.
- `codemirror/view`: viewport, line rendering, DOM view model, decorations.
- `codemirror/language`: language state, syntax integration, highlighting.
- `codemirror/lint`: diagnostics and lint decorations.
- `codemirror/search`: search range handling.
- `codemirror/lsp-client`: future LSP client reference.
- `codemirror/lang-javascript` and other `lang-*` packages: language package shape.

Use these as design references only. Do not import from them in product code.
