# Architecture

The editor is a readonly code viewer. It borrows the separations used by
CodeMirror and Monaco without carrying editing machinery.

## Layers

- `core`: immutable `DocumentSnapshot`, UTF-16 offsets, positions, ranges, and line indexing.
- `syntax`: whole-document lexical highlighting for the first milestone.
- `decorations`: range-based visual annotations without edit mapping.
- `workspace`: readonly source document identity, URI/path normalization, filesystem-provider contracts, language inference, and snapshot conversion.
- `language`: provider result types plus deterministic demo providers.
- `view`: DOM-neutral render model and JSON serialization.
- `dom`: JavaScript FFI boundary for the active backend host.
- `web`: MoonBit main package that reads source documents through a filesystem provider and emits a render model.

The viewer is a cross-platform app with a browser backend. The browser backend
owns DOM creation, CSS, scrolling, raw browser file handles, and Playwright-facing
observability. MoonBit owns workspace semantics, readonly document identity, and
the VS Code-style filesystem-provider contract (`readFile`, `watch`, and file
change events). Future native or desktop backends should implement the same
provider shape instead of changing the viewer pipeline. Future LSP transport
effects should remain a raw host bridge. Product code must not import from
`codemirror/` or `vscode/`. Only the `dom` package may declare JavaScript FFI.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser JavaScript
strings, Monaco/CodeMirror position behavior, and default LSP positions.
