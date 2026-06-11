# renderer/browser

Browser render backend adapter.

## Responsibilities

- Mount the Rabbita browser app and render backend-neutral
  `renderer.RenderFrame` values as browser HTML.
- Own the editor input bridge: one container handler set on the code viewer
  converts DOM events into typed `EditorEvent`s through the renderer's
  shared `hit_test`, fed by tracked view metrics (scroll offset, measured
  viewer height, char-probe width, gutter width). Rendered spans carry no
  handlers; overlay widgets swallow events under them.
- Own the feature controllers (`HoverController` today): each consumes
  editor events and answers with commands, span/line decorations, and
  widgets. Hover follows Monaco's timing (request at half the 300ms delay,
  display gated at the full delay, loading hover at 3x).
- Own the browser protocol client: counter-based request ids with a pending
  table so each response resumes its own suspended request, and the
  `language` provider trait implementations (`RemoteLanguageClient` in an
  ordered `ProviderRegistry`) the controllers resolve features through.
- Own the embedded code-surface cell: a cached Rabbita child cell with
  Map-keyed line children that renders only the visible line window between
  height-preserving spacers; the shell pushes frame/surface/window updates
  into it only when they change, so shell-only updates skip line subtrees.
- Own the browser document session loop: protocol connection, workspace
  listing, sidebar-driven workspace opens, server-backed document loads,
  watches, and refreshes.
- Emit browser observability events such as `moonbit:render` (with
  `buildMs`) and `dom:mounted` (with windowed `renderedLines` and
  `patchMs`).

Go-to-definition and find-references were removed for now; the viewer
focuses on hover until those features can be rebuilt without their bugs.

## Boundaries

- May depend on Rabbita public packages, `dom`, `workspace`, `language`,
  `remote_protocol`, `renderer`, `syntax`, and `decorations`.
- May declare JavaScript FFI it alone uses, under the host-FFI rule in
  `../../docs/architecture.md`; browser capabilities shared with other browser
  packages belong in `dom`.
- Module-level `Ref` registries (the app dispatcher, the protocol send hook,
  pending protocol requests, the code-cell cache) stay inside this package.
- Must not pass render-frame JSON to JavaScript for DOM rendering.
- Browser-only behavior stays here or in `dom`, not in shared renderer or
  domain packages.
- Must not expose a raw browser LSP transport.
- The backend-neutral `renderer` package must not import Rabbita or browser
  host packages.

## Checks

- Protocol-client correlation and hover staleness guards are covered by
  `protocol_client_wbtest.mbt`.
- Browser observability expectations are documented in `../../docs/harness.md`.
- Run `just check` for the repository-level type check.
