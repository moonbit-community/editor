# internal/shell/examples/embedded_viewer

A small internal embedding target for the reusable `viewer`. It mounts the
viewer and internal file-tree widget against in-memory documents and a
`WorkspaceTreeProvider` implementation. There is no workbench, server, remote
protocol, or websocket.

The web build script bundles it into `web/dist/embed.mjs` +
`web/dist/embed.html`, and the native server serves it at `/embed.html`.
`tests/browser/smoke/embed.spec.js` asserts it renders a document, lazily
expands a folder, and navigates between files with no websocket opened.

## What it demonstrates

- The host owns document storage and selection. Here it is a `Map` of URI to
  text; opening a file should build a `viewer/common/model.TextModel` and pass it to
  the viewer model API.
- Implementing `@workspace.WorkspaceTreeProvider` (root + one-level
  resolve) is all the tree widget needs; here it is a `Map` of directory
  URI to child stats.
- The host wires the two together: the widget's `on_open` intent reads from the
  in-memory document map, installs the corresponding text model on the viewer,
  and the viewer's rendered notification calls `tree.set_active(uri)` for
  autoReveal.
- The mount seam: the shell renders one stable `.viewer-host` element and
  calls `viewer.attach(host)` after the first paint; the browser `View` owns the
  whole subtree and the shell never renders children into it.
- No language providers are registered, so hover and diagnostics simply
  stay absent — the registry starts empty by design.
