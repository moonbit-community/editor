# examples/embedded_viewer

A real embedding target, the way Monaco's standalone editor proves its
package boundary: the viewer library (`renderer/browser`) plus the
file-tree widget (`widgets/file_tree`) mounted against in-memory
`DocumentSource` / `WorkspaceTreeProvider` implementations — a handful of
hardcoded documents and directories, zero server or websocket involvement.

The web build script bundles it into `web/dist/embed.mjs` +
`web/dist/embed.html`, and the native server serves it at `/embed.html`.
`tests/browser/embed.spec.js` asserts it renders a document, lazily
expands a folder, and navigates between files with no websocket opened.

## What it demonstrates

- Implementing `@workspace.DocumentSource` (open/watch/close) is the
  entire integration surface the viewer needs from a backend; here it is
  a `Map` of URI to text with inert watches.
- Implementing `@workspace.WorkspaceTreeProvider` (root + one-level
  resolve) is all the tree widget needs; here it is a `Map` of directory
  URI to child stats.
- The host wires the two together: the widget's `on_open` intent calls
  `viewer.open(uri)`, and the viewer's rendered notification calls
  `tree.set_active(uri)` for autoReveal.
- The mount seam: the shell renders one stable `.viewer-host` element and
  calls `viewer.attach(host)` after the first paint; the browser `View` owns the
  whole subtree and the shell never renders children into it.
- No language providers are registered, so hover and diagnostics simply
  stay absent — the registry starts empty by design.
