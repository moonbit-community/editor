# Monaco View-Part Render Architecture

Status: partially implemented; superseded for further work by
`monaco-view-part-ownership-architecture.md`.
Date: 2026-06-17

Implementation note, 2026-06-17: the initial `Island` to `View` move and the
first private `ViewPartRole` / `RenderingContext` lifecycle have landed. The
remaining work is now state ownership, real dirty rendering, stricter contexts,
and optional package promotion; use
`monaco-view-part-ownership-architecture.md` for that follow-up rather than
executing the stale current-state sections below literally.

## Summary

Refactor `renderer/browser` from an island-centered render loop into a
Monaco-style `View` plus `ViewPart` architecture. The public embedding surface
can remain `Viewer`, but the browser rendering internals should use Monaco's
role names, file names, render lifecycle, and structural DOM vocabulary where
the local readonly role is the same.

This plan is a narrow follow-up to the implemented
`monaco-role-aligned-viewer-architecture.md`. That broader plan made the
common/browser layer map and shipped readonly features such as soft wrap,
folding, inlay hints, selection/copy, and view zones. The remaining issue here
is internal render ownership: Monaco lets each view part own its DOM and render
phase, while our current `Island`/`Viewer::flush_render` path still coordinates
many parts through one fixed sequence.

## Goal

Make browser rendering easier to compare with Monaco source and easier to extend
without adding more logic to `Island` or `Viewer::flush_render`.

Target shape:

```text
Viewer                       public readonly embedding facade
  -> View                    Monaco editor/browser View role
       -> ViewPart[]         common render lifecycle
            ViewLines
            ViewZones
            ContentViewOverlays
            MarginViewOverlays
            ContentWidgets
            OverlayWidgets
            EditorScrollbar
```

`Viewer` keeps document-source ownership, public notifications, theme/options
entry points, and readonly feature services. `View` owns browser DOM, input
attachment, scheduling, viewport render orchestration, and the list of view
parts. Each `ViewPart` owns its DOM root, dirty state, read/prepare step, and
write/render step.

## Non-Goals

- Do not import product code from `vscode/`, `codemirror/`, or Monaco packages.
- Do not add Monaco's dependency injection, command service, contribution
  system, editable cursor stack, edit context, textarea input, minimap, overview
  ruler, or workbench service model.
- Do not make the viewer editable.
- Do not preserve old internal names merely for compatibility. Migrate docs,
  tests, examples, and harness selectors in the same change that renames a
  surface.
- Do not promote one package per Monaco file. First create role-aligned files
  inside `renderer/browser`; promote packages later only when dependency
  boundaries justify it.

## Current State

The current browser viewer already has many Monaco-shaped files:

```text
renderer/browser/view.mbt
renderer/browser/view_layer.mbt
renderer/browser/view_line.mbt
renderer/browser/view_zones.mbt
renderer/browser/view_overlays.mbt
renderer/browser/content_widgets.mbt
renderer/browser/overlay_widgets.mbt
renderer/browser/margin.mbt
renderer/browser/scrollable_element.mbt
```

The problem is that the render lifecycle is still centralized:

- `Viewer::attach` builds an `Island` and hooks input.
- `Viewer::flush_render` performs one fixed sequence: measure, render lines,
  apply geometry, update scrollbars, render hover.
- `Island::render_lines` coordinates line recycling, line numbers, folding
  markers, selection overlays, and view zones together.
- Hover, view zones, folding, selection, and scrollbars are separated by files,
  but not by a common render-part contract or independently tracked dirty state.

This is workable for the current readonly viewer, but it makes future
Monaco-source-led work harder because a change in one view concern often passes
through the central island sequence.

## Monaco Reference Points

Use these source files as the source map for this refactor:

```text
vscode/src/vs/editor/browser/view.ts
vscode/src/vs/editor/browser/view/viewPart.ts
vscode/src/vs/editor/browser/view/renderingContext.ts
vscode/src/vs/editor/browser/view/viewLayer.ts
vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts
vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts
vscode/src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts
vscode/src/vs/editor/browser/viewParts/overlayWidgets/overlayWidgets.ts
vscode/src/vs/editor/browser/viewParts/viewZones/viewZones.ts
vscode/src/vs/editor/browser/view/viewOverlays.ts
vscode/src/vs/editor/browser/viewParts/margin/margin.ts
vscode/src/vs/editor/browser/viewParts/lineNumbers/lineNumbers.ts
vscode/src/vs/editor/browser/viewParts/scrollbar/editorScrollbar.ts
```

Reference behavior to copy at the design level:

- `View` builds the editor root and child DOM containers.
- `View` stores a list of `ViewPart`s.
- `ViewPart` is an event handler with a render lifecycle:
  `onBeforeRender`, `prepareRender`, `render`, and `onDidRender`.
- `View` asks which parts need rendering, prepares viewport data, renders
  text lines, collects dirty parts again, then runs each part's prepare/write
  methods.
- DOM ownership belongs to the smallest matching part: view lines own line DOM,
  widgets own widget slots, view zones own zone DOM, margin overlays own margin
  overlays, and the scrollbar part owns scrollbar DOM.

## Naming Rules

Copy Monaco names where the local role is the same, translated to MoonBit style:

| Monaco | Local target |
| --- | --- |
| `View` | `View` |
| `ViewPart` | `ViewPart` |
| `ViewContext` | `ViewContext` |
| `RenderingContext` | `RenderingContext` |
| `RestrictedRenderingContext` | `RestrictedRenderingContext` |
| `ViewLayer` | `ViewLayer` |
| `ViewLines` | `ViewLines` |
| `ViewLine` | `ViewLine` |
| `ViewZones` | `ViewZones` |
| `ContentWidgets` | `ContentWidgets` |
| `OverlayWidgets` | `OverlayWidgets` |
| `ContentViewOverlays` | `ContentViewOverlays` |
| `MarginViewOverlays` | `MarginViewOverlays` |
| `Margin` | `Margin` |
| `EditorScrollbar` | `EditorScrollbar` |
| `ScrollableElement` | `ScrollableElement` |

File names should follow the same role names in lower snake case:

```text
renderer/browser/view_part.mbt
renderer/browser/view_context.mbt
renderer/browser/rendering_context.mbt
renderer/browser/view_lines.mbt
renderer/browser/view_line.mbt
renderer/browser/view_layer.mbt
renderer/browser/view_zones.mbt
renderer/browser/content_widgets.mbt
renderer/browser/overlay_widgets.mbt
renderer/browser/view_overlays.mbt
renderer/browser/margin.mbt
renderer/browser/editor_scrollbar.mbt
renderer/browser/scrollable_element.mbt
```

`Island` should disappear as a concept. If a transition bridge is needed during
implementation, keep it private, short-lived, and undocumented. The final docs
and code should talk about `View`, not `Island`.

For DOM names, use Monaco structural names when they identify editor structure:
`monaco-editor`, `overflow-guard`, `lines-content`, `view-lines`,
`view-zones`, `contentWidgets`, `overlayWidgets`,
`overflowingContentWidgets`, and `overflowingOverlayWidgets`. The root may keep
a product marker class such as `moonbit-viewer` only as an additional brand or
test aid, not as the structural name tests rely on.

## Target Render Lifecycle

The local render cycle should mirror Monaco's shape while remaining readonly:

```text
View::render()
  -> collect view parts where should_render()
  -> build ViewportData / RenderingContext inputs
  -> part.on_before_render(viewport_data)
  -> ViewLines::render_text(viewport_data)
  -> collect view parts again if line rendering changed layout/scroll
  -> part.prepare_render(rendering_context)
  -> part.render(restricted_rendering_context)
  -> part.on_did_render()
  -> notify Viewer of rendered/scroll facts
```

Keep the read/write discipline:

- measurement reads happen before writes;
- per-part `prepare_render` may read and compute;
- per-part `render` writes DOM;
- no part should read layout after another part has started writing, unless the
  plan explicitly records a Monaco-equivalent read-after-write case such as
  hover placement.

## Phase 0: Source Ledger and Baseline

Create a small implementation ledger before code moves:

- Add a section to `docs/references/monaco.md` or a local notes file in this
  plan's implementation branch mapping each target local file to the Monaco
  source file listed above.
- Record which roles are exact, readonly subset, deferred, or skipped.
- Run current browser/component/conformance checks and note any existing
  failures before refactoring.
- Identify tests that currently depend on `Island`, old selectors, or fixed
  render ordering.

Exit criteria:

- The refactor branch has a concrete role map.
- Existing behavior is reproducible before the first code move.

## Phase 1: Introduce `ViewPart` Infrastructure

Add the internal render abstractions without moving behavior yet:

- Add private `ViewPart` trait in `renderer/browser/view_part.mbt`.
- Add `ViewContext` for shared browser render state that parts need but should
  not mutate directly.
- Add `RenderingContext` and `RestrictedRenderingContext` in
  `rendering_context.mbt`.
- Add a small dirty-state convention: each part can report `should_render`,
  `on_before_render`, `prepare_render`, `render`, and `on_did_render`.
- Keep the API package-private until the ownership model stabilizes.

Exit criteria:

- `renderer/browser` compiles with the new infrastructure unused or lightly
  wired.
- No public `renderer/browser.Viewer` API changes are introduced in this phase.

## Phase 2: Rename `Island` to `View`

Move the root DOM owner to Monaco naming:

- Rename the internal `Island` type to `View`.
- Rename `Island::build` to `View::View` or `View::new`, following local
  MoonBit constructor conventions while keeping the role name `View`.
- Move root DOM creation and static container sync into `view.mbt`.
- Update `Viewer::attach` to create and store `View`.
- Rename field and helper references from `island` to `view`.
- Update comments, README text, and harness docs to stop calling the DOM owner
  an island.

Exit criteria:

- No production code, docs, or tests use `Island` as the intended architecture
  term.
- Attach behavior remains identical: one stable host element, idempotent mount,
  input hooks installed once, initial measurement scheduled.

## Phase 3: Extract `ViewLines` and `ViewLayer`

Separate line rendering from other visual concerns:

- Move line-node and render-input recycler state into `ViewLines`.
- Keep generic retained-window splice logic in `ViewLayer` where it matches the
  Monaco role.
- Make `ViewLines` the only owner of `.view-lines` children.
- Move per-line `RenderLineInput` construction and line HTML writes into
  `ViewLine`/`ViewLines`.
- Remove folding marker, selection overlay, and view-zone DOM writes from the
  line-render method.

Exit criteria:

- Scrolling still keeps DOM node count proportional to the viewport window.
- Existing line reuse and limited `innerHTML` rewrite tests still pass.
- Line rendering can be traced to the Monaco `ViewLines`/`ViewLayer` reference
  without passing through unrelated widget or margin logic.

## Phase 4: Extract View Parts for Zones, Overlays, Margin, and Widgets

Give each browser concern its own part:

- `ViewZones` owns `.view-zones`, view-zone node mounting, and zone positioning.
- `ContentWidgets` owns `.contentWidgets` and `.overflowingContentWidgets`.
  Hover remains the first content widget.
- `OverlayWidgets` owns `.overlayWidgets` and `.overflowingOverlayWidgets`,
  even if the readonly viewer has few overlay widgets initially.
- `ContentViewOverlays` owns text-space visual overlays such as selection.
- `MarginViewOverlays` owns margin-space overlays.
- `Margin` owns the margin root and static margin container composition.
- `LineNumbersOverlay` or the local equivalent owns line-number DOM under the
  margin overlay role.
- Folding markers move out of `ViewLines` into a margin/content overlay part
  that matches the final DOM placement.
- `EditorScrollbar` owns editor scrollbars and delegates geometry to the shared
  `ScrollableElement`.

Exit criteria:

- `Viewer::flush_render` no longer manually calls each visual concern in a
  hard-coded sequence.
- Each part owns its DOM root and write path.
- Existing hover, selection, folding, view-zone, scrollbar, and line-number
  behavior remains visible and covered by tests.

## Phase 5: Move to the Monaco Render Loop

Replace the fixed render sequence with `View`-coordinated part rendering:

- `Viewer` provides current source/view-model/layout state to `View`.
- `View` computes or receives `ViewportData`.
- `View` asks parts whether they need rendering.
- `ViewLines` renders text first.
- `View` collects dirty parts again after text render.
- `View` calls each part's `prepare_render` and `render` methods.
- Rendered-document and scrolled notifications still flow through `Viewer`.

Exit criteria:

- Render order can be explained with the same terms as Monaco's
  `_createCoordinatedRendering`.
- Parts can become dirty independently.
- A change in hover, scrollbar, view zone, or selection state does not require
  rewriting line DOM unless the relevant inputs changed.

## Phase 6: Naming and Selector Migration

Update all touched names in one pass:

- Rename files and internal types to the target naming table.
- Update `renderer/browser/README.md`, `docs/architecture.md`,
  `docs/harness.md`, and `docs/references/monaco.md`.
- Update browser/component/conformance tests to use the Monaco structural names.
- Update workbench/example comments that refer to island semantics.
- Remove old selectors and compatibility aliases unless a test proves an
  external public contract still needs one.

Exit criteria:

- Source, docs, and tests use one naming model.
- A new contributor can open Monaco `view.ts`/`viewPart.ts` and find the local
  counterpart by name.

## Phase 7: Optional Package Promotion

Only after the file-level extraction is stable, consider package promotion:

```text
renderer/browser/view
renderer/browser/widgets
renderer/browser/scrollbar
```

Promote only when the boundary reduces dependencies or prevents browser-only
effects from leaking. Do not create packages solely because Monaco has a file or
folder with the same name.

Exit criteria:

- `moon.pkg` imports express real dependency boundaries.
- Architecture checks prevent common-layer packages from importing browser view
  packages.

## Validation

For each coherent implementation slice:

```sh
git diff --check
moon check --target all
moon test --target js renderer/browser
just check
```

For slices touching browser DOM, input, or rendering:

```sh
just test-browser-conformance
just test-browser
```

For broad extraction or selector migration, also run a live smoke check:

```sh
just dev ROOT=/Users/baozhiyuan/Workspace/moonbit-project/simple PORT=5173
```

Verify in the browser:

- a MoonBit file opens and renders;
- scrolling keeps a bounded number of line nodes;
- diagnostics and marker hovers still render;
- hover appears as a content widget and remains positioned near edges;
- fold/unfold still updates margin and layout;
- inlay hints, wrapped lines, selection, copy, and view zones still compose;
- browser console is clean.

If port `5173` is already occupied, use a free port or stop the stale server
before treating failures as product regressions.

## Acceptance Criteria

- `Island` is gone from the intended architecture and replaced by `View`.
- `renderer/browser` has a private `ViewPart` lifecycle with independently
  renderable parts.
- `Viewer::flush_render` no longer owns every DOM operation directly; it
  delegates browser rendering to `View`.
- Each major DOM concern has a clear Monaco-named owner.
- Structural DOM and test selectors use Monaco naming where the structure
  matches Monaco.
- Public embedding behavior remains readonly and still flows through
  `Viewer`, `DocumentSource`, and `ViewerServices`.
- No product code imports from `vscode/` or `codemirror/`.
- Required checks pass, including browser conformance for touched DOM behavior.
