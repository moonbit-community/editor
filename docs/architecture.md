# Architecture

The v1 editor is a readonly code viewer. It borrows the separations used by
CodeMirror and Monaco without carrying editing machinery.

## Layers

- `core`: immutable `DocumentSnapshot`, UTF-16 offsets, positions, ranges, and line indexing.
- `syntax`: whole-document lexical highlighting for the first milestone.
- `decorations`: range-based visual annotations without edit mapping.
- `language`: provider result types plus deterministic demo providers.
- `view`: DOM-neutral render model and JSON serialization.
- `web`: MoonBit main package that reads browser-provided source and emits a render model.

The browser host owns DOM creation, CSS, scrolling, and Playwright-facing
observability. Product code must not import from `codemirror/` or `vscode/`.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser JavaScript
strings, Monaco/CodeMirror position behavior, and default LSP positions.
