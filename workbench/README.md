# workbench

The reference browser shell. It plays the small local `vs/workbench` role around
the reusable `viewer`: compose the viewer with an explorer widget, tokenizers,
language providers, theme state, remote protocol transport, and harness
observability.

This package demonstrates one host composition. It must call the viewer through
public APIs and must not rely on viewer DOM internals or private view-part
implementation details.

## Responsibilities

- Own the Rabbita app shell: topbar (title, language/revision, status),
  sidebar chrome (Explorer title, theme toggle), diagnostics panel,
  status/empty-viewer messages, and theme state + persistence.
- Own the websocket protocol client: counter-based request ids with a
  pending table so each response resumes its own suspended request
  (`protocol_request`), plus the uncorrelated push routing for watch and
  feature packets.
- Implement the host-side seams the viewer and widget are built against:
  `RemoteDocumentProvider` (`@workspace.DocumentProvider` over
  `OpenDocument`/`WatchDocument`/`CloseDocument` with a URI-keyed watch
  listener table), `RemoteWorkspaceTreeProvider`
  (`@workspace.WorkspaceTreeProvider` over `ResolveDirectory`), and
  `RemoteLanguageClient` (the `language` provider traits, registered with
  the viewer's selected `Languages` registry at startup).
- Own active-model composition: selecting a URI closes the previous source,
  reads the next source payload, converts it into `viewer/model.TextModel`,
  starts the host watch, applies watch updates through the viewer's model API,
  and decides how missing or failed documents affect the shell status and
  empty-viewer placeholder.
- Own the auto-open policy: a bounded depth-first resolve walk that opens
  the first MoonBit file (fallback: first file) when the socket opens with
  nothing loaded; the viewer's rendered notification then drives the
  tree's `set_active` (autoReveal).
- Own the viewer mount seam: the shell renders one stable `.viewer-host`
  element, never renders children inside it, and attaches the viewer after the
  first paint. Viewer methods are plain public calls lifted into shell commands.
  Host-captured keys route into public viewer entrypoints.
- Own harness observability: the viewer reports lifecycle facts through typed
  subscriptions and the workbench formats and emits the
  structured `[readonly-editor]` events (`dom:mounted`, `moonbit:render`,
  `view:scroll`, `language:*`) documented in `../docs/harness.md`, and
  installs the `__readonlyEditorScrollTo` scroll control. Workbench owns the
  browser-host helpers for harness globals, current-model exposure, theme
  storage, and protocol URL derivation. Workbench also installs the concrete
  runtime logger sink: provider failures go through `LogService`, and
  warning/error entries become the existing `language:error` harness event.

## Boundaries

- May depend on `base/common`, `viewer`, `viewer/model`,
  `widgets/file_tree`, `remote_protocol`, `workspace`, `language`,
  `platform/log`, concrete `syntax/lang_*` packages, and Rabbita packages
  including `websocket`.
- May declare narrowly scoped JavaScript FFI for workbench-owned browser-host
  effects such as harness observability, storage, and protocol URL derivation.
- Composition lives here: the viewer and tree widget must not know about each
  other or about the transport.
- Module-level `Ref` registries (the app dispatcher, the protocol send
  hook, pending protocol requests, the viewer and tree singletons) stay
  inside this package.

## Checks

- Protocol-client correlation is covered by `protocol_client_wbtest.mbt`.
- End-to-end behavior is covered by the Playwright specs in
  `../tests/browser`.
- Run `just check` for the repository-level type check.
