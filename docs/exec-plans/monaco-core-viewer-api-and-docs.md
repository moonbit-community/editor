# Monaco-Core Viewer API and Documentation Cleanup

Status: Proposed

## Summary

The viewer package is the main product package. It should be a
Monaco-core-like readonly viewer: embedders create and compose document state,
filesystem access, file trees, watches, and reload policy in their own
application code, then pass document state into the viewer through a small public
API. The viewer should render, measure, scroll, expose view events, and host
focused readonly language features. It should not own document sessions,
filesystem watching, provider reads, or reload policy.

The surrounding workbench and workspace packages are development shells and
examples for external users. They should stay thin and should not know viewer
internals such as line layout, render caches, viewport derivation, feature
request lifecycles, or DOM structure.

This plan supersedes the provider-owned direction in
`docs/exec-plans/document-snapshot-viewer-api.md` where that plan makes
`Viewer::open`, `DocumentProvider::watch`, `reload`, and `notify` part of the
core viewer API.

## Use Case

An external app should be able to build its own readonly document experience by
composing independent parts:

- A file tree, tab strip, route, command palette, or app-specific picker chooses
  a document URI.
- The app reads the document from local memory, a remote server, a workspace
  provider, or any other source it owns.
- The app creates immutable document state with URI, language identity, text,
  version, and any metadata needed by viewer features.
- The app passes that document state to the viewer.
- If the underlying source changes, the app decides whether to ignore it,
  refresh the active document, preserve scroll position, show an error, or clear
  the viewer.

The built-in workbench and `examples/embedded_viewer` should be examples of this
composition model, not hidden special cases that rely on private viewer session
helpers or duplicate viewer internals.

## Target Responsibility Split

### `viewer`

- Own DOM creation, layout, line rendering, scroll state, hover/widget display,
  decorations, feature registries, typed events, and disposal of viewer-owned
  resources.
- Accept externally created document state through a small public API.
- Define the stable public document and view-state types used by embedders.
- Preserve or reset view state according to explicit caller intent.
- Keep document revision checks for async language feature results.
- Avoid filesystem, workspace-provider, watch, reload, and session-helper APIs.

### `workbench`

- Act as a thin development shell and reference embedding.
- Own remote protocol integration, file tree selection, active URI state, provider
  reads, provider watches, reload policy, and error display policy.
- Adapt remote snapshots into the viewer public document type.
- Call viewer APIs directly when the active document changes or refreshes.
- Avoid depending on viewer internals beyond the documented public API.

### `workspace`

- Provide shell-side file and workspace provider contracts used by the
  development workbench and examples.
- Avoid presenting `DocumentProvider` as a viewer-core requirement.
- Avoid becoming a second viewer abstraction layer.

### `examples/embedded_viewer`

- Demonstrate direct composition: an app owns documents and selection, then
  calls the viewer with document state.
- Avoid a viewer session helper. The example can have ordinary app code, but
  the reusable package should remain the viewer core.
- Keep example glue simple enough that external users can copy the composition
  pattern without learning viewer internals.

## Target API Shape

Use Monaco as the API-shape reference, not as a naming requirement. The viewer
should expose a small, explicit surface similar in spirit to `create`, `setModel`,
`getModel`, `updateOptions`, `layout`, events, and `dispose`.

Candidate public shape:

```moonbit
let viewer = Viewer::create(host, options?)
viewer.set_document(document, view_state_policy?)
viewer.clear_document()
viewer.current_document()
viewer.get_view_state()
viewer.restore_view_state(state)
viewer.update_options(options)
viewer.remeasure()
viewer.dispose()
```

Important API decisions to settle early:

- Choose one primary document API name. Prefer a MoonBit-owned name such as
  `set_document` over preserving `open` for core viewer behavior.
- Define the document type boundary. Start with the current immutable snapshot
  shape if it is already suitable; introduce or re-export a viewer-owned
  `ViewerDocument` only if that makes the package boundary cleaner.
- Prefer viewer-owned public types over making the workbench understand internal
  layout, render, or feature-state structures.
- Define view-state policy explicitly, for example reset view, preserve scroll
  anchor, or restore a caller-provided view state.
- Keep event APIs typed and disposable. Remove events whose only purpose was
  viewer-owned provider loading or watching.

APIs to remove from the viewer core:

- Provider-based construction.
- `open(uri)` as a read/watch/session operation.
- `reload()`, `notify(...)`, and other provider-change entry points.
- `DocumentProvider::watch` or any viewer-owned watch lifecycle.
- Reusable session helpers that hide reads, watches, and reload policy.

## Documentation Plan

Stable docs should describe product boundaries and public contracts, not detailed
implementation choreography.

Update living docs:

- `viewer/README.md`: make the composition use case the first design constraint;
  document the small core API, document ownership boundaries, and feature scope.
- `docs/architecture.md`: describe the viewer as a core renderer composed by
  workbench and external apps; move read/watch/reload policy to host code.
- `workbench/README.md`: describe workbench as the app-level composition layer
  that adapts protocol, workspace, tree, and viewer while staying a thin shell.
- `workspace/README.md`: describe workspace providers as host-side contracts, not
  a required viewer dependency or replacement viewer layer.
- `examples/embedded_viewer/README.md`: show the intended external-user flow.

Cleanup rules for this pass:

- Remove stale claims that the viewer owns reads, watches, reload policy, or
  document sessions.
- Remove any wording that makes workbench or workspace sound like the primary
  product API.
- Remove repetitive API inventories when the package README already names the
  public contract.
- Keep exact selectors, test hooks, and harness event names in harness or package
  docs only when external users need them.
- Do not rewrite implemented exec plans as current architecture. Add concise
  superseding notes only where a previous proposed plan conflicts with the new
  direction.

## Implementation Phases

### Phase 1: Align Docs With The Use Case

- Add this exec plan.
- Update `viewer/README.md` first so future API choices are judged against the
  composition use case.
- Update architecture and package READMEs to remove viewer-owned provider/watch
  language.
- Mark conflicting proposed exec-plan direction as superseded instead of
  preserving it as current truth.

Exit criteria:

- A new contributor can read the viewer README and understand that the host owns
  document source, selection, watching, and reload policy.
- No living doc presents `DocumentProvider::watch` as part of the viewer core API.

### Phase 2: Reshape Viewer Core API

- Remove provider from viewer construction.
- Make the selected document API accept caller-owned immutable document state.
- Replace provider-driven `open/reload/notify` behavior with explicit
  `set_document`, `clear_document`, view-state, and option/layout calls.
- Keep scroll, layout, render, hover, diagnostics, and feature registries inside
  the viewer.
- Keep revision guards so async feature results cannot apply to stale documents.

Exit criteria:

- The viewer package can be instantiated and shown a document without any
  filesystem or watch provider.
- Viewer disposal only disposes viewer-owned resources.

### Phase 3: Move Composition To Hosts

- Update workbench active-document flow so the workbench reads, watches, refreshes,
  and handles errors before calling the viewer.
- Keep the workbench flow thin: it should translate app events into public viewer
  calls, not mirror viewer layout, render, or feature logic.
- Update `examples/embedded_viewer` to demonstrate external composition without a
  reusable session helper.
- Keep user-facing behavior unchanged for opening files, scrolling, hover, and
  external refresh.

Exit criteria:

- Workbench and embedded viewer both use the same public core viewer API.
- Watch/reload behavior lives in host code and is visible in host tests or docs.
- No shell package depends on viewer internals to implement normal document
  opening, refresh, or scrolling behavior.

### Phase 4: Tests And Browser Validation

- Add or update focused tests for direct viewer document replacement, clear, view
  state reset, and view state preservation.
- Update workbench tests for active-document refresh and deleted/failed document
  policy.
- Keep existing browser smoke coverage for first open, scroll, hover, and file
  switch behavior.
- Run the repo guardrails listed in `docs/quality.md`, including `just check` and
  the relevant browser smoke tests.

Exit criteria:

- Core viewer tests prove the viewer does not need a provider.
- Workbench/browser tests prove the composed app still satisfies the original
  user flow.

### Phase 5: Documentation Cleanup Pass

- Remove redundant implementation detail from living docs after the API migration.
- Keep architecture docs at boundary level.
- Keep package READMEs focused on public contracts and local responsibilities.
- Keep harness docs focused on commands and externally consumed observability.

Exit criteria:

- Docs are short enough to guide future API design without becoming an execution
  log.
- Old provider-owned plans are clearly not the current design source.

## Non-Goals

- Do not add editing, undo/redo, completion, or full Monaco editor parity.
- Do not copy Monaco service architecture, dependency injection, or extension host.
- Do not add a viewer session helper as a replacement for provider-owned APIs.
- Do not make the workbench the only supported embedding model.
- Do not move viewer internals into workbench or workspace.
- Do not rewrite historical implemented exec plans as if they were living docs.

## Risks

- `set_document` versus `show` naming could create churn. Settle it before broad
  call-site updates.
- Moving watch/reload policy into hosts may reveal implicit behavior that was
  previously hidden inside the viewer.
- If the public document/view-state API is too low-level, the workbench will
  become complicated. Treat that as a viewer API design failure, not as a reason
  to add shell-only knowledge of internals.
- Language provider APIs need a clean document boundary so they remain useful
  without reintroducing a provider dependency.
- Documentation cleanup should remove stale detail without deleting externally
  useful harness contracts.

## Final Acceptance

- `viewer` has a Monaco-core-like public API centered on caller-owned document
  state.
- `viewer` no longer exposes or requires provider reads, watches, reload policy,
  notify hooks, or session helpers.
- The external composition use case is documented in `viewer/README.md` and
  reflected consistently in architecture and package docs.
- Workbench and embedded viewer continue to satisfy the original readonly viewer
  flow by composing provider, tree, watch, and viewer APIs at the app layer
  without depending on viewer internals.
- The documentation set is concise and does not preserve obsolete implementation
  detail as current guidance.
