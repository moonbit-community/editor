# Architecture

The editor is a readonly code viewer. It borrows the separations used by
CodeMirror and Monaco without carrying editing machinery.

## Layers

- `core`: immutable `DocumentSnapshot`, UTF-16 offsets, positions, ranges, and line indexing.
- `syntax`: whole-document lexical highlighting for the first milestone.
- `decorations`: range-based visual annotations without edit mapping.
- `workspace`: readonly source document identity, URI/path normalization, language inference, and snapshot conversion.
- `language`: provider result types plus deterministic demo providers.
- `view`: DOM-neutral render model and JSON serialization.
- `dom`: JavaScript FFI boundary for the browser host.
- `web`: MoonBit main package that reads through `dom` and emits a render model.

The browser host owns DOM creation, CSS, scrolling, file read/watch effects, and
Playwright-facing observability. Future LSP transport effects should remain a
raw host bridge. MoonBit owns workspace semantics and readonly document
identity. Product code must not import from `codemirror/` or `vscode/`. Only the
`dom` package may declare JavaScript FFI.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser JavaScript
strings, Monaco/CodeMirror position behavior, and default LSP positions.
