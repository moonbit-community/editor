# Agent Notes

## Project Shape

- Product code lives at the repository root in MoonBit packages: `core`, `syntax`, `decorations`, `language`, `view`, and `web`.
- `codemirror/` and `vscode/` are reference-only submodules. Do not import product code from either tree.
- The editor is strictly readonly in v1: no transactions, undo/redo, IME, edit cursor, piece table, or change mapping.

## References

- Architecture overview: `docs/architecture.md`
- Harness workflow: `docs/harness.md`
- Quality checks: `docs/quality.md`
- CodeMirror map: `docs/references/codemirror.md`
- Monaco map: `docs/references/monaco.md`

## Version Control

- Commit regularly to save work in meaningful steps.
- Keep commits focused around one coherent change and use messages that describe the behavior or decision being saved.
- Run the most relevant local checks before committing when the change can affect behavior.

## Local Harness

Run these from the repo root:

```sh
npm run check
npm run test
npm run build
npm run test:browser
```

Use `npm run dev` for the browser viewer. The web shell imports generated MoonBit JS from `web/generated/editor.mjs`, which is created by `npm run build:moon-web`.
