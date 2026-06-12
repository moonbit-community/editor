# Pluggable Viewer Library and Provider-Backed File Tree

Status: proposed (2026-06-12).

## Goal

Restructure the browser side around VS Code's design so the viewer becomes an
embeddable library and the file tree sidebar becomes an optional,
provider-backed widget. Copied ideas (verified in the `vscode/` reference
tree):

1. Monaco's package boundary: `vs/editor` ships without the explorer because
   the workbench sits in a layer above it — exclusion by composition, not a
   config flag. Our viewer core keeps no sidebar; a `workbench` package
   composes the shipped app.
2. `IFileStat` + `IFileService.resolve` (`platform/files/common/files.ts`):
   entries are stat nodes carrying their full `resource` URI, minted by the
   provider side; `children` is resolved lazily one directory level at a
   time (`ExplorerItem.fetchChildren` -> `fileService.resolve`). Pull-based
   request/response; pushes only signal changes.
3. `IEditorService.openEditor({ resource })`: the explorer opens files by
   URI through a service and never touches the editor widget. Our
   equivalents are two `workspace` traits — `DocumentSource`
   (open/watch/close) and `WorkspaceTreeProvider` (root + resolve) — meeting
   the viewer at `DocumentUri`.
4. Explorer behavior: directories collapsed until expanded, children fetched
   on expand, and `autoReveal` expanding the tree to the active file.

The editor stays readonly. No URL routing is introduced. No compatibility
with the current flat-list sidebar design is kept: protocol packets are
replaced, not extended, and sidebar startup behavior intentionally changes
(client and server ship together; specs are updated, not preserved).

## Current State (verified against source)

- The sidebar is fused into the shell: `BrowserAppModel` carries
  `workspace_entries` / `selected_workspace_id` / `collapsed_workspace_ids`,
  and `view_sidebar`/`view_folder`/`view_file` live in
  `renderer/browser/app.mbt` next to the viewer.
- The tree is a flat, eager, pre-order list with `depth` annotations,
  produced by a full recursive walk on the server
  (`list_native_workspace_dir` in `server_host_native/native_host.mbt`) and
  fetched once per connection via `ListWorkspace`/`WorkspaceListed`, handled
  as an app-level push. Everything renders expanded by default.
- Selection works by string surgery on a hard-coded prefix:
  `workspace_id_from_uri` strips `readonly-remote://workspace/` and
  `workspace_document_uri` (`session.mbt`) re-adds it. Entries carry no URI.
- Document open/watch/close is hardwired to protocol packets
  (`load_workspace_document_cmd` sends `OpenDocument` + `WatchDocument`);
  `DocumentChanged` pushes route through the app update, not a watch seam.
- The language features already follow the target pattern: traits in
  `language`, `RemoteLanguageClient` implementing them over
  `protocol_request`, held in a (priv, hardcoded) `ProviderRegistry`
  (`language_client.mbt`).
- `WorkspaceEntry` is defined in `remote_protocol` (`protocol.mbt`), so any
  tree consumer must depend on the transport.
- `workspace` already owns `FileSystemProvider`, `FileWatch`,
  `SourceDocumentLoadResult` (`filesystem.mbt`) — reusable result/watch
  types for the new traits.
- `web` imports only `renderer/browser`; `scripts/_build/check-architecture.mbt`
  only greps for forbidden `codemirror/`/`vscode/` references and knows
  nothing about package imports.
- `tests/browser/workbench.spec.js` and `viewer.spec.js` depend on the
  sidebar classes/attributes, on every file being visible at startup, and on
  `dom:mounted` harness events.

## Target Package Shape

```text
web -> workbench
workbench -> renderer/browser, widgets/file_tree, remote_protocol, dom
renderer/browser -> renderer, dom, workspace, language, syntax, decorations
widgets/file_tree -> workspace (+ rabbita html/cmd)
workspace (gains WorkspaceStat + the two traits)
```

VS Code mapping: `renderer/browser` ↔ `vs/editor` (Monaco), `workbench` ↔
`vs/workbench` + the remote agent, `widgets/file_tree` ↔
`workbench/contrib/files` explorer view, `workspace.WorkspaceStat` ↔
`IFileStat`, `workspace` traits ↔ `IFileSystemProvider`/`IFileService` and
`IEditorService.openEditor(uri)`.

After the split, `renderer/browser` must not import `remote_protocol` or
`websocket`; `widgets/file_tree` must not import `remote_protocol` or
`renderer/browser`. Only `workbench` composes.

## Phase 1 — Workspace Contracts (IFileStat copy)

Steps:

1. Add `WorkspaceStat` to `workspace`, mirroring `IFileStat` in MoonBit
   idiom: `uri : DocumentUri`, `name : String`,
   `kind : WorkspaceEntryKind` (`File`/`Directory` enum in place of the
   `isFile`/`isDirectory` booleans), and
   `children : Array[WorkspaceStat]?` where `None` means "not resolved",
   exactly like `IFileStat.children: undefined`. URIs are minted by the
   provider side and carried on every stat. No `path`, no `depth` — depth
   is tree structure.
2. Add `WorkspaceTreeProvider` to `workspace` — the `IFileService.resolve`
   analog: `fn root(Self) -> DocumentUri` and
   `async fn resolve(Self, DocumentUri) -> WorkspaceResolveResult`,
   returning the stat for that URI with exactly one level of `children`
   resolved, or a `FileSystemProviderError`.
3. Add `DocumentSource` to `workspace` — the client-side mirror of
   `@server.ServerHost`, in `SourceDocument` terms:
   `async fn open_document(Self, DocumentUri) -> SourceDocumentLoadResult`,
   `fn watch_document(Self, DocumentUri, (SourceDocumentLoadResult) -> Unit) -> FileWatch`,
   `fn close_document(Self, DocumentUri) -> Unit`. Reuses `FileWatch` and
   `SourceDocumentLoadResult`. Document the relation to
   `FileSystemProvider` (content-level) vs `DocumentSource`
   (document-level, versioned, push-capable).
4. Protocol: add `ResolveDirectory(uri)` request and `DirectoryResolved`
   response carrying one stat with one level of children (kind serialized
   as a string at the wire boundary). `ListWorkspace`/`WorkspaceListed`
   stay temporarily so the old sidebar keeps compiling; they are deleted in
   Phase 3. Round-trip tests for the new packets.
5. Server: `ServerHost` gains one-level `read_directory(root, path)`;
   the native host implements it with a non-recursive `readdir` (reusing
   `skip_workspace_entry` filtering) and mints each child's
   `readonly-remote://workspace/<path>` URI. The recursive walk is deleted
   in Phase 3 with the old packets.

Validation: `moon check/test --target all`; new packet round-trip tests;
native host listing unit test for one-level resolution and URI minting.

## Phase 2 — DocumentSource Rewire

Still inside `renderer/browser`; sidebar untouched; behavior unchanged.

Steps:

1. `RemoteDocumentSource` implements `DocumentSource` over the protocol
   client: open → correlated `OpenDocument`; watch → `WatchDocument` plus a
   URI-keyed listener table that the websocket push branch routes
   `DocumentChanged` (and `FileNotFound` errors for the watched URI) into;
   close → `CloseDocument`. The app update stops handling `DocumentChanged`
   directly.
2. Document loading in the app update goes through the trait via provider
   commands (precedent: `hover_provider_cmd`). `workspace_document_uri`
   moves into `RemoteDocumentSource` pending full deletion when entries
   carry URIs in Phase 3.

Validation: all browser specs pass unchanged.

## Phase 3 — File-Tree Widget (explorer copy)

The widget is built directly against the new contracts in its final home,
so the sidebar is extracted once, not moved twice.

Steps:

1. Create `widgets/file_tree` (js target, no FFI; imports `workspace` and
   rabbita html/cmd). The widget is a Rabbita child cell owning a tree of
   `WorkspaceStat` nodes plus per-node expansion state — the
   `ExplorerItem`/`AsyncDataTree` role. Move the chevron/file icons; keep
   the DOM vocabulary (`workspace-item`, `workspace-folder`,
   `workspace-file`, `is-selected`, `data-workspace-id` now holding the
   URI, `aria-expanded`, `--depth` computed from tree depth, indent
   guides).
2. Lazy resolution, copied from `fetchChildren`: on mount the widget
   resolves `provider.root()`; expanding a directory with unresolved
   children calls `resolve(uri)` and caches the result on the node;
   directories render collapsed by default. A failed resolve renders the
   folder as empty-with-error state and is retried on next expand.
3. Widget API: constructed with a `&WorkspaceTreeProvider` and an
   `on_open : (DocumentUri) -> Unit` intent callback; `refresh()` re-resolves
   from the root (host calls it on reconnect); `set_active(uri)` is
   `autoReveal` — it resolves and expands the ancestor chain of the URI
   (derived from the root-relative path segments) and marks the node
   selected. The widget never opens documents itself.
4. The shell swaps `view_sidebar`'s entry list for the widget cell
   (sidebar chrome — Explorer title, theme toggle — stays in the shell);
   `on_open` routes to the existing document-open path; viewer lifecycle
   drives `set_active`. Auto-open policy (app policy, not widget behavior):
   on startup the shell does a bounded depth-first `resolve` walk to find
   the first `.mbt` file (fallback: first file) and opens it; `set_active`
   then reveals it in the tree.
5. Delete the flat-list design: `ListWorkspace`/`WorkspaceListed` packets,
   the server's recursive walk, `ServerHost.list_workspace`,
   `workspace_entries`/`collapsed_workspace_ids` model fields, the
   `view_folder`/`view_file` shell functions, and the remaining prefix
   surgery (`workspace_id_from_uri`, `selected_workspace_for_document`) —
   selection is URI equality.
6. Update browser specs for the new explorer behavior: nested files are
   not visible until their folders are expanded (or auto-revealed); specs
   that navigate to nested files expand folders or rely on auto-reveal of
   the auto-opened file.

Validation: `just test-browser` green with the updated specs; widget
expansion/reveal/resolve-caching logic unit-tested in the new package with
an in-memory `WorkspaceTreeProvider`.

## Phase 4 — Viewer/Workbench Package Split

Steps:

1. Create the `workbench` package (js target) and move shell concerns
   there: shell model/update/view (topbar, sidebar chrome, diagnostics
   panel, status/empty-viewer messages, theme state + persistence), the
   websocket protocol client, `RemoteLanguageClient`, `RemoteDocumentSource`,
   `RemoteWorkspaceTreeProvider`, the auto-open policy, and harness
   observability (`emit_event`, `dom:mounted` payloads). `web` imports
   `workbench`.
2. `renderer/browser` becomes the viewer-core library: code cell, input
   bridge, hover controller, `render_document`, provider registry. Its
   public embedding API:
   - constructed with a `&DocumentSource`; the language `ProviderRegistry`
     gains public registration functions (today a priv `let` hardcoding the
     remote client — the workbench registers the remote providers at
     startup);
   - `open(uri)` owns the full document-switch choreography currently
     spread across `select_workspace_update`/`document_rendered_update`
     (close previous, cell invalidation, scroll reset, re-measure, watch
     subscription) so embedders cannot get the sequencing wrong;
   - embeds as a Rabbita child cell (precedent: `code_surface_cell` and its
     `push_*_cmd` functions), with theme pushed in by the host;
   - emits lifecycle notifications (loaded/failed/changed, status) so the
     workbench syncs topbar, tree reveal, and harness events;
   - exposes a push API for unsolicited feature data so the workbench can
     route server-initiated diagnostics pushes into the render.
3. Viewer-owned model fields (`frame`, `source_document`, `provider_result`,
   `hover`, `scroll_top`, viewer metrics) move into the viewer cell; the
   shell keeps status, theme, and tree composition.

Validation: all browser specs pass unchanged from Phase 3;
`renderer/browser/moon.pkg` has no `remote_protocol` or `websocket`
imports.

## Phase 5 — Embedder Proof, Enforcement, Docs

Steps:

1. Prove the library boundary the way Monaco's standalone editor does — a
   real embedding target: a small `examples/embedded_viewer` js main
   package that mounts the viewer plus the file-tree widget against
   in-memory `DocumentSource` / `WorkspaceTreeProvider` implementations (a
   handful of hardcoded documents and directories), built by the web build
   script into `web/dist/embed.html`. Add a browser spec asserting it
   renders a document, expands a folder, and navigates between files with
   no websocket connection opened.
2. Extend `scripts/_build/check-architecture.mbt` to parse `moon.pkg`
   import lists and enforce the new rules: `renderer/browser` must not
   import `remote_protocol`/`websocket`/`workbench`/`widgets/*`;
   `widgets/file_tree` must not import `remote_protocol`/`renderer/browser`.
   Add the new directories to the forbidden-tree grep list.
3. Update `docs/architecture.md` (package map, dependency graph, the
   "workspace selection" system contract now phrased as provider + widget +
   workbench composition, explorer behavior contract), write READMEs for
   `workbench`, `widgets/file_tree`, and `examples/embedded_viewer`,
   refresh the `renderer/browser` README, and update `docs/harness.md` for
   the changed sidebar behavior and event ownership wording.

Validation: `just check`, `just test`, `just test-browser` green including
the new embed spec; architecture checker fails on a deliberate bad import
(verified once locally, then reverted).

## Cross-Cutting Decisions

- Composition over configuration: there is no `show_sidebar` flag anywhere.
  Excluding the tree means not importing the widget package (the Monaco
  cut).
- The tree contract copies `IFileStat`/`resolve`: stats carry
  provider-minted URIs, children resolve lazily one level per request,
  directories start collapsed, and `set_active` is `autoReveal`. The flat
  eager depth-annotated list is deleted, not deprecated.
- No wire compatibility: `ListWorkspace`/`WorkspaceListed` are replaced by
  `ResolveDirectory`/`DirectoryResolved`. Client and server ship together;
  the old packets survive only between Phase 1 and Phase 3 to keep each
  phase green.
- Not copied (yet): VS Code's compressed single-child folders
  (`resolveSingleChildDescendants`, the `a/b/c` rendering), multi-root
  workspaces, and tree drag/drop/context menus. All are additive later.
- No generic tree abstraction (`AsyncDataTree` equivalent): one consumer
  today, so the widget stays workspace-specific. Revisit when a second
  tree consumer exists.
- Server-initiated pushes (diagnostics) keep flowing: the workbench owns
  the socket and forwards them through the viewer's public feature-data
  API.
- Harness events (`dom:mounted`, `language:*`) stay workbench-owned; the
  viewer reports lifecycle facts, the workbench formats and emits.
- Phase order: 1 -> 2 -> 3 -> 4 -> 5. Phase 2 and 3 are independent and may
  swap. Each phase lands green on `just check`, `just test`,
  `just test-browser`.

## Spikes (before Phase 3 lands)

- Two cached sibling child cells (file tree + code surface) under Rabbita's
  slot diff: confirm independent skip/update behavior with a throwaway
  probe in `web`.
- Storing `&DocumentSource` / `&WorkspaceTreeProvider` trait objects in
  structs and module `Ref`s across async command boundaries on the js
  target (precedent: `ProviderRegistry` holds `Array[&HoverProvider]`, so
  expected to work — confirm for the async open/resolve paths).
- Async resolve from inside the widget cell's update loop (cmd dispatching
  back into the cell): confirm with the same probe.

## Exit Criteria

- `renderer/browser` compiles with no `remote_protocol`/`websocket`
  imports, enforced by the architecture checker.
- The shipped app (`just dev`) works end to end with the explorer-style
  tree: lazy expand, auto-reveal of the active file, reconnect refresh;
  spec suite green with the updated sidebar specs.
- The embedded example runs the viewer and the file tree from in-memory
  providers with zero server/websocket involvement, proven by a spec.
- Implementing `DocumentSource` (and optionally `WorkspaceTreeProvider`) is
  the entire integration surface for a custom backend, documented in the
  package READMEs with the example as reference.
