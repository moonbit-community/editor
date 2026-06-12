# workbench

The shipped app shell — the `vs/workbench` + remote-agent role. It is the
only package that composes the viewer library, the explorer widget, and the
remote protocol transport.

## Responsibilities

- Own the Rabbita app shell: topbar (title, language/version, status),
  sidebar chrome (Explorer title, theme toggle), diagnostics panel,
  status/empty-viewer messages, and theme state + persistence.
- Own the websocket protocol client: counter-based request ids with a
  pending table so each response resumes its own suspended request
  (`protocol_request`), plus the uncorrelated push routing for watch and
  feature packets.
- Implement the seams the viewer and widget are built against:
  `RemoteDocumentSource` (`@workspace.DocumentSource` over
  `OpenDocument`/`WatchDocument`/`CloseDocument` with a URI-keyed watch
  listener table), `RemoteWorkspaceTreeProvider`
  (`@workspace.WorkspaceTreeProvider` over `ResolveDirectory`), and
  `RemoteLanguageClient` (the `language` provider traits, registered with
  the viewer's provider registry at startup).
- Own the auto-open policy: a bounded depth-first resolve walk that opens
  the first MoonBit file (fallback: first file) when the socket opens with
  nothing loaded; the viewer's rendered notification then drives the
  tree's `set_active` (autoReveal).
- Own the viewer mount seam: the shell renders one stable `.viewer-host`
  element (never any children inside it) and attaches the imperative
  viewer island into it after the first paint; viewer methods are plain
  calls lifted into shell commands. Host-captured keys route into the
  viewer (Escape to the controllers; PgUp/PgDn/Home/End/arrows into the
  synthetic scroll methods).
- Own harness observability: the viewer reports lifecycle facts
  (`ViewerNotification`) and the workbench formats and emits the
  structured `[readonly-editor]` events (`dom:mounted`, `moonbit:render`,
  `view:scroll`, `language:*`) documented in `../docs/harness.md`, and
  installs the `__readonlyEditorScrollTo` scroll control.

## Boundaries

- May depend on `renderer/browser`, `widgets/file_tree`,
  `remote_protocol`, `dom`, `workspace`, `language`, and Rabbita packages
  including `websocket`.
- Composition lives here: the viewer and the tree widget must not know
  about each other or about the transport.
- Module-level `Ref` registries (the app dispatcher, the protocol send
  hook, pending protocol requests, the viewer and tree singletons) stay
  inside this package.

## Checks

- Protocol-client correlation is covered by `protocol_client_wbtest.mbt`.
- End-to-end behavior is covered by the Playwright specs in
  `../tests/browser`.
- Run `just check` for the repository-level type check.
