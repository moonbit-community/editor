# Architecture

The editor is a readonly code viewer. It borrows the separations used by
CodeMirror and Monaco without carrying editing machinery.

## Layers

- `core`: immutable `DocumentSnapshot`, UTF-16 offsets, positions, ranges, and line indexing.
- `syntax`: whole-document lexical highlighting for the first milestone.
- `decorations`: range-based visual annotations without edit mapping.
- `workspace`: readonly source document identity, URI/path normalization, filesystem-provider contracts, language inference, and snapshot conversion.
- `language`: provider traits, provider result types, deterministic demo providers, and the readonly LSP client.
- `view`: DOM-neutral render model and JSON serialization.
- `dom`: JavaScript FFI boundary for the active backend host.
- `web`: MoonBit main package that reads source documents through a filesystem provider and emits a render model.

The viewer is a cross-platform app with a browser backend. The browser backend
owns DOM creation, CSS, scrolling, raw browser file handles, and Playwright-facing
observability. MoonBit owns workspace semantics, readonly document identity, and
the VS Code-style filesystem-provider contract (`readFile`, `watch`, and file
change events). Future native or desktop backends should implement the same
provider shape instead of changing the viewer pipeline. LSP transport effects
remain a raw host bridge in `dom`; MoonBit owns LSP JSON-RPC message shaping,
readonly document sync state, diagnostics, hover normalization, and stale-result
discard. Product code must not import from `codemirror/` or `vscode/`. Only the
`dom` package may declare JavaScript FFI.

## Browser LSP Host Contract

Browser hosts may inject `globalThis.__readonlyEditorLspTransport` before the
MoonBit web module is loaded. The transport shape is:

- `request(message, { signal }) -> Promise<string> | string`: sends a raw
  JSON-RPC request and returns the raw JSON-RPC response string.
- `notify(message, { signal }) -> Promise<void> | void`: sends a raw JSON-RPC
  notification.
- `subscribe(listener) -> { dispose() }`: registers a raw JSON-RPC notification
  listener, primarily for `textDocument/publishDiagnostics`.

If no host transport is injected, the browser app installs a deterministic fake
LSP transport for tests and the default demo.

## Position Convention

Offsets and columns are UTF-16 code units. This matches browser JavaScript
strings, Monaco/CodeMirror position behavior, and default LSP positions.
