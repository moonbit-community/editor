# Rabbita Browser Backend Migration Plan

## Goal

Move the browser frontend from a handwritten JavaScript shell plus local `dom`
FFI package to a MoonBit-first browser app built on Rabbita.

The desired end state is:

- Rabbita owns browser DOM rendering, event dispatch, and app state updates.
- Product browser logic lives in MoonBit packages, not `app/src/main.js`.
- File selection happens inside the app through a VS Code-style workspace
  sidebar, not through `?uri=` or `?path=` URL parameters.
- Source content always comes from server API/protocol calls.
- The browser URL stays stable when selecting, opening, refreshing, or
  navigating between files.
- The local `dom` package is removed.
- Any remaining host boundary is narrow, named, and not a general DOM wrapper.
- The backend-neutral `renderer` package remains independent of Rabbita.

This plan replaces the browser render backend, not the native remote server or
the backend-neutral render-frame model.

## Rabbita Capability Check

Checked against `moonbit-community/rabbita` `main` at commit
`1b56fbcf48196ed4465967c72aa6ab8be3b9fc69` on 2026-06-10.

Relevant capabilities:

- Module metadata: Rabbita `0.12.4`, Apache-2.0, `preferred_target = "js"`,
  `supported_targets = "js+native"`.
- App runtime: `new(app).mount("app")` mounts a cell tree into a browser root.
- Stateful app model: `cell`, `simple_cell`, `cell_with_emit`, and
  `simple_cell_with_emit` support TEA-style model/update/view logic.
- External messages: `cell_with_emit` lets host-facing callbacks retain an
  `Emit[Msg]` value and dispatch render, document, hover, definition, and
  transport messages into the Rabbita app.
- Managed effects: `Cmd`, `batch`, `perform`, `attempt`, `delay`, and custom
  commands allow async work to re-enter the update loop as messages.
- Subscriptions: Rabbita has built-in subscriptions for resize, scroll, key,
  mouse, visibility, timers, and animation frames.
- HTML rendering: `@html` provides tag helpers, `Attrs::build()`,
  `Attrs::data_set()`, style/class/id helpers, mouse/keyboard/scroll/input
  handlers, keyed children via `Map[String, Html]`, and a `node()` escape hatch.
- Runtime rendering: the internal runtime builds VDOM nodes, patches real DOM,
  batches painting through `requestAnimationFrame`, and supports keyed diffing.
- Host helpers: `rabbita/http`, `rabbita/websocket`, and `rabbita/nav` can cover
  much of the browser transport/navigation surface without product-owned JS FFI.

Known constraints:

- Rabbita includes its own `moonbit-community/rabbita/dom` package with JS FFI.
  Rabbita's DOM FFI is the accepted browser framework boundary for this
  migration.
- Rabbita is an app framework. We should use public APIs from `@rabbita`,
  `@html`, `@sub`, `@http`, `@websocket`, and `@nav`; do not build product code
  on `moonbit-community/rabbita/internal/runtime`.
- Hydration is not currently supported. If we later add SSR, client mounting
  should be treated as a fresh render.
- We need an early spike to confirm large-file behavior, scroll preservation,
  and stable Playwright selectors.

## Target Package Shape

- `renderer`
  - Stays backend-neutral.
  - Continues to build `RenderFrame` from snapshots, syntax tokens,
    diagnostics, hovers, symbols, and semantic tokens.
  - Must not import Rabbita, browser packages, or host transports.

- `renderer/browser`
  - Becomes the Rabbita-backed browser renderer.
  - Imports Rabbita public packages and converts `RenderFrame` values to
    `@html.Html`.
  - Owns editor view state: current frame, status, workspace sidebar tree,
    active document selection, selected definition target, active hover
    tooltip, scroll metadata, and browser-facing observability.
  - Owns browser interactions as Rabbita messages, not JS listeners in
    `main.js`.

- `web`
  - Becomes the actual browser app entrypoint.
  - Mounts the Rabbita app.
  - Owns workspace navigation state, document session state, remote protocol
    client flow, and provider synchronization.
  - Uses Rabbita commands/subscriptions for async transport and lifecycle
    effects.

- `dom`
  - Removed after all product callers are migrated.
  - Do not replace it with another broad local JS FFI package.
  - If an unavoidable browser capability is missing from Rabbita, add the
    smallest named host package possible, for example `browser_host`, and keep
    it limited to that single capability.

- `app`
  - Keeps `index.html` and CSS as the Vite/browser harness.
  - `app/src/main.js` is deleted by the end of the migration.
  - Does not parse URL parameters for active document identity.
  - A temporary bootstrap file is allowed only while proving the generated
    MoonBit JS can be loaded directly from `index.html`.

## Workspace Sidebar Behavior

The browser app should behave like a readonly IDE workspace:

- On startup, the browser asks the native server for a workspace tree or a
  paged root listing.
- The left sidebar renders server-provided folders and files with stable
  root-relative IDs.
- Selecting a file sends an `OpenDocument` request to the server using the
  selected root-relative path or derived `readonly-remote://workspace/...` URI.
- The server reads the file, returns content and metadata, and starts or updates
  the watch for the selected document.
- The browser does not use `window.location.search`, `?uri=`, `?path=`,
  `history.pushState`, or hash fragments to represent the active file.
- Definition navigation to another file selects the target file in the sidebar
  and opens it through the same server API without changing the URL.
- Refreshing the browser returns to the default workspace state selected by the
  server, not to a URL-encoded active file. Later persistence can use server-side
  session state, not URL parameters.

The existing URI type remains useful as a protocol document identity, but it is
not a route. It should be hidden behind sidebar state and server protocol calls.

## Remote Protocol Delta

This migration builds on the already-implemented remote renderer architecture
instead of rewriting its execution plan. The sidebar work adds a small protocol
delta owned by this Rabbita migration:

- client requests: `ListWorkspace`, `OpenDocument`, `WatchDocument`,
  `CloseDocument`, `Hover`, `Definition`;
- server responses/events: `WorkspaceListed`, `DocumentLoaded`,
  `DocumentChanged`, `Diagnostics`, `HoverResult`, `DefinitionResult`,
  `Error`.

`ListWorkspace` and `WorkspaceListed` are new requirements for the sidebar.
`OpenDocument` should accept either a root-relative path selected from the
workspace tree or the derived `readonly-remote://workspace/...` URI.

The URL rule belongs to this migration: `readonly-remote://workspace/...`
remains protocol identity only. The browser must not use `?uri=`, `?path=`,
hashes, or history updates to represent the active file.

## Migration Slices

### 1. Dependency and Build Spike

- Add Rabbita as a MoonBit dependency.
- Build a minimal `web` app that mounts a static Rabbita cell into `#app`.
- Confirm `moon check --target all`, `moon build --target all`, `just build`,
  and `just test-browser` can run with Rabbita in the dependency graph.
- Decide whether Vite can load `web/generated/editor.mjs` directly from
  `app/index.html`; if yes, remove the JS bootstrap immediately for this spike.

Exit criteria:

- A Rabbita app mounts in the browser without `app/src/main.js` owning DOM
  rendering.
- The mounted app shows the main editor shell with a placeholder workspace
  sidebar region.
- Build output and source maps still land in `web/generated`.

### 2. Workspace Sidebar Skeleton

- Add Rabbita view/model state for:
  - workspace tree loading status;
  - expanded folders;
  - selected file ID/URI;
  - active document status.
- Render a VS Code-style left sidebar beside the readonly editor surface.
- Use server-shaped fake data first so layout, selection, keyboard focus, and
  Playwright selectors settle before the server protocol is extended.
- Keep the browser URL unchanged while selecting fake files.

Exit criteria:

- Selecting a sidebar item updates app state and active selection without
  changing `window.location.href`.
- Browser tests can assert sidebar selection and stable URL behavior.

### 3. RenderFrame to Rabbita HTML

- Add a pure adapter in `renderer/browser`:
  - `RenderFrame -> Html` for `.editor-shell`, `.topbar`, `.code-viewer`,
    `.code-lines`, `.code-line`, `.gutter`, `.code`, token spans, and
    diagnostics.
  - Preserve current CSS classes and `data-*` attributes used by Playwright:
    `data-status`, `data-line-count`, `data-source-uri`, span offsets,
    hover data, definition data, and definition target markers.
  - Use keyed children for lines and spans so changed frames do not replace the
    whole tree unnecessarily.
- Keep the existing `RenderFrame::to_json` until the old JS path is fully gone,
  then delete JSON-only render plumbing if no longer needed.

Exit criteria:

- The default demo frame renders through Rabbita with the same observable DOM
  shape expected by `tests/browser/viewer.spec.js`.
- `dom:mounted` and `moonbit:render` observability events are emitted from
  MoonBit-side logic.

### 4. Move Interaction State into Rabbita

- Model hover and definition as Rabbita messages:
  - `RequestHover(offset, version)`
  - `HoverResolved(offset, version, Hover?)`
  - `RequestDefinition(offset, version)`
  - `DefinitionResolved(version, Location?)`
  - `ClearHover`
  - `RevealDefinition(offset, uri)`
- Replace JS tooltip and definition listeners with Rabbita event handlers and
  model state.
- Keep readonly behavior: no editable document model, no text mutation, no
  cursor/edit machinery.
- Use existing CSS first; only adjust CSS when the Rabbita DOM shape requires
  it.

Exit criteria:

- Browser tests still observe hover tooltip text, `data-hover`,
  `data-definition-uri`, and `data-definition-target`.
- Version checks remain in MoonBit to reject stale hover/definition results.

### 5. Move Workspace, Document Session, and Remote Protocol Logic

- Move current `DocumentSession` responsibilities into `web` model/update:
  - request the workspace tree from the server on startup;
  - select the server-provided default file when appropriate;
  - load documents only through server API/protocol calls;
  - track status: loading, ready, stale, missing, error;
  - track revision/version increments;
  - reconnect watches on document changes.
- Extend the remote protocol/server as needed:
  - `ListWorkspace` or equivalent tree/list request;
  - workspace file/folder metadata response;
  - `OpenDocument` by root-relative path or derived remote URI;
  - `WatchDocument` for the active server-opened document.
- Remove URL-parameter and browser-local file selection behavior from the
  product path.
- Browser file picker and Vite `/@fs` file reads, if retained, are dev-only
  harness tools and must not be the product opening model.
- Use Rabbita `Cmd`/`attempt`/`perform` for async reads and protocol requests.
- Use `rabbita/websocket` or `rabbita/http` if they cover the chosen transport.
  If they do not, add a narrow transport host package only for request/watch
  primitives.

Exit criteria:

- `web` owns workspace navigation and document lifecycle without
  `app/src/main.js`.
- Selecting files in the sidebar loads content through server protocol calls.
- No product path reads active file identity from URL parameters.
- The old global callback API in `dom/browser_host.mbt` has no product callers.

### 6. Delete Local DOM and JS Shell

- Remove `dom/`.
- Remove `app/src/main.js`.
- Update `app/index.html` to load the generated MoonBit browser app directly,
  or the minimal generated-entry loader selected in slice 1.
- Update `web/moon.pkg` and `renderer/browser/moon.pkg` imports.
- Update docs:
  - `docs/architecture.md`
  - `docs/harness.md`
  - package `README.md` files
  - this plan, marking completed decisions
- Update architecture checks so product code cannot reintroduce broad JS FFI or
  `main.js`-style browser logic.

Exit criteria:

- No product source imports the removed local `dom` package.
- No handwritten JS application shell remains.
- Browser rendering, events, and observability are MoonBit/Rabbita-owned.
- File selection remains sidebar/server-driven with stable browser URLs.

## Validation Matrix

Run after each migration slice:

- `moon check --target all --warn-list +73`
- `moon test`
- `just build`
- `just test-browser`

Add or preserve browser smoke coverage for:

- demo document rendering;
- `readonly-remote://workspace/docs/fixtures/demo.mbt`;
- server-provided workspace tree rendering;
- sidebar folder expand/collapse;
- sidebar file selection without URL changes;
- content loading only through server API/protocol calls;
- diagnostics and diagnostic decorations;
- hover request, stale hover rejection, and tooltip display;
- definition request, same-document reveal, and cross-document navigation;
- watched document refresh;
- long lines and horizontal scrolling;
- large readonly file rendering;
- missing, invalid URI, permission, and transport error states;
- absence of accidental edit affordances.

## Risks and Decisions

- Rabbita DOM FFI is third-party FFI. Decision: Rabbita is the browser framework
  boundary, and product code should not introduce another broad DOM FFI layer.
- Vite dev local-file support may still need a host-only path. Keep it dev-only
  and separate from remote document semantics.
- The file sidebar makes workspace listing a first-class server API. That must
  be implemented in the native server before deleting URL/open-file fallbacks.
- Performance must be measured on realistic MoonBit files before deleting the
  old path. Keyed lines/spans and viewport rendering are likely necessary.
- Public Rabbita APIs are acceptable; internal runtime APIs are not.
- Do not collapse native server, remote protocol, and browser renderer work into
  one branch. The first branch should prove Rabbita rendering only.

## First Implementation Branch

Suggested first branch: `codex/rabbita-browser-renderer-spike`.

Scope:

1. Add Rabbita dependency.
2. Mount a Rabbita app from `web`.
3. Add the static sidebar skeleton and prove file selection does not touch the
   browser URL.
4. Render current demo `RenderFrame` through Rabbita.
5. Preserve current selectors and console events.
6. Keep document loading and remote protocol fallback unchanged until the
   rendered DOM passes the existing browser smoke tests.

Do not delete `dom` or `main.js` in the first branch unless direct generated JS
loading, Rabbita rendering, and stable-URL sidebar behavior all pass cleanly.

## 2026-06-10 Addendum: Next Implementation Slice

The first branch, `codex/rabbita-browser-renderer-spike`, proved Rabbita
rendering, stable sidebar selection, and preserved browser observability. It
intentionally left `app/src/main.js` in place as a bootstrap, provider host,
document session, and fallback JS renderer. The next slice exists to remove
that application-shell ownership rather than rename it or leave it as the
product entrypoint.

Suggested next branch: `codex/rabbita-generated-entry`.

Goal:

- Make the generated MoonBit browser app the direct Vite entrypoint, or use a
  minimal loader that only imports CSS and the generated module.
- Delete `app/src/main.js` as a product application shell.
- Move document/session/render ownership into MoonBit `web` and
  `renderer/browser` state.
- Keep any unavoidable JavaScript as a narrow host boundary for browser
  capabilities only. It must not render editor DOM, own document lifecycle, or
  represent active file identity.

Current state to start from:

- `app/index.html` loads `/src/main.js`.
- `app/src/main.js` imports `web/generated/editor.mjs`, installs file system
  and remote protocol globals, owns `DocumentSession`, manages status and
  watches, and still contains the old `renderEditor` fallback path.
- `web/main.mbt` mounts the Rabbita app and renders `RenderFrame` values once
  the JS shell has supplied document state and provider callbacks.
- `renderer/browser/app.mbt` owns the Rabbita DOM for the shell, sidebar,
  code viewer, diagnostics, hover, definition, and session status display.

Scope:

1. Decide and implement the generated entry strategy.
   - Prefer changing `app/index.html` to load `web/generated/editor.mjs`
     directly after `just build` has generated it.
   - If Vite cannot load the generated module directly in dev and production,
     add the smallest possible loader, for example `app/src/bootstrap.js`.
   - The loader may import `style.css`, install narrow host capability
     adapters, and import the generated MoonBit module. It must not render DOM,
     own `DocumentSession`, parse active-document URL state, or implement
     hover/definition UI.
2. Move document session ownership into MoonBit.
   - Model loading, ready, stale, missing, and error states in `web` or
     `renderer/browser`.
   - Track document identity, revision, and version increments in MoonBit.
   - Drive load, watch, hover, and definition requests through Rabbita
     messages and commands.
   - Keep the readonly invariant: no editable document model, mutation path,
     cursor editing state, or text input surface.
3. Replace broad globals with a narrow host API.
   - Remove product dependency on globals such as
     `__readonlyEditorMount` and callback APIs whose job is to mutate editor
     DOM or shuttle `RenderFrame` JSON into JS.
   - Keep only capability-specific host calls that Rabbita cannot cover, such
     as dev-only File System Access or a selected transport primitive.
   - Name the remaining boundary after the capability, not DOM. If a local
     package is still needed, prefer a small `browser_host`-style package over
     extending the broad `dom` package.
4. Delete the old JS renderer path.
   - Remove `renderEditor`, JS tooltip and definition listeners,
     `DocumentSession.mount`, and the fallback render/status DOM mutation path.
   - Preserve existing Playwright selectors through Rabbita-rendered DOM:
     `.editor-shell`, `.workspace-sidebar`, `.code-viewer`, `.code-line`,
     `.gutter`, `.code`, token span offsets, diagnostics, hover data, and
     definition target data.
5. Remove product URL active-file behavior from this path.
   - `?uri=`, `?path=`, hashes, and `history` updates must not drive active
     file identity.
   - If a local-file picker or Vite `/@fs` read remains for manual dev use, it
     must be harness-only and not the code path asserted by product browser
     tests.
6. Update tests and documentation.
   - Add a browser smoke assertion that `app/src/main.js` is not loaded as the
     app entrypoint.
   - Add or preserve coverage for generated-entry startup, stable URL sidebar
     selection, document status transitions, watched refresh, hover, and
     definition.
   - Update `docs/harness.md`, `docs/architecture.md`, `app` notes if any, and
     package READMEs for the new entrypoint and remaining host boundary.

Exit criteria:

- `app/index.html` no longer loads `/src/main.js`.
- `app/src/main.js` is deleted. If a loader remains, it is explicitly named as
  bootstrap or host glue and contains no editor rendering, session model, URL
  document routing, hover UI, or definition UI.
- `web/main.mbt` or packages it owns initialize and update document/session
  state without `DocumentSession` in JavaScript.
- No product code calls `__readonlyEditorMount`, passes `RenderFrame` JSON to
  JavaScript for DOM rendering, or depends on `renderEditor`.
- Sidebar selection and definition navigation keep `window.location.href`
  stable.
- Browser observability still emits structured `moonbit:render`,
  `dom:mounted`, `language:*`, and transport/status events needed by the
  harness.
- `moon check --target all --warn-list +73`, `moon test`, `just build`, and
  `just test-browser` pass.

Non-goals for this slice:

- Full removal of the local `dom` package if unavoidable host calls still need
  a temporary home.
- Large-file virtualization or performance tuning beyond preserving current
  browser smoke behavior.
- Completing the native server workspace listing protocol if a server-shaped
  fake or existing remote protocol path is still required to keep this slice
  focused on entrypoint and ownership.
